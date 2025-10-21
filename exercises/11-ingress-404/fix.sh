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

    kubectl patch ingress taskmaster-ingress -n ${NAMESPACE} --type='json' -p='[
      {"op": "replace", "path": "/spec/rules/0/http/paths/0/path", "value": "/"}
    ]'

    log_success "Ingress path fixed!"
}

main "$@"
