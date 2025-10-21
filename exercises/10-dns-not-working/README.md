# Exercise 10: DNS Not Working

**Difficulty:** ⭐⭐⭐⭐ Advanced
**Estimated Time:** 25 minutes

## Learning Objectives

- Understand Kubernetes DNS (CoreDNS)
- Diagnose DNS resolution failures
- Learn about system components
- Fix DNS service issues

## Scenario

CoreDNS has been scaled down to 0 replicas, causing DNS resolution to fail. Services cannot be reached by name, breaking service discovery.

## Breaking the Application

Run the break script:
```bash
./break.sh
```

## The Fix

Scale CoreDNS back up:
```bash
kubectl scale deployment coredns -n kube-system --replicas=2
```

---
**Next Exercise:** `cd ../11-ingress-404`
