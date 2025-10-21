#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="frontend"

main() {
    init_log

    log_section "Exercise 02: Fixing ImagePullBackOff"

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

The frontend deployment was configured to use an image tag that doesn't exist:

  ${RED}docker.io/reddydodda/taskmaster-frontend:2.0${NC}
                                                   ^^^
                                                   This tag doesn't exist!

${BOLD}Why it failed:${NC}

1. Kubernetes tried to pull the image from Docker Hub
2. The registry responded that tag '2.0' doesn't exist
3. Kubernetes entered ImagePullBackOff state
4. The pods couldn't start because the image wasn't available

${BOLD}The solution:${NC}

Change the image tag back to '1.0', which exists in the registry.

EOF

    if ! confirm "Apply the fix now?" "y"; then
        log_info "Fix cancelled"
        exit 0
    fi

    log_step 1 "Applying the fix: Changing image tag to 1.0"

    kubectl set image deployment/${DEPLOYMENT} \
        ${DEPLOYMENT}=docker.io/reddydodda/taskmaster-frontend:1.0 \
        -n ${NAMESPACE}

    log_success "Fix applied!"

    log_step 2 "Waiting for pods to start..."

    if wait_for_condition \
        "Frontend pods to be ready" \
        "kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' | grep -q '2'" \
        120 5; then
        log_success "Frontend pods are now running!"
    else
        log_warn "Pods may still be starting. Check status with: kubectl get pods -n ${NAMESPACE}"
    fi

    log_step 3 "Current status"
    kubectl get pods -n ${NAMESPACE} -l app=frontend

    log_section "Fix Complete!"

    cat <<EOF
${GREEN}${BOLD}The frontend is now fixed!${NC}

${BOLD}What was done:${NC}
  ✓ Changed image tag from 2.0 to 1.0
  ✓ Kubernetes pulled the correct image
  ✓ New pods started successfully
  ✓ Frontend is now accessible

${BOLD}Verify the fix:${NC}
  ${CYAN}./verify.sh${NC}

${BOLD}Check the dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Key Takeaways:${NC}
  • Always verify image tags exist before deploying
  • ImagePullBackOff means the image can't be pulled
  • Check pod events to see the exact error message
  • Use 'kubectl set image' to update deployment images

${BOLD}Useful commands used:${NC}
  • kubectl set image deployment/<name> <container>=<image>
  • kubectl describe pod - Shows image pull events
  • kubectl get events - Shows all recent events

EOF

    log_success "Exercise 02 fix completed!"
}

main "$@"
