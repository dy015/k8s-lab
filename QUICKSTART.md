# Kubernetes Workshop - Quick Start Guide

Get started with the Kubernetes Break & Fix Workshop in under 15 minutes!

## Prerequisites

- **OS:** CentOS 7.9+, CentOS 8 Stream, or Rocky Linux 8
- **Resources:** 4GB RAM (8GB recommended), 2 CPU cores (4 recommended), 20GB disk
- **Access:** Root or sudo access
- **Network:** Internet connection for initial setup

## Step-by-Step Setup

### Step 1: Install Kubernetes Cluster (5-10 minutes)

```bash
cd setup
sudo ./00-install-cluster.sh
```

**What this does:**
- Installs kubeadm Kubernetes cluster
- Installs containerd container runtime
- Configures firewall and SELinux
- Installs Flannel CNI
- Installs nginx-ingress and metrics-server
- Sets up kubectl

**Wait for:** Green success message showing cluster is ready

---

### Step 2: Verify Cluster Installation

```bash
./verify-cluster.sh
```

**Expected:** All checks should pass (green status)

If any checks fail, wait a few minutes and run again.

---

### Step 3: Deploy Application (3-5 minutes)

```bash
cd ../baseline-app
./00-deploy-baseline.sh
```

**What this does:**
- Creates taskmaster namespace
- Deploys PostgreSQL database with persistent storage
- Deploys Flask backend API (pulls from docker.io/reddydodda)
- Deploys nginx frontend (pulls from docker.io/reddydodda)
- Creates ingress routing

**Images Used:**
- `docker.io/reddydodda/taskmaster-frontend:1.0`
- `docker.io/reddydodda/taskmaster-backend:1.0`
- `postgres:15-alpine`

---

### Step 4: Verify Application

```bash
./verify-baseline.sh
```

**Expected:** All checks pass, application is healthy

---

### Step 5: Configure Access

Add this to your `/etc/hosts` file (on your local machine, not the VM):

```bash
# Get VM IP first
kubectl get nodes -o wide

# Then add to /etc/hosts
echo "YOUR_VM_IP taskmaster.local" | sudo tee -a /etc/hosts
```

**Example:**
```
192.168.1.100 taskmaster.local
```

---

### Step 6: Access the Dashboard

Open your web browser:

**URL:** http://taskmaster.local

You should see:
- ✅ Beautiful TaskMaster dashboard
- ✅ Green status indicators for all services
- ✅ Task list with sample data
- ✅ Ability to add/delete tasks

---

### Step 7: Start Learning! (8-10 hours)

Begin with Exercise 01:

```bash
cd ../exercises/01-crashloopbackoff
cat README.md
```

**Follow the pattern:**
1. Read the README to understand the scenario
2. Run `./break.sh` to introduce the issue
3. Troubleshoot using kubectl commands
4. Try to fix it yourself
5. Check `./fix.sh` if you need help
6. Run `./verify.sh` to confirm the fix
7. Run `./reset.sh` to restore baseline

---

## Quick Reference Commands

### Cluster Management

```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes

# View all resources
kubectl get all -A
```

### Application Management

```bash
# View application
kubectl get all -n taskmaster
kubectl get pods -n taskmaster

# View logs
kubectl logs -n taskmaster -l app=backend
kubectl logs -n taskmaster -l app=frontend
kubectl logs -n taskmaster -l app=postgres

# Check events
kubectl get events -n taskmaster
```

### Troubleshooting

```bash
# Describe resources
kubectl describe pod <pod-name> -n taskmaster
kubectl describe deployment <name> -n taskmaster

# Execute in pod
kubectl exec -it <pod-name> -n taskmaster -- /bin/sh

# Port forward for testing
kubectl port-forward -n taskmaster svc/backend-svc 5000:5000
```

---

## Workshop Structure

```
15 Exercises Total:
├── 01-05: Basic (CrashLoopBackOff, ImagePullBackOff, Services, ConfigMaps, Secrets)
├── 06-10: Medium (OOM, Probes, Storage, DNS)
└── 11-15: Medium (Ingress, RBAC, NetworkPolicy, Node Pressure, Rollouts)

Estimated Time: 15-35 minutes per exercise
```

---

## Common Issues & Solutions

### Issue: Cluster won't install

```bash
# Check system resources
free -h
df -h

# Check if swap is disabled
swapon --show

# View logs
sudo journalctl -u kubelet -f
sudo journalctl -u containerd -f
```

### Issue: Pods not starting

```bash
# Check pod status
kubectl get pods -n taskmaster
kubectl describe pod <pod-name> -n taskmaster

# Check events
kubectl get events -n taskmaster

# View logs
kubectl logs -n taskmaster <pod-name>
```

### Issue: Dashboard not loading

```bash
# Check /etc/hosts entry
cat /etc/hosts | grep taskmaster

# Check ingress
kubectl get ingress -n taskmaster

# Check services
kubectl get svc -n taskmaster
```

### Issue: Images not pulling

```bash
# Check image pull status
kubectl describe pod <pod-name> -n taskmaster

# Images should pull from:
# - docker.io/reddydodda/taskmaster-frontend:1.0
# - docker.io/reddydodda/taskmaster-backend:1.0
```

---

## Cleanup

### Remove Application Only

```bash
cd baseline-app
./destroy-baseline.sh
```

### Remove Everything (Cluster + App)

```bash
cd setup
sudo ./uninstall-cluster.sh
```

---

## Next Steps

After completing the quick start:

1. ✅ **Explore the dashboard** - Add tasks, check status
2. ✅ **Start Exercise 01** - Learn CrashLoopBackOff debugging
3. ✅ **Progress through exercises** - Build troubleshooting skills
4. ✅ **Master kubectl** - Learn essential commands
5. ✅ **Understand Kubernetes** - Pods, Services, Deployments, Ingress

---

## Workshop Timeline

```
Hour 0-1:   Cluster setup + Application deployment
Hour 1-2:   Exercises 01-03 (Basic pod issues)
Hour 2-4:   Exercises 04-08 (Configs, resources, probes)
Hour 4-6:   Exercises 09-12 (Storage, DNS, networking)
Hour 6-8:   Exercises 13-15 (Advanced topics)
Hour 8-10:  Review and practice
```

---

## Getting Help

- **Check logs:** `/tmp/k8s-workshop-*.log`
- **Review docs:** `README.md`, `IMPLEMENTATION-STATUS.md`
- **Verify setup:** Run verify scripts in each directory
- **Reset if needed:** Use `./reset.sh` in exercises

---

## Success Indicators

✅ Cluster: `kubectl get nodes` shows "Ready"
✅ App: All pods in "Running" state
✅ Dashboard: Green status for all services
✅ Network: Can access http://taskmaster.local
✅ Ready: Can break and fix applications

---

**You're all set! Start learning Kubernetes! 🚀**

For detailed information, see:
- `README.md` - Complete workshop guide
- `IMPLEMENTATION-STATUS.md` - Current status
- `setup/README.md` - Setup details
- `exercises/*/README.md` - Exercise guides
