#!/bin/bash
#
# Architecture Compatibility Checker
# Verifies system architecture matches workshop requirements
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="${SCRIPT_DIR}/helpers"

if [[ -f "${HELPERS_DIR}/colors.sh" ]]; then
    source "${HELPERS_DIR}/colors.sh"
else
    # Fallback colors if helpers not available
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    BOLD='\033[1m'
fi

print_header() {
    echo
    echo "=============================================="
    echo "  Workshop Architecture Compatibility Check"
    echo "=============================================="
    echo
}

check_system_arch() {
    local arch=$(uname -m)

    echo -e "${BOLD}System Architecture:${NC}"
    echo "  Detected: ${arch}"
    echo

    case ${arch} in
        x86_64|amd64)
            echo -e "${GREEN}✓ Compatible${NC}"
            echo "  Your system uses x86_64/amd64 architecture."
            echo "  Workshop Docker images are compatible."
            echo
            return 0
            ;;
        aarch64|arm64)
            echo -e "${RED}✗ Incompatible${NC}"
            echo "  Your system uses ARM64/aarch64 architecture."
            echo "  Workshop Docker images are built for x86_64 only."
            echo
            echo -e "${YELLOW}This will cause issues:${NC}"
            echo "  • Pods will fail to start"
            echo "  • Error: exec format error"
            echo "  • Application won't run"
            echo
            return 1
            ;;
        *)
            echo -e "${YELLOW}⚠ Unknown architecture: ${arch}${NC}"
            echo "  Workshop is designed for x86_64/amd64."
            echo "  This architecture may not work correctly."
            echo
            return 2
            ;;
    esac
}

check_docker_images() {
    echo -e "${BOLD}Checking Docker Image Compatibility:${NC}"

    if ! command -v docker &> /dev/null; then
        echo "  Docker not found, skipping image check"
        echo
        return 0
    fi

    local images=(
        "docker.io/reddydodda/taskmaster-backend:1.0"
        "docker.io/reddydodda/taskmaster-frontend:1.0"
    )

    for image in "${images[@]}"; do
        echo -n "  Checking ${image}... "

        if docker manifest inspect ${image} &> /dev/null; then
            local archs=$(docker manifest inspect ${image} 2>/dev/null | grep -A2 '"architecture"' | grep 'architecture' | awk -F'"' '{print $4}' | sort -u)
            if [[ -n "${archs}" ]]; then
                echo "Architectures: ${archs}"
            else
                echo "amd64 (default)"
            fi
        else
            echo "Unable to check"
        fi
    done
    echo
}

provide_solutions() {
    local arch=$1

    echo -e "${BOLD}Solutions:${NC}"
    echo

    if [[ ${arch} == "aarch64" ]] || [[ ${arch} == "arm64" ]]; then
        echo -e "${YELLOW}Option 1: Use x86_64 VM (Recommended)${NC}"
        echo "  1. Download CentOS Stream 9 x86_64 ISO"
        echo "  2. Create new VirtualBox VM with x86_64 architecture"
        echo "  3. Install CentOS Stream 9"
        echo "  4. Run workshop on new VM"
        echo
        echo -e "${YELLOW}Option 2: Rebuild Images for ARM64${NC}"
        echo "  1. Get application source code"
        echo "  2. Build images for ARM64:"
        echo "     docker build --platform linux/arm64 -t YOUR_REGISTRY/taskmaster-backend:1.0-arm64 ."
        echo "  3. Update manifests to use new images"
        echo "  4. Deploy application"
        echo
        echo -e "${YELLOW}Option 3: Use QEMU Emulation (Slow)${NC}"
        echo "  1. Install QEMU: sudo yum install -y qemu-user-static"
        echo "  2. Deploy application (will be very slow)"
        echo
        echo -e "${BOLD}For detailed instructions, see:${NC}"
        echo "  • FIX-ARM64-DEPLOYMENT.md"
        echo "  • ARCHITECTURE-FIX.md"
        echo
    fi
}

check_kubernetes() {
    echo -e "${BOLD}Kubernetes Status:${NC}"

    if command -v kubectl &> /dev/null; then
        if kubectl cluster-info &> /dev/null; then
            echo -e "  ${GREEN}✓ Kubernetes is running${NC}"

            local node_arch=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.architecture}' 2>/dev/null || echo "unknown")
            echo "  Cluster architecture: ${node_arch}"

            if [[ ${node_arch} == "amd64" ]] || [[ ${node_arch} == "x86_64" ]]; then
                echo -e "  ${GREEN}✓ Cluster is compatible${NC}"
            elif [[ ${node_arch} == "arm64" ]] || [[ ${node_arch} == "aarch64" ]]; then
                echo -e "  ${RED}✗ Cluster is ARM64 (incompatible with workshop images)${NC}"
            fi
        else
            echo "  Kubernetes not running or not configured"
        fi
    else
        echo "  kubectl not found"
    fi
    echo
}

check_running_pods() {
    if ! command -v kubectl &> /dev/null; then
        return 0
    fi

    if ! kubectl cluster-info &> /dev/null; then
        return 0
    fi

    if ! kubectl get namespace taskmaster &> /dev/null 2>&1; then
        return 0
    fi

    echo -e "${BOLD}Checking TaskMaster Pods:${NC}"

    local backend_status=$(kubectl get pods -n taskmaster -l app=backend -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    local frontend_status=$(kubectl get pods -n taskmaster -l app=frontend -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")

    if [[ ${backend_status} == "NotFound" ]]; then
        echo "  No taskmaster pods found"
    else
        echo "  Backend:  ${backend_status}"
        echo "  Frontend: ${frontend_status}"

        if [[ ${backend_status} == "CrashLoopBackOff" ]] || [[ ${frontend_status} == "CrashLoopBackOff" ]]; then
            echo
            echo -e "${RED}✗ Pods are crashing${NC}"
            echo "  This is likely due to architecture mismatch."
            echo
            echo "  Check pod logs:"
            echo "    kubectl logs -n taskmaster -l app=backend"
            echo
            echo "  If you see 'exec format error', this confirms the issue."
        fi
    fi
    echo
}

generate_report() {
    local arch=$1
    local compatible=$2

    echo -e "${BOLD}Summary:${NC}"
    echo "  System Architecture: ${arch}"

    if [[ ${compatible} -eq 0 ]]; then
        echo -e "  Status: ${GREEN}✓ Compatible${NC}"
        echo
        echo "  You can proceed with the workshop!"
        echo
        echo "  Next steps:"
        echo "    cd setup"
        echo "    sudo ./00-install-cluster.sh      # or 00-install-cluster-kubeadm.sh"
        echo "    cd ../baseline-app"
        echo "    ./00-deploy-baseline.sh"
    else
        echo -e "  Status: ${RED}✗ Incompatible${NC}"
        echo
        echo "  Your system architecture is not compatible with workshop images."
        echo "  Please see the solutions above or read the documentation:"
        echo "    • FIX-ARM64-DEPLOYMENT.md"
        echo "    • ARCHITECTURE-FIX.md"
    fi
    echo
}

main() {
    print_header

    local exit_code=0

    check_system_arch || exit_code=$?

    check_docker_images

    check_kubernetes

    check_running_pods

    if [[ ${exit_code} -ne 0 ]]; then
        provide_solutions $(uname -m)
    fi

    echo "=============================================="
    echo

    generate_report $(uname -m) ${exit_code}

    exit ${exit_code}
}

main "$@"
