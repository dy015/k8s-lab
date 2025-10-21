# Kubernetes Troubleshooting Guide

## Overview

This guide provides a systematic approach to troubleshooting Kubernetes applications. Use this methodology when diagnosing issues in the workshop or in production environments.

## Troubleshooting Methodology

### The 5-Step Approach

```
1. Observe   → What are the symptoms?
2. Gather    → Collect relevant information
3. Analyze   → Identify the root cause
4. Fix       → Apply the solution
5. Verify    → Confirm it's resolved
```

#### Step 1: Observe

Ask yourself:
- What is NOT working?
- What error messages do I see?
- Which components are affected?
- When did it stop working?
- What changed recently?

#### Step 2: Gather

Collect information systematically:
- Pod status and events
- Container logs
- Resource descriptions
- Service endpoints
- Network connectivity

#### Step 3: Analyze

Look for patterns:
- Error messages in logs
- Event timestamps
- Resource states
- Configuration mismatches

#### Step 4: Fix

Apply the appropriate solution:
- Edit resources
- Recreate objects
- Adjust configurations
- Scale resources

#### Step 5: Verify

Confirm the fix:
- Pods running and ready
- Services accessible
- Application functional
- No error logs

## Troubleshooting by Component

### Pod Issues

#### Pod Won't Start

**Symptoms:**
- Pod stuck in Pending, ContainerCreating, or Error state
- Application not accessible

**Investigation Steps:**

1. **Check pod status:**
```bash
kubectl get pods -n taskmaster
```

2. **Get detailed information:**
```bash
kubectl describe pod <pod-name> -n taskmaster
```

3. **Look for:**
- Events section (bottom of output)
- Container states
- Conditions
- Resource requests vs available

**Common Causes:**

| Status | Cause | Solution |
|--------|-------|----------|
| Pending | Insufficient resources | Check node resources, adjust limits |
| Pending | PVC not bound | Check PVC status, verify storage class |
| ContainerCreating | Image pull issues | Verify image name, check credentials |
| ContainerCreating | ConfigMap/Secret missing | Recreate missing resources |
| CrashLoopBackOff | Application crashes | Check logs, fix configuration |
| ImagePullBackOff | Image not found | Fix image name/tag |
| CreateContainerConfigError | Missing ConfigMap/Secret | Create the missing resource |

#### Pod Running But Not Ready

**Symptoms:**
- Pod in Running state
- READY shows 0/1
- Service not routing traffic to pod

**Investigation:**

```bash
# Check readiness probe status
kubectl describe pod <pod-name> -n taskmaster

# Look for:
# - Readiness probe failures
# - Probe configuration
# - Container logs
```

**Common Causes:**
- Readiness probe failing
- Application not fully started
- Wrong probe endpoint/port
- Probe timeout too short

**Solution:**
```bash
# Check logs for startup issues
kubectl logs <pod-name> -n taskmaster

# Adjust probe timing if needed
kubectl edit deployment <name> -n taskmaster
```

#### Pod Keeps Restarting

**Symptoms:**
- High restart count
- CrashLoopBackOff status
- Application intermittently unavailable

**Investigation:**

```bash
# Check restart count and status
kubectl get pods -n taskmaster

# View logs from current container
kubectl logs <pod-name> -n taskmaster

# View logs from previous crash
kubectl logs <pod-name> -n taskmaster --previous

# Check resource usage
kubectl top pod <pod-name> -n taskmaster
```

**Common Causes:**
- Application crashes (code bugs)
- OOM (Out of Memory) killed
- Liveness probe failures
- Resource limits too low

**Exit Code Meanings:**
- **0**: Normal exit
- **1**: Application error
- **137**: OOM killed (128 + 9)
- **143**: Terminated (128 + 15)

### Service Issues

#### Service Unreachable

**Symptoms:**
- Cannot connect to service
- Connection timeouts
- DNS resolution fails

**Investigation:**

```bash
# Check service exists
kubectl get svc -n taskmaster

# Check service endpoints
kubectl get endpoints <service-name> -n taskmaster

# Describe service
kubectl describe svc <service-name> -n taskmaster
```

**Diagnostics:**

1. **No endpoints:**
```bash
# Service selector doesn't match any pods
kubectl get pods -n taskmaster --show-labels
kubectl describe svc <service-name> -n taskmaster | grep Selector
```

2. **Test connectivity from another pod:**
```bash
# Get a shell in a pod
kubectl exec -it <pod-name> -n taskmaster -- /bin/sh

# Test service connectivity
wget -qO- http://<service-name>:<port>/health
curl http://<service-name>:<port>/health
```

3. **Check DNS resolution:**
```bash
# From within a pod
nslookup <service-name>
nslookup <service-name>.taskmaster.svc.cluster.local
```

**Common Causes:**
- Service selector doesn't match pod labels
- No pods running with matching labels
- Wrong port configuration
- DNS not working

**Solution Example:**
```bash
# Check pod labels
kubectl get pods -n taskmaster -l app=backend --show-labels

# Check service selector
kubectl get svc backend-svc -n taskmaster -o yaml | grep -A 5 selector

# If mismatch, edit service
kubectl edit svc backend-svc -n taskmaster
```

### Network Troubleshooting

#### Pod-to-Pod Communication

**Test basic connectivity:**

```bash
# Get pod IPs
kubectl get pods -n taskmaster -o wide

# Test from one pod to another
kubectl exec <source-pod> -n taskmaster -- ping <target-pod-ip>

# Test service port
kubectl exec <source-pod> -n taskmaster -- wget -qO- http://<target-pod-ip>:port
```

#### DNS Resolution

**Check DNS is working:**

```bash
# Verify CoreDNS pods are running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS from a pod
kubectl exec <pod-name> -n taskmaster -- nslookup kubernetes.default

# Test service DNS
kubectl exec <pod-name> -n taskmaster -- nslookup backend-svc.taskmaster.svc.cluster.local
```

**DNS Troubleshooting:**

```bash
# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Verify CoreDNS service
kubectl get svc -n kube-system kube-dns

# Check pod DNS configuration
kubectl exec <pod-name> -n taskmaster -- cat /etc/resolv.conf
```

#### Network Policy Issues

**Symptoms:**
- Connection refused or timeout
- Works from some pods but not others
- Specific ports blocked

**Investigation:**

```bash
# List network policies
kubectl get networkpolicy -n taskmaster

# Describe network policy
kubectl describe networkpolicy <policy-name> -n taskmaster

# Check policy selectors
kubectl get networkpolicy -n taskmaster -o yaml
```

**Test connectivity:**
```bash
# From allowed pod (should work)
kubectl exec <allowed-pod> -n taskmaster -- wget -qO- http://backend-svc:5000

# From blocked pod (should fail)
kubectl exec <blocked-pod> -n taskmaster -- wget -qO- http://backend-svc:5000
```

### Storage Troubleshooting

#### PVC Stuck in Pending

**Symptoms:**
- PersistentVolumeClaim in Pending state
- Pod stuck in ContainerCreating
- "FailedAttachVolume" or "FailedMount" events

**Investigation:**

```bash
# Check PVC status
kubectl get pvc -n taskmaster

# Describe PVC
kubectl describe pvc <pvc-name> -n taskmaster

# Check storage classes
kubectl get storageclass

# Check PV availability
kubectl get pv
```

**Common Causes:**
- No storage class defined
- Storage class doesn't exist
- Insufficient storage available
- Access mode mismatch
- Node selector issues (local storage)

**Solution:**
```bash
# Verify storage class
kubectl get storageclass local-path -o yaml

# Check node storage
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# If local-path provisioner issue
kubectl get pods -n kube-system -l app=local-path-provisioner
```

#### PVC Won't Delete

**Symptoms:**
- PVC stuck in Terminating state
- Delete command hangs

**Investigation:**

```bash
# Check if pod is still using it
kubectl get pods -n taskmaster -o yaml | grep -B 5 <pvc-name>

# Check finalizers
kubectl get pvc <pvc-name> -n taskmaster -o yaml | grep finalizers
```

**Solution:**
```bash
# Delete pods using the PVC first
kubectl delete pod <pod-name> -n taskmaster

# Then delete PVC
kubectl delete pvc <pvc-name> -n taskmaster

# If stuck, remove finalizer (use with caution)
kubectl patch pvc <pvc-name> -n taskmaster -p '{"metadata":{"finalizers":null}}'
```

### Configuration Issues

#### ConfigMap or Secret Missing

**Symptoms:**
- CreateContainerConfigError status
- Pods won't start
- Events mention missing ConfigMap or Secret

**Investigation:**

```bash
# List ConfigMaps
kubectl get configmap -n taskmaster

# List Secrets
kubectl get secret -n taskmaster

# Check what the deployment expects
kubectl get deployment <name> -n taskmaster -o yaml | grep -A 5 "configMapRef\|secretRef"
```

**Solution:**

Recreate the missing resource:

```bash
# ConfigMap example
kubectl create configmap backend-config -n taskmaster \
  --from-literal=FLASK_ENV=production \
  --from-literal=LOG_LEVEL=info

# Secret example
kubectl create secret generic backend-secret -n taskmaster \
  --from-literal=DB_HOST=postgres-svc \
  --from-literal=DB_PORT=5432
```

#### Configuration Validation

**Check syntax before applying:**

```bash
# Dry run to validate
kubectl apply -f manifest.yaml --dry-run=client

# Validate YAML syntax
kubectl apply -f manifest.yaml --validate=true --dry-run=server
```

### Resource Management

#### Out of Memory (OOM) Killed

**Symptoms:**
- Pod status: CrashLoopBackOff or OOMKilled
- High restart count
- Exit code 137

**Investigation:**

```bash
# Check pod status and exit code
kubectl describe pod <pod-name> -n taskmaster

# Look for:
# Last State: Terminated
#   Reason: OOMKilled
#   Exit Code: 137

# Check current resource usage
kubectl top pod <pod-name> -n taskmaster

# Check resource limits
kubectl get pod <pod-name> -n taskmaster -o yaml | grep -A 5 resources
```

**Solution:**

```bash
# Increase memory limits
kubectl set resources deployment <name> -n taskmaster \
  --limits=memory=1Gi \
  --requests=memory=512Mi

# Or edit deployment
kubectl edit deployment <name> -n taskmaster
```

#### CPU Throttling

**Symptoms:**
- Slow application performance
- High CPU usage at limit
- Request latency spikes

**Investigation:**

```bash
# Check CPU usage
kubectl top pods -n taskmaster

# Check CPU limits
kubectl describe pod <pod-name> -n taskmaster | grep -A 5 "Limits\|Requests"
```

**Solution:**
```bash
# Increase CPU limits
kubectl set resources deployment <name> -n taskmaster \
  --limits=cpu=1000m \
  --requests=cpu=500m
```

### Health Probe Issues

#### Liveness Probe Failures

**Symptoms:**
- Pods constantly restarting
- "Liveness probe failed" in events
- Application seems to work but keeps restarting

**Investigation:**

```bash
# Check probe configuration
kubectl describe pod <pod-name> -n taskmaster | grep -A 10 "Liveness"

# Check probe endpoint manually
kubectl exec <pod-name> -n taskmaster -- wget -qO- http://localhost:5000/api/health

# Check logs for errors during probe
kubectl logs <pod-name> -n taskmaster
```

**Common Issues:**
- Wrong endpoint path
- Wrong port
- Probe timeout too short
- initialDelaySeconds too small
- Application slow to start

**Solution:**
```bash
# Edit deployment to fix probe
kubectl edit deployment <name> -n taskmaster

# Adjust timing example:
livenessProbe:
  httpGet:
    path: /api/health
    port: 5000
  initialDelaySeconds: 30  # Increase if app is slow to start
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

#### Readiness Probe Failures

**Symptoms:**
- Pod Running but not Ready (0/1)
- Service doesn't route traffic to pod
- "Readiness probe failed" in events

**Solution:**
Similar to liveness probes - adjust timing or fix endpoint.

### Ingress Issues

#### Ingress Not Working

**Symptoms:**
- 404 errors when accessing application
- "Connection refused" from browser
- Can access services internally but not via ingress

**Investigation:**

```bash
# Check ingress resource
kubectl get ingress -n taskmaster

# Describe ingress
kubectl describe ingress <name> -n taskmaster

# Check ingress controller
kubectl get pods -n kube-system | grep ingress

# Check ingress controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=nginx-ingress
```

**Common Issues:**
- Wrong path configuration
- Wrong service backend
- Wrong port
- Ingress class not specified
- Ingress controller not running

**Test ingress routing:**
```bash
# Get node IP
kubectl get nodes -o wide

# Test with curl
curl -H "Host: taskmaster.local" http://<node-ip>/
curl -H "Host: taskmaster.local" http://<node-ip>/api/health
```

### RBAC Issues

#### Permission Denied / Forbidden

**Symptoms:**
- "Forbidden" errors
- "User cannot perform action" messages
- Operations fail with 403 status

**Investigation:**

```bash
# Check if ServiceAccount exists
kubectl get serviceaccount -n taskmaster

# Check roles and rolebindings
kubectl get role,rolebinding -n taskmaster

# Check what permissions a ServiceAccount has
kubectl auth can-i --list --as=system:serviceaccount:taskmaster:default -n taskmaster

# Test specific permission
kubectl auth can-i create pods --as=system:serviceaccount:taskmaster:myapp -n taskmaster
```

**Solution:**

Create necessary RBAC resources:

```bash
# Create role
kubectl create role pod-reader -n taskmaster \
  --verb=get,list,watch \
  --resource=pods

# Create rolebinding
kubectl create rolebinding pod-reader-binding -n taskmaster \
  --role=pod-reader \
  --serviceaccount=taskmaster:default
```

## Debugging Workflow by Symptom

### Application Not Accessible

```
1. Check ingress → kubectl get ingress -n taskmaster
2. Check frontend service → kubectl get svc frontend-svc -n taskmaster
3. Check frontend pods → kubectl get pods -n taskmaster -l app=frontend
4. Check pod logs → kubectl logs -n taskmaster -l app=frontend
5. Test from inside cluster → kubectl exec ... -- wget http://frontend-svc
```

### API Endpoints Failing

```
1. Check backend pods → kubectl get pods -n taskmaster -l app=backend
2. Check backend logs → kubectl logs -n taskmaster -l app=backend
3. Check database connection → kubectl logs -n taskmaster -l app=postgres
4. Check backend service → kubectl get svc backend-svc -n taskmaster
5. Test backend health → kubectl exec ... -- wget http://backend-svc:5000/api/health
```

### Database Issues

```
1. Check postgres pod → kubectl get pods -n taskmaster -l app=postgres
2. Check PVC → kubectl get pvc -n taskmaster
3. Check postgres logs → kubectl logs -n taskmaster -l app=postgres
4. Check secrets → kubectl get secret database-secret -n taskmaster
5. Test connection from backend → kubectl exec <backend-pod> -- pg_isready -h postgres-svc
```

## Event Interpretation

### Understanding Kubernetes Events

View events:
```bash
# All events in namespace
kubectl get events -n taskmaster

# Sorted by time
kubectl get events -n taskmaster --sort-by='.lastTimestamp'

# Watch events live
kubectl get events -n taskmaster -w

# Pod-specific events
kubectl describe pod <pod-name> -n taskmaster | grep -A 20 Events
```

### Common Event Messages

**Pod Events:**

| Event | Meaning | Action |
|-------|---------|--------|
| Scheduled | Pod assigned to node | Normal - wait for next steps |
| Pulling | Downloading container image | Normal - be patient |
| Pulled | Image downloaded | Normal - container will start |
| Created | Container created | Normal - starting soon |
| Started | Container running | Good - check readiness |
| BackOff | Container crashed, waiting to restart | Check logs and fix issue |
| Failed | Generic failure | Read message, check describe |
| FailedScheduling | Can't find node for pod | Check resources, taints |
| FailedMount | Can't mount volume | Check PVC, storage |
| Unhealthy | Probe failed | Fix probe or application |

**Image Events:**

| Event | Meaning | Action |
|-------|---------|--------|
| ErrImagePull | Can't download image | Check image name, credentials |
| ImagePullBackOff | Gave up pulling image | Fix image name or registry auth |
| ErrImageNeverPull | imagePullPolicy=Never but image not on node | Change policy or load image |

## Log Analysis

### Effective Log Viewing

**Basic log commands:**

```bash
# Current logs
kubectl logs <pod-name> -n taskmaster

# Follow logs (live stream)
kubectl logs -f <pod-name> -n taskmaster

# Previous container logs (after crash)
kubectl logs --previous <pod-name> -n taskmaster

# All pods with label
kubectl logs -n taskmaster -l app=backend

# Last N lines
kubectl logs <pod-name> -n taskmaster --tail=100

# Logs since timestamp
kubectl logs <pod-name> -n taskmaster --since=1h

# Specific container in multi-container pod
kubectl logs <pod-name> -c <container-name> -n taskmaster
```

### Log Patterns to Look For

**Application Errors:**
- Stack traces
- Exception messages
- "ERROR" or "FATAL" log levels
- Connection failures
- Timeout messages

**Configuration Issues:**
- "Missing environment variable"
- "Configuration file not found"
- "Invalid configuration"
- "Cannot connect to database"

**Resource Issues:**
- "Out of memory"
- "Cannot allocate memory"
- "Disk full"
- "No space left on device"

## Performance Troubleshooting

### Check Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources in namespace
kubectl top pods -n taskmaster

# Specific pod
kubectl top pod <pod-name> -n taskmaster

# Sort by CPU
kubectl top pods -n taskmaster --sort-by=cpu

# Sort by memory
kubectl top pods -n taskmaster --sort-by=memory
```

### Node Issues

**Check node health:**

```bash
# Node status
kubectl get nodes

# Node details
kubectl describe node <node-name>

# Look for:
# - Conditions (DiskPressure, MemoryPressure, PIDPressure)
# - Allocatable resources
# - Allocated resources
# - Events
```

**Common Node Issues:**

| Condition | Meaning | Action |
|-----------|---------|--------|
| DiskPressure | Node running out of disk | Clean up logs, images, volumes |
| MemoryPressure | Node low on memory | Delete pods or add resources |
| PIDPressure | Too many processes | Kill processes or add resources |
| NetworkUnavailable | Network not configured | Check CNI plugin |

## When to Restart vs Fix

### Safe to Restart

- Pod in CrashLoopBackOff (will restart anyway)
- Pod stuck after successful fix
- Need to reload configuration
- Testing changes

### Fix Without Restart

- Live configuration updates (ConfigMap/Secret changes may need restart)
- Service selector changes (immediate)
- Ingress rule updates (immediate)
- Resource limit increases (only new pods)

### How to Restart

```bash
# Delete pod (deployment will recreate)
kubectl delete pod <pod-name> -n taskmaster

# Rollout restart (graceful, all pods)
kubectl rollout restart deployment <name> -n taskmaster

# Scale to 0 and back (forceful)
kubectl scale deployment <name> -n taskmaster --replicas=0
kubectl scale deployment <name> -n taskmaster --replicas=2
```

## Prevention Strategies

### Proactive Monitoring

```bash
# Regular health checks
kubectl get pods -A
kubectl top nodes
kubectl top pods -A

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Watch for issues
watch kubectl get pods -A
```

### Configuration Best Practices

1. **Always set resource limits:**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

2. **Use health probes:**
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

3. **Label everything consistently:**
```yaml
labels:
  app: backend
  component: api
  version: v1.0
```

4. **Use namespaces:**
- Separate environments
- Isolate applications
- Apply policies

### Pre-deployment Validation

```bash
# Validate YAML syntax
kubectl apply -f manifest.yaml --dry-run=client

# Server-side validation
kubectl apply -f manifest.yaml --dry-run=server

# Diff before applying
kubectl diff -f manifest.yaml
```

## Quick Reference Tables

### kubectl Describe Sections

| Section | What to Look For |
|---------|------------------|
| Name | Resource name and namespace |
| Labels | Organization and selectors |
| Status | Current state |
| Controlled By | Owner (Deployment, ReplicaSet) |
| IP | Pod IP address |
| Containers | Container details and state |
| Conditions | Pod conditions (Ready, etc.) |
| Volumes | Mounted volumes and sources |
| Events | Chronological history |

### Common Port Numbers

| Service | Port | Protocol |
|---------|------|----------|
| Frontend (nginx) | 80 | HTTP |
| Backend (Flask) | 5000 | HTTP |
| PostgreSQL | 5432 | PostgreSQL |
| Kubernetes API | 6443 | HTTPS |
| CoreDNS | 53 | DNS |

### Useful Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias kn='kubectl config set-context --current --namespace'
```

## Additional Resources

### Official Documentation
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

### Workshop Resources
- [kubectl Cheatsheet](04-kubectl-cheatsheet.md)
- [Common Issues](05-common-issues.md)
- [Cluster Architecture](01-cluster-architecture.md)
- [Application Architecture](02-application-architecture.md)

---

**Remember:** Systematic troubleshooting beats random guessing. Observe, gather, analyze, fix, verify.
