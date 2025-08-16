#!/bin/bash

# Performance module - All performance testing and benchmarking
# Part of Enhanced Web Audit Script v2.1

# Source core module
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Show performance benchmarks report
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

# Performance testing function
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
        local curl_exit_code=$?
        end_benchmark "http_request_$i"
        
        if [[ $curl_exit_code -eq 0 && -n "$response_time" ]]; then
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
        # Use the resolve_domain function from dns module
        if command -v resolve_domain >/dev/null 2>&1; then
            resolve_domain "$domain" >/dev/null 2>&1
        else
            # Fallback if function not available
            timeout "$TIMEOUT_DNS" dig +short "$domain" A >/dev/null 2>&1
        fi
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

# Comprehensive compression analysis
analyze_compression() {
    local url="$1"
    
    echo "Compression Analysis:"
    
    # Test without compression
    local uncompressed_response=$(timeout 15 curl -s \
        -H "User-Agent: $USER_AGENT" \
        -H "Accept-Encoding: identity" \
        -w "%{size_download},%{http_code},%{content_type}" \
        -o /dev/null \
        "$url" 2>/dev/null)
    
    # Test with compression
    local compressed_response=$(timeout 15 curl -s \
        -H "User-Agent: $USER_AGENT" \
        -H "Accept-Encoding: gzip, deflate, br" \
        -w "%{size_download},%{http_code},%{content_type}" \
        -o /dev/null \
        "$url" 2>/dev/null)
    
    # Get compression headers
    local compression_headers=$(timeout 15 curl -s -I \
        -H "User-Agent: $USER_AGENT" \
        -H "Accept-Encoding: gzip, deflate, br" \
        "$url" 2>/dev/null)
    
    if [[ -n "$uncompressed_response" && -n "$compressed_response" ]]; then
        IFS=',' read -r uncompressed_size uncompressed_code uncompressed_type <<< "$uncompressed_response"
        IFS=',' read -r compressed_size compressed_code compressed_type <<< "$compressed_response"
        
        # Detect compression type
        local compression_type=""
        if echo "$compression_headers" | grep -qi "content-encoding.*br"; then
            compression_type="Brotli"
        elif echo "$compression_headers" | grep -qi "content-encoding.*gzip"; then
            compression_type="Gzip"
        elif echo "$compression_headers" | grep -qi "content-encoding.*deflate"; then
            compression_type="Deflate"
        fi
        
        # Calculate sizes and savings
        local uncompressed_kb=$(echo "scale=1; $uncompressed_size / 1024" | bc -l 2>/dev/null || echo "0")
        local compressed_kb=$(echo "scale=1; $compressed_size / 1024" | bc -l 2>/dev/null || echo "0")
        
        printf "  %-20s: %8.1f KB\n" "Uncompressed Size" "$uncompressed_kb"
        
        if [[ -n "$compression_type" ]]; then
            printf "  %-20s: %8.1f KB\n" "Compressed Size" "$compressed_kb"
            printf "  %-20s: %8s\n" "Compression Type" "$compression_type"
            
            # Calculate compression ratio
            if [[ "$uncompressed_size" -gt 0 ]]; then
                local savings=$(echo "scale=1; ($uncompressed_size - $compressed_size) * 100 / $uncompressed_size" | bc -l 2>/dev/null || echo "0")
                local ratio=$(echo "scale=1; $uncompressed_size / $compressed_size" | bc -l 2>/dev/null || echo "1")
                printf "  %-20s: %8.1f%%\n" "Size Reduction" "$savings"
                printf "  %-20s: %8.1f:1\n" "Compression Ratio" "$ratio"
            fi
            
            echo "  ✅ Compression enabled ($compression_type)"
        else
            printf "  %-20s: %8.1f KB\n" "Page Size" "$uncompressed_kb"
            
            # Analyze if compression would be beneficial
            if [[ "$uncompressed_size" -lt 1024 ]]; then
                echo "  ❓ No compression — page is very small (<1 KB), compression may not be beneficial"
            elif [[ "$uncompressed_size" -lt 5120 ]]; then
                echo "  ❓ No compression — page is small (<5 KB), minimal benefit expected"
            else
                echo "  ❌ No compression detected — should use Gzip/Brotli to reduce size"
            fi
        fi
        
        # Content type analysis
        if echo "$uncompressed_type" | grep -qi "text/\|application/javascript\|application/json\|application/xml"; then
            echo "  💡 Content type supports compression well"
        elif echo "$uncompressed_type" | grep -qi "image/\|video/\|audio/"; then
            echo "  💡 Media content - compression may not be effective"
        fi
        
    else
        echo "  ❌ Could not analyze compression (connection failed)"
    fi
    
    echo
}

# Quick performance check (lighter version)
quick_performance_check() {
    local url="$1"
    
    echo "Quick Performance Check:"
    
    # Single request timing
    local response_time=$(timeout 15 curl -s -o /dev/null -w "%{time_total}" \
        -H "User-Agent: $USER_AGENT" \
        "$url" 2>/dev/null)
    
    if [[ -n "$response_time" ]]; then
        printf "  Response Time: %8.3fs\n" "$response_time"
        
        # Quick rating
        if (( $(echo "$response_time < 1.0" | bc -l 2>/dev/null || echo 0) )); then
            echo "  Rating: Good"
        elif (( $(echo "$response_time < 3.0" | bc -l 2>/dev/null || echo 0) )); then
            echo "  Rating: Average"
        else
            echo "  Rating: Slow"
        fi
    else
        echo "  Could not measure response time"
    fi
    
    echo
}
