#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
SECRET="backend-secret"
DEPLOYMENT="backend"
BACKUP_FILE="/tmp/backend-secret-backup.yaml"

main() {
    init_log

    log_section "Exercise 05: Breaking Secret Dependency"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found. Deploy the baseline application first."
        exit 1
    fi

    log_warn "This will delete the backend Secret and trigger pod restart"
    echo
    if ! confirm "Continue with breaking the application?" "y"; then
        log_info "Operation cancelled"
        exit 0
    fi

    log_step 1 "Backing up Secret"
    kubectl get secret ${SECRET} -n ${NAMESPACE} -o yaml > ${BACKUP_FILE} 2>/dev/null || true
    if [[ -f "${BACKUP_FILE}" ]]; then
        log_info "Backup saved to: ${BACKUP_FILE}"
    else
        log_warn "Secret may not exist yet"
    fi

    log_step 2 "Deleting backend Secret"
    kubectl delete secret ${SECRET} -n ${NAMESPACE} 2>/dev/null || log_warn "Secret may not exist"

    log_success "Secret deleted!"

    log_step 3 "Triggering pod restart to show the issue"
    log_info "Scaling deployment down and up..."
    kubectl scale deployment ${DEPLOYMENT} -n ${NAMESPACE} --replicas=0
    sleep 3
    kubectl scale deployment ${DEPLOYMENT} -n ${NAMESPACE} --replicas=2

    log_info "Waiting for pods to attempt creation..."
    sleep 10

    log_info "Current pod status:"
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}Backend Secret is missing!${NC}

${BOLD}Symptoms:${NC}
  • Backend pods stuck in CreateContainerConfigError
  • Secret backend-secret not found
  • New pods can't be created with database credentials
  • Dashboard shows backend as unavailable
  • Cannot scale or update deployment

${BOLD}Your Mission:${NC}
  1. Investigate why pods won't start
  2. Find what Secret is missing
  3. Understand what credentials the Secret should contain
  4. Recreate the Secret with proper database configuration
  5. Verify pods start successfully

${BOLD}Troubleshooting Steps:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE}${NC}
  ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get secrets -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml | grep -A 5 secretRef${NC}

${BOLD}Hints:${NC}
  • Check pod events for error messages
  • Look for "secret not found" errors
  • Check deployment to see what Secret it expects
  • Secrets store sensitive configuration like passwords
  • You'll need to recreate it with database connection info

${BOLD}What should be in the Secret:${NC}
  • DB_HOST=postgres-svc
  • DB_PORT=5432
  • DB_NAME=taskmaster

${BOLD}When you're ready:${NC}
  • Try to fix it manually: ${CYAN}kubectl create secret generic ...${NC}
  • Or run: ${CYAN}./fix.sh${NC} to see the solution
  • Verify: ${CYAN}./verify.sh${NC}
  • Reset: ${CYAN}./reset.sh${NC}

${BOLD}Dashboard:${NC} http://taskmaster.local (backend will be unavailable)

Good luck! 🔧

EOF

    log_success "Exercise setup complete. Start troubleshooting!"
}

main "$@"