# TaskMaster Application Architecture

## Overview

TaskMaster is a 3-tier web application designed to demonstrate real-world Kubernetes deployments. It's a task management system with a web interface, REST API, and persistent database.

## Application Stack

```
┌─────────────────────────────────────────────────────────┐
│  Tier 1: Presentation Layer                             │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Frontend (nginx)                                 │  │
│  │  - HTML/CSS/JavaScript                            │  │
│  │  - Responsive dashboard                           │  │
│  │  - Real-time status monitoring                    │  │
│  └───────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTP/REST API
┌──────────────────────▼──────────────────────────────────┐
│  Tier 2: Application Layer                              │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Backend (Python Flask + gunicorn)                │  │
│  │  - RESTful API                                    │  │
│  │  - Business logic                                 │  │
│  │  - Database abstraction                           │  │
│  └───────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │ PostgreSQL Protocol
┌──────────────────────▼──────────────────────────────────┐
│  Tier 3: Data Layer                                     │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Database (PostgreSQL)                            │  │
│  │  - Persistent storage                             │  │
│  │  - Relational data                                │  │
│  │  - ACID transactions                              │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Kubernetes Resources

### Namespace

All application resources reside in the `taskmaster` namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: taskmaster
```

**Purpose:**
- Logical isolation from system resources
- Resource quotas and limits scoping
- RBAC policy boundaries
- Clean organization

### Frontend Components

#### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: taskmaster
spec:
  replicas: 2  # High availability
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: docker.io/reddydodda/taskmaster-frontend:1.0
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
```

**Key Features:**
- 2 replicas for availability
- Resource limits prevent overconsumption
- Nginx serves static files
- Port 80 for HTTP

#### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: taskmaster
spec:
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: ClusterIP
```

**Purpose:**
- Stable endpoint for frontend pods
- Load balancing across replicas
- Service discovery via DNS

### Backend Components

#### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: taskmaster
data:
  FLASK_ENV: "production"
  LOG_LEVEL: "info"
  WORKERS: "2"
```

**Purpose:**
- Non-sensitive configuration
- Environment-specific settings
- Easy updates without image rebuilds

#### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: taskmaster
type: Opaque
stringData:
  DB_HOST: "postgres-svc"
  DB_PORT: "5432"
  DB_NAME: "taskmaster"
```

**Purpose:**
- Sensitive configuration data
- Database connection details
- Credentials management

#### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: taskmaster
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: docker.io/reddydodda/taskmaster-backend:1.0
        ports:
        - containerPort: 5000
        envFrom:
        - configMapRef:
            name: backend-config
        - secretRef:
            name: backend-secret
        env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: POSTGRES_USER
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: POSTGRES_PASSWORD
        livenessProbe:
          httpGet:
            path: /api/health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

**Key Features:**
- 2 replicas for load balancing
- Environment variables from ConfigMap and Secret
- Health probes for reliability
- Resource limits for stability
- Gunicorn WSGI server for production

#### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: taskmaster
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 5000
    targetPort: 5000
  type: ClusterIP
```

### Database Components

#### Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: database-secret
  namespace: taskmaster
type: Opaque
stringData:
  POSTGRES_USER: "taskuser"
  POSTGRES_PASSWORD: "taskpass123"
  POSTGRES_DB: "taskmaster"
```

#### ConfigMap (Initialization Script)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: database-init
  namespace: taskmaster
data:
  init.sql: |
    CREATE TABLE IF NOT EXISTS tasks (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT,
        status VARCHAR(50) DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    INSERT INTO tasks (title, description, status) VALUES
    ('Setup Kubernetes Cluster', 'Install k3s on CentOS', 'completed'),
    ('Deploy Application', 'Deploy TaskMaster app', 'completed'),
    ('Start Exercises', 'Begin break-fix exercises', 'in_progress');
```

**Purpose:**
- Database schema creation
- Seed data insertion
- Automatic initialization

#### PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: taskmaster
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
```

**Purpose:**
- Persistent data storage
- Survives pod restarts
- Automatic volume provisioning

#### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: taskmaster
spec:
  replicas: 1  # Single instance (stateful)
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        envFrom:
        - secretRef:
            name: database-secret
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        - name: init-script
          mountPath: /docker-entrypoint-initdb.d
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
      - name: init-script
        configMap:
          name: database-init
```

**Key Features:**
- Single replica (stateful workload)
- Persistent volume for data
- Initialization script from ConfigMap
- PostgreSQL 15 Alpine (small image)

#### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-svc
  namespace: taskmaster
spec:
  selector:
    app: postgres
  ports:
  - protocol: TCP
    port: 5432
    targetPort: 5432
  type: ClusterIP
```

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: taskmaster-ingress
  namespace: taskmaster
spec:
  ingressClassName: nginx
  rules:
  - host: taskmaster.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-svc
            port:
              number: 5000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
```

**Routing Rules:**
- `/api/*` → backend-svc:5000
- `/*` → frontend-svc:80
- Host-based routing for taskmaster.local

## Application Flow

### Complete Request Flow

#### 1. Page Load

```
User Browser
     │
     │ GET http://taskmaster.local/
     ▼
Ingress Controller (nginx)
     │
     │ Route: / → frontend-svc
     ▼
Frontend Service (ClusterIP: 10.43.x.x:80)
     │
     │ Load balance to endpoints
     ▼
Frontend Pod (10.42.x.x:80)
     │
     │ nginx serves index.html
     ▼
User Browser
```

#### 2. API Request

```
User Browser (JavaScript)
     │
     │ GET http://taskmaster.local/api/tasks
     ▼
Ingress Controller
     │
     │ Route: /api → backend-svc
     ▼
Backend Service (ClusterIP: 10.43.y.y:5000)
     │
     │ Load balance to endpoints
     ▼
Backend Pod (10.42.y.y:5000)
     │
     │ Flask application processes request
     │
     │ Query database
     ▼
Database Service (ClusterIP: 10.43.z.z:5432)
     │
     ▼
Database Pod (10.42.z.z:5432)
     │
     │ PostgreSQL executes query
     │
     │ Return results
     ▼
Backend Pod
     │
     │ Format JSON response
     ▼
User Browser (displays tasks)
```

## API Endpoints

### Health Check

```
GET /api/health

Response:
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2025-01-19T12:00:00"
}
```

### Get All Tasks

```
GET /api/tasks

Response:
{
  "tasks": [
    {
      "id": 1,
      "title": "Setup Kubernetes",
      "description": "Install k3s",
      "status": "completed",
      "created_at": "2025-01-19T10:00:00",
      "updated_at": "2025-01-19T10:30:00"
    }
  ],
  "count": 1
}
```

### Create Task

```
POST /api/tasks
Content-Type: application/json

{
  "title": "New Task",
  "description": "Task description",
  "status": "pending"
}

Response:
{
  "id": 4,
  "title": "New Task",
  "description": "Task description",
  "status": "pending",
  "created_at": "2025-01-19T12:00:00"
}
```

### Update Task

```
PUT /api/tasks/4
Content-Type: application/json

{
  "status": "in_progress"
}

Response:
{
  "message": "Task updated successfully"
}
```

### Delete Task

```
DELETE /api/tasks/4

Response:
{
  "message": "Task deleted successfully"
}
```

### Database Status

```
GET /api/db-status

Response:
{
  "connected": true,
  "database": "taskmaster",
  "user": "taskuser",
  "host": "postgres-svc"
}
```

## Database Schema

```sql
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_created_at ON tasks(created_at);
```

## Resource Requirements

### Minimum Cluster Resources

```
Component   | CPU Request | Memory Request | CPU Limit | Memory Limit
------------|-------------|----------------|-----------|-------------
Frontend    | 100m × 2    | 128Mi × 2      | 200m × 2  | 256Mi × 2
Backend     | 200m × 2    | 256Mi × 2      | 500m × 2  | 512Mi × 2
Database    | 200m × 1    | 256Mi × 1      | 500m × 1  | 512Mi × 1
------------|-------------|----------------|-----------|-------------
Total App   | 900m        | 1024Mi (1GB)   | 2400m     | 2560Mi (2.5GB)
System      | 700m        | 800Mi          | -         | -
------------|-------------|----------------|-----------|-------------
Cluster Min | 1.6 cores   | 1.8GB          | 4 cores   | 4GB (recommended)
```

## High Availability Design

### Current Setup

- Frontend: 2 replicas (can lose 1 pod)
- Backend: 2 replicas (can lose 1 pod)
- Database: 1 replica (single point of failure)

### Pod Disruption

**What happens if a pod dies?**

**Frontend:**
- Requests route to remaining replica
- No downtime
- Kubernetes creates new pod

**Backend:**
- Requests route to remaining replica
- Slight performance impact
- No data loss
- New pod created automatically

**Database:**
- Service unavailable until pod restarts
- Data persists (PersistentVolume)
- Downtime: 30-60 seconds

### Production Improvements

**Database HA Options:**
1. PostgreSQL replication (primary + replicas)
2. External managed database (RDS, Cloud SQL)
3. StatefulSet with persistent storage
4. Database clustering (Patroni, Stolon)

## Application Configuration

### Environment Variables

**Frontend:**
- None required (static files)

**Backend:**
- `FLASK_ENV`: production/development
- `LOG_LEVEL`: debug/info/warning/error
- `WORKERS`: Number of gunicorn workers
- `DB_HOST`: Database hostname
- `DB_PORT`: Database port
- `DB_NAME`: Database name
- `DB_USER`: Database username (from secret)
- `DB_PASSWORD`: Database password (from secret)

**Database:**
- `POSTGRES_USER`: Database user
- `POSTGRES_PASSWORD`: Database password
- `POSTGRES_DB`: Database name

## Monitoring and Health

### Liveness Probes

**Purpose:** Is the application alive?

**Backend Liveness:**
```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: 5000
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 3
```

**Action on Failure:** Pod is restarted

### Readiness Probes

**Purpose:** Is the application ready to serve traffic?

**Backend Readiness:**
```yaml
readinessProbe:
  httpGet:
    path: /api/health
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

**Action on Failure:** Pod removed from service endpoints

### Application Logs

**Frontend (nginx):**
```bash
kubectl logs -n taskmaster -l app=frontend --tail=100
```

**Backend (Flask):**
```bash
kubectl logs -n taskmaster -l app=backend --tail=100 -f
```

**Database (PostgreSQL):**
```bash
kubectl logs -n taskmaster -l app=postgres --tail=100
```

## Security Considerations

### Network Security

- All communication within cluster is encrypted (optional)
- Ingress provides external access point
- Services use ClusterIP (internal only)
- NetworkPolicies can restrict pod-to-pod communication

### Secret Management

- Database credentials stored in Secrets
- Base64 encoded (not encrypted by default)
- Access controlled via RBAC
- Mounted as environment variables

### Container Security

- Non-root user in containers (best practice)
- Read-only root filesystem where possible
- Security contexts define privileges
- Image scanning for vulnerabilities

## Scaling Considerations

### Horizontal Scaling

**Frontend:**
```bash
kubectl scale deployment frontend -n taskmaster --replicas=4
```

**Backend:**
```bash
kubectl scale deployment backend -n taskmaster --replicas=4
```

**Database:**
- Requires replication setup
- Cannot simply scale replicas
- Consider read replicas

### Vertical Scaling

**Increase Resources:**
```bash
kubectl set resources deployment backend -n taskmaster \
  --limits=cpu=1000m,memory=1Gi \
  --requests=cpu=500m,memory=512Mi
```

## Troubleshooting Common Issues

### Frontend Not Loading

1. Check frontend pods: `kubectl get pods -n taskmaster -l app=frontend`
2. Check ingress: `kubectl get ingress -n taskmaster`
3. Check service endpoints: `kubectl get endpoints frontend-svc -n taskmaster`
4. Check nginx logs: `kubectl logs -n taskmaster -l app=frontend`

### API Not Responding

1. Check backend pods: `kubectl get pods -n taskmaster -l app=backend`
2. Check backend service: `kubectl get svc backend-svc -n taskmaster`
3. Test from frontend pod: `kubectl exec -n taskmaster <frontend-pod> -- wget -qO- http://backend-svc:5000/api/health`
4. Check logs: `kubectl logs -n taskmaster -l app=backend`

### Database Connection Errors

1. Check database pod: `kubectl get pods -n taskmaster -l app=postgres`
2. Check PVC: `kubectl get pvc -n taskmaster`
3. Verify credentials: `kubectl get secret database-secret -n taskmaster -o yaml`
4. Test connection: `kubectl exec -n taskmaster <backend-pod> -- pg_isready -h postgres-svc`

---

**Next**: [Troubleshooting Guide](03-troubleshooting-guide.md)
