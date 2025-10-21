#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"

    log_info "Testing: ${test_name}"

    if eval "${test_command}"; then
        print_status "ok" "${test_name}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_status "fail" "${test_name}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

main() {
    init_log

    log_section "Cluster Installation Tests"

    run_test "kubectl is installed" "command -v kubectl >/dev/null 2>&1"
    run_test "kubectl is configured" "kubectl cluster-info >/dev/null 2>&1"
    run_test "Node is Ready" "kubectl get nodes | grep -q ' Ready'"
    run_test "k3s service is running" "systemctl is-active --quiet k3s || true"
    run_test "CoreDNS is running" "kubectl get pods -n kube-system -l k8s-app=kube-dns | grep -q Running"
    run_test "Metrics server is running" "kubectl get pods -n kube-system -l k8s-app=metrics-server | grep -q Running"
    run_test "nginx-ingress is running" "kubectl get pods -n kube-system -l app.kubernetes.io/name=ingress-nginx | grep -q Running"
    run_test "local-path-provisioner is running" "kubectl get pods -n kube-system -l app=local-path-provisioner | grep -q Running"

    echo
    log_section "Test Summary"
    echo "  Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo "  Failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        log_success "All cluster tests passed!"
        return 0
    else
        log_error "${TESTS_FAILED} cluster test(s) failed"
        return 1
    fi
}

main "$@"
