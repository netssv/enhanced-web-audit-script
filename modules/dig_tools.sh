#!/bin/bash

# Advanced Dig Tools Module
# Part of Enhanced Web Audit Script v2.1

# Source core module
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Advanced DNS analysis using dig
advanced_dig_analysis() {
    local domain="$1"
    
    echo -e "${GREEN}== Advanced DNS Analysis (dig) ==${NC}"
    
    # DNS trace from root servers
    echo "DNS Resolution Path (Trace):"
    if command -v dig >/dev/null 2>&1; then
        local trace_output=$(timeout 15 dig +trace +short "$domain" A 2>/dev/null | tail -10)
        if [[ -n "$trace_output" ]]; then
            echo "$trace_output" | while read -r line; do
                echo "  $line"
            done
        else
            echo "  Could not perform DNS trace"
        fi
    fi
    echo
    
    # DNS response times from multiple servers
    echo "DNS Server Performance Analysis:"
    local dns_servers=("8.8.8.8" "1.1.1.1" "9.9.9.9" "77.88.8.8")
    local server_names=("Google" "Cloudflare" "Quad9" "Yandex")
    
    for i in "${!dns_servers[@]}"; do
        local server="${dns_servers[$i]}"
        local name="${server_names[$i]}"
        
        # Measure DNS resolution time
        local start_time=$(date +%s.%N)
        local result=$(timeout 5 dig @"$server" +short "$domain" A 2>/dev/null)
        local end_time=$(date +%s.%N)
        
        if [[ -n "$result" ]]; then
            local response_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
            printf "  %-12s [%s]: %6.3fs -> %s\n" "$name" "$server" "$response_time" "$(echo "$result" | head -1)"
        else
            printf "  %-12s [%s]: TIMEOUT\n" "$name" "$server"
        fi
    done
    echo
    
    # DNSSEC validation
    echo "DNSSEC Analysis:"
    if command -v dig >/dev/null 2>&1; then
        local dnssec_result=$(timeout 10 dig +dnssec +short "$domain" A 2>/dev/null)
        local ad_flag=$(timeout 10 dig +adflag "$domain" A 2>/dev/null | grep -o "flags:.*ad" || echo "")
        
        if [[ -n "$ad_flag" ]]; then
            echo "  DNSSEC: ✅ Validated (AD flag set)"
        elif [[ "$dnssec_result" == *"RRSIG"* ]]; then
            echo "  DNSSEC: ⚠️  Signed but not validated"
        else
            echo "  DNSSEC: ❌ Not signed"
        fi
        
        # Check for DNSKEY records
        local dnskey=$(timeout 10 dig +short "$domain" DNSKEY 2>/dev/null)
        if [[ -n "$dnskey" ]]; then
            local key_count=$(echo "$dnskey" | wc -l)
            echo "  DNSKEY Records: $key_count found"
        else
            echo "  DNSKEY Records: None found"
        fi
    fi
    echo
    
    # Comprehensive record analysis
    echo "DNS Record Types Analysis:"
    local record_types=("A" "AAAA" "MX" "NS" "TXT" "CNAME" "SOA" "CAA" "SRV")
    
    for record_type in "${record_types[@]}"; do
        local records=$(timeout 5 dig +short "$domain" "$record_type" 2>/dev/null)
        local count=$(echo "$records" | grep -c . 2>/dev/null || echo "0")
        
        if [[ -n "$records" && "$count" -gt 0 ]]; then
            printf "  %-6s: %2d records\n" "$record_type" "$count"
            
            # Show important records inline
            case "$record_type" in
                "MX")
                    echo "$records" | head -3 | while read -r line; do
                        echo "         $line"
                    done
                    ;;
                "TXT")
                    echo "$records" | grep -E "(spf|dkim|dmarc)" | head -2 | while read -r line; do
                        echo "         $line"
                    done
                    ;;
                "CAA")
                    echo "$records" | head -2 | while read -r line; do
                        echo "         $line"
                    done
                    ;;
            esac
        else
            printf "  %-6s: None\n" "$record_type"
        fi
    done
    echo
    
    # Reverse DNS lookup
    echo "Reverse DNS Analysis:"
    local a_records=$(timeout 5 dig +short "$domain" A 2>/dev/null)
    if [[ -n "$a_records" ]]; then
        echo "$a_records" | head -3 | while read -r ip; do
            if [[ -n "$ip" ]]; then
                local reverse=$(timeout 5 dig +short -x "$ip" 2>/dev/null)
                if [[ -n "$reverse" ]]; then
                    echo "  $ip -> $reverse"
                else
                    echo "  $ip -> No reverse DNS"
                fi
            fi
        done
    else
        echo "  No A records found for reverse lookup"
    fi
    echo
}

# DNS cache analysis
analyze_dns_cache() {
    local domain="$1"
    
    echo "DNS Cache & TTL Analysis:"
    
    # Get TTL information
    local full_response=$(timeout 10 dig "$domain" A 2>/dev/null)
    if [[ -n "$full_response" ]]; then
        echo "TTL Information:"
        echo "$full_response" | grep -E "^$domain|^[[:space:]]*[0-9]" | head -5 | while read -r line; do
            if [[ "$line" =~ [0-9]+.*IN.*A ]]; then
                local ttl=$(echo "$line" | awk '{print $2}')
                echo "  A Record TTL: ${ttl}s"
                
                # Convert to human readable
                if [[ $ttl -ge 86400 ]]; then
                    local days=$((ttl / 86400))
                    echo "               (${days} day(s))"
                elif [[ $ttl -ge 3600 ]]; then
                    local hours=$((ttl / 3600))
                    echo "               (${hours} hour(s))"
                elif [[ $ttl -ge 60 ]]; then
                    local minutes=$((ttl / 60))
                    echo "               (${minutes} minute(s))"
                fi
                break
            fi
        done
        
        # Authority section
        local authority=$(echo "$full_response" | grep -A10 "AUTHORITY SECTION:" | grep -v "AUTHORITY SECTION:" | head -3)
        if [[ -n "$authority" ]]; then
            echo
            echo "Authoritative Servers:"
            echo "$authority" | while read -r line; do
                echo "  $line"
            done
        fi
    fi
    echo
}

# DNS security analysis
analyze_dns_security() {
    local domain="$1"
    
    echo "DNS Security Features:"
    
    # Check for CAA records (Certificate Authority Authorization)
    local caa_records=$(timeout 10 dig +short "$domain" CAA 2>/dev/null)
    if [[ -n "$caa_records" ]]; then
        echo "  CAA Records: ✅ Present"
        echo "$caa_records" | while read -r record; do
            echo "    $record"
        done
    else
        echo "  CAA Records: ❌ None (allows any CA to issue certificates)"
    fi
    
    # Check SPF records
    local spf_record=$(timeout 10 dig +short "$domain" TXT 2>/dev/null | grep -i spf)
    if [[ -n "$spf_record" ]]; then
        echo "  SPF Record: ✅ Present"
        echo "    $spf_record"
    else
        echo "  SPF Record: ❌ None (email spoofing possible)"
    fi
    
    # Check DMARC records
    local dmarc_record=$(timeout 10 dig +short "_dmarc.$domain" TXT 2>/dev/null)
    if [[ -n "$dmarc_record" ]]; then
        echo "  DMARC Record: ✅ Present"
        echo "    $dmarc_record"
    else
        echo "  DMARC Record: ❌ None (email authentication weak)"
    fi
    
    echo
}

# Quick dig analysis for fast mode
quick_dig_analysis() {
    local domain="$1"
    
    echo "Quick DNS Analysis:"
    
    # Fast multi-server lookup
    local dns_servers=("8.8.8.8" "1.1.1.1")
    for server in "${dns_servers[@]}"; do
        local result=$(timeout 3 dig @"$server" +short "$domain" A 2>/dev/null | head -1)
        if [[ -n "$result" ]]; then
            echo "  $server: $result"
        fi
    done
    
    # Quick DNSSEC check
    local dnssec=$(timeout 5 dig +short +dnssec "$domain" A 2>/dev/null | grep -c RRSIG)
    if [[ $dnssec -gt 0 ]]; then
        echo "  DNSSEC: ✅ Signed"
    else
        echo "  DNSSEC: ❌ Not signed"
    fi
    
    echo
}
