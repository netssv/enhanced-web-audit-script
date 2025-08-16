#!/bin/bash

# Enhanced Web Audit Script - Enhanced Version 2.1
# Author: netss - Enhanced by Web Analyst
# GitHub: https://github.com/netssv
# Description: A robust CLI tool for comprehensive web audits including DNS, HTTP, SSL, and tech stack analysis.

# Script constants
readonly SCRIPT_VERSION="2.1"
readonly SCRIPT_NAME="Enhanced Web Audit Script"
readonly MIN_BASH_VERSION=4

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Check bash version compatibility
check_bash_version() {
    if [[ ${BASH_VERSION%%.*} -lt $MIN_BASH_VERSION ]]; then
        echo -e "${RED}[ERROR]${NC} Bash version $MIN_BASH_VERSION or higher required. Current: $BASH_VERSION" >&2
        exit 1
    fi
}

# Call version check early
check_bash_version

# Global variables for better error handling
TIMEOUT_DNS=8
TIMEOUT_HTTP=15
TIMEOUT_WHOIS=12
TIMEOUT_SSL=10
MAX_RETRIES=3
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# Configuration file support
CONFIG_FILE="${HOME}/.auditweb.conf"

# Enhanced logging configuration
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"

# Rate limiting for external requests
declare -A request_timestamps=()
declare -A request_counts=()

# Performance benchmarking variables
declare -A benchmark_times=()
declare benchmark_start_time=""

# Performance benchmarking functions
start_benchmark() {
    local operation="$1"
    benchmark_start_time=$(date +%s.%N)
    log_debug "Starting benchmark for: $operation"
}

end_benchmark() {
    local operation="$1"
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $benchmark_start_time" | bc -l 2>/dev/null || echo "0")
    benchmark_times["$operation"]="$duration"
    log_debug "Benchmark for $operation: ${duration}s"
}

show_performance_report() {
    echo -e "${GREEN}== Performance Benchmarks ==${NC}"
    echo "Operation timings:"
    
    for operation in "${!benchmark_times[@]}"; do
        local time="${benchmark_times[$operation]}"
        printf "  %-25s: %8.3fs\n" "$operation" "$time"
    done
    
    # Calculate total time
    local total_time=0
    for time in "${benchmark_times[@]}"; do
        total_time=$(echo "$total_time + $time" | bc -l 2>/dev/null || echo "$total_time")
    done
    
    echo
    printf "  %-25s: %8.3fs\n" "Total Audit Time" "$total_time"
    echo
}

# Enhanced logging with levels
log_with_level() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file if specified
    [[ -n "$LOG_FILE" ]] && echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        ERROR) echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        WARN) echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        INFO) echo -e "${CYAN}[INFO]${NC} $message" ;;
        DEBUG) [[ "$DEBUG" == "1" ]] && echo -e "${MAGENTA}[DEBUG]${NC} $message" ;;
    esac
}

# Replace existing log functions
log_error() { log_with_level "ERROR" "$1"; }
log_warning() { log_with_level "WARN" "$1"; }
log_section() { log_with_level "INFO" "$1"; }
log_debug() { log_with_level "DEBUG" "$1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Load configuration if it exists
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
                    if [[ ${#value} -lt 500 && ${#value} -gt 10 ]]; then  # Reasonable length limit
                        declare -g "$key=$value"
                        log_debug "Set $key=$value"
                    else
                        log_warning "Invalid USER_AGENT length (using default)"
                    fi
                    ;;
                LOG_FILE)
                    # Validate log file path
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

show_help() {
    cat << EOF
Enhanced Web Audit Script v$SCRIPT_VERSION
==============================

USAGE:
    $0 <URL> [format] [options]

ARGUMENTS:
    URL         Domain or URL to audit (required)
                Examples: example.com, https://example.com, subdomain.example.com

    format      Output format (optional, default: terminal)
                Options: terminal, html, txt, json

OPTIONS:
    debug       Enable debug mode for verbose output
    --config    Show configuration file location
    --version   Show version information
    --help      Show this help message
    --self-test Run self-test to verify script functionality

FEATURES:
    • Comprehensive DNS analysis with parallel queries
    • SSL certificate validation and security
    • Web technology detection (CMS, frameworks, etc.)
    • Hosting provider identification
    • Performance benchmarking and testing
    • Security headers analysis
    • Port scanning and connectivity tests
    • Geolocation and ISP information
    • Multiple output formats with proper escaping

EXAMPLES:
    $0 https://google.com
    $0 example.com html
    $0 subdomain.example.com terminal debug
    $0 --config
    $0 --self-test

CONFIGURATION:
    Config file: $CONFIG_FILE
    You can override default timeouts and settings in this file.

PERFORMANCE:
    The script includes built-in performance testing that measures:
    • HTTP response times (5 test requests)
    • DNS resolution performance
    • SSL handshake timing
    • Overall operation benchmarking

HOSTING DETECTION:
    Automatically detects:
    • Cloud providers (AWS, GCP, Azure, etc.)
    • CDN services (Cloudflare, Fastly, etc.)
    • Hosting companies and control panels
    • Performance optimizations (HTTP/2, compression)

EOF
    exit 1
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

# Sanitize output to prevent injection
sanitize_output() {
    local input="$1"
    # Remove control characters and limit length
    echo "$input" | tr -d '\0-\037\177' | head -c 1000
}

# Rate limiting for external requests
rate_limit_check() {
    local host="$1"
    local max_requests=10
    local time_window=60
    local current_time=$(date +%s)
    
    # Clean old entries
    for key in "${!request_timestamps[@]}"; do
        if [[ $((current_time - request_timestamps[$key])) -gt $time_window ]]; then
            unset request_timestamps[$key]
            unset request_counts[$key]
        fi
    done
    
    # Check current rate
    local count=${request_counts[$host]:-0}
    if [[ $count -ge $max_requests ]]; then
        log_warning "Rate limit reached for $host, waiting..."
        sleep 5
        return 1
    fi
    
    # Update counters
    request_timestamps[$host]=$current_time
    request_counts[$host]=$((count + 1))
    return 0
}

# Progress tracking for long operations
show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    
    local percentage=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percentage * bar_length / 100))
    
    printf "\r${CYAN}[%s] %d%% %s${NC}" \
        "$(printf "%*s" "$filled_length" | tr ' ' '=')" \
        "$percentage" \
        "$description"
    
    [[ $current -eq $total ]] && echo
}

# Enhanced domain extraction with better validation and security
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
    
    # Validate domain using the new validation function
    if ! validate_domain "$domain" >/dev/null; then
        return 1
    fi
    
    # Check for obviously malicious patterns (simplified approach)
    case "$domain" in
        *"<"*|*">"*|*"'"*|*'"'*|*"&"*|*";"*|*"|"*|*'`'*|*'$'*|*"("*|*")"*)
            log_error "Domain contains potentially malicious characters"
            return 1
            ;;
    esac
    
    echo "$domain"
}

# Robust DNS resolution with multiple methods using enhanced dig
resolve_domain() {
    local domain="$1"
    local ip=""
    local method=""
    
    # Method 1: dig (preferred) - Enhanced with perform_dig_query
    if command -v dig >/dev/null 2>&1; then
        ip=$(perform_dig_query "$domain" "A" | head -1)
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            method="dig (enhanced)"
        else
            # Fallback to traditional dig
            ip=$(timeout "$TIMEOUT_DNS" dig +short +time=3 +tries=2 "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
            method="dig (traditional)"
        fi
    fi
    
    # Method 2: nslookup (fallback)
    if [[ -z "$ip" ]] && command -v nslookup >/dev/null 2>&1; then
        ip=$(timeout "$TIMEOUT_DNS" nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
        method="nslookup"
    fi
    
    # Method 3: getent (system resolver)
    if [[ -z "$ip" ]] && command -v getent >/dev/null 2>&1; then
        ip=$(timeout "$TIMEOUT_DNS" getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -1)
        method="getent"
    fi
    
    # Method 4: DNS over HTTPS fallback (if curl is available)
    if [[ -z "$ip" ]] && command -v curl >/dev/null 2>&1; then
        ip=$(timeout 10 curl -s "https://dns.google/resolve?name=$domain&type=A" 2>/dev/null | \
            grep -o '"data":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            method="DNS over HTTPS"
        else
            ip=""
        fi
    fi
    
    if [[ -n "$ip" ]]; then
        log_debug "Domain resolved using $method: $domain -> $ip"
        echo "$ip"
    else
        log_warning "Could not resolve domain: $domain"
        return 1
    fi
}

# Enhanced whois with better parsing and error handling
get_domain_info() {
    local domain="$1"
    local clean_domain
    
    # Remove www. for whois queries
    clean_domain=$(echo "$domain" | sed 's/^www\.//')
    
    log_debug "Getting whois info for: $clean_domain"
    
    if ! command -v whois >/dev/null 2>&1; then
        echo "=== Domain Information (Web API) ==="
        
        # Fallback using web API for whois-like info
        local whois_api_data=$(timeout 10 curl -s "https://api.whoisjson.com/v1/$clean_domain" 2>/dev/null)
        
        if [[ -n "$whois_api_data" ]] && command -v jq >/dev/null 2>&1; then
            local registrar=$(echo "$whois_api_data" | jq -r '.registrar // "N/A"' 2>/dev/null)
            local creation=$(echo "$whois_api_data" | jq -r '.creation_date // "N/A"' 2>/dev/null)
            local expiry=$(echo "$whois_api_data" | jq -r '.expiration_date // "N/A"' 2>/dev/null)
            local status=$(echo "$whois_api_data" | jq -r '.status // "N/A"' 2>/dev/null)
            
            echo "Registrar: $registrar"
            echo "Creation Date: $creation"
            echo "Expiration Date: $expiry"
            echo "Status: $status"
        else
            echo "Registrar: Limited access (install whois for full info)"
            echo "Creation Date: N/A"
            echo "Expiration Date: N/A"
            echo "Status: N/A"
        fi
        return 0
    fi
    
    local whois_data
    local retry=0
    
    while [[ $retry -lt $MAX_RETRIES ]]; do
        whois_data=$(timeout "$TIMEOUT_WHOIS" whois "$clean_domain" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$whois_data" ]]; then
            break
        fi
        
        retry=$((retry + 1))
        log_debug "Whois attempt $retry failed, retrying..."
        sleep 2
    done
    
    if [[ -z "$whois_data" ]]; then
        echo -e "${YELLOW}Could not retrieve whois information (timeout or unavailable).${NC}"
        return 1
    fi
    
    # Enhanced parsing with multiple patterns
    local registrar=$(echo "$whois_data" | grep -iE "registrar:|registrar name:|sponsoring registrar:" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    local creation=$(echo "$whois_data" | grep -iE "creation date:|created:|registered:|registration date:" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    local expiry=$(echo "$whois_data" | grep -iE "expir(y|ation)|expires|registry expiry:" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    local status=$(echo "$whois_data" | grep -iE "status:|domain status:" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    # Name servers
    local nameservers=$(echo "$whois_data" | grep -iE "name server:|nserver:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | tr '\n' ', ' | sed 's/, $//')
    
    echo "Registrar: ${registrar:-N/A}"
    echo "Creation Date: ${creation:-N/A}"
    echo "Expiration Date: ${expiry:-N/A}"
    echo "Status: ${status:-N/A}"
    [[ -n "$nameservers" ]] && echo "Name Servers: $nameservers"
}

# Improved JSON with proper escaping
json_escape() {
    local string="$1"
    echo "$string" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

# Enhanced technology detection helper functions
detect_server_tech() {
    local headers="$1"
    local -n tech_array=$2
    
    local server=$(echo "$headers" | grep -iE "^server:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    local powered_by=$(echo "$headers" | grep -iE "^x-powered-by:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    [[ -n "$server" ]] && tech_array+=("Web Server: $server")
    [[ -n "$powered_by" ]] && tech_array+=("Powered By: $powered_by")
}

detect_cms() {
    local body="$1"
    local -n tech_array=$2
    
    # WordPress with version detection
    if echo "$body" | grep -qiE "wp-content|wordpress|wp-includes"; then
        local wp_version=$(echo "$body" | grep -oE 'wp-content/[^"]*\?ver=([0-9.]+)' | head -1 | grep -oE '[0-9.]+$')
        if [[ -n "$wp_version" ]]; then
            tech_array+=("WordPress $wp_version")
        else
            tech_array+=("WordPress")
        fi
        
        # WordPress plugins detection
        local plugins=$(echo "$body" | grep -oE 'wp-content/plugins/[^/]+' | sed 's|wp-content/plugins/||' | sort -u | head -5)
        [[ -n "$plugins" ]] && tech_array+=("WordPress Plugins: $(echo "$plugins" | tr '\n' ', ' | sed 's/, $//')")
        return
    fi
    
    # Other CMS detection
    echo "$body" | grep -qiE "joomla|/components/com_" && tech_array+=("Joomla")
    echo "$body" | grep -qiE "drupal|/sites/default/files" && tech_array+=("Drupal")
    echo "$body" | grep -qiE "shopify" && tech_array+=("Shopify")
    echo "$body" | grep -qiE "wix\.com|wixstatic" && tech_array+=("Wix")
    echo "$body" | grep -qiE "squarespace" && tech_array+=("Squarespace")
}

detect_js_frameworks() {
    local body="$1"
    local -n tech_array=$2
    local js_frameworks=()
    
    echo "$body" | grep -qiE "react|_react|reactjs" && js_frameworks+=("React")
    echo "$body" | grep -qiE "vue\.js|vue/|vuejs" && js_frameworks+=("Vue.js")
    echo "$body" | grep -qiE "angular|ng-|angularjs" && js_frameworks+=("Angular")
    echo "$body" | grep -qiE "jquery|jquery-" && js_frameworks+=("jQuery")
    echo "$body" | grep -qiE "ember|emberjs" && js_frameworks+=("Ember.js")
    echo "$body" | grep -qiE "svelte" && js_frameworks+=("Svelte")
    echo "$body" | grep -qiE "next\.js|nextjs" && js_frameworks+=("Next.js")
    
    [[ ${#js_frameworks[@]} -gt 0 ]] && tech_array+=("JavaScript Frameworks: $(IFS=', '; echo "${js_frameworks[*]}")")
}

detect_security_tech() {
    local headers="$1"
    local -n tech_array=$2
    
    echo "$headers" | grep -qi "x-frame-options" && tech_array+=("Security: Frame protection enabled")
    echo "$headers" | grep -qi "strict-transport-security" && tech_array+=("Security: HSTS enabled")
    echo "$headers" | grep -qi "content-security-policy" && tech_array+=("Security: CSP enabled")
    echo "$headers" | grep -qi "x-content-type-options" && tech_array+=("Security: MIME type sniffing protection")
}

detect_cdn_services() {
    local headers="$1"
    local -n tech_array=$2
    
    if echo "$headers" | grep -qi "cloudflare\|cf-"; then
        tech_array+=("CDN: Cloudflare")
    elif echo "$headers" | grep -qi "x-served-by"; then
        tech_array+=("CDN: Fastly")
    elif echo "$headers" | grep -qi "x-amz"; then
        tech_array+=("CDN: Amazon CloudFront")
    elif echo "$headers" | grep -qi "x-azure"; then
        tech_array+=("CDN: Azure CDN")
    elif echo "$headers" | grep -qiE "x-cache|x-served-by"; then
        tech_array+=("CDN: Detected")
    fi
}

# Web hosting provider detection
detect_hosting_provider() {
    local domain="$1"
    local ip="$2"
    local headers="$3"
    local body="$4"
    local hosting_info=()
    
    echo -e "${GREEN}== Web Hosting Analysis ==${NC}"
    
    # Check headers for hosting-specific signatures
    if echo "$headers" | grep -qi "server.*apache"; then
        hosting_info+=("Web Server: Apache")
    elif echo "$headers" | grep -qi "server.*nginx"; then
        hosting_info+=("Web Server: Nginx")
    elif echo "$headers" | grep -qi "server.*iis"; then
        hosting_info+=("Web Server: Microsoft IIS")
    elif echo "$headers" | grep -qi "server.*lighttpd"; then
        hosting_info+=("Web Server: Lighttpd")
    fi
    
    # Hosting provider detection based on headers and patterns
    if echo "$headers" | grep -qi "cloudflare"; then
        hosting_info+=("Hosting: Using Cloudflare services")
    elif echo "$headers" | grep -qi "amazonaws"; then
        hosting_info+=("Hosting: Amazon Web Services (AWS)")
    elif echo "$headers" | grep -qi "googlecloud\|gcp"; then
        hosting_info+=("Hosting: Google Cloud Platform")
    elif echo "$headers" | grep -qi "azure"; then
        hosting_info+=("Hosting: Microsoft Azure")
    elif echo "$headers" | grep -qi "digitalocean"; then
        hosting_info+=("Hosting: DigitalOcean")
    elif echo "$headers" | grep -qi "linode"; then
        hosting_info+=("Hosting: Linode")
    elif echo "$headers" | grep -qi "vultr"; then
        hosting_info+=("Hosting: Vultr")
    elif echo "$headers" | grep -qi "hetzner"; then
        hosting_info+=("Hosting: Hetzner")
    elif echo "$headers" | grep -qi "ovh"; then
        hosting_info+=("Hosting: OVH")
    fi
    
    # Check for specific hosting control panels
    if echo "$body" | grep -qi "cpanel"; then
        hosting_info+=("Control Panel: cPanel")
    elif echo "$body" | grep -qi "plesk"; then
        hosting_info+=("Control Panel: Plesk")
    elif echo "$body" | grep -qi "directadmin"; then
        hosting_info+=("Control Panel: DirectAdmin")
    fi
    
    # Check for shared hosting indicators
    if echo "$headers" | grep -qi "x-powered-by.*shared"; then
        hosting_info+=("Hosting Type: Shared Hosting")
    elif echo "$headers" | grep -qi "x-vps\|x-dedicated"; then
        hosting_info+=("Hosting Type: VPS/Dedicated")
    fi
    
    # ASN and ISP lookup for hosting provider detection
    local asn_info=""
    if command -v whois >/dev/null 2>&1 && [[ -n "$ip" ]]; then
        asn_info=$(timeout 10 whois "$ip" 2>/dev/null | grep -iE "orgname|netname|descr" | head -3)
        if [[ -n "$asn_info" ]]; then
            local org_name=$(echo "$asn_info" | grep -iE "orgname|netname" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
            [[ -n "$org_name" ]] && hosting_info+=("ISP/Hosting: $org_name")
        fi
    fi
    
    # Check for popular hosting providers by IP ranges (simplified)
    if [[ -n "$ip" ]]; then
        case "$ip" in
            104.21.*|172.67.*|104.16.*) hosting_info+=("Hosting: Cloudflare") ;;
            54.*|52.*|34.*|3.*) hosting_info+=("Hosting: Amazon AWS (likely)") ;;
            35.*|104.154.*|130.211.*) hosting_info+=("Hosting: Google Cloud (likely)") ;;
            40.*|52.*|13.*|20.*) hosting_info+=("Hosting: Microsoft Azure (likely)") ;;
            68.183.*|167.71.*|164.90.*) hosting_info+=("Hosting: DigitalOcean (likely)") ;;
        esac
    fi
    
    # Display hosting information
    if [[ ${#hosting_info[@]} -gt 0 ]]; then
        printf '%s\n' "${hosting_info[@]}"
    else
        echo "Hosting provider could not be determined"
    fi
    
    # Performance characteristics
    echo
    echo "Performance Characteristics:"
    
    # Check for HTTP/2 support
    if echo "$headers" | grep -qi "http/2"; then
        echo "✅ HTTP/2 supported"
    else
        echo "❌ HTTP/2 not detected"
    fi
    
    # Check for compression
    if echo "$headers" | grep -qi "content-encoding.*gzip"; then
        echo "✅ Gzip compression enabled"
    elif echo "$headers" | grep -qi "content-encoding.*br"; then
        echo "✅ Brotli compression enabled"
    else
        echo "❌ No compression detected"
    fi
    
    # Check for caching headers
    if echo "$headers" | grep -qi "cache-control\|expires\|etag"; then
        echo "✅ Caching headers present"
    else
        echo "❌ No caching headers detected"
    fi
    
    echo
}

# Performance testing and benchmarking
run_performance_tests() {
    local url="$1"
    local domain="$2"
    
    echo -e "${GREEN}== Performance Testing ==${NC}"
    
    # Test multiple requests to get average response time
    echo "Running performance tests..."
    local total_time=0
    local successful_requests=0
    local failed_requests=0
    local min_time=999999
    local max_time=0
    
    for i in {1..5}; do
        echo -n "Test $i/5: "
        
        start_benchmark "http_request_$i"
        local response_time=$(timeout 30 curl -s -o /dev/null -w "%{time_total}" \
            -H "User-Agent: $USER_AGENT" \
            --connect-timeout 10 \
            "$url" 2>/dev/null)
        end_benchmark "http_request_$i"
        
        if [[ $? -eq 0 && -n "$response_time" ]]; then
            echo "${response_time}s"
            total_time=$(echo "$total_time + $response_time" | bc -l 2>/dev/null || echo "$total_time")
            successful_requests=$((successful_requests + 1))
            
            # Update min/max times
            if (( $(echo "$response_time < $min_time" | bc -l 2>/dev/null || echo 0) )); then
                min_time="$response_time"
            fi
            if (( $(echo "$response_time > $max_time" | bc -l 2>/dev/null || echo 0) )); then
                max_time="$response_time"
            fi
        else
            echo "Failed"
            failed_requests=$((failed_requests + 1))
        fi
        
        sleep 1  # Brief pause between requests
    done
    
    echo
    echo "Performance Summary:"
    
    if [[ $successful_requests -gt 0 ]]; then
        local avg_time=$(echo "scale=3; $total_time / $successful_requests" | bc -l 2>/dev/null || echo "0")
        printf "  %-20s: %8.3fs\n" "Average Response" "$avg_time"
        printf "  %-20s: %8.3fs\n" "Fastest Response" "$min_time"
        printf "  %-20s: %8.3fs\n" "Slowest Response" "$max_time"
        printf "  %-20s: %8d\n" "Successful Requests" "$successful_requests"
        printf "  %-20s: %8d\n" "Failed Requests" "$failed_requests"
        
        # Performance rating
        local rating="Unknown"
        if (( $(echo "$avg_time < 0.5" | bc -l 2>/dev/null || echo 0) )); then
            rating="Excellent"
        elif (( $(echo "$avg_time < 1.0" | bc -l 2>/dev/null || echo 0) )); then
            rating="Good"
        elif (( $(echo "$avg_time < 2.0" | bc -l 2>/dev/null || echo 0) )); then
            rating="Average"
        elif (( $(echo "$avg_time < 5.0" | bc -l 2>/dev/null || echo 0) )); then
            rating="Slow"
        else
            rating="Very Slow"
        fi
        
        printf "  %-20s: %8s\n" "Performance Rating" "$rating"
    else
        echo "  All requests failed - website may be down"
    fi
    
    echo
    
    # DNS resolution performance
    echo "DNS Resolution Performance:"
    start_benchmark "dns_resolution_test"
    
    local dns_times=()
    for i in {1..3}; do
        local dns_start=$(date +%s.%N)
        resolve_domain "$domain" >/dev/null 2>&1
        local dns_end=$(date +%s.%N)
        local dns_time=$(echo "$dns_end - $dns_start" | bc -l 2>/dev/null || echo "0")
        dns_times+=("$dns_time")
    done
    
    end_benchmark "dns_resolution_test"
    
    # Calculate DNS averages
    local dns_total=0
    for time in "${dns_times[@]}"; do
        dns_total=$(echo "$dns_total + $time" | bc -l 2>/dev/null || echo "$dns_total")
    done
    local dns_avg=$(echo "scale=3; $dns_total / ${#dns_times[@]}" | bc -l 2>/dev/null || echo "0")
    
    printf "  %-20s: %8.3fs\n" "Average DNS Time" "$dns_avg"
    
    # SSL handshake performance (if HTTPS)
    if [[ "$url" =~ ^https ]]; then
        echo
        echo "SSL Handshake Performance:"
        start_benchmark "ssl_handshake_test"
        
        local ssl_time=$(timeout 15 curl -s -o /dev/null -w "%{time_appconnect}" \
            -H "User-Agent: $USER_AGENT" \
            "$url" 2>/dev/null)
        
        end_benchmark "ssl_handshake_test"
        
        if [[ -n "$ssl_time" && "$ssl_time" != "0.000000" ]]; then
            printf "  %-20s: %8.3fs\n" "SSL Handshake Time" "$ssl_time"
        else
            echo "  SSL handshake time: Could not measure"
        fi
    fi
    
    echo
}

# More comprehensive technology detection
detect_technologies_advanced() {
    local url="$1"
    local technologies=()
    
    # Get headers and body content
    local headers=$(get_headers "$url")
    local body=$(get_body_content "$url")
    
    # Server technologies
    detect_server_tech "$headers" technologies
    
    # CMS detection with version
    detect_cms "$body" technologies
    
    # JavaScript frameworks with versions
    detect_js_frameworks "$body" technologies
    
    # Security technologies
    detect_security_tech "$headers" technologies
    
    # CDN and performance services
    detect_cdn_services "$headers" technologies
    
    # Additional technologies
    echo "$body" | grep -qiE "google-analytics|gtag|ga\(" && technologies+=("Analytics: Google Analytics")
    echo "$body" | grep -qiE "bootstrapcdn|bootstrap" && technologies+=("CSS Framework: Bootstrap")
    
    # Display results
    printf '%s\n' "${technologies[@]}"
}

get_headers() {
    local url="$1"
    local retry=0
    
    while [[ $retry -lt $MAX_RETRIES ]]; do
        local headers=$(timeout "$TIMEOUT_HTTP" curl -s -L -I \
            -H "User-Agent: $USER_AGENT" \
            -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
            --max-redirs "$MAX_REDIRECTS" \
            --fail-with-body \
            --proto '=http,https' \
            "$url" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$headers" ]]; then
            echo "$headers"
            return 0
        fi
        
        retry=$((retry + 1))
        log_debug "Headers request attempt $retry failed, retrying..."
        sleep 2
    done
    
    return 1
}

get_body_content() {
    local url="$1"
    local retry=0
    
    while [[ $retry -lt $MAX_RETRIES ]]; do
        local body=$(timeout "$TIMEOUT_HTTP" curl -s -L \
            -H "User-Agent: $USER_AGENT" \
            -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
            --max-redirs "$MAX_REDIRECTS" \
            --max-filesize 1048576 \
            --fail-with-body \
            --proto '=http,https' \
            "$url" 2>/dev/null | head -200)
        
        if [[ $? -eq 0 ]]; then
            # Sanitize body content to prevent injection
            echo "$body" | tr -d '\0' | head -200
            return 0
        fi
        
        retry=$((retry + 1))
        log_debug "Body request attempt $retry failed, retrying..."
        sleep 2
    done
    
    return 1
}

# Enhanced technology detection with more patterns and security improvements
get_web_technologies() {
    local url="$1"
    local headers=""
    local body=""
    local retry=0
    
    # Input validation
    if [[ ! "$url" =~ ^https?://[a-zA-Z0-9.-]+(/.*)?$ ]]; then
        log_error "Invalid URL format for technology detection"
        return 1
    fi
    
    echo "=== Detected Technologies ==="
    
    # Get headers with retry logic and improved security
    while [[ $retry -lt $MAX_RETRIES ]]; do
        headers=$(timeout "$TIMEOUT_HTTP" curl -s -L -I \
            -H "User-Agent: $USER_AGENT" \
            -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
            --max-redirs 5 \
            --fail-with-body \
            --proto '=http,https' \
            "$url" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$headers" ]]; then
            break
        fi
        
        retry=$((retry + 1))
        log_debug "Headers request attempt $retry failed, retrying..."
        sleep 2
    done
    
    # Get body content (first 200 lines for better detection, but limit size)
    retry=0
    while [[ $retry -lt $MAX_RETRIES ]]; do
        body=$(timeout "$TIMEOUT_HTTP" curl -s -L \
            -H "User-Agent: $USER_AGENT" \
            -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
            --max-redirs 5 \
            --max-filesize 1048576 \
            --fail-with-body \
            --proto '=http,https' \
            "$url" 2>/dev/null | head -200)
        
        if [[ $? -eq 0 ]]; then
            break
        fi
        
        retry=$((retry + 1))
        log_debug "Body request attempt $retry failed, retrying..."
        sleep 2
    done
    
    # Sanitize body content to prevent injection
    body=$(printf '%s\n' "$body" | tr -d '\0' | head -200)
    
    # Server detection
    local server=$(echo "$headers" | grep -iE "^server:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    local powered_by=$(echo "$headers" | grep -iE "^x-powered-by:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    echo "Web Server: ${server:-N/A}"
    [[ -n "$powered_by" ]] && echo "Powered By: $powered_by"
    
    # Enhanced CMS detection with better patterns
    if echo "$body" | grep -qiE "wp-content|wordpress|wp-includes"; then
        echo "CMS: WordPress"
        # Try to detect version more safely
        local wp_version=$(echo "$body" | grep -oE "wp-content/[^\"']*\?ver=[0-9.]+" | head -1 | grep -oE "[0-9.]+$" | head -1)
        [[ -n "$wp_version" && ${#wp_version} -lt 10 ]] && echo "WordPress Version: $wp_version"
        
        # Check for common WordPress security headers
        if echo "$headers" | grep -qi "x-frame-options"; then
            echo "WordPress Security: Frame protection enabled"
        fi
    elif echo "$body" | grep -qiE "joomla|/components/com_"; then
        echo "CMS: Joomla"
    elif echo "$body" | grep -qiE "drupal|/sites/default/files"; then
        echo "CMS: Drupal"
    elif echo "$body" | grep -qiE "shopify"; then
        echo "Platform: Shopify"
    elif echo "$body" | grep -qiE "wix\.com|wixstatic"; then
        echo "Platform: Wix"
    elif echo "$body" | grep -qiE "squarespace"; then
        echo "Platform: Squarespace"
    fi
    
    # Enhanced JavaScript frameworks detection
    local js_frameworks=()
    echo "$body" | grep -qiE "react|_react|reactjs" && js_frameworks+=("React")
    echo "$body" | grep -qiE "vue\.js|vue/|vuejs" && js_frameworks+=("Vue.js")
    echo "$body" | grep -qiE "angular|ng-|angularjs" && js_frameworks+=("Angular")
    echo "$body" | grep -qiE "jquery|jquery-" && js_frameworks+=("jQuery")
    echo "$body" | grep -qiE "ember|emberjs" && js_frameworks+=("Ember.js")
    echo "$body" | grep -qiE "svelte" && js_frameworks+=("Svelte")
    echo "$body" | grep -qiE "next\.js|nextjs" && js_frameworks+=("Next.js")
    
    [[ ${#js_frameworks[@]} -gt 0 ]] && echo "JavaScript Frameworks: $(IFS=', '; echo "${js_frameworks[*]}")"
    
    # CDN detection
    local cdn_headers=$(echo "$headers" | grep -iE "cf-|cloudflare|x-served-by|x-cache|x-amz-|x-azure")
    if [[ -n "$cdn_headers" ]]; then
        if echo "$cdn_headers" | grep -qi "cloudflare\|cf-"; then
            echo "CDN: Cloudflare"
        elif echo "$cdn_headers" | grep -qi "x-served-by"; then
            echo "CDN: Fastly"
        elif echo "$cdn_headers" | grep -qi "x-amz"; then
            echo "CDN: Amazon CloudFront"
        elif echo "$cdn_headers" | grep -qi "x-azure"; then
            echo "CDN: Azure CDN"
        else
            echo "CDN: Detected"
        fi
    fi
    
    # Additional technologies
    if echo "$body" | grep -qiE "google-analytics|gtag|ga\("; then
        echo "Analytics: Google Analytics"
    fi
    
    if echo "$body" | grep -qiE "bootstrapcdn|bootstrap"; then
        echo "CSS Framework: Bootstrap"
    fi
}

# Enhanced connectivity check with better error handling
check_connectivity() {
    local url="$1"
    local response=""
    local final_url=""
    local http_code=""
    local retry=0
    
    log_debug "Checking connectivity for: $url"
    
    while [[ $retry -lt $MAX_RETRIES ]]; do
        response=$(timeout "$TIMEOUT_HTTP" curl -Ls \
            -H "User-Agent: $USER_AGENT" \
            --max-time "$TIMEOUT_HTTP" \
            --max-redirs 10 \
            -o /dev/null \
            -w "%{url_effective} %{http_code} %{time_total}" \
            "$url" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            final_url=$(echo "$response" | awk '{print $1}')
            http_code=$(echo "$response" | awk '{print $2}')
            local time_total=$(echo "$response" | awk '{print $3}')
            
            log_debug "HTTP response: $http_code (${time_total}s)"
            
            if [[ "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
                if [[ "$final_url" != "$url" ]]; then
                    log_section "Redirected to $final_url"
                    URL="$final_url"
                    DOMAIN=$(extract_domain "$final_url")
                fi
                return 0
            fi
        fi
        
        retry=$((retry + 1))
        log_debug "Connectivity check attempt $retry failed, retrying..."
        sleep 2
    done
    
    # Try HTTP if HTTPS failed
    if [[ "$url" == https://* ]]; then
        local fallback_url=$(echo "$url" | sed 's/^https:/http:/')
        log_warning "HTTPS failed, trying HTTP fallback..."
        
        retry=0
        while [[ $retry -lt $MAX_RETRIES ]]; do
            response=$(timeout "$TIMEOUT_HTTP" curl -Ls \
                -H "User-Agent: $USER_AGENT" \
                --max-time "$TIMEOUT_HTTP" \
                --max-redirs 10 \
                -o /dev/null \
                -w "%{url_effective} %{http_code}" \
                "$fallback_url" 2>/dev/null)
            
            if [[ $? -eq 0 ]]; then
                final_url=$(echo "$response" | awk '{print $1}')
                http_code=$(echo "$response" | awk '{print $2}')
                
                if [[ "$http_code" -ge 200 && "$http_code" -lt 400 ]]; then
                    log_section "HTTP fallback succeeded: $final_url"
                    URL="$final_url"
                    DOMAIN=$(extract_domain "$final_url")
                    return 0
                fi
            fi
            
            retry=$((retry + 1))
            sleep 2
        done
    fi
    
    log_error "Cannot access $url (HTTP code: ${http_code:-000})"
    return 1
}

# Advanced dig query function with comprehensive options
perform_dig_query() {
    local domain="$1"
    local record_type="$2"
    local dns_server="${3:-}"
    local result=""
    
    # Validate inputs
    [[ -z "$domain" || -z "$record_type" ]] && return 1
    
    # DNS servers to try in order of preference
    local dns_servers=("" "8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222")
    
    # If specific DNS server provided, use it first
    if [[ -n "$dns_server" ]]; then
        dns_servers=("$dns_server" "${dns_servers[@]}")
    fi
    
    # Record type specific optimizations
    local dig_opts="+short +time=3 +tries=2"
    case "$record_type" in
        "MX") dig_opts="+short +time=4 +tries=2" ;;
        "NS") dig_opts="+short +time=3 +tries=2 +norecurse" ;;
        "TXT") dig_opts="+short +time=5 +tries=2" ;;
        "SOA") dig_opts="+noall +answer +time=3 +tries=2" ;;
        "ANY") dig_opts="+noall +answer +time=6 +tries=1" ;;
    esac
    
    # Try each DNS server
    for server in "${dns_servers[@]}"; do
        local server_opt=""
        [[ -n "$server" ]] && server_opt="@$server"
        
        log_debug "Trying dig $server_opt $dig_opts $record_type $domain"
        
        result=$(timeout "$TIMEOUT_DNS" dig $server_opt $dig_opts "$record_type" "$domain" 2>/dev/null)
        
        # Check if we got a valid result
        if [[ $? -eq 0 && -n "$result" && "$result" != ";;" ]]; then
            log_debug "dig query successful with ${server:-system} DNS"
            echo "$result"
            return 0
        fi
        
        # Small delay between attempts
        sleep 0.5
    done
    
    log_debug "All dig attempts failed for $record_type $domain"
    return 1
}

# Enhanced dig diagnostic function
advanced_dig_diagnostic() {
    local domain="$1"
    
    echo -e "${MAGENTA}== Advanced DNS Diagnostic for $domain ==${NC}"
    
    if ! command -v dig >/dev/null 2>&1; then
        echo -e "${RED}dig command not available${NC}"
        return 1
    fi
    
    echo "Testing comprehensive dig functionality:"
    
    # Test 1: Basic connectivity to domain
    echo -n "1. Basic dig A record: "
    local test1=$(perform_dig_query "$domain" "A")
    if [[ -n "$test1" ]]; then
        echo -e "${GREEN}SUCCESS${NC} - $test1"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Test 2: SOA record (Start of Authority)
    echo -n "2. SOA record query: "
    local test2=$(perform_dig_query "$domain" "SOA")
    if [[ -n "$test2" ]]; then
        echo -e "${GREEN}SUCCESS${NC}"
        echo "   SOA: $test2"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Test 3: Reverse DNS lookup if we have an IP
    if [[ -n "$IP" ]]; then
        echo -n "3. Reverse DNS lookup: "
        local test3=$(timeout "$TIMEOUT_DNS" dig +short -x "$IP" 2>/dev/null)
        if [[ -n "$test3" ]]; then
            echo -e "${GREEN}SUCCESS${NC} - $test3"
        else
            echo -e "${YELLOW}NO PTR RECORD${NC}"
        fi
    fi
    
    # Test 4: DNSSEC validation
    echo -n "4. DNSSEC validation: "
    local test4=$(timeout "$TIMEOUT_DNS" dig +dnssec +short A "$domain" 2>/dev/null | grep -i rrsig)
    if [[ -n "$test4" ]]; then
        echo -e "${GREEN}DNSSEC ENABLED${NC}"
    else
        echo -e "${YELLOW}DNSSEC NOT DETECTED${NC}"
    fi
    
    # Test 5: Trace DNS resolution path
    if [[ "$DEBUG" == "1" ]]; then
        echo -n "5. DNS trace (debug): "
        local test5=$(timeout 15 dig +trace +short A "$domain" 2>/dev/null | tail -3)
        if [[ -n "$test5" ]]; then
            echo -e "${GREEN}SUCCESS${NC}"
            echo "   Trace result: $test5"
        else
            echo -e "${YELLOW}TRACE FAILED${NC}"
        fi
    fi
    
    echo
}

# DNS diagnostic function for troubleshooting
dns_diagnostic() {
    local domain="$1"
    
    echo -e "${MAGENTA}== DNS Diagnostic for $domain ==${NC}"
    
    if ! command -v dig >/dev/null 2>&1; then
        echo -e "${RED}dig command not available - install with: sudo apt install dnsutils${NC}"
        return 1
    fi
    
    echo "Testing different DNS query methods:"
    
    # Test 1: Basic dig with system DNS
    echo -n "1. System DNS A record: "
    local test1=$(perform_dig_query "$domain" "A")
    if [[ -n "$test1" ]]; then
        echo -e "${GREEN}SUCCESS${NC} - $test1"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Test 2: Google DNS
    echo -n "2. Google DNS (8.8.8.8): "
    local test2=$(perform_dig_query "$domain" "A" "8.8.8.8")
    if [[ -n "$test2" ]]; then
        echo -e "${GREEN}SUCCESS${NC} - $test2"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Test 3: Cloudflare DNS
    echo -n "3. Cloudflare DNS (1.1.1.1): "
    local test3=$(perform_dig_query "$domain" "A" "1.1.1.1")
    if [[ -n "$test3" ]]; then
        echo -e "${GREEN}SUCCESS${NC} - $test3"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Test 4: Quad9 DNS
    echo -n "4. Quad9 DNS (9.9.9.9): "
    local test4=$(perform_dig_query "$domain" "A" "9.9.9.9")
    if [[ -n "$test4" ]]; then
        echo -e "${GREEN}SUCCESS${NC} - $test4"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Test 5: MX records
    echo -n "5. MX records: "
    local test5=$(perform_dig_query "$domain" "MX")
    if [[ -n "$test5" ]]; then
        echo -e "${GREEN}SUCCESS${NC} - $test5"
    else
        echo -e "${YELLOW}NO MX RECORDS${NC}"
    fi
    
    # Test 6: Check dig version and capabilities
    echo -n "6. dig version: "
    local dig_version=$(dig -v 2>&1 | head -1)
    echo -e "${CYAN}$dig_version${NC}"
    
    # Test current system DNS configuration
    echo -n "7. System DNS config: "
    if [[ -f /etc/resolv.conf ]]; then
        local nameservers=$(grep "^nameserver" /etc/resolv.conf | head -2 | tr '\n' ' ')
        echo -e "${CYAN}$nameservers${NC}"
    else
        echo -e "${YELLOW}No /etc/resolv.conf found${NC}"
    fi
    
    # Run advanced diagnostic if debug enabled
    if [[ "$DEBUG" == "1" ]]; then
        advanced_dig_diagnostic "$domain"
    fi
    
    echo
}

# Parallel DNS queries for better performance
get_dns_info_parallel() {
    local domain="$1"
    
    echo -e "${GREEN}== DNS Information (Parallel) ==${NC}"
    
    # Create temporary files for parallel execution
    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" RETURN
    
    # Start parallel queries
    show_progress 1 6 "Starting DNS queries..."
    {
        perform_dig_query "$domain" "A" > "$temp_dir/a_records" &
        show_progress 2 6 "Querying A records..."
        perform_dig_query "$domain" "AAAA" > "$temp_dir/aaaa_records" &
        show_progress 3 6 "Querying AAAA records..."
        perform_dig_query "$domain" "MX" > "$temp_dir/mx_records" &
        show_progress 4 6 "Querying MX records..."
        perform_dig_query "$domain" "NS" > "$temp_dir/ns_records" &
        show_progress 5 6 "Querying NS records..."
        perform_dig_query "$domain" "TXT" > "$temp_dir/txt_records" &
        show_progress 6 6 "Querying TXT records..."
        wait
    }
    
    # Display results
    echo
    echo "A records:"
    if [[ -s "$temp_dir/a_records" ]]; then
        cat "$temp_dir/a_records"
    else
        echo "No A records found"
    fi
    echo
    
    echo "AAAA records (IPv6):"
    if [[ -s "$temp_dir/aaaa_records" ]]; then
        cat "$temp_dir/aaaa_records"
    else
        echo "No AAAA records found"
    fi
    echo
    
    echo "MX records:"
    if [[ -s "$temp_dir/mx_records" ]]; then
        cat "$temp_dir/mx_records"
        MX_RECORDS=$(cat "$temp_dir/mx_records" | tr '\n' ' ')
    else
        echo "No MX records found"
        MX_RECORDS=""
    fi
    echo
    
    echo "NS records:"
    if [[ -s "$temp_dir/ns_records" ]]; then
        cat "$temp_dir/ns_records"
        NS_RECORDS=$(cat "$temp_dir/ns_records" | tr '\n' ' ')
    else
        echo "No NS records found"
        NS_RECORDS=""
    fi
    echo
    
    echo "TXT records:"
    if [[ -s "$temp_dir/txt_records" ]]; then
        cat "$temp_dir/txt_records"
        TXT_RECORDS=$(cat "$temp_dir/txt_records" | tr '\n' ' ')
    else
        echo "No TXT records found"
        TXT_RECORDS=""
    fi
    echo
}

# Enhanced DNS information gathering with improved dig integration
get_dns_info() {
    local domain="$1"
    
    echo -e "${GREEN}== DNS Information ==${NC}"
    
    # Check dig availability and version
    if command -v dig >/dev/null 2>&1; then
        local dig_version=$(dig -v 2>&1 | head -1)
        log_debug "Using dig: $dig_version"
        echo "DNS Tool: dig (preferred method)"
    else
        echo "DNS Tool: Web API fallback (dig not available)"
        log_warning "Install dig for better DNS resolution: sudo apt install dnsutils"
    fi
    echo
    
    # Run diagnostic if debug mode is enabled
    if [[ "$DEBUG" == "1" ]]; then
        dns_diagnostic "$domain"
    fi
    
    # Check if we have dig or need to use web API fallback
    local use_web_api=false
    if ! command -v dig >/dev/null 2>&1; then
        use_web_api=true
        echo "Using web API for DNS queries (dig not available)"
    fi
    
    # A records with enhanced error handling and multiple dig methods
    echo "A records:"
    local a_records=""
    
    if [[ "$use_web_api" == "true" ]]; then
        # Web API fallback for A records
        a_records=$(timeout 10 curl -s "https://dns.google/resolve?name=$domain&type=A" 2>/dev/null | \
            jq -r '.Answer[]? | select(.type==1) | .data' 2>/dev/null | head -5)
    else
        # Enhanced dig methods with multiple fallbacks
        # Method 1: Standard dig with optimal settings
        a_records=$(timeout "$TIMEOUT_DNS" dig +short +time=3 +tries=2 +norecurse A "$domain" 2>/dev/null)
        
        # Method 2: If first fails, try with different parameters
        if [[ -z "$a_records" ]]; then
            log_debug "Retrying A record query with extended timeout"
            a_records=$(timeout $((TIMEOUT_DNS + 2)) dig +short +time=5 +tries=3 A "$domain" 2>/dev/null)
        fi
        
        # Method 3: Try with Google DNS (8.8.8.8)
        if [[ -z "$a_records" ]]; then
            log_debug "Trying A record query with Google DNS"
            a_records=$(timeout "$TIMEOUT_DNS" dig @8.8.8.8 +short +time=3 +tries=2 A "$domain" 2>/dev/null)
        fi
        
        # Method 4: Try with Cloudflare DNS (1.1.1.1)
        if [[ -z "$a_records" ]]; then
            log_debug "Trying A record query with Cloudflare DNS"
            a_records=$(timeout "$TIMEOUT_DNS" dig @1.1.1.1 +short +time=3 +tries=2 A "$domain" 2>/dev/null)
        fi
        
        # Method 5: Try with Quad9 DNS (9.9.9.9)
        if [[ -z "$a_records" ]]; then
            log_debug "Trying A record query with Quad9 DNS"
            a_records=$(timeout "$TIMEOUT_DNS" dig @9.9.9.9 +short +time=3 +tries=2 A "$domain" 2>/dev/null)
        fi
    fi
    
    log_debug "A query result for $domain: '$a_records'"
    
    if [[ -n "$a_records" ]]; then
        echo "$a_records"
    else
        echo "No A records found"
    fi
    echo
    
    # AAAA records (IPv6)
    echo "AAAA records (IPv6):"
    local aaaa_records=""
    
    if [[ "$use_web_api" == "true" ]]; then
        # Web API fallback for AAAA records
        aaaa_records=$(timeout 10 curl -s "https://dns.google/resolve?name=$domain&type=AAAA" 2>/dev/null | \
            jq -r '.Answer[]? | select(.type==28) | .data' 2>/dev/null | head -5)
    else
        aaaa_records=$(timeout "$TIMEOUT_DNS" dig +short +time=3 +tries=2 AAAA "$domain" 2>/dev/null)
    fi
    
    if [[ -n "$aaaa_records" ]]; then
        echo "$aaaa_records"
    else
        echo "No AAAA records found"
    fi
    echo
    
    # MX records with enhanced error handling and multiple dig strategies
    echo "MX records:"
    local mx_records=""
    
    if [[ "$use_web_api" == "true" ]]; then
        # Web API fallback for MX records
        mx_records=$(timeout 10 curl -s "https://dns.google/resolve?name=$domain&type=MX" 2>/dev/null | \
            jq -r '.Answer[]? | select(.type==15) | .data' 2>/dev/null)
    else
        # Enhanced dig methods for MX records with multiple DNS servers
        # Method 1: Standard dig with optimal settings
        mx_records=$(timeout "$TIMEOUT_DNS" dig +short +time=3 +tries=2 MX "$domain" 2>/dev/null)
        
        # Method 2: If first fails, try with different parameters
        if [[ -z "$mx_records" ]]; then
            log_debug "Retrying MX query with extended timeout"
            mx_records=$(timeout $((TIMEOUT_DNS + 3)) dig +short +time=5 +tries=3 MX "$domain" 2>/dev/null)
        fi
        
        # Method 3: Try with Google DNS (8.8.8.8)
        if [[ -z "$mx_records" ]]; then
            log_debug "Trying MX query with Google DNS"
            mx_records=$(timeout "$TIMEOUT_DNS" dig @8.8.8.8 +short +time=4 +tries=2 MX "$domain" 2>/dev/null)
        fi
        
        # Method 4: Try with Cloudflare DNS (1.1.1.1)
        if [[ -z "$mx_records" ]]; then
            log_debug "Trying MX query with Cloudflare DNS"
            mx_records=$(timeout "$TIMEOUT_DNS" dig @1.1.1.1 +short +time=4 +tries=2 MX "$domain" 2>/dev/null)
        fi
        
        # Method 5: Try with authoritative DNS servers if we have NS records
        if [[ -z "$mx_records" && -n "$NS_RECORDS" ]]; then
            local first_ns=$(echo "$NS_RECORDS" | head -1 | sed 's/\.$//')
            if [[ -n "$first_ns" ]]; then
                log_debug "Trying MX query with authoritative NS: $first_ns"
                mx_records=$(timeout "$TIMEOUT_DNS" dig @"$first_ns" +short +time=4 +tries=2 MX "$domain" 2>/dev/null)
            fi
        fi
        
        # Method 6: Last resort with verbose output for debugging
        if [[ -z "$mx_records" && "$DEBUG" == "1" ]]; then
            log_debug "Final MX attempt with verbose output"
            mx_records=$(timeout "$TIMEOUT_DNS" dig +noall +answer +time=5 +tries=1 MX "$domain" 2>/dev/null | awk '{print $5 " " $6}')
        fi
    fi
    
    # Debug output
    log_debug "MX query result for $domain: '$mx_records'"
    
    if [[ -n "$mx_records" ]]; then
        echo "$mx_records"
        MX_RECORDS="$mx_records"
    else
        echo "No MX records found (Email may not be configured)"
        MX_RECORDS=""
    fi
    echo
    
    # NS records with enhanced error handling using perform_dig_query
    echo "NS servers:"
    local ns_records=""
    
    if [[ "$use_web_api" == "true" ]]; then
        # Web API fallback for NS records
        ns_records=$(timeout 10 curl -s "https://dns.google/resolve?name=$domain&type=NS" 2>/dev/null | \
            jq -r '.Answer[]? | select(.type==2) | .data' 2>/dev/null)
    else
        # Use enhanced dig function
        ns_records=$(perform_dig_query "$domain" "NS")
    fi
    
    log_debug "NS query result for $domain: '$ns_records'"
    
    if [[ -n "$ns_records" ]]; then
        echo "$ns_records"
        NS_RECORDS="$ns_records"
    else
        echo "No NS records found"
        NS_RECORDS=""
    fi
    echo
    
    # TXT records (SPF/DKIM/DMARC) with enhanced error handling using perform_dig_query
    echo "TXT records (SPF/DKIM/DMARC):"
    local txt_records=""
    
    if [[ "$use_web_api" == "true" ]]; then
        # Web API fallback for TXT records
        txt_records=$(timeout 10 curl -s "https://dns.google/resolve?name=$domain&type=TXT" 2>/dev/null | \
            jq -r '.Answer[]? | select(.type==16) | .data' 2>/dev/null)
    else
        # Use enhanced dig function
        txt_records=$(perform_dig_query "$domain" "TXT")
    fi
    
    log_debug "TXT query result for $domain: '$txt_records'"
    
    if [[ -n "$txt_records" ]]; then
        echo "$txt_records" | grep -iE "spf|dkim|dmarc" || echo "No email security records found in TXT records"
        TXT_RECORDS="$txt_records"
    else
        echo "No TXT records found"
        TXT_RECORDS=""
    fi
    echo
    
    # CNAME records for www using perform_dig_query
    echo "CNAME records for www.$domain:"
    local cname_records=""
    
    if [[ "$use_web_api" == "true" ]]; then
        # Web API fallback for CNAME records
        cname_records=$(timeout 10 curl -s "https://dns.google/resolve?name=www.$domain&type=CNAME" 2>/dev/null | \
            jq -r '.Answer[]? | select(.type==5) | .data' 2>/dev/null)
    else
        cname_records=$(perform_dig_query "www.$domain" "CNAME")
    fi
    
    if [[ -n "$cname_records" ]]; then
        echo "$cname_records"
    else
        echo "No CNAME records found for www.$domain"
    fi
    echo
    
    # Additional DNS records if debug mode is enabled
    if [[ "$DEBUG" == "1" ]]; then
        echo "=== Additional DNS Records (Debug Mode) ==="
        
        # SOA record
        echo "SOA record:"
        local soa_record=$(perform_dig_query "$domain" "SOA")
        if [[ -n "$soa_record" ]]; then
            echo "$soa_record"
        else
            echo "No SOA record found"
        fi
        echo
        
        # CAA records (Certificate Authority Authorization)
        echo "CAA records:"
        local caa_records=$(perform_dig_query "$domain" "CAA")
        if [[ -n "$caa_records" ]]; then
            echo "$caa_records"
        else
            echo "No CAA records found"
        fi
        echo
    fi
}

# Enhanced SSL certificate check
check_ssl_certificate() {
    local domain="$1"
    
    echo -e "${GREEN}== SSL Certificate ==${NC}"
    
    local ssl_info=$(timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -issuer -subject -dates -fingerprint 2>/dev/null)
    
    if [[ -n "$ssl_info" ]]; then
        echo "$ssl_info"
        echo -e "${GREEN}✔ SSL/TLS is properly configured${NC}"
        
        # Check certificate expiry
        local expiry_date=$(echo "$ssl_info" | grep "notAfter=" | cut -d= -f2-)
        if [[ -n "$expiry_date" ]]; then
            local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
            local current_epoch=$(date +%s)
            if [[ -n "$expiry_epoch" ]]; then
                local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                if [[ $days_left -lt 30 ]]; then
                    echo -e "${YELLOW}⚠ Certificate expires in $days_left days${NC}"
                else
                    echo -e "${GREEN}Certificate expires in $days_left days${NC}"
                fi
            fi
        fi
        
        # Check for mixed content
        if [[ "$URL" == https://* ]]; then
            local body=$(timeout "$TIMEOUT_HTTP" curl -s -L "$URL" 2>/dev/null | head -50)
            if echo "$body" | grep -q "http://"; then
                echo -e "${YELLOW}⚠ Possible mixed content detected${NC}"
            fi
        fi
    else
        echo -e "${RED}✘ No valid SSL certificate found${NC}"
        
        # Check if port 443 is open
        if timeout 5 nc -z "$domain" 443 2>/dev/null; then
            echo -e "${YELLOW}Port 443 is open but SSL handshake failed${NC}"
        else
            echo -e "${RED}Port 443 is not accessible${NC}"
        fi
    fi
    echo
}

# Enhanced geolocation with fallback
get_geolocation() {
    local ip="$1"
    
    if [[ -z "$ip" ]]; then
        echo "IP address not available"
        return 1
    fi
    
    echo -e "${GREEN}== Geolocation ==${NC}"
    
    # Method 1: ip-api.com
    local geo_info=$(timeout 10 curl -s "http://ip-api.com/json/$ip" 2>/dev/null)
    
    if [[ -n "$geo_info" ]] && echo "$geo_info" | grep -q "country"; then
        if command -v jq >/dev/null 2>&1; then
            local country=$(echo "$geo_info" | jq -r '.country // "N/A"')
            local region=$(echo "$geo_info" | jq -r '.regionName // "N/A"')
            local city=$(echo "$geo_info" | jq -r '.city // "N/A"')
            local isp=$(echo "$geo_info" | jq -r '.isp // "N/A"')
            local org=$(echo "$geo_info" | jq -r '.org // "N/A"')
            
            echo "Country: $country"
            echo "Region: $region"
            echo "City: $city"
            echo "ISP: $isp"
            [[ "$org" != "N/A" && "$org" != "$isp" ]] && echo "Organization: $org"
        else
            echo "$geo_info" | sed 's/[{}"]//g' | tr ',' '\n' | grep -E "country|regionName|city|isp"
        fi
    else
        # Fallback method
        local whois_geo=$(timeout 10 whois "$ip" 2>/dev/null | grep -iE "country|netname|descr" | head -3)
        if [[ -n "$whois_geo" ]]; then
            echo "$whois_geo"
        else
            echo "Geolocation information not available"
        fi
    fi
    echo
}

# Enhanced security headers check
check_security_headers() {
    local url="$1"
    
    echo -e "${GREEN}== Security Headers ==${NC}"
    
    local headers=$(timeout "$TIMEOUT_HTTP" curl -s -L -I \
        -H "User-Agent: $USER_AGENT" \
        --max-time "$TIMEOUT_HTTP" \
        "$url" 2>/dev/null)
    
    if [[ -z "$headers" ]]; then
        echo "Could not retrieve headers"
        return 1
    fi
    
    # Define security headers to check
    declare -A security_headers=(
        ["x-frame-options"]="Clickjacking protection"
        ["content-security-policy"]="Content Security Policy"
        ["strict-transport-security"]="HSTS"
        ["x-content-type-options"]="MIME type sniffing protection"
        ["x-xss-protection"]="XSS protection"
        ["referrer-policy"]="Referrer policy"
        ["permissions-policy"]="Permissions policy"
        ["x-powered-by"]="Server information disclosure"
    )
    
    local score=0
    local total_headers=7  # Excluding x-powered-by as it's a negative indicator
    
    for header in "${!security_headers[@]}"; do
        if echo "$headers" | grep -iq "^$header:"; then
            if [[ "$header" == "x-powered-by" ]]; then
                echo -e "${YELLOW}⚠ $header found: ${security_headers[$header]} (information disclosure)${NC}"
            else
                echo -e "${GREEN}✔ $header found: ${security_headers[$header]}${NC}"
                score=$((score + 1))
            fi
        else
            if [[ "$header" != "x-powered-by" ]]; then
                echo -e "${RED}✘ $header missing: ${security_headers[$header]}${NC}"
            fi
        fi
    done
    
    echo
    echo "Security Headers Score: $score/$total_headers"
    echo
}

# Enhanced port scan with better error handling
check_open_ports() {
    local domain="$1"
    
    echo -e "${GREEN}== Open Ports ==${NC}"
    
    if ! command -v nmap >/dev/null 2>&1; then
        echo "nmap not installed. Install with: sudo apt install nmap"
        
        # Fallback: check common ports with netcat
        echo "Checking common ports with netcat..."
        local common_ports=(80 443 21 22 25 53 110 143 993 995)
        
        for port in "${common_ports[@]}"; do
            if timeout 3 nc -z "$domain" "$port" 2>/dev/null; then
                echo -e "${GREEN}$port/tcp open${NC}"
            fi
        done
    else
        local ports=$(timeout 30 nmap -Pn -T4 --top-ports 1000 "$domain" 2>/dev/null | grep -E "^[0-9]+.*open" | head -10)
        
        if [[ -n "$ports" ]]; then
            echo "$ports"
        else
            echo "No open ports detected or host is filtered"
        fi
    fi
    echo
}

# Main report generation function
generate_terminal_report() {
    echo -e "${BLUE}=========================================="
    echo -e "         WEB AUDIT REPORT"
    echo -e "==========================================${NC}"
    echo -e "${CYAN}Domain:${NC} $DOMAIN"
    echo -e "${CYAN}URL:${NC} $URL"
    echo -e "${CYAN}Date:${NC} $TIMESTAMP"
    echo -e "${CYAN}IP:${NC} $IP"
    echo -e "${CYAN}Audit Tool:${NC} Enhanced Web Audit Script v2.0"
    echo

    echo -e "${GREEN}== Domain Information ==${NC}"
    get_domain_info "$DOMAIN"
    echo

    get_geolocation "$IP"
    
    echo -e "${GREEN}== HTTP Status ==${NC}"
    local http_status=$(timeout "$TIMEOUT_HTTP" curl -s -o /dev/null -w "%{http_code}" \
        -H "User-Agent: $USER_AGENT" \
        "$URL" 2>/dev/null)
    echo "Status Code: ${http_status:-N/A}"
    
    # Additional HTTP info
    local response_time=$(timeout "$TIMEOUT_HTTP" curl -s -o /dev/null -w "%{time_total}" \
        -H "User-Agent: $USER_AGENT" \
        "$URL" 2>/dev/null)
    [[ -n "$response_time" ]] && echo "Response Time: ${response_time}s"
    echo

    echo -e "${GREEN}== Web Technologies ==${NC}"
    start_benchmark "technology_detection"
    get_web_technologies "$URL"
    end_benchmark "technology_detection"
    echo

    start_benchmark "ssl_certificate_check"
    check_ssl_certificate "$DOMAIN"
    end_benchmark "ssl_certificate_check"
    
    start_benchmark "port_scanning"
    check_open_ports "$DOMAIN"
    end_benchmark "port_scanning"
    
    # Use parallel DNS queries for better performance
    start_benchmark "dns_analysis"
    if command -v dig >/dev/null 2>&1; then
        get_dns_info_parallel "$DOMAIN"
    else
        get_dns_info "$DOMAIN"
    fi
    end_benchmark "dns_analysis"

    # Show dig statistics if debug mode is enabled
    if [[ "$DEBUG" == "1" ]] && command -v dig >/dev/null 2>&1; then
        show_dig_stats "$DOMAIN"
    fi
    
    start_benchmark "security_headers_check"
    check_security_headers "$URL"
    end_benchmark "security_headers_check"
    
    # Add hosting provider detection
    start_benchmark "hosting_detection"
    local headers=$(get_headers "$URL")
    local body=$(get_body_content "$URL")
    detect_hosting_provider "$DOMAIN" "$IP" "$headers" "$body"
    end_benchmark "hosting_detection"
    
    # Add performance testing
    start_benchmark "performance_testing"
    run_performance_tests "$URL" "$DOMAIN"
    end_benchmark "performance_testing"
    
    # Show performance benchmarks
    show_performance_report

    echo -e "${GREEN}== Summary ==${NC}"
    local score=0
    local max_score=100
    
    # HTTP status (20 points)
    [[ "$http_status" == "200" ]] && score=$((score + 20))
    
    # Security headers (40 points total)
    local headers=$(timeout "$TIMEOUT_HTTP" curl -s -L -I "$URL" 2>/dev/null)
    [[ "$headers" =~ [Xx]-[Ff]rame-[Oo]ptions ]] && score=$((score + 10))
    [[ "$headers" =~ [Cc]ontent-[Ss]ecurity-[Pp]olicy ]] && score=$((score + 10))
    [[ "$headers" =~ [Ss]trict-[Tt]ransport-[Ss]ecurity ]] && score=$((score + 10))
    [[ "$headers" =~ [Xx]-[Cc]ontent-[Tt]ype-[Oo]ptions ]] && score=$((score + 10))
    
    # SSL certificate (20 points)
    if timeout 10 openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
        score=$((score + 20))
    fi
    
    # DNS configuration (20 points)
    [[ -n "$MX_RECORDS" ]] && score=$((score + 5))
    [[ -n "$NS_RECORDS" ]] && score=$((score + 5))
    [[ -n "$TXT_RECORDS" ]] && score=$((score + 5))
    [[ -n "$IP" ]] && score=$((score + 5))
    
    echo -e "Overall Security Score: $score/$max_score"
    
    if [[ $score -ge 80 ]]; then
        echo -e "${GREEN}✔ Excellent security posture${NC}"
    elif [[ $score -ge 60 ]]; then
        echo -e "${YELLOW}⚠ Good security, some improvements needed${NC}"
    elif [[ $score -ge 40 ]]; then
        echo -e "${YELLOW}⚠ Moderate security, several improvements needed${NC}"
    else
        echo -e "${RED}✘ Poor security posture, immediate attention required${NC}"
    fi
    echo
    
    echo -e "${YELLOW}== Issues and Recommendations ==${NC}"
    [[ -z "$MX_RECORDS" ]] && echo -e "${YELLOW}- MX records not found: Email service might not be configured${NC}"
    [[ -z "$NS_RECORDS" ]] && echo -e "${YELLOW}- NS records not found: DNS provider could not be identified${NC}"
    [[ -z "$TXT_RECORDS" ]] && echo -e "${YELLOW}- No SPF/DKIM/DMARC found: Email authentication may be missing${NC}"
    [[ "$http_status" != "200" ]] && echo -e "${YELLOW}- HTTP status is $http_status: Website may have issues${NC}"
    [[ ! "$headers" =~ [Ss]trict-[Tt]ransport-[Ss]ecurity ]] && echo -e "${YELLOW}- HSTS header missing: Consider enabling HTTPS enforcement${NC}"
    [[ ! "$headers" =~ [Cc]ontent-[Ss]ecurity-[Pp]olicy ]] && echo -e "${YELLOW}- CSP header missing: Consider adding Content Security Policy${NC}"
    echo
    
    echo -e "${BLUE}=========================================="
    echo -e "         AUDIT COMPLETED"
    echo -e "==========================================${NC}"
}

# Main execution function
main() {
    # Handle special arguments
    case "${1:-}" in
        --help|-h) show_help ;;
        --version|-v) echo "$SCRIPT_NAME v$SCRIPT_VERSION"; exit 0 ;;
        --config) echo "Configuration file: $CONFIG_FILE"; exit 0 ;;
        --self-test) run_self_test; exit $? ;;
        "") show_help ;;
    esac
    
    local input_url="$1"
    FORMAT="${2:-terminal}"
    
    # Check if debug is specified as second or third argument
    [[ "$2" == "debug" ]] && { FORMAT="terminal"; DEBUG=1; }
    [[ "$3" == "debug" ]] && DEBUG=1
    
    # Enhanced URL processing with validation
    if [[ "$input_url" =~ ^https?:// ]]; then
        URL="$input_url"
        DOMAIN=$(extract_domain "$input_url")
    else
        DOMAIN=$(extract_domain "$input_url")
        if [[ $? -ne 0 ]]; then
            log_error "Invalid domain format"
            exit 1
        fi
        URL="https://$DOMAIN"
    fi
    
    # Validate format
    case "$FORMAT" in
        html|txt|terminal|json|debug) ;;
        *) echo "Invalid format. Use: html, txt, terminal, json"; exit 1 ;;
    esac
    
    # Global variables
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    REPORT_BASE="web_audit_${DOMAIN//./_}"
    MX_RECORDS=""
    NS_RECORDS=""
    TXT_RECORDS=""
    
    log_section "Starting comprehensive audit for $DOMAIN"
    
    # Resolve domain to IP
    IP=$(resolve_domain "$DOMAIN")
    
    if [[ -z "$IP" ]]; then
        log_error "Could not resolve domain $DOMAIN"
        log_section "Continuing with DNS-only audit..."
    else
        log_success "Domain resolved: $DOMAIN -> $IP"
    fi
    
    # Check website connectivity
    if ! check_connectivity "$URL"; then
        log_warning "Website connectivity issues detected, continuing with available checks..."
    else
        log_success "Website is accessible"
    fi
    
    # Generate report based on format
    case "$FORMAT" in
        terminal)
            generate_terminal_report
            ;;
        html)
            generate_html_report
            ;;
        txt)
            generate_txt_report
            ;;
        json)
            generate_json_report
            ;;
    esac
    
    log_success "Audit completed successfully"
}

# HTML report generation (bonus feature)
generate_html_report() {
    local html_file="${REPORT_BASE}_${TIMESTAMP//[: -]/_}.html"
    
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Web Audit Report - $DOMAIN</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .info-card { background: #ecf0f1; padding: 15px; border-radius: 5px; border-left: 4px solid #3498db; }
        .success { color: #27ae60; }
        .warning { color: #f39c12; }
        .error { color: #e74c3c; }
        .score { font-size: 24px; font-weight: bold; text-align: center; padding: 20px; background: #3498db; color: white; border-radius: 5px; }
        pre { background: #2c3e50; color: white; padding: 15px; border-radius: 5px; overflow-x: auto; }
        .timestamp { color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Web Audit Report</h1>
            <p><strong>Domain:</strong> $DOMAIN</p>
            <p><strong>URL:</strong> $URL</p>
            <p><strong>IP:</strong> $IP</p>
            <p class="timestamp">Generated: $TIMESTAMP</p>
        </div>
EOF
    
    # Add sections dynamically by capturing terminal output
    {
        echo "<div class='section'>"
        echo "<h2>Domain Information</h2>"
        echo "<div class='info-card'><pre>"
        get_domain_info "$DOMAIN"
        echo "</pre></div>"
        echo "</div>"
        
        echo "<div class='section'>"
        echo "<h2>DNS Information</h2>"
        echo "<div class='info-card'><pre>"
        get_dns_info "$DOMAIN"
        echo "</pre></div>"
        echo "</div>"
        
        echo "<div class='section'>"
        echo "<h2>Web Technologies</h2>"
        echo "<div class='info-card'><pre>"
        get_web_technologies "$URL"
        echo "</pre></div>"
        echo "</div>"
        
    } >> "$html_file"
    
    cat >> "$html_file" << EOF
    </div>
</body>
</html>
EOF
    
    log_success "HTML report generated: $html_file"
}

# Display dig statistics and information
show_dig_stats() {
    local domain="$1"
    
    if ! command -v dig >/dev/null 2>&1; then
        echo -e "${YELLOW}dig not available - install with: sudo apt install dnsutils${NC}"
        return 1
    fi
    
    echo -e "${CYAN}== dig Statistics for $domain ==${NC}"
    
    # dig version
    local dig_version=$(dig -v 2>&1)
    echo "dig Version: $dig_version"
    
    # Query time measurement
    echo "Query Performance Test:"
    local start_time=$(date +%s%N)
    local query_result=$(dig +short +time=3 +tries=1 A "$domain" 2>/dev/null)
    local end_time=$(date +%s%N)
    local query_time=$(( (end_time - start_time) / 1000000 ))
    
    if [[ -n "$query_result" ]]; then
        echo "  ✅ A record query: ${query_time}ms"
        echo "  📍 Result: $query_result"
    else
        echo "  ❌ A record query failed"
    fi
    
    # Test different DNS servers response times
    echo "DNS Server Response Times:"
    local dns_servers=("8.8.8.8" "1.1.1.1" "9.9.9.9" "208.67.222.222")
    local dns_names=("Google" "Cloudflare" "Quad9" "OpenDNS")
    
    for i in "${!dns_servers[@]}"; do
        local server="${dns_servers[$i]}"
        local name="${dns_names[$i]}"
        
        local start_time=$(date +%s%N)
        local result=$(timeout 5 dig @"$server" +short +time=3 +tries=1 A "$domain" 2>/dev/null)
        local end_time=$(date +%s%N)
        local response_time=$(( (end_time - start_time) / 1000000 ))
        
        if [[ -n "$result" ]]; then
            echo "  ✅ $name ($server): ${response_time}ms"
        else
            echo "  ❌ $name ($server): timeout/failed"
        fi
    done
    
    echo
}

# Text report generation
generate_txt_report() {
    local txt_file="${REPORT_BASE}_${TIMESTAMP//[: -]/_}.txt"
    
    {
        echo "=========================================="
        echo "         WEB AUDIT REPORT"
        echo "=========================================="
        echo "Domain: $DOMAIN"
        echo "URL: $URL"
        echo "Date: $TIMESTAMP"
        echo "IP: $IP"
        echo ""
        
        echo "== Domain Information =="
        get_domain_info "$DOMAIN"
        echo ""
        
        echo "== DNS Information =="
        get_dns_info "$DOMAIN"
        echo ""
        
        echo "== Web Technologies =="
        get_web_technologies "$URL"
        echo ""
        
        echo "== SSL Certificate =="
        check_ssl_certificate "$DOMAIN"
        echo ""
        
        echo "== Security Headers =="
        check_security_headers "$URL"
        echo ""
        
        echo "=========================================="
        echo "         AUDIT COMPLETED"
        echo "=========================================="
        
    } > "$txt_file"
    
    log_success "Text report generated: $txt_file"
}

# JSON report generation (enhanced with proper escaping)
generate_json_report() {
    local json_file="${REPORT_BASE}_${TIMESTAMP//[: -]/_}.json"
    
    # Start JSON structure
    cat > "$json_file" << EOF
{
  "audit_info": {
    "domain": "$(json_escape "$DOMAIN")",
    "url": "$(json_escape "$URL")",
    "ip": "$(json_escape "$IP")",
    "timestamp": "$(json_escape "$TIMESTAMP")",
    "tool_version": "$(json_escape "$SCRIPT_NAME v$SCRIPT_VERSION")"
  },
  "domain_info": {
EOF
    
    # Get domain info and format as JSON
    local domain_info=$(get_domain_info "$DOMAIN" 2>/dev/null)
    if [[ -n "$domain_info" ]]; then
        # Parse domain info into JSON with proper escaping
        local registrar=$(echo "$domain_info" | grep "Registrar:" | cut -d: -f2- | sed 's/^[[:space:]]*//')
        local creation=$(echo "$domain_info" | grep "Creation Date:" | cut -d: -f2- | sed 's/^[[:space:]]*//')
        local expiry=$(echo "$domain_info" | grep "Expiration Date:" | cut -d: -f2- | sed 's/^[[:space:]]*//')
        
        cat >> "$json_file" << EOF
    "registrar": "$(json_escape "${registrar:-N/A}")",
    "creation_date": "$(json_escape "${creation:-N/A}")",
    "expiration_date": "$(json_escape "${expiry:-N/A}")"
EOF
    else
        cat >> "$json_file" << EOF
    "registrar": "N/A",
    "creation_date": "N/A",
    "expiration_date": "N/A"
EOF
    fi
    
    cat >> "$json_file" << EOF
  },
  "dns_info": {
    "mx_records": "$(json_escape "$MX_RECORDS")",
    "ns_records": "$(json_escape "$NS_RECORDS")",
    "txt_records": "$(json_escape "$TXT_RECORDS")"
  },
  "ssl_info": {
EOF
    
    # Check SSL and add to JSON
    local ssl_valid=false
    if timeout 10 openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
        ssl_valid=true
    fi
    
    cat >> "$json_file" << EOF
    "valid": $ssl_valid,
    "checked_at": "$TIMESTAMP"
  },
  "security_score": {
EOF
    
    # Calculate security score (simplified)
    local score=0
    [[ "$ssl_valid" == "true" ]] && score=$((score + 25))
    [[ -n "$MX_RECORDS" ]] && score=$((score + 25))
    [[ -n "$NS_RECORDS" ]] && score=$((score + 25))
    [[ -n "$TXT_RECORDS" ]] && score=$((score + 25))
    
    cat >> "$json_file" << EOF
    "total": $score,
    "max_possible": 100
  }
}
EOF
    
    log_success "JSON report generated: $json_file"
}

# Enhanced error handling and cleanup
cleanup() {
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && log_error "Script exited with error code $exit_code"
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Self-test function
run_self_test() {
    echo "Running self-test..."
    local test_domain="google.com"
    local tests_passed=0
    local total_tests=5
    
    # Test 1: Domain resolution
    if resolve_domain "$test_domain" >/dev/null; then
        echo "✅ Domain resolution test passed"
        ((tests_passed++))
    else
        echo "❌ Domain resolution test failed"
    fi
    
    # Test 2: HTTP connectivity
    if check_connectivity "https://$test_domain" >/dev/null 2>&1; then
        echo "✅ HTTP connectivity test passed"
        ((tests_passed++))
    else
        echo "❌ HTTP connectivity test failed"
    fi
    
    # Test 3: DNS query
    if perform_dig_query "$test_domain" "A" >/dev/null; then
        echo "✅ DNS query test passed"
        ((tests_passed++))
    else
        echo "❌ DNS query test failed"
    fi
    
    # Test 4: SSL check
    if timeout 10 openssl s_client -connect "$test_domain:443" -servername "$test_domain" </dev/null >/dev/null 2>&1; then
        echo "✅ SSL test passed"
        ((tests_passed++))
    else
        echo "❌ SSL test failed"
    fi
    
    # Test 5: Configuration loading
    if load_and_validate_config >/dev/null 2>&1; then
        echo "✅ Configuration test passed"
        ((tests_passed++))
    else
        echo "❌ Configuration test failed"
    fi
    
    echo "Self-test completed: $tests_passed/$total_tests tests passed"
    [[ $tests_passed -eq $total_tests ]]
}

# Parameter validation
validate_dependencies() {
    local missing_deps=()
    
    # Essential tools
    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v openssl >/dev/null 2>&1 || missing_deps+=("openssl")
    
    # Check for at least one DNS resolution tool
    if ! command -v dig >/dev/null 2>&1 && ! command -v nslookup >/dev/null 2>&1 && ! command -v getent >/dev/null 2>&1; then
        missing_deps+=("dnsutils (or nslookup)")
    fi
    
    # Required for performance calculations
    command -v bc >/dev/null 2>&1 || missing_deps+=("bc")
    
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

# Check dependencies before running
validate_dependencies

# Load user configuration
load_and_validate_config

# Run main function
main "$@"
