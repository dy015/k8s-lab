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

    log_section "Exercise 15: Fixing Rollout"

    kubectl rollout undo deployment backend -n ${NAMESPACE}

    log_success "Rollout rolled back!"
}

main "$@"
