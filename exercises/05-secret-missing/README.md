# Exercise 05: Secret Missing

**Difficulty:** ⭐⭐ Basic
**Estimated Time:** 20 minutes

## Learning Objectives

- Understand Kubernetes Secrets
- Diagnose missing Secret issues
- Learn the difference between ConfigMaps and Secrets
- Fix Secret dependency problems
- Understand base64 encoding in Secrets

## Scenario

The backend Secret containing database credentials has been accidentally deleted. Existing backend pods still work (they loaded the secret at startup), but new pods fail to start because they can't access the required credentials.

Your task is to diagnose why new pods won't start and recreate the missing Secret.

## Visual Impact

- ❌ Cannot scale backend deployment
- ❌ New pods stuck in CreateContainerConfigError
- ❌ Existing pods work (until restarted)
- ❌ Cannot perform rolling updates
- ❌ Pod restarts fail

## Prerequisites

- Baseline application is deployed and working
- You can access the dashboard at http://taskmaster.local
- All pods are currently in Running state

## Breaking the Application

Run the break script to introduce the issue:

```bash
./break.sh
```

This script will delete the backend Secret and trigger a pod restart.

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
- `STATUS`: CreateContainerConfigError indicates configuration issue
- Similar to Exercise 04, but this time it's a Secret

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
  Warning  Failed     Error: secret "backend-secret" not found
```

**Key Information:**
- Error says Secret is missing
- Container can't start without it

### Step 3: Check Secrets

```bash
kubectl get secrets -n taskmaster
```

**Expected Output:**
```
NAME              TYPE     DATA   AGE
database-secret   Opaque   3      20m
```

**Analysis:** backend-secret is missing!

### Step 4: List All Secrets in Detail

```bash
kubectl get secrets -n taskmaster -o wide
```

### Step 5: Check Deployment Configuration

```bash
kubectl get deployment backend -n taskmaster -o yaml | grep -A 10 "secretRef\|secretKeyRef"
```

**What to look for:**
```yaml
envFrom:
- secretRef:
    name: backend-secret  ← Deployment references this Secret
```

But the Secret doesn't exist!

## Root Cause

The backend deployment references a Secret that no longer exists:

**Deployment Configuration:**
```yaml
spec:
  containers:
  - name: backend
    envFrom:
    - secretRef:
        name: backend-secret  ← This Secret is missing!
```

**Missing Secret:**
```
kubectl get secret backend-secret -n taskmaster
Error from server (NotFound): secrets "backend-secret" not found
```

**Result:** Pods can't be created because required credentials are missing.

## The Fix

### Recreate the Secret

The backend Secret should contain database connection information:

```bash
kubectl create secret generic backend-secret -n taskmaster \
  --from-literal=DB_HOST=postgres-svc \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=taskmaster
```

### Alternative: Apply from YAML

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: taskmaster
type: Opaque
stringData:  # Use stringData for plain text (auto-encoded to base64)
  DB_HOST: "postgres-svc"
  DB_PORT: "5432"
  DB_NAME: "taskmaster"
```

Save as `backend-secret.yaml` and apply:
```bash
kubectl apply -f backend-secret.yaml
```

### Alternative: Using Base64 Encoded Data

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: taskmaster
type: Opaque
data:  # Base64 encoded values
  DB_HOST: cG9zdGdyZXMtc3Zj      # postgres-svc
  DB_PORT: NTQzMg==              # 5432
  DB_NAME: dGFza21hc3Rlcg==      # taskmaster
```

### Using the Auto-Fix Script

```bash
./fix.sh
```

This script will automatically recreate the Secret.

## Verification

After recreating the Secret:

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

### 3. Check Secret Exists

```bash
kubectl get secret backend-secret -n taskmaster
kubectl describe secret backend-secret -n taskmaster
```

Note: Secret values are NOT shown in describe output (for security).

### 4. Check Dashboard

Visit http://taskmaster.local - backend should show green status.

## Key Learnings

### What are Secrets?

- Store sensitive data (passwords, tokens, keys)
- Base64 encoded (NOT encrypted by default)
- Similar to ConfigMaps but for sensitive info
- Access can be restricted with RBAC

### ConfigMaps vs Secrets

| Feature | ConfigMap | Secret |
|---------|-----------|--------|
| Purpose | Non-sensitive config | Sensitive data |
| Encoding | Plain text | Base64 |
| Size Limit | 1MB | 1MB |
| Visibility | Visible in describe | Hidden in describe |
| Use Cases | App config, env vars | Passwords, tokens, keys |

### How Pods Use Secrets

**As Environment Variables:**
```yaml
envFrom:
- secretRef:
    name: backend-secret
```

**Individual Variables:**
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: backend-secret
      key: password
```

**As Volume Mounts:**
```yaml
volumes:
- name: secrets
  secret:
    secretName: backend-secret
```

### Common Secret Issues

1. **Secret doesn't exist** (like this exercise)
2. **Typo in Secret name**
3. **Secret in wrong namespace**
4. **Missing required keys**
5. **Incorrect base64 encoding**
6. **Secret deleted while in use**

### Base64 Encoding

Secrets use base64 encoding:

```bash
# Encode
echo -n "mypassword" | base64
# Output: bXlwYXNzd29yZA==

# Decode
echo "bXlwYXNzd29yZA==" | base64 -d
# Output: mypassword
```

**Important:** Base64 is NOT encryption! Anyone with cluster access can decode Secrets.

### Debugging Tools

- `kubectl get secrets` - List Secrets
- `kubectl describe secret` - View Secret metadata (not values!)
- `kubectl get secret <name> -o yaml` - View Secret with base64 values
- `kubectl describe pod` - See why container can't be created

### Security Best Practices

1. **Use RBAC** to restrict Secret access
2. **Enable encryption at rest** for Secrets
3. **Use external secret managers** (Vault, AWS Secrets Manager)
4. **Don't commit Secrets to git**
5. **Rotate Secrets regularly**
6. **Use separate Secrets per app/environment**

## Common Mistakes

1. ❌ Storing Secrets in git repositories
2. ❌ Using ConfigMaps for sensitive data
3. ❌ Deleting Secrets without checking dependencies
4. ❌ Not encoding values properly
5. ❌ Sharing Secrets across multiple applications

## Secret Types

Kubernetes supports different Secret types:

- `Opaque` - Generic secret (default)
- `kubernetes.io/service-account-token` - Service account token
- `kubernetes.io/dockerconfigjson` - Docker registry credentials
- `kubernetes.io/tls` - TLS certificate and key
- `kubernetes.io/ssh-auth` - SSH authentication
- `kubernetes.io/basic-auth` - Basic authentication

## Creating Secrets (Different Methods)

### From Literals

```bash
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123
```

### From Files

```bash
kubectl create secret generic my-secret \
  --from-file=ssh-privatekey=~/.ssh/id_rsa \
  --from-file=ssh-publickey=~/.ssh/id_rsa.pub
```

### From YAML (with stringData)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
stringData:  # Auto-converted to base64
  username: admin
  password: secret123
```

## Reset to Baseline

To restore the original configuration:

```bash
./reset.sh
```

## Related Exercises

- Exercise 04: ConfigMap Missing
- Exercise 12: RBAC Forbidden

## Additional Resources

- [Secrets - Kubernetes](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Distribute Credentials Securely](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/)
- [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)

---

**Congratulations!** You've successfully diagnosed and fixed a missing Secret issue!

**Next Exercise:** `cd ../06-oom-killed`
