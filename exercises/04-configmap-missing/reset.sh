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
BACKUP_FILE="/tmp/backend-configmap-backup.yaml"

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
    log_step 1 "Restoring from baseline manifests"

    local manifest_file="${SCRIPT_DIR}/../../baseline-app/manifests/backend/01-configmap.yaml"

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

    log_section "Exercise 04: Reset to Baseline"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    log_warn "This will restore the backend ConfigMap to baseline configuration"
    echo

    if ! confirm "Continue with reset?" "y"; then
        log_info "Reset cancelled"
        exit 0
    fi

    if ! reset_from_backup; then
        reset_from_baseline
    fi

    log_step 2 "Waiting for pods to be ready..."

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
    kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE}
    echo
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Reset Complete!"

    cat <<EOF
${GREEN}${BOLD}Backend ConfigMap has been reset to baseline!${NC}

${BOLD}ConfigMap Status:${NC}
EOF
    kubectl describe configmap ${CONFIGMAP} -n ${NAMESPACE}

    cat <<EOF

${BOLD}Verify baseline:${NC}
  ${CYAN}../../baseline-app/verify-baseline.sh${NC}

${BOLD}Access dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Ready for next exercise:${NC}
  ${CYAN}cd ../05-secret-missing${NC}

EOF

    if [[ -f "${BACKUP_FILE}" ]]; then
        log_info "Cleaning up backup file: ${BACKUP_FILE}"
        rm -f "${BACKUP_FILE}"
    fi

    log_success "Reset completed successfully!"
}

main "$@"
