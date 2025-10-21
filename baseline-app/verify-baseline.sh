#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"

verify_namespace() {
    log_info "Checking namespace..."

    if check_namespace "${NAMESPACE}"; then
        print_status "ok" "Namespace '${NAMESPACE}' exists"
        return 0
    else
        print_status "fail" "Namespace '${NAMESPACE}' not found"
        return 1
    fi
}

verify_pods() {
    log_info "Checking pods..."

    local total_pods=$(kubectl get pods -n ${NAMESPACE} --no-headers 2>/dev/null | wc -l)
    local running_pods=$(kubectl get pods -n ${NAMESPACE} --no-headers 2>/dev/null | grep " Running" | wc -l)

    if [[ $total_pods -eq 0 ]]; then
        print_status "fail" "No pods found in namespace ${NAMESPACE}"
        return 1
    fi

    if [[ $running_pods -eq $total_pods ]]; then
        print_status "ok" "All ${total_pods} pods are Running"
    else
        print_status "warn" "${running_pods}/${total_pods} pods are Running"
    fi

    echo
    kubectl get pods -n ${NAMESPACE}
    return 0
}

verify_services() {
    log_info "Checking services..."

    local services=("postgres-svc" "backend-svc" "frontend-svc")
    local all_ok=true

    for svc in "${services[@]}"; do
        if kubectl get service ${svc} -n ${NAMESPACE} >/dev/null 2>&1; then
            local endpoints=$(kubectl get endpoints ${svc} -n ${NAMESPACE} -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
            if [[ $endpoints -gt 0 ]]; then
                print_status "ok" "Service ${svc} has ${endpoints} endpoint(s)"
            else
                print_status "warn" "Service ${svc} has no endpoints"
                all_ok=false
            fi
        else
            print_status "fail" "Service ${svc} not found"
            all_ok=false
        fi
    done

    echo
    kubectl get svc -n ${NAMESPACE}

    if [[ "${all_ok}" == true ]]; then
        return 0
    else
        return 1
    fi
}

verify_ingress() {
    log_info "Checking ingress..."

    if kubectl get ingress taskmaster-ingress -n ${NAMESPACE} >/dev/null 2>&1; then
        print_status "ok" "Ingress 'taskmaster-ingress' exists"
        echo
        kubectl get ingress -n ${NAMESPACE}
        return 0
    else
        print_status "fail" "Ingress not found"
        return 1
    fi
}

verify_pvc() {
    log_info "Checking PersistentVolumeClaim..."

    local pvc_status=$(kubectl get pvc postgres-pvc -n ${NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")

    if [[ "${pvc_status}" == "Bound" ]]; then
        print_status "ok" "PVC is Bound"
        return 0
    elif [[ "${pvc_status}" == "Pending" ]]; then
        print_status "warn" "PVC is Pending"
        return 1
    else
        print_status "fail" "PVC not found or in bad state: ${pvc_status}"
        return 1
    fi
}

test_database_connection() {
    log_info "Testing database connection..."

    local db_pod=$(kubectl get pods -n ${NAMESPACE} -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "${db_pod}" ]]; then
        print_status "fail" "Database pod not found"
        return 1
    fi

    if kubectl exec -n ${NAMESPACE} ${db_pod} -- pg_isready -U taskuser >/dev/null 2>&1; then
        print_status "ok" "Database is accepting connections"
        return 0
    else
        print_status "fail" "Database is not ready"
        return 1
    fi
}

test_backend_api() {
    log_info "Testing backend API..."

    local backend_pod=$(kubectl get pods -n ${NAMESPACE} -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "${backend_pod}" ]]; then
        print_status "fail" "Backend pod not found"
        return 1
    fi

    if kubectl exec -n ${NAMESPACE} ${backend_pod} -- wget -q -O- http://localhost:5000/api/health >/dev/null 2>&1; then
        print_status "ok" "Backend API is responding"
        return 0
    else
        print_status "warn" "Backend API health check failed"
        return 1
    fi
}

test_frontend() {
    log_info "Testing frontend..."

    local frontend_pod=$(kubectl get pods -n ${NAMESPACE} -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "${frontend_pod}" ]]; then
        print_status "fail" "Frontend pod not found"
        return 1
    fi

    if kubectl exec -n ${NAMESPACE} ${frontend_pod} -- wget -q -O- http://localhost/ >/dev/null 2>&1; then
        print_status "ok" "Frontend is serving pages"
        return 0
    else
        print_status "warn" "Frontend health check failed"
        return 1
    fi
}

test_full_stack() {
    log_info "Testing full application stack via ingress..."

    local node_ip=$(get_node_ip)

    log_info "Testing frontend access..."
    if curl -sf -H "Host: taskmaster.local" http://${node_ip}/ >/dev/null 2>&1; then
        print_status "ok" "Frontend accessible via ingress"
    else
        print_status "warn" "Frontend not accessible via ingress"
        log_info "Make sure /etc/hosts has: ${node_ip} taskmaster.local"
    fi

    log_info "Testing backend API access..."
    if curl -sf -H "Host: taskmaster.local" http://${node_ip}/api/health >/dev/null 2>&1; then
        print_status "ok" "Backend API accessible via ingress"
    else
        print_status "warn" "Backend API not accessible via ingress"
    fi
}

display_summary() {
    local failed=$1

    log_section "Verification Summary"

    if [[ $failed -eq 0 ]]; then
        cat <<EOF
${GREEN}${BOLD}✓ All checks passed!${NC}

Your TaskMaster application is healthy and ready to use.

${BOLD}Access the application:${NC}
  ${GREEN}http://taskmaster.local${NC}

${BOLD}Next Steps:${NC}
  1. Open the dashboard in your browser
  2. Test adding and managing tasks
  3. Start the break-and-fix exercises:
     ${CYAN}cd ../exercises/01-crashloopbackoff${NC}
     ${CYAN}cat README.md${NC}

EOF
    else
        cat <<EOF
${YELLOW}${BOLD}⚠ ${failed} check(s) failed or returned warnings${NC}

Some components may not be fully ready. Wait a few minutes and try again.

${BOLD}Troubleshooting:${NC}
  • Check pod status:    ${CYAN}kubectl get pods -n ${NAMESPACE}${NC}
  • Check pod logs:      ${CYAN}kubectl logs -n ${NAMESPACE} -l app=<component>${NC}
  • Check events:        ${CYAN}kubectl get events -n ${NAMESPACE}${NC}
  • Describe resources:  ${CYAN}kubectl describe pod <pod-name> -n ${NAMESPACE}${NC}

EOF
    fi
}

main() {
    init_log

    log_section "TaskMaster Baseline Application Verification"

    local failed=0

    verify_namespace || ((failed++))
    echo

    verify_pods || ((failed++))
    echo

    verify_services || ((failed++))
    echo

    verify_ingress || ((failed++))
    echo

    verify_pvc || ((failed++))
    echo

    test_database_connection || ((failed++))
    echo

    test_backend_api || ((failed++))
    echo

    test_frontend || ((failed++))
    echo

    test_full_stack || ((failed++))
    echo

    display_summary $failed

    if [[ $failed -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
