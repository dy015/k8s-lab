#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"
BACKUP_FILE="/tmp/backend-probe-backup.yaml"

main() {
    init_log

    log_section "Exercise 07: Breaking Liveness Probe"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found. Deploy the baseline application first."
        exit 1
    fi

    log_warn "This will misconfigure the liveness probe causing restarts"
    echo
    if ! confirm "Continue with breaking the application?" "y"; then
        log_info "Operation cancelled"
        exit 0
    fi

    log_step 1 "Backing up current deployment"
    kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml > ${BACKUP_FILE}
    log_info "Backup saved to: ${BACKUP_FILE}"

    log_step 2 "Setting incorrect liveness probe endpoint"

    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/containers/0/livenessProbe",
        "value": {
          "httpGet": {
            "path": "/wrong-health",
            "port": 8080
          },
          "initialDelaySeconds": 30,
          "periodSeconds": 10,
          "timeoutSeconds": 5,
          "failureThreshold": 3
        }
      }
    ]' 2>/dev/null || kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/livenessProbe",
        "value": {
          "httpGet": {
            "path": "/wrong-health",
            "port": 8080
          },
          "initialDelaySeconds": 30,
          "periodSeconds": 10,
          "timeoutSeconds": 5,
          "failureThreshold": 3
        }
      }
    ]'

    log_success "Liveness probe set to wrong endpoint!"

    log_step 3 "Waiting for probe failures to start..."
    log_info "Pods will start restarting in ~30 seconds..."
    sleep 40

    log_info "Current pod status:"
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}Backend liveness probe is failing!${NC}

${BOLD}Symptoms:${NC}
  • Pods constantly restarting
  • High restart count increasing
  • Liveness probe failed: 404
  • Container killed despite being healthy
  • Dashboard shows backend flapping

${BOLD}Your Mission:${NC}
  1. Investigate why pods keep restarting
  2. Check the liveness probe configuration
  3. Verify the correct health endpoint
  4. Fix the probe configuration
  5. Verify pods stabilize

${BOLD}Troubleshooting Steps:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE} -w${NC}
  ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp'${NC}
  ${CYAN}kubectl exec <pod-name> -n ${NAMESPACE} -- curl http://localhost:8080/api/health${NC}

${BOLD}Hints:${NC}
  • Check the Events section in pod description
  • Look for "Liveness probe failed" messages
  • Current probe endpoint: /wrong-health
  • Correct endpoint: /api/health
  • Probe fails after 3 consecutive failures

${BOLD}When you're ready:${NC}
  • Try to fix it manually: ${CYAN}kubectl patch deployment ...${NC}
  • Or run: ${CYAN}./fix.sh${NC} to see the solution
  • Verify: ${CYAN}./verify.sh${NC}
  • Reset: ${CYAN}./reset.sh${NC}

${BOLD}Dashboard:${NC} http://taskmaster.local (backend will be unstable)

${BOLD}Watch the restarts happen:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=backend -w${NC}

Good luck! 🔧

EOF

    log_success "Exercise setup complete. Start troubleshooting!"
}

main "$@"