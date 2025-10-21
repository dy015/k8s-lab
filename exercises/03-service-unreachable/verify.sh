#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
SERVICE="backend-svc"

verify_service_selector() {
    log_info "Checking service selector..."

    local selector=$(kubectl get svc ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.spec.selector.app}')

    if [[ "${selector}" == "backend" ]]; then
        print_status "ok" "Service selector is correct: app=${selector}"
        return 0
    else
        print_status "fail" "Service selector is wrong: app=${selector} (expected: backend)"
        return 1
    fi
}

verify_service_endpoints() {
    log_info "Checking service endpoints..."

    local endpoints=$(kubectl get endpoints ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")

    if [[ -n "${endpoints}" ]]; then
        local count=$(echo "${endpoints}" | wc -w)
        print_status "ok" "Service has ${count} endpoint(s): ${endpoints}"
        return 0
    else
        print_status "fail" "Service has NO endpoints"
        kubectl get endpoints ${SERVICE} -n ${NAMESPACE}
        return 1
    fi
}

verify_backend_pods_running() {
    log_info "Checking backend pods status..."

    local not_running=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers 2>/dev/null | grep -v "Running" | wc -l)

    if [[ $not_running -eq 0 ]]; then
        local count=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers 2>/dev/null | wc -l)
        print_status "ok" "All ${count} backend pod(s) are Running"
        return 0
    else
        print_status "fail" "${not_running} backend pod(s) are not Running"
        return 1
    fi
}

verify_service_connectivity() {
    log_info "Testing service connectivity..."

    local backend_pod=$(kubectl get pods -n ${NAMESPACE} -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "${backend_pod}" ]]; then
        print_status "fail" "No backend pod found for testing"
        return 1
    fi

    if kubectl exec -n ${NAMESPACE} ${backend_pod} -- wget -qO- --timeout=5 http://backend-svc:5000/api/health 2>/dev/null | grep -q "healthy"; then
        print_status "ok" "Backend service is reachable and healthy"
        return 0
    else
        print_status "fail" "Backend service is not reachable or not healthy"
        return 1
    fi
}

verify_pod_labels_match() {
    log_info "Verifying pod labels match service selector..."

    local service_selector=$(kubectl get svc ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.spec.selector.app}')
    local matching_pods=$(kubectl get pods -n ${NAMESPACE} -l app=${service_selector} --no-headers 2>/dev/null | wc -l)

    if [[ ${matching_pods} -gt 0 ]]; then
        print_status "ok" "${matching_pods} pod(s) match the service selector"
        return 0
    else
        print_status "fail" "No pods match the service selector: app=${service_selector}"
        return 1
    fi
}

main() {
    init_log

    log_section "Exercise 03: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    local all_passed=0

    log_step 1 "Verifying Service Selector"
    if ! verify_service_selector; then
        all_passed=1
    fi
    echo

    log_step 2 "Verifying Service Endpoints"
    if ! verify_service_endpoints; then
        all_passed=1
    fi
    echo

    log_step 3 "Verifying Backend Pods Running"
    if ! verify_backend_pods_running; then
        all_passed=1
    fi
    echo

    log_step 4 "Verifying Pod Labels Match Selector"
    if ! verify_pod_labels_match; then
        all_passed=1
    fi
    echo

    log_step 5 "Testing Service Connectivity"
    if ! verify_service_connectivity; then
        all_passed=1
    fi
    echo

    log_section "Verification Summary"

    if [[ $all_passed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

${BOLD}Service Configuration:${NC}
EOF
        kubectl get svc ${SERVICE} -n ${NAMESPACE}
        echo
        kubectl get endpoints ${SERVICE} -n ${NAMESPACE}

        cat <<EOF

${BOLD}Access the application:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}What you learned:${NC}
  ✓ How Kubernetes Services use label selectors
  ✓ The importance of matching labels and selectors
  ✓ How to diagnose service endpoint issues
  ✓ How to check service connectivity
  ✓ The role of endpoints in service routing

${BOLD}Key Concepts:${NC}
  • Services find pods using label selectors
  • Endpoints are automatically managed by Kubernetes
  • No endpoints = service can't route traffic
  • kubectl get endpoints is your friend!

${GREEN}${BOLD}Exercise 03 completed successfully!${NC}

${BOLD}Next steps:${NC}
  • Visit the dashboard and verify tasks load
  • Try Exercise 04: ${CYAN}cd ../04-configmap-missing${NC}
  • Reset to baseline: ${CYAN}./reset.sh${NC}

EOF
        log_success "Verification completed successfully!"
        return 0
    else
        cat <<EOF
${RED}${BOLD}✗ Some checks failed${NC}

${BOLD}Troubleshooting:${NC}
  1. Check selector: ${CYAN}kubectl describe svc ${SERVICE} -n ${NAMESPACE} | grep Selector${NC}
  2. Check endpoints: ${CYAN}kubectl get endpoints ${SERVICE} -n ${NAMESPACE}${NC}
  3. Check labels: ${CYAN}kubectl get pods -n ${NAMESPACE} --show-labels${NC}
  4. Try fix again: ${CYAN}./fix.sh${NC}

${BOLD}Debug commands:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=backend --show-labels${NC}
  ${CYAN}kubectl describe svc ${SERVICE} -n ${NAMESPACE}${NC}

EOF
        log_error "Verification failed. Please review the errors above."
        return 1
    fi
}

main "$@"
