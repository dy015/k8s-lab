#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

FORCE=false

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Uninstall k3s Kubernetes cluster and clean up all resources

OPTIONS:
    --force    Skip confirmation prompt
    -h, --help Show this help message

WARNING:
    This will remove k3s and ALL cluster data. This action cannot be undone!

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
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

confirm_uninstall() {
    if [[ "${FORCE}" == true ]]; then
        return 0
    fi

    log_warn "This will completely remove k3s and all cluster data!"
    echo
    echo "The following will be removed:"
    echo "  • k3s service and binaries"
    echo "  • All containers and images"
    echo "  • All persistent data"
    echo "  • kubectl configuration"
    echo "  • Network configurations"
    echo

    if ! confirm "Are you absolutely sure you want to continue?" "n"; then
        log_info "Uninstall cancelled by user"
        exit 0
    fi

    echo
    if ! confirm "This is your last chance. Really uninstall?" "n"; then
        log_info "Uninstall cancelled by user"
        exit 0
    fi
}

stop_k3s_service() {
    log_step 1 "Stopping k3s service"

    if systemctl is-active --quiet k3s; then
        systemctl stop k3s
        log_success "k3s service stopped"
    else
        log_info "k3s service is not running"
    fi
}

run_k3s_uninstall() {
    log_step 2 "Running k3s uninstall script"

    if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
        /usr/local/bin/k3s-uninstall.sh
        log_success "k3s uninstall script completed"
    else
        log_warn "k3s uninstall script not found, k3s may not be installed"
    fi
}

cleanup_kubectl_config() {
    log_step 3 "Cleaning up kubectl configuration"

    if [[ -f ~/.kube/config ]]; then
        if grep -q "k3s" ~/.kube/config 2>/dev/null; then
            rm -f ~/.kube/config
            log_info "Removed kubectl config file"
        else
            log_info "kubectl config does not contain k3s configuration, keeping it"
        fi
    else
        log_info "kubectl config file not found"
    fi
}

cleanup_network() {
    log_step 4 "Cleaning up network configurations"

    local interfaces_removed=0

    for iface in $(ip link show | grep -o 'cni[0-9]*\|flannel\.[0-9]*\|veth[0-9a-f]*' || true); do
        ip link delete "${iface}" 2>/dev/null || true
        ((interfaces_removed++))
    done

    if [[ $interfaces_removed -gt 0 ]]; then
        log_info "Removed ${interfaces_removed} network interfaces"
    fi

    iptables -F -t nat 2>/dev/null || true
    iptables -F -t mangle 2>/dev/null || true
    iptables -F 2>/dev/null || true

    log_success "Network cleanup completed"
}

cleanup_directories() {
    log_step 5 "Removing k3s directories"

    local dirs=(
        "/var/lib/rancher/k3s"
        "/var/lib/rancher"
        "/etc/rancher/k3s"
        "/etc/rancher"
    )

    for dir in "${dirs[@]}"; do
        if [[ -d "${dir}" ]]; then
            rm -rf "${dir}"
            log_info "Removed directory: ${dir}"
        fi
    done

    log_success "Directory cleanup completed"
}

cleanup_kernel_modules() {
    log_step 6 "Cleaning up kernel module configuration"

    if [[ -f /etc/modules-load.d/k3s.conf ]]; then
        rm -f /etc/modules-load.d/k3s.conf
        log_info "Removed kernel module configuration"
    fi

    log_success "Kernel module cleanup completed"
}

cleanup_sysctl() {
    log_step 7 "Cleaning up sysctl configuration"

    if [[ -f /etc/sysctl.d/k3s.conf ]]; then
        rm -f /etc/sysctl.d/k3s.conf
        log_info "Removed sysctl configuration"
        sysctl --system >/dev/null 2>&1 || true
    fi

    log_success "Sysctl cleanup completed"
}

cleanup_firewall_rules() {
    log_step 8 "Cleaning up firewall rules"

    if systemctl is-active --quiet firewalld; then
        local rules_removed=false

        firewall-cmd --permanent --remove-port=6443/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=443/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=80/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=10250/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=8472/udp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=51820/udp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=51821/udp 2>/dev/null && rules_removed=true || true

        if firewall-cmd --get-active-zones | grep -q trusted; then
            firewall-cmd --permanent --zone=trusted --remove-source=10.42.0.0/16 2>/dev/null || true
            firewall-cmd --permanent --zone=trusted --remove-source=10.43.0.0/16 2>/dev/null || true
        fi

        if [[ "${rules_removed}" == true ]]; then
            firewall-cmd --reload
            log_info "Firewall rules removed"
        fi
    else
        log_info "firewalld is not running, skipping firewall cleanup"
    fi

    log_success "Firewall cleanup completed"
}

verify_uninstall() {
    log_step 9 "Verifying uninstall"

    local issues=0

    if systemctl list-unit-files | grep -q k3s; then
        print_status "warn" "k3s systemd unit files still present"
        ((issues++))
    else
        print_status "ok" "No k3s systemd unit files found"
    fi

    if command -v k3s >/dev/null 2>&1; then
        print_status "warn" "k3s binary still present"
        ((issues++))
    else
        print_status "ok" "k3s binary removed"
    fi

    if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
        print_status "warn" "kubectl can still connect to a cluster"
        ((issues++))
    else
        print_status "ok" "kubectl cannot connect to cluster"
    fi

    if [[ -d /var/lib/rancher ]]; then
        print_status "warn" "/var/lib/rancher directory still exists"
        ((issues++))
    else
        print_status "ok" "/var/lib/rancher directory removed"
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "Uninstall verification passed"
        return 0
    else
        log_warn "Uninstall verification found ${issues} issue(s)"
        return 1
    fi
}

display_summary() {
    log_section "Uninstall Complete"

    cat <<EOF
${GREEN}k3s has been successfully uninstalled!${NC}

${BOLD}What was removed:${NC}
  ✓ k3s service and binaries
  ✓ All containers and images
  ✓ All persistent data
  ✓ Network configurations
  ✓ Firewall rules
  ✓ System configurations

${BOLD}What remains:${NC}
  • SELinux is still in permissive mode (if it was changed)
  • Swap is still disabled (if it was disabled)
  • System packages installed during setup

${BOLD}To restore original system state:${NC}
  • Re-enable swap: ${CYAN}swapon -a${NC}
  • Edit /etc/fstab to uncomment swap entries
  • Re-enable SELinux: ${CYAN}setenforce 1${NC}

${BOLD}To reinstall k3s:${NC}
  ${CYAN}cd setup${NC}
  ${CYAN}sudo ./00-install-cluster.sh${NC}

EOF
}

main() {
    init_log

    parse_args "$@"

    log_section "k3s Cluster Uninstall"

    if ! check_root; then
        exit 1
    fi

    confirm_uninstall

    log_section "Uninstalling k3s"

    stop_k3s_service
    run_k3s_uninstall
    cleanup_kubectl_config
    cleanup_network
    cleanup_directories
    cleanup_kernel_modules
    cleanup_sysctl
    cleanup_firewall_rules

    log_section "Verification"

    verify_uninstall

    display_summary

    log_success "k3s cluster uninstall completed!"
}

main "$@"
