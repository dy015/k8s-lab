# Common Issues and FAQ

## Overview

This document provides solutions to common issues you may encounter during the Kubernetes Break & Fix Workshop. Issues are organized by category for quick reference.

## Quick Troubleshooting Index

- [Cluster Setup Issues](#cluster-setup-issues)
- [Application Deployment Issues](#application-deployment-issues)
- [Exercise-Specific Problems](#exercise-specific-problems)
- [Environment Issues](#environment-issues)
- [Network and Connectivity Issues](#network-and-connectivity-issues)
- [Storage Issues](#storage-issues)
- [Performance Issues](#performance-issues)
- [Recovery Procedures](#recovery-procedures)

---

## Cluster Setup Issues

### Issue: k3s Installation Fails

**Symptom:**
```
Error: Failed to download k3s binary
```

**Cause:** Network connectivity or repository access issues

**Solution:**
```bash
# Check internet connectivity
ping -c 3 get.k3s.io

# Check if firewall is blocking
sudo systemctl status firewalld
sudo firewall-cmd --list-all

# Retry installation
cd setup
sudo ./00-install-cluster.sh
```

**Prevention:** Ensure stable internet connection before starting

---

### Issue: kubectl Command Not Found

**Symptom:**
```
bash: kubectl: command not found
```

**Cause:** k3s kubectl symlink not in PATH or not created

**Solution:**
```bash
# Create symlink manually
sudo ln -s /usr/local/bin/k3s /usr/local/bin/kubectl

# Or add to PATH
export PATH=$PATH:/usr/local/bin

# Add to .bashrc for persistence
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc

# Verify
kubectl version
```

---

### Issue: Permission Denied When Running kubectl

**Symptom:**
```
error: error loading config file "/etc/rancher/k3s/k3s.yaml": open /etc/rancher/k3s/k3s.yaml: permission denied
```

**Cause:** KUBECONFIG file not readable by current user

**Solution:**
```bash
# Option 1: Copy kubeconfig to user directory (recommended)
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(whoami):$(whoami) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Option 2: Run with sudo (not recommended for learning)
sudo kubectl get nodes

# Option 3: Add user to appropriate group
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```

---

### Issue: Node Shows NotReady

**Symptom:**
```bash
kubectl get nodes
NAME    STATUS     ROLES                  AGE   VERSION
node1   NotReady   control-plane,master   5m    v1.28.0+k3s1
```

**Cause:** Container runtime not started, network plugin issue, or resource constraints

**Solution:**
```bash
# Check k3s service status
sudo systemctl status k3s

# Restart k3s if needed
sudo systemctl restart k3s

# Check node conditions
kubectl describe node <node-name> | grep -A 10 Conditions

# Check system resources
free -h
df -h

# Check for errors in k3s logs
sudo journalctl -u k3s -f
```

**Wait:** Node may take 30-60 seconds to become Ready after k3s starts

---

### Issue: CoreDNS Pods Not Running

**Symptom:**
```bash
kubectl get pods -n kube-system
NAME                     READY   STATUS    RESTARTS   AGE
coredns-xxx              0/1     Pending   0          5m
```

**Cause:** Insufficient resources or scheduling issues

**Solution:**
```bash
# Check pod events
kubectl describe pod -n kube-system <coredns-pod-name>

# Check node resources
kubectl top nodes
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# Force delete and recreate
kubectl delete pod -n kube-system <coredns-pod-name>

# If persistent, check k3s installation
sudo systemctl restart k3s
```

---

## Application Deployment Issues

### Issue: Images Won't Pull from Docker Hub

**Symptom:**
```
Failed to pull image "docker.io/reddydodda/taskmaster-backend:1.0":
rpc error: code = Unknown desc = failed to pull and unpack image
```

**Cause:** Docker Hub rate limiting, network issues, or wrong image name

**Solution:**
```bash
# Verify image exists
curl -s https://hub.docker.com/v2/repositories/reddydodda/taskmaster-backend/tags | grep '"name"'

# Pull manually to test
sudo k3s crictl pull docker.io/reddydodda/taskmaster-backend:1.0

# Check if it's rate limiting
kubectl describe pod <pod-name> -n taskmaster | grep -i "rate"

# Wait and retry (rate limit resets)
kubectl delete pod <pod-name> -n taskmaster

# Use image pull secrets if needed (usually not required for public images)
```

**Prevention:** Don't delete and recreate pods unnecessarily

---

### Issue: All Pods Stuck in ContainerCreating

**Symptom:**
```
NAME                       READY   STATUS              RESTARTS   AGE
backend-xxx                0/1     ContainerCreating   0          5m
frontend-xxx               0/1     ContainerCreating   0          5m
postgres-xxx               0/1     ContainerCreating   0          5m
```

**Cause:** CNI plugin issue, storage provisioner not ready, or resource constraints

**Solution:**
```bash
# Check specific pod events
kubectl describe pod <pod-name> -n taskmaster

# Check CNI pods
kubectl get pods -n kube-system | grep -E "flannel|cni"

# Check local-path-provisioner
kubectl get pods -n kube-system | grep local-path

# Restart k3s if CNI issue
sudo systemctl restart k3s

# Wait a few minutes for recovery
kubectl get pods -n taskmaster -w
```

---

### Issue: Namespace Stuck in Terminating

**Symptom:**
```bash
kubectl get ns taskmaster
NAME         STATUS        AGE
taskmaster   Terminating   10m
```

**Cause:** Resources with finalizers preventing deletion

**Solution:**
```bash
# Force delete namespace (use with caution)
kubectl delete namespace taskmaster --grace-period=0 --force

# Or remove finalizers
kubectl get namespace taskmaster -o json | \
  jq '.spec.finalizers = []' | \
  kubectl replace --raw "/api/v1/namespaces/taskmaster/finalize" -f -

# Recreate namespace
kubectl create namespace taskmaster
```

**Prevention:** Always clean up resources properly before deleting namespace

---

### Issue: Deployment Rollout Stuck

**Symptom:**
```bash
kubectl rollout status deployment/backend -n taskmaster
Waiting for deployment "backend" rollout to finish: 0 of 2 updated replicas are available...
```

**Cause:** Pods failing to start, resource limits, or readiness probe failures

**Solution:**
```bash
# Check rollout status details
kubectl rollout status deployment/backend -n taskmaster

# Check new pods
kubectl get pods -n taskmaster

# Describe failing pods
kubectl describe pod <new-pod-name> -n taskmaster

# Check logs
kubectl logs <new-pod-name> -n taskmaster

# If bad update, rollback
kubectl rollout undo deployment/backend -n taskmaster

# If needed, pause rollout to investigate
kubectl rollout pause deployment/backend -n taskmaster
```

---

## Exercise-Specific Problems

### Exercise 01: CrashLoopBackOff

**Issue:** Can't find the error in logs

**Solution:**
```bash
# Check previous container logs
kubectl logs <pod-name> -n taskmaster --previous

# Look for the command error
kubectl describe pod <pod-name> -n taskmaster | grep -A 10 "Last State"

# Check deployment command
kubectl get deployment backend -n taskmaster -o yaml | grep -A 5 command
```

---

### Exercise 02: ImagePullBackOff

**Issue:** Pod still shows ImagePullBackOff after fixing image tag

**Solution:**
```bash
# Delete pod to retry with new configuration
kubectl delete pod <pod-name> -n taskmaster

# Or rollout restart
kubectl rollout restart deployment/backend -n taskmaster

# Verify new image tag
kubectl describe deployment backend -n taskmaster | grep Image
```

---

### Exercise 03: Service Unreachable

**Issue:** Can't figure out why service has no endpoints

**Solution:**
```bash
# Compare service selector with pod labels
kubectl get svc backend-svc -n taskmaster -o yaml | grep -A 3 selector
kubectl get pods -n taskmaster -l app=backend --show-labels

# Common mistake: typo in label or selector
# Look for: app=backend vs app=backends
```

---

### Exercise 04: ConfigMap Missing

**Issue:** Can't remember ConfigMap contents

**Solution:**
```bash
# Check what the deployment expects
kubectl get deployment backend -n taskmaster -o yaml | grep -A 10 configMapRef

# Check baseline manifests
cat baseline-app/manifests/backend-configmap.yaml

# Recreate with correct values
kubectl create configmap backend-config -n taskmaster \
  --from-literal=FLASK_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=WORKERS=2
```

---

### Exercise 05: Secret Missing

**Issue:** Don't know what values to put in Secret

**Solution:**
```bash
# Check baseline manifests
cat baseline-app/manifests/backend-secret.yaml

# Recreate backend-secret
kubectl create secret generic backend-secret -n taskmaster \
  --from-literal=DB_HOST=postgres-svc \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=taskmaster
```

---

### Exercise 06: OOM Killed

**Issue:** Pod still getting killed after increasing memory

**Solution:**
```bash
# Check if deployment was updated
kubectl get deployment backend -n taskmaster -o yaml | grep -A 5 resources

# Verify new pods have new limits
kubectl describe pod <new-pod-name> -n taskmaster | grep -A 5 Limits

# Check actual memory usage
kubectl top pod <pod-name> -n taskmaster

# May need higher limits
kubectl set resources deployment backend -n taskmaster \
  --limits=memory=1Gi --requests=memory=512Mi
```

---

### Exercise 10: DNS Not Working

**Issue:** CoreDNS won't scale back up

**Solution:**
```bash
# Force delete CoreDNS pods
kubectl delete pods -n kube-system -l k8s-app=kube-dns

# Scale deployment
kubectl scale deployment coredns -n kube-system --replicas=2

# Check status
kubectl get pods -n kube-system -l k8s-app=kube-dns

# If still failing, restart k3s
sudo systemctl restart k3s
```

---

### Exercise 11: Ingress 404

**Issue:** Still getting 404 after fixing ingress paths

**Solution:**
```bash
# Check ingress configuration
kubectl get ingress taskmaster-ingress -n taskmaster -o yaml

# Verify ingress controller processed changes
kubectl logs -n kube-system -l app.kubernetes.io/name=nginx-ingress

# Delete ingress and recreate
kubectl delete ingress taskmaster-ingress -n taskmaster
kubectl apply -f fixed-ingress.yaml

# Test with curl
curl -H "Host: taskmaster.local" http://<node-ip>/
curl -H "Host: taskmaster.local" http://<node-ip>/api/health
```

---

### Exercise 12: RBAC Forbidden

**Issue:** Role and RoleBinding created but still forbidden

**Solution:**
```bash
# Verify role exists
kubectl get role -n taskmaster

# Verify rolebinding exists
kubectl get rolebinding -n taskmaster

# Check if they're linked correctly
kubectl describe rolebinding <name> -n taskmaster

# Test permissions
kubectl auth can-i list pods --as=system:serviceaccount:taskmaster:<sa-name> -n taskmaster

# Delete and recreate if needed
kubectl delete role,rolebinding <name> -n taskmaster
```

---

## Environment Issues

### Issue: Can't Access http://taskmaster.local

**Symptom:**
Browser shows "This site can't be reached" or "Server not found"

**Cause:** Missing /etc/hosts entry or wrong IP address

**Solution:**

**On your local machine (not the VM):**

```bash
# Get VM IP address (run on VM)
kubectl get nodes -o wide
# Note the INTERNAL-IP

# Add to /etc/hosts (on your local machine)
# Linux/Mac:
sudo nano /etc/hosts
# Add this line:
192.168.1.100  taskmaster.local

# Windows:
# Edit C:\Windows\System32\drivers\etc\hosts as Administrator
# Add:
192.168.1.100  taskmaster.local

# Verify DNS resolution (on local machine)
ping taskmaster.local
nslookup taskmaster.local
```

**Test:**
```bash
curl http://taskmaster.local
# Should return HTML
```

---

### Issue: Dashboard Shows But API Fails

**Symptom:**
Frontend loads but "Backend: Unreachable" in red

**Cause:** Backend pods not running or service misconfigured

**Solution:**
```bash
# Check backend pods
kubectl get pods -n taskmaster -l app=backend

# Check backend service
kubectl get svc backend-svc -n taskmaster
kubectl get endpoints backend-svc -n taskmaster

# Test backend from frontend pod
kubectl exec -it <frontend-pod> -n taskmaster -- wget -qO- http://backend-svc:5000/api/health

# Check ingress routing
kubectl describe ingress taskmaster-ingress -n taskmaster

# Check backend logs
kubectl logs -n taskmaster -l app=backend
```

---

### Issue: Port 80 Already in Use

**Symptom:**
```
Error: port 80 is already allocated
```

**Cause:** Another service using port 80 (Apache, nginx, etc.)

**Solution:**
```bash
# Check what's using port 80
sudo netstat -tlnp | grep :80
sudo lsof -i :80

# Stop conflicting service
sudo systemctl stop httpd
sudo systemctl stop nginx
sudo systemctl disable httpd
sudo systemctl disable nginx

# Verify port is free
sudo netstat -tlnp | grep :80

# Restart k3s
sudo systemctl restart k3s
```

---

### Issue: SELinux Blocking Operations

**Symptom:**
Pods fail with permission errors in logs

**Cause:** SELinux enforcing mode blocking container operations

**Solution:**
```bash
# Check SELinux status
getenforce

# Temporary: Set to permissive
sudo setenforce 0

# Permanent: Disable in config
sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

# Verify
getenforce

# Reboot for permanent change (if needed)
sudo reboot
```

**Note:** In production, configure proper SELinux policies instead of disabling

---

### Issue: Firewall Blocking Access

**Symptom:**
Can access from VM but not from local machine

**Cause:** Firewall blocking ports 80, 443

**Solution:**
```bash
# Check firewall status
sudo systemctl status firewalld

# Allow HTTP and HTTPS
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=6443/tcp  # K8s API
sudo firewall-cmd --reload

# Verify rules
sudo firewall-cmd --list-all

# Or disable firewall (not recommended for production)
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

---

## Network and Connectivity Issues

### Issue: Pods Can't Communicate

**Symptom:**
Pod-to-pod networking fails, DNS works

**Cause:** Network policy blocking traffic or CNI plugin issue

**Solution:**
```bash
# Check network policies
kubectl get networkpolicy -n taskmaster

# Delete restrictive policies (if learning)
kubectl delete networkpolicy <policy-name> -n taskmaster

# Test pod-to-pod connectivity
kubectl exec <pod1> -n taskmaster -- ping <pod2-ip>

# Check flannel pods
kubectl get pods -n kube-system | grep flannel

# Restart flannel if needed
kubectl delete pods -n kube-system -l app=flannel
```

---

### Issue: DNS Resolution Fails

**Symptom:**
```
wget: bad address 'backend-svc'
nslookup: can't resolve 'backend-svc'
```

**Cause:** CoreDNS not running or pod DNS configuration wrong

**Solution:**
```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Verify CoreDNS service
kubectl get svc -n kube-system kube-dns

# Check pod DNS config
kubectl exec <pod> -n taskmaster -- cat /etc/resolv.conf

# Should show:
# nameserver 10.43.0.10
# search taskmaster.svc.cluster.local svc.cluster.local cluster.local

# Restart CoreDNS if needed
kubectl rollout restart deployment coredns -n kube-system
```

---

### Issue: Ingress Returns 503 Service Unavailable

**Symptom:**
Browser shows 503 error when accessing application

**Cause:** Backend service has no ready endpoints

**Solution:**
```bash
# Check service endpoints
kubectl get endpoints -n taskmaster

# If no endpoints, check pods
kubectl get pods -n taskmaster

# Check readiness probes
kubectl describe pod <pod-name> -n taskmaster | grep -A 10 Readiness

# Fix pods first, then ingress will work
```

---

## Storage Issues

### Issue: PVC Stuck in Pending

**Symptom:**
```bash
kubectl get pvc -n taskmaster
NAME           STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
postgres-pvc   Pending                                      local-path     5m
```

**Cause:** Local-path-provisioner not running or storage not available

**Solution:**
```bash
# Check local-path-provisioner
kubectl get pods -n kube-system | grep local-path

# Check provisioner logs
kubectl logs -n kube-system -l app=local-path-provisioner

# Check node storage
df -h /var/lib/rancher/k3s/storage

# If provisioner not running, restart k3s
sudo systemctl restart k3s

# Delete and recreate PVC if needed
kubectl delete pvc postgres-pvc -n taskmaster
kubectl apply -f baseline-app/manifests/postgres-pvc.yaml
```

---

### Issue: Pod Fails with "Volume Already Mounted"

**Symptom:**
```
Error: Volume is already exclusively attached to one node and can't be attached to another
```

**Cause:** PVC with ReadWriteOnce still attached to deleted pod

**Solution:**
```bash
# Force delete old pod
kubectl delete pod <old-pod-name> -n taskmaster --force --grace-period=0

# Wait for volume to detach (30-60 seconds)
sleep 60

# New pod should start
kubectl get pods -n taskmaster -w
```

---

### Issue: Data Lost After Pod Restart

**Symptom:**
Database empty after restarting PostgreSQL pod

**Cause:** PVC not mounted or wrong mount path

**Solution:**
```bash
# Check if PVC is bound
kubectl get pvc -n taskmaster

# Check pod volume mounts
kubectl describe pod <postgres-pod> -n taskmaster | grep -A 10 Mounts

# Should show:
# /var/lib/postgresql/data from postgres-storage

# Verify volume in pod spec
kubectl get pod <postgres-pod> -n taskmaster -o yaml | grep -A 10 volumes

# If misconfigured, fix deployment
kubectl edit deployment postgres -n taskmaster
```

---

## Performance Issues

### Issue: Pods Using Too Much Memory

**Symptom:**
```bash
kubectl top pods -n taskmaster
NAME         CPU    MEMORY
backend-xxx  100m   800Mi
```

**Cause:** Memory leak, inefficient code, or too many requests

**Solution:**
```bash
# Increase memory limits
kubectl set resources deployment backend -n taskmaster \
  --limits=memory=1Gi --requests=memory=512Mi

# Check for memory leak
kubectl logs <pod> -n taskmaster | grep -i "memory\|oom"

# Monitor over time
watch kubectl top pods -n taskmaster

# Restart pod to clear memory
kubectl delete pod <pod> -n taskmaster
```

---

### Issue: Slow Application Response

**Symptom:**
Dashboard takes 10+ seconds to load

**Cause:** Insufficient resources, database slow, or network latency

**Solution:**
```bash
# Check resource usage
kubectl top pods -n taskmaster
kubectl top nodes

# Check pod events for throttling
kubectl describe pod <pod> -n taskmaster | grep -i throttl

# Increase CPU limits
kubectl set resources deployment backend -n taskmaster \
  --limits=cpu=1000m --requests=cpu=500m

# Check database performance
kubectl logs -n taskmaster -l app=postgres | grep -i slow

# Scale up replicas
kubectl scale deployment backend -n taskmaster --replicas=3
```

---

### Issue: Node Running Out of Resources

**Symptom:**
```bash
kubectl describe node <node> | grep Pressure
MemoryPressure   True
DiskPressure     True
```

**Cause:** Too many pods, insufficient node resources

**Solution:**
```bash
# Check node resources
kubectl top node

# List all pods on node
kubectl get pods -A -o wide | grep <node-name>

# Remove unused pods
kubectl delete pod <unused-pod> -n <namespace>

# Clean up disk space
sudo docker system prune -a -f
sudo k3s crictl rmi --prune

# Check disk usage
df -h
```

---

## Recovery Procedures

### Complete Application Reset

**When:** Application is completely broken and you want to start fresh

**Procedure:**
```bash
# 1. Destroy current deployment
cd baseline-app
./destroy-baseline.sh

# 2. Wait for cleanup
kubectl get all -n taskmaster
# Should show: No resources found

# 3. Redeploy
./00-deploy-baseline.sh

# 4. Verify
./verify-baseline.sh

# 5. Access dashboard
# http://taskmaster.local
```

---

### Cluster Reset (Nuclear Option)

**When:** Cluster is completely broken

**Procedure:**
```bash
# 1. Uninstall k3s
cd setup
sudo ./uninstall-cluster.sh

# 2. Clean up remaining files
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s

# 3. Reinstall cluster
sudo ./00-install-cluster.sh

# 4. Verify cluster
./verify-cluster.sh

# 5. Redeploy application
cd ../baseline-app
./00-deploy-baseline.sh
```

**Warning:** This deletes everything. Use as last resort.

---

### Reset Single Exercise

**When:** Exercise is stuck and you want to retry

**Procedure:**
```bash
cd exercises/<exercise-number>

# Reset to baseline
./reset.sh

# Verify application works
cd ../../baseline-app
./verify-baseline.sh

# Try exercise again
cd ../exercises/<exercise-number>
./break.sh
```

---

### Recover Deleted Resources

**When:** Accidentally deleted important resources

**Procedure:**
```bash
# Recreate from baseline manifests
cd baseline-app/manifests

# Recreate ConfigMap
kubectl apply -f backend-configmap.yaml

# Recreate Secret
kubectl apply -f backend-secret.yaml
kubectl apply -f database-secret.yaml

# Recreate Services
kubectl apply -f frontend-service.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f postgres-service.yaml

# Recreate Deployments (last)
kubectl apply -f frontend-deployment.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f postgres-deployment.yaml
```

---

## Prevention Best Practices

### Before Starting Exercises

1. **Verify baseline is healthy:**
```bash
cd baseline-app
./verify-baseline.sh
```

2. **Access dashboard to confirm it works:**
```
http://taskmaster.local
```

3. **Take note of healthy state:**
```bash
kubectl get all -n taskmaster
kubectl get pods -n taskmaster -o wide
```

---

### During Exercises

1. **Always read the README first**
2. **Take notes of what you change**
3. **Use verify.sh after fixing**
4. **Use reset.sh before next exercise**

---

### General Tips

1. **Use namespace flag:** Always include `-n taskmaster` to avoid affecting other namespaces
2. **Don't skip verification:** Run verify scripts to confirm fixes
3. **Check logs first:** Most issues show up in pod logs
4. **Read events:** Events explain what happened chronologically
5. **One change at a time:** Don't fix multiple things simultaneously
6. **Wait for pods:** Give pods 30-60 seconds to stabilize after changes

---

## Getting Help

### Debug Information to Collect

When asking for help, provide:

```bash
# 1. Cluster info
kubectl version
kubectl get nodes

# 2. Pod status
kubectl get pods -n taskmaster -o wide

# 3. Pod details
kubectl describe pod <problematic-pod> -n taskmaster

# 4. Logs
kubectl logs <pod> -n taskmaster --tail=50

# 5. Events
kubectl get events -n taskmaster --sort-by='.lastTimestamp' | tail -20

# 6. Resource usage
kubectl top nodes
kubectl top pods -n taskmaster
```

### Log Files

Workshop scripts log to:
```bash
/tmp/k8s-workshop-*.log
```

View latest log:
```bash
tail -f $(ls -t /tmp/k8s-workshop-*.log | head -1)
```

### Documentation References

- [Troubleshooting Guide](03-troubleshooting-guide.md) - Systematic troubleshooting methodology
- [kubectl Cheatsheet](04-kubectl-cheatsheet.md) - Command reference
- [Cluster Architecture](01-cluster-architecture.md) - How the cluster works
- [Application Architecture](02-application-architecture.md) - How the app works

---

## Quick Diagnostic Commands

### Is Everything Working?

```bash
# One-liner health check
kubectl get pods -n taskmaster && \
kubectl get svc -n taskmaster && \
kubectl get ingress -n taskmaster && \
curl -s http://taskmaster.local/api/health
```

### What's Broken?

```bash
# Find non-running pods
kubectl get pods -A --field-selector=status.phase!=Running

# Find recent errors
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -10

# Find pods with restarts
kubectl get pods -n taskmaster -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '$2 > 0'
```

### Resource Status

```bash
# Overall cluster health
kubectl get nodes && \
kubectl get pods -A | grep -v Running | grep -v Completed && \
kubectl top nodes
```

---

## Common Error Messages Explained

| Error Message | Meaning | Solution |
|--------------|---------|----------|
| CrashLoopBackOff | Container keeps crashing | Check logs, fix app or config |
| ImagePullBackOff | Can't download image | Fix image name/tag |
| CreateContainerConfigError | Missing ConfigMap/Secret | Create missing resource |
| ErrImagePull | Image not found | Verify image exists |
| Pending | Can't schedule pod | Check resources, node status |
| OOMKilled | Out of memory | Increase memory limits |
| Evicted | Pod evicted by kubelet | Check node pressure, resources |
| Error | Generic error | Read describe output |
| InvalidImageName | Bad image format | Fix image name syntax |
| RunContainerError | Can't start container | Check runtime, permissions |

---

**Remember:** Most issues can be solved by reading pod events and logs carefully. When in doubt, describe the pod and read the events section!

For more detailed troubleshooting, see [Troubleshooting Guide](03-troubleshooting-guide.md).
