# Exercise 09: PVC Pending

**Difficulty:** ⭐⭐⭐ Intermediate
**Estimated Time:** 20 minutes

## Learning Objectives

- Understand Persistent Volume Claims (PVCs)
- Diagnose PVC provisioning issues
- Learn about StorageClasses
- Fix storage provisioning problems

## Scenario

The StorageClass has been deleted, causing the Postgres PVC to be stuck in Pending state. When the postgres pod is restarted, it cannot start because the volume cannot be provisioned.

## Breaking the Application

Run the break script:
```bash
./break.sh
```

## The Fix

Recreate the StorageClass:
```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: Immediate
EOF
```

---
**Next Exercise:** `cd ../10-dns-not-working`
