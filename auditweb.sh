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
source "$SCRIPT_DIR/modules/ssl.sh"
source "$SCRIPT_DIR/modules/dig_tools.sh"
source "$SCRIPT_DIR/modules/curl_tools.sh"

# =============================================================================
# GLOBAL VARIABLE DECLARATIONS
# =============================================================================

# Global audit variables (will be set during execution)
declare -g DOMAIN=""
declare -g URL=""
declare -g IP=""
declare -g FORMAT="comprehensive"
declare -g TIMESTAMP=""
declare -g REPORT_BASE=""
declare -g MX_RECORDS=""
declare -g NS_RECORDS=""
declare -g TXT_RECORDS=""

# =============================================================================
# HELP AND USAGE INFORMATION
# =============================================================================

show_help() {
    cat << EOF
Enhanced Web Audit Script v$SCRIPT_VERSION (Modular)
==================================================

USAGE:
    $0 <URL> [options]

ARGUMENTS:
    URL         Domain or URL to audit (required)
                Examples: example.com, https://example.com, subdomain.example.com

OPTIONS:
    --quick     Fast audit with essential checks (DNS, SSL, performance)
    --debug     Enable verbose debug mode
    --config    Show configuration file location
    --version   Show version information
    --help      Show this help message
    --self-test Verify script functionality

SPECIALIZED COMMANDS:
    $0 --dns-check <domain> [record_type]      # Standalone DNS propagation check
    $0 --dns-monitor <domain> [interval] [max] # Monitor DNS changes over time

AUDIT MODES:
    Default Mode: Comprehensive analysis including:
                 • DNS resolution and propagation (16 global servers)
                 • SSL certificate lifecycle and security analysis
                 • Advanced dig tools with DNSSEC validation
                 • HTTP protocol analysis with curl tools
                 • Web technology and hosting detection
                 • Performance benchmarking and optimization
                 • Security headers and compression analysis

    Quick Mode:  Essential checks for rapid assessment:
                • Basic connectivity and DNS resolution
                • SSL certificate expiry monitoring
                • Core performance metrics
                • Basic security validation

EXAMPLES:
    $0 github.com                     # Full comprehensive audit
    $0 github.com --quick             # Quick essential checks
    $0 example.com --debug            # Full audit with verbose output
    $0 --dns-check example.com        # DNS propagation only
    $0 --dns-monitor example.com 60 5 # Monitor DNS for 5 checks, 60s intervals
    $0 --self-test                    # Verify script functionality

MODULAR ARCHITECTURE:
    • core.sh        - Core utilities and benchmarking
    • config.sh      - Configuration and validation
    • dns.sh         - DNS analysis with global propagation
    • ssl.sh         - SSL certificate lifecycle monitoring
    • dig_tools.sh   - Advanced DNS analysis with DNSSEC
    • curl_tools.sh  - HTTP protocol and security analysis
    • http.sh        - Web technology detection
    • performance.sh - Performance testing and optimization
    • hosting.sh     - Hosting provider identification

For more information: https://github.com/netssv/enhanced-web-audit-script

EOF
    exit 1
}

# =============================================================================
# AUDIT EXECUTION FUNCTIONS
# =============================================================================

# Quick audit mode - Essential checks for rapid assessment
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
    echo -e "${CYAN}Mode:${NC} Quick Essential Checks"
    echo

    # 1. CONNECTIVITY CHECK
    echo -e "${GREEN}== Connectivity & Basic DNS ==${NC}"
    start_benchmark "quick_connectivity"
    if check_connectivity "$url"; then
        log_success "✅ Website is accessible"
    else
        log_warning "⚠️ Website accessibility issues detected"
    fi
    echo "📍 A record: $ip"
    end_benchmark "quick_connectivity"
    echo

    # 2. SSL CERTIFICATE QUICK CHECK
    if [[ "$url" == https://* ]]; then
        echo -e "${GREEN}== SSL Certificate Status ==${NC}"
        start_benchmark "quick_ssl"
        quick_ssl_check "$url"
        end_benchmark "quick_ssl"
        echo
    fi

    # 3. DNS PROPAGATION CHECK
    echo -e "${GREEN}== DNS Propagation (Quick) ==${NC}"
    start_benchmark "quick_dns_propagation"
    quick_dns_propagation "$domain"
    end_benchmark "quick_dns_propagation"
    echo

    # 4. PERFORMANCE ESSENTIALS
    echo -e "${GREEN}== Performance Essentials ==${NC}"
    start_benchmark "quick_performance"
    quick_performance_check "$url"
    end_benchmark "quick_performance"
    echo

    # 5. HOSTING QUICK CHECK
    echo -e "${GREEN}== Hosting & Technology ==${NC}"
    start_benchmark "quick_hosting"
    quick_hosting_check "$domain" "$ip" "$url" "$url"
    end_benchmark "quick_hosting"
    echo

    # 6. ADVANCED TOOLS QUICK ANALYSIS
    echo -e "${GREEN}== Advanced Tools Quick Check ==${NC}"
    start_benchmark "quick_tools"
    
    # Quick dig analysis
    echo "🔍 DNS Analysis:"
    quick_dig_analysis "$domain"
    echo
    
    # Quick curl analysis  
    echo "🌐 HTTP Analysis:"
    quick_curl_analysis "$url"
    
    end_benchmark "quick_tools"
    echo

    # QUICK SUMMARY
    echo -e "${BLUE}=========================================="
    echo -e "         QUICK AUDIT SUMMARY"
    echo -e "==========================================${NC}"
    show_performance_report
    echo -e "${GREEN}✅ Quick audit completed - Essential checks done${NC}"
    echo -e "${CYAN}💡 For comprehensive analysis, run without --quick flag${NC}"
}

# Full comprehensive audit mode - Complete analysis
run_full_audit() {
    echo -e "${BLUE}=========================================="
    echo -e "      COMPREHENSIVE WEB AUDIT"
    echo -e "==========================================${NC}"
    echo -e "${CYAN}Domain:${NC} $DOMAIN"
    echo -e "${CYAN}URL:${NC} $URL"
    echo -e "${CYAN}IP Address:${NC} $IP"
    echo -e "${CYAN}Audit Date:${NC} $TIMESTAMP"
    echo -e "${CYAN}Audit Tool:${NC} $SCRIPT_NAME v$SCRIPT_VERSION (Modular)"
    echo -e "${CYAN}Mode:${NC} Comprehensive Analysis"
    echo

    # 1. DOMAIN AND DNS FOUNDATION
    echo -e "${GREEN}== 1. Domain & DNS Foundation ==${NC}"
    start_benchmark "domain_info"
    get_domain_info "$DOMAIN"
    
    if command -v dig >/dev/null 2>&1; then
        get_dns_info_parallel "$DOMAIN"
        echo
        check_dns_propagation "$DOMAIN"
    else
        log_warning "dig not available, using basic DNS resolution"
        echo "A record: $IP"
    fi
    end_benchmark "domain_info"
    echo

    # 2. SSL CERTIFICATE LIFECYCLE ANALYSIS
    if [[ "$URL" == https://* ]]; then
        echo -e "${GREEN}== 2. SSL Certificate Lifecycle ==${NC}"
        start_benchmark "ssl_analysis"
        analyze_ssl_certificate "$URL"
        echo
        analyze_ssl_protocols "$(echo "$URL" | sed 's|^https\?://||' | sed 's|/.*||' | sed 's|:.*||')"
        echo
        analyze_certificate_chain "$(echo "$URL" | sed 's|^https\?://||' | sed 's|/.*||' | sed 's|:.*||')"
        end_benchmark "ssl_analysis"
        echo
    fi

    # 3. ADVANCED DNS ANALYSIS WITH DIG TOOLS
    if command -v dig >/dev/null 2>&1; then
        echo -e "${GREEN}== 3. Advanced DNS Analysis ==${NC}"
        start_benchmark "advanced_dns"
        advanced_dig_analysis "$DOMAIN"
        echo
        analyze_dns_cache "$DOMAIN"
        echo
        analyze_dns_security "$DOMAIN"
        end_benchmark "advanced_dns"
        echo
    fi

    # 4. HTTP PROTOCOL AND SECURITY ANALYSIS
    echo -e "${GREEN}== 4. HTTP Protocol & Security ==${NC}"
    start_benchmark "advanced_http_analysis"
    advanced_curl_analysis "$URL"
    echo
    analyze_http_protocols "$URL"
    echo
    analyze_content_with_curl "$URL"
    end_benchmark "advanced_http_analysis"
    echo

    # 5. WEB TECHNOLOGIES AND HOSTING
    echo -e "${GREEN}== 5. Web Technologies & Hosting ==${NC}"
    start_benchmark "technology_detection"
    get_web_technologies "$URL"
    echo
    
    local headers=$(get_headers "$URL")
    local body=$(get_body_content "$URL")
    detect_hosting_provider "$DOMAIN" "$IP" "$headers" "$body"
    end_benchmark "technology_detection"
    echo

    # 6. PERFORMANCE AND OPTIMIZATION
    echo -e "${GREEN}== 6. Performance & Optimization ==${NC}"
    start_benchmark "performance_testing"
    run_performance_tests "$URL" "$DOMAIN"
    echo
    performance_test_with_curl "$URL"
    echo
    analyze_compression "$URL"
    end_benchmark "performance_testing"
    echo

    # 7. COMPREHENSIVE SUMMARY
    echo -e "${BLUE}=========================================="
    echo -e "         AUDIT SUMMARY & BENCHMARKS"
    echo -e "==========================================${NC}"
    show_performance_report
    
    echo -e "${BLUE}=========================================="
    echo -e "         COMPREHENSIVE AUDIT COMPLETED"
    echo -e "==========================================${NC}"
    echo -e "${GREEN}✅ Full analysis completed successfully${NC}"
    echo -e "${CYAN}📊 All modules executed with performance tracking${NC}"
}

# =============================================================================
# SELF-TEST AND VALIDATION
# =============================================================================

# Self-test function to verify script functionality
run_self_test() {
    echo -e "${BLUE}=========================================="
    echo -e "         SYSTEM SELF-TEST"
    echo -e "==========================================${NC}"
    echo "Testing modular script functionality..."
    echo
    
    local test_domain="google.com"
    local tests_passed=0
    local total_tests=8
    
    # Test 1: Module loading verification
    echo "🔧 Testing module loading..."
    if [[ -f "$MODULES_DIR/core.sh" && -f "$MODULES_DIR/dns.sh" && -f "$MODULES_DIR/ssl.sh" ]]; then
        echo "   ✅ All core modules loaded successfully"
        ((tests_passed++))
    else
        echo "   ❌ Module loading failed - missing required modules"
    fi
    
    # Test 2: Domain resolution capability
    echo "🌐 Testing domain resolution..."
    if resolve_domain "$test_domain" >/dev/null; then
        echo "   ✅ Domain resolution working correctly"
        ((tests_passed++))
    else
        echo "   ❌ Domain resolution failed"
    fi
    
    # Test 3: HTTP connectivity
    echo "🔗 Testing HTTP connectivity..."
    if check_connectivity "https://$test_domain" >/dev/null 2>&1; then
        echo "   ✅ HTTP connectivity test passed"
        ((tests_passed++))
    else
        echo "   ❌ HTTP connectivity test failed"
    fi
    
    # Test 4: SSL tools availability
    echo "🔒 Testing SSL analysis tools..."
    if command -v openssl >/dev/null 2>&1; then
        echo "   ✅ OpenSSL available for SSL analysis"
        ((tests_passed++))
    else
        echo "   ❌ OpenSSL not available (SSL analysis will be limited)"
    fi
    
    # Test 5: DNS tools availability
    echo "🔍 Testing DNS analysis tools..."
    if command -v dig >/dev/null 2>&1; then
        echo "   ✅ Dig tool available for advanced DNS analysis"
        ((tests_passed++))
    else
        echo "   ❌ Dig tool not available (DNS analysis will be basic)"
    fi
    
    # Test 6: Performance calculation tools
    echo "📊 Testing performance calculation..."
    if command -v bc >/dev/null 2>&1; then
        echo "   ✅ Performance calculation tools available"
        ((tests_passed++))
    else
        echo "   ❌ Performance calculation tools missing (bc required)"
    fi
    
    # Test 7: Configuration loading
    echo "⚙️  Testing configuration system..."
    if load_and_validate_config >/dev/null 2>&1; then
        echo "   ✅ Configuration system working"
        ((tests_passed++))
    else
        echo "   ❌ Configuration system failed"
    fi
    
    # Test 8: Benchmark system
    echo "⏱️  Testing benchmark system..."
    start_benchmark "self_test"
    sleep 0.1
    end_benchmark "self_test"
    if [[ -n "${benchmark_times[self_test]}" ]]; then
        echo "   ✅ Benchmark system operational"
        ((tests_passed++))
    else
        echo "   ❌ Benchmark system failed"
    fi
    
    echo
    echo -e "${BLUE}=========================================="
    echo -e "         SELF-TEST RESULTS"
    echo -e "==========================================${NC}"
    echo "Tests completed: $tests_passed/$total_tests passed"
    
    if [[ $tests_passed -eq $total_tests ]]; then
        echo -e "${GREEN}✅ All tests passed - System ready for audits${NC}"
        return 0
    elif [[ $tests_passed -ge 6 ]]; then
        echo -e "${YELLOW}⚠️  Most tests passed - System functional with limitations${NC}"
        return 0
    else
        echo -e "${RED}❌ Multiple test failures - Please check dependencies${NC}"
        return 1
    fi
}

# =============================================================================
# ARGUMENT PARSING AND VALIDATION
# =============================================================================

# Parse and validate command line arguments
parse_arguments() {
    # Handle special commands first
    case "${1:-}" in
        --help|-h) 
            show_help ;;
        --version|-v) 
            echo "$SCRIPT_NAME v$SCRIPT_VERSION (Modular Architecture)"
            echo "Enhanced Web Audit Script with SSL, DNS, and HTTP analysis"
            exit 0 ;;
        --config) 
            echo "Configuration file: $CONFIG_FILE"
            echo "Modules directory: $MODULES_DIR"
            exit 0 ;;
        --self-test) 
            run_self_test
            exit $? ;;
        --dns-check) 
            shift
            local domain="${1:-}"
            local record_type="${2:-A}"
            if [[ -z "$domain" ]]; then
                echo "❌ Error: Domain required for DNS check"
                echo "Usage: $0 --dns-check <domain> [record_type]"
                exit 1
            fi
            echo "🔍 Running standalone DNS propagation check for $domain..."
            check_dns_propagation "$domain" "$record_type"
            exit $? ;;
        --dns-monitor)
            shift
            local domain="${1:-}"
            local interval="${2:-60}"
            local max_checks="${3:-10}"
            if [[ -z "$domain" ]]; then
                echo "❌ Error: Domain required for DNS monitoring"
                echo "Usage: $0 --dns-monitor <domain> [interval] [max_checks]"
                exit 1
            fi
            echo "📊 Starting DNS monitoring for $domain (${max_checks} checks, ${interval}s intervals)..."
            monitor_dns_changes "$domain" "A" "$interval" "$max_checks"
            exit $? ;;
        "") 
            show_help ;;
    esac
    
    # Parse main command arguments
    local input_url="$1"
    local quick_mode=false
    local debug_mode=false
    
    # Process additional arguments
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quick)
                quick_mode=true
                ;;
            --debug)
                debug_mode=true
                DEBUG=1
                ;;
            *)
                echo "❌ Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
    
    # Validate and process URL
    if [[ "$input_url" =~ ^https?:// ]]; then
        URL="$input_url"
        DOMAIN=$(extract_domain "$input_url")
    else
        DOMAIN=$(extract_domain "$input_url")
        if [[ $? -ne 0 ]]; then
            log_error "Invalid domain format: $input_url"
            echo "Valid formats: example.com, https://example.com, subdomain.example.com"
            exit 1
        fi
        URL="https://$DOMAIN"
    fi
    
    # Set audit mode
    if [[ "$quick_mode" == true ]]; then
        FORMAT="quick"
        log_section "Quick audit mode selected"
    else
        FORMAT="comprehensive"
        log_section "Comprehensive audit mode selected"
    fi
    
    [[ "$debug_mode" == true ]] && log_section "Debug mode enabled"
    
    # Set global variables
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    REPORT_BASE="web_audit_${DOMAIN//./_}"
    
    # Export for use in other functions
    export DOMAIN URL FORMAT DEBUG TIMESTAMP REPORT_BASE
}
# =============================================================================
# MAIN EXECUTION FLOW
# =============================================================================

# Main execution function with improved flow
main() {
    # Parse and validate arguments
    parse_arguments "$@"
    
    echo -e "${BLUE}=========================================="
    echo -e "    ENHANCED WEB AUDIT SCRIPT v$SCRIPT_VERSION"
    echo -e "==========================================${NC}"
    echo -e "${CYAN}🎯 Target:${NC} $DOMAIN"
    echo -e "${CYAN}🔗 URL:${NC} $URL"  
    echo -e "${CYAN}📅 Started:${NC} $TIMESTAMP"
    echo -e "${CYAN}⚙️  Mode:${NC} $FORMAT"
    [[ "$DEBUG" == "1" ]] && echo -e "${CYAN}🐛 Debug:${NC} Enabled"
    echo

    # Step 1: Domain Resolution
    echo -e "${GREEN}== Initial Domain Resolution ==${NC}"
    start_benchmark "domain_resolution"
    IP=$(resolve_domain "$DOMAIN")
    end_benchmark "domain_resolution"
    
    if [[ -z "$IP" ]]; then
        log_error "❌ Could not resolve domain $DOMAIN"
        log_section "🔍 Continuing with DNS-only analysis..."
        IP="N/A"
    else
        log_success "✅ Domain resolved: $DOMAIN → $IP"
    fi
    echo

    # Step 2: Connectivity Check
    echo -e "${GREEN}== Website Connectivity ==${NC}"
    start_benchmark "connectivity_check"
    if check_connectivity "$URL"; then
        log_success "✅ Website is accessible and responding"
    else
        log_warning "⚠️  Website connectivity issues detected"
        log_section "🔍 Continuing with available analyses..."
    fi
    end_benchmark "connectivity_check"
    echo

    # Step 3: Execute Audit Based on Mode
    case "$FORMAT" in
        quick)
            log_section "🚀 Executing Quick Audit (Essential Checks)"
            run_quick_audit "$DOMAIN" "$URL" "$IP"
            ;;
        comprehensive)
            log_section "🔬 Executing Comprehensive Audit (Full Analysis)"
            run_full_audit
            ;;
        *)
            log_warning "⚠️  Unknown format '$FORMAT', defaulting to comprehensive"
            run_full_audit
            ;;
    esac

    # Final completion message
    echo
    echo -e "${BLUE}=========================================="
    echo -e "           AUDIT COMPLETED"
    echo -e "==========================================${NC}"
    log_success "✅ Web audit completed successfully for $DOMAIN"
    echo -e "${CYAN}🕒 Finished at:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}📊 Performance data available above${NC}"
    echo
}

# =============================================================================
# SCRIPT INITIALIZATION AND CLEANUP
# =============================================================================

# Enhanced error handling and cleanup
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo
        log_error "Script exited with error code $exit_code"
        echo -e "${YELLOW}💡 Try running with --debug for more information${NC}"
        echo -e "${CYAN}🆘 Use --help for usage information${NC}"
    fi
    exit $exit_code
}

# Initialize script environment
initialize_script() {
    # Set up signal handlers for clean exit
    trap cleanup EXIT INT TERM
    
    # Validate dependencies and load configuration
    if ! validate_dependencies; then
        log_error "Dependency validation failed"
        exit 1
    fi
    
    if ! load_and_validate_config; then
        log_error "Configuration loading failed"
        exit 1
    fi
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Initialize and run
initialize_script
main "$@"
