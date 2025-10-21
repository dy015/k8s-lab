#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
SERVICE="backend-svc"
BACKUP_FILE="/tmp/backend-service-backup.yaml"

reset_from_backup() {
    log_step 1 "Restoring from backup file"

    if [[ ! -f "${BACKUP_FILE}" ]]; then
        log_warn "Backup file not found: ${BACKUP_FILE}"
        log_info "Restoring using known good configuration..."
        return 1
    fi

    kubectl apply -f "${BACKUP_FILE}"
    log_success "Restored from backup"
    return 0
}

reset_from_baseline() {
    log_step 1 "Restoring from baseline manifests"

    local manifest_file="${SCRIPT_DIR}/../../baseline-app/manifests/backend/04-service.yaml"

    if [[ ! -f "${manifest_file}" ]]; then
        log_error "Baseline manifest not found: ${manifest_file}"
        return 1
    fi

    kubectl apply -f "${manifest_file}"
    log_success "Restored from baseline manifest"
    return 0
}

main() {
    init_log

    log_section "Exercise 03: Reset to Baseline"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    log_warn "This will restore the backend service to baseline configuration"
    echo

    if ! confirm "Continue with reset?" "y"; then
        log_info "Reset cancelled"
        exit 0
    fi

    if ! reset_from_backup; then
        reset_from_baseline
    fi

    log_step 2 "Verifying service endpoints..."
    sleep 3

    local endpoints=$(kubectl get endpoints ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")

    if [[ -n "${endpoints}" ]]; then
        log_success "Service has endpoints: ${endpoints}"
    else
        log_warn "Endpoints not yet available. Give it a few seconds..."
    fi

    log_step 3 "Verifying reset"
    echo
    kubectl get svc ${SERVICE} -n ${NAMESPACE}
    echo
    kubectl get endpoints ${SERVICE} -n ${NAMESPACE}

    log_section "Reset Complete!"

    cat <<EOF
${GREEN}${BOLD}Backend service has been reset to baseline configuration!${NC}

${BOLD}Current status:${NC}
  Service Selector: $(kubectl get svc ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.spec.selector.app}')
  Endpoints: $(kubectl get endpoints ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' || echo "none")

${BOLD}Verify baseline:${NC}
  ${CYAN}../../baseline-app/verify-baseline.sh${NC}

${BOLD}Access dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Ready for next exercise:${NC}
  ${CYAN}cd ../04-configmap-missing${NC}

EOF

    if [[ -f "${BACKUP_FILE}" ]]; then
        log_info "Cleaning up backup file: ${BACKUP_FILE}"
        rm -f "${BACKUP_FILE}"
    fi

    log_success "Reset completed successfully!"
}

main "$@"
