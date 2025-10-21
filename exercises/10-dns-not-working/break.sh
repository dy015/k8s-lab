#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

main() {
    init_log

    log_section "Exercise 10: Breaking DNS"

    if ! check_kubectl; then
        exit 1
    fi

    log_warn "This will scale down CoreDNS causing DNS failures"
    echo
    if ! confirm "Continue?" "y"; then
        exit 0
    fi

    log_step 1 "Scaling down CoreDNS"
    kubectl scale deployment coredns -n kube-system --replicas=0

    sleep 10

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}DNS resolution is broken!${NC}

Test with:
  ${CYAN}kubectl exec <pod> -n taskmaster -- nslookup kubernetes.default${NC}

Fix: ${CYAN}./fix.sh${NC}
EOF

    log_success "Exercise setup complete!"
}

main "$@"
