#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
SECRET="backend-secret"
DEPLOYMENT="backend"

main() {
    init_log

    log_section "Exercise 05: Fixing Missing Secret"

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

The backend Secret was deleted, but the deployment still references it:

  Deployment expects: ${RED}backend-secret Secret${NC}
  Secret status:      ${RED}Not found${NC}

${BOLD}Why it failed:${NC}

1. Backend deployment uses secretRef to inject database credentials
2. The Secret contains sensitive database connection information
3. When Secret is missing, pods can't be created
4. Kubernetes can't start containers without required secrets
5. Pods stuck in CreateContainerConfigError state

${BOLD}The solution:${NC}

Recreate the backend-secret Secret with the required database connection data.

${BOLD}Important Note:${NC}
Secrets store sensitive data and are base64 encoded (but NOT encrypted by default).

EOF

    if ! confirm "Apply the fix now?" "y"; then
        log_info "Fix cancelled"
        exit 0
    fi

    log_step 1 "Recreating backend Secret"

    kubectl create secret generic ${SECRET} -n ${NAMESPACE} \
      --from-literal=DB_HOST=postgres-svc \
      --from-literal=DB_PORT=5432 \
      --from-literal=DB_NAME=taskmaster

    log_success "Secret created!"

    log_step 2 "Verifying Secret"
    kubectl get secret ${SECRET} -n ${NAMESPACE}

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
${GREEN}${BOLD}Backend Secret has been restored!${NC}

${BOLD}What was done:${NC}
  ✓ Recreated backend-secret Secret
  ✓ Added database connection credentials
  ✓ Kubernetes automatically restarted pods
  ✓ Pods now have the credentials they need

${BOLD}Secret Details:${NC}
EOF
    kubectl describe secret ${SECRET} -n ${NAMESPACE}

    cat <<EOF

${BOLD}Note:${NC} Secret values are hidden in describe output for security.

${BOLD}To view encoded values:${NC}
  ${CYAN}kubectl get secret ${SECRET} -n ${NAMESPACE} -o yaml${NC}

${BOLD}To decode a value:${NC}
  ${CYAN}kubectl get secret ${SECRET} -n ${NAMESPACE} -o jsonpath='{.data.DB_HOST}' | base64 -d${NC}

${BOLD}Verify the fix:${NC}
  ${CYAN}./verify.sh${NC}

${BOLD}Check the dashboard:${NC}
  ${CYAN}http://taskmaster.local${NC}

${BOLD}Key Takeaways:${NC}
  • Secrets store sensitive configuration data
  • Pods can't start without required Secrets
  • Secrets are base64 encoded (not encrypted!)
  • Use 'kubectl create secret' to create them
  • Never commit Secrets to git repositories

${BOLD}Security Best Practices:${NC}
  • Enable encryption at rest for Secrets
  • Use RBAC to limit Secret access
  • Consider external secret management tools
  • Rotate secrets regularly
  • Use separate Secrets per environment

${BOLD}Useful commands used:${NC}
  • kubectl create secret generic <name> --from-literal=KEY=VALUE
  • kubectl get secrets
  • kubectl describe secret
  • kubectl delete secret (use with caution!)

EOF

    log_success "Exercise 05 fix completed!"
}

main "$@"