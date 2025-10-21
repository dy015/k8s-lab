#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"
BACKUP_FILE="/tmp/backend-readiness-backup.yaml"

main() {
    init_log

    log_section "Exercise 08: Reset to Baseline"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    log_warn "This will restore the backend deployment to baseline"
    echo

    if ! confirm "Continue with reset?" "y"; then
        log_info "Reset cancelled"
        exit 0
    fi

    if [[ -f "${BACKUP_FILE}" ]]; then
        kubectl apply -f "${BACKUP_FILE}"
        log_success "Restored from backup"
    else
        kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
          {
            "op": "remove",
            "path": "/spec/template/spec/containers/0/readinessProbe"
          }
        ]' 2>/dev/null || log_info "Readiness probe already at baseline"
        log_success "Restored to baseline"
    fi

    kubectl rollout restart deployment ${DEPLOYMENT} -n ${NAMESPACE}

    log_step 2 "Waiting for pods to be ready..."
    sleep 15

    kubectl get pods -n ${NAMESPACE} -l app=backend

    if [[ -f "${BACKUP_FILE}" ]]; then
        rm -f "${BACKUP_FILE}"
    fi

    log_success "Reset completed successfully!"
}

main "$@"
