#!/bin/bash
#
# Kubernetes cluster installation using kubeadm
# For single-node clusters on CentOS/Rocky Linux
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

K8S_VERSION="${K8S_VERSION:-1.28.0}"
POD_NETWORK_CIDR="10.244.0.0/16"
INTERFACE=""  # REQUIRED - must be specified by user
NODE_IP=""    # Will be detected from interface

show_usage() {
    cat <<EOF
Usage: $0 --interface <interface_name>

Install Kubernetes cluster using kubeadm on CentOS/Rocky Linux (single-node)

REQUIRED:
    --interface <name>      Network interface to use (e.g., eth1, eno1, enp0s8)

OPTIONAL:
    --k8s-version VERSION   Specify Kubernetes version (default: 1.28.0)
    --pod-cidr CIDR         Pod network CIDR (default: 10.244.0.0/16)
    -h, --help              Show this help message

EXAMPLES:
    sudo $0 --interface eth1        # Use eth1 interface
    sudo $0 --interface eno1        # Use eno1 interface
    sudo $0 --interface enp0s8      # Use enp0s8 interface

NOTES:
    - The interface MUST have an IP address configured
    - Firewall is disabled automatically (lab environment)
    - SELinux is set to permissive mode automatically

EOF
}

parse_args() {
    if [[ $# -eq 0 ]]; then
        log_error "Missing required --interface parameter"
        show_usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --interface)
                INTERFACE="$2"
                shift 2
                ;;
            --k8s-version)
                K8S_VERSION="$2"
                shift 2
                ;;
            --pod-cidr)
                POD_NETWORK_CIDR="$2"
                shift 2
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

    # Validate required parameters
    if [[ -z "${INTERFACE}" ]]; then
        log_error "Missing required --interface parameter"
        show_usage
        exit 1
    fi
}

get_ip_from_interface() {
    local iface=$1

    log_info "Detecting IP from interface: ${iface}"

    # Check if interface exists
    if ! ip link show "${iface}" &>/dev/null; then
        log_error "Interface '${iface}' does not exist"
        log_info "Available interfaces:"
        ip -o link show | awk -F': ' '{print "  " $2}' | grep -v lo
        return 1
    fi

    # Get IPv4 address
    local ip=$(ip -4 addr show "${iface}" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

    if [[ -z "${ip}" ]]; then
        log_error "No IPv4 address found on interface '${iface}'"
        log_info "Current interface status:"
        ip addr show "${iface}"
        log_info ""
        log_info "To configure an IP on ${iface}:"
        log_info "  sudo ip addr add 192.168.1.100/24 dev ${iface}"
        log_info "  sudo ip link set ${iface} up"
        return 1
    fi

    echo "${ip}"
    return 0
}

disable_swap() {
    log_step 1 "Disabling swap"
    swapoff -a
    sed -i.bak '/swap/s/^/#/' /etc/fstab
    log_success "Swap disabled"
}

load_kernel_modules() {
    log_step 2 "Loading required kernel modules"

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

    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

    sysctl --system >/dev/null

    log_success "Sysctl configured"
}

configure_selinux() {
    log_step 4 "Configuring SELinux"

    if command -v setenforce &> /dev/null; then
        log_info "Setting SELinux to permissive mode..."
        setenforce 0 2>/dev/null || true
        sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
        sed -i 's/^SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config 2>/dev/null || true
        log_success "SELinux configured to permissive mode"
    else
        log_info "SELinux not found, skipping"
    fi
}

disable_firewall() {
    log_step 5 "Disabling firewall"

    # Stop and disable firewalld
    if systemctl is-active --quiet firewalld; then
        systemctl stop firewalld 2>/dev/null || true
    fi
    systemctl disable firewalld 2>/dev/null || true

    # Flush all iptables rules
    log_info "Flushing iptables rules..."
    iptables -F 2>/dev/null || true
    iptables -X 2>/dev/null || true
    iptables -t nat -F 2>/dev/null || true
    iptables -t nat -X 2>/dev/null || true
    iptables -t mangle -F 2>/dev/null || true
    iptables -t mangle -X 2>/dev/null || true
    iptables -P INPUT ACCEPT 2>/dev/null || true
    iptables -P FORWARD ACCEPT 2>/dev/null || true
    iptables -P OUTPUT ACCEPT 2>/dev/null || true

    log_success "Firewall disabled and iptables flushed"
}

install_container_runtime() {
    log_step 6 "Installing containerd"

    yum install -y yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y containerd.io

    # Configure containerd
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    # Start and enable containerd
    systemctl restart containerd
    systemctl enable containerd

    log_success "Containerd installed and configured"
}

install_k8s_tools() {
    log_step 7 "Installing kubeadm, kubelet, and kubectl"

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

    # Install Kubernetes tools
    yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

    log_success "Kubernetes tools installed"
}

configure_kubelet_node_ip() {
    log_step 8 "Configuring kubelet node IP"

    log_info "Setting kubelet node IP to: ${NODE_IP} (from interface: ${INTERFACE})"

    # For RPM-based systems (CentOS/Rocky), use /etc/sysconfig/kubelet
    # This is the official way per Kubernetes documentation
    cat > /etc/sysconfig/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}
EOF

    # Enable kubelet (will start after kubeadm init)
    systemctl enable kubelet

    log_success "Kubelet configured with node IP: ${NODE_IP}"
    log_info "Configuration written to: /etc/sysconfig/kubelet"
}

initialize_cluster() {
    log_step 9 "Initializing Kubernetes cluster"

    log_info "Using interface: ${INTERFACE}"
    log_info "Using IP address: ${NODE_IP}"
    log_info "Running kubeadm init (this may take several minutes)..."

    kubeadm init \
        --pod-network-cidr=${POD_NETWORK_CIDR} \
        --apiserver-advertise-address=${NODE_IP} \
        --kubernetes-version=${K8S_VERSION}

    log_success "Cluster initialized"
}

configure_kubectl() {
    log_step 10 "Configuring kubectl"

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
    log_step 11 "Untainting control-plane for single-node setup"

    kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
    kubectl taint nodes --all node-role.kubernetes.io/master- 2>/dev/null || true

    log_success "Control-plane untainted"
}

install_cni_plugin() {
    log_step 12 "Installing Flannel CNI plugin"

    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

    log_info "Waiting for CoreDNS to be ready..."
    sleep 10

    log_success "CNI plugin installed"
}

install_nginx_ingress() {
    log_step 13 "Installing nginx ingress controller"

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

    log_info "Waiting for deployment to be created..."
    sleep 5

    log_info "Configuring ingress to use hostNetwork (listen on port 80/443)..."
    kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='json' \
        -p='[
          {
            "op": "add",
            "path": "/spec/template/spec/hostNetwork",
            "value": true
          },
          {
            "op": "add",
            "path": "/spec/template/spec/dnsPolicy",
            "value": "ClusterFirstWithHostNet"
          }
        ]' 2>/dev/null || true

    log_info "Waiting for ingress controller to be ready..."
    kubectl rollout status deployment ingress-nginx-controller -n ingress-nginx --timeout=120s 2>/dev/null || sleep 15

    log_success "Nginx ingress controller installed and configured"
    log_info "Ingress listening on port 80 and 443"
}

install_metrics_server() {
    log_step 14 "Installing metrics-server"

    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    # Patch for insecure TLS
    kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' 2>/dev/null || true

    log_success "Metrics-server installed"
}

install_storage_provisioner() {
    log_step 15 "Installing local-path storage provisioner"

    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml

    sleep 10

    # Set as default StorageClass
    kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || true

    log_success "Local-path storage provisioner installed"
}

verify_installation() {
    log_step 16 "Verifying installation"

    log_info "Waiting for node to be ready..."
    sleep 5

    # Check node status
    if kubectl get nodes | grep -q " Ready"; then
        print_status "ok" "Node is Ready"
    else
        log_warn "Node is not Ready yet"
    fi

    # Display node info
    log_info "Node information:"
    kubectl get nodes -o wide

    log_success "Verification completed"
}

display_access_info() {
    log_section "Installation Complete!"

    cat <<EOF
${GREEN}${BOLD}Kubernetes cluster successfully installed!${NC}

${BOLD}Cluster Information:${NC}
  Interface:      ${INTERFACE}
  Node IP:        ${NODE_IP}
  API Server:     https://${NODE_IP}:6443
  Kubernetes:     v${K8S_VERSION}
  Pod CIDR:       ${POD_NETWORK_CIDR}

${BOLD}Cluster Status:${NC}
$(kubectl get nodes -o wide)

${BOLD}Verify Node IP:${NC}
  ${CYAN}kubectl get nodes -o wide${NC}
  ${CYAN}# INTERNAL-IP should show: ${NODE_IP}${NC}

  ${CYAN}cat /etc/sysconfig/kubelet${NC}
  ${CYAN}# Should show: KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}${NC}

${BOLD}Next Steps:${NC}
  1. Deploy the baseline application:
     ${CYAN}cd ../baseline-app${NC}
     ${CYAN}./00-deploy-baseline.sh${NC}

  2. Verify cluster health:
     ${CYAN}cd ../setup${NC}
     ${CYAN}./verify-cluster.sh${NC}

${BOLD}Important Notes:${NC}
  • Firewall is DISABLED (lab environment)
  • SELinux is set to PERMISSIVE mode
  • Node IP configured via /etc/sysconfig/kubelet
  • Interface used: ${INTERFACE}
  • Single-node cluster (control-plane is untainted)

${BOLD}Useful Commands:${NC}
  • Cluster info:  ${CYAN}kubectl cluster-info${NC}
  • All resources: ${CYAN}kubectl get all -A${NC}
  • Node IP check: ${CYAN}kubectl get nodes -o wide${NC}

${BOLD}Log File:${NC} ${LOG_FILE}

EOF
}

main() {
    init_log

    parse_args "$@"

    log_section "Kubernetes Installation with kubeadm"
    log_info "Installing single-node cluster on CentOS/Rocky Linux"
    log_info "Using interface: ${INTERFACE}"

    # Detect IP from interface FIRST
    if ! NODE_IP=$(get_ip_from_interface "${INTERFACE}"); then
        log_error "Failed to detect IP from interface ${INTERFACE}"
        exit 1
    fi

    log_success "Detected IP: ${NODE_IP} from interface: ${INTERFACE}"

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
    configure_selinux
    disable_firewall

    log_section "Installing Container Runtime and Kubernetes"

    install_container_runtime
    install_k8s_tools
    configure_kubelet_node_ip

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
