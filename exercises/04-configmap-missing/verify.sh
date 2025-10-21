#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
CONFIGMAP="backend-config"
DEPLOYMENT="backend"

verify_configmap_exists() {
    log_info "Checking if ConfigMap exists..."

    if kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE} >/dev/null 2>&1; then
        print_status "ok" "ConfigMap '${CONFIGMAP}' exists"
        return 0
    else
        print_status "fail" "ConfigMap '${CONFIGMAP}' not found"
        return 1
    fi
}

verify_configmap_data() {
    log_info "Checking ConfigMap data..."

    local has_flask_env=$(kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE} -o jsonpath='{.data.FLASK_ENV}' 2>/dev/null || echo "")
    local has_log_level=$(kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE} -o jsonpath='{.data.LOG_LEVEL}' 2>/dev/null || echo "")
    local has_workers=$(kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE} -o jsonpath='{.data.WORKERS}' 2>/dev/null || echo "")

    if [[ -n "${has_flask_env}" ]] && [[ -n "${has_log_level}" ]] && [[ -n "${has_workers}" ]]; then
        print_status "ok" "ConfigMap has required keys: FLASK_ENV, LOG_LEVEL, WORKERS"
        return 0
    else
        print_status "fail" "ConfigMap is missing required keys"
        return 1
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

verify_no_config_errors() {
    log_info "Checking for configuration errors..."

    local config_errors=$(kubectl get events -n ${NAMESPACE} --field-selector involvedObject.kind=Pod 2>/dev/null | grep -i "CreateContainerConfigError\|configmap.*not found" | wc -l)

    if [[ $config_errors -eq 0 ]]; then
        print_status "ok" "No configuration errors detected"
        return 0
    else
        print_status "warn" "Found ${config_errors} configuration error events (may be from before the fix)"
        return 0
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

    log_section "Exercise 04: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    local all_passed=0

    log_step 1 "Verifying ConfigMap Exists"
    if ! verify_configmap_exists; then
        all_passed=1
    fi
    echo

    log_step 2 "Verifying ConfigMap Data"
    if ! verify_configmap_data; then
        all_passed=1
    fi
    echo

    log_step 3 "Verifying Pods Running"
    if ! verify_pods_running; then
        all_passed=1
    fi
    echo

    log_step 4 "Verifying Deployment Ready"
    if ! verify_deployment_ready; then
        all_passed=1
    fi
    echo

    log_step 5 "Checking for Config Errors"
    if ! verify_no_config_errors; then
        all_passed=1
    fi
    echo

    log_section "Verification Summary"

    if [[ $all_passed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

${BOLD}ConfigMap Status:${NC}
EOF
        kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE}
        echo
        kubectl describe configmap ${CONFIGMAP} -n ${NAMESPACE}

        cat <<EOF

${BOLD}Backend Status:${NC}
EOF
        kubectl get pods -n ${NAMESPACE} -l app=backend

        cat <<EOF

${BOLD}Access the application:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}What you learned:${NC}
  ✓ How ConfigMaps provide configuration to pods
  ✓ How to diagnose CreateContainerConfigError
  ✓ How to recreate missing ConfigMaps
  ✓ How to verify ConfigMap data
  ✓ The importance of backing up configurations

${BOLD}Key Commands:${NC}
  • kubectl create configmap - Create ConfigMaps
  • kubectl get configmaps - List ConfigMaps
  • kubectl describe configmap - View ConfigMap details
  • kubectl delete configmap - Delete ConfigMaps (use with care!)

${GREEN}${BOLD}Exercise 04 completed successfully!${NC}

${BOLD}Next steps:${NC}
  • Visit the dashboard and verify backend works
  • Try Exercise 05: ${CYAN}cd ../05-secret-missing${NC}
  • Reset to baseline: ${CYAN}./reset.sh${NC}

EOF
        log_success "Verification completed successfully!"
        return 0
    else
        cat <<EOF
${RED}${BOLD}✗ Some checks failed${NC}

${BOLD}Troubleshooting:${NC}
  1. Check ConfigMap: ${CYAN}kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE}${NC}
  2. Check pod status: ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=backend${NC}
  3. Check events: ${CYAN}kubectl get events -n ${NAMESPACE} | grep backend${NC}
  4. Try fix again: ${CYAN}./fix.sh${NC}

EOF
        log_error "Verification failed. Please review the errors above."
        return 1
    fi
}

main "$@"
