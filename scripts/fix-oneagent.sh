#!/bin/bash

#########################################
# Fix Dynatrace OneAgent Installation
# Ensures proper OneAgent setup for Problem Detection
#########################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_step() { echo -e "\n${BLUE}▶${NC} $1"; }

# Configuration
RESOURCE_GROUP="dynatrace-demo-rg"
APP_NAME="${1:-dynatrace-demo-api-30529}"
DT_TENANT="vvz65479"
DT_DOMAIN="live.dynatrace.com"

# IMPORTANT: You need a PaaS token (not API token) for OneAgent
# Get it from: Settings → Integration → Platform as a Service
DT_PAAS_TOKEN="${DT_PAAS_TOKEN:-}"

echo "=========================================="
echo "  Dynatrace OneAgent Fix Script"
echo "=========================================="
echo ""
print_info "App Name: $APP_NAME"
print_info "Resource Group: $RESOURCE_GROUP"
print_info "Dynatrace Tenant: $DT_TENANT"
echo ""

#########################################
# Validation
#########################################
print_step "Step 1: Validating prerequisites"

if [ -z "$DT_PAAS_TOKEN" ]; then
    print_error "DT_PAAS_TOKEN not set!"
    echo ""
    echo "You need a PaaS token (NOT an API token) for OneAgent."
    echo ""
    echo "Get it from Dynatrace:"
    echo "  1. Go to: Settings → Integration → Platform as a Service"
    echo "  2. Click 'Generate token'"
    echo "  3. Name it: 'Azure App Service OneAgent'"
    echo "  4. Copy the token"
    echo ""
    echo "Then run:"
    echo "  export DT_PAAS_TOKEN='your-paas-token-here'"
    echo "  ./fix-oneagent.sh $APP_NAME"
    echo ""
    exit 1
fi

if ! command -v az &> /dev/null; then
    print_error "Azure CLI not found"
    exit 1
fi

if ! az account show &> /dev/null; then
    print_error "Not logged into Azure. Run: az login"
    exit 1
fi

print_info "Prerequisites OK"

#########################################
# Check App Service
#########################################
print_step "Step 2: Checking App Service"

if ! az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_error "App Service not found: $APP_NAME"
    exit 1
fi

print_info "App Service found"

#########################################
# Install OneAgent Extension
#########################################
print_step "Step 3: Installing Dynatrace OneAgent extension"

print_warning "This may take 2-3 minutes..."

# Try to uninstall first (in case it exists)
az rest --method delete \
  --url "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${APP_NAME}/siteextensions/Dynatrace.OneAgent.extension?api-version=2022-03-01" \
  &>/dev/null || true

sleep 5

# Install extension
if az rest --method put \
  --url "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${APP_NAME}/siteextensions/Dynatrace.OneAgent.extension?api-version=2022-03-01" \
  --body '{}' &>/dev/null; then
  print_info "OneAgent extension installed"
else
  print_warning "Extension install may have failed - continuing anyway"
fi

sleep 10

#########################################
# Configure App Settings
#########################################
print_step "Step 4: Configuring Dynatrace settings"

print_info "Setting OneAgent configuration..."

az webapp config appsettings set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    DT_TENANT="$DT_TENANT" \
    DT_CONNECTION_POINT="https://${DT_TENANT}.${DT_DOMAIN}" \
    DT_PAAS_TOKEN="$DT_PAAS_TOKEN" \
  --output none

print_info "Configuration updated"

#########################################
# Restart App Service
#########################################
print_step "Step 5: Restarting App Service"

print_warning "Restarting to apply changes..."
az webapp restart \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output none

sleep 5
print_info "App Service restarted"

#########################################
# Wait for OneAgent Initialization
#########################################
print_step "Step 6: Waiting for OneAgent to initialize"

print_warning "OneAgent initialization takes 5-10 minutes"
print_info "Monitoring app status..."

for i in {1..10}; do
  sleep 30
  STATUS=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query state -o tsv)
  if [ "$STATUS" = "Running" ]; then
    print_info "App is running (${i}/10)"
  else
    print_warning "App status: $STATUS (${i}/10)"
  fi
done

#########################################
# Verification
#########################################
print_step "Step 7: Verification"

APP_URL=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)
print_info "App URL: https://$APP_URL"

echo ""
print_info "Testing health endpoint..."
if curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$APP_URL/api/health" | grep -q "200"; then
    print_info "✓ App is responding"
else
    print_warning "App may not be ready yet"
fi

#########################################
# Next Steps
#########################################
echo ""
echo "=========================================="
echo "  OneAgent Installation Complete!"
echo "=========================================="
echo ""
print_info "What happens next:"
echo ""
echo "1. OneAgent starts instrumenting the application (5-10 min)"
echo "2. Service appears in Dynatrace (10-15 min)"
echo "3. Baseline learning begins (20-30 min)"
echo "4. Problems can be detected (30+ min)"
echo ""
print_warning "Timeline for first Problem detection: 30-60 minutes"
echo ""
echo "Verify installation:"
echo "  1. Check service detection:"
echo "     → https://${DT_TENANT}.${DT_DOMAIN}/ui/services"
echo "     → Search for: $APP_NAME"
echo ""
echo "  2. Wait 15 minutes, then generate problems:"
echo "     → cd scripts"
echo "     → ./generate-problems.sh $APP_URL"
echo ""
echo "  3. Check Problems view (after another 15 minutes):"
echo "     → https://${DT_TENANT}.${DT_DOMAIN}/ui/problems"
echo ""
echo "If service is NOT detected after 15 minutes:"
echo "  → Run diagnostics: ./diagnose-dynatrace.sh $APP_NAME"
echo "  → Check logs: az webapp log tail --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo ""
print_warning "Tip: For immediate problem detection:"
echo "  - Lower anomaly thresholds in Settings → Anomaly detection"
echo "  - Create custom event: loglevel = ERROR (> 20 events in 5 min)"
echo ""
