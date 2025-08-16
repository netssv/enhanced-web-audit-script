#!/bin/bash

# Enhanced Web Audit Script v2.1 - Modular Version
# Author: netss - Enhanced by Web Analyst
# GitHub: https://github.com/netssv
# Description: A robust, modular CLI tool for comprehensive web audits

# Resolve the symlink to get the real script path
SOURCE="${BASH_SOURCE[0]}"
# While $SOURCE is a symlink, resolve it
while [ -L "$SOURCE" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    # If $SOURCE was a relative symlink, resolve it relative to the path where the symlink file was located
    [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done
# Final script directory
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"


# Source modules from the same directory as the script
source "$SCRIPT_DIR/modules/core.sh"
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/dns.sh"
source "$SCRIPT_DIR/modules/http.sh"
source "$SCRIPT_DIR/modules/performance.sh"
source "$SCRIPT_DIR/modules/hosting.sh"

# Global audit variables
declare -g DOMAIN=""
declare -g URL=""
declare -g IP=""
declare -g FORMAT="terminal"
declare -g TIMESTAMP=""
declare -g REPORT_BASE=""
declare -g MX_RECORDS=""
declare -g NS_RECORDS=""
declare -g TXT_RECORDS=""

# Show help
show_help() {
    cat << EOF
Enhanced Web Audit Script v$SCRIPT_VERSION (Modular)
==================================================

USAGE:
    $0 <URL> [format] [options]

ARGUMENTS:
    URL         Domain or URL to audit (required)
                Examples: example.com, https://example.com, subdomain.example.com

    format      Output format (optional, default: terminal)
                Options: terminal, html, txt, json, quick

OPTIONS:
    debug       Enable debug mode for verbose output
    --config    Show configuration file location
    --version   Show version information
    --help      Show this help message
    --self-test Run self-test to verify script functionality
    --quick     Run quick audit (faster, less comprehensive)
    --dns-check Run standalone DNS propagation check
    --dns-monitor Monitor DNS changes over time

DNS COMMANDS:
    $0 --dns-check <domain> [record_type]      # Check DNS propagation
    $0 --dns-monitor <domain> [interval] [max] # Monitor DNS changes

FEATURES:
    • Modular architecture for better performance
    • Comprehensive DNS analysis with parallel queries
    • SSL certificate validation and security
    • Web technology detection (CMS, frameworks, etc.)
    • Hosting provider identification
    • Performance benchmarking and testing
    • Security headers analysis
    • Quick audit mode for fast checks

EXAMPLES:
    $0 https://google.com
    $0 example.com quick          # Fast audit with DNS propagation
    $0 example.com json
    $0 subdomain.example.com terminal debug
    $0 --self-test
    $0 --dns-check example.com    # Check DNS propagation
    $0 --dns-monitor example.com 60 10  # Monitor DNS for 10 minutes

MODULAR STRUCTURE:
    • core.sh        - Core functions and utilities
    • config.sh      - Configuration and validation
    • dns.sh         - DNS analysis and resolution
    • http.sh        - HTTP checks and technology detection
    • performance.sh - Performance testing and benchmarking
    • hosting.sh     - Hosting provider detection

EOF
    exit 1
}

# Quick audit mode (faster, less comprehensive)
run_quick_audit() {
    local domain="$1"
    local url="$2"
    local ip="$3"
    
    echo -e "${BLUE}=========================================="
    echo -e "         QUICK WEB AUDIT"
    echo -e "==========================================${NC}"
    echo -e "${CYAN}Domain:${NC} $domain"
    echo -e "${CYAN}URL:${NC} $url"
    echo -e "${CYAN}IP:${NC} $ip"
    echo
    
    # Quick connectivity check
    if check_connectivity "$url"; then
        log_success "Website is accessible"
    else
        log_warning "Website accessibility issues"
    fi
    echo
    
    # Quick performance check
    quick_performance_check "$url"
    
    # Quick hosting check
    quick_hosting_check "$domain" "$ip" "$url" "$url"
    
    # Basic DNS info
    echo "Basic DNS Info:"
    echo "A record: $ip"
    
    # Quick DNS propagation check
    quick_dns_propagation "$domain"
    echo
    
    # Quick technology detection
    echo "Quick Technology Check:"
    local headers=$(get_headers "$url" 2>/dev/null)
    if [[ -n "$headers" ]]; then
        local server=$(echo "$headers" | grep -iE "^server:" | cut -d: -f2- | sed 's/^[[:space:]]*//')
        [[ -n "$server" ]] && echo "  Web Server: $server"
        
        # HTTP/2 check
        if echo "$headers" | grep -qi "http/2"; then
            echo "  HTTP/2: ✅"
        else
            echo "  HTTP/2: ❌"
        fi
    else
        echo "  Could not retrieve headers"
    fi
    
    echo
    echo -e "${GREEN}Quick audit completed${NC}"
}

# Full audit mode
run_full_audit() {
    echo -e "${BLUE}=========================================="
    echo -e "         COMPREHENSIVE WEB AUDIT"
    echo -e "==========================================${NC}"
    echo -e "${CYAN}Domain:${NC} $DOMAIN"
    echo -e "${CYAN}URL:${NC} $URL"
    echo -e "${CYAN}Date:${NC} $TIMESTAMP"
    echo -e "${CYAN}IP:${NC} $IP"
    echo -e "${CYAN}Audit Tool:${NC} $SCRIPT_NAME v$SCRIPT_VERSION (Modular)"
    echo

    # Domain information
    echo -e "${GREEN}== Domain Information ==${NC}"
    start_benchmark "domain_info"
    get_domain_info "$DOMAIN"
    end_benchmark "domain_info"
    echo

    # Web technologies
    echo -e "${GREEN}== Web Technologies ==${NC}"
    start_benchmark "technology_detection"
    get_web_technologies "$URL"
    end_benchmark "technology_detection"
    echo

    # Hosting provider analysis
    start_benchmark "hosting_detection"
    local headers=$(get_headers "$URL")
    local body=$(get_body_content "$URL")
    detect_hosting_provider "$DOMAIN" "$IP" "$headers" "$body"
    end_benchmark "hosting_detection"
    
    # DNS analysis with parallel queries
    start_benchmark "dns_analysis"
    if command -v dig >/dev/null 2>&1; then
        get_dns_info_parallel "$DOMAIN"
        
        # DNS propagation check
        echo
        check_dns_propagation "$DOMAIN"
    else
        log_warning "dig not available, using basic DNS resolution"
        echo "A record: $IP"
    fi
    end_benchmark "dns_analysis"
    
    # Performance testing
    start_benchmark "performance_testing"
    run_performance_tests "$URL" "$DOMAIN"
    end_benchmark "performance_testing"
    
    # Compression analysis
    start_benchmark "compression_analysis"
    analyze_compression "$URL"
    end_benchmark "compression_analysis"

    # Show performance benchmarks
    show_performance_report    echo -e "${BLUE}=========================================="
    echo -e "         AUDIT COMPLETED"
    echo -e "==========================================${NC}"
}

# Self-test function
run_self_test() {
    echo "Running self-test for modular script..."
    local test_domain="google.com"
    local tests_passed=0
    local total_tests=6
    
    # Test 1: Module loading
    if [[ -f "$MODULES_DIR/core.sh" && -f "$MODULES_DIR/dns.sh" ]]; then
        echo "✅ Module loading test passed"
        ((tests_passed++))
    else
        echo "❌ Module loading test failed"
    fi
    
    # Test 2: Domain resolution
    if resolve_domain "$test_domain" >/dev/null; then
        echo "✅ Domain resolution test passed"
        ((tests_passed++))
    else
        echo "❌ Domain resolution test failed"
    fi
    
    # Test 3: HTTP connectivity
    if check_connectivity "https://$test_domain" >/dev/null 2>&1; then
        echo "✅ HTTP connectivity test passed"
        ((tests_passed++))
    else
        echo "❌ HTTP connectivity test failed"
    fi
    
    # Test 4: Performance functions
    if command -v bc >/dev/null 2>&1; then
        echo "✅ Performance calculation test passed"
        ((tests_passed++))
    else
        echo "❌ Performance calculation test failed (bc missing)"
    fi
    
    # Test 5: Configuration loading
    if load_and_validate_config >/dev/null 2>&1; then
        echo "✅ Configuration test passed"
        ((tests_passed++))
    else
        echo "❌ Configuration test failed"
    fi
    
    # Test 6: Benchmark system
    start_benchmark "self_test"
    sleep 0.1
    end_benchmark "self_test"
    if [[ -n "${benchmark_times[self_test]}" ]]; then
        echo "✅ Benchmark system test passed"
        ((tests_passed++))
    else
        echo "❌ Benchmark system test failed"
    fi
    
    echo "Self-test completed: $tests_passed/$total_tests tests passed"
    [[ $tests_passed -eq $total_tests ]]
}

# Main execution function
main() {
    # Handle special arguments
    case "${1:-}" in
        --help|-h) show_help ;;
        --version|-v) echo "$SCRIPT_NAME v$SCRIPT_VERSION (Modular)"; exit 0 ;;
        --config) echo "Configuration file: $CONFIG_FILE"; exit 0 ;;
        --self-test) run_self_test; exit $? ;;
        --quick) shift; FORMAT="quick" ;;
        --dns-check) 
            shift
            local domain="${1:-}"
            local record_type="${2:-A}"
            if [[ -z "$domain" ]]; then
                echo "Error: Domain required for DNS check"
                echo "Usage: $0 --dns-check <domain> [record_type]"
                exit 1
            fi
            check_dns_propagation "$domain" "$record_type"
            exit $?
        ;;
        --dns-monitor)
            shift
            local domain="${1:-}"
            local interval="${2:-60}"
            local max_checks="${3:-10}"
            if [[ -z "$domain" ]]; then
                echo "Error: Domain required for DNS monitoring"
                echo "Usage: $0 --dns-monitor <domain> [interval] [max_checks]"
                exit 1
            fi
            monitor_dns_changes "$domain" "A" "$interval" "$max_checks"
            exit $?
        ;;
        "") show_help ;;
    esac
    
    local input_url="$1"
    FORMAT="${2:-${FORMAT:-terminal}}"
    
    # Check if quick mode is specified
    [[ "$2" == "quick" || "$FORMAT" == "quick" ]] && FORMAT="quick"
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
        html|txt|terminal|json|quick) ;;
        *) echo "Invalid format. Use: html, txt, terminal, json, quick"; exit 1 ;;
    esac
    
    # Global variables
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    REPORT_BASE="web_audit_${DOMAIN//./_}"
    MX_RECORDS=""
    NS_RECORDS=""
    TXT_RECORDS=""
    
    log_section "Starting audit for $DOMAIN (Mode: $FORMAT)"
    
    # Resolve domain to IP
    start_benchmark "domain_resolution"
    IP=$(resolve_domain "$DOMAIN")
    end_benchmark "domain_resolution"
    
    if [[ -z "$IP" ]]; then
        log_error "Could not resolve domain $DOMAIN"
        log_section "Continuing with DNS-only audit..."
    else
        log_success "Domain resolved: $DOMAIN -> $IP"
    fi
    
    # Check website connectivity
    start_benchmark "connectivity_check"
    if ! check_connectivity "$URL"; then
        log_warning "Website connectivity issues detected, continuing with available checks..."
    else
        log_success "Website is accessible"
    fi
    end_benchmark "connectivity_check"
    
    # Run audit based on format/mode
    case "$FORMAT" in
        quick)
            run_quick_audit "$DOMAIN" "$URL" "$IP"
            ;;
        terminal)
            run_full_audit
            ;;
        *)
            log_warning "Format $FORMAT not yet implemented in modular version"
            run_full_audit
            ;;
    esac
    
    log_success "Audit completed successfully"
}

# Enhanced error handling and cleanup
cleanup() {
    local exit_code=$?
    [[ $exit_code -ne 0 ]] && log_error "Script exited with error code $exit_code"
    exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Check dependencies and load configuration
validate_dependencies
load_and_validate_config

# Run main function
main "$@"
