# PowerShell script to deploy the application to AKS
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    
    [Parameter(Mandatory=$true)]
    [string]$AksName,
    
    [Parameter(Mandatory=$true)]
    [string]$DynatraceEndpoint,
    
    [Parameter(Mandatory=$true)]
    [string]$DynatraceApiToken,
    
    [string]$Location = "eastus",
    [string]$ImageTag = "latest"
)

Write-Host "=== Deploying Sample API to AKS with Dynatrace ===" -ForegroundColor Green

# Step 1: Build and push Docker image
Write-Host "`n[1/6] Building and pushing Docker image..." -ForegroundColor Cyan
docker build -t sampleapi:$ImageTag .
if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }

docker tag sampleapi:$ImageTag ${AcrName}.azurecr.io/sampleapi:$ImageTag
docker push ${AcrName}.azurecr.io/sampleapi:$ImageTag
if ($LASTEXITCODE -ne 0) { throw "Docker push failed" }

Write-Host "✓ Image pushed successfully" -ForegroundColor Green

# Step 2: Get AKS credentials
Write-Host "`n[2/6] Getting AKS credentials..." -ForegroundColor Cyan
az aks get-credentials --resource-group $ResourceGroup --name $AksName --overwrite-existing
if ($LASTEXITCODE -ne 0) { throw "Failed to get AKS credentials" }

Write-Host "✓ AKS credentials configured" -ForegroundColor Green

# Step 3: Create Dynatrace secret
Write-Host "`n[3/6] Creating Dynatrace secret..." -ForegroundColor Cyan
kubectl delete secret dynatrace-config --ignore-not-found=true

kubectl create secret generic dynatrace-config `
    --from-literal=endpoint=$DynatraceEndpoint `
    --from-literal=api-token=$DynatraceApiToken

if ($LASTEXITCODE -ne 0) { throw "Failed to create secret" }

Write-Host "✓ Dynatrace secret created" -ForegroundColor Green

# Step 4: Update deployment manifest
Write-Host "`n[4/6] Updating deployment manifest..." -ForegroundColor Cyan
$deploymentContent = Get-Content -Path "k8s/deployment.yaml" -Raw
$deploymentContent = $deploymentContent -replace '<YOUR_ACR_NAME>', $AcrName
$deploymentContent | Set-Content -Path "k8s/deployment.yaml"

Write-Host "✓ Deployment manifest updated" -ForegroundColor Green

# Step 5: Deploy to AKS
Write-Host "`n[5/6] Deploying to AKS..." -ForegroundColor Cyan
kubectl apply -f k8s/deployment.yaml
if ($LASTEXITCODE -ne 0) { throw "Deployment failed" }

Write-Host "✓ Application deployed" -ForegroundColor Green

# Step 6: Wait for external IP
Write-Host "`n[6/6] Waiting for external IP assignment..." -ForegroundColor Cyan
$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $externalIp = kubectl get service sampleapi-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    
    if ($externalIp -and $externalIp -ne "") {
        Write-Host "✓ External IP assigned: $externalIp" -ForegroundColor Green
        
        Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
        Write-Host "`nApplication URLs:" -ForegroundColor Yellow
        Write-Host "  API Base: http://$externalIp"
        Write-Host "  Swagger: http://$externalIp/swagger"
        Write-Host "  Health: http://$externalIp/health"
        Write-Host "  Products: http://$externalIp/api/products"
        
        Write-Host "`nTest error endpoints:" -ForegroundColor Yellow
        Write-Host "  curl http://$externalIp/api/products/error/500"
        Write-Host "  curl http://$externalIp/api/products/error/exception"
        
        Write-Host "`nMonitor in Dynatrace:" -ForegroundColor Yellow
        Write-Host "  Environment: $DynatraceEndpoint"
        
        exit 0
    }
    
    $attempt++
    Write-Host "  Waiting for external IP... ($attempt/$maxAttempts)"
    Start-Sleep -Seconds 10
}

Write-Host "⚠ Timeout waiting for external IP. Check status manually with: kubectl get service sampleapi-service" -ForegroundColor Yellow
