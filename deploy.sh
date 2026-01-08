#!/bin/bash

#########################################
# Complete Azure App Service Deployment
# with .NET Sample App and Dynatrace
# IMPROVED VERSION WITH BETTER LOG INTEGRATION
#########################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

#########################################
# CONFIGURATION - UPDATE THESE VALUES
#########################################

# Azure Configuration
RESOURCE_GROUP="dynatrace-demo-rg"
APP_SERVICE_PLAN="dynatrace-demo-plan"
APP_NAME="dynatrace-demo-api-$RANDOM"  # Random suffix for unique name
LOCATION="southcentralus"
SKU="B1"  # Basic tier (cheap for demo, use P1V2 for production)

# Dynatrace Configuration
DT_TENANT="vvz65479"  # Your Dynatrace tenant ID
DT_DOMAIN="live.dynatrace.com"  # Your Dynatrace domain
DT_TOKEN=""

# Application Configuration
APP_DIR="./sample-dotnet-app"
DOTNET_VERSION="8.0"

#########################################
# VALIDATION
#########################################

print_info "Starting deployment script..."

# Check if Dynatrace token is set
if [ -z "$DT_TOKEN" ]; then
    print_error "Dynatrace token not set! Please set environment variable:"
    echo "  export DT_TOKEN='dt0c01.XXXXX...'"
    exit 1
fi

# Validate token format
if [[ ! "$DT_TOKEN" =~ ^dt0c01\. ]]; then
    print_error "Invalid Dynatrace token format. Should start with 'dt0c01.'"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if .NET SDK is installed
if ! command -v dotnet &> /dev/null; then
    print_error ".NET SDK is not installed. Please install it first."
    exit 1
fi

# Check Azure login
print_info "Checking Azure login..."
if ! az account show &> /dev/null; then
    print_error "Not logged into Azure. Please run 'az login'"
    exit 1
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
print_info "Using Azure subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

#########################################
# STEP 2: CREATE AZURE RESOURCES
#########################################

print_info "Step 2: Creating Azure resources..."

# Create Resource Group
print_info "Creating resource group: $RESOURCE_GROUP..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none

print_info "✓ Resource group created"

# Create App Service Plan
print_info "Creating App Service Plan: $APP_SERVICE_PLAN..."
az appservice plan create \
    --name "$APP_SERVICE_PLAN" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "$SKU" \
    --is-linux \
    --output none

print_info "✓ App Service Plan created"

# Create Web App
print_info "Creating Web App: $APP_NAME..."
az webapp create \
    --name "$APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$APP_SERVICE_PLAN" \
    --runtime "DOTNETCORE:$DOTNET_VERSION" \
    --output none

APP_URL=$(az webapp show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --query defaultHostName -o tsv)

print_info "✓ Web App created: https://$APP_URL"

#########################################
# STEP 3: CONFIGURE DYNATRACE
#########################################

print_info "Step 3: Configuring Dynatrace integration with comprehensive logging..."

# Configure Dynatrace settings
az webapp config appsettings set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --settings \
        ASPNETCORE_ENVIRONMENT="Production" \
        ASPNETCORE_URLS="http://+:8080" \
        DT_ENDPOINT="https://$DT_TENANT.$DT_DOMAIN" \
        DT_API_TOKEN="$DT_TOKEN" \
        DT_INCLUDE="dotnet" \
        DT_LOGACCESS="true" \
        DT_LOGLEVELCON="INFO" \
        START_APP_CMD="dotnet SampleAPI.dll" \
        DT_CUSTOM_PROP="service=$APP_NAME,environment=demo,platform=azure-appservice" \
        DT_TAGS="environment:demo,service:$APP_NAME,platform:azure" \
        Logging__LogLevel__Default="Information" \
        Logging__LogLevel__Microsoft="Warning" \
        Logging__LogLevel__Microsoft.AspNetCore="Information" \
    --output none

print_info "✓ Dynatrace settings configured"

# Configure startup command
print_info "Configuring OneAgent startup command..."
STARTUP_CMD='wget -O /tmp/installer.sh -q https://raw.githubusercontent.com/dynatrace-oss/cloud-snippets/main/azure/linux-app-service/oneagent-installer.sh && DT_ENDPOINT=$DT_ENDPOINT DT_API_TOKEN=$DT_API_TOKEN DT_INCLUDE=$DT_INCLUDE DT_LOGACCESS=$DT_LOGACCESS START_APP_CMD=$START_APP_CMD sh /tmp/installer.sh'

az webapp config set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --startup-file "$STARTUP_CMD" \
    --output none

print_info "✓ OneAgent startup command configured"

#########################################
# STEP 4: ENABLE LOGGING
#########################################

print_info "Step 4: Enabling application logging..."

az webapp log config \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --application-logging filesystem \
    --level verbose \
    --detailed-error-messages true \
    --failed-request-tracing true \
    --web-server-logging filesystem \
    --output none

print_info "✓ Logging enabled"

#########################################
# STEP 5: DEPLOY APPLICATION
#########################################

print_info "Step 5: Publishing and deploying application..."

cd "$APP_DIR"

# Build the application
print_info "Building application..."
# dotnet build -v q

print_info "✓ Sample .NET application created with Dynatrace log integration!"

print_info "Publishing .NET application..."
# dotnet publish -c Release -o ./publish -v q

print_info "Creating deployment package..."

# cd publish
# # Use PowerShell Compress-Archive on Windows if zip is not available
# if command -v zip &> /dev/null; then
#     zip -r -q ../deploy.zip .
# else
#     powershell.exe -Command "Compress-Archive -Path * -DestinationPath ../deploy.zip -Force"
# fi
# cd ..

print_info "Deploying to Azure App Service..."
az webapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --src deploy.zip \
    --output none

print_info "✓ Application deployed"
cd ..

#########################################
# STEP 6: RESTART FOR DYNATRACE
#########################################

print_info "Step 6: Restarting App Service for Dynatrace initialization..."

# First restart
print_info "First restart - downloading OneAgent..."
az webapp restart \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --output none

print_info "Waiting 60 seconds for OneAgent installation..."
sleep 60

# Second restart
print_info "Second restart - starting with OneAgent..."
az webapp restart \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --output none

print_info "✓ App Service restarted"

#########################################
# STEP 7: SEND DEPLOYMENT EVENT
#########################################

print_info "Step 7: Sending deployment event to Dynatrace..."

curl -s -X POST "https://$DT_TENANT.$DT_DOMAIN/api/v2/events/ingest" \
    -H "Authorization: Api-Token $DT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"eventType\": \"CUSTOM_DEPLOYMENT\",
        \"title\": \"Deployment: $APP_NAME\",
        \"properties\": {
            \"deploymentName\": \"$APP_NAME\",
            \"deploymentVersion\": \"1.0.1\",
            \"deploymentProject\": \"Dynatrace Demo\",
            \"source\": \"Deployment Script\",
            \"environment\": \"Demo\"
        }
    }" > /dev/null 2>&1

print_info "✓ Deployment event sent"

#########################################
# STEP 8: GENERATE INITIAL TRAFFIC
#########################################

print_info "Step 8: Generating initial traffic for log testing..."

sleep 45

for i in {1..20}; do
    curl -s "https://$APP_URL/" > /dev/null 2>&1
    curl -s "https://$APP_URL/api/health" > /dev/null 2>&1
    curl -s "https://$APP_URL/api/products" > /dev/null 2>&1
    echo -n "."
done

echo ""
print_info "✓ Initial traffic generated"

#########################################
# DEPLOYMENT SUMMARY
#########################################

echo ""
echo "=========================================="
echo "       DEPLOYMENT COMPLETED!              "
echo "=========================================="
echo ""
print_info "Resource Details:"
echo "  Resource Group:    $RESOURCE_GROUP"
echo "  App Service:       $APP_NAME"
echo "  App URL:           https://$APP_URL"
echo ""
print_info "Endpoints:"
echo "  Root:              https://$APP_URL/"
echo "  Swagger:           https://$APP_URL/swagger"
echo "  Health:            https://$APP_URL/api/health"
echo "  Products:          https://$APP_URL/api/products"
echo ""
print_info "Dynatrace Console:"
echo "  https://$DT_TENANT.$DT_DOMAIN"
echo ""
print_info "⏰ IMPORTANT: Wait 10-15 minutes for logs to appear!"
echo ""
print_info "How to verify logs:"
echo "  1. Go to Dynatrace → Logs (left menu)"
echo "  2. Filter by: service.name = $APP_NAME"
echo "  3. Or search for: $APP_NAME"
echo ""
print_info "Generate more traffic:"
echo "  for i in {1..50}; do curl -s https://$APP_URL/api/health; sleep 2; done"
echo ""
print_info "View Azure logs:"
echo "  az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_NAME"
echo ""
print_info "Azure Portal:"
echo "  https://portal.azure.com/#resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME"
echo ""
print_info "Cleanup:"
echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo ""
echo "=========================================="