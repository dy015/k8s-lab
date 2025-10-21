# Exercise 15: Rollout Stuck

**Difficulty:** ⭐⭐⭐⭐ Advanced
**Estimated Time:** 25 minutes

## Learning Objectives

- Understand deployment rollouts
- Diagnose stuck rollouts
- Rollback deployments

## Scenario

Backend updated with invalid image and maxUnavailable: 0, causing rollout to get stuck.

## The Fix

Rollback the deployment:
```bash
kubectl rollout undo deployment backend -n taskmaster
```

---
**Congratulations!** You've completed all exercises!
