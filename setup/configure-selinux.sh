#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Configure SELinux for Kubernetes (k3s) cluster

OPTIONS:
    --enforcing     Set SELinux to enforcing mode
    --permissive    Set SELinux to permissive mode (default for k3s)
    --status        Show current SELinux status
    -h, --help      Show this help message

NOTE:
    k3s works best with SELinux in permissive mode. Enforcing mode may
    require additional configuration and policies.

EOF
}

MODE="permissive"
STATUS_ONLY=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --enforcing)
                MODE="enforcing"
                shift
                ;;
            --permissive)
                MODE="permissive"
                shift
                ;;
            --status)
                STATUS_ONLY=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

check_selinux_available() {
    if ! command_exists getenforce; then
        log_error "SELinux tools not found. SELinux may not be available on this system."
        return 1
    fi
    return 0
}

show_selinux_status() {
    log_section "SELinux Status"

    if ! check_selinux_available; then
        log_warn "SELinux is not available on this system"
        return 1
    fi

    local current_mode=$(getenforce)
    local config_mode="unknown"

    if [[ -f /etc/selinux/config ]]; then
        config_mode=$(grep "^SELINUX=" /etc/selinux/config | cut -d'=' -f2)
    fi

    echo -e "${BOLD}Current Mode (Runtime):${NC} ${current_mode}"
    echo -e "${BOLD}Configured Mode (Boot):${NC} ${config_mode}"
    echo

    if command_exists sestatus; then
        echo -e "${BOLD}Detailed Status:${NC}"
        sestatus
    fi

    return 0
}

set_selinux_mode() {
    local target_mode=$1

    log_section "Configuring SELinux"

    if ! check_selinux_available; then
        return 1
    fi

    local current_mode=$(getenforce)

    if [[ "${current_mode,,}" == "${target_mode,,}" ]]; then
        log_info "SELinux is already in ${target_mode} mode"
        return 0
    fi

    log_info "Setting SELinux to ${target_mode} mode..."

    case "${target_mode}" in
        enforcing)
            setenforce 1
            sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
            log_warn "SELinux set to enforcing mode. This may cause issues with k3s."
            log_warn "You may need to install additional SELinux policies for k3s."
            ;;
        permissive)
            setenforce 0
            sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
            log_info "SELinux set to permissive mode (recommended for k3s)"
            ;;
        disabled)
            sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
            log_warn "SELinux will be disabled after reboot"
            log_warn "Current runtime mode cannot be changed to disabled without reboot"
            ;;
        *)
            log_error "Unknown SELinux mode: ${target_mode}"
            return 1
            ;;
    esac

    log_success "SELinux configuration updated"

    local new_runtime=$(getenforce)
    local new_config=$(grep "^SELINUX=" /etc/selinux/config | cut -d'=' -f2)

    echo
    echo -e "${BOLD}SELinux Configuration:${NC}"
    echo -e "  Runtime Mode:     ${new_runtime}"
    echo -e "  Configured Mode:  ${new_config}"
    echo

    if [[ "${new_runtime,,}" != "${new_config,,}" ]] && [[ "${new_config,,}" != "disabled" ]]; then
        log_warn "Runtime and configured modes differ. Changes will take full effect after reboot."
    fi

    return 0
}

verify_k3s_compatibility() {
    log_section "Verifying k3s Compatibility"

    if ! check_selinux_available; then
        return 0
    fi

    local current_mode=$(getenforce)

    case "${current_mode}" in
        Enforcing)
            print_status "warn" "SELinux is in Enforcing mode"
            log_warn "k3s may have issues with SELinux in Enforcing mode"
            log_warn "Consider setting it to Permissive mode for k3s"
            echo
            log_info "To set to permissive mode, run:"
            log_info "  sudo $0 --permissive"
            return 1
            ;;
        Permissive)
            print_status "ok" "SELinux is in Permissive mode (recommended for k3s)"
            return 0
            ;;
        Disabled)
            print_status "ok" "SELinux is Disabled"
            return 0
            ;;
        *)
            print_status "warn" "Unknown SELinux mode: ${current_mode}"
            return 1
            ;;
    esac
}

main() {
    init_log

    parse_args "$@"

    if ! check_root; then
        exit 1
    fi

    if [[ "${STATUS_ONLY}" == true ]]; then
        show_selinux_status
        verify_k3s_compatibility
        exit 0
    fi

    set_selinux_mode "${MODE}"
    echo
    show_selinux_status
    echo
    verify_k3s_compatibility

    log_success "SELinux configuration completed!"
}

main "$@"
