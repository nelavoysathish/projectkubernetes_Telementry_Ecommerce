# Multi-Environment Kubernetes Deployment Guide

## Overview

This guide explains how to manage **multiple isolated environments** (dev, staging, prod) on your Azure AKS cluster using separate namespaces, Kustomize, and environment-specific configurations.

---

## 1. Environment Isolation Strategy

### Namespace-Based Isolation

Each environment gets its own set of namespaces:

```
Development Environment:
├── otel-demo-dev           (application services)
├── istio-ingress-dev       (ingress gateway)
└── prometheus-dev          (monitoring)

Staging Environment:
├── otel-demo-staging       (application services)
├── istio-ingress-staging   (ingress gateway)
└── prometheus-staging      (monitoring)

Production Environment:
├── otel-demo-prod          (application services)
├── istio-system            (shared Istio control plane)
└── prometheus-prod         (monitoring)
```

### Environment Configuration

Each environment has different resource allocations:

| Aspect | Dev | Staging | Production |
|--------|-----|---------|-----------|
| Replicas | 1 | 2 | 3+ |
| CPU Request | 50m | 100m | 250m |
| CPU Limit | 200m | 500m | 1000m |
| Memory Request | 128Mi | 256Mi | 512Mi |
| Memory Limit | 256Mi | 512Mi | 1Gi |
| Autoscaling | No | Yes (2-5) | Yes (3-10) |
| Log Level | debug | info | warn |
| Network Policies | None | Basic | Strict |
| Backups | Manual | Daily | Hourly |

---

## 2. Quick Start - Using manage-environments.sh

### Create Environments

```bash
# Create dev environment
./manage-environments.sh create dev

# Create staging environment
./manage-environments.sh create staging

# Create production environment
./manage-environments.sh create prod
```

### List Environments

```bash
# Show all environments and their status
./manage-environments.sh list
```

### Switch Between Environments

```bash
# Switch kubectl context to dev
./manage-environments.sh switch dev

# Switch to staging
./manage-environments.sh switch staging

# Switch to prod
./manage-environments.sh switch prod

# Verify current context
kubectl config current-context
kubectl get namespace
```

### View Environment Status

```bash
# Show detailed status of dev environment
./manage-environments.sh status dev

# Shows:
# - Configuration (replicas, CPU, memory)
# - Namespaces
# - Pods and services
# - ConfigMaps and secrets
```

### Backup & Restore

```bash
# Backup production environment
./manage-environments.sh backup prod
# Creates: backups/prod-20260419-120000/

# Restore from backup
./manage-environments.sh restore prod backups/prod-20260419-120000/otel-demo.yaml
```

### Delete Environment

```bash
# Delete dev environment (with confirmation)
./manage-environments.sh delete dev
```

---

## 3. Using Kustomize for Declarative Environment Management

### Directory Structure

```
kustomize/
├── base/
│   ├── kustomization.yaml      (shared base config)
│   ├── deployment.yaml         (parameterized deployment)
│   ├── service.yaml
│   ├── configmap.yaml
│   └── prometheus-setup.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   └── ingress-dev.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── ingress-staging.yaml
│   │   ├── pdb.yaml
│   │   └── networkpolicy.yaml
│   └── prod/
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── ingress-prod.yaml
│       ├── pdb.yaml
│       ├── networkpolicy.yaml
│       ├── resource-quota.yaml
│       └── limit-range.yaml
```

### Build and Deploy with Kustomize

```bash
# Deploy dev environment
kubectl kustomize overlays/dev | kubectl apply -f -

# Deploy staging environment
kubectl kustomize overlays/staging | kubectl apply -f -

# Deploy production environment
kubectl kustomize overlays/prod | kubectl apply -f -

# Generate manifests without applying
kubectl kustomize overlays/dev > dev-manifests.yaml
kubectl kustomize overlays/staging > staging-manifests.yaml
kubectl kustomize overlays/prod > prod-manifests.yaml

# Validate configurations
kubectl kustomize overlays/dev > /dev/null && echo "Dev config is valid"
kubectl kustomize overlays/staging > /dev/null && echo "Staging config is valid"
kubectl kustomize overlays/prod > /dev/null && echo "Prod config is valid"
```

---

## 4. Environment-Specific Features

### Development Environment

**Purpose**: Fast iteration, testing features, debugging

```yaml
- Minimal resources (1 replica)
- Debug logging enabled
- No autoscaling
- No network policies
- Shared Istio ingress
- Local container registry access
```

**Example Deployment**:
```bash
./manage-environments.sh create dev
kubectl apply -f istio-gateway.yaml -n istio-ingress-dev
kubectl apply -f frontend-deployment.yaml -n otel-demo-dev
```

### Staging Environment

**Purpose**: Pre-production testing, performance validation, integration tests

```yaml
- 2 replicas for load balancing
- Info logging level
- Autoscaling enabled (2-5 pods)
- Basic network policies
- Separate ingress gateway
- Matches production config closely
```

**Example Deployment**:
```bash
./manage-environments.sh create staging
kubectl kustomize overlays/staging | kubectl apply -f -
```

### Production Environment

**Purpose**: Live traffic, customer-facing, SLA-compliant

```yaml
- 3+ replicas for high availability
- Warn logging level (minimal noise)
- Aggressive autoscaling (3-10 pods)
- Strict network policies (deny by default)
- Separate ingress gateway with TLS
- Pod Disruption Budgets enforced
- Resource quotas and limits
- Hourly backups
- Dedicated monitoring
```

**Example Deployment**:
```bash
./manage-environments.sh create prod
kubectl kustomize overlays/prod | kubectl apply -f -
kubectl apply -f istio-policies.yaml -n otel-demo-prod
```

---

## 5. Managing Secrets Across Environments

### Create Environment-Specific Secrets

```bash
# Dev environment
kubectl create secret generic env-secrets \
  --from-literal=OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector-dev:4318 \
  -n otel-demo-dev

# Staging environment
kubectl create secret generic env-secrets \
  --from-literal=OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector-staging:4318 \
  -n otel-demo-staging

# Production environment
kubectl create secret generic env-secrets \
  --from-literal=OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector-prod:4318 \
  -n otel-demo-prod

# Registry credentials (same for all environments)
kubectl create secret docker-registry acr-secret \
  --docker-server=myregistry.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  -n otel-demo-dev

kubectl create secret docker-registry acr-secret \
  --docker-server=myregistry.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  -n otel-demo-staging

kubectl create secret docker-registry acr-secret \
  --docker-server=myregistry.azurecr.io \
  --docker-username=<username> \
  --docker-password=<password> \
  -n otel-demo-prod
```

---

## 6. CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy to Environments

on:
  push:
    branches:
      - main
      - develop

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        environment: [dev, staging, prod]
        exclude:
          - environment: prod
            branches: develop  # Only deploy to prod from main

    steps:
    - uses: actions/checkout@v2
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v1
    
    - name: Get AKS Credentials
      run: |
        az aks get-credentials \
          --resource-group ${{ secrets.RESOURCE_GROUP }} \
          --name ${{ secrets.CLUSTER_NAME }}
    
    - name: Build and Push Docker Images
      run: |
        az acr build -r ${{ secrets.REGISTRY_NAME }} \
          -f ./src/frontend/Dockerfile \
          -t frontend:${{ github.sha }} .
    
    - name: Deploy with Kustomize
      run: |
        kubectl kustomize overlays/${{ matrix.environment }} | \
        kubectl apply -f - \
        --record
    
    - name: Wait for Rollout
      run: |
        kubectl rollout status deployment/frontend \
          -n otel-demo-${{ matrix.environment }}
```

---

## 7. Upgrading Applications Across Environments

### Promote from Dev → Staging → Prod

```bash
# 1. Test in dev with new image
./manage-environments.sh switch dev
kubectl set image deployment/frontend \
  frontend=myregistry.azurecr.io/frontend:v2.0.0 \
  -n otel-demo-dev

# 2. Verify dev works
kubectl rollout status deployment/frontend -n otel-demo-dev
./manage-environments.sh status dev

# 3. Deploy to staging
./manage-environments.sh switch staging
kubectl set image deployment/frontend \
  frontend=myregistry.azurecr.io/frontend:v2.0.0 \
  -n otel-demo-staging

# 4. Run integration tests on staging
kubectl exec -it <frontend-pod> -n otel-demo-staging -- bash
# Run test suite...

# 5. Promote to production
./manage-environments.sh switch prod
kubectl set image deployment/frontend \
  frontend=myregistry.azurecr.io/frontend:v2.0.0 \
  -n otel-demo-prod

# 6. Monitor production
kubectl logs -f deployment/frontend -n otel-demo-prod
./manage-environments.sh status prod
```

---

## 8. Monitoring Across Environments

### Access Prometheus for Each Environment

```bash
# Dev Prometheus
kubectl port-forward -n prometheus-dev \
  svc/prometheus-kube-prometheus-prometheus 9090:9090

# Staging Prometheus
kubectl port-forward -n prometheus-staging \
  svc/prometheus-kube-prometheus-prometheus 9091:9090

# Production Prometheus
kubectl port-forward -n prometheus-prod \
  svc/prometheus-kube-prometheus-prometheus 9092:9090
```

### Unified Monitoring Dashboard

Create a Grafana datasource for each environment:
- Dev: http://localhost:9090
- Staging: http://localhost:9091
- Prod: http://localhost:9092

Create dashboards with environment variables:
```
{environment=~"dev|staging|prod"}
```

---

## 9. Troubleshooting Multi-Environment Issues

### Check which environment you're in

```bash
kubectl config current-context
kubectl get namespace --current
```

### Switch environments

```bash
./manage-environments.sh switch staging
kubectl config set-context --current --namespace=otel-demo-staging
```

### View all pods across environments

```bash
# Dev
kubectl get pods -n otel-demo-dev

# Staging
kubectl get pods -n otel-demo-staging

# Prod
kubectl get pods -n otel-demo-prod

# All at once
for env in dev staging prod; do
  echo "=== $env ==="
  kubectl get pods -n otel-demo-$env
done
```

### Compare configurations

```bash
# Diff dev and staging deployments
kubectl get deployment frontend -n otel-demo-dev -o yaml > dev-deploy.yaml
kubectl get deployment frontend -n otel-demo-staging -o yaml > staging-deploy.yaml
diff dev-deploy.yaml staging-deploy.yaml
```

### Backup before major changes

```bash
# Backup all environments
for env in dev staging prod; do
  ./manage-environments.sh backup $env
done
```

---

## 10. Best Practices

✅ **Always test in dev first** before staging  
✅ **Run integration tests in staging** before production  
✅ **Use Kustomize overlays** for reproducible deployments  
✅ **Backup prod daily** and test restores monthly  
✅ **Monitor each environment separately** with dedicated Prometheus instances  
✅ **Use namespace labels** for easy filtering  
✅ **Implement network policies** in prod only  
✅ **Document environment differences** in your runbooks  
✅ **Automate promotion** via CI/CD pipelines  
✅ **Test disaster recovery** regularly  

---

## Quick Reference Commands

```bash
# Create all environments
./manage-environments.sh create dev
./manage-environments.sh create staging
./manage-environments.sh create prod

# List all
./manage-environments.sh list

# Deploy to all with Kustomize
kubectl kustomize overlays/dev | kubectl apply -f -
kubectl kustomize overlays/staging | kubectl apply -f -
kubectl kustomize overlays/prod | kubectl apply -f -

# Switch environments
./manage-environments.sh switch dev
./manage-environments.sh switch staging
./manage-environments.sh switch prod

# Check status
./manage-environments.sh status dev
./manage-environments.sh status staging
./manage-environments.sh status prod

# Backup/Restore
./manage-environments.sh backup prod
./manage-environments.sh restore prod <backup-file>

# Delete (careful!)
./manage-environments.sh delete dev
```

---

**Congratulations! You now have a production-grade multi-environment Kubernetes setup!**
