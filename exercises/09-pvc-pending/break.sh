#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
STORAGECLASS="standard"
BACKUP_FILE="/tmp/storageclass-backup.yaml"

main() {
    init_log

    log_section "Exercise 09: Breaking PVC Provisioning"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    log_warn "This will delete the StorageClass causing PVC issues"
    echo
    if ! confirm "Continue?" "y"; then
        exit 0
    fi

    log_step 1 "Backing up StorageClass"
    kubectl get storageclass ${STORAGECLASS} -o yaml > ${BACKUP_FILE} 2>/dev/null || true

    log_step 2 "Deleting StorageClass"
    kubectl delete storageclass ${STORAGECLASS} 2>/dev/null || log_warn "StorageClass may not exist"

    log_step 3 "Triggering postgres pod restart"
    kubectl delete pod -n ${NAMESPACE} -l app=postgres --force --grace-period=0

    sleep 10
    kubectl get pods -n ${NAMESPACE}
    kubectl get pvc -n ${NAMESPACE}

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}PVC stuck in Pending state!${NC}

Troubleshoot with:
  ${CYAN}kubectl get pvc -n ${NAMESPACE}${NC}
  ${CYAN}kubectl describe pvc <pvc-name> -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get storageclass${NC}

Fix: ${CYAN}./fix.sh${NC}

EOF

    log_success "Exercise setup complete!"
}

main "$@"
