#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

BACKUP_FILE="/tmp/storageclass-backup.yaml"

main() {
    init_log

    log_section "Exercise 09: Reset to Baseline"

    if ! check_kubectl; then
        exit 1
    fi

    if [[ -f "${BACKUP_FILE}" ]]; then
        kubectl apply -f "${BACKUP_FILE}"
        rm -f "${BACKUP_FILE}"
    else
        kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: Immediate
EOF
    fi

    log_success "Reset completed!"
}

main "$@"
