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

    log_section "Exercise 07: Fixing Liveness Probe"

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

The liveness probe is checking the wrong endpoint:

  Configured endpoint: ${RED}/wrong-health${NC} (returns 404)
  Correct endpoint:    ${GREEN}/api/health${NC}

${BOLD}Why it failed:${NC}

1. Liveness probe checks /wrong-health every 10 seconds
2. Endpoint doesn't exist, returns 404
3. After 3 consecutive failures, Kubernetes kills the container
4. Container restarts but probe still wrong
5. Cycle repeats indefinitely

${BOLD}The solution:${NC}

Update the liveness probe to use the correct health endpoint.

EOF

    if ! confirm "Apply the fix now?" "y"; then
        log_info "Fix cancelled"
        exit 0
    fi

    log_step 1 "Fixing liveness probe endpoint"

    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/path",
        "value": "/api/health"
      }
    ]'

    log_success "Liveness probe updated to correct endpoint!"

    log_step 2 "Waiting for pods to stabilize..."

    log_info "Pods are being recreated with correct probe..."
    sleep 10

    if wait_for_condition \
        "Backend pods to stabilize" \
        "kubectl get pods -n ${NAMESPACE} -l app=backend --no-headers | grep 'Running' | wc -l | grep -q '2'" \
        120 5; then
        log_success "Backend pods are stable!"
    else
        log_warn "Pods may still be stabilizing"
    fi

    log_step 3 "Current pod status"
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Fix Complete!"

    cat <<EOF
${GREEN}${BOLD}Liveness probe has been fixed!${NC}

${BOLD}What was done:${NC}
  ✓ Changed probe path from /wrong-health to /api/health
  ✓ Pods restarted with correct configuration
  ✓ Probe now checking valid endpoint
  ✓ Pods no longer restarting

${BOLD}Verify the fix:${NC}
  ${CYAN}./verify.sh${NC}

${BOLD}Check the dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Key Takeaways:${NC}
  • Liveness probes determine if container should restart
  • Wrong endpoint causes unnecessary restarts
  • Probe failures are shown in pod events
  • Set appropriate timing for your application

${BOLD}Probe Best Practices:${NC}
  • Keep health checks lightweight
  • Don't check external dependencies
  • Use readiness for traffic routing
  • Set reasonable failure thresholds
  • Log health check failures

EOF

    log_success "Exercise 07 fix completed!"
}

main "$@"