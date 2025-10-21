#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
SECRET="backend-secret"
DEPLOYMENT="backend"

verify_secret_exists() {
    log_info "Checking if Secret exists..."

    if kubectl get secret ${SECRET} -n ${NAMESPACE} >/dev/null 2>&1; then
        print_status "ok" "Secret '${SECRET}' exists"
        return 0
    else
        print_status "fail" "Secret '${SECRET}' not found"
        return 1
    fi
}

verify_secret_data() {
    log_info "Checking Secret data..."

    local has_db_host=$(kubectl get secret ${SECRET} -n ${NAMESPACE} -o jsonpath='{.data.DB_HOST}' 2>/dev/null || echo "")
    local has_db_port=$(kubectl get secret ${SECRET} -n ${NAMESPACE} -o jsonpath='{.data.DB_PORT}' 2>/dev/null || echo "")
    local has_db_name=$(kubectl get secret ${SECRET} -n ${NAMESPACE} -o jsonpath='{.data.DB_NAME}' 2>/dev/null || echo "")

    if [[ -n "${has_db_host}" ]] && [[ -n "${has_db_port}" ]] && [[ -n "${has_db_name}" ]]; then
        print_status "ok" "Secret has required keys: DB_HOST, DB_PORT, DB_NAME"
        return 0
    else
        print_status "fail" "Secret is missing required keys"
        return 1
    fi
}

verify_secret_values() {
    log_info "Checking Secret values (decoded)..."

    local db_host=$(kubectl get secret ${SECRET} -n ${NAMESPACE} -o jsonpath='{.data.DB_HOST}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    local db_port=$(kubectl get secret ${SECRET} -n ${NAMESPACE} -o jsonpath='{.data.DB_PORT}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    local db_name=$(kubectl get secret ${SECRET} -n ${NAMESPACE} -o jsonpath='{.data.DB_NAME}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

    if [[ "${db_host}" == "postgres-svc" ]] && [[ "${db_port}" == "5432" ]] && [[ "${db_name}" == "taskmaster" ]]; then
        print_status "ok" "Secret values are correct (DB_HOST=postgres-svc, DB_PORT=5432, DB_NAME=taskmaster)"
        return 0
    else
        print_status "warn" "Secret values may be incorrect"
        log_info "  DB_HOST: ${db_host}"
        log_info "  DB_PORT: ${db_port}"
        log_info "  DB_NAME: ${db_name}"
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

verify_no_secret_errors() {
    log_info "Checking for secret-related errors..."

    local secret_errors=$(kubectl get events -n ${NAMESPACE} --field-selector involvedObject.kind=Pod 2>/dev/null | grep -i "CreateContainerConfigError\|secret.*not found" | wc -l)

    if [[ $secret_errors -eq 0 ]]; then
        print_status "ok" "No secret-related errors detected"
        return 0
    else
        print_status "warn" "Found ${secret_errors} secret error events (may be from before the fix)"
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

    log_section "Exercise 05: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    local all_passed=0

    log_step 1 "Verifying Secret Exists"
    if ! verify_secret_exists; then
        all_passed=1
    fi
    echo

    log_step 2 "Verifying Secret Data"
    if ! verify_secret_data; then
        all_passed=1
    fi
    echo

    log_step 3 "Verifying Secret Values"
    if ! verify_secret_values; then
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

    log_step 6 "Checking for Secret Errors"
    if ! verify_no_secret_errors; then
        all_passed=1
    fi
    echo

    log_section "Verification Summary"

    if [[ $all_passed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

${BOLD}Secret Status:${NC}
EOF
        kubectl get secret ${SECRET} -n ${NAMESPACE}
        echo
        kubectl describe secret ${SECRET} -n ${NAMESPACE}

        cat <<EOF

${BOLD}Backend Status:${NC}
EOF
        kubectl get pods -n ${NAMESPACE} -l app=backend

        cat <<EOF

${BOLD}Access the application:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}What you learned:${NC}
  ✓ How Secrets provide sensitive data to pods
  ✓ How to diagnose CreateContainerConfigError for Secrets
  ✓ How to recreate missing Secrets
  ✓ How to verify Secret data (base64 encoded)
  ✓ The difference between ConfigMaps and Secrets

${BOLD}Key Commands:${NC}
  • kubectl create secret generic - Create Secrets
  • kubectl get secrets - List Secrets
  • kubectl describe secret - View Secret metadata
  • kubectl delete secret - Delete Secrets (use with care!)
  • kubectl get secret -o yaml - View encoded values

${BOLD}Security Notes:${NC}
  • Secrets are base64 encoded, NOT encrypted!
  • Enable encryption at rest for production
  • Use RBAC to control Secret access
  • Never commit Secrets to git

${GREEN}${BOLD}Exercise 05 completed successfully!${NC}

${BOLD}Next steps:${NC}
  • Visit the dashboard and verify backend works
  • Try Exercise 06: ${CYAN}cd ../06-oom-killed${NC}
  • Reset to baseline: ${CYAN}./reset.sh${NC}

EOF
        log_success "Verification completed successfully!"
        return 0
    else
        cat <<EOF
${RED}${BOLD}✗ Some checks failed${NC}

${BOLD}Troubleshooting:${NC}
  1. Check Secret: ${CYAN}kubectl get secret ${SECRET} -n ${NAMESPACE}${NC}
  2. Check pod status: ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=backend${NC}
  3. Check events: ${CYAN}kubectl get events -n ${NAMESPACE} | grep backend${NC}
  4. Try fix again: ${CYAN}./fix.sh${NC}

EOF
        log_error "Verification failed. Please review the errors above."
        return 1
    fi
}

main "$@"