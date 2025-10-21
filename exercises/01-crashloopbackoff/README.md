# Exercise 01: CrashLoopBackOff

**Difficulty:** ⭐ Basic
**Estimated Time:** 15 minutes

## Learning Objectives

- Understand pod lifecycle states
- Read and interpret pod events
- Analyze container exit codes
- Use kubectl logs effectively
- Fix CrashLoopBackOff errors

## Scenario

The backend API pods are in a CrashLoopBackOff state. The application was working fine, but after a recent configuration change, the backend pods keep crashing and restarting.

Your task is to diagnose why the pods are crash looping and fix the issue.

## Visual Impact

- ❌ Dashboard shows RED status for backend
- ❌ Tasks won't load
- ❌ API endpoint returns errors or timeouts
- ❌ Backend health check fails

## Prerequisites

- Baseline application is deployed and working
- You can access the dashboard at http://taskmaster.local
- All pods are currently in Running state

## Breaking the Application

Run the break script to introduce the issue:

```bash
./break.sh
```

This script will modify the backend deployment to introduce a typo in the container command.

## Troubleshooting Steps

### Step 1: Check Pod Status

```bash
kubectl get pods -n taskmaster
```

**Expected Output:**
```
NAME                        READY   STATUS             RESTARTS   AGE
backend-xxx                 0/1     CrashLoopBackOff   5          5m
backend-yyy                 0/1     CrashLoopBackOff   5          5m
frontend-xxx                1/1     Running            0          10m
postgres-xxx                1/1     Running            0          10m
```

**What to look for:**
- `STATUS`: CrashLoopBackOff means the container keeps crashing
- `RESTARTS`: High number indicates multiple crash attempts
- `READY`: 0/1 means container is not ready

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
  Normal   Created    Created container backend
  Normal   Started    Started container backend
  Warning  BackOff    Back-off restarting failed container
```

**Key Information:**
- `Last State`: Shows exit code and reason
- `Events`: Shows the sequence of what happened
- `Exit Code`: Non-zero indicates failure

### Step 3: View Container Logs

```bash
kubectl logs <backend-pod-name> -n taskmaster
```

**What to look for:**
```
/usr/local/bin/gunicorn: can't open file '/app/appp.py': [Errno 2] No such file or directory
```

**Analysis:**
- The container is trying to run `appp.py` (with typo)
- The correct file is `app.py`
- This causes the container to exit immediately

### Step 4: Check Previous Logs

```bash
kubectl logs <backend-pod-name> -n taskmaster --previous
```

This shows logs from the previous crash (useful if container crashes immediately).

### Step 5: Check Deployment Configuration

```bash
kubectl get deployment backend -n taskmaster -o yaml | grep -A 10 "command:"
```

or

```bash
kubectl edit deployment backend -n taskmaster
```

**What to look for:**
- Container command or args
- Entry point configuration
- Working directory

## Root Cause

The deployment configuration has a typo in the container command:

**Broken:**
```yaml
command: ["gunicorn", "--bind", "0.0.0.0:5000", "appp:app"]
                                                    ^^^^
                                                    TYPO!
```

**Correct:**
```yaml
command: ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
```

## The Fix

### Manual Fix

Edit the deployment and correct the typo:

```bash
kubectl edit deployment backend -n taskmaster
```

Find the command line and change `appp:app` to `app:app`, then save.

### Alternative: Patch Command

```bash
kubectl patch deployment backend -n taskmaster --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/command",
        "value": ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2",
                  "--timeout", "60", "--log-level", "info", "app:app"]}]'
```

### Using the Auto-Fix Script

```bash
./fix.sh
```

This script will automatically apply the fix.

## Verification

After applying the fix:

### 1. Watch Pods Recover

```bash
kubectl get pods -n taskmaster -w
```

You should see:
- Old pods terminating
- New pods starting
- Status changing to Running
- READY changing to 1/1

### 2. Run Verification Script

```bash
./verify.sh
```

### 3. Check Dashboard

Visit http://taskmaster.local - backend should show green status.

### 4. Test API

```bash
kubectl exec -n taskmaster <frontend-pod> -- wget -qO- http://backend-svc:5000/api/health
```

## Key Learnings

### CrashLoopBackOff Explained

- **Crash:** Container exits with non-zero exit code
- **Loop:** Kubernetes tries to restart it
- **BackOff:** Kubernetes increases delay between restart attempts (10s, 20s, 40s, etc.)

### Common Causes

1. **Misconfigured commands/args** (like this exercise)
2. **Missing dependencies or files**
3. **Application crashes on startup**
4. **Wrong environment variables**
5. **Configuration errors in app code**

### Debugging Tools

- `kubectl get pods` - See overall status
- `kubectl describe pod` - Detailed info and events
- `kubectl logs` - Current container logs
- `kubectl logs --previous` - Previous container logs
- `kubectl exec` - Execute commands in container

### Important kubectl Flags

- `-n <namespace>` - Specify namespace
- `-w` - Watch for changes
- `-o yaml` - Output as YAML
- `-o json` - Output as JSON
- `--previous` - Get logs from previous container instance

## Common Mistakes

1. ❌ Not checking pod events
2. ❌ Not viewing logs from crashed container
3. ❌ Editing wrong deployment or namespace
4. ❌ Not waiting for pods to fully restart
5. ❌ Not verifying the fix worked

## Reset to Baseline

To restore the original configuration:

```bash
./reset.sh
```

## Related Exercises

- Exercise 02: ImagePullBackOff
- Exercise 06: OOM Killed
- Exercise 15: Rollout Stuck

## Additional Resources

- [Kubernetes Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- [Container Exit Codes](https://kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/)

---

**Congratulations!** You've successfully diagnosed and fixed a CrashLoopBackOff issue!

**Next Exercise:** `cd ../02-imagepullbackoff`
