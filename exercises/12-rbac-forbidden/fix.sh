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

    kubectl create role pod-reader -n ${NAMESPACE} --verb=get,list,watch --resource=pods
    kubectl create rolebinding test-sa-binding -n ${NAMESPACE} --role=pod-reader --serviceaccount=${NAMESPACE}:test-sa

    log_success "RBAC permissions granted!"
}

main "$@"
