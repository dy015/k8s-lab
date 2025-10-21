#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$(cd "${SCRIPT_DIR}/../scripts/helpers" && pwd)"

source "${HELPERS_DIR}/colors.sh"
source "${HELPERS_DIR}/logger.sh"
source "${HELPERS_DIR}/validators.sh"

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Configure firewall rules for Kubernetes (k3s) cluster

OPTIONS:
    --remove    Remove firewall rules instead of adding them
    -h, --help  Show this help message

EOF
}

REMOVE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove)
                REMOVE=true
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

ensure_firewalld_running() {
    if ! systemctl is-active --quiet firewalld; then
        log_info "firewalld is not running, starting it..."
        systemctl start firewalld
        systemctl enable firewalld
        log_success "firewalld started and enabled"
    else
        log_info "firewalld is already running"
    fi
}

add_firewall_rules() {
    log_section "Adding Firewall Rules for Kubernetes"

    log_info "Adding required ports..."

    firewall-cmd --permanent --add-port=6443/tcp
    print_status "ok" "Port 6443/tcp (Kubernetes API server)"

    firewall-cmd --permanent --add-port=443/tcp
    print_status "ok" "Port 443/tcp (HTTPS/Ingress)"

    firewall-cmd --permanent --add-port=80/tcp
    print_status "ok" "Port 80/tcp (HTTP/Ingress)"

    firewall-cmd --permanent --add-port=10250/tcp
    print_status "ok" "Port 10250/tcp (Kubelet API)"

    firewall-cmd --permanent --add-port=8472/udp
    print_status "ok" "Port 8472/udp (Flannel VXLAN)"

    firewall-cmd --permanent --add-port=51820/udp
    print_status "ok" "Port 51820/udp (Flannel WireGuard)"

    firewall-cmd --permanent --add-port=51821/udp
    print_status "ok" "Port 51821/udp (Flannel WireGuard IPv6)"

    log_info "Adding trusted network sources..."

    if firewall-cmd --get-active-zones | grep -q trusted; then
        firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
        print_status "ok" "Pod network: 10.42.0.0/16"

        firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
        print_status "ok" "Service network: 10.43.0.0/16"
    else
        log_warn "Trusted zone not available, skipping network source configuration"
    fi

    log_info "Reloading firewall..."
    firewall-cmd --reload

    log_success "Firewall rules added successfully"
}

remove_firewall_rules() {
    log_section "Removing Firewall Rules for Kubernetes"

    log_info "Removing ports..."

    firewall-cmd --permanent --remove-port=6443/tcp 2>/dev/null || true
    firewall-cmd --permanent --remove-port=443/tcp 2>/dev/null || true
    firewall-cmd --permanent --remove-port=80/tcp 2>/dev/null || true
    firewall-cmd --permanent --remove-port=10250/tcp 2>/dev/null || true
    firewall-cmd --permanent --remove-port=8472/udp 2>/dev/null || true
    firewall-cmd --permanent --remove-port=51820/udp 2>/dev/null || true
    firewall-cmd --permanent --remove-port=51821/udp 2>/dev/null || true

    log_info "Removing trusted network sources..."

    if firewall-cmd --get-active-zones | grep -q trusted; then
        firewall-cmd --permanent --zone=trusted --remove-source=10.42.0.0/16 2>/dev/null || true
        firewall-cmd --permanent --zone=trusted --remove-source=10.43.0.0/16 2>/dev/null || true
    fi

    log_info "Reloading firewall..."
    firewall-cmd --reload

    log_success "Firewall rules removed successfully"
}

display_current_rules() {
    log_section "Current Firewall Configuration"

    echo -e "${BOLD}Active Zones:${NC}"
    firewall-cmd --get-active-zones
    echo

    echo -e "${BOLD}Public Zone Ports:${NC}"
    firewall-cmd --zone=public --list-ports
    echo

    if firewall-cmd --get-active-zones | grep -q trusted; then
        echo -e "${BOLD}Trusted Zone Sources:${NC}"
        firewall-cmd --zone=trusted --list-sources
        echo
    fi

    echo -e "${BOLD}All Rules:${NC}"
    firewall-cmd --list-all
}

main() {
    init_log

    parse_args "$@"

    if ! check_root; then
        exit 1
    fi

    ensure_firewalld_running

    if [[ "${REMOVE}" == true ]]; then
        remove_firewall_rules
    else
        add_firewall_rules
    fi

    display_current_rules

    log_success "Firewall configuration completed!"
}

main "$@"
