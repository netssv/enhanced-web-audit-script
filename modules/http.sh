#!/bin/bash

# HTTP module - All HTTP-related functionality including technology detection
# Part of Enhanced Web Audit Script v2.1

# Source core module
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Get headers efficiently
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

# Get body content efficiently
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
            # Sanitize body content
            echo "$body" | tr -d '\0' | head -200
            return 0
        fi
        
        retry=$((retry + 1))
        log_debug "Body request attempt $retry failed, retrying..."
        sleep 2
    done
    
    return 1
}

# Enhanced connectivity check
check_connectivity() {
    local url="$1"
    local response=""
    local final_url=""
    local http_code=""
    local retry=0
    
    log_debug "Checking connectivity for: $url"
    
    while [[ $retry -lt $MAX_RETRIES ]]; do
        # Get comprehensive curl info
        local curl_output=$(timeout "$TIMEOUT_HTTP" curl -s -L -o /dev/null -w "HTTPCODE:%{http_code}\nFINALURL:%{url_effective}\nTIME:%{time_total}\n" \
            -H "User-Agent: $USER_AGENT" \
            --max-time "$TIMEOUT_HTTP" \
            --max-redirs "$MAX_REDIRECTS" \
            "$url" 2>/dev/null)
        local curl_exit_code=$?
        
        if [[ $curl_exit_code -eq 0 && -n "$curl_output" ]]; then
            http_code=$(echo "$curl_output" | grep "HTTPCODE:" | cut -d: -f2)
            final_url=$(echo "$curl_output" | grep "FINALURL:" | cut -d: -f2-)
            local response_time=$(echo "$curl_output" | grep "TIME:" | cut -d: -f2)
            
            log_debug "HTTP response: $http_code (${response_time}s)"
            
            if [[ "$final_url" != "$url" ]]; then
                log_section "Redirected to $final_url"
            fi
            
            case "$http_code" in
                200|301|302|303|307|308) return 0 ;;
                *) log_warning "HTTP status: $http_code" ;;
            esac
            break
        fi
        
        retry=$((retry + 1))
        log_debug "Connectivity check attempt $retry failed, retrying..."
        sleep 2
    done
    
    [[ $retry -ge $MAX_RETRIES ]] && return 1
    return 0
}

# CMS detection
detect_cms() {
    local body="$1"
    local -n tech_array=$2
    
    # WordPress detection
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

# JavaScript frameworks detection
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

# Server technology detection
detect_server_tech() {
    local headers="$1"
    local -n tech_array=$2
    
    local server=$(echo "$headers" | grep -iE "^server:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    local powered_by=$(echo "$headers" | grep -iE "^x-powered-by:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    
    [[ -n "$server" ]] && tech_array+=("Web Server: $server")
    [[ -n "$powered_by" ]] && tech_array+=("Powered By: $powered_by")
}

# Enhanced technology detection
get_web_technologies() {
    local url="$1"
    local technologies=()
    
    echo "=== Detected Technologies ==="
    
    # Get headers and body content
    local headers=$(get_headers "$url")
    local body=$(get_body_content "$url")
    
    if [[ -z "$headers" || -z "$body" ]]; then
        echo "Could not retrieve website content for analysis"
        return 1
    fi
    
    # Detect various technologies
    detect_server_tech "$headers" technologies
    detect_cms "$body" technologies
    detect_js_frameworks "$body" technologies
    
    # Additional technologies
    echo "$body" | grep -qiE "google-analytics|gtag|ga\(" && technologies+=("Analytics: Google Analytics")
    echo "$body" | grep -qiE "bootstrapcdn|bootstrap" && technologies+=("CSS Framework: Bootstrap")
    
    # Display results
    if [[ ${#technologies[@]} -gt 0 ]]; then
        printf '%s\n' "${technologies[@]}"
    else
        echo "No specific technologies detected"
    fi
}
