# Kubernetes Break & Fix Workshop

**Learn Kubernetes by Breaking & Fixing It!**

A hands-on workshop where you deploy a working 3-tier application, then systematically break and repair it through 15 progressive exercises.

---

## 🎯 What You'll Learn

- Install and configure Kubernetes (kubeadm) on CentOS/Rocky Linux
- Deploy multi-tier applications (Frontend → Backend → Database)
- Master kubectl troubleshooting commands
- Fix 15 common Kubernetes issues:
  - Pod crashes (CrashLoopBackOff, ImagePullBackOff)
  - Service networking problems
  - ConfigMap and Secret issues
  - Resource limits and health probes
  - Storage and DNS problems
  - Ingress routing, RBAC, and network policies

**Duration:** 8-10 hours
**Difficulty:** Basic → Medium
**Target OS:** CentOS Stream 9, Rocky Linux 8/9
**Architecture:** x86_64/amd64 and ARM64/aarch64 (Multi-arch support)

---

## ⚡ Quick Start (20 Minutes)

### Prerequisites

- **VM:** VirtualBox or similar with CentOS Stream 9 (x86_64)
- **Resources:** 4GB RAM (8GB recommended), 2 CPU, 20GB disk
- **Access:** Root or sudo access
- **Network:** Internet connection

### Step 1: Install Kubernetes Cluster (8-12 min)

```bash
cd setup
sudo ./00-install-cluster.sh
./verify-cluster.sh
```

**What this installs:**
- kubeadm, kubelet, kubectl
- containerd container runtime
- Flannel CNI plugin
- nginx-ingress controller
- metrics-server

### Step 2: Deploy Application (3-5 min)

```bash
cd ../baseline-app
./00-deploy-baseline.sh
./verify-baseline.sh
```

**Images automatically pulled from:** `docker.io/reddydodda`

### Step 3: Configure Access

```bash
# Get your VM IP
kubectl get nodes -o wide

# Add to /etc/hosts (on your local machine)
echo "YOUR_VM_IP taskmaster.local" | sudo tee -a /etc/hosts
```

### Step 4: Access Dashboard

**Open:** http://taskmaster.local

You should see a beautiful dashboard with real-time status!

### Step 5: Start Learning

```bash
cd ../exercises/01-crashloopbackoff
cat README.md
./break.sh
# Now troubleshoot and fix!
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│          User Browser                    │
│     http://taskmaster.local              │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│      Ingress (nginx-ingress)            │
│      Routes: / → frontend               │
│              /api → backend             │
└──────────────┬──────────────────────────┘
               │
        ┌──────┴──────┐
        │             │
┌───────▼─────┐ ┌────▼────────┐
│  Frontend   │ │  Backend    │
│  (nginx)    │ │  (Flask)    │
│  Port: 80   │ │  Port: 5000 │
└─────────────┘ └─────┬───────┘
                      │
                ┌─────▼──────┐
                │  Database  │
                │ (PostgreSQL)│
                │  Port: 5432 │
                │  PVC: 5Gi   │
                └────────────┘
```

**Stack:**
- **K8s:** kubeadm v1.28
- **Runtime:** containerd
- **CNI:** Flannel
- **Ingress:** nginx-ingress
- **Metrics:** metrics-server

---

## 📚 Workshop Exercises

| # | Exercise | Issue | Difficulty | Time |
|---|----------|-------|------------|------|
| 01 | CrashLoopBackOff | Wrong command | ⭐ Basic | 15m |
| 02 | ImagePullBackOff | Bad image tag | ⭐ Basic | 15m |
| 03 | Service Unreachable | Wrong selector | ⭐⭐ Basic | 20m |
| 04 | ConfigMap Missing | Deleted config | ⭐⭐ Basic | 20m |
| 05 | Secret Missing | Deleted secret | ⭐⭐ Basic | 20m |
| 06 | OOM Killed | Memory limit | ⭐⭐ Medium | 25m |
| 07 | Liveness Probe | Wrong endpoint | ⭐⭐ Medium | 25m |
| 08 | Readiness Probe | Probe timing | ⭐⭐ Medium | 25m |
| 09 | PVC Pending | Storage issue | ⭐⭐⭐ Medium | 30m |
| 10 | DNS Not Working | CoreDNS down | ⭐⭐⭐ Medium | 30m |
| 11 | Ingress 404 | Wrong path | ⭐⭐ Medium | 25m |
| 12 | RBAC Forbidden | Missing perms | ⭐⭐⭐ Medium | 30m |
| 13 | Network Policy | Blocked traffic | ⭐⭐⭐ Medium | 30m |
| 14 | Node Pressure | Disk full | ⭐⭐⭐⭐ Advanced | 35m |
| 15 | Rollout Stuck | Bad deployment | ⭐⭐⭐ Medium | 30m |

**Current Status:** Exercise 01 complete, others ready as templates

---

## 🛠️ System Requirements

### Minimum
- **CPU:** 2 cores
- **RAM:** 4 GB
- **Disk:** 20 GB
- **OS:** CentOS Stream 9, Rocky Linux 8/9
- **Architecture:** x86_64/amd64 or ARM64/aarch64 (Multi-arch)

### Recommended
- **CPU:** 4 cores
- **RAM:** 8 GB
- **Disk:** 40 GB

### ✅ Multi-Architecture Support
**ARM64 SUPPORTED:** Docker images are built for both x86_64 and ARM64 architectures. The images will automatically pull the correct version for your system. See `BUILD-MULTI-ARCH-IMAGES.md` for details.

---

## 🔧 Essential Commands

### Cluster Management

```bash
# View cluster info
kubectl cluster-info
kubectl get nodes -o wide

# View all resources
kubectl get all -A

# Check services
systemctl status kubelet
systemctl status containerd
```

### Application Management

```bash
# View application resources
kubectl get all -n taskmaster

# Check pod status
kubectl get pods -n taskmaster
kubectl describe pod <pod-name> -n taskmaster

# View logs
kubectl logs -n taskmaster -l app=backend
kubectl logs -n taskmaster -l app=frontend
kubectl logs -n taskmaster -l app=postgres

# Execute commands in pod
kubectl exec -it <pod-name> -n taskmaster -- /bin/sh
```

### Debugging

```bash
# Check events
kubectl get events -n taskmaster

# Port forward
kubectl port-forward -n taskmaster svc/backend-svc 5000:5000

# Check resource usage
kubectl top nodes
kubectl top pods -n taskmaster

# Check logs
journalctl -u kubelet -f
journalctl -u containerd -f
```

---

## 🎓 Learning Path

### Hour 0-1: Setup
- Install kubeadm cluster
- Deploy baseline application
- Verify everything works

### Hours 1-3: Basic Pod Issues (Ex 01-05)
- CrashLoopBackOff debugging
- Image pull problems
- Service networking
- ConfigMaps and Secrets

### Hours 3-6: Resource Management (Ex 06-10)
- Memory limits (OOM)
- Health probes (liveness, readiness)
- Storage (PVC)
- DNS troubleshooting

### Hours 6-10: Advanced Topics (Ex 11-15)
- Ingress routing
- RBAC permissions
- Network policies
- Node pressure
- Deployment rollouts

---

## 🔄 Cleanup

### Remove Application Only

```bash
cd baseline-app
./destroy-baseline.sh
```

### Remove Everything

```bash
cd setup
sudo ./uninstall-cluster.sh
```

---

## 🎯 Success Criteria

Your setup is successful when:

- ✅ `kubectl get nodes` shows "Ready"
- ✅ All pods in "Running" state
- ✅ Dashboard accessible at http://taskmaster.local
- ✅ Green status for all services
- ✅ Can add/delete tasks in UI

---

## 📁 Directory Structure

```
k8s-lab1/
├── README.md                    # This file
├── QUICKSTART.md                # Detailed guide
│
├── setup/                       # Cluster installation
│   ├── 00-install-cluster.sh   # kubeadm installer
│   ├── verify-cluster.sh       # Health checks
│   ├── uninstall-cluster.sh    # Complete removal
│   └── README.md
│
├── baseline-app/               # 3-tier application
│   ├── 00-deploy-baseline.sh
│   ├── verify-baseline.sh
│   ├── destroy-baseline.sh
│   └── manifests/             # Kubernetes YAML files
│
├── exercises/                 # Break & Fix scenarios
│   ├── 01-crashloopbackoff/  # ✅ Complete
│   ├── 02-imagepullbackoff/  # Template ready
│   └── ... (15 total)
│
├── scripts/helpers/           # Utilities
│   ├── colors.sh
│   ├── logger.sh
│   └── validators.sh
│
└── docs/                      # Documentation
```

---

## 🧪 Troubleshooting

### Cluster Won't Install

```bash
# Check system resources
free -h
df -h
nproc

# Check logs
journalctl -u kubelet -f

# Verify architecture
uname -m  # Should show: x86_64 or aarch64 (both supported)
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n taskmaster

# Describe pod
kubectl describe pod <pod-name> -n taskmaster

# Check events
kubectl get events -n taskmaster --sort-by='.lastTimestamp'

# View logs
kubectl logs <pod-name> -n taskmaster
```

### Application Crashes with "exec format error"

**This means the Docker images don't match your architecture.**

```bash
# Check your architecture
uname -m  # Should show x86_64 or aarch64

# Verify images support your architecture
docker manifest inspect docker.io/reddydodda/taskmaster-backend:1.0

# Our images support both x86_64 and ARM64
```

### Dashboard Not Loading

```bash
# Check /etc/hosts entry
cat /etc/hosts | grep taskmaster

# Check ingress
kubectl get ingress -n taskmaster

# Check services
kubectl get svc -n taskmaster

# Test connectivity
curl http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
```

---

## 📖 Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Detailed setup guide
- **[setup/README.md](setup/README.md)** - Cluster installation details
- **[BUILD-MULTI-ARCH-IMAGES.md](BUILD-MULTI-ARCH-IMAGES.md)** - How multi-arch images were built
- **[docker-images/README.md](docker-images/README.md)** - Building your own images

---

## 🚀 Features

### Simple Deployment
- ✅ One-command installation
- ✅ Images pulled from Docker Hub
- ✅ Automatic verification
- ✅ Production-quality scripts

### Beautiful Output
- ✅ Color-coded terminal output
- ✅ Progress indicators
- ✅ Clear error messages
- ✅ Helpful next-step suggestions

### Real Application
- ✅ Full 3-tier stack
- ✅ Persistent data
- ✅ Health monitoring
- ✅ Production-like setup

---

## 🎉 Ready to Start?

1. **Verify Requirements:** CentOS/Rocky Linux (x86_64 or ARM64), 4GB RAM, 20GB disk
2. **Install:** `cd setup && sudo ./00-install-cluster.sh`
3. **Deploy:** `cd ../baseline-app && ./00-deploy-baseline.sh`
4. **Learn:** `cd ../exercises/01-crashloopbackoff`

**🚀 Start your Kubernetes journey today!**

The cluster installation takes ~10 minutes.
The application deploys in ~5 minutes.
Learning troubleshooting: Priceless! 😊

**Images available at:** https://hub.docker.com/u/reddydodda

---

## 📞 Support

- **Logs:** Check `/tmp/k8s-workshop-*.log`
- **Verify:** Run `./verify-cluster.sh` or `./verify-baseline.sh`
- **Architecture Check:** Run `./scripts/check-architecture.sh`
- **Issues:** See docs/ directory

---

## 📝 License

MIT License - See LICENSE file for details

---

**Happy Learning! 🎓**
