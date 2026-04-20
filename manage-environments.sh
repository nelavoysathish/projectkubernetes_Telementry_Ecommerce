#!/bin/bash

# Multi-Environment Management for OpenTelemetry E-Commerce Platform
# Supports: dev, staging, prod environments with isolated namespaces

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

print_section() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Usage help
show_help() {
    cat << 'EOF'
Usage: ./manage-environments.sh <command> <environment>

Commands:
    create          Create a new environment with all namespaces
    delete          Delete an environment and all its resources
    list            List all environments
    switch          Switch kubectl context to an environment
    status          Show status of an environment
    upgrade         Upgrade application in an environment
    backup          Backup environment configuration
    restore         Restore environment from backup

Environments:
    dev             Development environment (1 replica, minimal resources)
    staging         Staging environment (2 replicas, moderate resources)
    prod            Production environment (3+ replicas, full resources)

Examples:
    ./manage-environments.sh create dev
    ./manage-environments.sh create staging
    ./manage-environments.sh create prod
    ./manage-environments.sh status dev
    ./manage-environments.sh switch staging
    ./manage-environments.sh backup prod
    ./manage-environments.sh delete dev

EOF
}

# Validate environment name
validate_environment() {
    local env=$1
    case "$env" in
        dev|staging|prod)
            return 0
            ;;
        *)
            print_error "Invalid environment: $env"
            echo "Valid environments: dev, staging, prod"
            return 1
            ;;
    esac
}

# Get environment-specific configuration
get_env_config() {
    local env=$1
    
    case "$env" in
        dev)
            REPLICAS=1
            MEMORY_REQUEST="128Mi"
            MEMORY_LIMIT="256Mi"
            CPU_REQUEST="50m"
            CPU_LIMIT="200m"
            ENABLE_HPA="false"
            HPA_MIN=1
            HPA_MAX=2
            ;;
        staging)
            REPLICAS=2
            MEMORY_REQUEST="256Mi"
            MEMORY_LIMIT="512Mi"
            CPU_REQUEST="100m"
            CPU_LIMIT="500m"
            ENABLE_HPA="true"
            HPA_MIN=2
            HPA_MAX=5
            ;;
        prod)
            REPLICAS=3
            MEMORY_REQUEST="512Mi"
            MEMORY_LIMIT="1Gi"
            CPU_REQUEST="250m"
            CPU_LIMIT="1000m"
            ENABLE_HPA="true"
            HPA_MIN=3
            HPA_MAX=10
            ;;
    esac
}

# Create environment
create_environment() {
    local env=$1
    
    validate_environment "$env" || return 1
    get_env_config "$env"
    
    print_section "Creating $env Environment"
    
    # Create namespaces
    print_info "Creating namespaces for $env environment..."
    
    # Application namespace
    kubectl create namespace "otel-demo-$env" || print_warning "Namespace otel-demo-$env already exists"
    
    # Istio namespace (if not in prod, share with prod)
    if [ "$env" = "dev" ] || [ "$env" = "staging" ]; then
        kubectl create namespace "istio-system" || print_warning "Namespace istio-system already exists"
        kubectl create namespace "istio-ingress-$env" || print_warning "Namespace istio-ingress-$env already exists"
    fi
    
    # Monitoring namespace
    kubectl create namespace "prometheus-$env" || print_warning "Namespace prometheus-$env already exists"
    
    # Label namespaces
    print_info "Labeling namespaces for $env environment..."
    kubectl label namespace "otel-demo-$env" \
        environment=$env \
        istio-injection=enabled \
        --overwrite
    
    kubectl label namespace "istio-ingress-$env" \
        environment=$env \
        istio-injection=enabled \
        --overwrite 2>/dev/null || true
    
    kubectl label namespace "prometheus-$env" \
        environment=$env \
        --overwrite
    
    # Create ConfigMap with environment settings
    print_info "Creating environment configuration..."
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: env-config
  namespace: otel-demo-$env
data:
  ENVIRONMENT: "$env"
  REPLICAS: "$REPLICAS"
  MEMORY_REQUEST: "$MEMORY_REQUEST"
  MEMORY_LIMIT: "$MEMORY_LIMIT"
  CPU_REQUEST: "$CPU_REQUEST"
  CPU_LIMIT: "$CPU_LIMIT"
  ENABLE_HPA: "$ENABLE_HPA"
  LOG_LEVEL: "$([ "$env" = "prod" ] && echo "warn" || echo "info")"
  METRICS_ENABLED: "true"
  TRACING_ENABLED: "true"
---
apiVersion: v1
kind: Secret
metadata:
  name: env-secrets
  namespace: otel-demo-$env
type: Opaque
stringData:
  ENVIRONMENT: "$env"
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://otel-collector-$env:4318"
EOF
    
    # Create RBAC for environment
    print_info "Creating RBAC for $env environment..."
    
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-demo-sa
  namespace: otel-demo-$env
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: otel-demo-role
  namespace: otel-demo-$env
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: otel-demo-rolebinding
  namespace: otel-demo-$env
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: otel-demo-role
subjects:
- kind: ServiceAccount
  name: otel-demo-sa
  namespace: otel-demo-$env
EOF
    
    # Create network policies for security
    if [ "$env" = "prod" ]; then
        print_info "Creating network policies for $env (production)..."
        
        cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: otel-demo-$env
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal
  namespace: otel-demo-$env
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          environment: prod
EOF
    fi
    
    # Create environment-specific Istio Gateway
    if [ "$env" != "prod" ]; then
        print_info "Creating Istio Gateway for $env..."
        
        cat << EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: gateway-$env
  namespace: istio-ingress-$env
spec:
  selector:
    istio: ingressgateway-$env
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: frontend-$env
  namespace: otel-demo-$env
spec:
  hosts:
  - "*"
  gateways:
  - istio-ingress-$env/gateway-$env
  http:
  - match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: frontend
        port:
          number: 80
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
EOF
    fi
    
    print_info "Environment $env created successfully!"
    print_info "Namespaces created:"
    kubectl get namespace -l environment=$env
}

# Delete environment
delete_environment() {
    local env=$1
    
    validate_environment "$env" || return 1
    
    print_section "Deleting $env Environment"
    print_warning "This will delete all resources in $env environment!"
    
    read -p "Are you sure you want to delete the $env environment? (yes/no) " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        print_info "Deletion cancelled"
        return
    fi
    
    print_info "Deleting namespaces for $env environment..."
    
    # Delete namespaces (cascading delete)
    kubectl delete namespace "otel-demo-$env" --ignore-not-found
    kubectl delete namespace "istio-ingress-$env" --ignore-not-found
    kubectl delete namespace "prometheus-$env" --ignore-not-found
    
    # Wait for deletion
    print_info "Waiting for resources to be deleted..."
    sleep 10
    
    print_info "Environment $env deleted successfully!"
}

# List environments
list_environments() {
    print_section "Listing All Environments"
    
    print_info "Environments found:"
    kubectl get namespace -L environment | grep -E "otel-demo-|istio-ingress-|prometheus-"
    
    echo ""
    print_info "Summary:"
    for env in dev staging prod; do
        if kubectl get namespace "otel-demo-$env" &>/dev/null; then
            echo -e "${GREEN}✓${NC} $env environment exists"
        else
            echo -e "${YELLOW}✗${NC} $env environment does not exist"
        fi
    done
}

# Switch kubectl context to environment
switch_environment() {
    local env=$1
    
    validate_environment "$env" || return 1
    
    print_info "Switching to $env environment..."
    kubectl config set-context --current --namespace="otel-demo-$env"
    
    print_info "Current context set to namespace: otel-demo-$env"
    kubectl get namespace
}

# Show environment status
show_status() {
    local env=$1
    
    validate_environment "$env" || return 1
    
    print_section "Status of $env Environment"
    get_env_config "$env"
    
    echo ""
    print_info "Environment Configuration:"
    echo "  Replicas: $REPLICAS"
    echo "  Memory Request: $MEMORY_REQUEST"
    echo "  Memory Limit: $MEMORY_LIMIT"
    echo "  CPU Request: $CPU_REQUEST"
    echo "  CPU Limit: $CPU_LIMIT"
    echo "  Autoscaling: $ENABLE_HPA (Min: $HPA_MIN, Max: $HPA_MAX)"
    
    echo ""
    print_info "Namespaces:"
    kubectl get namespace -l environment=$env
    
    echo ""
    print_info "Pods in otel-demo-$env:"
    kubectl get pods -n "otel-demo-$env" 2>/dev/null || print_warning "No pods found"
    
    echo ""
    print_info "Services in otel-demo-$env:"
    kubectl get svc -n "otel-demo-$env" 2>/dev/null || print_warning "No services found"
    
    echo ""
    print_info "ConfigMap in otel-demo-$env:"
    kubectl get configmap env-config -n "otel-demo-$env" -o yaml 2>/dev/null || print_warning "No ConfigMap found"
}

# Backup environment
backup_environment() {
    local env=$1
    
    validate_environment "$env" || return 1
    
    local backup_dir="backups/$env-$(date +%Y%m%d-%H%M%S)"
    
    print_section "Backing up $env Environment"
    
    mkdir -p "$backup_dir"
    
    print_info "Backing up all resources from otel-demo-$env..."
    kubectl get all,cm,secret,ing -n "otel-demo-$env" -o yaml > "$backup_dir/otel-demo.yaml" 2>/dev/null || print_warning "No resources in otel-demo-$env"
    
    if [ "$env" != "prod" ]; then
        print_info "Backing up Istio resources..."
        kubectl get gateway,virtualservice,destinationrule,peerauthentication,authorizationpolicy -n "otel-demo-$env" -o yaml > "$backup_dir/istio.yaml" 2>/dev/null || print_warning "No Istio resources found"
    fi
    
    print_info "Backing up Prometheus resources..."
    kubectl get all -n "prometheus-$env" -o yaml > "$backup_dir/prometheus.yaml" 2>/dev/null || print_warning "No Prometheus resources found"
    
    print_info "Backup completed: $backup_dir"
    ls -lh "$backup_dir"
}

# Restore environment
restore_environment() {
    local env=$1
    local backup_file=$2
    
    validate_environment "$env" || return 1
    
    if [ -z "$backup_file" ]; then
        print_error "Backup file not specified"
        echo "Usage: ./manage-environments.sh restore <env> <backup-file>"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    print_section "Restoring $env Environment"
    print_warning "This will apply resources from backup file!"
    
    read -p "Are you sure you want to restore? (yes/no) " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        print_info "Restore cancelled"
        return
    fi
    
    print_info "Restoring from $backup_file..."
    kubectl apply -f "$backup_file"
    
    print_info "Restore completed!"
}

# Upgrade application in environment
upgrade_application() {
    local env=$1
    
    validate_environment "$env" || return 1
    get_env_config "$env"
    
    print_section "Upgrading Application in $env Environment"
    
    print_info "Current deployments in otel-demo-$env:"
    kubectl get deployment -n "otel-demo-$env"
    
    read -p "Enter deployment name to upgrade: " deployment_name
    read -p "Enter new image (e.g., myregistry.azurecr.io/service:2.0.0): " image
    
    if [ -z "$deployment_name" ] || [ -z "$image" ]; then
        print_error "Deployment name and image are required"
        return 1
    fi
    
    print_info "Rolling update of $deployment_name with image: $image"
    kubectl set image deployment/$deployment_name \
        "$deployment_name=$image" \
        -n "otel-demo-$env" \
        --record
    
    print_info "Waiting for rollout to complete..."
    kubectl rollout status deployment/$deployment_name -n "otel-demo-$env"
    
    print_info "Upgrade completed!"
}

# Main function
main() {
    local command=$1
    local environment=$2
    local arg3=$3
    
    if [ -z "$command" ]; then
        show_help
        return
    fi
    
    case "$command" in
        create)
            if [ -z "$environment" ]; then
                print_error "Environment name required"
                show_help
                return 1
            fi
            create_environment "$environment"
            ;;
        delete)
            if [ -z "$environment" ]; then
                print_error "Environment name required"
                show_help
                return 1
            fi
            delete_environment "$environment"
            ;;
        list)
            list_environments
            ;;
        switch)
            if [ -z "$environment" ]; then
                print_error "Environment name required"
                show_help
                return 1
            fi
            switch_environment "$environment"
            ;;
        status)
            if [ -z "$environment" ]; then
                print_error "Environment name required"
                show_help
                return 1
            fi
            show_status "$environment"
            ;;
        backup)
            if [ -z "$environment" ]; then
                print_error "Environment name required"
                show_help
                return 1
            fi
            backup_environment "$environment"
            ;;
        restore)
            if [ -z "$environment" ] || [ -z "$arg3" ]; then
                print_error "Environment name and backup file required"
                show_help
                return 1
            fi
            restore_environment "$environment" "$arg3"
            ;;
        upgrade)
            if [ -z "$environment" ]; then
                print_error "Environment name required"
                show_help
                return 1
            fi
            upgrade_application "$environment"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            return 1
            ;;
    esac
}

# Run main function
main "$@"
