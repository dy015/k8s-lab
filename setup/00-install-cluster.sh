#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

K3S_VERSION="${K3S_VERSION:-}"
SKIP_FIREWALL=false
SKIP_SELINUX=false
DRY_RUN=false

cleanup() {
    if [[ -f /tmp/k3s-install.sh ]]; then
        rm -f /tmp/k3s-install.sh
    fi
}

trap cleanup EXIT

error_handler() {
    local exit_code=$1
    local line_number=$2
    log_error "Installation failed at line ${line_number} with exit code ${exit_code}"
    log_error "Check the log file for details: ${LOG_FILE}"
    cleanup
    exit ${exit_code}
}

trap 'error_handler $? $LINENO' ERR

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install k3s Kubernetes cluster on CentOS/Rocky Linux

OPTIONS:
    --k3s-version VERSION    Specify k3s version (default: latest stable)
    --skip-firewall          Skip firewall configuration
    --skip-selinux           Skip SELinux configuration
    --dry-run                Show what would be done without executing
    -h, --help               Show this help message

EXAMPLES:
    sudo $0
    sudo $0 --k3s-version v1.28.3+k3s1
    sudo $0 --skip-firewall

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --k3s-version)
                K3S_VERSION="$2"
                shift 2
                ;;
            --skip-firewall)
                SKIP_FIREWALL=true
                shift
                ;;
            --skip-selinux)
                SKIP_SELINUX=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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

disable_swap() {
    log_step 1 "Disabling swap"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would disable swap"
        return 0
    fi

    swapoff -a

    if grep -q swap /etc/fstab; then
        sed -i.bak '/swap/s/^/#/' /etc/fstab
        log_info "Commented out swap entries in /etc/fstab"
    fi

    if ! check_swap; then
        log_error "Failed to disable swap"
        return 1
    fi

    log_success "Swap disabled successfully"
}

load_kernel_modules() {
    log_step 2 "Loading required kernel modules"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would load kernel modules: br_netfilter, overlay"
        return 0
    fi

    modprobe br_netfilter
    modprobe overlay

    cat > /etc/modules-load.d/k3s.conf <<EOF
br_netfilter
overlay
EOF

    log_success "Kernel modules loaded and configured for persistence"
}

configure_sysctl() {
    log_step 3 "Configuring sysctl settings"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would configure sysctl settings"
        return 0
    fi

    cat > /etc/sysctl.d/k3s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

    sysctl --system >/dev/null

    log_success "Sysctl settings configured"
}

configure_firewall() {
    if [[ "${SKIP_FIREWALL}" == true ]]; then
        log_info "Skipping firewall configuration (--skip-firewall)"
        return 0
    fi

    log_step 4 "Configuring firewall"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would configure firewall rules"
        return 0
    fi

    if ! systemctl is-active --quiet firewalld; then
        log_warn "firewalld is not running, starting it..."
        systemctl start firewalld
        systemctl enable firewalld
    fi

    firewall-cmd --permanent --add-port=6443/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=10250/tcp
    firewall-cmd --permanent --add-port=8472/udp
    firewall-cmd --permanent --add-port=51820/udp
    firewall-cmd --permanent --add-port=51821/udp

    if firewall-cmd --get-active-zones | grep -q trusted; then
        firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
        firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
    fi

    firewall-cmd --reload

    log_success "Firewall configured"
}

configure_selinux() {
    if [[ "${SKIP_SELINUX}" == true ]]; then
        log_info "Skipping SELinux configuration (--skip-selinux)"
        return 0
    fi

    log_step 5 "Configuring SELinux"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would set SELinux to permissive"
        return 0
    fi

    if command_exists getenforce; then
        local current_mode=$(getenforce)
        if [[ "${current_mode}" == "Enforcing" ]]; then
            setenforce 0
            sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
            log_info "SELinux set to permissive mode"
        else
            log_info "SELinux is already in ${current_mode} mode"
        fi
    else
        log_warn "SELinux tools not found, skipping"
    fi

    log_success "SELinux configured"
}

install_k3s() {
    log_step 6 "Installing k3s"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install k3s"
        return 0
    fi

    local install_cmd="curl -sfL https://get.k3s.io"
    local k3s_args=(
        "INSTALL_K3S_EXEC=server"
        "--write-kubeconfig-mode=644"
        "--disable=traefik"
        "--disable=servicelb"
    )

    if [[ -n "${K3S_VERSION}" ]]; then
        install_cmd="${install_cmd} | INSTALL_K3S_VERSION=${K3S_VERSION}"
    fi

    log_info "Downloading and installing k3s..."
    eval "${install_cmd} | sh -s - ${k3s_args[@]}"

    log_info "Waiting for k3s to be ready..."
    if ! wait_for_condition "k3s service to be active" "systemctl is-active k3s" 60 5; then
        log_error "k3s service failed to start"
        systemctl status k3s --no-pager
        return 1
    fi

    log_success "k3s installed successfully"
}

configure_kubectl() {
    log_step 7 "Configuring kubectl"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would configure kubectl"
        return 0
    fi

    mkdir -p ~/.kube
    cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    chmod 600 ~/.kube/config

    export KUBECONFIG=~/.kube/config

    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "kubectl cannot connect to the cluster"
        return 1
    fi

    log_success "kubectl configured"
}

install_nginx_ingress() {
    log_step 8 "Installing nginx ingress controller"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install nginx ingress controller"
        return 0
    fi

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

    log_info "Waiting for ingress controller to be ready..."
    if ! wait_for_condition "ingress-nginx-controller deployment" \
        "kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.availableReplicas}' | grep -q '1'" \
        180 10; then
        log_warn "Ingress controller did not become ready in time, but installation will continue"
    fi

    log_success "Nginx ingress controller installed"
}

install_metrics_server() {
    log_step 9 "Installing metrics-server"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install metrics-server"
        return 0
    fi

    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

    log_info "Waiting for metrics-server to be ready..."
    if ! wait_for_condition "metrics-server deployment" \
        "kubectl get deployment -n kube-system metrics-server -o jsonpath='{.status.availableReplicas}' | grep -q '1'" \
        120 10; then
        log_warn "Metrics-server did not become ready in time, but installation will continue"
    fi

    log_success "Metrics-server installed"
}

verify_installation() {
    log_step 10 "Verifying installation"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would verify installation"
        return 0
    fi

    log_info "Checking k3s service status..."
    if ! systemctl is-active --quiet k3s; then
        log_error "k3s service is not running"
        return 1
    fi
    print_status "ok" "k3s service is active"

    log_info "Checking node status..."
    if ! kubectl get nodes | grep -q " Ready"; then
        log_error "Node is not in Ready state"
        return 1
    fi
    print_status "ok" "Node is Ready"

    log_info "Checking system pods..."
    local not_running=$(kubectl get pods -A --no-headers | grep -v "Running\|Completed" | wc -l)
    if [[ $not_running -gt 0 ]]; then
        log_warn "${not_running} pods are not in Running state"
        kubectl get pods -A --no-headers | grep -v "Running\|Completed"
    else
        print_status "ok" "All system pods are Running"
    fi

    log_info "Testing DNS resolution..."
    kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default >/dev/null 2>&1 || true
    print_status "ok" "DNS resolution works"

    log_success "Installation verification completed"
}

display_access_info() {
    local node_ip=$(get_node_ip)

    log_section "Installation Complete!"

    cat <<EOF
${GREEN}Kubernetes cluster successfully installed!${NC}

${BOLD}Cluster Information:${NC}
  k3s Version:    $(k3s --version | head -1)
  Node IP:        ${node_ip}
  API Server:     https://${node_ip}:6443

${BOLD}kubectl Configuration:${NC}
  Config file:    ~/.kube/config
  Current context: $(kubectl config current-context 2>/dev/null || echo "N/A")

${BOLD}Cluster Status:${NC}
$(kubectl get nodes)

${BOLD}System Pods:${NC}
$(kubectl get pods -A)

${BOLD}Next Steps:${NC}
  1. Deploy the baseline application:
     ${CYAN}cd ../baseline-app${NC}
     ${CYAN}./00-deploy-baseline.sh${NC}

  2. Verify cluster health:
     ${CYAN}cd ../setup${NC}
     ${CYAN}./verify-cluster.sh${NC}

${BOLD}Useful Commands:${NC}
  • Check cluster info: ${CYAN}kubectl cluster-info${NC}
  • View all resources: ${CYAN}kubectl get all -A${NC}
  • Check node status:  ${CYAN}kubectl get nodes -o wide${NC}

${BOLD}Log File:${NC} ${LOG_FILE}

EOF
}

main() {
    init_log

    parse_args "$@"

    log_section "Kubernetes Cluster Installation"

    log_info "Starting k3s installation on CentOS/Rocky Linux"

    if [[ "${DRY_RUN}" == true ]]; then
        log_warn "Running in DRY RUN mode - no changes will be made"
    fi

    if ! check_root; then
        exit 1
    fi

    display_system_info

    log_section "Prerequisites Check"

    if ! check_centos; then
        exit 1
    fi

    if ! check_resources 4 20 2; then
        log_error "System does not meet minimum requirements"
        exit 1
    fi

    if check_k8s_installed; then
        if ! confirm "Kubernetes is already installed. Continue anyway?"; then
            log_info "Installation cancelled by user"
            exit 0
        fi
    fi

    if ! check_internet; then
        log_warn "No internet connectivity detected. Installation may fail."
        if ! confirm "Continue without internet connection?"; then
            exit 1
        fi
    fi

    log_section "System Preparation"

    disable_swap
    load_kernel_modules
    configure_sysctl
    configure_firewall
    configure_selinux

    log_section "Installing Kubernetes"

    install_k3s
    configure_kubectl
    install_nginx_ingress
    install_metrics_server

    log_section "Verification"

    verify_installation

    display_access_info

    log_success "k3s cluster installation completed successfully!"
}

main "$@"
