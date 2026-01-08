# Quick start deployment script
param(
    [string]$ConfigFile = "deploy-config.json"
)

if (Test-Path $ConfigFile) {
    $config = Get-Content $ConfigFile | ConvertFrom-Json
    
    Write-Host "Using configuration from $ConfigFile" -ForegroundColor Cyan
    
    .\deploy.ps1 `
        -ResourceGroup $config.resourceGroup `
        -AcrName $config.acrName `
        -AksName $config.aksName `
        -DynatraceEndpoint $config.dynatraceEndpoint `
        -DynatraceApiToken $config.dynatraceApiToken `
        -Location $config.location `
        -ImageTag $config.imageTag
} else {
    Write-Host "Configuration file not found: $ConfigFile" -ForegroundColor Red
    Write-Host "`nCreating template configuration file..." -ForegroundColor Yellow
    
    $template = @{
        resourceGroup = "rg-dynatrace-demo"
        acrName = "acrdynatracedemo"
        aksName = "aks-dynatrace-demo"
        dynatraceEndpoint = "https://YOUR_ENVIRONMENT.live.dynatrace.com"
        dynatraceApiToken = "YOUR_API_TOKEN"
        location = "eastus"
        imageTag = "latest"
    }
    
    $template | ConvertTo-Json | Set-Content $ConfigFile
    
    Write-Host "✓ Template created: $ConfigFile" -ForegroundColor Green
    Write-Host "Please update it with your values and run again." -ForegroundColor Yellow
}
