# Deploy .NET API to AKS with Dynatrace Monitoring

## Prerequisites
- Azure CLI installed
- kubectl installed
- Docker installed
- Access to an Azure subscription
- Dynatrace account with API token

## Step 1: Set up Azure Container Registry (ACR)

```powershell
# Set variables
$RESOURCE_GROUP = "rg-dynatrace-demo"
$LOCATION = "eastus"
$ACR_NAME = "acrdynatracedemo"  # Must be globally unique
$AKS_NAME = "aks-dynatrace-demo"

# Login to Azure
az login

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create ACR
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic

# Login to ACR
az acr login --name $ACR_NAME
```

## Step 2: Build and Push Docker Image

```powershell
# Build the Docker image
docker build -t sampleapi:latest .

# Tag the image for ACR
docker tag sampleapi:latest ${ACR_NAME}.azurecr.io/sampleapi:latest

# Push to ACR
docker push ${ACR_NAME}.azurecr.io/sampleapi:latest
```

## Step 3: Create AKS Cluster

```powershell
# Create AKS cluster with Azure CNI
az aks create `
  --resource-group $RESOURCE_GROUP `
  --name $AKS_NAME `
  --node-count 2 `
  --node-vm-size Standard_D2s_v3 `
  --enable-managed-identity `
  --attach-acr $ACR_NAME `
  --generate-ssh-keys

# Get AKS credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_NAME --overwrite-existing

# Verify connection
kubectl get nodes
```

## Step 4: Install Dynatrace Operator on AKS

### Option A: Using Dynatrace Operator (Recommended)

```powershell
# Create Dynatrace namespace
kubectl apply -f k8s/dynatrace-namespace.yaml

# Install Dynatrace Operator via Helm
helm repo add dynatrace https://raw.githubusercontent.com/Dynatrace/dynatrace-operator/main/config/helm/repos/stable
helm repo update

# Create secret for Dynatrace API access
kubectl create secret generic dynakube `
  --from-literal="apiToken=<YOUR_API_TOKEN>" `
  --from-literal="dataIngestToken=<YOUR_DATA_INGEST_TOKEN>" `
  --namespace dynatrace

# Install the operator
helm install dynatrace-operator dynatrace/dynatrace-operator `
  --namespace dynatrace `
  --create-namespace `
  --set installCRD=true

# Create DynaKube custom resource
kubectl apply -f - <<EOF
apiVersion: dynatrace.com/v1beta1
kind: DynaKube
metadata:
  name: dynakube
  namespace: dynatrace
spec:
  apiUrl: https://<YOUR_ENVIRONMENT_ID>.live.dynatrace.com/api
  tokens: dynakube
  oneAgent:
    cloudNativeFullStack:
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
        operator: Exists
EOF
```

### Option B: Manual OneAgent Installation

```powershell
# Download and apply OneAgent for Kubernetes
# Go to Dynatrace UI > Deploy Dynatrace > Kubernetes
# Follow the instructions to get your custom deployment YAML
# Apply it using: kubectl apply -f dynatrace-oneagent.yaml
```

## Step 5: Configure Application Secrets

```powershell
# Edit the secret file with your Dynatrace details
# Then apply it

# Update k8s/dynatrace-secret.yaml with your values:
# - endpoint: Your Dynatrace environment URL
# - api-token: Your Dynatrace API token

kubectl apply -f k8s/dynatrace-secret.yaml
```

## Step 6: Deploy Application

```powershell
# Update deployment.yaml with your ACR name
# Replace <YOUR_ACR_NAME> with your actual ACR name

kubectl apply -f k8s/deployment.yaml

# Check deployment status
kubectl get pods
kubectl get services

# Get the external IP
kubectl get service sampleapi-service --watch
```

## Step 7: Verify Dynatrace Integration

```powershell
# Check if Dynatrace is injecting into pods
kubectl describe pod <pod-name> | Select-String -Pattern "dynatrace"

# Check logs
kubectl logs <pod-name>
```

## Step 8: Access Your Application

```powershell
# Get the external IP
$EXTERNAL_IP = kubectl get service sampleapi-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test the API
curl http://${EXTERNAL_IP}/
curl http://${EXTERNAL_IP}/api/products
curl http://${EXTERNAL_IP}/health

# Open in browser
Start-Process "http://${EXTERNAL_IP}/swagger"
```

## Step 9: Test Error Scenarios (for Dynatrace)

```powershell
# These will trigger alerts in Dynatrace
curl http://${EXTERNAL_IP}/api/products/error/500
curl http://${EXTERNAL_IP}/api/products/error/exception
curl http://${EXTERNAL_IP}/api/products/error/timeout
```

## Dynatrace Configuration

### Required API Permissions

Your Dynatrace API token needs these permissions:
- `logs.ingest` - For log ingestion
- `metrics.ingest` - For custom metrics
- `DataExport` - For data export
- `ReadConfig` - For reading configuration

### Monitoring Features Available

1. **Application Performance Monitoring (APM)**
   - Request tracing
   - Response times
   - Error rates
   - Database queries

2. **Infrastructure Monitoring**
   - Pod metrics (CPU, memory, network)
   - Node health
   - Container resource usage

3. **Log Analytics**
   - Structured logs from DynatraceLogService
   - HTTP request/response logs
   - Error logs

4. **Custom Metrics**
   - Product operations
   - API endpoint usage
   - Error simulation tracking

## Scaling

```powershell
# Scale up
kubectl scale deployment sampleapi-deployment --replicas=5

# Enable autoscaling
kubectl autoscale deployment sampleapi-deployment --cpu-percent=70 --min=2 --max=10
```

## Cleanup

```powershell
# Delete Kubernetes resources
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/dynatrace-secret.yaml

# Delete AKS cluster
az aks delete --resource-group $RESOURCE_GROUP --name $AKS_NAME --yes --no-wait

# Delete ACR
az acr delete --resource-group $RESOURCE_GROUP --name $ACR_NAME --yes

# Delete resource group
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## Troubleshooting

### Check Pod Status
```powershell
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Check Dynatrace Injection
```powershell
kubectl get pods -o json | Select-String -Pattern "dynatrace"
```

### Check Service Endpoints
```powershell
kubectl get endpoints sampleapi-service
```

### View Events
```powershell
kubectl get events --sort-by='.lastTimestamp'
```

## Next Steps

1. Configure Dynatrace dashboards for your application
2. Set up alerting rules based on error rates
3. Create custom metrics for business KPIs
4. Implement distributed tracing across services
5. Configure log processing rules in Dynatrace
