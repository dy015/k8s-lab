#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"
BACKUP_FILE="/tmp/backend-deployment-backup.yaml"

main() {
    init_log

    log_section "Exercise 01: Breaking the Backend (CrashLoopBackOff)"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found. Deploy the baseline application first."
        exit 1
    fi

    log_warn "This will introduce a CrashLoopBackOff error in the backend deployment"
    echo
    if ! confirm "Continue with breaking the application?" "y"; then
        log_info "Operation cancelled"
        exit 0
    fi

    log_step 1 "Backing up current deployment configuration"
    kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml > ${BACKUP_FILE}
    log_info "Backup saved to: ${BACKUP_FILE}"

    log_step 2 "Introducing the error: Typo in application filename"
    log_info "Changing command from 'app:app' to 'appp:app' (with typo)"

    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' \
      -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/command",
            "value": ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2",
                      "--timeout", "60", "--log-level", "info", "appp:app"]}]'

    log_success "Error introduced successfully!"

    log_step 3 "Waiting for pods to start crashing..."
    sleep 10

    log_info "Current pod status:"
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}The backend is now broken!${NC}

${BOLD}Symptoms:${NC}
  • Backend pods are in CrashLoopBackOff state
  • Dashboard shows RED status for backend
  • Tasks won't load
  • API returns errors

${BOLD}Your Mission:${NC}
  1. Investigate why the pods are crash looping
  2. Find the root cause
  3. Fix the issue
  4. Verify the fix worked

${BOLD}Troubleshooting Steps:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE}${NC}
  ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}
  ${CYAN}kubectl logs <pod-name> -n ${NAMESPACE}${NC}
  ${CYAN}kubectl logs <pod-name> -n ${NAMESPACE} --previous${NC}

${BOLD}Hints:${NC}
  • Look at the pod events
  • Check the container logs
  • Look for file-not-found errors
  • Check the deployment configuration

${BOLD}When you're ready:${NC}
  • Try to fix it manually
  • Or run: ${CYAN}./fix.sh${NC} to see the solution
  • Verify: ${CYAN}./verify.sh${NC}
  • Reset: ${CYAN}./reset.sh${NC}

${BOLD}Dashboard:${NC} http://taskmaster.local

Good luck! 🔧

EOF

    log_success "Exercise setup complete. Start troubleshooting!"
}

main "$@"
