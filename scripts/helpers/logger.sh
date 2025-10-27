#!/bin/bash

# Source colors if not already sourced
if [[ -z "${RED}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/colors.sh"
fi

# Log file configuration
LOG_FILE="${LOG_FILE:-/tmp/k8s-workshop-$(date +%Y%m%d-%H%M%S).log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Initialize log file
init_log() {
    mkdir -p "$(dirname "${LOG_FILE}")"
    echo "=== K8s Workshop Log - $(date) ===" > "${LOG_FILE}"
}

# Get timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Log to file
log_to_file() {
    echo "[$(get_timestamp)] $*" >> "${LOG_FILE}"
}

# Info message
log_info() {
    local message="$*"
    echo -e "${GREEN}[INFO]${NC} $(get_timestamp) - ${message}" >&2
    log_to_file "INFO: ${message}"
}

# Error message
log_error() {
    local message="$*"
    echo -e "${RED}[ERROR]${NC} $(get_timestamp) - ${message}" >&2
    log_to_file "ERROR: ${message}"
}

# Warning message
log_warn() {
    local message="$*"
    echo -e "${YELLOW}[WARN]${NC} $(get_timestamp) - ${message}" >&2
    log_to_file "WARN: ${message}"
}

# Success message
log_success() {
    local message="$*"
    echo -e "${GREEN}[SUCCESS]${NC} $(get_timestamp) - ${message}" >&2
    log_to_file "SUCCESS: ${message}"
}

# Debug message
log_debug() {
    if [[ "${LOG_LEVEL}" == "DEBUG" ]]; then
        local message="$*"
        echo -e "${CYAN}[DEBUG]${NC} $(get_timestamp) - ${message}" >&2
        log_to_file "DEBUG: ${message}"
    fi
}

# Step message (for progress tracking)
log_step() {
    local step_num=$1
    shift
    local message="$*"
    echo -e "${BLUE}[STEP ${step_num}]${NC} ${message}" >&2
    log_to_file "STEP ${step_num}: ${message}"
}

# Section header
log_section() {
    local section="$*"
    echo >&2
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}" >&2
    echo -e "${BOLD}${CYAN}║${NC} ${BOLD}${section}${NC}" >&2
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}" >&2
    echo >&2
    log_to_file "SECTION: ${section}"
}

# Separator line
log_separator() {
    echo -e "${DIM}────────────────────────────────────────────────────────────────${NC}" >&2
}

# Spinner function
spinner() {
    local pid=$1
    local message="${2:-Processing}"
    local spin='-\|/'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${BLUE}[${spin:$i:1}]${NC} ${message}"
        sleep 0.1
    done

    wait $pid
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        printf "\r${CHECK_MARK} ${message}\n"
    else
        printf "\r${CROSS_MARK} ${message} (failed)\n"
        return $exit_code
    fi
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))

    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %3d%%" $percentage

    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Print formatted output
print_status() {
    local status=$1
    local message=$2

    case "${status}" in
        "ok"|"success"|"pass")
            echo -e "${CHECK_MARK} ${GREEN}${message}${NC}" >&2
            ;;
        "fail"|"error"|"failed")
            echo -e "${CROSS_MARK} ${RED}${message}${NC}" >&2
            ;;
        "warn"|"warning")
            echo -e "${WARNING_SIGN} ${YELLOW}${message}${NC}" >&2
            ;;
        "info")
            echo -e "${INFO_SIGN} ${BLUE}${message}${NC}" >&2
            ;;
        *)
            echo -e "${BULLET} ${message}" >&2
            ;;
    esac
}

# Display summary
log_summary() {
    local title="$1"
    shift
    local items=("$@")

    echo >&2
    echo -e "${BOLD}${WHITE}${title}${NC}" >&2
    log_separator
    for item in "${items[@]}"; do
        echo -e "  ${BULLET} ${item}" >&2
    done
    log_separator
    echo >&2
}
