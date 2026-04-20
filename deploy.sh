#!/bin/bash

# Kubernetes & Istio Deployment Script for OpenTelemetry E-Commerce Platform
# This script automates the deployment process to Azure AKS

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-myResourceGroup}"
CLUSTER_NAME="${CLUSTER_NAME:-ecommerce-cluster}"
LOCATION="${LOCATION:-eastus}"
REGISTRY_NAME="${REGISTRY_NAME:-myecommerceacr}"
NODE_COUNT="${NODE_COUNT:-3}"
NODE_SIZE="${NODE_SIZE:-Standard_D4s_v3}"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Phase 1: Prerequisites Check
phase_prerequisites() {
    print_info "=== Phase 1: Checking Prerequisites ==="
    
    local missing_tools=()
    
    for tool in az kubectl helm istioctl; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        else
            version=$($tool version 2>&1 | head -1)
            print_info "$tool is installed: $version"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_error "Missing tools: ${missing_tools[*]}"
        print_info "Please install all required tools before proceeding"
        return 1
    fi
    
    print_info "All prerequisites are met!"
    return 0
}

# Phase 2: Azure Setup
phase_azure_setup() {
    print_info "=== Phase 2: Azure Setup ==="
    
    print_info "Logging into Azure..."
    az login
    
    print_info "Creating resource group: $RESOURCE_GROUP"
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION"
    
    print_info "Creating container registry: $REGISTRY_NAME"
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$REGISTRY_NAME" \
        --sku Basic
    
    print_info "Azure setup completed!"
}

# Phase 3: AKS Cluster Creation
phase_aks_creation() {
    print_info "=== Phase 3: Creating AKS Cluster ==="
    
    print_info "This may take 10-15 minutes..."
    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --node-count "$NODE_COUNT" \
        --vm-set-type VirtualMachineScaleSets \
        --load-balancer-sku standard \
        --enable-managed-identity \
        --network-plugin azure \
        --network-policy azure \
        --enable-addons monitoring \
        --enable-cluster-autoscaling \
        --min-count 2 \
        --max-count 5 \
        --zones 1 2 3 \
        --kubernetes-version 1.28 \
        --node-vm-size "$NODE_SIZE"
    
    print_info "Configuring kubectl..."
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME"
    
    print_info "Verifying cluster connectivity..."
    kubectl cluster-info
    
    print_info "AKS cluster created successfully!"
}

# Phase 4: Create Namespaces
phase_create_namespaces() {
    print_info "=== Phase 4: Creating Namespaces ==="
    
    kubectl create namespace istio-system || print_warning "Namespace istio-system already exists"
    kubectl create namespace istio-ingress || print_warning "Namespace istio-ingress already exists"
    kubectl create namespace otel-demo || print_warning "Namespace otel-demo already exists"
    kubectl create namespace prometheus || print_warning "Namespace prometheus already exists"
    
    print_info "Namespaces created!"
}

# Phase 5: Install Istio
phase_install_istio() {
    print_info "=== Phase 5: Installing Istio ==="
    
    print_info "Downloading Istio..."
    cd /tmp
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-*
    export PATH=$PWD/bin:$PATH
    
    print_info "Installing Istio with production profile..."
    istioctl install --set profile=production -y
    
    print_info "Enabling sidecar injection..."
    kubectl label namespace otel-demo istio-injection=enabled --overwrite
    kubectl label namespace istio-ingress istio-injection=enabled --overwrite
    
    print_info "Installing Kiali add-on..."
    kubectl apply -f samples/addons/kiali.yaml
    
    print_info "Istio installed successfully!"
}

# Phase 6: Install Prometheus
phase_install_prometheus() {
    print_info "=== Phase 6: Installing Prometheus ==="
    
    print_info "Adding Prometheus Helm repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    print_info "Installing Prometheus stack..."
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace prometheus \
        --values prometheus-values.yaml 2>/dev/null || \
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace prometheus
    
    print_info "Prometheus installed successfully!"
}

# Phase 7: Deploy Application
phase_deploy_application() {
    print_info "=== Phase 7: Deploying Application ==="
    
    if [ ! -f "istio-gateway.yaml" ]; then
        print_error "istio-gateway.yaml not found in current directory"
        return 1
    fi
    
    print_info "Applying Istio Gateway..."
    kubectl apply -f istio-gateway.yaml
    
    print_info "Applying Istio policies..."
    kubectl apply -f istio-policies.yaml 2>/dev/null || print_warning "istio-policies.yaml not found"
    
    print_info "Applying Prometheus setup..."
    kubectl apply -f prometheus-setup.yaml 2>/dev/null || print_warning "prometheus-setup.yaml not found"
    
    print_info "Applying frontend deployment..."
    kubectl apply -f frontend-deployment.yaml 2>/dev/null || print_warning "frontend-deployment.yaml not found"
    
    print_info "Waiting for pods to be ready..."
    sleep 30
    kubectl get pods -n otel-demo
    
    print_info "Application deployed successfully!"
}

# Phase 8: Post-Deployment Verification
phase_verification() {
    print_info "=== Phase 8: Verification ==="
    
    print_info "Checking Istio components..."
    kubectl get pods -n istio-system
    
    print_info "Checking application pods..."
    kubectl get pods -n otel-demo
    
    print_info "Checking Prometheus..."
    kubectl get pods -n prometheus
    
    print_info "Getting Istio Ingress Gateway IP..."
    INGRESS_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -n "$INGRESS_IP" ]; then
        print_info "Application is accessible at: http://$INGRESS_IP"
    else
        print_warning "Ingress IP not yet assigned (may take a few minutes)"
        print_info "Run: kubectl get svc -n istio-system istio-ingressgateway -w"
    fi
}

# Phase 9: Port Forwarding Setup Instructions
phase_port_forwarding() {
    print_info "=== Phase 9: Port Forwarding Instructions ==="
    
    cat << 'EOF'

To access the monitoring dashboards, run these commands in separate terminals:

# Access Prometheus
kubectl port-forward -n prometheus svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090

# Access Grafana
kubectl port-forward -n prometheus svc/prometheus-grafana 3000:80
# Visit: http://localhost:3000 (admin/prom-operator)

# Access Kiali (Istio visualization)
kubectl port-forward -n istio-system svc/kiali 20000:20000
# Visit: http://localhost:20000/kiali

# Access Jaeger (Distributed tracing)
kubectl port-forward -n istio-system svc/jaeger 16686:16686
# Visit: http://localhost:16686

EOF
}

# Main execution
main() {
    print_info "Starting OpenTelemetry E-Commerce Deployment to Azure AKS"
    print_info "============================================================"
    
    # Execute phases
    phase_prerequisites || return 1
    
    read -p "Continue with Azure setup? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        phase_azure_setup || return 1
    fi
    
    read -p "Continue with AKS cluster creation? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        phase_aks_creation || return 1
    fi
    
    phase_create_namespaces || return 1
    phase_install_istio || return 1
    phase_install_prometheus || return 1
    
    read -p "Continue with application deployment? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        phase_deploy_application || return 1
    fi
    
    phase_verification || return 1
    phase_port_forwarding
    
    print_info "=== Deployment Complete ==="
    print_info "Your OpenTelemetry E-Commerce platform is now running on Azure AKS!"
}

# Run main function
main "$@"
