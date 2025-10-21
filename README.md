# Kubernetes Break & Fix Workshop

**Learn Kubernetes by Breaking & Fixing It!**

A hands-on workshop where you deploy a working 3-tier application, then systematically break and repair it through 15 progressive exercises.

---

## 🎯 What You'll Learn

- Install and configure Kubernetes (k3s) on CentOS
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
**Target OS:** CentOS 7.9+, CentOS 8 Stream, Rocky Linux 8

---

## ⚡ Quick Start (15 Minutes)

### 1. Install Kubernetes Cluster (5-10 min)

```bash
cd setup
sudo ./00-install-cluster.sh
./verify-cluster.sh
```

### 2. Deploy Application (3-5 min)

```bash
cd ../baseline-app
./00-deploy-baseline.sh
./verify-baseline.sh
```

**Images automatically pulled from:** `docker.io/reddydodda`

### 3. Configure Access

```bash
# Get your VM IP
kubectl get nodes -o wide

# Add to /etc/hosts (on your local machine)
echo "YOUR_VM_IP taskmaster.local" | sudo tee -a /etc/hosts
```

### 4. Access Dashboard

**Open:** http://taskmaster.local

You should see a beautiful dashboard with real-time status!

### 5. Start Learning

```bash
cd ../exercises/01-crashloopbackoff
cat README.md
./break.sh
# Now troubleshoot and fix!
```

**See [QUICKSTART.md](QUICKSTART.md) for detailed step-by-step guide.**

---

## 📦 What's Included

### ✅ Production-Ready Components

- **Cluster Setup** - Complete k3s installation for CentOS
- **3-Tier Application** - Frontend, Backend API, PostgreSQL
- **Docker Images** - Pre-built and published to Docker Hub
- **15 Exercises** - Progressively harder scenarios (1 complete, 14 templates ready)
- **Helper Scripts** - Beautiful logging, validation, and utilities
- **Documentation** - Setup guides and troubleshooting tips

### 🎨 Application Features

**Frontend (nginx):**
- Responsive HTML/CSS/JS dashboard
- Real-time status monitoring
- Task management UI
- Color-coded health indicators (🟢 🟡 🔴)

**Backend (Python Flask):**
- REST API with health endpoints
- PostgreSQL integration
- Full CRUD operations for tasks
- Production-ready with gunicorn

**Database (PostgreSQL):**
- Persistent storage (5Gi PVC)
- Auto-initialized schema
- Seed data included
- Health checks configured

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

---

## 📚 Workshop Structure

### Exercises

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

**Current Status:** Exercise 01 complete with all scripts and documentation

---

## 🛠️ System Requirements

### Minimum
- **CPU:** 2 cores
- **RAM:** 4 GB
- **Disk:** 20 GB
- **OS:** CentOS 7.9+, CentOS 8 Stream, Rocky Linux 8

### Recommended
- **CPU:** 4 cores
- **RAM:** 8 GB
- **Disk:** 40 GB

---

## 📖 Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 15 minutes
- **[IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md)** - Current progress
- **[setup/README.md](setup/README.md)** - Cluster installation details
- **[files/K8S-WORKSHOP-DESIGN.md](files/K8S-WORKSHOP-DESIGN.md)** - Full design spec

---

## 🔧 Essential Commands

### Cluster Management

```bash
# View cluster info
kubectl cluster-info
kubectl get nodes

# View all resources
kubectl get all -A
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
```

---

## 🎓 Learning Path

### Hour 0-1: Setup
- Install k3s cluster
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

## 🚀 Features

### Simple Deployment
- ✅ No manual image building
- ✅ Images pulled from Docker Hub
- ✅ One-command installation
- ✅ Automatic verification

### Beautiful Output
- ✅ Color-coded terminal output
- ✅ Progress indicators
- ✅ Clear error messages
- ✅ Helpful next-step suggestions

### Production Quality
- ✅ Comprehensive error handling
- ✅ Idempotent scripts
- ✅ Detailed logging
- ✅ Safe rollback options

### Real Application
- ✅ Full 3-tier stack
- ✅ Persistent data
- ✅ Health monitoring
- ✅ Production-like setup

---

## 📁 Directory Structure

```
k8s-lab/
├── README.md                    # This file
├── QUICKSTART.md                # Quick start guide
├── IMPLEMENTATION-STATUS.md     # Current status
│
├── setup/                       # Cluster installation
│   ├── 00-install-cluster.sh
│   ├── verify-cluster.sh
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
└── docs/                      # Documentation (coming soon)
```

---

## 🧪 Testing

All scripts log to `/tmp/k8s-workshop-<timestamp>.log`

View the latest log:

```bash
tail -f $(ls -t /tmp/k8s-workshop-*.log | head -1)
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

## 📊 Current Progress

**Phase 1 Complete (40%):**
- ✅ Directory structure
- ✅ Helper scripts
- ✅ Setup scripts (install, verify, uninstall)
- ✅ Baseline application (frontend, backend, database)
- ✅ Docker images (published to docker.io/reddydodda)
- ✅ Exercise 01 (complete template)

**Remaining Work:**
- 🚧 Exercises 02-15 (template ready, needs customization)
- 🚧 Workshop documentation
- 🚧 Test suite

**Estimated completion:** 3-4 weeks for remaining exercises and docs

---

## 🤝 Contributing

This workshop is designed for hands-on learning. You can:

- Report issues or bugs
- Suggest improvements
- Add new exercises
- Improve documentation
- Share your experience

---

## 📝 License

MIT License - See LICENSE file for details

---

## 🎉 Ready to Start?

1. **Read:** [QUICKSTART.md](QUICKSTART.md)
2. **Install:** Follow the quick start guide
3. **Learn:** Start with Exercise 01
4. **Master:** Complete all 15 exercises

---

## 📞 Support

- **Logs:** Check `/tmp/k8s-workshop-*.log`
- **Status:** Review `IMPLEMENTATION-STATUS.md`
- **Setup:** See `setup/README.md`
- **Design:** Read `files/K8S-WORKSHOP-DESIGN.md`

---

**🚀 Start your Kubernetes journey today!**

The cluster installation takes ~10 minutes.
The application deploys in ~5 minutes.
Learning troubleshooting: Priceless! 😊

**Images available at:** https://hub.docker.com/u/reddydodda
