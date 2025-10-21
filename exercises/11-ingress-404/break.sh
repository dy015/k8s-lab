#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
BACKUP_FILE="/tmp/ingress-backup.yaml"

main() {
    init_log

    log_section "Exercise 11: Breaking Ingress"

    if ! check_kubectl; then
        exit 1
    fi

    kubectl get ingress taskmaster-ingress -n ${NAMESPACE} -o yaml > ${BACKUP_FILE}

    kubectl patch ingress taskmaster-ingress -n ${NAMESPACE} --type='json' -p='[
      {"op": "replace", "path": "/spec/rules/0/http/paths/0/path", "value": "/wrong-path"}
    ]'

    log_success "Ingress path changed to /wrong-path!"
}

main "$@"
