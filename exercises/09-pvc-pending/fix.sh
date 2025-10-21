#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"

main() {
    init_log

    log_section "Exercise 09: Fixing PVC Issue"

    if ! check_kubectl; then
        exit 1
    fi

    log_step 1 "Recreating StorageClass"

    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: Immediate
EOF

    log_success "StorageClass created!"

    log_step 2 "Waiting for PVC to bind..."
    sleep 10

    kubectl get pvc -n ${NAMESPACE}
    kubectl get pods -n ${NAMESPACE}

    log_success "Exercise 09 fix completed!"
}

main "$@"
