#!/bin/bash
#
# Alternative installation script using kubeadm instead of k3s
# For single-node Kubernetes cluster on CentOS/Rocky Linux
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

K8S_VERSION="${K8S_VERSION:-1.28.0}"
POD_NETWORK_CIDR="10.244.0.0/16"
API_SERVER_IP=""  # Auto-detect if empty
SKIP_FIREWALL=false
DISABLE_FIREWALL=false
DRY_RUN=false

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install Kubernetes cluster using kubeadm on CentOS/Rocky Linux (single-node)

OPTIONS:
    --k8s-version VERSION    Specify Kubernetes version (default: 1.28.0)
    --pod-cidr CIDR          Pod network CIDR (default: 10.244.0.0/16)
    --api-server-ip IP       API server advertise IP (default: auto-detect)
    --skip-firewall          Skip firewall configuration (leave as-is)
    --disable-firewall       Completely disable firewall (recommended for labs)
    --dry-run                Show what would be done without executing
    -h, --help               Show this help message

EXAMPLES:
    sudo $0
    sudo $0 --k8s-version 1.29.0
    sudo $0 --pod-cidr 10.244.0.0/16
    sudo $0 --api-server-ip 192.168.1.100
    sudo $0 --api-server-ip 192.168.1.100 --disable-firewall

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --k8s-version)
                K8S_VERSION="$2"
                shift 2
                ;;
            --pod-cidr)
                POD_NETWORK_CIDR="$2"
                shift 2
                ;;
            --api-server-ip)
                API_SERVER_IP="$2"
                shift 2
                ;;
            --skip-firewall)
                SKIP_FIREWALL=true
                shift
                ;;
            --disable-firewall)
                DISABLE_FIREWALL=true
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
    sed -i.bak '/swap/s/^/#/' /etc/fstab

    log_success "Swap disabled"
}

load_kernel_modules() {
    log_step 2 "Loading required kernel modules"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would load kernel modules"
        return 0
    fi

    cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

    modprobe overlay
    modprobe br_netfilter

    log_success "Kernel modules loaded"
}

configure_sysctl() {
    log_step 3 "Configuring sysctl settings"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would configure sysctl"
        return 0
    fi

    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sysctl --system >/dev/null

    log_success "Sysctl configured"
}

configure_firewall() {
    log_step 4 "Configuring firewall"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would configure firewall"
        return 0
    fi

    # Disable firewall completely
    if [[ "${DISABLE_FIREWALL}" == true ]]; then
        log_info "Disabling firewall completely..."
        if systemctl is-active --quiet firewalld; then
            systemctl stop firewalld
        fi
        systemctl disable firewalld
        log_success "Firewall disabled"
        return 0
    fi

    # Skip firewall configuration
    if [[ "${SKIP_FIREWALL}" == true ]]; then
        log_info "Skipping firewall configuration"
        return 0
    fi

    # Configure firewall
    if ! systemctl is-active --quiet firewalld; then
        systemctl start firewalld
        systemctl enable firewalld
    fi

    # Add all interfaces to internal zone for simplicity
    log_info "Adding all network interfaces to internal zone..."
    for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
        firewall-cmd --permanent --zone=internal --add-interface=${iface} 2>/dev/null || true
    done

    # Kubernetes API server
    firewall-cmd --permanent --zone=internal --add-port=6443/tcp

    # etcd server client API
    firewall-cmd --permanent --zone=internal --add-port=2379-2380/tcp

    # Kubelet API
    firewall-cmd --permanent --zone=internal --add-port=10250/tcp

    # kube-scheduler
    firewall-cmd --permanent --zone=internal --add-port=10259/tcp

    # kube-controller-manager
    firewall-cmd --permanent --zone=internal --add-port=10257/tcp

    # NodePort Services
    firewall-cmd --permanent --zone=internal --add-port=30000-32767/tcp

    # Flannel VXLAN
    firewall-cmd --permanent --zone=internal --add-port=8472/udp

    # HTTP/HTTPS for ingress
    firewall-cmd --permanent --zone=internal --add-port=80/tcp
    firewall-cmd --permanent --zone=internal --add-port=443/tcp

    # Pod and Service networks in trusted zone
    firewall-cmd --permanent --zone=trusted --add-source=${POD_NETWORK_CIDR}
    firewall-cmd --permanent --zone=trusted --add-source=10.96.0.0/16

    # Allow masquerading for NAT (important for multi-interface setups)
    firewall-cmd --permanent --zone=internal --add-masquerade
    firewall-cmd --permanent --zone=trusted --add-masquerade

    firewall-cmd --reload

    log_info "Firewall zones configured:"
    firewall-cmd --get-active-zones

    log_success "Firewall configured for multi-interface setup"
}

install_container_runtime() {
    log_step 5 "Installing containerd"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install containerd"
        return 0
    fi

    # Install containerd
    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y containerd.io

    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml

    # Enable SystemdCgroup
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    # Start and enable containerd
    systemctl restart containerd
    systemctl enable containerd

    log_success "Containerd installed and configured"
}

install_k8s_tools() {
    log_step 6 "Installing kubeadm, kubelet, and kubectl"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install Kubernetes tools"
        return 0
    fi

    # Add Kubernetes repo
    cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

    # Install tools
    yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

    # Enable kubelet
    systemctl enable kubelet

    log_success "Kubernetes tools installed"
}

initialize_cluster() {
    log_step 7 "Initializing Kubernetes cluster"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would initialize cluster"
        return 0
    fi

    # Determine API server IP
    local api_ip
    if [[ -n "${API_SERVER_IP}" ]]; then
        api_ip="${API_SERVER_IP}"
        log_info "Using custom API server IP: ${api_ip}"
    else
        api_ip=$(hostname -I | awk '{print $1}')
        log_info "Auto-detected API server IP: ${api_ip}"
    fi

    log_info "Running kubeadm init (this may take several minutes)..."

    kubeadm init \
        --pod-network-cidr=${POD_NETWORK_CIDR} \
        --apiserver-advertise-address=${api_ip} \
        --kubernetes-version=${K8S_VERSION}

    log_success "Cluster initialized"
}

configure_kubectl() {
    log_step 8 "Configuring kubectl for current user"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would configure kubectl"
        return 0
    fi

    # For root user
    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> ~/.bashrc

    # For regular user (if not root)
    if [[ -n "${SUDO_USER:-}" ]] && [[ "${SUDO_USER}" != "root" ]]; then
        local user_home=$(eval echo ~${SUDO_USER})
        sudo -u ${SUDO_USER} mkdir -p ${user_home}/.kube
        cp /etc/kubernetes/admin.conf ${user_home}/.kube/config
        chown -R ${SUDO_USER}:${SUDO_USER} ${user_home}/.kube
        log_info "kubectl configured for user: ${SUDO_USER}"
    fi

    log_success "kubectl configured"
}

untaint_control_plane() {
    log_step 9 "Untainting control-plane for single-node setup"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would untaint control-plane node"
        return 0
    fi

    # Allow workloads on control-plane node (single-node setup)
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
    kubectl taint nodes --all node-role.kubernetes.io/master- || true

    log_success "Control-plane untainted"
}

install_cni_plugin() {
    log_step 10 "Installing Flannel CNI plugin"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install CNI plugin"
        return 0
    fi

    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

    log_info "Waiting for CoreDNS to be ready..."
    if ! wait_for_condition "CoreDNS pods" \
        "kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[*].status.phase}' | grep -q Running" \
        180 10; then
        log_warn "CoreDNS may not be ready yet"
    fi

    log_success "CNI plugin installed"
}

install_nginx_ingress() {
    log_step 11 "Installing nginx ingress controller"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install nginx ingress"
        return 0
    fi

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

    log_info "Waiting for ingress controller to be ready..."
    if ! wait_for_condition "ingress-nginx-controller" \
        "kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.availableReplicas}' | grep -q '1'" \
        180 10; then
        log_warn "Ingress controller may not be ready yet"
    fi

    log_success "Nginx ingress controller installed"
}

install_metrics_server() {
    log_step 12 "Installing metrics-server"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install metrics-server"
        return 0
    fi

    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    # Patch for insecure TLS (needed for some environments)
    kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

    log_success "Metrics-server installed"
}

install_storage_provisioner() {
    log_step 13 "Installing local-path storage provisioner"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would install local-path provisioner"
        return 0
    fi

    # Install local-path provisioner (same as k3s default)
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

    log_info "Waiting for local-path-provisioner to be ready..."
    if ! wait_for_condition "local-path-provisioner" \
        "kubectl get deployment -n local-path-storage local-path-provisioner -o jsonpath='{.status.availableReplicas}' | grep -q '1'" \
        180 10; then
        log_warn "local-path-provisioner may not be ready yet"
    fi

    # Set as default StorageClass
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

    log_success "Local-path storage provisioner installed"
}

verify_installation() {
    log_step 14 "Verifying installation"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would verify installation"
        return 0
    fi

    log_info "Checking node status..."
    if ! kubectl get nodes | grep -q " Ready"; then
        log_error "Node is not Ready"
        return 1
    fi
    print_status "ok" "Node is Ready"

    log_info "Checking system pods..."
    local not_running=$(kubectl get pods -A --no-headers | grep -v "Running\|Completed" | wc -l)
    if [[ $not_running -gt 0 ]]; then
        log_warn "${not_running} pods are not Running yet"
    else
        print_status "ok" "All system pods Running"
    fi

    log_success "Verification completed"
}

display_access_info() {
    local node_ip=$(get_node_ip)

    log_section "Installation Complete!"

    cat <<EOF
${GREEN}${BOLD}Kubernetes cluster (kubeadm) successfully installed!${NC}

${BOLD}Cluster Information:${NC}
  Kubernetes:     v${K8S_VERSION}
  Node IP:        ${node_ip}
  API Server:     https://${node_ip}:6443
  Pod CIDR:       ${POD_NETWORK_CIDR}

${BOLD}Cluster Status:${NC}
$(kubectl get nodes -o wide)

${BOLD}System Pods:${NC}
$(kubectl get pods -A)

${BOLD}Next Steps:${NC}
  1. Deploy the baseline application:
     ${CYAN}cd ../baseline-app${NC}
     ${CYAN}./00-deploy-baseline.sh${NC}

  2. Verify cluster health:
     ${CYAN}cd ../setup${NC}
     ${CYAN}./verify-cluster.sh${NC}

${BOLD}Important Notes:${NC}
  • This is a single-node cluster (control-plane is untainted)
  • Using containerd as container runtime
  • Using Flannel as CNI plugin
  • Using local-path storage provisioner for PVCs
  • Ingress controller uses NodePort (access via http://${node_ip}:NodePort)

${BOLD}Useful Commands:${NC}
  • Cluster info:  ${CYAN}kubectl cluster-info${NC}
  • All resources: ${CYAN}kubectl get all -A${NC}
  • Node details:  ${CYAN}kubectl describe node$(hostname)${NC}

${BOLD}Log File:${NC} ${LOG_FILE}

EOF
}

main() {
    init_log

    parse_args "$@"

    log_section "Kubernetes Installation with kubeadm"
    log_info "Installing single-node cluster on CentOS/Rocky Linux"

    if [[ "${DRY_RUN}" == true ]]; then
        log_warn "Running in DRY RUN mode"
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
        log_error "Insufficient resources"
        exit 1
    fi

    if check_k8s_installed; then
        if ! confirm "Kubernetes already installed. Continue?"; then
            exit 0
        fi
    fi

    log_section "System Preparation"

    disable_swap
    load_kernel_modules
    configure_sysctl
    configure_firewall

    log_section "Installing Container Runtime and Kubernetes"

    install_container_runtime
    install_k8s_tools

    log_section "Initializing Cluster"

    initialize_cluster
    configure_kubectl
    untaint_control_plane
    install_cni_plugin

    log_section "Installing Add-ons"

    install_nginx_ingress
    install_metrics_server
    install_storage_provisioner

    log_section "Verification"

    verify_installation

    display_access_info

    log_success "kubeadm cluster installation completed!"
}

main "$@"
