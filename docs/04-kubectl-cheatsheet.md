# kubectl Cheatsheet

## Quick Reference

Essential kubectl commands for Kubernetes troubleshooting and management in the workshop.

## Command Structure

```
kubectl [command] [TYPE] [NAME] [flags]

Examples:
kubectl get pods                          # List pods
kubectl describe pod backend-xxx          # Describe specific pod
kubectl logs backend-xxx -n taskmaster   # View logs
```

## Table of Contents

- [Context and Configuration](#context-and-configuration)
- [Viewing Resources](#viewing-resources)
- [Pod Operations](#pod-operations)
- [Deployments](#deployments)
- [Services](#services)
- [ConfigMaps and Secrets](#configmaps-and-secrets)
- [Storage](#storage)
- [Debugging](#debugging)
- [Logs](#logs)
- [Executing Commands](#executing-commands)
- [Resource Management](#resource-management)
- [Networking](#networking)
- [Events](#events)
- [Advanced Queries](#advanced-queries)
- [Cluster Information](#cluster-information)

---

## Context and Configuration

### Set Default Namespace

```bash
# Set default namespace for current context
kubectl config set-context --current --namespace=taskmaster

# Verify current context
kubectl config current-context

# View all contexts
kubectl config get-contexts
```

### View Configuration

```bash
# View kubeconfig
kubectl config view

# View current namespace
kubectl config view --minify | grep namespace

# Get cluster info
kubectl cluster-info
```

---

## Viewing Resources

### Get Commands

**Basic syntax:**
```bash
kubectl get [resource] [flags]
```

**Common resources:**
```bash
# Pods
kubectl get pods -n taskmaster
kubectl get pods -A                    # All namespaces
kubectl get pods -o wide               # More details (node, IP)

# Deployments
kubectl get deployments -n taskmaster
kubectl get deploy -n taskmaster       # Short form

# Services
kubectl get services -n taskmaster
kubectl get svc -n taskmaster         # Short form

# All resources in namespace
kubectl get all -n taskmaster

# All resources cluster-wide
kubectl get all -A

# Specific resource types
kubectl get pods,svc,deploy -n taskmaster
```

### Watch for Changes

```bash
# Watch pods (updates in real-time)
kubectl get pods -n taskmaster -w

# Watch all resources
kubectl get all -n taskmaster -w

# Watch events
kubectl get events -n taskmaster -w
```

### Label Selectors

```bash
# Filter by label
kubectl get pods -l app=backend -n taskmaster
kubectl get pods -l app=frontend -n taskmaster
kubectl get pods -l app=postgres -n taskmaster

# Multiple labels
kubectl get pods -l app=backend,version=v1 -n taskmaster

# Show labels
kubectl get pods --show-labels -n taskmaster

# Label selector with inequality
kubectl get pods -l app!=frontend -n taskmaster
```

### Output Formats

```bash
# Wide output (more columns)
kubectl get pods -o wide -n taskmaster

# YAML output
kubectl get pod <pod-name> -n taskmaster -o yaml

# JSON output
kubectl get pod <pod-name> -n taskmaster -o json

# Custom columns
kubectl get pods -n taskmaster -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName

# Name only
kubectl get pods -n taskmaster -o name

# JSONPath (extract specific fields)
kubectl get pods -n taskmaster -o jsonpath='{.items[*].metadata.name}'
```

---

## Pod Operations

### View Pod Status

```bash
# List all pods in namespace
kubectl get pods -n taskmaster

# Show pod details (IP, node, status)
kubectl get pods -n taskmaster -o wide

# Get specific pod
kubectl get pod <pod-name> -n taskmaster

# Watch pod status changes
kubectl get pods -n taskmaster -w
```

### Describe Pod

```bash
# Detailed information about pod
kubectl describe pod <pod-name> -n taskmaster

# Describe all pods with label
kubectl describe pods -l app=backend -n taskmaster

# Get events only
kubectl describe pod <pod-name> -n taskmaster | grep -A 20 Events
```

### Delete Pods

```bash
# Delete specific pod
kubectl delete pod <pod-name> -n taskmaster

# Delete all pods with label
kubectl delete pods -l app=backend -n taskmaster

# Force delete (immediate, no grace period)
kubectl delete pod <pod-name> -n taskmaster --force --grace-period=0

# Delete and wait for new pod
kubectl delete pod <pod-name> -n taskmaster && kubectl get pods -n taskmaster -w
```

### Pod Troubleshooting

```bash
# Get pod YAML definition
kubectl get pod <pod-name> -n taskmaster -o yaml

# Check pod events
kubectl get events -n taskmaster --field-selector involvedObject.name=<pod-name>

# Get pod status
kubectl get pod <pod-name> -n taskmaster -o jsonpath='{.status.phase}'

# Get container status
kubectl get pod <pod-name> -n taskmaster -o jsonpath='{.status.containerStatuses[0].state}'
```

---

## Deployments

### View Deployments

```bash
# List deployments
kubectl get deployments -n taskmaster

# Describe deployment
kubectl describe deployment <deployment-name> -n taskmaster

# Get deployment details
kubectl get deployment <deployment-name> -n taskmaster -o wide

# View deployment YAML
kubectl get deployment <deployment-name> -n taskmaster -o yaml
```

### Scale Deployments

```bash
# Scale to N replicas
kubectl scale deployment <deployment-name> -n taskmaster --replicas=3

# Scale to 0 (stop all pods)
kubectl scale deployment <deployment-name> -n taskmaster --replicas=0

# Scale backend
kubectl scale deployment backend -n taskmaster --replicas=3
```

### Update Deployments

```bash
# Edit deployment interactively
kubectl edit deployment <deployment-name> -n taskmaster

# Set new image
kubectl set image deployment/<deployment-name> <container-name>=<new-image> -n taskmaster

# Example: Update backend image
kubectl set image deployment/backend backend=reddydodda/taskmaster-backend:2.0 -n taskmaster

# Update resource limits
kubectl set resources deployment <deployment-name> -n taskmaster \
  --limits=cpu=500m,memory=512Mi \
  --requests=cpu=200m,memory=256Mi
```

### Rollout Operations

```bash
# Check rollout status
kubectl rollout status deployment/<deployment-name> -n taskmaster

# View rollout history
kubectl rollout history deployment/<deployment-name> -n taskmaster

# Rollback to previous version
kubectl rollout undo deployment/<deployment-name> -n taskmaster

# Rollback to specific revision
kubectl rollout undo deployment/<deployment-name> -n taskmaster --to-revision=2

# Restart deployment (rolling restart)
kubectl rollout restart deployment/<deployment-name> -n taskmaster

# Pause rollout
kubectl rollout pause deployment/<deployment-name> -n taskmaster

# Resume rollout
kubectl rollout resume deployment/<deployment-name> -n taskmaster
```

---

## Services

### View Services

```bash
# List services
kubectl get services -n taskmaster
kubectl get svc -n taskmaster

# Describe service
kubectl describe svc <service-name> -n taskmaster

# Get service details with endpoints
kubectl get svc <service-name> -n taskmaster -o wide

# View service YAML
kubectl get svc <service-name> -n taskmaster -o yaml
```

### Check Service Endpoints

```bash
# List endpoints
kubectl get endpoints -n taskmaster

# Describe specific endpoint
kubectl describe endpoints <service-name> -n taskmaster

# Get endpoint IPs
kubectl get endpoints <service-name> -n taskmaster -o jsonpath='{.subsets[*].addresses[*].ip}'
```

### Edit Services

```bash
# Edit service interactively
kubectl edit svc <service-name> -n taskmaster

# Change service type
kubectl patch svc <service-name> -n taskmaster -p '{"spec":{"type":"NodePort"}}'
```

### Port Forwarding

```bash
# Forward local port to service
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n taskmaster

# Example: Access backend locally
kubectl port-forward svc/backend-svc 5000:5000 -n taskmaster

# Forward to pod
kubectl port-forward pod/<pod-name> 5000:5000 -n taskmaster

# Listen on all interfaces
kubectl port-forward --address 0.0.0.0 svc/backend-svc 5000:5000 -n taskmaster
```

---

## ConfigMaps and Secrets

### ConfigMaps

**List and view:**
```bash
# List ConfigMaps
kubectl get configmap -n taskmaster
kubectl get cm -n taskmaster

# Describe ConfigMap
kubectl describe configmap <configmap-name> -n taskmaster

# View ConfigMap data
kubectl get configmap <configmap-name> -n taskmaster -o yaml
```

**Create ConfigMaps:**
```bash
# From literal values
kubectl create configmap backend-config -n taskmaster \
  --from-literal=FLASK_ENV=production \
  --from-literal=LOG_LEVEL=info

# From file
kubectl create configmap app-config -n taskmaster \
  --from-file=config.json

# From directory
kubectl create configmap app-config -n taskmaster \
  --from-file=/path/to/config/dir/
```

**Edit and delete:**
```bash
# Edit ConfigMap
kubectl edit configmap <configmap-name> -n taskmaster

# Delete ConfigMap
kubectl delete configmap <configmap-name> -n taskmaster
```

### Secrets

**List and view:**
```bash
# List secrets
kubectl get secrets -n taskmaster

# Describe secret (values are hidden)
kubectl describe secret <secret-name> -n taskmaster

# View secret data (base64 encoded)
kubectl get secret <secret-name> -n taskmaster -o yaml

# Decode secret value
kubectl get secret <secret-name> -n taskmaster -o jsonpath='{.data.password}' | base64 -d
```

**Create secrets:**
```bash
# From literal values
kubectl create secret generic database-secret -n taskmaster \
  --from-literal=POSTGRES_USER=taskuser \
  --from-literal=POSTGRES_PASSWORD=taskpass123

# From file
kubectl create secret generic ssh-key -n taskmaster \
  --from-file=ssh-privatekey=~/.ssh/id_rsa

# TLS secret
kubectl create secret tls tls-secret -n taskmaster \
  --cert=path/to/cert.crt \
  --key=path/to/key.key
```

**Edit and delete:**
```bash
# Edit secret
kubectl edit secret <secret-name> -n taskmaster

# Delete secret
kubectl delete secret <secret-name> -n taskmaster
```

---

## Storage

### PersistentVolumeClaims

```bash
# List PVCs
kubectl get pvc -n taskmaster

# Describe PVC
kubectl describe pvc <pvc-name> -n taskmaster

# View PVC details
kubectl get pvc <pvc-name> -n taskmaster -o yaml

# Delete PVC
kubectl delete pvc <pvc-name> -n taskmaster
```

### PersistentVolumes

```bash
# List PVs (cluster-wide)
kubectl get pv

# Describe PV
kubectl describe pv <pv-name>

# Get PV details
kubectl get pv <pv-name> -o yaml
```

### StorageClasses

```bash
# List storage classes
kubectl get storageclass
kubectl get sc

# Describe storage class
kubectl describe storageclass local-path

# Get default storage class
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'
```

---

## Debugging

### Interactive Debugging

```bash
# Get shell in pod
kubectl exec -it <pod-name> -n taskmaster -- /bin/sh
kubectl exec -it <pod-name> -n taskmaster -- /bin/bash

# Run single command in pod
kubectl exec <pod-name> -n taskmaster -- ls -la /app
kubectl exec <pod-name> -n taskmaster -- env
kubectl exec <pod-name> -n taskmaster -- cat /etc/resolv.conf

# Run command in specific container (multi-container pod)
kubectl exec <pod-name> -c <container-name> -n taskmaster -- command
```

### Network Debugging

```bash
# Test connectivity from pod
kubectl exec <pod-name> -n taskmaster -- wget -qO- http://backend-svc:5000/api/health
kubectl exec <pod-name> -n taskmaster -- curl http://backend-svc:5000/api/health

# Test DNS resolution
kubectl exec <pod-name> -n taskmaster -- nslookup backend-svc
kubectl exec <pod-name> -n taskmaster -- nslookup backend-svc.taskmaster.svc.cluster.local

# Ping another pod
kubectl exec <pod-name> -n taskmaster -- ping <other-pod-ip>

# Check listening ports
kubectl exec <pod-name> -n taskmaster -- netstat -tlnp
```

### Debug Container

```bash
# Create debug container in pod (Kubernetes 1.23+)
kubectl debug <pod-name> -n taskmaster -it --image=busybox

# Debug with different image
kubectl debug <pod-name> -n taskmaster -it --image=nicolaka/netshoot

# Debug node by creating pod on node
kubectl debug node/<node-name> -it --image=busybox
```

---

## Logs

### Basic Log Commands

```bash
# View pod logs
kubectl logs <pod-name> -n taskmaster

# Follow logs (stream)
kubectl logs -f <pod-name> -n taskmaster

# View logs from previous container (after crash)
kubectl logs --previous <pod-name> -n taskmaster
kubectl logs -p <pod-name> -n taskmaster

# Logs from specific container in multi-container pod
kubectl logs <pod-name> -c <container-name> -n taskmaster
```

### Advanced Log Options

```bash
# Last N lines
kubectl logs <pod-name> -n taskmaster --tail=100

# Logs since timestamp
kubectl logs <pod-name> -n taskmaster --since=1h
kubectl logs <pod-name> -n taskmaster --since=2m
kubectl logs <pod-name> -n taskmaster --since=30s

# Logs since specific time
kubectl logs <pod-name> -n taskmaster --since-time=2025-01-20T10:00:00Z

# All pods with label
kubectl logs -l app=backend -n taskmaster

# All containers in pod
kubectl logs <pod-name> -n taskmaster --all-containers=true

# Include timestamps
kubectl logs <pod-name> -n taskmaster --timestamps
```

### Log Examples for Workshop

```bash
# Backend logs
kubectl logs -n taskmaster -l app=backend --tail=50 -f

# Frontend logs
kubectl logs -n taskmaster -l app=frontend --tail=50

# Database logs
kubectl logs -n taskmaster -l app=postgres --tail=100

# All pods in namespace
kubectl logs -n taskmaster --all-pods=true --tail=20
```

---

## Executing Commands

### Common Commands in Pods

```bash
# Check application files
kubectl exec <pod-name> -n taskmaster -- ls -la /app

# Check environment variables
kubectl exec <pod-name> -n taskmaster -- env | grep DB

# Check processes
kubectl exec <pod-name> -n taskmaster -- ps aux

# Test network connectivity
kubectl exec <pod-name> -n taskmaster -- wget -qO- http://backend-svc:5000/api/health

# Check DNS configuration
kubectl exec <pod-name> -n taskmaster -- cat /etc/resolv.conf

# Check mounted volumes
kubectl exec <pod-name> -n taskmaster -- df -h

# View configuration file
kubectl exec <pod-name> -n taskmaster -- cat /etc/nginx/nginx.conf
```

### Database Commands

```bash
# PostgreSQL - Check if ready
kubectl exec <postgres-pod> -n taskmaster -- pg_isready -h localhost

# Connect to PostgreSQL
kubectl exec -it <postgres-pod> -n taskmaster -- psql -U taskuser -d taskmaster

# Run SQL query
kubectl exec <postgres-pod> -n taskmaster -- psql -U taskuser -d taskmaster -c "SELECT * FROM tasks;"

# Check database tables
kubectl exec <postgres-pod> -n taskmaster -- psql -U taskuser -d taskmaster -c "\dt"
```

---

## Resource Management

### View Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n taskmaster

# Specific pod
kubectl top pod <pod-name> -n taskmaster

# Sort by CPU
kubectl top pods -n taskmaster --sort-by=cpu

# Sort by memory
kubectl top pods -n taskmaster --sort-by=memory

# All namespaces
kubectl top pods -A
```

### Resource Requests and Limits

```bash
# View pod resource settings
kubectl get pod <pod-name> -n taskmaster -o jsonpath='{.spec.containers[*].resources}'

# Update deployment resources
kubectl set resources deployment <name> -n taskmaster \
  --limits=cpu=500m,memory=512Mi \
  --requests=cpu=200m,memory=256Mi

# View all pod resources in namespace
kubectl get pods -n taskmaster -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory
```

### Node Information

```bash
# List nodes
kubectl get nodes

# Node details
kubectl describe node <node-name>

# Node capacity and allocatable
kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory

# Node allocated resources
kubectl describe node <node-name> | grep -A 10 "Allocated resources"
```

---

## Networking

### Ingress

```bash
# List ingress resources
kubectl get ingress -n taskmaster

# Describe ingress
kubectl describe ingress <ingress-name> -n taskmaster

# View ingress YAML
kubectl get ingress <ingress-name> -n taskmaster -o yaml

# Edit ingress
kubectl edit ingress <ingress-name> -n taskmaster
```

### Network Policies

```bash
# List network policies
kubectl get networkpolicy -n taskmaster
kubectl get netpol -n taskmaster

# Describe network policy
kubectl describe networkpolicy <policy-name> -n taskmaster

# View network policy YAML
kubectl get networkpolicy <policy-name> -n taskmaster -o yaml

# Delete network policy
kubectl delete networkpolicy <policy-name> -n taskmaster
```

### DNS Debugging

```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS from pod
kubectl exec <pod-name> -n taskmaster -- nslookup kubernetes.default
kubectl exec <pod-name> -n taskmaster -- nslookup backend-svc.taskmaster.svc.cluster.local
```

---

## Events

### View Events

```bash
# All events in namespace
kubectl get events -n taskmaster

# Sorted by timestamp
kubectl get events -n taskmaster --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n taskmaster -w

# Events for specific object
kubectl get events -n taskmaster --field-selector involvedObject.name=<pod-name>

# All events cluster-wide
kubectl get events -A

# Recent events (last 20)
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Event Types

```bash
# Filter by type
kubectl get events -n taskmaster --field-selector type=Warning
kubectl get events -n taskmaster --field-selector type=Normal

# Filter by reason
kubectl get events -n taskmaster --field-selector reason=Failed
```

---

## Advanced Queries

### JSONPath Examples

```bash
# Get all pod names
kubectl get pods -n taskmaster -o jsonpath='{.items[*].metadata.name}'

# Get pod IPs
kubectl get pods -n taskmaster -o jsonpath='{.items[*].status.podIP}'

# Get pod with node
kubectl get pods -n taskmaster -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}{end}'

# Get container images
kubectl get pods -n taskmaster -o jsonpath='{.items[*].spec.containers[*].image}'

# Get pod status
kubectl get pods -n taskmaster -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Get service ClusterIP
kubectl get svc -n taskmaster -o jsonpath='{.items[*].spec.clusterIP}'

# Get secret data keys
kubectl get secret <secret-name> -n taskmaster -o jsonpath='{.data}'
```

### Custom Columns

```bash
# Pods with custom columns
kubectl get pods -n taskmaster -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
NODE:.spec.nodeName,\
IP:.status.podIP

# Services with custom columns
kubectl get svc -n taskmaster -o custom-columns=\
NAME:.metadata.name,\
TYPE:.spec.type,\
CLUSTER-IP:.spec.clusterIP,\
PORT:.spec.ports[0].port

# Nodes with custom columns
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[-1].type,\
CPU:.status.capacity.cpu,\
MEMORY:.status.capacity.memory
```

### Grep and Filtering

```bash
# Filter output with grep
kubectl get pods -n taskmaster | grep backend
kubectl describe pod <pod-name> -n taskmaster | grep -i error
kubectl get events -n taskmaster | grep Warning

# Multiple conditions
kubectl get pods -A | grep -E "Running|Pending"

# Case insensitive
kubectl logs <pod-name> -n taskmaster | grep -i "error"

# Show context around match
kubectl logs <pod-name> -n taskmaster | grep -A 5 -B 5 "error"
```

---

## Cluster Information

### Cluster Status

```bash
# Cluster info
kubectl cluster-info

# Cluster version
kubectl version
kubectl version --short

# API resources
kubectl api-resources

# API versions
kubectl api-versions

# Component status (deprecated in newer versions)
kubectl get componentstatuses
kubectl get cs
```

### System Pods

```bash
# All system pods
kubectl get pods -n kube-system

# Specific system components
kubectl get pods -n kube-system -l k8s-app=kube-dns      # CoreDNS
kubectl get pods -n kube-system -l app=local-path-provisioner
kubectl get pods -n kube-system | grep ingress
kubectl get pods -n kube-system | grep metrics
```

### RBAC

```bash
# List roles and rolebindings
kubectl get role,rolebinding -n taskmaster

# List cluster roles (cluster-wide)
kubectl get clusterrole
kubectl get clusterrolebinding

# Check permissions
kubectl auth can-i create pods -n taskmaster
kubectl auth can-i delete deployments -n taskmaster

# Check permissions for service account
kubectl auth can-i list pods --as=system:serviceaccount:taskmaster:default -n taskmaster
```

---

## Practical Scenarios

### Scenario 1: Pod Won't Start

```bash
# 1. Check pod status
kubectl get pods -n taskmaster

# 2. Describe pod for events
kubectl describe pod <pod-name> -n taskmaster

# 3. Check logs
kubectl logs <pod-name> -n taskmaster

# 4. Check previous logs if crashed
kubectl logs --previous <pod-name> -n taskmaster

# 5. Check deployment
kubectl describe deployment <deployment-name> -n taskmaster
```

### Scenario 2: Service Not Working

```bash
# 1. Check service
kubectl get svc <service-name> -n taskmaster

# 2. Check endpoints
kubectl get endpoints <service-name> -n taskmaster

# 3. Check if pods match selector
kubectl get pods -n taskmaster --show-labels
kubectl describe svc <service-name> -n taskmaster | grep Selector

# 4. Test from another pod
kubectl exec <test-pod> -n taskmaster -- wget -qO- http://<service-name>:<port>
```

### Scenario 3: High Memory Usage

```bash
# 1. Check resource usage
kubectl top pods -n taskmaster --sort-by=memory

# 2. Check pod limits
kubectl describe pod <pod-name> -n taskmaster | grep -A 5 Limits

# 3. Check events for OOM
kubectl get events -n taskmaster --field-selector reason=OOMKilled

# 4. Increase limits
kubectl set resources deployment <name> -n taskmaster \
  --limits=memory=1Gi --requests=memory=512Mi
```

### Scenario 4: Application Not Accessible

```bash
# 1. Check ingress
kubectl get ingress -n taskmaster
kubectl describe ingress taskmaster-ingress -n taskmaster

# 2. Check ingress controller
kubectl get pods -n kube-system | grep ingress

# 3. Check frontend service
kubectl get svc frontend-svc -n taskmaster
kubectl get endpoints frontend-svc -n taskmaster

# 4. Check frontend pods
kubectl get pods -n taskmaster -l app=frontend
kubectl logs -n taskmaster -l app=frontend --tail=20
```

---

## Useful One-Liners

### Quick Diagnostics

```bash
# All pods not running
kubectl get pods -A --field-selector=status.phase!=Running

# Get all pod IPs in namespace
kubectl get pods -n taskmaster -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Count pods by status
kubectl get pods -A -o json | jq -r '.items[].status.phase' | sort | uniq -c

# Get all images in namespace
kubectl get pods -n taskmaster -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u

# Find pods on specific node
kubectl get pods -A --field-selector spec.nodeName=<node-name>

# Pods with restart count > 0
kubectl get pods -n taskmaster -o json | jq -r '.items[] | select(.status.containerStatuses[0].restartCount > 0) | .metadata.name'
```

### Resource Management

```bash
# Total resource requests in namespace
kubectl get pods -n taskmaster -o json | jq '[.items[].spec.containers[].resources.requests] | add'

# Pods using most CPU
kubectl top pods -n taskmaster --sort-by=cpu | head

# Pods using most memory
kubectl top pods -n taskmaster --sort-by=memory | head

# Delete all failed pods
kubectl delete pods -n taskmaster --field-selector=status.phase=Failed
```

### Quick Fixes

```bash
# Restart all pods in deployment
kubectl rollout restart deployment/<deployment-name> -n taskmaster

# Delete and recreate pod
kubectl delete pod <pod-name> -n taskmaster

# Force delete stuck pod
kubectl delete pod <pod-name> -n taskmaster --force --grace-period=0

# Scale deployment to 0 and back
kubectl scale deployment <name> -n taskmaster --replicas=0 && \
kubectl scale deployment <name> -n taskmaster --replicas=2
```

---

## Aliases and Shortcuts

### Recommended Bash Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Basic aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kgn='kubectl get nodes'

# Namespace-specific
alias kgpt='kubectl get pods -n taskmaster'
alias kgst='kubectl get svc -n taskmaster'

# Describe
alias kdp='kubectl describe pod'
alias kds='kubectl describe svc'
alias kdd='kubectl describe deployment'

# Logs
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias klp='kubectl logs --previous'

# Edit
alias ke='kubectl edit'
alias kep='kubectl edit pod'
alias ked='kubectl edit deployment'

# Execute
alias kex='kubectl exec -it'

# Apply/Delete
alias ka='kubectl apply -f'
alias kdel='kubectl delete'

# Context
alias kn='kubectl config set-context --current --namespace'
alias kctx='kubectl config current-context'
```

### Usage Examples

```bash
# After setting aliases
kgpt                    # Same as: kubectl get pods -n taskmaster
kl backend-xxx -n taskmaster    # Same as: kubectl logs backend-xxx -n taskmaster
kex backend-xxx -n taskmaster -- /bin/sh    # Same as: kubectl exec -it backend-xxx...
```

---

## Quick Reference Tables

### Common Resource Short Names

| Full Name | Short Name |
|-----------|------------|
| pods | po |
| services | svc |
| deployments | deploy |
| replicasets | rs |
| namespaces | ns |
| configmaps | cm |
| persistentvolumeclaims | pvc |
| persistentvolumes | pv |
| storageclasses | sc |
| ingresses | ing |
| networkpolicies | netpol |

### Field Selectors

```bash
# By status
--field-selector status.phase=Running
--field-selector status.phase=Pending
--field-selector status.phase=Failed

# By node
--field-selector spec.nodeName=<node-name>

# By namespace (for cluster-wide queries)
--field-selector metadata.namespace=taskmaster

# By name
--field-selector metadata.name=<pod-name>
```

### Output Format Options

| Format | Flag | Use Case |
|--------|------|----------|
| Wide | `-o wide` | More columns (IP, node) |
| YAML | `-o yaml` | Full resource definition |
| JSON | `-o json` | Machine-readable |
| Name | `-o name` | Just resource names |
| Custom Columns | `-o custom-columns=...` | Specific fields |
| JSONPath | `-o jsonpath='{...}'` | Extract specific data |

---

## Workshop-Specific Commands

### Setup Verification

```bash
# Verify cluster
kubectl get nodes
kubectl get pods -A

# Verify TaskMaster deployment
kubectl get all -n taskmaster
kubectl get pods -n taskmaster
kubectl get svc -n taskmaster
kubectl get ingress -n taskmaster
```

### Exercise Workflows

```bash
# Before breaking
kubectl get pods -n taskmaster    # All should be Running

# After breaking
kubectl get pods -n taskmaster    # Identify issues
kubectl describe pod <pod-name> -n taskmaster    # Investigate
kubectl logs <pod-name> -n taskmaster    # Check logs

# After fixing
kubectl get pods -n taskmaster -w    # Watch recovery
```

### Common Exercise Commands

```bash
# Exercise 01: CrashLoopBackOff
kubectl logs <pod-name> -n taskmaster
kubectl edit deployment backend -n taskmaster

# Exercise 02: ImagePullBackOff
kubectl describe pod <pod-name> -n taskmaster
kubectl edit deployment backend -n taskmaster

# Exercise 03: Service Unreachable
kubectl get svc -n taskmaster
kubectl get endpoints backend-svc -n taskmaster
kubectl edit svc backend-svc -n taskmaster

# Exercise 04-05: ConfigMap/Secret Missing
kubectl get configmap -n taskmaster
kubectl get secret -n taskmaster
kubectl create configmap/secret ...

# Exercise 06: OOM Killed
kubectl top pods -n taskmaster
kubectl set resources deployment backend -n taskmaster --limits=memory=1Gi

# Exercise 10: DNS Not Working
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl scale deployment coredns -n kube-system --replicas=2
```

---

## Additional Resources

### Official Documentation
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [kubectl Commands](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)
- [kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)

### Workshop Resources
- [Troubleshooting Guide](03-troubleshooting-guide.md)
- [Common Issues](05-common-issues.md)
- [Application Architecture](02-application-architecture.md)

---

**Pro Tip:** Use `kubectl explain` to learn about resource fields:

```bash
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy
```
