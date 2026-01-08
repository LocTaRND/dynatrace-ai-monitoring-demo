#!/bin/bash

#########################################
# Dynatrace Operator Deployment for AKS
# Deploys Dynatrace OneAgent to Kubernetes
#########################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

#########################################
# CONFIGURATION
#########################################

NAMESPACE="dynatrace"
DYNAKUBE_FILE="dynatrace/dynakube.yaml"
HELM_RELEASE="dynatrace-operator"
HELM_CHART="oci://public.ecr.aws/dynatrace/dynatrace-operator"

#########################################
# VALIDATION
#########################################

print_info "Starting Dynatrace Operator deployment script..."

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    echo "  Installation guide: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install it first."
    echo "  Installation guide: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if connected to Kubernetes cluster
print_info "Checking Kubernetes cluster connection..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster."
    echo "  Please configure kubectl to connect to your cluster."
    echo "  For AKS: az aks get-credentials --resource-group <RG> --name <CLUSTER>"
    exit 1
fi

# Display current context
CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "Unknown")
print_info "Current Kubernetes context: $CURRENT_CONTEXT"
print_info "Cluster: $CLUSTER_NAME"

# Check if DynaKube YAML file exists
if [ ! -f "$DYNAKUBE_FILE" ]; then
    print_error "DynaKube configuration file not found: $DYNAKUBE_FILE"
    echo "  Please ensure the file exists in the correct location."
    exit 1
fi

print_info "DynaKube configuration found: $DYNAKUBE_FILE"

# Confirmation prompt
echo ""
print_warning "You are about to deploy Dynatrace Operator to cluster: $CLUSTER_NAME"
read -p "Do you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    print_info "Deployment cancelled by user."
    exit 0
fi

#########################################
# STEP 1: INSTALL DYNATRACE OPERATOR
#########################################

print_step "Step 1: Installing Dynatrace Operator using Helm..."

# Check if namespace exists
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_info "Namespace '$NAMESPACE' already exists."
else
    print_info "Namespace '$NAMESPACE' will be created."
fi

# Check if Helm release already exists
if helm list -n "$NAMESPACE" | grep -q "$HELM_RELEASE"; then
    print_warning "Dynatrace Operator release '$HELM_RELEASE' already exists."
    read -p "Do you want to upgrade it? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy]es$ ]]; then
        print_info "Upgrading Dynatrace Operator..."
        helm upgrade "$HELM_RELEASE" "$HELM_CHART" \
            --namespace "$NAMESPACE" \
            --atomic \
            --wait
        print_info "✓ Dynatrace Operator upgraded successfully!"
    else
        print_info "Skipping Helm installation."
    fi
else
    print_info "Installing Dynatrace Operator (this may take a few minutes)..."
    helm install "$HELM_RELEASE" "$HELM_CHART" \
        --create-namespace \
        --namespace "$NAMESPACE" \
        --atomic \
        --wait
    
    if [ $? -eq 0 ]; then
        print_info "✓ Dynatrace Operator installed successfully!"
    else
        print_error "Failed to install Dynatrace Operator"
        exit 1
    fi
fi

# Wait for operator pods to be ready
print_info "Waiting for operator pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=dynatrace-operator \
    -n "$NAMESPACE" \
    --timeout=300s

print_info "✓ Operator pods are ready!"

#########################################
# STEP 2: APPLY DYNAKUBE CONFIGURATION
#########################################

print_step "Step 2: Applying DynaKube configuration..."

# Validate YAML syntax
if ! kubectl apply --dry-run=client -f "$DYNAKUBE_FILE" &> /dev/null; then
    print_error "Invalid DynaKube YAML configuration"
    echo "  Please check the file: $DYNAKUBE_FILE"
    exit 1
fi

print_info "Applying DynaKube configuration from $DYNAKUBE_FILE..."
kubectl apply -f "$DYNAKUBE_FILE"

if [ $? -eq 0 ]; then
    print_info "✓ DynaKube configuration applied successfully!"
else
    print_error "Failed to apply DynaKube configuration"
    exit 1
fi

#########################################
# STEP 3: VERIFY DEPLOYMENT
#########################################

print_step "Step 3: Verifying deployment..."

# Get DynaKube name from the YAML
DYNAKUBE_NAME=$(kubectl get dynakube -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$DYNAKUBE_NAME" ]; then
    print_warning "Could not retrieve DynaKube name. Skipping detailed status."
else
    print_info "DynaKube resource: $DYNAKUBE_NAME"
    
    # Wait a bit for initialization
    sleep 5
    
    # Check DynaKube status
    print_info "DynaKube status:"
    kubectl get dynakube "$DYNAKUBE_NAME" -n "$NAMESPACE"
fi

# List all pods in dynatrace namespace
echo ""
print_info "Pods in namespace '$NAMESPACE':"
kubectl get pods -n "$NAMESPACE"

#########################################
# COMPLETION
#########################################

echo ""
print_info "======================================"
print_info "Dynatrace Operator Deployment Complete!"
print_info "======================================"
echo ""
print_info "Next steps:"
echo "  1. Wait 5-10 minutes for OneAgent to fully initialize"
echo "  2. Check pod status: kubectl get pods -n $NAMESPACE"
echo "  3. View DynaKube status: kubectl describe dynakube -n $NAMESPACE"
echo "  4. Check operator logs: kubectl logs -l app.kubernetes.io/name=dynatrace-operator -n $NAMESPACE"
echo "  5. Verify in Dynatrace UI: Settings → Kubernetes"
echo ""
print_info "Useful commands:"
echo "  • Monitor deployment: watch kubectl get pods -n $NAMESPACE"
echo "  • View all resources: kubectl get all -n $NAMESPACE"
echo "  • Check DynaKube details: kubectl describe dynakube -n $NAMESPACE"
echo "  • Operator logs: kubectl logs -l app.kubernetes.io/name=dynatrace-operator -n $NAMESPACE -f"
echo ""
print_info "Deployment completed successfully! 🎉"