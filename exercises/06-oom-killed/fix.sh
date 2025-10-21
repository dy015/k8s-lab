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

    log_section "Exercise 06: Fixing OOM Kill Issue"

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

The backend deployment has memory limits set way too low:

  Current limit:  ${RED}32Mi${NC}
  Actual usage:   ${YELLOW}~256Mi${NC}
  Result:         ${RED}OOMKilled${NC}

${BOLD}Why it failed:${NC}

1. Memory limit of 32Mi is insufficient for the backend application
2. When the container exceeds 32Mi, Kubernetes kills it immediately
3. Exit code 137 indicates SIGKILL (128 + 9)
4. Container restarts but gets killed again (CrashLoopBackOff)
5. Application is unstable and unavailable

${BOLD}The solution:${NC}

Set appropriate memory requests and limits:
  • Requests: 256Mi (guaranteed minimum)
  • Limits: 512Mi (maximum allowed with buffer)

${BOLD}Understanding OOM:${NC}
  • OOM = Out Of Memory
  • Memory is incompressible (unlike CPU)
  • Exceeding memory limit = immediate kill
  • No graceful shutdown possible

EOF

    if ! confirm "Apply the fix now?" "y"; then
        log_info "Fix cancelled"
        exit 0
    fi

    log_step 1 "Checking current memory limits"

    current_limit=$(kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "not set")
    log_info "Current memory limit: ${current_limit}"

    log_step 2 "Updating memory limits to appropriate values"

    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/resources",
        "value": {
          "limits": {
            "memory": "512Mi",
            "cpu": "500m"
          },
          "requests": {
            "memory": "256Mi",
            "cpu": "250m"
          }
        }
      }
    ]'

    log_success "Memory limits updated!"

    log_step 3 "New resource configuration"

    kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].resources}' | python3 -m json.tool 2>/dev/null || \
    kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].resources}'

    log_step 4 "Waiting for pods to stabilize..."

    log_info "Pods are being recreated with new limits..."
    sleep 10

    if wait_for_condition \
        "Backend pods to be ready without OOM kills" \
        "kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers | grep -v 'OOMKilled' | grep 'Running' | wc -l | grep -q '2'" \
        120 5; then
        log_success "Backend pods are now stable!"
    else
        log_warn "Pods may still be stabilizing. Check status with: kubectl get pods -n ${NAMESPACE}"
    fi

    log_step 5 "Current pod status"
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_step 6 "Checking resource usage"
    kubectl top pod -n ${NAMESPACE} -l app=backend 2>/dev/null || log_info "Metrics not available yet"

    log_section "Fix Complete!"

    cat <<EOF
${GREEN}${BOLD}Memory limits have been fixed!${NC}

${BOLD}What was done:${NC}
  ✓ Increased memory limit from 32Mi to 512Mi
  ✓ Set memory request to 256Mi
  ✓ Added CPU limits for completeness
  ✓ Pods restarted with new configuration
  ✓ No more OOM kills!

${BOLD}New Resource Configuration:${NC}
  requests:
    memory: 256Mi (guaranteed minimum)
    cpu: 250m
  limits:
    memory: 512Mi (maximum allowed)
    cpu: 500m

${BOLD}Verify the fix:${NC}
  ${CYAN}./verify.sh${NC}

${BOLD}Check the dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Monitor resources:${NC}
  ${CYAN}kubectl top pod -n ${NAMESPACE}${NC}

${BOLD}Key Takeaways:${NC}
  • Memory limits must be appropriate for workload
  • OOMKilled = immediate termination (exit code 137)
  • Memory is incompressible (unlike CPU)
  • Set requests for scheduling, limits for capping
  • Monitor actual usage to set proper limits

${BOLD}Best Practices:${NC}
  • Start with generous limits, then optimize
  • Set requests to typical usage
  • Set limits 1.5-2x requests for buffer
  • Use monitoring to understand actual needs
  • Different limits for dev/staging/production

${BOLD}QoS Classes:${NC}
  • Guaranteed: requests = limits
  • Burstable: requests < limits (our config)
  • BestEffort: no requests/limits

EOF

    log_success "Exercise 06 fix completed!"
}

main "$@"