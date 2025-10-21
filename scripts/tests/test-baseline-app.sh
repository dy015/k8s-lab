#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
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

    log_section "Baseline Application Tests"

    run_test "Namespace exists" "kubectl get namespace ${NAMESPACE} >/dev/null 2>&1"
    run_test "Frontend deployment exists" "kubectl get deployment frontend -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Backend deployment exists" "kubectl get deployment backend -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Database deployment exists" "kubectl get deployment postgres -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Frontend service exists" "kubectl get svc frontend-svc -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Backend service exists" "kubectl get svc backend-svc -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Database service exists" "kubectl get svc postgres-svc -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Ingress exists" "kubectl get ingress -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Frontend pods are running" "kubectl get pods -n ${NAMESPACE} -l app=frontend --no-headers 2>/dev/null | grep -q Running"
    run_test "Backend pods are running" "kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers 2>/dev/null | grep -q Running"
    run_test "Database pod is running" "kubectl get pods -n ${NAMESPACE} -l app=postgres --no-headers 2>/dev/null | grep -q Running"
    run_test "Backend ConfigMap exists" "kubectl get configmap backend-config -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Backend Secret exists" "kubectl get secret backend-secret -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "Database Secret exists" "kubectl get secret database-secret -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "PVC exists" "kubectl get pvc postgres-pvc -n ${NAMESPACE} >/dev/null 2>&1"
    run_test "PVC is bound" "kubectl get pvc postgres-pvc -n ${NAMESPACE} | grep -q Bound"
    run_test "Backend has endpoints" "kubectl get endpoints backend-svc -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q ."
    run_test "Frontend has endpoints" "kubectl get endpoints frontend-svc -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q ."

    echo
    log_section "Test Summary"
    echo "  Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo "  Failed: ${RED}${TESTS_FAILED}${NC}"

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        log_success "All baseline application tests passed!"
        return 0
    else
        log_error "${TESTS_FAILED} baseline test(s) failed"
        return 1
    fi
}

main "$@"
