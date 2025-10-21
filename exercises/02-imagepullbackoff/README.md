# Exercise 02: ImagePullBackOff

**Difficulty:** ⭐ Basic
**Estimated Time:** 15 minutes

## Learning Objectives

- Understand ImagePullBackOff errors
- Diagnose image registry issues
- Check image tags and repositories
- Fix image pull problems
- Understand imagePullPolicy

## Scenario

The frontend deployment has been updated with a new image tag, but the pods won't start. They're stuck in ImagePullBackOff state. The image tag was changed but the specified version doesn't exist in the container registry.

Your task is to diagnose why the image can't be pulled and fix the issue.

## Visual Impact

- ❌ Dashboard won't load (frontend unavailable)
- ❌ Frontend pods stuck in ImagePullBackOff
- ❌ http://taskmaster.local returns 503 or connection refused
- ❌ Ingress can't route to frontend

## Prerequisites

- Baseline application is deployed and working
- You can access the dashboard at http://taskmaster.local
- All pods are currently in Running state

## Breaking the Application

Run the break script to introduce the issue:

```bash
./break.sh
```

This script will modify the frontend deployment to use a non-existent image tag.

## Troubleshooting Steps

### Step 1: Check Pod Status

```bash
kubectl get pods -n taskmaster
```

**Expected Output:**
```
NAME                        READY   STATUS             RESTARTS   AGE
backend-xxx                 1/1     Running            0          10m
frontend-xxx                0/1     ImagePullBackOff   0          2m
frontend-yyy                0/1     ImagePullBackOff   0          2m
postgres-xxx                1/1     Running            0          10m
```

**What to look for:**
- `STATUS`: ImagePullBackOff means Kubernetes can't pull the image
- `READY`: 0/1 means container is not ready
- `RESTARTS`: Usually 0 (container never started)

### Step 2: Describe the Pod

```bash
kubectl describe pod <frontend-pod-name> -n taskmaster
```

**What to look for:**
```
Events:
  Type     Reason     Message
  ----     ------     -------
  Normal   Scheduled  Successfully assigned taskmaster/frontend-xxx to node
  Normal   Pulling    Pulling image "docker.io/reddydodda/taskmaster-frontend:2.0"
  Warning  Failed     Failed to pull image "docker.io/reddydodda/taskmaster-frontend:2.0": rpc error: code = NotFound desc = failed to pull and unpack image "docker.io/reddydodda/taskmaster-frontend:2.0": failed to resolve reference "docker.io/reddydodda/taskmaster-frontend:2.0": docker.io/reddydodda/taskmaster-frontend:2.0: not found
  Warning  Failed     Error: ErrImagePull
  Normal   BackOff    Back-off pulling image "docker.io/reddydodda/taskmaster-frontend:2.0"
  Warning  Failed     Error: ImagePullBackOff
```

**Key Information:**
- Image pull is failing
- Error message says "not found"
- Kubernetes is backing off retry attempts

### Step 3: Check Container Status

```bash
kubectl get pod <frontend-pod-name> -n taskmaster -o jsonpath='{.status.containerStatuses[0].state.waiting}' | jq
```

**Expected:**
```json
{
  "message": "rpc error: code = NotFound desc = failed to pull and unpack image...",
  "reason": "ImagePullBackOff"
}
```

### Step 4: Check Image Configuration

```bash
kubectl get deployment frontend -n taskmaster -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**What to look for:**
- Image repository name
- Image tag
- Any typos in the image name

### Step 5: Verify Image Exists

Check if the image tag exists in Docker Hub:

```bash
# List available tags (if you have access)
curl -s https://hub.docker.com/v2/repositories/reddydodda/taskmaster-frontend/tags/ | jq '.results[].name'
```

Or check directly: https://hub.docker.com/r/reddydodda/taskmaster-frontend/tags

## Root Cause

The deployment configuration specifies a non-existent image tag:

**Broken:**
```yaml
spec:
  containers:
  - name: frontend
    image: docker.io/reddydodda/taskmaster-frontend:2.0
                                                        ^^^
                                                        Tag doesn't exist!
```

**Correct:**
```yaml
spec:
  containers:
  - name: frontend
    image: docker.io/reddydodda/taskmaster-frontend:1.0
                                                        ^^^
                                                        Correct tag
```

## The Fix

### Manual Fix

Edit the deployment and correct the image tag:

```bash
kubectl edit deployment frontend -n taskmaster
```

Find the `image:` line and change the tag from `2.0` to `1.0`, then save.

### Alternative: Set Image Command

```bash
kubectl set image deployment/frontend frontend=docker.io/reddydodda/taskmaster-frontend:1.0 -n taskmaster
```

### Alternative: Patch Command

```bash
kubectl patch deployment frontend -n taskmaster --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image",
        "value": "docker.io/reddydodda/taskmaster-frontend:1.0"}]'
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
- Image being pulled successfully
- Status changing to Running
- READY changing to 1/1

### 2. Run Verification Script

```bash
./verify.sh
```

### 3. Check Dashboard

Visit http://taskmaster.local - frontend should load successfully.

### 4. Verify Image

```bash
kubectl get pod <frontend-pod-name> -n taskmaster -o jsonpath='{.spec.containers[0].image}'
```

Should show: `docker.io/reddydodda/taskmaster-frontend:1.0`

## Key Learnings

### ImagePullBackOff Explained

- **ImagePull:** Kubernetes tries to pull the container image
- **BackOff:** After failing, Kubernetes backs off before retrying
- **Reasons:** Image doesn't exist, wrong tag, authentication issues, network problems

### Common Causes

1. **Non-existent image tag** (like this exercise)
2. **Typo in image name**
3. **Private registry without credentials**
4. **Network connectivity issues**
5. **Rate limiting from registry**
6. **Wrong image repository**

### imagePullPolicy Options

- `Always` - Always pull the image
- `IfNotPresent` - Pull only if not present locally
- `Never` - Never pull, use local image only

### Debugging Tools

- `kubectl get pods` - See overall status
- `kubectl describe pod` - See pull attempts and errors
- `kubectl get events` - See recent events
- `kubectl get deployment -o yaml` - Check image configuration
- Container registry web UI - Verify image exists

### Important Points

- Image tags must exactly match what's in the registry
- Tag `latest` might not always be present
- Private images need imagePullSecrets
- Check registry authentication if needed

## Common Mistakes

1. ❌ Using image tag that doesn't exist
2. ❌ Forgetting to push image to registry
3. ❌ Typo in image name or tag
4. ❌ Missing imagePullSecrets for private images
5. ❌ Not checking registry availability

## ImagePullBackOff vs ErrImagePull

- **ErrImagePull:** First failure to pull image
- **ImagePullBackOff:** Kubernetes is in backoff state after multiple failures
- Both indicate the same root cause (image can't be pulled)

## Reset to Baseline

To restore the original configuration:

```bash
./reset.sh
```

## Related Exercises

- Exercise 01: CrashLoopBackOff
- Exercise 04: ConfigMap Missing
- Exercise 05: Secret Missing

## Additional Resources

- [Images - Kubernetes](https://kubernetes.io/docs/concepts/containers/images/)
- [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)
- [Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/)

---

**Congratulations!** You've successfully diagnosed and fixed an ImagePullBackOff issue!

**Next Exercise:** `cd ../03-service-unreachable`
