# Setup - Kubernetes Cluster Installation

This directory contains scripts to install, verify, and manage a kubeadm Kubernetes cluster on CentOS/Rocky Linux.

## Quick Start

```bash
# Install cluster (requires root/sudo)
sudo ./00-install-cluster.sh

# Verify installation
./verify-cluster.sh

# (Optional) Uninstall cluster
sudo ./uninstall-cluster.sh
```

## Scripts Overview

### 00-install-cluster.sh

Installs kubeadm Kubernetes cluster with all required components.

**Usage:**
```bash
sudo ./00-install-cluster.sh [OPTIONS]
```

**Options:**
- `--k8s-version VERSION` - Specify Kubernetes version (default: 1.28.0)
- `--pod-cidr CIDR` - Pod network CIDR (default: 10.244.0.0/16)
- `--api-server-ip IP` - API server advertise IP (default: auto-detect)
- `--skip-firewall` - Skip firewall configuration
- `--skip-selinux` - Skip SELinux configuration
- `--dry-run` - Show what would be done without executing
- `-h, --help` - Show help message

**What it does:**
1. Validates system requirements (4GB RAM, 20GB disk, 2 CPU cores)
2. Disables swap
3. Loads required kernel modules (br_netfilter, overlay)
4. Configures sysctl settings for Kubernetes
5. Configures firewall rules (firewalld)
6. Sets SELinux to permissive mode
7. Installs container runtime (containerd)
8. Installs kubeadm, kubelet, kubectl
9. Initializes Kubernetes cluster
10. Configures kubectl
11. Installs Flannel CNI
12. Installs nginx-ingress-controller
13. Installs metrics-server
14. Installs local-path storage provisioner (for PVCs)
15. Verifies installation

**Examples:**
```bash
# Install with defaults (auto-detect IP)
sudo ./00-install-cluster.sh

# Install with specific Kubernetes version
sudo ./00-install-cluster.sh --k8s-version 1.28.0

# Install with custom API server IP (for multiple interfaces)
sudo ./00-install-cluster.sh --api-server-ip 192.168.1.100

# Dry run to see what would be done
sudo ./00-install-cluster.sh --dry-run

# Skip firewall configuration
sudo ./00-install-cluster.sh --skip-firewall
```

**Installation Time:** 5-10 minutes

---

### verify-cluster.sh

Verifies that the Kubernetes cluster is healthy and all components are running.

**Usage:**
```bash
./verify-cluster.sh
```

**What it checks:**
- kubelet service status
- containerd service status
- kubectl connectivity
- Node Ready status
- Control plane pods (kube-apiserver, kube-scheduler, kube-controller-manager, etcd)
- System pods (kube-system namespace)
- CoreDNS functionality
- DNS resolution
- Flannel CNI
- Ingress controller
- Metrics-server
- Storage class availability
- Resource usage

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed

---

### uninstall-cluster.sh

Completely removes kubeadm cluster and all cluster resources.

**Usage:**
```bash
sudo ./uninstall-cluster.sh [OPTIONS]
```

**Options:**
- `--force` - Skip confirmation prompts
- `-h, --help` - Show help message

**What it removes:**
- kubeadm, kubelet, kubectl packages
- containerd container runtime
- All containers and images
- All persistent data (/var/lib/kubelet, /etc/kubernetes, /var/lib/etcd)
- kubectl configuration
- CNI configurations
- Network configurations
- Firewall rules
- System configurations (kernel modules, sysctl)

**Warning:** This action cannot be undone! All cluster data will be lost.

**Examples:**
```bash
# Uninstall with confirmation prompts
sudo ./uninstall-cluster.sh

# Force uninstall without prompts
sudo ./uninstall-cluster.sh --force
```

---

### configure-firewall.sh

Configures firewall rules for Kubernetes.

**Usage:**
```bash
sudo ./configure-firewall.sh [OPTIONS]
```

**Options:**
- `--remove` - Remove firewall rules
- `-h, --help` - Show help message

**Ports configured:**
- `6443/tcp` - Kubernetes API server
- `443/tcp` - HTTPS/Ingress
- `80/tcp` - HTTP/Ingress
- `10250/tcp` - Kubelet API
- `8472/udp` - Flannel VXLAN
- `51820/udp` - Flannel WireGuard
- `51821/udp` - Flannel WireGuard IPv6

**Trusted networks:**
- `10.42.0.0/16` - Pod network
- `10.43.0.0/16` - Service network

**Examples:**
```bash
# Add firewall rules
sudo ./configure-firewall.sh

# Remove firewall rules
sudo ./configure-firewall.sh --remove
```

---

### configure-selinux.sh

Configures SELinux for Kubernetes.

**Usage:**
```bash
sudo ./configure-selinux.sh [OPTIONS]
```

**Options:**
- `--enforcing` - Set SELinux to enforcing mode
- `--permissive` - Set SELinux to permissive mode (default, recommended)
- `--status` - Show current SELinux status
- `-h, --help` - Show help message

**Note:** Kubernetes works best with SELinux in permissive mode.

**Examples:**
```bash
# Set to permissive (recommended for Kubernetes)
sudo ./configure-selinux.sh --permissive

# Check SELinux status
sudo ./configure-selinux.sh --status

# Set to enforcing (may cause issues with Kubernetes)
sudo ./configure-selinux.sh --enforcing
```

---

## System Requirements

### Minimum
- **OS:** CentOS 7.9+, CentOS 8 Stream, or Rocky Linux 8
- **CPU:** 2 cores
- **RAM:** 4 GB
- **Disk:** 20 GB free space
- **Network:** Internet connectivity (for initial setup)

### Recommended
- **CPU:** 4 cores
- **RAM:** 8 GB
- **Disk:** 40 GB free space

## Prerequisites

- Root or sudo access
- CentOS/Rocky Linux operating system
- Internet connectivity (for downloading packages and images)
- Firewalld installed (for firewall configuration)

## Installation Flow

```
┌─────────────────────────────────────────┐
│  1. Prerequisites Check                 │
│     - Root access                       │
│     - CentOS version                    │
│     - System resources                  │
│     - No existing k8s                   │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  2. System Preparation                  │
│     - Disable swap                      │
│     - Load kernel modules               │
│     - Configure sysctl                  │
│     - Configure firewall                │
│     - Set SELinux to permissive         │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  3. Container Runtime Installation      │
│     - Install containerd                │
│     - Configure containerd              │
│     - Start containerd service          │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  4. Kubernetes Installation             │
│     - Add Kubernetes repo               │
│     - Install kubeadm, kubelet, kubectl │
│     - Start kubelet service             │
│     - Initialize cluster (kubeadm init) │
│     - Install Flannel CNI               │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  5. kubectl Configuration               │
│     - Copy kubeconfig                   │
│     - Set permissions                   │
│     - Verify connectivity               │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  6. Add-ons Installation                │
│     - nginx-ingress-controller          │
│     - metrics-server                    │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│  7. Verification                        │
│     - Service status                    │
│     - Node status                       │
│     - Pod status                        │
│     - DNS resolution                    │
└────────────────┬────────────────────────┘
                 │
                 ▼
            ✓ Complete!
```

## Troubleshooting

### Installation Issues

**Problem:** Installation fails with "insufficient resources"
```bash
# Check system resources
free -h
df -h
nproc
```

**Problem:** kubelet service won't start
```bash
# Check service status
systemctl status kubelet

# View logs
journalctl -u kubelet -f

# Check if swap is still enabled
swapon --show

# Check containerd
systemctl status containerd
```

**Problem:** Firewall is blocking traffic
```bash
# Check firewall status
firewall-cmd --list-all

# Temporarily disable firewall for testing
systemctl stop firewalld

# Or reconfigure firewall
sudo ./configure-firewall.sh
```

### Verification Issues

**Problem:** Pods are not running
```bash
# Check pod status
kubectl get pods -A

# Describe pod for details
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
```

**Problem:** DNS resolution not working
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run test-dns --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default
```

**Problem:** Ingress controller not working
```bash
# Check ingress controller status
kubectl get pods -n ingress-nginx

# Check ingress controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## Logs

All scripts log to `/tmp/k8s-workshop-<timestamp>.log`

View logs:
```bash
# List recent log files
ls -lt /tmp/k8s-workshop-*.log | head

# View latest log
tail -f $(ls -t /tmp/k8s-workshop-*.log | head -1)
```

## Next Steps

After successful cluster installation:

1. **Verify the cluster:**
   ```bash
   ./verify-cluster.sh
   ```

2. **Deploy the baseline application:**
   ```bash
   cd ../baseline-app
   ./00-deploy-baseline.sh
   ```

3. **Start the workshop exercises:**
   ```bash
   cd ../exercises/01-crashloopbackoff
   cat README.md
   ```

## Additional Resources

- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [containerd Documentation](https://containerd.io/)
- [Workshop Documentation](../docs/)

## Support

If you encounter issues:

1. Check the log files
2. Run the verify script: `./verify-cluster.sh`
3. Review the troubleshooting section above
4. Check system resources: `kubectl top nodes`
5. Review pod logs: `kubectl logs <pod-name> -n <namespace>`
