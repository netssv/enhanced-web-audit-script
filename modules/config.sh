#!/bin/bash

# Configuration module - Handle all configuration loading and validation
# Part of Enhanced Web Audit Script v2.1

# Source core module
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Load and validate configuration
load_and_validate_config() {
    # Set defaults
    declare -A default_config=(
        [TIMEOUT_DNS]=8
        [TIMEOUT_HTTP]=15
        [TIMEOUT_WHOIS]=12
        [TIMEOUT_SSL]=10
        [MAX_RETRIES]=3
        [MAX_REDIRECTS]=5
        [USER_AGENT]="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    )
    
    # Apply defaults first
    for key in "${!default_config[@]}"; do
        declare -g "$key=${default_config[$key]}"
    done
    
    if [[ -f "$CONFIG_FILE" ]]; then
        log_debug "Loading configuration from $CONFIG_FILE"
        # Source the config file safely
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Validate and set known configuration variables
            case $key in
                TIMEOUT_DNS|TIMEOUT_HTTP|TIMEOUT_WHOIS|TIMEOUT_SSL|MAX_RETRIES|MAX_REDIRECTS)
                    if [[ $value =~ ^[0-9]+$ ]] && [[ $value -gt 0 ]] && [[ $value -le 300 ]]; then
                        declare -g "$key=$value"
                        log_debug "Set $key=$value"
                    else
                        log_warning "Invalid config value for $key: $value (using default: ${default_config[$key]})"
                    fi
                    ;;
                USER_AGENT)
                    if [[ ${#value} -lt 500 && ${#value} -gt 10 ]]; then
                        declare -g "$key=$value"
                        log_debug "Set $key=$value"
                    else
                        log_warning "Invalid USER_AGENT length (using default)"
                    fi
                    ;;
                LOG_FILE)
                    if [[ -n "$value" ]]; then
                        local log_dir=$(dirname "$value")
                        if [[ -d "$log_dir" && -w "$log_dir" ]]; then
                            LOG_FILE="$value"
                            log_debug "Set LOG_FILE=$value"
                        else
                            log_warning "Log directory not writable: $log_dir"
                        fi
                    fi
                    ;;
            esac
        done < "$CONFIG_FILE"
    fi
}

# Dependency validation
validate_dependencies() {
    local missing_deps=()
    
    # Essential tools
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v openssl >/dev/null 2>&1 || missing_deps+=("openssl")
    command -v bc >/dev/null 2>&1 || missing_deps+=("bc")
    
    # Check for at least one DNS resolution tool
    if ! command -v dig >/dev/null 2>&1 && ! command -v nslookup >/dev/null 2>&1 && ! command -v getent >/dev/null 2>&1; then
        missing_deps+=("dnsutils (or nslookup)")
    fi
    
    # Optional but recommended
    command -v whois >/dev/null 2>&1 || log_warning "whois not found - domain info will be limited"
    command -v nmap >/dev/null 2>&1 || log_warning "nmap not found - port scanning will use netcat fallback"
    command -v jq >/dev/null 2>&1 || log_warning "jq not found - JSON parsing will be basic"
    command -v nc >/dev/null 2>&1 || log_warning "netcat not found - port checking will be limited"
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo "Note: This script requires basic networking tools. Install them if possible."
        exit 1
    fi
}

# Enhanced domain validation
validate_domain() {
    local domain="$1"
    
    # Length validation
    if [[ ${#domain} -gt 253 ]]; then
        log_error "Domain name too long (max 253 characters)"
        return 1
    fi
    
    # Character validation
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Invalid domain format: $domain"
        return 1
    fi
    
    # Check for reserved domains
    case "$domain" in
        localhost|*.localhost|*.local|*.test|*.example)
            log_warning "Using reserved/test domain: $domain"
            ;;
    esac
    
    echo "$domain"
}

# Enhanced domain extraction with validation
extract_domain() {
    local input="$1"
    local domain
    
    # Input validation
    if [[ -z "$input" ]]; then
        log_error "No domain provided"
        return 1
    fi
    
    # Remove protocol if present
    domain=$(echo "$input" | sed -E 's#^https?://##' | sed 's#/.*##')
    
    # Remove port if present
    domain=$(echo "$domain" | sed 's/:[0-9]*$//')
    
    # Validate domain using the validation function
    if ! validate_domain "$domain" >/dev/null; then
        return 1
    fi
    
    # Check for malicious patterns
    case "$domain" in
        *"<"*|*">"*|*"'"*|*'"'*|*"&"*|*";"*|*"|"*|*'`'*|*'$'*|*"("*|*")"*)
            log_error "Domain contains potentially malicious characters"
            return 1
            ;;
    esac
    
    echo "$domain"
}
