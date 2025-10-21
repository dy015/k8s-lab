# Exercise 06: OOM Killed

**Difficulty:** ⭐⭐⭐ Intermediate
**Estimated Time:** 25 minutes

## Learning Objectives

- Understand Kubernetes resource limits
- Diagnose Out Of Memory (OOM) kills
- Learn about requests and limits
- Fix memory resource issues
- Understand QoS classes

## Scenario

The backend deployment has been configured with very restrictive memory limits (32Mi), causing the container to exceed its memory allocation. When this happens, Kubernetes kills the container with an OOMKilled status. The pod keeps restarting but gets killed again each time it tries to use more memory than allowed.

Your task is to diagnose the OOM issue and fix the memory limits.

## Visual Impact

- ❌ Backend pods constantly restarting
- ❌ Container status shows OOMKilled
- ❌ High restart count on pods
- ❌ Application intermittently unavailable
- ❌ Dashboard shows backend flapping

## Prerequisites

- Baseline application is deployed and working
- You can access the dashboard at http://taskmaster.local
- All pods are currently in Running state

## Breaking the Application

Run the break script to introduce the issue:

```bash
./break.sh
```

This script will set very low memory limits on the backend deployment, causing OOM kills.

## Troubleshooting Steps

### Step 1: Check Pod Status

```bash
kubectl get pods -n taskmaster -w
```

**Expected Output:**
```
NAME                        READY   STATUS      RESTARTS      AGE
backend-xxx                 0/1     OOMKilled   3 (15s ago)   2m
backend-yyy                 0/1     OOMKilled   4 (10s ago)   2m
frontend-xxx                1/1     Running     0             10m
postgres-xxx                1/1     Running     0             10m
```

**What to look for:**
- `STATUS`: OOMKilled indicates Out Of Memory
- `RESTARTS`: High restart count shows repeated failures
- Pods cycle through: Running → OOMKilled → CrashLoopBackOff

### Step 2: Describe the Pod

```bash
kubectl describe pod <backend-pod-name> -n taskmaster
```

**What to look for:**
```
State:          Terminated
  Reason:       OOMKilled
  Exit Code:    137
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137

Limits:
  memory:  32Mi    ← Very low limit!
Requests:
  memory:  16Mi

Events:
  Type     Reason     Message
  ----     ------     -------
  Warning  BackOff    Back-off restarting failed container
  Normal   Pulled     Container image already present
  Normal   Created    Created container backend
  Normal   Started    Started container backend
  Normal   Killing    Container backend exceeded memory limit
```

**Key Information:**
- Exit code 137 = SIGKILL (128 + 9)
- Memory limit is only 32Mi (way too low!)
- Container exceeds memory and gets killed

### Step 3: Check Resource Configuration

```bash
kubectl get deployment backend -n taskmaster -o yaml | grep -A 5 resources
```

**Expected Output:**
```yaml
resources:
  limits:
    memory: 32Mi    ← Too restrictive!
  requests:
    memory: 16Mi
```

### Step 4: Monitor Memory Usage

```bash
kubectl top pod -n taskmaster
```

**Expected Output:**
```
NAME                        CPU(cores)   MEMORY(bytes)
backend-xxx                 10m          45Mi    ← Needs more than 32Mi!
frontend-xxx                5m           128Mi
postgres-xxx                15m          256Mi
```

**Analysis:** Backend needs ~45-50Mi but limit is only 32Mi!

### Step 5: Check Previous Logs

```bash
kubectl logs <backend-pod-name> -n taskmaster --previous
```

Logs may be cut off when container is killed.

## Root Cause

The backend deployment has insufficient memory limits:

**Current Configuration:**
```yaml
spec:
  containers:
  - name: backend
    resources:
      limits:
        memory: 32Mi    ← Too low! Backend needs ~256Mi
      requests:
        memory: 16Mi
```

**What happens:**
1. Container starts with 32Mi memory limit
2. Application loads and uses memory
3. Memory usage exceeds 32Mi
4. Kubernetes kills container (OOMKilled)
5. Container restarts (CrashLoopBackOff)
6. Cycle repeats

## The Fix

### Update Memory Limits

```bash
kubectl patch deployment backend -n taskmaster --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/limits/memory",
    "value": "512Mi"
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/requests/memory",
    "value": "256Mi"
  }
]'
```

### Alternative: Edit Deployment

```bash
kubectl edit deployment backend -n taskmaster
```

Change:
```yaml
resources:
  limits:
    memory: 512Mi   # Was 32Mi
  requests:
    memory: 256Mi   # Was 16Mi
```

### Using the Auto-Fix Script

```bash
./fix.sh
```

This script will automatically set appropriate memory limits.

## Verification

After fixing the memory limits:

### 1. Watch Pods Stabilize

```bash
kubectl get pods -n taskmaster -w
```

Pods should:
- Stop getting OOMKilled
- Restart count should stop increasing
- Reach Running state and stay there

### 2. Run Verification Script

```bash
./verify.sh
```

### 3. Check Resource Usage

```bash
kubectl top pod -n taskmaster
```

Memory usage should be within limits.

### 4. Check Dashboard

Visit http://taskmaster.local - backend should be stable.

## Key Learnings

### Resource Requests vs Limits

| Aspect | Requests | Limits |
|--------|----------|---------|
| Purpose | Scheduling guarantee | Maximum allowed |
| Used for | Pod placement | Resource capping |
| Enforcement | Soft (scheduling) | Hard (kill if exceeded) |
| CPU behavior | Throttled | Throttled |
| Memory behavior | No effect | OOMKilled |

### Quality of Service (QoS) Classes

1. **Guaranteed**
   - Requests = Limits for all resources
   - Highest priority, least likely to be evicted

2. **Burstable**
   - Requests < Limits
   - Can use more resources when available

3. **BestEffort**
   - No requests or limits set
   - Lowest priority, first to be evicted

### Memory vs CPU

| Resource | Exceeded Behavior | Recovery |
|----------|------------------|----------|
| Memory | Container killed (OOMKilled) | Container restarts |
| CPU | Container throttled | Continues running slowly |

### OOM Exit Codes

- Exit Code 137 = 128 + 9 (SIGKILL)
- OOMKilled is immediate termination
- No graceful shutdown possible

### Memory Sizing Guidelines

```yaml
resources:
  requests:
    memory: "256Mi"   # Minimum needed for normal operation
  limits:
    memory: "512Mi"   # Maximum allowed (with buffer)
```

**Best Practices:**
- Set requests to typical usage
- Set limits 1.5-2x requests
- Monitor actual usage with `kubectl top`
- Allow headroom for spikes

## Common Mistakes

1. ❌ Setting limits too low without testing
2. ❌ Not setting requests (affects scheduling)
3. ❌ Huge gap between requests and limits
4. ❌ Not monitoring actual resource usage
5. ❌ Same limits for all environments

## Debugging Tools

- `kubectl top pod` - View current resource usage
- `kubectl describe pod` - See limits and OOM events
- `kubectl logs --previous` - View logs before OOM
- `kubectl get events` - See OOM kill events

## Resource Limit Examples

### Minimal Pod
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

### Standard Web App
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Memory-Intensive App
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## Reset to Baseline

To restore the original configuration:

```bash
./reset.sh
```

## Related Exercises

- Exercise 14: Node Pressure
- Exercise 03: Service Unreachable

## Additional Resources

- [Resource Management for Pods](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Assign Memory Resources](https://kubernetes.io/docs/tasks/configure-pod-container/assign-memory-resource/)
- [Pod Quality of Service Classes](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/)

---

**Congratulations!** You've successfully diagnosed and fixed an OOM kill issue!

**Next Exercise:** `cd ../07-liveness-probe-fail`