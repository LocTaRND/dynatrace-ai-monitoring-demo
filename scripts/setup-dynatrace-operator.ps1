# Install Dynatrace Operator on AKS
param(
    [Parameter(Mandatory=$true)]
    [string]$DynatraceEnvironmentUrl,  # e.g., https://abc12345.live.dynatrace.com
    
    [Parameter(Mandatory=$true)]
    [string]$ApiToken,  # Token with "InstallerDownload" and "DataExport" permissions
    
    [Parameter(Mandatory=$true)]
    [string]$DataIngestToken  # Token with "metrics.ingest" and "logs.ingest" permissions
)

Write-Host "=== Installing Dynatrace Operator on AKS ===" -ForegroundColor Green

# Step 1: Add Dynatrace Helm repo
Write-Host "`n[1/5] Adding Dynatrace Helm repository..." -ForegroundColor Cyan
helm repo add dynatrace https://raw.githubusercontent.com/Dynatrace/dynatrace-operator/main/config/helm/repos/stable
helm repo update
Write-Host "✓ Helm repo added" -ForegroundColor Green

# Step 2: Create Dynatrace namespace
Write-Host "`n[2/5] Creating Dynatrace namespace..." -ForegroundColor Cyan
kubectl apply -f k8s/dynatrace-namespace.yaml
Write-Host "✓ Namespace created" -ForegroundColor Green

# Step 3: Create secret for Dynatrace tokens
Write-Host "`n[3/5] Creating Dynatrace tokens secret..." -ForegroundColor Cyan
kubectl create secret generic dynakube `
    --from-literal="apiToken=$ApiToken" `
    --from-literal="dataIngestToken=$DataIngestToken" `
    --namespace dynatrace `
    --dry-run=client -o yaml | kubectl apply -f -
Write-Host "✓ Secret created" -ForegroundColor Green

# Step 4: Install Dynatrace Operator
Write-Host "`n[4/5] Installing Dynatrace Operator..." -ForegroundColor Cyan
helm install dynatrace-operator dynatrace/dynatrace-operator `
    --namespace dynatrace `
    --create-namespace `
    --set installCRD=true `
    --wait
Write-Host "✓ Operator installed" -ForegroundColor Green

# Step 5: Create DynaKube custom resource
Write-Host "`n[5/5] Configuring DynaKube for full-stack monitoring..." -ForegroundColor Cyan

$dynaKubeYaml = @"
apiVersion: dynatrace.com/v1beta1
kind: DynaKube
metadata:
  name: dynakube
  namespace: dynatrace
spec:
  apiUrl: $DynatraceEnvironmentUrl/api
  skipCertCheck: false
  networkZone: ""
  tokens: dynakube
  
  # CloudNative FullStack monitoring
  oneAgent:
    cloudNativeFullStack:
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
        operator: Exists
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 300m
          memory: 512Mi
  
  # ActiveGate for routing
  activeGate:
    capabilities:
    - routing
    - kubernetes-monitoring
    - dynatrace-api
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi
"@

$dynaKubeYaml | kubectl apply -f -

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ DynaKube configured" -ForegroundColor Green
    
    Write-Host "`n=== Dynatrace Operator Installation Complete ===" -ForegroundColor Green
    Write-Host "`nVerify installation:" -ForegroundColor Yellow
    Write-Host "  kubectl get pods -n dynatrace"
    Write-Host "  kubectl get dynakube -n dynatrace"
    Write-Host "`nWait for all pods to be Running, then deploy your application." -ForegroundColor Yellow
} else {
    Write-Host "✗ Failed to create DynaKube" -ForegroundColor Red
    exit 1
}

# Show status
Write-Host "`nCurrent status:" -ForegroundColor Cyan
kubectl get pods -n dynatrace
