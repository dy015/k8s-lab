#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

BACKUP_FILE="/tmp/ingress-backup.yaml"

main() {
    init_log
    if [[ -f "${BACKUP_FILE}" ]]; then
        kubectl apply -f "${BACKUP_FILE}"
        rm -f "${BACKUP_FILE}"
    fi
    log_success "Reset completed!"
}

main "$@"
