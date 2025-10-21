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

    log_section "Exercise 01: Fix - CrashLoopBackOff"

    if ! check_kubectl; then
        exit 1
    fi

    log_section "The Problem"

    cat <<EOF
${BOLD}Root Cause Analysis:${NC}

The backend deployment has a typo in the gunicorn command:

${RED}Broken:${NC}  command: [..., "appp:app"]
                                    ^^^^
                                    TYPO!

${GREEN}Correct:${NC} command: [..., "app:app"]

${BOLD}Why this causes CrashLoopBackOff:${NC}
  1. Gunicorn tries to load module "appp"
  2. File "appp.py" doesn't exist (should be "app.py")
  3. Gunicorn exits with error code 2
  4. Kubernetes sees the container crashed
  5. Kubernetes tries to restart it
  6. Same error happens again
  7. Kubernetes backs off between restarts
  8. Result: CrashLoopBackOff state

EOF

    if ! confirm "Apply the fix now?" "y"; then
        log_info "Fix cancelled"
        exit 0
    fi

    log_section "Applying the Fix"

    log_step 1 "Correcting the command in deployment"

    log_info "Patching deployment to fix the typo..."
    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' \
      -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/command",
            "value": ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2",
                      "--timeout", "60", "--log-level", "info", "app:app"]}]'

    log_success "Deployment patched successfully"

    log_step 2 "Waiting for pods to restart"

    log_info "Watching pod status..."
    echo
    kubectl get pods -n ${NAMESPACE} -l app=backend

    echo
    log_info "Waiting for new pods to be ready..."
    if wait_for_condition \
        "Backend pods to be ready" \
        "kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' | grep -q '2'" \
        120 10; then
        log_success "Backend pods are now running!"
    else
        log_warn "Pods may not be fully ready yet. Check status manually."
    fi

    echo
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Fix Applied Successfully!"

    cat <<EOF
${GREEN}${BOLD}✓ The issue has been fixed!${NC}

${BOLD}What we did:${NC}
  1. Identified the typo in the deployment command
  2. Patched the deployment with the correct command
  3. Kubernetes automatically rolled out new pods
  4. New pods started successfully

${BOLD}Verify the fix:${NC}
  ${CYAN}./verify.sh${NC}

${BOLD}Check the dashboard:${NC}
  http://taskmaster.local
  Backend should now show ${GREEN}green status${NC}

${BOLD}Key Commands Used:${NC}
  ${CYAN}kubectl patch deployment${NC}  - Modify deployment configuration
  ${CYAN}kubectl get pods -w${NC}        - Watch pods status change
  ${CYAN}kubectl logs${NC}               - View application logs

${BOLD}Learning Points:${NC}
  • Always check pod events when debugging
  • Container logs show the actual error
  • Deployment changes trigger automatic rollout
  • Kubernetes maintains desired state

EOF

    log_success "Exercise 01 completed!"
}

main "$@"
