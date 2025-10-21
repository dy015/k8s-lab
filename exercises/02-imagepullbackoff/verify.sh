#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="frontend"

verify_pod_status() {
    log_info "Checking pod status..."

    local not_running=$(kubectl get pods -n ${NAMESPACE} -l app=frontend --no-headers 2>/dev/null | grep -v "Running" | wc -l)

    if [[ $not_running -eq 0 ]]; then
        print_status "ok" "All frontend pods are in Running state"
        return 0
    else
        print_status "fail" "${not_running} pods are not in Running state"
        kubectl get pods -n ${NAMESPACE} -l app=frontend
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

verify_image_config() {
    log_info "Checking image configuration..."

    local current_image=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}')
    local expected_image="docker.io/reddydodda/taskmaster-frontend:1.0"

    if [[ "${current_image}" == "${expected_image}" ]]; then
        print_status "ok" "Image is correctly set to: ${current_image}"
        return 0
    else
        print_status "fail" "Image is: ${current_image}, expected: ${expected_image}"
        return 1
    fi
}

verify_no_image_pull_errors() {
    log_info "Checking for image pull errors..."

    local pull_errors=$(kubectl get events -n ${NAMESPACE} --field-selector involvedObject.kind=Pod 2>/dev/null | grep -i "Failed.*pull\|ImagePullBackOff\|ErrImagePull" | wc -l)

    if [[ $pull_errors -eq 0 ]]; then
        print_status "ok" "No recent image pull errors detected"
        return 0
    else
        print_status "warn" "Found ${pull_errors} recent image pull error events (may be from before the fix)"
        return 0
    fi
}

verify_frontend_accessible() {
    log_info "Checking frontend service endpoint..."

    local frontend_pod=$(kubectl get pods -n ${NAMESPACE} -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "${frontend_pod}" ]]; then
        print_status "fail" "No frontend pod found"
        return 1
    fi

    if kubectl exec -n ${NAMESPACE} ${frontend_pod} -- wget -qO- http://localhost 2>&1 | grep -q "TaskMaster"; then
        print_status "ok" "Frontend is serving content"
        return 0
    else
        print_status "fail" "Frontend is not responding correctly"
        return 1
    fi
}

main() {
    init_log

    log_section "Exercise 02: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    local all_passed=0

    log_step 1 "Verifying Pod Status"
    if ! verify_pod_status; then
        all_passed=1
    fi
    echo

    log_step 2 "Verifying Deployment Ready"
    if ! verify_deployment_ready; then
        all_passed=1
    fi
    echo

    log_step 3 "Verifying Image Configuration"
    if ! verify_image_config; then
        all_passed=1
    fi
    echo

    log_step 4 "Checking Image Pull Errors"
    if ! verify_no_image_pull_errors; then
        all_passed=1
    fi
    echo

    log_step 5 "Verifying Frontend Accessibility"
    if ! verify_frontend_accessible; then
        all_passed=1
    fi
    echo

    log_section "Verification Summary"

    if [[ $all_passed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

${BOLD}Frontend Status:${NC}
EOF
        kubectl get pods -n ${NAMESPACE} -l app=frontend

        cat <<EOF

${BOLD}Access the application:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}What you learned:${NC}
  ✓ How to diagnose ImagePullBackOff errors
  ✓ How to check image configuration
  ✓ How to fix incorrect image tags
  ✓ How to verify image pull is working

${GREEN}${BOLD}Exercise 02 completed successfully!${NC}

${BOLD}Next steps:${NC}
  • Visit the dashboard and verify it loads
  • Try Exercise 03: ${CYAN}cd ../03-service-unreachable${NC}
  • Reset to baseline: ${CYAN}./reset.sh${NC}

EOF
        log_success "Verification completed successfully!"
        return 0
    else
        cat <<EOF
${RED}${BOLD}✗ Some checks failed${NC}

${BOLD}Troubleshooting:${NC}
  1. Check pod status: ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=frontend${NC}
  2. Check events: ${CYAN}kubectl get events -n ${NAMESPACE} | grep frontend${NC}
  3. Check image: ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}
  4. Try fix again: ${CYAN}./fix.sh${NC}

EOF
        log_error "Verification failed. Please review the errors above."
        return 1
    fi
}

main "$@"
