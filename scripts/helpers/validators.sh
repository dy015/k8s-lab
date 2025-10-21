#!/bin/bash

# Source logger if not already sourced
if [[ -z "${RED}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/colors.sh"
    source "${SCRIPT_DIR}/logger.sh"
fi

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        return 1
    fi
    log_debug "Root check passed"
    return 0
}

# Check if command exists
command_exists() {
    local cmd=$1
    if command -v "$cmd" >/dev/null 2>&1; then
        log_debug "Command '${cmd}' found"
        return 0
    else
        log_debug "Command '${cmd}' not found"
        return 1
    fi
}

# Check CentOS/Rocky Linux version
check_centos() {
    if [[ ! -f /etc/centos-release ]] && [[ ! -f /etc/rocky-release ]] && [[ ! -f /etc/redhat-release ]]; then
        log_error "This script requires CentOS, Rocky Linux, or RHEL"
        return 1
    fi

    local version
    if [[ -f /etc/centos-release ]]; then
        version=$(rpm -E %{rhel} 2>/dev/null || echo "0")
    elif [[ -f /etc/rocky-release ]]; then
        version=$(rpm -E %{rhel} 2>/dev/null || echo "0")
    elif [[ -f /etc/redhat-release ]]; then
        version=$(rpm -E %{rhel} 2>/dev/null || echo "0")
    fi

    if [[ $version -lt 7 ]]; then
        log_error "CentOS/Rocky/RHEL 7 or higher required (found version: ${version})"
        return 1
    fi

    log_info "Detected RHEL-based Linux version: ${version}"
    return 0
}

# Check system resources
check_resources() {
    local min_ram_gb=${1:-4}
    local min_disk_gb=${2:-20}
    local min_cpu_cores=${3:-2}

    local errors=0

    # Check RAM
    local total_ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_ram_gb -lt $min_ram_gb ]]; then
        log_error "Minimum ${min_ram_gb}GB RAM required, found ${total_ram_gb}GB"
        ((errors++))
    else
        log_info "RAM check passed: ${total_ram_gb}GB available"
    fi

    # Check disk space
    local available_disk_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_disk_gb -lt $min_disk_gb ]]; then
        log_error "Minimum ${min_disk_gb}GB disk space required, found ${available_disk_gb}GB available"
        ((errors++))
    else
        log_info "Disk space check passed: ${available_disk_gb}GB available"
    fi

    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt $min_cpu_cores ]]; then
        log_error "Minimum ${min_cpu_cores} CPU cores required, found ${cpu_cores}"
        ((errors++))
    else
        log_info "CPU check passed: ${cpu_cores} cores available"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "System resources check failed with ${errors} error(s)"
        return 1
    fi

    log_success "All system resources checks passed"
    return 0
}

# Check if port is available
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
        log_warn "Port ${port} is already in use"
        return 1
    else
        log_debug "Port ${port} is available"
        return 0
    fi
}

# Check if service is running
check_service() {
    local service=$1
    if systemctl is-active --quiet "${service}"; then
        log_debug "Service '${service}' is running"
        return 0
    else
        log_debug "Service '${service}' is not running"
        return 1
    fi
}

# Check if file exists
check_file() {
    local file=$1
    if [[ -f "${file}" ]]; then
        log_debug "File '${file}' exists"
        return 0
    else
        log_debug "File '${file}' does not exist"
        return 1
    fi
}

# Check if directory exists
check_directory() {
    local dir=$1
    if [[ -d "${dir}" ]]; then
        log_debug "Directory '${dir}' exists"
        return 0
    else
        log_debug "Directory '${dir}' does not exist"
        return 1
    fi
}

# Check internet connectivity
check_internet() {
    local test_host="${1:-8.8.8.8}"
    if ping -c 1 -W 2 "${test_host}" >/dev/null 2>&1; then
        log_info "Internet connectivity check passed"
        return 0
    else
        log_warn "No internet connectivity detected"
        return 1
    fi
}

# Check if Kubernetes is already installed
check_k8s_installed() {
    if command_exists kubectl && kubectl cluster-info >/dev/null 2>&1; then
        log_warn "Kubernetes cluster is already running"
        return 0
    elif systemctl list-unit-files | grep -q k3s; then
        log_warn "k3s is already installed"
        return 0
    else
        log_debug "No existing Kubernetes installation detected"
        return 1
    fi
}

# Check if swap is enabled
check_swap() {
    if swapon --show | grep -q '/'; then
        log_warn "Swap is enabled (Kubernetes requires swap to be disabled)"
        return 1
    else
        log_debug "Swap is disabled"
        return 0
    fi
}

# Validate IP address
validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ $ip =~ $regex ]]; then
        for octet in ${ip//./ }; do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done
        log_debug "IP address '${ip}' is valid"
        return 0
    else
        log_debug "IP address '${ip}' is invalid"
        return 1
    fi
}

# Validate namespace name
validate_k8s_name() {
    local name=$1
    local regex='^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'

    if [[ $name =~ $regex ]] && [[ ${#name} -le 63 ]]; then
        log_debug "Kubernetes name '${name}' is valid"
        return 0
    else
        log_debug "Kubernetes name '${name}' is invalid"
        return 1
    fi
}

# Confirmation prompt
confirm() {
    local message="$1"
    local default="${2:-n}"

    local prompt
    if [[ $default == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    read -p "${message} ${prompt}: " response
    response=${response:-$default}

    if [[ $response =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Validate YAML file
validate_yaml() {
    local yaml_file=$1

    if ! check_file "${yaml_file}"; then
        log_error "YAML file not found: ${yaml_file}"
        return 1
    fi

    if command_exists python3; then
        python3 -c "import yaml; yaml.safe_load(open('${yaml_file}'))" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            log_debug "YAML file '${yaml_file}' is valid"
            return 0
        else
            log_error "YAML file '${yaml_file}' is invalid"
            return 1
        fi
    else
        log_debug "Python3 not available, skipping YAML validation"
        return 0
    fi
}

# Wait for condition with timeout
wait_for_condition() {
    local description=$1
    local condition_cmd=$2
    local timeout=${3:-300}
    local interval=${4:-5}

    local elapsed=0
    log_info "Waiting for: ${description}"

    while [[ $elapsed -lt $timeout ]]; do
        if eval "${condition_cmd}" >/dev/null 2>&1; then
            log_success "${description} - completed in ${elapsed}s"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
        printf "."
    done

    echo
    log_error "${description} - timed out after ${timeout}s"
    return 1
}

# Check kubectl connectivity
check_kubectl() {
    if ! command_exists kubectl; then
        log_error "kubectl is not installed"
        return 1
    fi

    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        return 1
    fi

    log_info "kubectl connectivity check passed"
    return 0
}

# Check pod status
check_pod_status() {
    local pod_name=$1
    local namespace=${2:-default}
    local expected_status=${3:-Running}

    if ! check_kubectl; then
        return 1
    fi

    local status=$(kubectl get pod "${pod_name}" -n "${namespace}" -o jsonpath='{.status.phase}' 2>/dev/null)

    if [[ "${status}" == "${expected_status}" ]]; then
        log_debug "Pod '${pod_name}' in namespace '${namespace}' is ${expected_status}"
        return 0
    else
        log_debug "Pod '${pod_name}' status is '${status}', expected '${expected_status}'"
        return 1
    fi
}

# Check if namespace exists
check_namespace() {
    local namespace=$1

    if ! check_kubectl; then
        return 1
    fi

    if kubectl get namespace "${namespace}" >/dev/null 2>&1; then
        log_debug "Namespace '${namespace}' exists"
        return 0
    else
        log_debug "Namespace '${namespace}' does not exist"
        return 1
    fi
}

# Get node IP
get_node_ip() {
    if command_exists kubectl; then
        kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null
    else
        hostname -I | awk '{print $1}'
    fi
}

# Display system information
display_system_info() {
    log_section "System Information"

    echo -e "${BOLD}Operating System:${NC}"
    cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2

    echo -e "\n${BOLD}Kernel Version:${NC}"
    uname -r

    echo -e "\n${BOLD}CPU Information:${NC}"
    echo "Cores: $(nproc)"
    echo "Model: $(lscpu | grep 'Model name' | sed 's/Model name: *//')"

    echo -e "\n${BOLD}Memory Information:${NC}"
    free -h | grep Mem

    echo -e "\n${BOLD}Disk Information:${NC}"
    df -h / | tail -1

    echo -e "\n${BOLD}Network Information:${NC}"
    echo "Hostname: $(hostname)"
    echo "IP Address: $(get_node_ip)"

    echo
}
