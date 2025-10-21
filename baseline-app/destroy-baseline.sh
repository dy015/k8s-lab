#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
FORCE=false

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Destroy the TaskMaster baseline application

OPTIONS:
    --force    Skip confirmation prompt
    -h, --help Show this help message

WARNING:
    This will remove all application resources including data!

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

confirm_destroy() {
    if [[ "${FORCE}" == true ]]; then
        return 0
    fi

    log_warn "This will destroy the entire TaskMaster application!"
    echo
    echo "The following will be removed:"
    echo "  • All pods (frontend, backend, database)"
    echo "  • All services"
    echo "  • Ingress configuration"
    echo "  • Persistent storage and data"
    echo "  • ConfigMaps and Secrets"
    echo

    if ! confirm "Are you sure you want to continue?" "n"; then
        log_info "Destroy cancelled by user"
        exit 0
    fi
}

delete_application() {
    log_step 1 "Deleting application components"

    if ! check_namespace "${NAMESPACE}"; then
        log_info "Namespace '${NAMESPACE}' does not exist"
        return 0
    fi

    log_info "Deleting ingress..."
    kubectl delete -f "${SCRIPT_DIR}/manifests/ingress/01-ingress.yaml" --ignore-not-found=true 2>&1 | tail -1

    log_info "Deleting frontend..."
    kubectl delete -f "${SCRIPT_DIR}/manifests/frontend/" --ignore-not-found=true 2>&1 | tail -3

    log_info "Deleting backend..."
    kubectl delete -f "${SCRIPT_DIR}/manifests/backend/" --ignore-not-found=true 2>&1 | tail -5

    log_info "Deleting database..."
    kubectl delete -f "${SCRIPT_DIR}/manifests/database/" --ignore-not-found=true 2>&1 | tail -5

    log_info "Deleting storage..."
    kubectl delete -f "${SCRIPT_DIR}/manifests/02-pvc-postgres.yaml" --ignore-not-found=true 2>&1 | tail -1

    log_success "Application components deleted"
}

delete_namespace() {
    log_step 2 "Deleting namespace"

    if check_namespace "${NAMESPACE}"; then
        kubectl delete namespace "${NAMESPACE}" --timeout=60s
        log_success "Namespace deleted"
    else
        log_info "Namespace already removed"
    fi
}

verify_cleanup() {
    log_step 3 "Verifying cleanup"

    if check_namespace "${NAMESPACE}"; then
        print_status "warn" "Namespace still exists (may be terminating)"
    else
        print_status "ok" "Namespace removed"
    fi

    log_success "Cleanup verification completed"
}

display_summary() {
    log_section "Cleanup Complete"

    cat <<EOF
${GREEN}TaskMaster application has been destroyed!${NC}

${BOLD}What was removed:${NC}
  ✓ All application pods
  ✓ All services
  ✓ Ingress configuration
  ✓ Persistent storage and data
  ✓ ConfigMaps and Secrets
  ✓ Namespace '${NAMESPACE}'

${BOLD}To redeploy the application:${NC}
  ${CYAN}./00-deploy-baseline.sh${NC}

${BOLD}To verify cluster is clean:${NC}
  ${CYAN}kubectl get all -n ${NAMESPACE}${NC}
  (should return: "No resources found")

EOF
}

main() {
    init_log

    parse_args "$@"

    log_section "Destroying TaskMaster Baseline Application"

    if ! check_kubectl; then
        exit 1
    fi

    confirm_destroy

    delete_application
    echo

    delete_namespace
    echo

    verify_cleanup
    echo

    display_summary

    log_success "Application destroy completed!"
}

main "$@"
