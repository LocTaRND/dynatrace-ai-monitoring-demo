# Complete End-to-End Deployment
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    
    [Parameter(Mandatory=$true)]
    [string]$AksName,
    
    [Parameter(Mandatory=$true)]
    [string]$DynatraceEnvironmentUrl,  # https://abc12345.live.dynatrace.com
    
    [Parameter(Mandatory=$true)]
    [string]$DynatraceApiToken,  # For log ingestion
    
    [Parameter(Mandatory=$true)]
    [string]$DynatraceOperatorApiToken,  # For operator (InstallerDownload + DataExport)
    
    [Parameter(Mandatory=$true)]
    [string]$DynatraceDataIngestToken,  # For operator (metrics.ingest + logs.ingest)
    
    [string]$Location = "eastus"
)

Write-Host "=== Complete AKS + Dynatrace Setup ===" -ForegroundColor Green

# Phase 1: Azure Infrastructure
Write-Host "`n### Phase 1: Setting up Azure Infrastructure ###" -ForegroundColor Magenta

Write-Host "`n[1/3] Creating Resource Group..." -ForegroundColor Cyan
az group create --name $ResourceGroup --location $Location
Write-Host "✓ Resource group created" -ForegroundColor Green

Write-Host "`n[2/3] Creating Azure Container Registry..." -ForegroundColor Cyan
az acr create --resource-group $ResourceGroup --name $AcrName --sku Standard
az acr login --name $AcrName
Write-Host "✓ ACR created and logged in" -ForegroundColor Green

Write-Host "`n[3/3] Creating AKS Cluster..." -ForegroundColor Cyan
az aks create `
    --resource-group $ResourceGroup `
    --name $AksName `
    --node-count 2 `
    --node-vm-size Standard_D2s_v3 `
    --enable-managed-identity `
    --attach-acr $AcrName `
    --generate-ssh-keys `
    --network-plugin azure

az aks get-credentials --resource-group $ResourceGroup --name $AksName --overwrite-existing
Write-Host "✓ AKS cluster created" -ForegroundColor Green

# Phase 2: Install Dynatrace
Write-Host "`n### Phase 2: Installing Dynatrace Operator ###" -ForegroundColor Magenta
.\setup-dynatrace-operator.ps1 `
    -DynatraceEnvironmentUrl $DynatraceEnvironmentUrl `
    -ApiToken $DynatraceOperatorApiToken `
    -DataIngestToken $DynatraceDataIngestToken

# Wait for Dynatrace to be ready
Write-Host "`nWaiting for Dynatrace operator to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Phase 3: Deploy Application
Write-Host "`n### Phase 3: Deploying Application ###" -ForegroundColor Magenta
.\deploy.ps1 `
    -ResourceGroup $ResourceGroup `
    -AcrName $AcrName `
    -AksName $AksName `
    -DynatraceEndpoint $DynatraceEnvironmentUrl `
    -DynatraceApiToken $DynatraceApiToken `
    -Location $Location

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
Write-Host "`nMonitor your application in Dynatrace:" -ForegroundColor Yellow
Write-Host "  $DynatraceEnvironmentUrl" -ForegroundColor Cyan
