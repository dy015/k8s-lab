#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
DEPLOYMENT="backend"
BACKUP_FILE="/tmp/backend-resources-backup.yaml"

main() {
    init_log

    log_section "Exercise 06: Breaking with OOM Kill"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found. Deploy the baseline application first."
        exit 1
    fi

    log_warn "This will set very low memory limits causing OOM kills"
    echo
    if ! confirm "Continue with breaking the application?" "y"; then
        log_info "Operation cancelled"
        exit 0
    fi

    log_step 1 "Backing up current deployment"
    kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml > ${BACKUP_FILE}
    log_info "Backup saved to: ${BACKUP_FILE}"

    log_step 2 "Setting restrictive memory limits"

    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "add",
        "path": "/spec/template/spec/containers/0/resources",
        "value": {
          "limits": {
            "memory": "32Mi"
          },
          "requests": {
            "memory": "16Mi"
          }
        }
      }
    ]' 2>/dev/null || kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/resources",
        "value": {
          "limits": {
            "memory": "32Mi"
          },
          "requests": {
            "memory": "16Mi"
          }
        }
      }
    ]'

    log_success "Memory limits set to 32Mi (way too low!)"

    log_step 3 "Waiting for pods to restart and hit OOM..."
    log_info "This will take 30-60 seconds as pods get killed..."
    sleep 30

    log_info "Current pod status:"
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Issue Introduced!"

    cat <<EOF
${RED}${BOLD}Backend pods are being OOM killed!${NC}

${BOLD}Symptoms:${NC}
  • Pods showing OOMKilled status
  • High restart count
  • Pods cycling: Running → OOMKilled → CrashLoopBackOff
  • Exit code 137 (SIGKILL)
  • Dashboard shows backend flapping

${BOLD}Your Mission:${NC}
  1. Investigate why pods are being killed
  2. Check the current memory limits
  3. Monitor actual memory usage
  4. Fix the memory limits
  5. Verify pods stabilize

${BOLD}Troubleshooting Steps:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE} -w${NC}
  ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}
  ${CYAN}kubectl top pod -n ${NAMESPACE}${NC}
  ${CYAN}kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o yaml | grep -A 5 resources${NC}

${BOLD}Hints:${NC}
  • Look for "OOMKilled" status
  • Check the memory limits in pod description
  • Exit code 137 = 128 + 9 (SIGKILL)
  • Memory limit is currently only 32Mi
  • Backend needs at least 256Mi to run properly

${BOLD}What should the limits be:${NC}
  • requests.memory: 256Mi (minimum needed)
  • limits.memory: 512Mi (maximum allowed with buffer)

${BOLD}When you're ready:${NC}
  • Try to fix it manually: ${CYAN}kubectl patch deployment ...${NC}
  • Or run: ${CYAN}./fix.sh${NC} to see the solution
  • Verify: ${CYAN}./verify.sh${NC}
  • Reset: ${CYAN}./reset.sh${NC}

${BOLD}Dashboard:${NC} http://taskmaster.local (backend will be flapping)

${BOLD}Watch the OOM kills happen:${NC}
  ${CYAN}kubectl get pods -n ${NAMESPACE} -l app=backend -w${NC}

Good luck! 🔧

EOF

    log_success "Exercise setup complete. Start troubleshooting!"
}

main "$@"