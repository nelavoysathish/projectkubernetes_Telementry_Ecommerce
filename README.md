# Kubernetes & Istio Deployment Guide
## OpenTelemetry E-Commerce Microservices with Azure AKS & Prometheus Sidecar Injection

---

## 📋 Overview

This complete deployment package enables you to run the OpenTelemetry E-Commerce Microservices platform on Azure Kubernetes Service (AKS) with:

✅ **Istio Service Mesh** - Advanced traffic management, security, and observability  
✅ **Prometheus Sidecar Injection** - Automatic metrics collection from every pod  
✅ **Distributed Tracing** - Full request tracing via OpenTelemetry & Jaeger  
✅ **Enterprise Security** - Automatic mTLS, fine-grained authorization policies  
✅ **High Availability** - Multi-zone deployment with autoscaling  
✅ **Full Observability** - Metrics, logs, and traces via Prometheus, Grafana, Kiali  

---

## 📦 Deliverables

### 1. **Kubernetes_Istio_Prometheus_Deployment_Guide.docx**
Comprehensive 11-section guide (50+ pages) covering:
- Executive overview and architecture
- Microservices topology (14+ services)
- Prerequisites and tools installation
- Phase-by-phase deployment instructions
- Prometheus sidecar setup and configuration
- Istio mTLS and traffic management policies
- Monitoring with Prometheus, Grafana, Kiali, Jaeger
- Advanced configurations (canary deployments, rate limiting, chaos engineering)
- Troubleshooting and operational guidelines

### 2. **istio-gateway.yaml**
Istio Gateway and VirtualService configuration for:
- HTTP ingress routing
- Frontend traffic management
- Timeouts and retry policies

### 3. **prometheus-setup.yaml**
Complete Prometheus integration including:
- ServiceMonitor resources for automatic service discovery
- ConfigMap for sidecar Prometheus configuration
- MutatingWebhookConfiguration for sidecar injection
- Scrape targets for all microservices

### 4. **istio-policies.yaml**
Enterprise-grade Istio policies including:
- PeerAuthentication for strict mTLS enforcement
- AuthorizationPolicy for service-to-service access control
- DestinationRule for connection pooling and outlier detection
- VirtualService with canary deployment support
- RequestAuthentication for optional JWT validation

### 5. **frontend-deployment.yaml**
Production-ready Kubernetes Deployment with:
- Prometheus sidecar injection (with storage limits)
- Resource requests/limits for proper autoscaling
- Health checks (liveness and readiness probes)
- Security context and non-root execution
- Pod Disruption Budget for availability
- HorizontalPodAutoscaler configuration
- Pod anti-affinity for high availability

### 6. **deploy.sh**
Automated deployment script with 9 phases:
1. Prerequisites verification
2. Azure setup and registry creation
3. AKS cluster creation (with autoscaling)
4. Namespace creation
5. Istio installation and configuration
6. Prometheus installation
7. Application deployment
8. Verification and health checks
9. Port-forwarding setup instructions

---

## 🚀 Quick Start

### Option A: Using Automated Script
```bash
# Set environment variables (optional - defaults provided)
export RESOURCE_GROUP="myResourceGroup"
export CLUSTER_NAME="ecommerce-cluster"
export REGISTRY_NAME="myecommerceacr"

# Run the deployment script
chmod +x deploy.sh
./deploy.sh
```

### Option B: Manual Step-by-Step
Follow the detailed instructions in the **Kubernetes_Istio_Prometheus_Deployment_Guide.docx**

---

## 📊 Architecture Overview

### Microservices (14+)
- **Frontend** (Next.js) - Web UI
- **Cart** (C#) - Shopping cart with Valkey backend
- **Checkout** (Go) - Order processing with Kafka
- **Payment** (Node.js) - Payment processing
- **ProductCatalog** (Go) - Product database
- **Recommendation** (Python) - ML-based recommendations
- **Shipping** (Rust) - Shipping calculations
- **Ad Service** (Java) - Advertising service
- **Email** (Ruby) - Email notifications
- **Currency** (C++) - Currency conversion
- **Plus**: Kafka, PostgreSQL, Valkey, OpenTelemetry Collector

### Infrastructure Stack
```
┌─────────────────────────────────────────────────────────┐
│                    Azure AKS Cluster                     │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │           Istio Control Plane                    │  │
│  │  ├─ Istiod (policy & telemetry)                │  │
│  │  ├─ Ingress Gateway                           │  │
│  │  └─ Egress Gateway                            │  │
│  └──────────────────────────────────────────────────┘  │
│                          ▼                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │   Microservices with Envoy Sidecars              │  │
│  │   + Prometheus Sidecar Agents                    │  │
│  └──────────────────────────────────────────────────┘  │
│                          ▼                               │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Observability Stack                             │  │
│  │  ├─ Prometheus (metrics storage)                │  │
│  │  ├─ Grafana (visualization)                     │  │
│  │  ├─ Kiali (service mesh visualization)         │  │
│  │  ├─ Jaeger (distributed tracing)               │  │
│  │  └─ OpenTelemetry Collector (aggregation)      │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## 🔒 Security Features

### Built-In Security
- **Automatic mTLS** between all services via Istio
- **Fine-Grained Access Control** with AuthorizationPolicy
- **No Credential Sprawl** - sidecars handle certificates
- **Network Policies** enforced at cluster level
- **RBAC** enabled by default on AKS
- **Pod Security Standards** with non-root containers

### Compliance
- PCI-DSS ready payment processing isolation
- HIPAA-compatible audit logging
- SOC 2 aligned access controls

---

## 📈 Monitoring & Observability

### Prometheus Metrics
- Request latency (P50, P95, P99)
- Error rates per service
- Request throughput
- Resource utilization (CPU, memory)
- Envoy proxy metrics from Istio

### Grafana Dashboards
Pre-configured dashboards for:
- Service health and uptime
- Request rate and latency trends
- Error analysis
- Resource consumption

### Kiali Service Mesh Visualization
- Service topology graph
- Traffic flow visualization
- Request tracing
- Service mesh configuration validation

### Jaeger Distributed Tracing
- End-to-end request tracing
- Service dependency mapping
- Latency analysis
- Error tracking

---

## ⚙️ Configuration Files Explained

### istio-gateway.yaml
Configures external traffic entry point and routes requests to frontend service.

### prometheus-setup.yaml
Defines:
- ServiceMonitor for automatic service discovery
- ConfigMap with Prometheus scrape configuration
- MutatingWebhook for automatic sidecar injection

### istio-policies.yaml
Implements:
- mTLS enforcement (PeerAuthentication)
- Service-to-service authorization (AuthorizationPolicy)
- Traffic policies (DestinationRule, VirtualService)

### frontend-deployment.yaml
Production-ready Kubernetes manifest with:
- Prometheus sidecar container
- Resource limits for autoscaling
- Health checks for reliability
- Anti-affinity rules for high availability

---

## 🔄 Deployment Phases

### Phase 1-2: Prerequisites & Azure Setup
- Verify required tools
- Create resource groups and container registry
- Authenticate with Azure

### Phase 3: AKS Cluster Creation
- 3+ node cluster with autoscaling (2-5 nodes)
- Multi-zone deployment for HA
- Network policies enabled
- Azure monitoring addon

### Phase 4: Namespace Organization
- istio-system: Istio control plane
- istio-ingress: Ingress gateway
- otel-demo: Application services
- prometheus: Monitoring stack

### Phase 5: Istio Service Mesh
- Install Istio with production profile
- Enable automatic sidecar injection
- Deploy ingress gateway
- Install Kiali for visualization

### Phase 6: Prometheus Observability
- Deploy Prometheus Operator
- Configure sidecar injection webhooks
- Create ServiceMonitors for metric discovery

### Phase 7: Application Deployment
- Build container images in ACR
- Deploy microservices with sidecars
- Configure services and ingress
- Enable autoscaling policies

### Phase 8: Traffic Management
- Apply mTLS policies
- Configure authorization rules
- Set up traffic routing (canary support)
- Configure circuit breakers

### Phase 9: Verification
- Health check all components
- Verify metrics collection
- Test service communication
- Setup port-forwarding for dashboards

---

## 🛠️ Troubleshooting

### Common Issues

#### Pod stuck in Pending
```bash
kubectl describe pod <pod-name> -n otel-demo
# Check resource requests vs node availability
# Verify node count is sufficient
```

#### Sidecar injection not working
```bash
# Verify namespace label
kubectl get ns -L istio-injection

# Restart pods to trigger injection
kubectl rollout restart deployment/frontend -n otel-demo
```

#### mTLS connection errors
```bash
# Analyze configuration
istioctl analyze

# Check PeerAuthentication policy
kubectl get peerauthentication -n otel-demo
```

#### No metrics in Prometheus
```bash
# Check ServiceMonitor creation
kubectl get servicemonitor -n otel-demo

# Verify metrics endpoint is exposed
kubectl exec <pod> -c prometheus-sidecar -- curl localhost:9090/api/v1/targets
```

---

## 📊 Performance Expectations

### Startup Time
- AKS cluster creation: 10-15 minutes
- Istio installation: 3-5 minutes
- Application deployment: 2-3 minutes

### Resource Consumption
- Istio control plane: ~2-3 CPU, 2-4 GB memory
- Per pod sidecar: ~50-100 mCPU, 50-100 MB memory
- Prometheus instance: ~1-2 CPU, 2-4 GB memory

### Scalability
- Horizontal autoscaling: Based on CPU/memory metrics
- Vertical pod autoscaling: Supported via VPA
- Cluster autoscaling: Min 2, max 5 nodes (configurable)

---

## 🔄 Update and Maintenance

### Updating Istio
```bash
istioctl upgrade --set profile=production
```

### Updating Applications
```bash
# Rolling update (zero downtime)
kubectl set image deployment/frontend frontend=myecommerceacr.azurecr.io/frontend:2.0.0 -n otel-demo
```

### Backing Up Configuration
```bash
kubectl get all,cm,secret -n otel-demo -o yaml > backup.yaml
```

---

## 📚 Additional Resources

- **Istio Documentation**: https://istio.io/latest/docs/
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Prometheus Documentation**: https://prometheus.io/docs/
- **Azure AKS Documentation**: https://learn.microsoft.com/en-us/azure/aks/

---

## 📝 Implementation Checklist

- [ ] Review the deployment guide document
- [ ] Verify all prerequisites are installed
- [ ] Set up Azure account and subscription
- [ ] Create resource group
- [ ] Create container registry
- [ ] Build and push container images
- [ ] Run deployment script (or follow manual steps)
- [ ] Verify cluster components
- [ ] Setup port-forwarding for dashboards
- [ ] Configure custom Grafana dashboards
- [ ] Implement backup strategy
- [ ] Test failover scenarios
- [ ] Document operational procedures

---

## 🎯 Next Steps

1. **Read the Guide**: Start with "Kubernetes_Istio_Prometheus_Deployment_Guide.docx"
2. **Run the Script**: Execute `./deploy.sh` for automated deployment
3. **Access Dashboards**: Use port-forwarding to access Prometheus, Grafana, Kiali
4. **Monitor Metrics**: Create custom dashboards for your business metrics
5. **Test Resilience**: Run chaos engineering experiments
6. **Optimize Configuration**: Fine-tune resource limits and scaling policies

---

## 📞 Support

For issues or questions:
1. Check the troubleshooting section in the guide
2. Review Istio and Kubernetes documentation
3. Run `istioctl analyze` for configuration validation
4. Check pod logs: `kubectl logs <pod> -n otel-demo`
5. Describe pod for events: `kubectl describe pod <pod> -n otel-demo`

---

**Version**: 1.0  
**Last Updated**: April 2026  
**Platform**: Azure AKS, Istio 1.19+, Kubernetes 1.28+

---

## File Structure
```
├── Kubernetes_Istio_Prometheus_Deployment_Guide.docx  (Main guide - 50+ pages)
├── deploy.sh                                           (Automated deployment script)
├── istio-gateway.yaml                                  (Gateway & routing configuration)
├── istio-policies.yaml                                 (mTLS, AuthZ, traffic policies)
├── prometheus-setup.yaml                               (Prometheus & sidecar injection)
├── frontend-deployment.yaml                            (Example deployment with sidecar)
└── README.md                                           (This file)
```

---

**Happy Deploying! 🚀**
