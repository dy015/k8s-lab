#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"
BACKUP_FILE="/tmp/backend-deployment-backup.yaml"

main() {
    init_log

    log_section "Exercise 01: Reset to Baseline"

    if ! check_kubectl; then
        exit 1
    fi

    log_info "This will restore the backend deployment to its original state"
    echo

    if ! confirm "Continue with reset?" "y"; then
        log_info "Reset cancelled"
        exit 0
    fi

    log_step 1 "Restoring original deployment configuration"

    if [[ -f "${BACKUP_FILE}" ]]; then
        log_info "Restoring from backup: ${BACKUP_FILE}"
        kubectl delete deployment ${DEPLOYMENT} -n ${NAMESPACE} --ignore-not-found=true
        kubectl apply -f ${BACKUP_FILE}
        log_success "Deployment restored from backup"
    else
        log_warn "Backup file not found, applying fix instead"
        kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' \
          -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/command",
                "value": ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2",
                          "--timeout", "60", "--log-level", "info", "app:app"]}]'
        log_success "Deployment configuration corrected"
    fi

    log_step 2 "Waiting for pods to be ready"

    log_info "Waiting for rollout to complete..."
    if wait_for_condition \
        "Backend pods to be ready" \
        "kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' | grep -q '2'" \
        120 10; then
        log_success "Backend pods are ready"
    else
        log_warn "Pods may not be fully ready yet"
    fi

    log_step 3 "Verifying baseline is restored"

    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Reset Complete!"

    cat <<EOF
${GREEN}${BOLD}✓ Baseline has been restored!${NC}

${BOLD}Current Status:${NC}
$(kubectl get pods -n ${NAMESPACE} -l app=backend)

${BOLD}Verify restoration:${NC}
  ${CYAN}./verify.sh${NC}

${BOLD}Dashboard:${NC}
  http://taskmaster.local
  Backend should be ${GREEN}green${NC}

${BOLD}Ready for next exercise?${NC}
  ${CYAN}cd ../02-imagepullbackoff${NC}

EOF

    log_success "Exercise reset completed!"
}

main "$@"
