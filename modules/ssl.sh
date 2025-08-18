#!/bin/bash

# SSL Certificate Analysis Module
# Part of Enhanced Web Audit Script v2.1

# Source core module
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Comprehensive SSL certificate analysis
analyze_ssl_certificate() {
    local url="$1"
    local domain=$(echo "$url" | sed 's|^https\?://||' | sed 's|/.*||' | sed 's|:.*||')
    
    echo -e "${GREEN}== SSL Certificate Analysis ==${NC}"
    
    # Extract certificate information using openssl
    local cert_info=$(timeout "$TIMEOUT_SSL" openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -text 2>/dev/null)
    
    if [[ -z "$cert_info" ]]; then
        echo "❌ Could not retrieve SSL certificate information"
        return 1
    fi
    
    # Get certificate dates
    local cert_dates=$(timeout "$TIMEOUT_SSL" openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [[ -n "$cert_dates" ]]; then
        echo "Certificate Validity:"
        
        # Parse start and end dates
        local not_before=$(echo "$cert_dates" | grep "notBefore" | cut -d= -f2)
        local not_after=$(echo "$cert_dates" | grep "notAfter" | cut -d= -f2)
        
        echo "  Valid From: $not_before"
        echo "  Valid Until: $not_after"
        
        # Calculate days until expiration
        if command -v date >/dev/null 2>&1; then
            local expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null)
            local current_epoch=$(date +%s)
            
            if [[ -n "$expiry_epoch" && "$expiry_epoch" =~ ^[0-9]+$ ]]; then
                local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                
                echo "  Days Until Expiry: $days_left"
                
                # Color-coded warnings
                if [[ $days_left -lt 0 ]]; then
                    echo "  ❌ Certificate EXPIRED!"
                elif [[ $days_left -lt 7 ]]; then
                    echo "  🚨 Certificate expires in less than a week!"
                elif [[ $days_left -lt 30 ]]; then
                    echo "  ⚠️  Certificate expires within 30 days"
                elif [[ $days_left -lt 90 ]]; then
                    echo "  📅 Certificate expires within 90 days"
                else
                    echo "  ✅ Certificate has good validity period"
                fi
            fi
        fi
    fi
    
    echo
    
    # Certificate issuer and subject
    local issuer=$(echo "$cert_info" | grep -A1 "Issuer:" | tail -1 | sed 's/^[[:space:]]*//')
    local subject=$(echo "$cert_info" | grep -A1 "Subject:" | tail -1 | sed 's/^[[:space:]]*//')
    
    if [[ -n "$issuer" ]]; then
        echo "Certificate Authority:"
        echo "  Issuer: $issuer"
    fi
    
    if [[ -n "$subject" ]]; then
        echo "  Subject: $subject"
    fi
    
    echo
    
    # Certificate algorithm and key length
    local sig_algo=$(echo "$cert_info" | grep "Signature Algorithm:" | head -1 | cut -d: -f2 | sed 's/^[[:space:]]*//')
    local key_usage=$(echo "$cert_info" | grep -A5 "X509v3 Key Usage:" | grep -v "X509v3 Key Usage:" | head -1 | sed 's/^[[:space:]]*//')
    
    echo "Security Features:"
    if [[ -n "$sig_algo" ]]; then
        echo "  Signature Algorithm: $sig_algo"
        
        # Check for weak algorithms
        case "$sig_algo" in
            *"sha1"*|*"SHA1"*|*"md5"*|*"MD5"*)
                echo "  ⚠️  Weak signature algorithm detected"
                ;;
            *"sha256"*|*"SHA256"*|*"sha384"*|*"SHA384"*|*"sha512"*|*"SHA512"*)
                echo "  ✅ Strong signature algorithm"
                ;;
        esac
    fi
    
    # Get public key information
    local key_info=$(timeout "$TIMEOUT_SSL" openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -pubkey 2>/dev/null | openssl rsa -pubin -text -noout 2>/dev/null | grep "Public-Key:" | head -1)
    
    if [[ -n "$key_info" ]]; then
        echo "  $key_info"
        
        # Extract key size
        local key_size=$(echo "$key_info" | grep -o '[0-9]\+' | head -1)
        if [[ -n "$key_size" ]]; then
            if [[ $key_size -ge 2048 ]]; then
                echo "  ✅ Strong key size ($key_size bits)"
            else
                echo "  ⚠️  Weak key size ($key_size bits, recommend 2048+)"
            fi
        fi
    fi
    
    if [[ -n "$key_usage" ]]; then
        echo "  Key Usage: $key_usage"
    fi
    
    echo
    
    # Subject Alternative Names (SAN)
    local san_list=$(echo "$cert_info" | grep -A1 "X509v3 Subject Alternative Name:" | tail -1 | sed 's/^[[:space:]]*//')
    
    if [[ -n "$san_list" ]]; then
        echo "Subject Alternative Names:"
        echo "  $san_list" | tr ',' '\n' | sed 's/^[[:space:]]*DNS:/  /' | sed 's/^[[:space:]]*/    /'
        echo
    fi
    
    # OCSP and CRL information
    local ocsp_url=$(echo "$cert_info" | grep -A5 "Authority Information Access:" | grep "OCSP" | cut -d: -f2- | sed 's/^[[:space:]]*//')
    local crl_url=$(echo "$cert_info" | grep -A10 "X509v3 CRL Distribution Points:" | grep "URI:" | cut -d: -f2- | sed 's/^[[:space:]]*//')
    
    echo "Revocation Information:"
    if [[ -n "$ocsp_url" ]]; then
        echo "  OCSP URL: $ocsp_url"
    else
        echo "  OCSP: Not available"
    fi
    
    if [[ -n "$crl_url" ]]; then
        echo "  CRL URL: $crl_url"
    else
        echo "  CRL: Not available"
    fi
    
    echo
}

# Quick SSL check for fast mode
quick_ssl_check() {
    local url="$1"
    local domain=$(echo "$url" | sed 's|^https\?://||' | sed 's|/.*||' | sed 's|:.*||')
    
    echo "SSL Certificate Check:"
    
    # Quick certificate expiry check
    local cert_dates=$(timeout 5 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [[ -n "$cert_dates" ]]; then
        local not_after=$(echo "$cert_dates" | grep "notAfter" | cut -d= -f2)
        echo "  Valid Until: $not_after"
        
        # Quick expiry calculation
        if command -v date >/dev/null 2>&1; then
            local expiry_epoch=$(date -d "$not_after" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null)
            local current_epoch=$(date +%s)
            
            if [[ -n "$expiry_epoch" && "$expiry_epoch" =~ ^[0-9]+$ ]]; then
                local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
                
                if [[ $days_left -lt 0 ]]; then
                    echo "  Status: ❌ EXPIRED"
                elif [[ $days_left -lt 30 ]]; then
                    echo "  Status: ⚠️  Expires in $days_left days"
                else
                    echo "  Status: ✅ Valid ($days_left days left)"
                fi
            fi
        fi
        
        # Quick issuer check
        local issuer=$(timeout 5 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | cut -d= -f2-)
        if [[ -n "$issuer" ]]; then
            echo "  Issuer: $issuer"
        fi
    else
        echo "  Status: ❌ Could not retrieve certificate"
    fi
    
    echo
}

# Advanced SSL/TLS protocol analysis
analyze_ssl_protocols() {
    local domain="$1"
    
    echo "SSL/TLS Protocol Support:"
    
    # Test different TLS versions
    local protocols=("ssl3" "tls1" "tls1_1" "tls1_2" "tls1_3")
    local protocol_names=("SSLv3" "TLS 1.0" "TLS 1.1" "TLS 1.2" "TLS 1.3")
    
    for i in "${!protocols[@]}"; do
        local protocol="${protocols[$i]}"
        local name="${protocol_names[$i]}"
        
        if timeout 5 openssl s_client -connect "$domain:443" -"$protocol" </dev/null >/dev/null 2>&1; then
            case "$protocol" in
                "ssl3"|"tls1"|"tls1_1")
                    echo "  $name: ⚠️  Supported (deprecated)"
                    ;;
                "tls1_2")
                    echo "  $name: ✅ Supported (good)"
                    ;;
                "tls1_3")
                    echo "  $name: ✅ Supported (excellent)"
                    ;;
            esac
        else
            case "$protocol" in
                "ssl3"|"tls1"|"tls1_1")
                    echo "  $name: ✅ Disabled (good)"
                    ;;
                "tls1_2"|"tls1_3")
                    echo "  $name: ❌ Not supported"
                    ;;
            esac
        fi
    done
    
    echo
}

# Certificate chain analysis
analyze_certificate_chain() {
    local domain="$1"
    
    echo "Certificate Chain Analysis:"
    
    # Get certificate chain
    local chain_info=$(timeout "$TIMEOUT_SSL" openssl s_client -connect "$domain:443" -servername "$domain" -showcerts </dev/null 2>/dev/null | openssl crl2pkcs7 -nocrl -certfile /dev/stdin 2>/dev/null | openssl pkcs7 -print_certs -noout -text 2>/dev/null)
    
    if [[ -n "$chain_info" ]]; then
        local cert_count=$(echo "$chain_info" | grep -c "Certificate:")
        echo "  Chain Length: $cert_count certificates"
        
        # Check for self-signed
        local is_self_signed=$(timeout "$TIMEOUT_SSL" openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null | sort | uniq | wc -l)
        
        if [[ "$is_self_signed" -eq 1 ]]; then
            echo "  Type: ⚠️  Self-signed certificate"
        else
            echo "  Type: ✅ CA-signed certificate"
        fi
    else
        echo "  ❌ Could not analyze certificate chain"
    fi
    
    echo
}
