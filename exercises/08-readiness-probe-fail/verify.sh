#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"

main() {
    init_log

    log_section "Exercise 08: Verification"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    log_step 1 "Checking pod readiness"

    local ready_count=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers | grep "1/1" | wc -l)
    local total_count=$(kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers | wc -l)

    if [[ ${ready_count} -eq ${total_count} ]] && [[ ${ready_count} -gt 0 ]]; then
        print_status "ok" "All ${ready_count} backend pod(s) are ready"
    else
        print_status "fail" "Only ${ready_count}/${total_count} backend pod(s) are ready"
    fi

    log_step 2 "Checking service endpoints"

    local endpoints=$(kubectl get endpoints backend-svc -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
    
    if [[ ${endpoints} -gt 0 ]]; then
        print_status "ok" "Service has ${endpoints} endpoint(s)"
    else
        print_status "fail" "Service has no endpoints"
    fi

    echo
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_success "Verification completed!"
}

main "$@"
