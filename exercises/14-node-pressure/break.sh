#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

main() {
    init_log

    log_section "Exercise 14: Creating Node Pressure"

    log_warn "Creating large file to simulate disk pressure"
    dd if=/dev/zero of=/tmp/largefile bs=1M count=5000 2>/dev/null || true

    log_success "Disk pressure simulated!"
}

main "$@"
