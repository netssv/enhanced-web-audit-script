#!/bin/bash

# Advanced Curl Tools Module  
# Part of Enhanced Web Audit Script v2.1

# Source core module
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Advanced HTTP analysis using curl
advanced_curl_analysis() {
    local url="$1"
    
    echo -e "${GREEN}== Advanced HTTP Analysis (curl) ==${NC}"
    
    # Comprehensive timing breakdown
    echo "HTTP Connection Timing Breakdown:"
    local timing_output=$(timeout 15 curl -w "\
  DNS Resolution:     %{time_namelookup}s
  TCP Connection:     %{time_connect}s  
  TLS Handshake:      %{time_appconnect}s
  Server Processing:  %{time_pretransfer}s
  Content Transfer:   %{time_starttransfer}s
  Total Time:         %{time_total}s
  Redirect Time:      %{time_redirect}s" \
    -o /dev/null -s "$url" 2>/dev/null)
    
    if [[ -n "$timing_output" ]]; then
        echo "$timing_output"
    else
        echo "  Could not retrieve timing information"
    fi
    echo
    
    # HTTP version and protocol analysis
    echo "HTTP Protocol Analysis:"
    local http_info=$(timeout 10 curl -I -s -w "HTTP Version: %{http_version}\nHTTP Code: %{http_code}\nContent Type: %{content_type}\nRedirect URL: %{redirect_url}" "$url" 2>/dev/null)
    
    if [[ -n "$http_info" ]]; then
        echo "$http_info" | while read -r line; do
            if [[ -n "$line" ]]; then
                echo "  $line"
            fi
        done
    fi
    echo
    
    # Advanced headers analysis
    echo "Security Headers Analysis:"
    local headers=$(timeout 10 curl -I -s "$url" 2>/dev/null)
    
    if [[ -n "$headers" ]]; then
        # Security headers to check
        local security_headers=(
            "Strict-Transport-Security:HSTS"
            "Content-Security-Policy:CSP"
            "X-Frame-Options:Frame Protection"
            "X-Content-Type-Options:MIME Sniffing Protection"
            "X-XSS-Protection:XSS Protection"
            "Referrer-Policy:Referrer Policy"
            "Permissions-Policy:Permissions Policy"
            "Content-Security-Policy-Report-Only:CSP Report Only"
        )
        
        for header_info in "${security_headers[@]}"; do
            IFS=':' read -r header_name display_name <<< "$header_info"
            if echo "$headers" | grep -qi "^$header_name:"; then
                local header_value=$(echo "$headers" | grep -i "^$header_name:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | head -1)
                echo "  ✅ $display_name: $header_value"
            else
                echo "  ❌ $display_name: Not set"
            fi
        done
        
        echo
        echo "Caching Headers:"
        local caching_headers=("Cache-Control" "Expires" "ETag" "Last-Modified" "Age")
        for header in "${caching_headers[@]}"; do
            if echo "$headers" | grep -qi "^$header:"; then
                local value=$(echo "$headers" | grep -i "^$header:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | head -1)
                echo "  $header: $value"
            fi
        done
        
        echo
        echo "Server Information:"
        local server_headers=("Server" "X-Powered-By" "X-AspNet-Version" "X-Generator")
        for header in "${server_headers[@]}"; do
            if echo "$headers" | grep -qi "^$header:"; then
                local value=$(echo "$headers" | grep -i "^$header:" | cut -d: -f2- | sed 's/^[[:space:]]*//' | head -1)
                echo "  $header: $value"
            fi
        done
    else
        echo "  Could not retrieve headers"
    fi
    echo
    
    # Response size analysis
    echo "Response Size Analysis:"
    local size_info=$(timeout 15 curl -w "\
  Header Size:        %{size_header} bytes
  Download Size:      %{size_download} bytes  
  Upload Size:        %{size_upload} bytes
  Content Length:     %{size_request} bytes
  Speed Download:     %{speed_download} bytes/sec
  Speed Upload:       %{speed_upload} bytes/sec" \
    -o /dev/null -s "$url" 2>/dev/null)
    
    if [[ -n "$size_info" ]]; then
        echo "$size_info"
    fi
    echo
    
    # Redirect chain analysis
    echo "Redirect Chain Analysis:"
    local redirect_info=$(timeout 15 curl -I -L -s -w "Final URL: %{url_effective}\nRedirect Count: %{num_redirects}" "$url" 2>/dev/null)
    
    if [[ -n "$redirect_info" ]]; then
        echo "$redirect_info" | while read -r line; do
            if [[ -n "$line" ]]; then
                echo "  $line"
            fi
        done
        
        # Show redirect chain if any
        local redirect_count=$(echo "$redirect_info" | grep "Redirect Count:" | cut -d: -f2 | tr -d ' ')
        if [[ "$redirect_count" -gt 0 ]]; then
            echo "  Analyzing redirect chain..."
            timeout 10 curl -I -L -s "$url" 2>/dev/null | grep -i "^location:" | while read -r location; do
                local redirect_url=$(echo "$location" | cut -d: -f2- | sed 's/^[[:space:]]*//')
                echo "    -> $redirect_url"
            done
        fi
    fi
    echo
}

# HTTP/2 and HTTP/3 support analysis
analyze_http_protocols() {
    local url="$1"
    local domain=$(echo "$url" | sed 's|^https\?://||' | sed 's|/.*||' | sed 's|:.*||')
    
    echo "HTTP Protocol Support:"
    
    # Test HTTP/2
    local http2_test=$(timeout 10 curl -I -s --http2 "$url" 2>/dev/null | head -1)
    if [[ "$http2_test" == *"HTTP/2"* ]]; then
        echo "  HTTP/2: ✅ Supported"
    else
        echo "  HTTP/2: ❌ Not supported"
    fi
    
    # Test HTTP/3 (if curl supports it)
    if curl --help all 2>/dev/null | grep -q "http3"; then
        local http3_test=$(timeout 10 curl -I -s --http3 "$url" 2>/dev/null | head -1)
        if [[ "$http3_test" == *"HTTP/3"* ]]; then
            echo "  HTTP/3: ✅ Supported"
        else
            echo "  HTTP/3: ❌ Not supported"
        fi
    else
        echo "  HTTP/3: ❓ Cannot test (curl doesn't support HTTP/3)"
    fi
    
    # Test different TLS versions
    echo "  TLS Support:"
    local tls_versions=("--tlsv1.2" "--tlsv1.3")
    local tls_names=("TLS 1.2" "TLS 1.3")
    
    for i in "${!tls_versions[@]}"; do
        local tls_flag="${tls_versions[$i]}"
        local tls_name="${tls_names[$i]}"
        
        if timeout 5 curl -I -s "$tls_flag" "$url" >/dev/null 2>&1; then
            echo "    $tls_name: ✅ Supported"
        else
            echo "    $tls_name: ❌ Not supported"
        fi
    done
    
    echo
}

# Content analysis using curl
analyze_content_with_curl() {
    local url="$1"
    
    echo "Content Analysis:"
    
    # Get content type and encoding
    local content_info=$(timeout 10 curl -I -s "$url" 2>/dev/null | grep -i "content-")
    
    if [[ -n "$content_info" ]]; then
        echo "$content_info" | while read -r line; do
            if [[ -n "$line" ]]; then
                echo "  $line"
            fi
        done
    fi
    
    # Check for common web technologies in headers
    echo
    echo "Technology Detection (Headers):"
    local tech_headers=$(timeout 10 curl -I -s "$url" 2>/dev/null)
    
    # Common technology indicators
    if echo "$tech_headers" | grep -qi "cloudflare"; then
        echo "  ✅ Cloudflare CDN detected"
    fi
    
    if echo "$tech_headers" | grep -qi "nginx"; then
        echo "  ✅ Nginx web server detected"
    fi
    
    if echo "$tech_headers" | grep -qi "apache"; then
        echo "  ✅ Apache web server detected"
    fi
    
    if echo "$tech_headers" | grep -qi "express"; then
        echo "  ✅ Express.js detected"
    fi
    
    if echo "$tech_headers" | grep -qi "php"; then
        echo "  ✅ PHP detected"
    fi
    
    # Check for WordPress
    local wp_check=$(timeout 10 curl -s "$url" 2>/dev/null | grep -c "wp-content\|wordpress")
    if [[ $wp_check -gt 0 ]]; then
        echo "  ✅ WordPress detected"
    fi
    
    echo
}

# Performance testing with curl
performance_test_with_curl() {
    local url="$1"
    
    echo "Performance Testing (Multiple Requests):"
    
    # Test with different connection approaches
    echo "  Connection Performance:"
    
    # Fresh connection each time
    local fresh_time=$(timeout 10 curl -w "%{time_total}" -o /dev/null -s "$url" 2>/dev/null)
    echo "    Fresh Connection: ${fresh_time}s"
    
    # Keep-alive connection
    local keepalive_time=$(timeout 10 curl -w "%{time_total}" -o /dev/null -s --keepalive-time 60 "$url" 2>/dev/null)
    echo "    Keep-Alive: ${keepalive_time}s"
    
    # IPv4 only
    local ipv4_time=$(timeout 10 curl -w "%{time_total}" -o /dev/null -s -4 "$url" 2>/dev/null)
    echo "    IPv4 Only: ${ipv4_time}s"
    
    # IPv6 only (if available)
    local ipv6_time=$(timeout 10 curl -w "%{time_total}" -o /dev/null -s -6 "$url" 2>/dev/null)
    if [[ -n "$ipv6_time" && "$ipv6_time" != "0.000000" ]]; then
        echo "    IPv6 Only: ${ipv6_time}s"
    else
        echo "    IPv6 Only: Not available"
    fi
    
    echo
}

# Quick curl analysis for fast mode
quick_curl_analysis() {
    local url="$1"
    
    echo "Quick HTTP Analysis:"
    
    # Basic timing
    local quick_timing=$(timeout 5 curl -w "Response: %{time_total}s, Code: %{http_code}" -o /dev/null -s "$url" 2>/dev/null)
    echo "  $quick_timing"
    
    # Quick security check
    local security_score=0
    local headers=$(timeout 5 curl -I -s "$url" 2>/dev/null)
    
    if echo "$headers" | grep -qi "strict-transport-security"; then
        ((security_score++))
    fi
    if echo "$headers" | grep -qi "content-security-policy"; then
        ((security_score++))
    fi
    if echo "$headers" | grep -qi "x-frame-options"; then
        ((security_score++))
    fi
    
    echo "  Security Headers: $security_score/3 present"
    
    echo
}
