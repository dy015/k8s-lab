# Kubernetes Break & Fix Workshop - Overview

## Welcome to the Workshop!

This hands-on workshop teaches Kubernetes troubleshooting through practical experience. You'll deploy a real 3-tier application and systematically break and repair it through 15 progressive exercises.

## Workshop Philosophy

**"The best way to learn troubleshooting is by troubleshooting."**

Instead of passive learning, you'll:
- Deploy real applications
- Encounter real problems
- Use real debugging tools
- Develop real troubleshooting skills

## What You'll Build

A complete 3-tier web application called **TaskMaster**:
- **Frontend**: Responsive web dashboard (nginx)
- **Backend**: RESTful API (Python Flask)
- **Database**: Persistent data store (PostgreSQL)

All deployed on Kubernetes with proper networking, storage, and ingress configuration.

## Workshop Structure

### Hour 0-1: Foundation
- Install k3s Kubernetes cluster
- Deploy baseline application
- Verify everything works
- Access the dashboard
- Understand the architecture

### Hour 1-3: Basic Issues (Exercises 01-05)
**Focus**: Pod-level problems

- Exercise 01: CrashLoopBackOff (misconfigured command)
- Exercise 02: ImagePullBackOff (wrong image tag)
- Exercise 03: Service Unreachable (selector mismatch)
- Exercise 04: ConfigMap Missing (deleted configuration)
- Exercise 05: Secret Missing (missing credentials)

**Skills**: kubectl basics, pod debugging, resource inspection

### Hour 3-6: Resource Management (Exercises 06-10)
**Focus**: Resource limits and probes

- Exercise 06: OOM Killed (memory limits)
- Exercise 07: Liveness Probe Fail (wrong health endpoint)
- Exercise 08: Readiness Probe Fail (probe timing)
- Exercise 09: PVC Pending (storage issues)
- Exercise 10: DNS Not Working (CoreDNS problems)

**Skills**: Resource management, health checks, storage, DNS troubleshooting

### Hour 6-10: Advanced Topics (Exercises 11-15)
**Focus**: Networking and operations

- Exercise 11: Ingress 404 (routing issues)
- Exercise 12: RBAC Forbidden (permission problems)
- Exercise 13: Network Policy Blocked (network segmentation)
- Exercise 14: Node Pressure (disk pressure)
- Exercise 15: Rollout Stuck (deployment updates)

**Skills**: Networking, security, node management, deployments

## Learning Methodology

Each exercise follows a consistent pattern:

### 1. Break (3-5 minutes)
Run `./break.sh` to introduce the issue
- Application breaks in a specific way
- You see the symptoms
- Dashboard shows the problem

### 2. Troubleshoot (10-15 minutes)
Use kubectl to investigate
- Check pod status
- Review events
- Examine logs
- Describe resources
- Find the root cause

### 3. Fix (5 minutes)
Apply the fix
- Manual fix (recommended for learning)
- Or use `./fix.sh` to see the solution
- Understand why it works

### 4. Verify (2-3 minutes)
Confirm the fix worked
- Run `./verify.sh`
- Check dashboard
- Test functionality
- Ensure everything is healthy

### 5. Reset (1-2 minutes)
Return to baseline
- Run `./reset.sh`
- Ready for next exercise
- Clean slate

## Key Learning Outcomes

By the end of this workshop, you will:

### Technical Skills
- Master essential kubectl commands
- Debug pod failures effectively
- Understand Kubernetes networking
- Troubleshoot service connectivity
- Manage resource limits and quotas
- Configure health probes correctly
- Work with ConfigMaps and Secrets
- Implement RBAC policies
- Use Network Policies
- Handle storage issues
- Manage deployments and rollouts

### Troubleshooting Mindset
- Systematic problem investigation
- Reading error messages effectively
- Using logs and events
- Understanding cause and effect
- Knowing where to look for issues
- Building mental models of systems

### Operational Knowledge
- Production-ready deployments
- Security best practices
- Resource optimization
- Monitoring and observability
- Incident response patterns
- Prevention strategies

## Workshop Prerequisites

### System Requirements
- CentOS 7.9+, CentOS 8 Stream, or Rocky Linux 8
- 4GB RAM minimum (8GB recommended)
- 2 CPU cores minimum (4 recommended)
- 20GB disk space minimum
- Root or sudo access
- Internet connection

### Knowledge Prerequisites
- Basic Linux command line skills
- Understanding of containers (Docker/Podman)
- Basic networking concepts
- Familiarity with YAML
- Text editor skills (vi/nano)

**No prior Kubernetes experience required!** This workshop teaches you from the ground up.

## Tools You'll Use

### Essential kubectl Commands
```bash
# Pod management
kubectl get pods
kubectl describe pod <name>
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- /bin/sh

# Deployments
kubectl get deployments
kubectl describe deployment <name>
kubectl rollout status deployment/<name>

# Services and networking
kubectl get svc
kubectl get endpoints
kubectl describe svc <name>

# Configuration
kubectl get configmaps
kubectl get secrets
kubectl describe configmap <name>

# Debugging
kubectl get events
kubectl top nodes
kubectl top pods
```

### Helper Scripts Provided
- Automated setup scripts
- Verification scripts
- Cleanup scripts
- Exercise scripts (break/fix/verify/reset)

## Workshop Environment

### What's Provided
- Complete Kubernetes cluster (k3s)
- Pre-built Docker images (on Docker Hub)
- Fully configured baseline application
- 15 ready-to-run exercises
- Comprehensive documentation
- Troubleshooting guides

### What You'll Set Up
- Kubernetes cluster installation (automated)
- Application deployment (automated)
- /etc/hosts entry (manual)

## Time Investment

### Minimum (Fast Track)
- Setup: 30 minutes
- Core exercises (01-08): 2-3 hours
- **Total**: 3-4 hours

### Recommended (Full Experience)
- Setup: 30 minutes
- All exercises (01-15): 6-8 hours
- Review and practice: 1-2 hours
- **Total**: 8-10 hours

### Extended (Mastery)
- Full workshop: 8-10 hours
- Repeat exercises: 2-3 hours
- Custom scenarios: 2-3 hours
- **Total**: 12-16 hours

## Success Criteria

You'll know you've succeeded when you can:

1. ✅ Deploy a Kubernetes application from scratch
2. ✅ Diagnose why pods aren't starting
3. ✅ Fix service connectivity issues
4. ✅ Debug configuration problems
5. ✅ Resolve resource limit issues
6. ✅ Troubleshoot networking problems
7. ✅ Handle storage issues
8. ✅ Manage deployments confidently

## Support Resources

### Documentation
- `README.md` - Main workshop guide
- `QUICKSTART.md` - Fast setup guide
- `docs/` - Comprehensive documentation
- `exercises/*/README.md` - Exercise guides

### Troubleshooting
- Exercise-specific troubleshooting in each README
- `docs/03-troubleshooting-guide.md` - General troubleshooting
- `docs/05-common-issues.md` - FAQ and common problems
- Log files in `/tmp/k8s-workshop-*.log`

### Community
- GitHub Issues for bug reports
- Discussion forums for questions
- Share your solutions and learn from others

## Workshop Variations

### Self-Paced Learning
- Work at your own speed
- Take breaks between exercises
- Repeat challenging exercises
- Skip exercises if needed

### Instructor-Led Training
- Follow instructor's pace
- Ask questions during exercises
- Collaborate with peers
- Structured learning path

### Team Workshop
- Pair programming approach
- Rotate driver/navigator roles
- Discuss solutions as a team
- Learn from each other

## After the Workshop

### Next Steps
1. Practice exercises again
2. Deploy your own applications
3. Explore advanced Kubernetes features
4. Study for CKA/CKAD certifications
5. Share knowledge with your team

### Additional Learning
- Kubernetes documentation
- Official tutorials
- Advanced workshops
- Community resources
- Production case studies

## Getting Started

Ready to begin? Follow these steps:

1. **Read** `QUICKSTART.md` for setup instructions
2. **Install** the Kubernetes cluster
3. **Deploy** the baseline application
4. **Start** with Exercise 01
5. **Learn** by doing!

---

**Remember**: Breaking things is the best way to learn how they work. Don't be afraid to experiment!

**Good luck and enjoy the workshop!** 🚀
