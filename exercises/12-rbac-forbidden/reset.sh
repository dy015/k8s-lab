#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

main() {
    init_log
    kubectl delete serviceaccount test-sa -n taskmaster 2>/dev/null || true
    kubectl delete role pod-reader -n taskmaster 2>/dev/null || true
    kubectl delete rolebinding test-sa-binding -n taskmaster 2>/dev/null || true
    log_success "Reset completed!"
}

main "$@"
