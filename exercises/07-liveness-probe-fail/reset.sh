#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"
BACKUP_FILE="/tmp/backend-probe-backup.yaml"

reset_from_backup() {
    log_step 1 "Restoring from backup file"

    if [[ ! -f "${BACKUP_FILE}" ]]; then
        log_warn "Backup file not found: ${BACKUP_FILE}"
        log_info "Restoring using baseline configuration..."
        return 1
    fi

    kubectl apply -f "${BACKUP_FILE}"
    log_success "Restored from backup"
    return 0
}

reset_from_baseline() {
    log_step 1 "Restoring from baseline (removing liveness probe)"

    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "remove",
        "path": "/spec/template/spec/containers/0/livenessProbe"
      }
    ]' 2>/dev/null || log_info "Liveness probe already at baseline"

    log_success "Restored to baseline (no liveness probe)"
    return 0
}

main() {
    init_log

    log_section "Exercise 07: Reset to Baseline"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    log_warn "This will restore the backend deployment to baseline configuration"
    echo

    if ! confirm "Continue with reset?" "y"; then
        log_info "Reset cancelled"
        exit 0
    fi

    if ! reset_from_backup; then
        reset_from_baseline
    fi

    log_step 2 "Waiting for pods to be ready..."

    kubectl rollout restart deployment ${DEPLOYMENT} -n ${NAMESPACE}

    if wait_for_condition \
        "Backend pods to be ready" \
        "kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' | grep -q '2'" \
        120 5; then
        log_success "Backend pods are ready!"
    else
        log_warn "Pods may still be starting"
    fi

    log_step 3 "Verifying reset"
    echo
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Reset Complete!"

    cat <<EOF
${GREEN}${BOLD}Backend deployment has been reset to baseline!${NC}

${BOLD}Current Status:${NC}
EOF
    kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE}
    echo
    kubectl get pods -n ${NAMESPACE} -l app=backend

    cat <<EOF

${BOLD}Verify baseline:${NC}
  ${CYAN}../../baseline-app/verify-baseline.sh${NC}

${BOLD}Access dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Ready for next exercise:${NC}
  ${CYAN}cd ../08-readiness-probe-fail${NC}

EOF

    if [[ -f "${BACKUP_FILE}" ]]; then
        log_info "Cleaning up backup file: ${BACKUP_FILE}"
        rm -f "${BACKUP_FILE}"
    fi

    log_success "Reset completed successfully!"
}

main "$@"