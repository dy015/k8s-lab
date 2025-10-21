#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"

verify_pods_running() {
    log_info "Checking pod status..."

    local not_running=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers | grep -v " Running" | wc -l)

    if [[ $not_running -eq 0 ]]; then
        print_status "ok" "All backend pods are Running"
        return 0
    else
        print_status "fail" "Some backend pods are not Running"
        kubectl get pods -n ${NAMESPACE} -l app=backend
        return 1
    fi
}

verify_pods_ready() {
    log_info "Checking if pods are ready..."

    local ready_replicas=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired_replicas=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

    if [[ "${ready_replicas}" == "${desired_replicas}" ]] && [[ "${ready_replicas}" -gt 0 ]]; then
        print_status "ok" "${ready_replicas}/${desired_replicas} pods are ready"
        return 0
    else
        print_status "fail" "Only ${ready_replicas}/${desired_replicas} pods are ready"
        return 1
    fi
}

verify_no_restarts() {
    log_info "Checking for pod restarts..."

    local max_restarts=$(kubectl get pods -n ${NAMESPACE} -l app=backend -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' | tr ' ' '\n' | sort -nr | head -1 || echo "0")

    if [[ $max_restarts -eq 0 ]]; then
        print_status "ok" "No pod restarts detected"
        return 0
    else
        print_status "warn" "Pods have ${max_restarts} restart(s) (expected after fixing issue)"
        return 0
    fi
}

verify_api_health() {
    log_info "Testing API health..."

    local backend_pod=$(kubectl get pods -n ${NAMESPACE} -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "${backend_pod}" ]]; then
        print_status "fail" "No backend pod found"
        return 1
    fi

    if kubectl exec -n ${NAMESPACE} ${backend_pod} -- wget -qO- http://localhost:5000/api/health >/dev/null 2>&1; then
        print_status "ok" "Backend API is responding"
        return 0
    else
        print_status "fail" "Backend API is not responding"
        return 1
    fi
}

verify_deployment_config() {
    log_info "Checking deployment configuration..."

    local command=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].command[-1]}' 2>/dev/null || echo "")

    if [[ "${command}" == "app:app" ]]; then
        print_status "ok" "Deployment command is correct"
        return 0
    else
        print_status "fail" "Deployment command is still incorrect: ${command}"
        return 1
    fi
}

main() {
    init_log

    log_section "Exercise 01: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    local failed=0

    verify_pods_running || ((failed++))
    echo

    verify_pods_ready || ((failed++))
    echo

    verify_no_restarts || ((failed++))
    echo

    verify_api_health || ((failed++))
    echo

    verify_deployment_config || ((failed++))
    echo

    log_section "Verification Results"

    if [[ $failed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

${BOLD}The issue has been successfully resolved!${NC}

${BOLD}Summary:${NC}
  • Backend pods are Running
  • All replicas are ready
  • API health check passes
  • Deployment configuration is correct

${BOLD}You've successfully:${NC}
  ✓ Diagnosed a CrashLoopBackOff issue
  ✓ Identified the root cause (typo in command)
  ✓ Applied the fix
  ✓ Verified the application is working

${BOLD}Check the dashboard:${NC}
  http://taskmaster.local
  Backend should show ${GREEN}green status${NC}

${BOLD}Next Exercise:${NC}
  ${CYAN}cd ../02-imagepullbackoff${NC}

EOF
        exit 0
    else
        cat <<EOF
${YELLOW}${BOLD}⚠ ${failed} check(s) failed${NC}

${BOLD}The issue may not be fully resolved yet.${NC}

${BOLD}Troubleshooting:${NC}
  • Check pod status:    ${CYAN}kubectl get pods -n ${NAMESPACE}${NC}
  • Check pod logs:      ${CYAN}kubectl logs -n ${NAMESPACE} <pod-name>${NC}
  • Describe pod:        ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}
  • Check deployment:    ${CYAN}kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml${NC}

${BOLD}Try again:${NC}
  • Re-run fix script:   ${CYAN}./fix.sh${NC}
  • Or reset and retry:  ${CYAN}./reset.sh${NC}

EOF
        exit 1
    fi
}

main "$@"
