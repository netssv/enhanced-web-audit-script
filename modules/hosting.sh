#!/bin/bash

# Hosting module - Web hosting provider detection and analysis
# Part of Enhanced Web Audit Script v2.1

# Source core module
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

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
    detect_isp_info "$ip" hosting_info
    
    # IP range-based detection
    detect_by_ip_range "$ip" hosting_info
    
    # Display hosting information
    if [[ ${#hosting_info[@]} -gt 0 ]]; then
        printf '%s\n' "${hosting_info[@]}"
    else
        echo "Hosting provider could not be determined"
    fi
    
    # Performance characteristics
    echo
    analyze_performance_features "$headers"
    echo
}

# ISP/ASN detection
detect_isp_info() {
    local ip="$1"
    local -n hosting_array=$2
    
    if command -v whois >/dev/null 2>&1 && [[ -n "$ip" ]]; then
        local asn_info=$(timeout 10 whois "$ip" 2>/dev/null | grep -iE "orgname|netname|descr" | head -3)
        if [[ -n "$asn_info" ]]; then
            local org_name=$(echo "$asn_info" | grep -iE "orgname|netname" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
            [[ -n "$org_name" ]] && hosting_array+=("ISP/Hosting: $org_name")
        fi
    fi
}

# IP range-based provider detection
detect_by_ip_range() {
    local ip="$1"
    local -n hosting_array=$2
    
    if [[ -n "$ip" ]]; then
        case "$ip" in
            104.21.*|172.67.*|104.16.*) hosting_array+=("Hosting: Cloudflare") ;;
            54.*|52.*|34.*|3.*) hosting_array+=("Hosting: Amazon AWS (likely)") ;;
            35.*|104.154.*|130.211.*) hosting_array+=("Hosting: Google Cloud (likely)") ;;
            40.*|52.*|13.*|20.*) hosting_array+=("Hosting: Microsoft Azure (likely)") ;;
            68.183.*|167.71.*|164.90.*) hosting_array+=("Hosting: DigitalOcean (likely)") ;;
        esac
    fi
}

# Analyze performance features
analyze_performance_features() {
    local headers="$1"
    
    echo "Performance Characteristics:"
    
    # Check for HTTP/2 support
    if echo "$headers" | grep -qi "http/2"; then
        echo "✅ HTTP/2 supported"
    else
        echo "❌ HTTP/2 not detected"
    fi
    
    # Check for compression with proper headers
    local compression_headers=$(echo "$headers" | grep -i "content-encoding" | head -1)
    local accept_encoding_test=$(timeout 10 curl -s -I \
        -H "User-Agent: $USER_AGENT" \
        -H "Accept-Encoding: gzip, deflate, br" \
        "$url" 2>/dev/null | grep -i "content-encoding" | head -1)
    
    if [[ -n "$accept_encoding_test" ]]; then
        if echo "$accept_encoding_test" | grep -qi "br"; then
            echo "✅ Brotli compression enabled"
        elif echo "$accept_encoding_test" | grep -qi "gzip"; then
            echo "✅ Gzip compression enabled"
        elif echo "$accept_encoding_test" | grep -qi "deflate"; then
            echo "✅ Deflate compression enabled"
        else
            echo "❌ No compression detected"
        fi
    elif [[ -n "$compression_headers" ]]; then
        if echo "$compression_headers" | grep -qi "br"; then
            echo "✅ Brotli compression enabled"
        elif echo "$compression_headers" | grep -qi "gzip"; then
            echo "✅ Gzip compression enabled"
        elif echo "$compression_headers" | grep -qi "deflate"; then
            echo "✅ Deflate compression enabled"
        else
            echo "❌ No compression detected"
        fi
    else
        # Check page size to provide better feedback
        local page_size=$(timeout 10 curl -s -o /dev/null -w "%{size_download}" \
            -H "User-Agent: $USER_AGENT" \
            -H "Accept-Encoding: identity" \
            "$url" 2>/dev/null)
        
        if [[ -n "$page_size" && "$page_size" -gt 0 ]]; then
            local size_kb=$(echo "scale=1; $page_size / 1024" | bc -l 2>/dev/null || echo "0")
            if [[ "$page_size" -lt 5120 ]]; then
                echo "❓ No compression — page is small (${size_kb} KB), minimal benefit expected"
            else
                echo "❌ No compression detected — should use Gzip/Brotli (page: ${size_kb} KB)"
            fi
        else
            echo "❌ No compression detected"
        fi
    fi
    
    # Check for caching headers
    if echo "$headers" | grep -qi "cache-control\|expires\|etag"; then
        echo "✅ Caching headers present"
    else
        echo "❌ No caching headers detected"
    fi
}

# CDN detection
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

# Quick hosting check (lighter version)
quick_hosting_check() {
    local domain="$1"
    local ip="$2"
    local url="${3:-https://$domain}"
    
    echo "Quick Hosting Check:"
    
    # Simple IP range check
    if [[ -n "$ip" ]]; then
        case "$ip" in
            104.21.*|172.67.*|104.16.*) echo "  Provider: Cloudflare" ;;
            54.*|52.*|34.*|3.*) echo "  Provider: Amazon AWS (likely)" ;;
            35.*|104.154.*|130.211.*) echo "  Provider: Google Cloud (likely)" ;;
            40.*|52.*|13.*|20.*) echo "  Provider: Microsoft Azure (likely)" ;;
            68.183.*|167.71.*|164.90.*) echo "  Provider: DigitalOcean (likely)" ;;
            *) echo "  Provider: Unknown" ;;
        esac
    else
        echo "  Provider: Could not determine"
    fi
    
    # Quick compression check using the final URL (handles redirects)
    local compression_test=$(timeout 5 curl -s -I \
        -H "User-Agent: Mozilla/5.0 (Linux) Enhanced-Audit/2.1" \
        -H "Accept-Encoding: gzip, deflate, br" \
        "$url" 2>/dev/null | grep -i "content-encoding" | head -1)
    
    # Get page size for context
    local page_size=$(timeout 5 curl -s -o /dev/null -w "%{size_download}" \
        -H "User-Agent: Mozilla/5.0 (Linux) Enhanced-Audit/2.1" \
        -H "Accept-Encoding: gzip, deflate, br" \
        "$url" 2>/dev/null)
    
    local size_info=""
    if [[ -n "$page_size" && "$page_size" -gt 0 ]]; then
        local size_kb=$(echo "scale=1; $page_size / 1024" | bc -l 2>/dev/null || echo "0")
        size_info=" (${size_kb} KB)"
    fi
    
    if [[ -n "$compression_test" ]]; then
        if echo "$compression_test" | grep -qi "br"; then
            echo "  Compression: ✅ Brotli${size_info}"
        elif echo "$compression_test" | grep -qi "gzip"; then
            echo "  Compression: ✅ Gzip${size_info}"
        elif echo "$compression_test" | grep -qi "deflate"; then
            echo "  Compression: ✅ Deflate${size_info}"
        else
            echo "  Compression: ❌ None detected${size_info}"
        fi
    else
        if [[ -n "$page_size" && "$page_size" -gt 0 ]]; then
            local size_kb=$(echo "scale=1; $page_size / 1024" | bc -l 2>/dev/null || echo "0")
            if [[ "$page_size" -lt 5120 ]]; then
                echo "  Compression: ❓ None (${size_kb} KB page, minimal benefit)"
            else
                echo "  Compression: ❌ None (${size_kb} KB page, should compress)"
            fi
        else
            echo "  Compression: ❌ None detected"
        fi
    fi
    
    echo
}
