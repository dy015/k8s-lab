#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"
BACKUP_FILE="/tmp/backend-readiness-backup.yaml"

main() {
    init_log

    log_section "Exercise 08: Breaking Readiness Probe"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found. Deploy the baseline application first."
        exit 1
    fi

    log_warn "This will set aggressive readiness probe timing"
    echo
    if ! confirm "Continue with breaking the application?" "y"; then
        log_info "Operation cancelled"
        exit 0
    fi

    log_step 1 "Backing up current deployment"
    kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml > ${BACKUP_FILE}
    log_info "Backup saved to: ${BACKUP_FILE}"

    log_step 2 "Setting aggressive readiness probe timing"

    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/containers/0/readinessProbe",
        "value": {
          "httpGet": {
            "path": "/api/health",
            "port": 8080
          },
          "initialDelaySeconds": 1,
          "periodSeconds": 1,
          "timeoutSeconds": 1,
          "failureThreshold": 1
        }
      }
    ]' 2>/dev/null || kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/readinessProbe",
        "value": {
          "httpGet": {
            "path": "/api/health",
            "port": 8080
          },
          "initialDelaySeconds": 1,
          "periodSeconds": 1,
          "timeoutSeconds": 1,
          "failureThreshold": 1
        }
      }
    ]'

    log_success "Readiness probe timing set too aggressive!"

    log_step 3 "Waiting for pods to show not ready..."
    sleep 20

    log_info "Current pod status:"
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}Backend pods not becoming ready!${NC}

${BOLD}Symptoms:${NC}
  • Pods show 0/1 Ready
  • STATUS is Running but not Ready
  • Service has no endpoints
  • No traffic routed to backend
  • Dashboard shows backend unavailable

${BOLD}Your Mission:${NC}
  1. Investigate why pods aren't ready
  2. Check readiness probe timing
  3. Fix the probe configuration
  4. Verify pods become ready

${BOLD}Troubleshooting Steps:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE}${NC}
  ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get endpoints backend-svc -n ${NAMESPACE}${NC}

${BOLD}When you're ready:${NC}
  • Try to fix it manually: ${CYAN}kubectl patch deployment ...${NC}
  • Or run: ${CYAN}./fix.sh${NC} to see the solution
  • Verify: ${CYAN}./verify.sh${NC}
  • Reset: ${CYAN}./reset.sh${NC}

Good luck! 🔧

EOF

    log_success "Exercise setup complete. Start troubleshooting!"
}

main "$@"