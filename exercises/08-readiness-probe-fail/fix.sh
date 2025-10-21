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

    log_section "Exercise 08: Fixing Readiness Probe"

    if ! check_kubectl; then
        exit 1
    fi

    if ! check_namespace "${NAMESPACE}"; then
        log_error "Namespace '${NAMESPACE}' not found."
        exit 1
    fi

    log_section "Problem Analysis"

    cat <<EOF
The readiness probe timing is too aggressive:

  Current: initialDelay=1s, period=1s, timeout=1s
  Needed:  initialDelay=10s, period=5s, timeout=5s

The application needs time to initialize before becoming ready.

EOF

    if ! confirm "Apply the fix now?" "y"; then
        log_info "Fix cancelled"
        exit 0
    fi

    log_step 1 "Fixing readiness probe timing"

    kubectl patch deployment ${DEPLOYMENT} -n ${NAMESPACE} --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/readinessProbe",
        "value": {
          "httpGet": {
            "path": "/api/health",
            "port": 8080
          },
          "initialDelaySeconds": 10,
          "periodSeconds": 5,
          "timeoutSeconds": 5,
          "failureThreshold": 3
        }
      }
    ]'

    log_success "Readiness probe timing fixed!"

    log_step 2 "Waiting for pods to become ready..."
    sleep 15

    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_success "Exercise 08 fix completed!"
}

main "$@"
