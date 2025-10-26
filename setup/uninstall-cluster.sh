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

Uninstall kubeadm Kubernetes cluster and clean up all resources

OPTIONS:
    --force    Skip confirmation prompt
    -h, --help Show this help message

WARNING:
    This will remove kubeadm, kubelet, kubectl and ALL cluster data.
    This action cannot be undone!

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

    log_warn "This will completely remove Kubernetes (kubeadm) and all cluster data!"
    echo
    echo "The following will be removed:"
    echo "  • kubeadm, kubelet, kubectl"
    echo "  • containerd container runtime"
    echo "  • All containers and images"
    echo "  • All persistent data"
    echo "  • kubectl configuration"
    echo "  • Network configurations"
    echo "  • etcd data"
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

drain_and_delete_node() {
    log_step 1 "Draining and deleting node"

    if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1; then
        local node_name=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [[ -n "${node_name}" ]]; then
            kubectl drain "${node_name}" --delete-emptydir-data --force --ignore-daemonsets 2>/dev/null || true
            kubectl delete node "${node_name}" 2>/dev/null || true
            log_info "Node drained and deleted"
        fi
    else
        log_info "Cannot connect to cluster, skipping node drain"
    fi

    log_success "Node drain completed"
}

reset_kubeadm() {
    log_step 2 "Resetting kubeadm"

    if command -v kubeadm &>/dev/null; then
        kubeadm reset -f
        log_success "kubeadm reset completed"
    else
        log_warn "kubeadm not found, skipping kubeadm reset"
    fi
}

stop_services() {
    log_step 3 "Stopping Kubernetes services"

    local services=("kubelet" "containerd")

    for service in "${services[@]}"; do
        if systemctl is-active --quiet "${service}"; then
            systemctl stop "${service}"
            log_info "Stopped ${service}"
        fi

        if systemctl is-enabled --quiet "${service}" 2>/dev/null; then
            systemctl disable "${service}"
            log_info "Disabled ${service}"
        fi
    done

    log_success "Services stopped"
}

remove_packages() {
    log_step 4 "Removing Kubernetes packages"

    local packages=("kubelet" "kubeadm" "kubectl" "containerd.io")
    local removed=0

    for package in "${packages[@]}"; do
        if rpm -q "${package}" &>/dev/null; then
            yum remove -y "${package}" 2>/dev/null || true
            ((removed++))
            log_info "Removed ${package}"
        fi
    done

    if [[ ${removed} -gt 0 ]]; then
        log_info "Removed ${removed} packages"
    else
        log_info "No packages to remove"
    fi

    log_success "Package removal completed"
}

cleanup_directories() {
    log_step 5 "Removing Kubernetes directories"

    local dirs=(
        "/etc/kubernetes"
        "/var/lib/kubelet"
        "/var/lib/etcd"
        "/var/lib/cni"
        "/etc/cni/net.d"
        "/opt/cni/bin"
        "/run/flannel"
        "/var/lib/containerd"
        "/etc/containerd"
    )

    local removed=0
    for dir in "${dirs[@]}"; do
        if [[ -d "${dir}" ]]; then
            rm -rf "${dir}"
            ((removed++))
            log_info "Removed directory: ${dir}"
        fi
    done

    if [[ ${removed} -gt 0 ]]; then
        log_info "Removed ${removed} directories"
    fi

    log_success "Directory cleanup completed"
}

cleanup_kubectl_config() {
    log_step 6 "Cleaning up kubectl configuration"

    # Root user
    if [[ -f ~/.kube/config ]]; then
        rm -f ~/.kube/config
        log_info "Removed root kubectl config"
    fi

    if [[ -d ~/.kube ]]; then
        rm -rf ~/.kube
        log_info "Removed root .kube directory"
    fi

    # SUDO_USER if exists
    if [[ -n "${SUDO_USER:-}" ]] && [[ "${SUDO_USER}" != "root" ]]; then
        local user_home=$(eval echo ~${SUDO_USER})
        if [[ -d "${user_home}/.kube" ]]; then
            rm -rf "${user_home}/.kube"
            log_info "Removed kubectl config for user: ${SUDO_USER}"
        fi
    fi

    # Remove from bashrc
    sed -i '/KUBECONFIG/d' ~/.bashrc 2>/dev/null || true
    if [[ -n "${SUDO_USER:-}" ]] && [[ "${SUDO_USER}" != "root" ]]; then
        local user_home=$(eval echo ~${SUDO_USER})
        sed -i '/KUBECONFIG/d' "${user_home}/.bashrc" 2>/dev/null || true
    fi

    log_success "kubectl config cleanup completed"
}

cleanup_network() {
    log_step 7 "Cleaning up network configurations"

    # Remove CNI interfaces
    local interfaces_removed=0
    for iface in $(ip link show | grep -o 'cni[0-9]*\|flannel\.[0-9]*\|veth[0-9a-f]*\|docker[0-9]*' 2>/dev/null || true); do
        ip link delete "${iface}" 2>/dev/null || true
        ((interfaces_removed++))
    done

    if [[ $interfaces_removed -gt 0 ]]; then
        log_info "Removed ${interfaces_removed} network interfaces"
    fi

    # Clear iptables rules
    iptables -F -t nat 2>/dev/null || true
    iptables -F -t mangle 2>/dev/null || true
    iptables -F 2>/dev/null || true
    iptables -X 2>/dev/null || true

    log_info "Cleared iptables rules"

    log_success "Network cleanup completed"
}

cleanup_kernel_modules() {
    log_step 8 "Cleaning up kernel module configuration"

    if [[ -f /etc/modules-load.d/k8s.conf ]]; then
        rm -f /etc/modules-load.d/k8s.conf
        log_info "Removed kernel module configuration"
    fi

    log_success "Kernel module cleanup completed"
}

cleanup_sysctl() {
    log_step 9 "Cleaning up sysctl configuration"

    if [[ -f /etc/sysctl.d/k8s.conf ]]; then
        rm -f /etc/sysctl.d/k8s.conf
        log_info "Removed sysctl configuration"
        sysctl --system >/dev/null 2>&1 || true
    fi

    log_success "Sysctl cleanup completed"
}

cleanup_repositories() {
    log_step 10 "Cleaning up package repositories"

    if [[ -f /etc/yum.repos.d/kubernetes.repo ]]; then
        rm -f /etc/yum.repos.d/kubernetes.repo
        log_info "Removed Kubernetes repository"
    fi

    if [[ -f /etc/yum.repos.d/docker-ce.repo ]]; then
        log_info "Docker repository still present (may be used by other apps)"
    fi

    log_success "Repository cleanup completed"
}

cleanup_firewall_rules() {
    log_step 11 "Cleaning up firewall rules"

    if systemctl is-active --quiet firewalld; then
        local rules_removed=false

        # Kubernetes ports
        firewall-cmd --permanent --remove-port=6443/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=2379-2380/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=10250/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=10259/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=10257/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=30000-32767/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=8472/udp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=443/tcp 2>/dev/null && rules_removed=true || true
        firewall-cmd --permanent --remove-port=80/tcp 2>/dev/null && rules_removed=true || true

        # Remove trusted sources
        if firewall-cmd --get-active-zones | grep -q trusted; then
            firewall-cmd --permanent --zone=trusted --remove-source=10.244.0.0/16 2>/dev/null || true
            firewall-cmd --permanent --zone=trusted --remove-source=10.96.0.0/16 2>/dev/null || true
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
    log_step 12 "Verifying uninstall"

    local issues=0

    # Check for kubelet service
    if systemctl list-unit-files | grep -q kubelet; then
        print_status "warn" "kubelet systemd unit files still present"
        ((issues++))
    else
        print_status "ok" "No kubelet systemd unit files found"
    fi

    # Check for binaries
    if command -v kubeadm &>/dev/null; then
        print_status "warn" "kubeadm binary still present"
        ((issues++))
    else
        print_status "ok" "kubeadm binary removed"
    fi

    if command -v kubelet &>/dev/null; then
        print_status "warn" "kubelet binary still present"
        ((issues++))
    else
        print_status "ok" "kubelet binary removed"
    fi

    # Check kubectl connectivity
    if command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null 2>&1; then
        print_status "warn" "kubectl can still connect to a cluster"
        ((issues++))
    else
        print_status "ok" "kubectl cannot connect to cluster"
    fi

    # Check directories
    if [[ -d /etc/kubernetes ]]; then
        print_status "warn" "/etc/kubernetes directory still exists"
        ((issues++))
    else
        print_status "ok" "/etc/kubernetes directory removed"
    fi

    if [[ -d /var/lib/kubelet ]]; then
        print_status "warn" "/var/lib/kubelet directory still exists"
        ((issues++))
    else
        print_status "ok" "/var/lib/kubelet directory removed"
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "Uninstall verification passed"
        return 0
    else
        log_warn "Uninstall verification found ${issues} issue(s)"
        log_info "You may need to reboot the system for complete cleanup"
        return 1
    fi
}

display_summary() {
    log_section "Uninstall Complete"

    cat <<EOF
${GREEN}Kubernetes (kubeadm) has been successfully uninstalled!${NC}

${BOLD}What was removed:${NC}
  ✓ kubeadm, kubelet, kubectl
  ✓ containerd runtime
  ✓ All containers and images
  ✓ All persistent data
  ✓ Network configurations
  ✓ Firewall rules
  ✓ System configurations
  ✓ etcd data

${BOLD}What remains:${NC}
  • SELinux is still in permissive mode (if it was changed)
  • Swap is still disabled (if it was disabled)
  • Kernel modules loaded
  • Some repository configurations

${BOLD}To restore original system state:${NC}
  • Re-enable swap: ${CYAN}swapon -a${NC}
  • Edit /etc/fstab to uncomment swap entries
  • Re-enable SELinux: ${CYAN}setenforce 1${NC}
  • Reboot system: ${CYAN}reboot${NC}

${BOLD}To reinstall Kubernetes:${NC}
  ${CYAN}cd setup${NC}
  ${CYAN}sudo ./00-install-cluster.sh${NC}

EOF
}

main() {
    init_log

    parse_args "$@"

    log_section "Kubernetes (kubeadm) Cluster Uninstall"

    if ! check_root; then
        exit 1
    fi

    confirm_uninstall

    log_section "Uninstalling Kubernetes"

    drain_and_delete_node
    reset_kubeadm
    stop_services
    remove_packages
    cleanup_directories
    cleanup_kubectl_config
    cleanup_network
    cleanup_kernel_modules
    cleanup_sysctl
    cleanup_repositories
    cleanup_firewall_rules

    log_section "Verification"

    verify_uninstall

    display_summary

    log_success "Kubernetes cluster uninstall completed!"
}

main "$@"
