#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

main() {
    init_log

    log_section "Exercise 10: Verification"

    log_step 1 "Checking CoreDNS pods"
    kubectl get pods -n kube-system -l k8s-app=kube-dns

    log_success "Verification completed!"
}

main "$@"
