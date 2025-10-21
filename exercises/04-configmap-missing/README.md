# Exercise 04: ConfigMap Missing

**Difficulty:** ⭐⭐ Basic
**Estimated Time:** 20 minutes

## Learning Objectives

- Understand ConfigMaps and their role
- Diagnose missing ConfigMap issues
- Learn about pod creation failures
- Fix configuration dependency problems
- Understand environment variable injection

## Scenario

Someone accidentally deleted the backend ConfigMap that contains important environment variables. Now when you try to scale up or restart the backend pods, they fail to create. Existing pods keep running, but no new pods can start.

Your task is to diagnose why new pods won't start and restore the missing ConfigMap.

## Visual Impact

- ❌ Cannot scale backend deployment
- ❌ New pods stuck in CreateContainerConfigError
- ❌ Existing pods still work (until restarted)
- ❌ Rolling updates fail
- ❌ Cannot recreate pods

## Prerequisites

- Baseline application is deployed and working
- You can access the dashboard at http://taskmaster.local
- All pods are currently in Running state

## Breaking the Application

Run the break script to introduce the issue:

```bash
./break.sh
```

This script will delete the backend ConfigMap and trigger a pod restart.

## Troubleshooting Steps

### Step 1: Check Pod Status

```bash
kubectl get pods -n taskmaster
```

**Expected Output:**
```
NAME                        READY   STATUS                       RESTARTS   AGE
backend-xxx                 0/1     CreateContainerConfigError   0          1m
backend-yyy                 0/1     CreateContainerConfigError   0          1m
frontend-xxx                1/1     Running                      0          10m
postgres-xxx                1/1     Running                      0          10m
```

**What to look for:**
- `STATUS`: CreateContainerConfigError means container can't be created
- Usually related to ConfigMaps or Secrets

### Step 2: Describe the Pod

```bash
kubectl describe pod <backend-pod-name> -n taskmaster
```

**What to look for:**
```
Events:
  Type     Reason     Message
  ----     ------     -------
  Normal   Scheduled  Successfully assigned taskmaster/backend-xxx to node
  Normal   Pulled     Container image pulled
  Warning  Failed     Error: configmap "backend-config" not found
```

**Key Information:**
- Error message says ConfigMap is missing
- Container can't start without it

### Step 3: Check ConfigMaps

```bash
kubectl get configmaps -n taskmaster
```

**Expected Output:**
```
NAME                DATA   AGE
database-init       1      20m
```

**Analysis:** backend-config ConfigMap is missing!

### Step 4: List All ConfigMaps in Detail

```bash
kubectl get configmaps -n taskmaster -o wide
```

### Step 5: Check Deployment Configuration

```bash
kubectl get deployment backend -n taskmaster -o yaml | grep -A 10 "envFrom"
```

**What to look for:**
```yaml
envFrom:
- configMapRef:
    name: backend-config  ← Deployment references this ConfigMap
```

But the ConfigMap doesn't exist!

## Root Cause

The backend deployment references a ConfigMap that no longer exists:

**Deployment Configuration:**
```yaml
spec:
  containers:
  - name: backend
    envFrom:
    - configMapRef:
        name: backend-config  ← This ConfigMap is missing!
```

**Missing ConfigMap:**
```
kubectl get configmap backend-config -n taskmaster
Error from server (NotFound): configmaps "backend-config" not found
```

**Result:** Pods can't be created because required configuration is missing.

## The Fix

### Recreate the ConfigMap

The backend ConfigMap should contain environment variables for the backend application:

```bash
kubectl create configmap backend-config -n taskmaster \
  --from-literal=FLASK_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=WORKERS=2
```

### Alternative: Apply from YAML

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: taskmaster
data:
  FLASK_ENV: "production"
  LOG_LEVEL: "info"
  WORKERS: "2"
```

Save as `backend-config.yaml` and apply:
```bash
kubectl apply -f backend-config.yaml
```

### Using the Auto-Fix Script

```bash
./fix.sh
```

This script will automatically recreate the ConfigMap.

## Verification

After recreating the ConfigMap:

### 1. Watch Pods Recover

```bash
kubectl get pods -n taskmaster -w
```

Pods should:
- Exit CreateContainerConfigError state
- Start successfully
- Reach Running state

### 2. Run Verification Script

```bash
./verify.sh
```

### 3. Check ConfigMap Exists

```bash
kubectl get configmap backend-config -n taskmaster
kubectl describe configmap backend-config -n taskmaster
```

### 4. Check Dashboard

Visit http://taskmaster.local - backend should show green status.

## Key Learnings

### What are ConfigMaps?

- Store non-confidential configuration data
- Key-value pairs available to pods
- Can be used as:
  - Environment variables
  - Command-line arguments
  - Configuration files in volumes

### How Pods Use ConfigMaps

**As Environment Variables:**
```yaml
envFrom:
- configMapRef:
    name: backend-config
```

**Individual Variables:**
```yaml
env:
- name: LOG_LEVEL
  valueFrom:
    configMapKeyRef:
      name: backend-config
      key: LOG_LEVEL
```

**As Volume Mounts:**
```yaml
volumes:
- name: config
  configMap:
    name: backend-config
```

### Common ConfigMap Issues

1. **ConfigMap doesn't exist** (like this exercise)
2. **Typo in ConfigMap name**
3. **ConfigMap in wrong namespace**
4. **Missing required keys**
5. **Deleted ConfigMap that's still referenced**

### CreateContainerConfigError

This error occurs when:
- Referenced ConfigMap doesn't exist
- Referenced Secret doesn't exist
- Invalid configuration reference
- Missing required configuration

### Debugging Tools

- `kubectl get configmaps` - List ConfigMaps
- `kubectl describe configmap` - View ConfigMap details
- `kubectl describe pod` - See why container can't be created
- `kubectl get events` - See configuration errors

### Important Concepts

**ConfigMap vs Secret:**
- ConfigMap: Non-sensitive configuration
- Secret: Sensitive data (passwords, tokens)

**Optional ConfigMaps:**
```yaml
configMapRef:
  name: backend-config
  optional: true  ← Pod will start even if missing
```

**Immutable ConfigMaps:**
```yaml
immutable: true  ← ConfigMap can't be modified
```

## Common Mistakes

1. ❌ Deleting ConfigMaps without checking dependencies
2. ❌ Not making ConfigMaps optional when appropriate
3. ❌ Hardcoding configuration instead of using ConfigMaps
4. ❌ Not verifying ConfigMap exists before deploying
5. ❌ Using ConfigMaps for sensitive data (use Secrets instead)

## ConfigMap Management Best Practices

### 1. Backup Important ConfigMaps

```bash
kubectl get configmap backend-config -n taskmaster -o yaml > backend-config-backup.yaml
```

### 2. Version Control

Store ConfigMap manifests in git:
```bash
k8s-lab/
  baseline-app/
    manifests/
      backend/
        01-configmap.yaml  ← Version controlled
```

### 3. Check Dependencies

Before deleting a ConfigMap:
```bash
# Find all pods using this ConfigMap
kubectl get pods -n taskmaster -o yaml | grep "backend-config"
```

### 4. Use Descriptive Names

- ❌ `config`, `data`, `settings`
- ✅ `backend-config`, `database-init`, `nginx-conf`

## Reset to Baseline

To restore the original configuration:

```bash
./reset.sh
```

## Related Exercises

- Exercise 03: Service Unreachable
- Exercise 05: Secret Missing
- Exercise 07: Liveness Probe Fail

## Additional Resources

- [ConfigMaps - Kubernetes](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Configure Pods Using ConfigMap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)
- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)

---

**Congratulations!** You've successfully diagnosed and fixed a missing ConfigMap issue!

**Next Exercise:** `cd ../05-secret-missing`
