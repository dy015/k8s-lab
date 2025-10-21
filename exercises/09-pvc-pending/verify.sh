#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"

main() {
    init_log

    log_section "Exercise 09: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    log_step 1 "Checking StorageClass"
    kubectl get storageclass

    log_step 2 "Checking PVC status"
    kubectl get pvc -n ${NAMESPACE}

    log_step 3 "Checking postgres pod"
    kubectl get pods -n ${NAMESPACE} -l app=postgres

    log_success "Verification completed!"
}

main "$@"
