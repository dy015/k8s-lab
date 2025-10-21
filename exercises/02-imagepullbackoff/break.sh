#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="frontend"
BACKUP_FILE="/tmp/frontend-deployment-backup.yaml"

main() {
    init_log

    log_section "Exercise 02: Breaking the Frontend (ImagePullBackOff)"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found. Deploy the baseline application first."
        exit 1
    fi

    log_warn "This will introduce an ImagePullBackOff error in the frontend deployment"
    echo
    if ! confirm "Continue with breaking the application?" "y"; then
        log_info "Operation cancelled"
        exit 0
    fi

    log_step 1 "Backing up current deployment configuration"
    kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml > ${BACKUP_FILE}
    log_info "Backup saved to: ${BACKUP_FILE}"

    log_step 2 "Introducing the error: Changing image to non-existent tag"
    log_info "Changing image tag from '1.0' to '2.0' (which doesn't exist)"

    kubectl set image deployment/${DEPLOYMENT} \
        ${DEPLOYMENT}=docker.io/reddydodda/taskmaster-frontend:2.0 \
        -n ${NAMESPACE}

    log_success "Error introduced successfully!"

    log_step 3 "Waiting for Kubernetes to attempt image pull..."
    sleep 15

    log_info "Current pod status:"
    kubectl get pods -n ${NAMESPACE} -l app=frontend

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}The frontend is now broken!${NC}

${BOLD}Symptoms:${NC}
  • Frontend pods are in ImagePullBackOff state
  • Dashboard won't load (http://taskmaster.local)
  • Frontend pods show 0/1 ready
  • Image pull is failing

${BOLD}Your Mission:${NC}
  1. Investigate why the image can't be pulled
  2. Find what's wrong with the image configuration
  3. Fix the issue
  4. Verify the frontend loads again

${BOLD}Troubleshooting Steps:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE}${NC}
  ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml | grep image${NC}
  ${CYAN}kubectl get events -n ${NAMESPACE} | grep -i pull${NC}

${BOLD}Hints:${NC}
  • Look at the pod events for image pull errors
  • Check what image tag is being used
  • Verify the image tag exists in Docker Hub
  • Compare with working backend image configuration

${BOLD}Check Image:${NC}
  ${CYAN}kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}'${NC}

${BOLD}When you're ready:${NC}
  • Try to fix it manually
  • Or run: ${CYAN}./fix.sh${NC} to see the solution
  • Verify: ${CYAN}./verify.sh${NC}
  • Reset: ${CYAN}./reset.sh${NC}

${BOLD}Dashboard:${NC} http://taskmaster.local (will be unavailable until fixed)

Good luck! 🔧

EOF

    log_success "Exercise setup complete. Start troubleshooting!"
}

main "$@"
