#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

NAMESPACE="taskmaster"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"

check_prerequisites() {
    log_step 1 "Checking prerequisites"

    if ! check_kubectl; then
        log_error "kubectl is not configured properly"
        exit 1
    fi

    if ! kubectl get nodes | grep -q " Ready"; then
        log_error "Kubernetes cluster is not ready"
        log_info "Please install the cluster first:"
        log_info "  cd ../setup"
        log_info "  sudo ./00-install-cluster.sh"
        exit 1
    fi

    log_success "Prerequisites check completed"
}

create_namespace() {
    log_step 2 "Creating namespace"

    if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
        log_info "Namespace '${NAMESPACE}' already exists"
    else
        kubectl apply -f "${MANIFESTS_DIR}/00-namespace.yaml"
        log_success "Namespace created"
    fi
}

deploy_storage() {
    log_step 3 "Deploying storage"

    log_info "Applying StorageClass..."
    kubectl apply -f "${MANIFESTS_DIR}/01-storage-class.yaml" 2>&1 | tail -1

    log_info "Creating PersistentVolumeClaim..."
    kubectl apply -f "${MANIFESTS_DIR}/02-pvc-postgres.yaml" 2>&1 | tail -1

    log_success "Storage configuration applied"
}

deploy_database() {
    log_step 4 "Deploying PostgreSQL database"

    log_info "Applying database secret..."
    kubectl apply -f "${MANIFESTS_DIR}/database/01-secret.yaml" 2>&1 | tail -1

    log_info "Applying database init ConfigMap..."
    kubectl apply -f "${MANIFESTS_DIR}/database/02-configmap.yaml" 2>&1 | tail -1

    log_info "Deploying database..."
    kubectl apply -f "${MANIFESTS_DIR}/database/03-deployment.yaml" 2>&1 | tail -1

    log_info "Creating database service..."
    kubectl apply -f "${MANIFESTS_DIR}/database/04-service.yaml" 2>&1 | tail -1

    log_info "Waiting for database to be ready..."
    if wait_for_condition \
        "PostgreSQL pod to be ready" \
        "kubectl get pods -n ${NAMESPACE} -l app=postgres -o jsonpath='{.items[0].status.phase}' | grep -q Running" \
        180 10; then
        log_success "Database deployed successfully"
    else
        log_error "Database failed to start"
        kubectl get pods -n ${NAMESPACE} -l app=postgres
        kubectl logs -n ${NAMESPACE} -l app=postgres --tail=50 || true
        return 1
    fi
}

deploy_backend() {
    log_step 5 "Deploying Backend API"

    log_info "Applying backend ConfigMap..."
    kubectl apply -f "${MANIFESTS_DIR}/backend/01-configmap.yaml" 2>&1 | tail -1

    log_info "Applying backend secret..."
    kubectl apply -f "${MANIFESTS_DIR}/backend/02-secret.yaml" 2>&1 | tail -1

    log_info "Deploying backend (pulling image from docker.io/reddydodda)..."
    kubectl apply -f "${MANIFESTS_DIR}/backend/03-deployment.yaml" 2>&1 | tail -1

    log_info "Creating backend service..."
    kubectl apply -f "${MANIFESTS_DIR}/backend/04-service.yaml" 2>&1 | tail -1

    log_info "Waiting for backend to be ready..."
    if wait_for_condition \
        "Backend pods to be ready" \
        "kubectl get deployment backend -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' | grep -q '2'" \
        180 10; then
        log_success "Backend deployed successfully"
    else
        log_warn "Backend may not be fully ready yet"
        kubectl get pods -n ${NAMESPACE} -l app=backend
    fi
}

deploy_frontend() {
    log_step 6 "Deploying Frontend"

    log_info "Deploying frontend (pulling image from docker.io/reddydodda)..."
    kubectl apply -f "${MANIFESTS_DIR}/frontend/01-deployment.yaml" 2>&1 | tail -1

    log_info "Creating frontend service..."
    kubectl apply -f "${MANIFESTS_DIR}/frontend/02-service.yaml" 2>&1 | tail -1

    log_info "Waiting for frontend to be ready..."
    if wait_for_condition \
        "Frontend pods to be ready" \
        "kubectl get deployment frontend -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' | grep -q '2'" \
        120 10; then
        log_success "Frontend deployed successfully"
    else
        log_warn "Frontend may not be fully ready yet"
        kubectl get pods -n ${NAMESPACE} -l app=frontend
    fi
}

deploy_ingress() {
    log_step 7 "Deploying Ingress"

    log_info "Creating ingress rules..."
    kubectl apply -f "${MANIFESTS_DIR}/ingress/01-ingress.yaml" 2>&1 | tail -1

    log_info "Waiting for ingress to be ready..."
    sleep 10

    log_success "Ingress deployed"
}

verify_deployment() {
    log_step 8 "Verifying deployment"

    log_info "Checking all pods..."
    kubectl get pods -n ${NAMESPACE}

    local not_running=$(kubectl get pods -n ${NAMESPACE} --no-headers | grep -v "Running" | wc -l)
    if [[ $not_running -eq 0 ]]; then
        print_status "ok" "All pods are running"
    else
        print_status "warn" "${not_running} pods are not running yet"
    fi

    log_info "Checking services..."
    kubectl get svc -n ${NAMESPACE}

    log_info "Checking ingress..."
    kubectl get ingress -n ${NAMESPACE}

    log_success "Deployment verification completed"
}

configure_hosts_entry() {
    local node_ip=$(get_node_ip)

    log_section "Hosts Configuration"

    cat <<EOF
${YELLOW}To access the application, add this entry to your /etc/hosts file:${NC}

${BOLD}On your local machine (not the VM):${NC}
  ${CYAN}echo "${node_ip} taskmaster.local" | sudo tee -a /etc/hosts${NC}

${BOLD}Or edit manually:${NC}
  ${CYAN}sudo nano /etc/hosts${NC}

  Add this line:
  ${GREEN}${node_ip}  taskmaster.local${NC}

EOF
}

display_access_info() {
    local node_ip=$(get_node_ip)

    log_section "Deployment Complete!"

    cat <<EOF
${GREEN}${BOLD}TaskMaster application deployed successfully!${NC}

${BOLD}Application Information:${NC}
  Namespace:     ${NAMESPACE}
  Node IP:       ${node_ip}
  Ingress Host:  taskmaster.local
  Images From:   docker.io/reddydodda

${BOLD}Deployed Components:${NC}
EOF

    kubectl get all -n ${NAMESPACE}

    echo
    cat <<EOF
${BOLD}Access URLs:${NC}
  ${GREEN}http://taskmaster.local${NC}          - Frontend Dashboard
  ${GREEN}http://taskmaster.local/api/health${NC} - Backend Health Check

${BOLD}Useful Commands:${NC}
  • View all resources:    ${CYAN}kubectl get all -n ${NAMESPACE}${NC}
  • View pods:             ${CYAN}kubectl get pods -n ${NAMESPACE}${NC}
  • View logs (backend):   ${CYAN}kubectl logs -n ${NAMESPACE} -l app=backend${NC}
  • View logs (frontend):  ${CYAN}kubectl logs -n ${NAMESPACE} -l app=frontend${NC}
  • View logs (database):  ${CYAN}kubectl logs -n ${NAMESPACE} -l app=postgres${NC}

${BOLD}Verify Deployment:${NC}
  ${CYAN}./verify-baseline.sh${NC}

${BOLD}Start Exercises:${NC}
  ${CYAN}cd ../exercises/01-crashloopbackoff${NC}
  ${CYAN}cat README.md${NC}

${BOLD}Workshop Status:${NC}
  ✅ Cluster installed
  ✅ Application deployed
  ✅ Ready for exercises!

EOF
}

main() {
    init_log

    log_section "Deploying TaskMaster Baseline Application"

    check_prerequisites
    echo

    create_namespace
    echo

    deploy_storage
    echo

    deploy_database
    echo

    deploy_backend
    echo

    deploy_frontend
    echo

    deploy_ingress
    echo

    verify_deployment
    echo

    configure_hosts_entry

    display_access_info

    log_success "Baseline application deployment completed!"
}

main "$@"
