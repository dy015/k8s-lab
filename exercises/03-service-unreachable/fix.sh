#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
SERVICE="backend-svc"

main() {
    init_log

    log_section "Exercise 03: Fixing Service Connectivity"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    log_section "Problem Analysis"

    cat <<EOF
${BOLD}What went wrong:${NC}

The backend service selector was changed to look for pods with the wrong label:

  Service Selector: ${RED}app=backend-api${NC}
  Pod Labels:       ${GREEN}app=backend${NC}

${BOLD}Why it failed:${NC}

1. Services use label selectors to find pods
2. Only pods with matching labels become service endpoints
3. The selector 'app=backend-api' matches NO pods
4. Without endpoints, the service can't route traffic
5. Frontend requests to backend-svc fail

${BOLD}Current state:${NC}
EOF

    echo -n "  Service selector: "
    kubectl get svc ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.spec.selector.app}'
    echo

    echo -n "  Service endpoints: "
    kubectl get endpoints ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' || echo "(none)"
    echo
    echo

    cat <<EOF
${BOLD}The solution:${NC}

Change the service selector back to 'app=backend' to match the pod labels.

EOF

    if ! confirm "Apply the fix now?" "y"; then
        log_info "Fix cancelled"
        exit 0
    fi

    log_step 1 "Applying the fix: Correcting service selector"

    kubectl patch service ${SERVICE} -n ${NAMESPACE} --type='json' \
      -p='[{"op": "replace", "path": "/spec/selector/app", "value": "backend"}]'

    log_success "Fix applied!"

    log_step 2 "Verifying endpoints are created..."
    sleep 3

    local endpoints=$(kubectl get endpoints ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")

    if [[ -n "${endpoints}" ]]; then
        log_success "Service now has endpoints: ${endpoints}"
    else
        log_warn "Endpoints not yet available. Give it a few seconds..."
    fi

    log_step 3 "Current status"
    echo
    log_info "Service details:"
    kubectl describe svc ${SERVICE} -n ${NAMESPACE} | grep -A 5 "Selector:"
    echo
    log_info "Endpoints:"
    kubectl get endpoints ${SERVICE} -n ${NAMESPACE}

    log_section "Fix Complete!"

    cat <<EOF
${GREEN}${BOLD}Backend service connectivity is restored!${NC}

${BOLD}What was done:${NC}
  ✓ Changed service selector from 'app=backend-api' to 'app=backend'
  ✓ Selector now matches pod labels
  ✓ Kubernetes automatically created endpoints
  ✓ Service can now route traffic to backend pods

${BOLD}Verify the fix:${NC}
  ${CYAN}./verify.sh${NC}

${BOLD}Check the dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Test connectivity:${NC}
  ${CYAN}kubectl run test --image=busybox --rm -it -n taskmaster -- wget -qO- http://backend-svc:5000/api/health${NC}

${BOLD}Key Takeaways:${NC}
  • Services use label selectors to find pods
  • Selectors must exactly match pod labels
  • No matching labels = no endpoints
  • Check endpoints when services don't work
  • Even if pods are Running, service might not work

${BOLD}Useful commands used:${NC}
  • kubectl get endpoints - See service endpoints
  • kubectl describe svc - View selector configuration
  • kubectl get pods --show-labels - See pod labels
  • kubectl patch - Modify resource configuration

EOF

    log_success "Exercise 03 fix completed!"
}

main "$@"
