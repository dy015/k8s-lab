# Exercise 03: Service Unreachable

**Difficulty:** ⭐⭐ Basic
**Estimated Time:** 20 minutes

## Learning Objectives

- Understand Kubernetes Services and label selectors
- Diagnose service endpoint issues
- Learn about pod-to-service communication
- Fix service selector mismatches
- Understand the role of labels in Kubernetes

## Scenario

The backend API is running fine, but the frontend can't communicate with it. Users see "Unable to connect to backend" errors in the dashboard. The backend pods are healthy and running, but the backend service has no endpoints.

Your task is to diagnose why the service can't find the backend pods and fix the connectivity issue.

## Visual Impact

- ❌ Dashboard shows RED status for backend
- ❌ Tasks won't load (API unreachable)
- ❌ "Failed to fetch tasks" error in browser console
- ✅ Backend pods are Running (confusingly!)
- ✅ Frontend is accessible

## Prerequisites

- Baseline application is deployed and working
- You can access the dashboard at http://taskmaster.local
- All pods are currently in Running state

## Breaking the Application

Run the break script to introduce the issue:

```bash
./break.sh
```

This script will modify the backend service selector to point to non-existent labels.

## Troubleshooting Steps

### Step 1: Check Pod Status

```bash
kubectl get pods -n taskmaster
```

**Expected Output:**
```
NAME                        READY   STATUS    RESTARTS   AGE
backend-xxx                 1/1     Running   0          10m
backend-yyy                 1/1     Running   0          10m
frontend-xxx                1/1     Running   0          10m
postgres-xxx                1/1     Running   0          10m
```

**Observation:** All pods are Running! So why isn't it working?

### Step 2: Check Service Status

```bash
kubectl get svc -n taskmaster
```

**Expected Output:**
```
NAME           TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
backend-svc    ClusterIP   10.43.xxx.xxx   <none>        5000/TCP   10m
frontend-svc   ClusterIP   10.43.xxx.xxx   <none>        80/TCP     10m
postgres-svc   ClusterIP   10.43.xxx.xxx   <none>        5432/TCP   10m
```

Services exist, so what's the problem?

### Step 3: Check Service Endpoints

```bash
kubectl get endpoints -n taskmaster
```

**Expected Output:**
```
NAME           ENDPOINTS         AGE
backend-svc    <none>            10m  ← NO ENDPOINTS!
frontend-svc   10.42.x.x:80      10m
postgres-svc   10.42.x.x:5432    10m
```

**Key Finding:** backend-svc has NO endpoints! This is the problem.

### Step 4: Describe the Service

```bash
kubectl describe svc backend-svc -n taskmaster
```

**What to look for:**
```
Name:              backend-svc
Namespace:         taskmaster
Selector:          app=backend-api  ← This selector!
Type:              ClusterIP
IP:                10.43.xxx.xxx
Port:              http  5000/TCP
TargetPort:        5000/TCP
Endpoints:         <none>           ← No endpoints match!
```

**Key Information:**
- `Selector`: What labels the service is looking for
- `Endpoints`: List of pod IPs (empty means no matching pods)

### Step 5: Check Pod Labels

```bash
kubectl get pods -n taskmaster -l app=backend --show-labels
```

**Expected Output:**
```
NAME           READY   STATUS    RESTARTS   AGE   LABELS
backend-xxx    1/1     Running   0          10m   app=backend,pod-template-hash=xxx
backend-yyy    1/1     Running   0          10m   app=backend,pod-template-hash=xxx
```

**Analysis:**
- Pods have label `app=backend`
- Service is looking for `app=backend-api`
- Labels don't match, so no endpoints!

### Step 6: Compare Service Selector with Pod Labels

```bash
# Check service selector
kubectl get svc backend-svc -n taskmaster -o jsonpath='{.spec.selector}'

# Check pod labels
kubectl get pods -n taskmaster -l app=backend -o jsonpath='{.items[0].metadata.labels}'
```

## Root Cause

The service selector doesn't match the pod labels:

**Service Selector (WRONG):**
```yaml
spec:
  selector:
    app: backend-api  ← Looking for this label
```

**Pod Labels (ACTUAL):**
```yaml
metadata:
  labels:
    app: backend      ← Pods have this label
```

**Result:** Service can't find any pods, so no endpoints are created.

## The Fix

### Manual Fix Option 1: Edit the Service

```bash
kubectl edit svc backend-svc -n taskmaster
```

Find the `selector` section and change:
```yaml
selector:
  app: backend-api
```

To:
```yaml
selector:
  app: backend
```

Save and exit.

### Manual Fix Option 2: Patch the Service

```bash
kubectl patch svc backend-svc -n taskmaster --type='json' \
  -p='[{"op": "replace", "path": "/spec/selector/app", "value": "backend"}]'
```

### Using the Auto-Fix Script

```bash
./fix.sh
```

This script will automatically apply the fix.

## Verification

After applying the fix:

### 1. Check Endpoints Immediately

```bash
kubectl get endpoints backend-svc -n taskmaster
```

Should now show pod IPs:
```
NAME          ENDPOINTS                     AGE
backend-svc   10.42.x.x:5000,10.42.x.x:5000 15m
```

### 2. Test Backend Connectivity

```bash
kubectl run test-pod --image=busybox --rm -it -n taskmaster -- wget -qO- http://backend-svc:5000/api/health
```

Should return healthy status JSON.

### 3. Run Verification Script

```bash
./verify.sh
```

### 4. Check Dashboard

Visit http://taskmaster.local - backend should show green status and tasks should load.

## Key Learnings

### How Services Work

1. **Service** has a selector (labels to match)
2. **Pods** have labels
3. **Endpoint Controller** watches for matching pods
4. When labels match, pod IPs are added as endpoints
5. Service routes traffic to these endpoints

### Label Selector Matching

Services use **label selectors** to find pods:
```yaml
service:
  selector:
    app: backend
    tier: api

pods:
  labels:
    app: backend  ← Must match
    tier: api     ← All selector labels
```

### Common Service Issues

1. **Selector mismatch** (like this exercise)
2. **Typo in labels**
3. **Wrong namespace**
4. **Pods not ready** (readiness probe failing)
5. **Port mismatch** (service port vs container port)

### Debugging Tools

- `kubectl get endpoints` - See if service has endpoints
- `kubectl describe svc` - View selector and endpoints
- `kubectl get pods --show-labels` - See pod labels
- `kubectl get pods -l <selector>` - Test selector matching

### Important Concepts

**Labels:**
- Key-value pairs attached to resources
- Used for grouping and selection
- Can be added/modified after creation

**Selectors:**
- Query labels to find matching resources
- Used by Services, Deployments, etc.
- Must match exactly (no partial matching)

**Endpoints:**
- List of IP addresses that match the service selector
- Automatically managed by Kubernetes
- Empty endpoints = service can't route traffic

## Common Mistakes

1. ❌ Assuming running pods mean working service
2. ❌ Not checking if service has endpoints
3. ❌ Typo in label names (app vs application)
4. ❌ Wrong namespace (labels in different namespace)
5. ❌ Not understanding selector matching rules

## Testing Service Connectivity

### From Another Pod

```bash
kubectl run test --image=busybox --rm -it -n taskmaster -- wget -qO- http://backend-svc:5000/api/health
```

### Port Forward for Local Testing

```bash
kubectl port-forward svc/backend-svc 5000:5000 -n taskmaster
curl http://localhost:5000/api/health
```

### Using DNS

Services are accessible via DNS:
- `<service-name>.<namespace>.svc.cluster.local`
- Short form: `<service-name>` (within same namespace)

## Reset to Baseline

To restore the original configuration:

```bash
./reset.sh
```

## Related Exercises

- Exercise 04: ConfigMap Missing
- Exercise 08: Readiness Probe Fail
- Exercise 11: Ingress 404
- Exercise 13: Network Policy Blocked

## Additional Resources

- [Services - Kubernetes](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)

---

**Congratulations!** You've successfully diagnosed and fixed a service selector mismatch!

**Next Exercise:** `cd ../04-configmap-missing`
