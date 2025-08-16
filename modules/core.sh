#!/bin/bash

# Core module - Essential functions and constants
# Part of Enhanced Web Audit Script v2.1

# Constants and globals
declare -g SCRIPT_VERSION="2.1"
declare -g SCRIPT_NAME="Enhanced Web Audit Script"
declare -g MIN_BASH_VERSION=4

# Colors for terminal output
declare -g RED='\033[0;31m'
declare -g GREEN='\033[0;32m'
declare -g YELLOW='\033[1;33m'
declare -g BLUE='\033[0;34m'
declare -g CYAN='\033[0;36m'
declare -g MAGENTA='\033[0;35m'
declare -g NC='\033[0m'

# Performance benchmarking variables
declare -gA benchmark_times=()
declare -g benchmark_start_time=""

# Rate limiting for external requests
declare -gA request_timestamps=()
declare -gA request_counts=()

# Configuration variables with defaults
declare -g TIMEOUT_DNS=8
declare -g TIMEOUT_HTTP=15
declare -g TIMEOUT_WHOIS=12
declare -g TIMEOUT_SSL=10
declare -g MAX_RETRIES=3
declare -g MAX_REDIRECTS=5
declare -g USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
declare -g CONFIG_FILE="${HOME}/.auditweb.conf"
declare -g LOG_LEVEL="${LOG_LEVEL:-INFO}"
declare -g LOG_FILE="${LOG_FILE:-}"
declare -g DEBUG="${DEBUG:-0}"

# Check bash version compatibility
check_bash_version() {
    if [[ ${BASH_VERSION%%.*} -lt $MIN_BASH_VERSION ]]; then
        echo -e "${RED}[ERROR]${NC} Bash version $MIN_BASH_VERSION or higher required. Current: $BASH_VERSION" >&2
        exit 1
    fi
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

# Logging functions
log_error() { log_with_level "ERROR" "$1"; }
log_warning() { log_with_level "WARN" "$1"; }
log_section() { log_with_level "INFO" "$1"; }
log_debug() { log_with_level "DEBUG" "$1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

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

# Progress tracking
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

# Sanitize output to prevent injection
sanitize_output() {
    local input="$1"
    echo "$input" | tr -d '\0-\037\177' | head -c 1000
}

# JSON escaping
json_escape() {
    local string="$1"
    echo "$string" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
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

# Module initialization
check_bash_version
