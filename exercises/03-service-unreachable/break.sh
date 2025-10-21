#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
SERVICE="backend-svc"
BACKUP_FILE="/tmp/backend-service-backup.yaml"

main() {
    init_log

    log_section "Exercise 03: Breaking Service Connectivity"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found. Deploy the baseline application first."
        exit 1
    fi

    log_warn "This will break backend service connectivity by changing the selector"
    echo
    if ! confirm "Continue with breaking the application?" "y"; then
        log_info "Operation cancelled"
        exit 0
    fi

    log_step 1 "Backing up current service configuration"
    kubectl get service ${SERVICE} -n ${NAMESPACE} -o yaml > ${BACKUP_FILE}
    log_info "Backup saved to: ${BACKUP_FILE}"

    log_step 2 "Introducing the error: Changing service selector"
    log_info "Changing selector from 'app=backend' to 'app=backend-api' (wrong label)"

    kubectl patch service ${SERVICE} -n ${NAMESPACE} --type='json' \
      -p='[{"op": "replace", "path": "/spec/selector/app", "value": "backend-api"}]'

    log_success "Error introduced successfully!"

    log_step 3 "Verifying the issue..."
    sleep 5

    log_info "Service endpoints (should be empty now):"
    kubectl get endpoints ${SERVICE} -n ${NAMESPACE}

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}Backend service is now broken!${NC}

${BOLD}Symptoms:${NC}
  • Backend pods are Running (confusing!)
  • Backend service has NO endpoints
  • Frontend can't connect to backend
  • Dashboard shows RED for backend
  • Tasks won't load

${BOLD}Your Mission:${NC}
  1. Figure out why the service can't connect to pods
  2. Understand the relationship between services and pods
  3. Find the mismatch
  4. Fix the connectivity

${BOLD}Troubleshooting Steps:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get svc -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get endpoints -n ${NAMESPACE}${NC}
  ${CYAN}kubectl describe svc ${SERVICE} -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE} --show-labels${NC}

${BOLD}Hints:${NC}
  • All pods are running - so it's not a pod problem
  • Check if the service has any endpoints
  • Compare service selector with pod labels
  • Look for label mismatches
  • Services use selectors to find pods

${BOLD}Key Commands:${NC}
  ${CYAN}kubectl get endpoints ${SERVICE} -n ${NAMESPACE}${NC}
  ${CYAN}kubectl describe svc ${SERVICE} -n ${NAMESPACE} | grep Selector${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=backend --show-labels${NC}

${BOLD}When you're ready:${NC}
  • Try to fix it manually
  • Or run: ${CYAN}./fix.sh${NC} to see the solution
  • Verify: ${CYAN}./verify.sh${NC}
  • Reset: ${CYAN}./reset.sh${NC}

${BOLD}Dashboard:${NC} http://taskmaster.local (backend will be unreachable)

Good luck! 🔧

EOF

    log_success "Exercise setup complete. Start troubleshooting!"
}

main "$@"
