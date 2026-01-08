#!/bin/bash

#########################################
# .NET Application Deployment to AKS
# Build, Push Docker Image, and Deploy
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

APP_DIR="sample-dotnet-app-on-k8s"
K8S_DIR="$APP_DIR/k8s"
NAMESPACE="application"

# Docker Registry Configuration (can be Docker Hub, private registry, etc.)
REGISTRY="${DOCKER_REGISTRY:-taloc}"  # Default to taloc (can be set via DOCKER_REGISTRY env var)
IMAGE_NAME="dynatrace"
IMAGE_TAG="${IMAGE_TAG:-sampleapi}"  # Default to sampleapi tag
FULL_IMAGE_NAME="$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"

#########################################
# VALIDATION
#########################################

print_info "Starting application deployment script..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    echo "  Installation guide: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    echo "  Installation guide: https://kubernetes.io/docs/tasks/tools/"
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

# Check if application directory exists
if [ ! -d "$APP_DIR" ]; then
    print_error "Application directory not found: $APP_DIR"
    exit 1
fi

# Check if Dockerfile exists
if [ ! -f "$APP_DIR/Dockerfile" ]; then
    print_error "Dockerfile not found: $APP_DIR/Dockerfile"
    exit 1
fi

# Check if K8s manifests exist
if [ ! -d "$K8S_DIR" ]; then
    print_error "Kubernetes manifests directory not found: $K8S_DIR"
    exit 1
fi

print_info "✓ All prerequisites validated"

print_info "Image configuration:"
print_info "  • Full image name: $FULL_IMAGE_NAME"
print_info "  • Registry: $REGISTRY"

# Confirmation prompt
echo ""
print_warning "You are about to:"
echo "  • Build Docker image from: $APP_DIR"
echo "  • Tag as: $FULL_IMAGE_NAME"
echo "  • Push to registry: $REGISTRY"
echo "  • Deploy to cluster: $CLUSTER_NAME"
echo "  • Namespace: $NAMESPACE"
echo ""
print_info "Note: Make sure you're logged into your Docker registry"
echo "      For Docker Hub: docker login"
echo "      For other: docker login <registry>"
read -p "Do you want to continue? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    print_info "Deployment cancelled by user."
    exit 0
fi

#########################################
# STEP 1: BUILD DOCKER IMAGE
#########################################

print_step "Step 1: Building Docker image..."

print_info "Building image: $FULL_IMAGE_NAME"
print_info "Build context: $APP_DIR"

cd "$APP_DIR"

docker build -t "$FULL_IMAGE_NAME" .

if [ $? -eq 0 ]; then
    print_info "✓ Docker image built successfully!"
else
    print_error "Failed to build Docker image"
    exit 1
fi

cd ..

#########################################
# STEP 2: PUSH DOCKER IMAGE
#########################################

print_step "Step 2: Pushing Docker image..."

print_info "Pushing image: $FULL_IMAGE_NAME"

docker push "$FULL_IMAGE_NAME"

if [ $? -eq 0 ]; then
    print_info "✓ Docker image pushed successfully!"
else
    print_error "Failed to push Docker image"
    print_warning "Make sure you are logged into the registry:"
    echo "  For Docker Hub: docker login"
    echo "  For private registry: docker login <registry>"
    exit 1
fi

#########################################
# STEP 3: CREATE KUBERNETES NAMESPACE
#########################################

print_step "Step 3: Creating Kubernetes namespace..."

if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_info "Namespace '$NAMESPACE' already exists."
else
    print_info "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
    print_info "✓ Namespace created successfully!"
fi

#########################################
# STEP 4: UPDATE K8S MANIFESTS
#########################################

print_step "Step 4: Updating Kubernetes manifests..."

# Create temporary directory for modified manifests
TEMP_DIR=$(mktemp -d)
cp -r "$K8S_DIR"/* "$TEMP_DIR/"

# Update image in deployment.yaml
DEPLOYMENT_FILE="$TEMP_DIR/deployment.yaml"

if [ -f "$DEPLOYMENT_FILE" ]; then
    print_info "Updating deployment image to: $FULL_IMAGE_NAME"
    
    # Replace image reference in deployment
    sed -i.bak "s|image:.*|image: $FULL_IMAGE_NAME|g" "$DEPLOYMENT_FILE"
    
    print_info "✓ Deployment manifest updated"
else
    print_error "Deployment manifest not found: $DEPLOYMENT_FILE"
    exit 1
fi

#########################################
# STEP 5: DEPLOY TO KUBERNETES
#########################################

print_step "Step 5: Deploying application to Kubernetes..."

print_info "Applying Kubernetes manifests from: $TEMP_DIR"

# Apply all manifests
kubectl apply -f "$TEMP_DIR" -n "$NAMESPACE"

if [ $? -eq 0 ]; then
    print_info "✓ Application manifests applied successfully!"
else
    print_error "Failed to apply Kubernetes manifests"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Clean up temporary directory
rm -rf "$TEMP_DIR"

#########################################
# STEP 6: WAIT FOR DEPLOYMENT
#########################################

print_step "Step 6: Waiting for deployment to be ready..."

print_info "Waiting for pods to be ready (timeout: 5 minutes)..."

kubectl wait --for=condition=ready pod \
    -l app=sampleapi \
    -n "$NAMESPACE" \
    --timeout=300s

if [ $? -eq 0 ]; then
    print_info "✓ Pods are ready!"
else
    print_warning "Timeout waiting for pods. Checking status..."
fi

#########################################
# STEP 7: VERIFY DEPLOYMENT
#########################################

print_step "Step 7: Verifying deployment..."

# Get deployment status
echo ""
print_info "Deployment status:"
kubectl get deployment -n "$NAMESPACE"

echo ""
print_info "Pods status:"
kubectl get pods -n "$NAMESPACE" -l app=sampleapi

echo ""
print_info "Service status:"
kubectl get service -n "$NAMESPACE"

# Get service external IP (if LoadBalancer)
print_info "Waiting for external IP (this may take a few minutes)..."
sleep 10

EXTERNAL_IP=$(kubectl get service sampleapi-service -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$EXTERNAL_IP" ]; then
    print_info "✓ Service is accessible at: http://$EXTERNAL_IP"
else
    print_warning "External IP not yet assigned. Check later with:"
    echo "  kubectl get service sampleapi-service -n $NAMESPACE"
fi

#########################################
# COMPLETION
#########################################

echo ""
print_info "======================================"
print_info "Application Deployment Complete!"
print_info "======================================"
echo ""
print_info "Deployment Summary:"
echo "  • Image: $FULL_IMAGE_NAME"
echo "  • Namespace: $NAMESPACE"
echo "  • Cluster: $CLUSTER_NAME"
if [ -n "$EXTERNAL_IP" ]; then
    echo "  • External IP: http://$EXTERNAL_IP"
fi
echo ""
print_info "Health Check Endpoints:"
if [ -n "$EXTERNAL_IP" ]; then
    echo "  • Health: http://$EXTERNAL_IP/health"
    echo "  • Products: http://$EXTERNAL_IP/api/products"
else
    echo "  • Health: http://<EXTERNAL_IP>/health"
    echo "  • Products: http://<EXTERNAL_IP>/api/products"
fi
echo ""
print_info "Useful commands:"
echo "  • Get pods: kubectl get pods -n $NAMESPACE"
echo "  • Get services: kubectl get svc -n $NAMESPACE"
echo "  • View logs: kubectl logs -l app=sampleapi -n $NAMESPACE -f"
echo "  • Port forward (testing): kubectl port-forward svc/sampleapi-service 8080:80 -n $NAMESPACE"
echo "  • Describe deployment: kubectl describe deployment sampleapi-deployment -n $NAMESPACE"
echo "  • Scale replicas: kubectl scale deployment sampleapi-deployment --replicas=3 -n $NAMESPACE"
echo ""
print_info "To rebuild and redeploy:"
echo "  • Run this script again: ./deploy-application.sh"
echo "  • Or manually: docker build, docker push, kubectl rollout restart deployment/sampleapi-deployment -n $NAMESPACE"
echo ""
print_info "Monitoring in Dynatrace:"
echo "  • Check that Dynatrace OneAgent is installed (dynatrace namespace)"
echo "  • Application should appear automatically in Dynatrace UI"
echo "  • Navigate to: Applications & Microservices → Services"
echo ""
print_info "Deployment completed successfully! 🎉"
