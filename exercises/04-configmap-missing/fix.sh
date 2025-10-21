#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
CONFIGMAP="backend-config"
DEPLOYMENT="backend"

main() {
    init_log

    log_section "Exercise 04: Fixing Missing ConfigMap"

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

The backend ConfigMap was deleted, but the deployment still references it:

  Deployment expects: ${RED}backend-config ConfigMap${NC}
  ConfigMap status:   ${RED}Not found${NC}

${BOLD}Why it failed:${NC}

1. Backend deployment uses configMapRef to inject environment variables
2. The ConfigMap contains important configuration (FLASK_ENV, LOG_LEVEL, etc.)
3. When ConfigMap is missing, pods can't be created
4. Kubernetes can't start containers without required configuration
5. Pods stuck in CreateContainerConfigError state

${BOLD}The solution:${NC}

Recreate the backend-config ConfigMap with the required configuration data.

EOF

    if ! confirm "Apply the fix now?" "y"; then
        log_info "Fix cancelled"
        exit 0
    fi

    log_step 1 "Recreating backend ConfigMap"

    kubectl create configmap ${CONFIGMAP} -n ${NAMESPACE} \
      --from-literal=FLASK_ENV=production \
      --from-literal=LOG_LEVEL=info \
      --from-literal=WORKERS=2

    log_success "ConfigMap created!"

    log_step 2 "Verifying ConfigMap"
    kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE}

    log_step 3 "Waiting for pods to start..."

    if wait_for_condition \
        "Backend pods to be ready" \
        "kubectl get deployment ${DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' | grep -q '2'" \
        120 5; then
        log_success "Backend pods are now running!"
    else
        log_warn "Pods may still be starting. Check status with: kubectl get pods -n ${NAMESPACE}"
    fi

    log_step 4 "Current status"
    kubectl get pods -n ${NAMESPACE} -l app=backend

    log_section "Fix Complete!"

    cat <<EOF
${GREEN}${BOLD}Backend ConfigMap has been restored!${NC}

${BOLD}What was done:${NC}
  ✓ Recreated backend-config ConfigMap
  ✓ Added required environment variables
  ✓ Kubernetes automatically restarted pods
  ✓ Pods now have the configuration they need

${BOLD}ConfigMap Contents:${NC}
EOF
    kubectl describe configmap ${CONFIGMAP} -n ${NAMESPACE}

    cat <<EOF

${BOLD}Verify the fix:${NC}
  ${CYAN}./verify.sh${NC}

${BOLD}Check the dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Key Takeaways:${NC}
  • ConfigMaps store configuration data
  • Pods can't start without required ConfigMaps
  • Always backup ConfigMaps before deleting
  • Use 'kubectl create configmap' to create them
  • ConfigMaps can be created from literals, files, or YAML

${BOLD}Useful commands used:${NC}
  • kubectl create configmap <name> --from-literal=KEY=VALUE
  • kubectl get configmaps
  • kubectl describe configmap
  • kubectl delete configmap (use with caution!)

EOF

    log_success "Exercise 04 fix completed!"
}

main "$@"
