#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"

verify_memory_limits() {
    log_info "Checking memory limits..."

    local memory_limit=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "")
    local memory_request=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")

    if [[ -z "${memory_limit}" ]]; then
        print_status "fail" "No memory limit set"
        return 1
    fi

    # Convert to Mi for comparison
    local limit_value=$(echo "${memory_limit}" | sed 's/Mi//')
    local request_value=$(echo "${memory_request}" | sed 's/Mi//')

    if [[ "${limit_value}" -ge 256 ]]; then
        print_status "ok" "Memory limit is ${memory_limit} (sufficient)"
    else
        print_status "fail" "Memory limit is ${memory_limit} (too low, needs >= 256Mi)"
        return 1
    fi

    if [[ -n "${memory_request}" ]]; then
        print_status "ok" "Memory request is ${memory_request}"
    else
        print_status "warn" "No memory request set (affects scheduling)"
    fi

    return 0
}

verify_no_oom_kills() {
    log_info "Checking for OOM kills..."

    local oom_pods=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers 2>/dev/null | grep "OOMKilled" | wc -l)

    if [[ $oom_pods -eq 0 ]]; then
        print_status "ok" "No pods currently in OOMKilled state"
        return 0
    else
        print_status "fail" "${oom_pods} pod(s) in OOMKilled state"
        kubectl get pods -n ${NAMESPACE} -l app=backend
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

    local high_restarts=0
    for count in ${restart_counts}; do
        if [[ ${count} -gt 10 ]]; then
            high_restarts=$((high_restarts + 1))
        fi
    done

    if [[ ${high_restarts} -eq 0 ]]; then
        print_status "ok" "Pod restart counts are reasonable"
        return 0
    else
        print_status "warn" "${high_restarts} pod(s) have high restart counts (may be from before fix)"
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

verify_resource_usage() {
    log_info "Checking actual memory usage..."

    if ! command -v kubectl >/dev/null 2>&1 || ! kubectl top node >/dev/null 2>&1; then
        print_status "skip" "Metrics server not available"
        return 0
    fi

    local backend_pods=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers -o name 2>/dev/null)

    if [[ -z "${backend_pods}" ]]; then
        print_status "fail" "No backend pods found"
        return 1
    fi

    for pod in ${backend_pods}; do
        local pod_name=$(echo ${pod} | cut -d'/' -f2)
        local memory_usage=$(kubectl top pod ${pod_name} -n ${NAMESPACE} --no-headers 2>/dev/null | awk '{print $3}' || echo "")

        if [[ -n "${memory_usage}" ]]; then
            print_status "info" "Pod ${pod_name} using ${memory_usage} memory"
        fi
    done

    return 0
}

main() {
    init_log

    log_section "Exercise 06: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    local all_passed=0

    log_step 1 "Verifying Memory Limits"
    if ! verify_memory_limits; then
        all_passed=1
    fi
    echo

    log_step 2 "Checking for OOM Kills"
    if ! verify_no_oom_kills; then
        all_passed=1
    fi
    echo

    log_step 3 "Verifying Pod Stability"
    if ! verify_pods_stable; then
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

    log_step 6 "Checking Resource Usage"
    verify_resource_usage
    echo

    log_section "Verification Summary"

    if [[ $all_passed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

${BOLD}Resource Configuration:${NC}
EOF
        kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].resources}' | python3 -m json.tool 2>/dev/null || \
        kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].resources}'

        cat <<EOF

${BOLD}Pod Status:${NC}
EOF
        kubectl get pods -n ${NAMESPACE} -l app=backend

        cat <<EOF

${BOLD}Access the application:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}What you learned:${NC}
  ✓ How to diagnose OOMKilled pods
  ✓ Understanding memory limits vs requests
  ✓ Exit code 137 = SIGKILL for OOM
  ✓ How to set appropriate resource limits
  ✓ The importance of monitoring resource usage

${BOLD}Key Commands:${NC}
  • kubectl top pod - View current resource usage
  • kubectl describe pod - See OOM events
  • kubectl patch deployment - Update resources
  • kubectl logs --previous - Logs before OOM

${BOLD}Resource Management:${NC}
  • Requests: Guaranteed minimum (scheduling)
  • Limits: Maximum allowed (enforcement)
  • Memory exceeded = OOMKilled
  • CPU exceeded = Throttled (not killed)

${GREEN}${BOLD}Exercise 06 completed successfully!${NC}

${BOLD}Next steps:${NC}
  • Monitor resource usage over time
  • Try Exercise 07: ${CYAN}cd ../07-liveness-probe-fail${NC}
  • Reset to baseline: ${CYAN}./reset.sh${NC}

EOF
        log_success "Verification completed successfully!"
        return 0
    else
        cat <<EOF
${RED}${BOLD}✗ Some checks failed${NC}

${BOLD}Troubleshooting:${NC}
  1. Check memory limits: ${CYAN}kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml | grep -A 5 resources${NC}
  2. Check pod status: ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=backend${NC}
  3. Check events: ${CYAN}kubectl get events -n ${NAMESPACE} | grep OOMKilled${NC}
  4. Try fix again: ${CYAN}./fix.sh${NC}

EOF
        log_error "Verification failed. Please review the errors above."
        return 1
    fi
}

main "$@"