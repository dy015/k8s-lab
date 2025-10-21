# Exercise 07: Liveness Probe Failure

**Difficulty:** ⭐⭐⭐ Intermediate
**Estimated Time:** 25 minutes

## Learning Objectives

- Understand Kubernetes liveness probes
- Diagnose probe failure issues
- Learn probe timing configuration
- Fix incorrect probe endpoints
- Understand probe vs readiness differences

## Scenario

The backend liveness probe has been misconfigured to check a non-existent endpoint (/wrong-health instead of /api/health). This causes Kubernetes to think the container is unhealthy and restart it continuously, even though the application is working fine.

Your task is to diagnose the probe failures and fix the endpoint configuration.

## Visual Impact

- ❌ Backend pods constantly restarting
- ❌ High restart count
- ❌ Liveness probe failed events
- ❌ Pods killed despite being healthy
- ❌ Dashboard shows backend unstable

## Prerequisites

- Baseline application is deployed and working
- You can access the dashboard at http://taskmaster.local
- All pods are currently in Running state

## Breaking the Application

Run the break script to introduce the issue:

```bash
./break.sh
```

This script will change the liveness probe to use a wrong endpoint.

## Troubleshooting Steps

### Step 1: Check Pod Status

```bash
kubectl get pods -n taskmaster -w
```

**Expected Output:**
```
NAME                        READY   STATUS    RESTARTS      AGE
backend-xxx                 1/1     Running   5 (30s ago)   3m
backend-yyy                 1/1     Running   6 (20s ago)   3m
frontend-xxx                1/1     Running   0             10m
postgres-xxx                1/1     Running   0             10m
```

**What to look for:**
- High `RESTARTS` count that keeps increasing
- Pods appear Running but keep restarting
- Pattern repeats every ~30 seconds

### Step 2: Describe the Pod

```bash
kubectl describe pod <backend-pod-name> -n taskmaster
```

**What to look for:**
```
Liveness:  http-get http://:8080/wrong-health delay=30s timeout=5s period=10s #failure=3
Readiness: http-get http://:8080/api/health delay=10s timeout=5s period=5s #failure=3

Events:
  Type     Reason     Message
  ----     ------     -------
  Warning  Unhealthy  Liveness probe failed: HTTP probe failed with statuscode: 404
  Normal   Killing    Container backend failed liveness probe, will be restarted
```

**Key Information:**
- Liveness probe checking `/wrong-health`
- Returns 404 (endpoint doesn't exist)
- After 3 failures, pod is killed

### Step 3: Check Events

```bash
kubectl get events -n taskmaster --sort-by='.lastTimestamp' | grep backend
```

**Expected Output:**
```
Warning  Unhealthy   Liveness probe failed: HTTP probe failed with statuscode: 404
Normal   Killing     Container backend failed liveness probe, will be restarted
Normal   Pulled      Container image already present
Normal   Created     Created container backend
Normal   Started     Started container backend
```

### Step 4: Test the Correct Endpoint

```bash
kubectl exec <backend-pod-name> -n taskmaster -- curl -s http://localhost:8080/api/health
```

**Expected Output:**
```json
{"status":"healthy","timestamp":"2024-01-20T10:30:00Z"}
```

### Step 5: Test the Wrong Endpoint

```bash
kubectl exec <backend-pod-name> -n taskmaster -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/wrong-health
```

**Expected Output:**
```
404
```

## Root Cause

The liveness probe is configured with the wrong endpoint:

**Current Configuration:**
```yaml
livenessProbe:
  httpGet:
    path: /wrong-health  ← Wrong endpoint!
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

**Correct Configuration:**
```yaml
livenessProbe:
  httpGet:
    path: /api/health   ← Correct endpoint
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3
```

## The Fix

### Update the Liveness Probe

```bash
kubectl patch deployment backend -n taskmaster --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/path",
    "value": "/api/health"
  }
]'
```

### Alternative: Edit Deployment

```bash
kubectl edit deployment backend -n taskmaster
```

Change:
```yaml
livenessProbe:
  httpGet:
    path: /api/health  # Was /wrong-health
```

### Using the Auto-Fix Script

```bash
./fix.sh
```

## Verification

After fixing the probe:

### 1. Watch Pods Stabilize

```bash
kubectl get pods -n taskmaster -w
```

Restart count should stop increasing.

### 2. Run Verification Script

```bash
./verify.sh
```

### 3. Check Dashboard

Visit http://taskmaster.local - backend should be stable.

## Key Learnings

### Liveness vs Readiness Probes

| Aspect | Liveness Probe | Readiness Probe |
|--------|----------------|-----------------|
| Purpose | Is container alive? | Is container ready for traffic? |
| Failure Action | Restart container | Remove from service endpoints |
| Use Case | Detect deadlocks/hangs | Wait for initialization |
| Recovery | Automatic restart | Automatic when probe succeeds |

### Probe Types

1. **HTTP GET**
   ```yaml
   httpGet:
     path: /health
     port: 8080
     httpHeaders:
     - name: Custom-Header
       value: Awesome
   ```

2. **TCP Socket**
   ```yaml
   tcpSocket:
     port: 8080
   ```

3. **Exec Command**
   ```yaml
   exec:
     command:
     - cat
     - /tmp/healthy
   ```

### Probe Timing Parameters

- **initialDelaySeconds**: Wait before first probe
- **periodSeconds**: How often to probe
- **timeoutSeconds**: Probe timeout
- **successThreshold**: Successes to be considered healthy
- **failureThreshold**: Failures before action taken

### Common Probe Issues

1. **Wrong endpoint** (this exercise)
2. **Too aggressive timing**
3. **Endpoint too slow**
4. **Dependencies in health check**
5. **No graceful degradation**

## Best Practices

- Keep health endpoints lightweight
- Don't check external dependencies in liveness
- Use readiness for dependency checks
- Set appropriate delays for startup
- Log probe failures for debugging

## Reset to Baseline

To restore the original configuration:

```bash
./reset.sh
```

## Related Exercises

- Exercise 08: Readiness Probe Fail
- Exercise 06: OOM Killed

## Additional Resources

- [Configure Liveness, Readiness Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Kubernetes Probes Best Practices](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#container-probes)

---

**Congratulations!** You've successfully diagnosed and fixed a liveness probe failure!

**Next Exercise:** `cd ../08-readiness-probe-fail`