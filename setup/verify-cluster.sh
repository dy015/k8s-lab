#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

verify_kubelet_service() {
    log_info "Checking kubelet service..."

    if systemctl is-active --quiet kubelet; then
        print_status "ok" "kubelet service is running"
        return 0
    else
        print_status "fail" "kubelet service is not running"
        systemctl status kubelet --no-pager || true
        return 1
    fi
}

verify_containerd_service() {
    log_info "Checking containerd service..."

    if systemctl is-active --quiet containerd; then
        print_status "ok" "containerd service is running"
        return 0
    else
        print_status "fail" "containerd service is not running"
        systemctl status containerd --no-pager || true
        return 1
    fi
}

verify_kubectl_connectivity() {
    log_info "Checking kubectl connectivity..."

    if ! command_exists kubectl; then
        print_status "fail" "kubectl not found"
        return 1
    fi

    if kubectl cluster-info >/dev/null 2>&1; then
        print_status "ok" "kubectl can connect to the cluster"
        kubectl cluster-info
        return 0
    else
        print_status "fail" "kubectl cannot connect to the cluster"
        log_info "Check if KUBECONFIG is set: echo \$KUBECONFIG"
        return 1
    fi
}

verify_node_status() {
    log_info "Checking node status..."

    local node_status=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}')

    if [[ "${node_status}" == "Ready" ]]; then
        print_status "ok" "Node is Ready"
        kubectl get nodes
        return 0
    else
        print_status "fail" "Node is not Ready (status: ${node_status})"
        kubectl describe nodes
        return 1
    fi
}

verify_control_plane_pods() {
    log_info "Checking control plane pods..."

    local etcd_status=$(kubectl get pod -n kube-system -l component=etcd --no-headers 2>/dev/null | awk '{print $3}' | head -1)
    local apiserver_status=$(kubectl get pod -n kube-system -l component=kube-apiserver --no-headers 2>/dev/null | awk '{print $3}' | head -1)
    local controller_status=$(kubectl get pod -n kube-system -l component=kube-controller-manager --no-headers 2>/dev/null | awk '{print $3}' | head -1)
    local scheduler_status=$(kubectl get pod -n kube-system -l component=kube-scheduler --no-headers 2>/dev/null | awk '{print $3}' | head -1)

    local failed=0

    if [[ "${etcd_status}" == "Running" ]]; then
        print_status "ok" "etcd is Running"
    else
        print_status "fail" "etcd status: ${etcd_status}"
        ((failed++))
    fi

    if [[ "${apiserver_status}" == "Running" ]]; then
        print_status "ok" "kube-apiserver is Running"
    else
        print_status "fail" "kube-apiserver status: ${apiserver_status}"
        ((failed++))
    fi

    if [[ "${controller_status}" == "Running" ]]; then
        print_status "ok" "kube-controller-manager is Running"
    else
        print_status "fail" "kube-controller-manager status: ${controller_status}"
        ((failed++))
    fi

    if [[ "${scheduler_status}" == "Running" ]]; then
        print_status "ok" "kube-scheduler is Running"
    else
        print_status "fail" "kube-scheduler status: ${scheduler_status}"
        ((failed++))
    fi

    if [[ ${failed} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

verify_system_pods() {
    log_info "Checking system pods..."

    local total_pods=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
    local running_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c " Running\| Completed" || true)
    local not_running=$((total_pods - running_pods))

    if [[ $not_running -eq 0 ]]; then
        print_status "ok" "All ${total_pods} system pods are Running/Completed"
    else
        print_status "warn" "${not_running}/${total_pods} pods are not Running"
        log_info "Pods not in Running/Completed state:"
        kubectl get pods -A --no-headers | grep -v "Running\|Completed"
    fi

    echo
    kubectl get pods -A
}

verify_coredns() {
    log_info "Checking CoreDNS..."

    local replicas=$(kubectl get deployment coredns -n kube-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

    if [[ $replicas -gt 0 ]]; then
        print_status "ok" "CoreDNS is running (${replicas} replicas available)"
        return 0
    else
        print_status "fail" "CoreDNS is not running"
        kubectl describe deployment coredns -n kube-system
        return 1
    fi
}

verify_cni_plugin() {
    log_info "Checking CNI plugin (Flannel)..."

    if kubectl get daemonset kube-flannel-ds -n kube-flannel >/dev/null 2>&1; then
        local desired=$(kubectl get daemonset kube-flannel-ds -n kube-flannel -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
        local ready=$(kubectl get daemonset kube-flannel-ds -n kube-flannel -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")

        if [[ "${desired}" == "${ready}" ]] && [[ "${ready}" -gt 0 ]]; then
            print_status "ok" "Flannel CNI is running (${ready}/${desired} pods ready)"
            return 0
        else
            print_status "warn" "Flannel CNI: ${ready}/${desired} pods ready"
            return 1
        fi
    else
        print_status "warn" "Flannel CNI not found (check kube-system namespace)"
        kubectl get pods -n kube-system | grep -i flannel || true
        return 1
    fi
}

verify_dns_resolution() {
    log_info "Testing DNS resolution..."

    local test_output=$(kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never --command -- nslookup kubernetes.default 2>&1 || true)

    if echo "${test_output}" | grep -q "Server:"; then
        print_status "ok" "DNS resolution is working"
        return 0
    else
        print_status "fail" "DNS resolution failed"
        echo "${test_output}"
        return 1
    fi
}

verify_ingress_controller() {
    log_info "Checking ingress controller..."

    if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
        local replicas=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

        if [[ $replicas -gt 0 ]]; then
            print_status "ok" "Ingress controller is running (${replicas} replicas)"
            return 0
        else
            print_status "warn" "Ingress controller deployment exists but no replicas available"
            kubectl get deployment ingress-nginx-controller -n ingress-nginx
            return 1
        fi
    else
        print_status "warn" "Ingress controller is not installed"
        return 1
    fi
}

verify_metrics_server() {
    log_info "Checking metrics-server..."

    if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
        local replicas=$(kubectl get deployment metrics-server -n kube-system -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

        if [[ $replicas -gt 0 ]]; then
            print_status "ok" "Metrics-server is running (${replicas} replicas)"

            log_info "Testing metrics collection (may take a minute)..."
            sleep 10
            if kubectl top nodes >/dev/null 2>&1; then
                print_status "ok" "Metrics collection is working"
            else
                print_status "warn" "Metrics collection not ready yet (give it more time)"
            fi
            return 0
        else
            print_status "warn" "Metrics-server deployment exists but no replicas available"
            return 1
        fi
    else
        print_status "warn" "Metrics-server is not installed"
        return 1
    fi
}

verify_storage_class() {
    log_info "Checking storage class..."

    local storage_classes=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)

    if [[ ${storage_classes} -gt 0 ]]; then
        print_status "ok" "StorageClass(es) available: ${storage_classes}"
        kubectl get storageclass
        return 0
    else
        print_status "warn" "No StorageClass found (will be created during app deployment)"
        return 0  # Not a failure, as baseline app will create it
    fi
}

check_resource_usage() {
    log_info "Checking resource usage..."

    echo
    echo -e "${BOLD}Node Resources:${NC}"
    kubectl top nodes 2>/dev/null || log_warn "Metrics not available yet"

    echo
    echo -e "${BOLD}System Pod Resources:${NC}"
    kubectl top pods -A 2>/dev/null || log_warn "Metrics not available yet"
}

display_summary() {
    local failed=$1

    log_section "Verification Summary"

    if [[ $failed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

Your Kubernetes cluster is healthy and ready to use.

${BOLD}Cluster Details:${NC}
  Installation: kubeadm
  Runtime: containerd
  CNI: Flannel
  Ingress: nginx-ingress

${BOLD}Next Steps:${NC}
  1. Deploy the baseline application:
     ${CYAN}cd ../baseline-app${NC}
     ${CYAN}./00-deploy-baseline.sh${NC}

  2. Start with the exercises:
     ${CYAN}cd ../exercises/01-crashloopbackoff${NC}
     ${CYAN}cat README.md${NC}

${BOLD}Useful Commands:${NC}
  • kubectl get all -A
  • kubectl get nodes -o wide
  • kubectl top nodes
  • kubectl top pods -A

EOF
    else
        cat <<EOF
${YELLOW}${BOLD}⚠ ${failed} check(s) failed or returned warnings${NC}

Some components may not be fully ready. This could be normal if the cluster
was just installed. Wait a few minutes and run this script again.

${BOLD}To troubleshoot:${NC}
  • Check kubelet service: ${CYAN}systemctl status kubelet${NC}
  • View kubelet logs: ${CYAN}journalctl -u kubelet -f${NC}
  • Check containerd: ${CYAN}systemctl status containerd${NC}
  • Check all pods: ${CYAN}kubectl get pods -A${NC}
  • View pod logs: ${CYAN}kubectl logs -n kube-system <pod-name>${NC}

${BOLD}Common Issues:${NC}
  • If control plane pods fail: Check ${CYAN}/var/log/pods/${NC}
  • If CNI issues: ${CYAN}kubectl logs -n kube-flannel <pod-name>${NC}
  • If DNS fails: ${CYAN}kubectl logs -n kube-system -l k8s-app=kube-dns${NC}

EOF
    fi
}

main() {
    init_log

    log_section "Kubernetes Cluster Verification"

    local failed=0

    verify_kubelet_service || ((failed++))
    echo

    verify_containerd_service || ((failed++))
    echo

    verify_kubectl_connectivity || ((failed++))
    echo

    verify_node_status || ((failed++))
    echo

    verify_control_plane_pods || ((failed++))
    echo

    verify_system_pods || ((failed++))
    echo

    verify_coredns || ((failed++))
    echo

    verify_cni_plugin || ((failed++))
    echo

    verify_dns_resolution || ((failed++))
    echo

    verify_ingress_controller || ((failed++))
    echo

    verify_metrics_server || ((failed++))
    echo

    verify_storage_class || ((failed++))
    echo

    check_resource_usage
    echo

    display_summary $failed

    if [[ $failed -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
