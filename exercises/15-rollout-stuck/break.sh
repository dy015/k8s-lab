#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
BACKUP_FILE="/tmp/backend-rollout-backup.yaml"

main() {
    init_log

    log_section "Exercise 15: Breaking Rollout"

    kubectl get deployment backend -n ${NAMESPACE} -o yaml > ${BACKUP_FILE}

    kubectl set image deployment/backend -n ${NAMESPACE} backend=backend:invalid-tag
    kubectl patch deployment backend -n ${NAMESPACE} -p '{"spec":{"strategy":{"rollingUpdate":{"maxUnavailable":0}}}}'

    log_success "Rollout stuck with invalid image!"
}

main "$@"
