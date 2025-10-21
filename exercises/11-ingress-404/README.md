# Exercise 11: Ingress 404

**Difficulty:** ⭐⭐⭐ Intermediate
**Estimated Time:** 20 minutes

## Learning Objectives

- Understand Kubernetes Ingress
- Diagnose routing issues
- Fix Ingress path configuration

## Scenario

The Ingress path has been changed from / to /wrong-path, causing 404 errors when accessing the frontend.

## The Fix

Update the Ingress path:
```bash
kubectl patch ingress taskmaster-ingress -n taskmaster --type='json' -p='[
  {"op": "replace", "path": "/spec/rules/0/http/paths/0/path", "value": "/"}
]'
```

---
**Next Exercise:** `cd ../12-rbac-forbidden`
