#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"

verify_probe_endpoint() {
    log_info "Checking liveness probe configuration..."

    local probe_path=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null || echo "")

    if [[ "${probe_path}" == "/api/health" ]]; then
        print_status "ok" "Liveness probe endpoint is correct: ${probe_path}"
        return 0
    elif [[ -z "${probe_path}" ]]; then
        print_status "warn" "No liveness probe configured"
        return 0
    else
        print_status "fail" "Liveness probe endpoint is wrong: ${probe_path}"
        return 1
    fi
}

verify_pods_stable() {
    log_info "Checking pod stability..."

    local restart_counts=$(kubectl get pods -n ${NAMESPACE} -l app=backend -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' 2>/dev/null || echo "")

    if [[ -z "${restart_counts}" ]]; then
        print_status "fail" "No backend pods found"
        return 1
    fi

    local max_restarts=0
    for count in ${restart_counts}; do
        if [[ ${count} -gt ${max_restarts} ]]; then
            max_restarts=${count}
        fi
    done

    if [[ ${max_restarts} -lt 10 ]]; then
        print_status "ok" "Pod restart counts are stable (max: ${max_restarts})"
        return 0
    else
        print_status "warn" "High restart count detected (max: ${max_restarts}) - may be from before fix"
        return 0
    fi
}

verify_no_probe_failures() {
    log_info "Checking for recent probe failures..."

    local probe_failures=$(kubectl get events -n ${NAMESPACE} --field-selector involvedObject.kind=Pod 2>/dev/null | grep -i "Liveness probe failed" | grep "1m\|[0-9]s" | wc -l)

    if [[ $probe_failures -eq 0 ]]; then
        print_status "ok" "No recent liveness probe failures"
        return 0
    else
        print_status "warn" "Found ${probe_failures} recent probe failure events (may be from before fix)"
        return 0
    fi
}

verify_pods_running() {
    log_info "Checking backend pods status..."

    local not_running=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers 2>/dev/null | grep -v "Running" | wc -l)

    if [[ $not_running -eq 0 ]]; then
        local count=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers 2>/dev/null | wc -l)
        print_status "ok" "All ${count} backend pod(s) are Running"
        return 0
    else
        print_status "fail" "${not_running} backend pod(s) are not Running"
        kubectl get pods -n ${NAMESPACE} -l app=backend
        return 1
    fi
}

verify_deployment_ready() {
    log_info "Checking deployment readiness..."

    local ready_replicas=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired_replicas=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    if [[ "${ready_replicas}" == "${desired_replicas}" ]] && [[ "${ready_replicas}" != "0" ]]; then
        print_status "ok" "Deployment has ${ready_replicas}/${desired_replicas} replicas ready"
        return 0
    else
        print_status "fail" "Deployment has ${ready_replicas}/${desired_replicas} replicas ready"
        return 1
    fi
}

main() {
    init_log

    log_section "Exercise 07: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    local all_passed=0

    log_step 1 "Verifying Probe Configuration"
    if ! verify_probe_endpoint; then
        all_passed=1
    fi
    echo

    log_step 2 "Verifying Pod Stability"
    if ! verify_pods_stable; then
        all_passed=1
    fi
    echo

    log_step 3 "Checking for Probe Failures"
    if ! verify_no_probe_failures; then
        all_passed=1
    fi
    echo

    log_step 4 "Verifying Pods Running"
    if ! verify_pods_running; then
        all_passed=1
    fi
    echo

    log_step 5 "Verifying Deployment Ready"
    if ! verify_deployment_ready; then
        all_passed=1
    fi
    echo

    log_section "Verification Summary"

    if [[ $all_passed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

${BOLD}Probe Configuration:${NC}
EOF
        kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml | grep -A 10 "livenessProbe:"

        cat <<EOF

${BOLD}Pod Status:${NC}
EOF
        kubectl get pods -n ${NAMESPACE} -l app=backend

        cat <<EOF

${BOLD}Access the application:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}What you learned:${NC}
  ✓ How liveness probes work
  ✓ Difference between liveness and readiness
  ✓ How to diagnose probe failures
  ✓ Importance of correct health endpoints
  ✓ Probe timing configuration

${GREEN}${BOLD}Exercise 07 completed successfully!${NC}

${BOLD}Next steps:${NC}
  • Monitor pod stability
  • Try Exercise 08: ${CYAN}cd ../08-readiness-probe-fail${NC}
  • Reset to baseline: ${CYAN}./reset.sh${NC}

EOF
        log_success "Verification completed successfully!"
        return 0
    else
        cat <<EOF
${RED}${BOLD}✗ Some checks failed${NC}

${BOLD}Troubleshooting:${NC}
  1. Check probe config: ${CYAN}kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml | grep -A 10 livenessProbe${NC}
  2. Check pod status: ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=backend${NC}
  3. Check events: ${CYAN}kubectl get events -n ${NAMESPACE} | grep "probe"${NC}
  4. Try fix again: ${CYAN}./fix.sh${NC}

EOF
        log_error "Verification failed. Please review the errors above."
        return 1
    fi
}

main "$@"