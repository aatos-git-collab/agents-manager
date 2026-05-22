---
name: kubernetes-development
description: kubernetes-development skill
  Develops Kubernetes integration features for Coolify. Activates when working with K8s clusters,
  deployments, services, ingress, HPA, ConfigMaps, Secrets, or kubectl operations.
---

# Kubernetes Development

## When to Apply

Activate when:
- Working with KubernetesCluster, KubernetesPipeline, KubernetesApp, KubernetesAddon models
- Creating K8s deployment manifests
- Debugging K8s deployments
- Adding K8s features to Coolify

## Coolify K8s Architecture

### Models
- `KubernetesCluster` - Cluster connection + kubeconfig storage
- `KubernetesPipeline` - Pipeline per project/environment
- `KubernetesApp` - App deployment config with scaling/HPA
- `KubernetesAddon` - Database addons (PostgreSQL, MySQL, Redis)

### Services
- `KubernetesService` - Full K8s API client (deployments, services, ingress, HPA, pods, jobs)
- `KubernetesManifestGenerator` - Generate K8s manifests from app config
- `KubernetesDeploymentJob` - Queue-based async deployment

### Key Files
```
app/Models/KubernetesCluster.php
app/Models/KubernetesApp.php
app/Services/KubernetesService.php
app/Services/KubernetesManifestGenerator.php
app/Jobs/KubernetesDeploymentJob.php
app/Livewire/Settings/KubernetesClusters.php
app/Livewire/Settings/KubernetesApps.php
```

## K8s API Basics

### Authentication
- Kubeconfig with token OR certificate-based auth
- Decode encrypted kubeconfig: `decrypt($encrypted)`
- Extract: apiServer, token, caBundle

### Common Operations
```php
// Set cluster context
$k8s = new KubernetesService();
$k8s->setCluster($cluster);

// Headers for API calls
$headers = [
    'Authorization' => 'Bearer ' . $this->token,
    'Content-Type' => 'application/json',
];

// Base URL
$baseUrl = rtrim($cluster->api_server_url, '/');
```

## Manifest Generation Pattern

### Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {app_name}
  namespace: {namespace}
spec:
  replicas: {replicas}
  selector:
    matchLabels:
      app: {app_name}
  template:
    metadata:
      labels:
        app: {app_name}
    spec:
      containers:
        - name: app
          image: {image}:{tag}
          ports:
            - containerPort: {port}
```

### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {app_name}
  namespace: {namespace}
spec:
  selector:
    app: {app_name}
  ports:
    - port: 80
      targetPort: {port}
```

### Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {app_name}
  namespace: {namespace}
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
    - host: {host}
      http:
        paths:
          - path: {path}
            pathType: Prefix
            backend:
              service:
                name: {app_name}
                port:
                  number: 80
```

## Security Rules

1. **NEVER log kubeconfig or tokens**
2. **Always encrypt kubeconfig at rest** using Laravel's encrypt()
3. **Use namespace isolation** - don't use default namespace for user apps
4. **Handle resourceVersion conflicts** - optimistic locking for updates
5. **Validate all K8s resources** before applying

## Testing K8s Features

```bash
# Test connection
kubectl cluster-info
kubectl get nodes

# Apply manifest
kubectl apply -f manifest.yaml

# Check status
kubectl get deployment,service,ingress -n namespace
kubectl describe deployment app-name -n namespace

# Logs
kubectl logs -n namespace -l app=app-name
```

## Gotchas

- K8s API is strict: missing fields cause 422 errors
- Ingress class must match cluster's ingress controller
- Secrets must be base64 encoded
- HPA requires metrics-server or custom metrics API
- Namespaces must exist before creating resources in them
## Quick Commands
- `skill-load kubernetes-development` — Load this skill
