# Kubernetes Cluster Architecture

## Overview

This workshop uses k3s, a lightweight Kubernetes distribution designed for edge computing, IoT, and development environments. It provides a full Kubernetes experience with a smaller footprint.

## Why k3s?

**Advantages for Learning:**
- Single binary installation
- Low resource requirements (512MB RAM minimum)
- Fast startup (under 1 minute)
- Full Kubernetes API compatibility
- Perfect for single-node setups
- Easy to install and uninstall

**Production-Ready:**
- CNCF certified Kubernetes distribution
- Used in production by many companies
- Same API as full Kubernetes
- Supports standard Kubernetes features

## Cluster Components

### Control Plane

The k3s control plane includes:

```
┌─────────────────────────────────────────┐
│         k3s Control Plane                │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  API Server                       │   │
│  │  - kubectl entry point            │   │
│  │  - REST API for cluster           │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  Scheduler                        │   │
│  │  - Assigns pods to nodes          │   │
│  │  - Resource-based decisions       │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  Controller Manager               │   │
│  │  - Deployment controller          │   │
│  │  - ReplicaSet controller          │   │
│  │  - Service controller             │   │
│  │  - Endpoint controller            │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  etcd (embedded)                  │   │
│  │  - Cluster state storage          │   │
│  │  - Configuration data             │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Worker Node Components

```
┌─────────────────────────────────────────┐
│         k3s Node                         │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  kubelet                          │   │
│  │  - Manages pods on node           │   │
│  │  - Reports to API server          │   │
│  │  - Executes container runtime     │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  containerd                       │   │
│  │  - Container runtime              │   │
│  │  - Pulls images                   │   │
│  │  - Runs containers                │   │
│  └──────────────────────────────────┘   │
│                                          │
│  ┌──────────────────────────────────┐   │
│  │  kube-proxy                       │   │
│  │  - Network rules                  │   │
│  │  - Service load balancing         │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

## Network Architecture

### Pod Network (Flannel)

k3s uses Flannel for pod networking:

```
┌─────────────────────────────────────────────────────────┐
│  Pod Network (10.42.0.0/16)                             │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Pod          │  │ Pod          │  │ Pod          │  │
│  │ 10.42.0.2    │  │ 10.42.0.3    │  │ 10.42.0.4    │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                  │                  │         │
│         └──────────────────┴──────────────────┘         │
│                            │                            │
│                    ┌───────▼───────┐                    │
│                    │  cni0 Bridge  │                    │
│                    └───────┬───────┘                    │
│                            │                            │
│                    ┌───────▼───────┐                    │
│                    │  flannel.1    │                    │
│                    └───────┬───────┘                    │
│                            │                            │
└────────────────────────────┼────────────────────────────┘
                             │
                      ┌──────▼──────┐
                      │  Host NIC   │
                      └─────────────┘
```

**Flannel Features:**
- VXLAN overlay network
- Automatic IP address management
- Cross-node pod communication
- Simple and reliable

### Service Network

Services use ClusterIP by default:

```
┌─────────────────────────────────────────────────────────┐
│  Service Network (10.43.0.0/16)                         │
│                                                          │
│  ┌──────────────────────────────────────────────┐       │
│  │  Service: backend-svc (10.43.100.50)         │       │
│  │  Selector: app=backend                       │       │
│  └─────────────────┬────────────────────────────┘       │
│                    │                                     │
│       ┌────────────┼────────────┐                       │
│       │            │            │                        │
│   ┌───▼───┐    ┌───▼───┐    ┌───▼───┐                  │
│   │ Pod   │    │ Pod   │    │ Pod   │                   │
│   │backend│    │backend│    │backend│                   │
│   │ :5000 │    │ :5000 │    │ :5000 │                   │
│   └───────┘    └───────┘    └───────┘                   │
│   Endpoint     Endpoint     Endpoint                    │
└─────────────────────────────────────────────────────────┘
```

**kube-proxy** implements service routing using iptables rules.

### DNS Architecture

CoreDNS provides cluster DNS:

```
┌─────────────────────────────────────────────────────────┐
│  DNS Resolution in Cluster                              │
│                                                          │
│  Pod Query: backend-svc.taskmaster.svc.cluster.local    │
│                            │                            │
│                    ┌───────▼────────┐                   │
│                    │   CoreDNS Pod  │                   │
│                    │  (kube-system) │                   │
│                    └───────┬────────┘                   │
│                            │                            │
│                  ┌─────────▼──────────┐                 │
│                  │  Returns ClusterIP │                 │
│                  │    10.43.100.50    │                 │
│                  └────────────────────┘                 │
└─────────────────────────────────────────────────────────┘
```

**DNS Records:**
- Services: `<service>.<namespace>.svc.cluster.local`
- Pods: `<pod-ip>.<namespace>.pod.cluster.local`
- Short names: `<service>` (within same namespace)

## Storage Architecture

### Local Path Provisioner

k3s includes a local-path storage provisioner:

```
┌─────────────────────────────────────────────────────────┐
│  Storage Architecture                                    │
│                                                          │
│  ┌─────────────────────────────────────────────┐        │
│  │  PersistentVolumeClaim (PVC)                │        │
│  │  - Name: postgres-pvc                       │        │
│  │  - Size: 5Gi                                │        │
│  │  - StorageClass: local-path                 │        │
│  └──────────────────┬──────────────────────────┘        │
│                     │                                    │
│                     │ (Provisioner creates)              │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────┐        │
│  │  PersistentVolume (PV)                      │        │
│  │  - Automatically created                    │        │
│  │  - Path: /var/lib/rancher/k3s/storage/...  │        │
│  └──────────────────┬──────────────────────────┘        │
│                     │                                    │
│                     │ (Mounted to pod)                   │
│                     ▼                                    │
│  ┌─────────────────────────────────────────────┐        │
│  │  Pod Volume Mount                           │        │
│  │  - mountPath: /var/lib/postgresql/data     │        │
│  └─────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────┘
```

**Storage Features:**
- Automatic PV provisioning
- Local node storage
- Persistent data across pod restarts
- Simple and fast

## Ingress Architecture

### nginx-ingress-controller

```
┌─────────────────────────────────────────────────────────┐
│  Ingress Flow                                            │
│                                                          │
│  User Browser                                            │
│       │                                                  │
│       │ http://taskmaster.local                          │
│       ▼                                                  │
│  ┌─────────────────────────────────────────────┐        │
│  │  nginx-ingress-controller                   │        │
│  │  - HostPort 80, 443                         │        │
│  │  - Reads Ingress resources                  │        │
│  └──────────────────┬──────────────────────────┘        │
│                     │                                    │
│       ┌─────────────┼──────────────┐                    │
│       │ Path: /     │              │ Path: /api         │
│       ▼             │              ▼                     │
│  ┌─────────┐        │         ┌──────────┐              │
│  │Frontend │        │         │ Backend  │              │
│  │Service  │        │         │ Service  │              │
│  │Port: 80 │        │         │Port: 5000│              │
│  └────┬────┘        │         └─────┬────┘              │
│       │             │               │                    │
│   ┌───▼───┐         │           ┌───▼───┐               │
│   │ Pods  │         │           │ Pods  │               │
│   └───────┘         │           └───────┘               │
└─────────────────────────────────────────────────────────┘
```

**Ingress Features:**
- HTTP/HTTPS routing
- Path-based routing
- Host-based routing
- TLS termination (optional)

## System Pods

Essential system pods in kube-system namespace:

```bash
NAMESPACE     NAME                                     READY   STATUS
kube-system   coredns-xxx                              1/1     Running  # DNS
kube-system   local-path-provisioner-xxx               1/1     Running  # Storage
kube-system   metrics-server-xxx                       1/1     Running  # Metrics
kube-system   nginx-ingress-controller-xxx             1/1     Running  # Ingress
```

### CoreDNS
- Provides DNS resolution for services and pods
- Critical for service discovery
- Usually runs 2 replicas for HA

### Local-Path-Provisioner
- Automatically creates PersistentVolumes
- Uses local node storage
- Essential for stateful applications

### Metrics-Server
- Collects resource metrics from nodes and pods
- Enables `kubectl top` commands
- Used by Horizontal Pod Autoscaler

### nginx-ingress-controller
- Routes external traffic to services
- Implements Ingress resources
- Provides load balancing

## Resource Allocation

### Default k3s Configuration

```yaml
API Server:
  Memory: ~200MB
  CPU: 0.2 cores

kubelet:
  Memory: ~100MB
  CPU: 0.1 cores

Container Runtime:
  Memory: ~100MB
  CPU: 0.1 cores

System Pods:
  Memory: ~400MB
  CPU: 0.3 cores

Total System Overhead:
  Memory: ~800MB
  CPU: 0.7 cores
```

**Available for Applications:**
- 4GB system: ~3.2GB for apps
- 8GB system: ~7.2GB for apps

## Security Architecture

### RBAC (Role-Based Access Control)

```
┌─────────────────────────────────────────────────────────┐
│  RBAC Structure                                          │
│                                                          │
│  ┌─────────────┐      ┌──────────────┐                  │
│  │ User/SA     │◄─────┤ RoleBinding  │                  │
│  └─────────────┘      └──────┬───────┘                  │
│                              │                           │
│                              │ binds to                  │
│                              ▼                           │
│                       ┌──────────────┐                   │
│                       │     Role     │                   │
│                       │  - verbs     │                   │
│                       │  - resources │                   │
│                       └──────────────┘                   │
└─────────────────────────────────────────────────────────┘
```

**Default Service Accounts:**
- Each namespace has a default service account
- Pods use service accounts to access API
- RBAC controls what service accounts can do

### Network Policies

```
┌─────────────────────────────────────────────────────────┐
│  Network Policy Example                                  │
│                                                          │
│  ┌────────────────┐                                      │
│  │ Frontend Pods  │──X──┐ (blocked)                      │
│  └────────────────┘     │                                │
│                         │                                │
│  ┌────────────────┐     │  ┌──────────────────┐          │
│  │ Backend Pods   │─────┼─►│ Database Pods    │          │
│  │ (allowed)      │     │  │                  │          │
│  └────────────────┘     │  └──────────────────┘          │
│                         │                                │
│              NetworkPolicy rules                         │
└─────────────────────────────────────────────────────────┘
```

**Network Policy Features:**
- Pod-to-pod traffic control
- Namespace isolation
- Ingress and egress rules
- Label-based selection

## Cluster Communication Flow

### Complete Request Flow

```
User Request → Ingress Controller → Service → Endpoint → Pod
     ↓              ↓                   ↓         ↓        ↓
  Browser      nginx-ingress      ClusterIP   iptables  Container
                                                         Process
```

**Step by Step:**
1. User makes HTTP request to http://taskmaster.local
2. Request hits nginx-ingress-controller (port 80)
3. Ingress controller checks Ingress rules
4. Routes to appropriate Service (frontend-svc)
5. Service load balances to one of its Endpoints
6. kube-proxy iptables rules DNAT to pod IP
7. Request reaches container in pod
8. Application processes request
9. Response follows reverse path

## High Availability Considerations

### Single Node Limitations

**Current Setup:**
- Single master node
- Single etcd instance
- Single point of failure

**Production Recommendations:**
- 3+ control plane nodes
- Separate etcd cluster
- Multiple worker nodes
- Load balancer for API server

### Data Persistence

**What's Persistent:**
- PersistentVolume data
- etcd cluster state
- Container images (local cache)

**What's Ephemeral:**
- Pod filesystems (unless using volumes)
- Container logs (unless exported)
- In-memory data

## Monitoring and Observability

### Built-in Monitoring

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n taskmaster

# Events
kubectl get events -n taskmaster

# Logs
kubectl logs -f <pod-name>
```

### What's Being Monitored

- CPU usage per node/pod
- Memory usage per node/pod
- Disk usage on nodes
- Network traffic
- Pod events and state changes

## Useful Cluster Commands

### Cluster Information

```bash
# Cluster info
kubectl cluster-info

# Component status
kubectl get componentstatuses

# Node details
kubectl describe node <node-name>

# API resources
kubectl api-resources

# API versions
kubectl api-versions
```

### Debugging

```bash
# System pods
kubectl get pods -n kube-system

# All resources
kubectl get all -A

# Events
kubectl get events -A --sort-by='.lastTimestamp'

# Logs from system components
kubectl logs -n kube-system <pod-name>
```

## Differences from Production Kubernetes

### k3s vs Full Kubernetes

| Feature | k3s | Full K8s |
|---------|-----|----------|
| Binary size | 50MB | 1GB+ |
| Memory usage | 512MB+ | 2GB+ |
| etcd | Embedded SQLite option | External etcd |
| Load Balancer | ServiceLB | Cloud LB |
| Ingress | nginx (optional) | Optional |
| Storage | local-path | Cloud storage |
| CNI | Flannel | Multiple options |

### What's the Same

- Full Kubernetes API
- kubectl compatibility
- Manifest compatibility
- RBAC, Network Policies
- Custom Resource Definitions (CRDs)
- All core Kubernetes concepts

---

**Next**: [Application Architecture](02-application-architecture.md)
