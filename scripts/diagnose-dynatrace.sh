#!/bin/bash

#########################################
# Dynatrace OneAgent Diagnostic Script
# Checks if OneAgent is properly configured
#########################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_section() { echo -e "\n${BLUE}═══ $1 ═══${NC}"; }

# Configuration
RESOURCE_GROUP="dynatrace-demo-rg"
APP_NAME="${1:-dynatrace-demo-api-30529}"
DT_TENANT="vvz65479"

echo "=========================================="
echo "  Dynatrace OneAgent Diagnostic Tool"
echo "=========================================="
echo ""
print_info "App Name: $APP_NAME"
print_info "Resource Group: $RESOURCE_GROUP"
echo ""

#########################################
# Check Azure CLI
#########################################
print_section "Azure CLI Check"
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    exit 1
fi
print_info "Azure CLI installed"

# Check login
if ! az account show &> /dev/null; then
    print_error "Not logged into Azure. Run: az login"
    exit 1
fi
SUBSCRIPTION=$(az account show --query name -o tsv)
print_info "Logged in to: $SUBSCRIPTION"

#########################################
# Check App Service Exists
#########################################
print_section "App Service Check"
if az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_info "App Service exists: $APP_NAME"
    
    # Get app status
    STATUS=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query state -o tsv)
    if [ "$STATUS" = "Running" ]; then
        print_info "App Status: $STATUS"
    else
        print_warning "App Status: $STATUS (not running)"
    fi
    
    # Get URL
    URL=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)
    print_info "App URL: https://$URL"
else
    print_error "App Service not found: $APP_NAME"
    exit 1
fi

#########################################
# Check OneAgent Extension
#########################################
print_section "OneAgent Extension Check"
echo "Checking for Dynatrace site extensions..."

EXTENSIONS=$(az rest --method get \
  --url "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${APP_NAME}/siteextensions?api-version=2022-03-01" \
  --query "value[].{id:id,name:properties.title,version:properties.version}" -o json 2>/dev/null)

if echo "$EXTENSIONS" | grep -q "Dynatrace"; then
    print_info "Dynatrace OneAgent extension is installed"
    echo "$EXTENSIONS" | grep -i dynatrace
else
    print_error "Dynatrace OneAgent extension is NOT installed"
    print_warning "Install using: az webapp deployment site-extension install --name $APP_NAME --resource-group $RESOURCE_GROUP --extension-name Dynatrace.OneAgent.extension"
fi

#########################################
# Check Dynatrace App Settings
#########################################
print_section "Dynatrace Configuration Check"
echo "Checking application settings..."

SETTINGS=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" -o json)

# Check DT_TENANT
if echo "$SETTINGS" | grep -q "DT_TENANT"; then
    DT_TENANT_VALUE=$(echo "$SETTINGS" | jq -r '.[] | select(.name=="DT_TENANT") | .value')
    print_info "DT_TENANT = $DT_TENANT_VALUE"
else
    print_error "DT_TENANT not configured"
fi

# Check DT_CONNECTION_POINT
if echo "$SETTINGS" | grep -q "DT_CONNECTION_POINT"; then
    DT_CONN=$(echo "$SETTINGS" | jq -r '.[] | select(.name=="DT_CONNECTION_POINT") | .value')
    print_info "DT_CONNECTION_POINT = $DT_CONN"
else
    print_error "DT_CONNECTION_POINT not configured"
fi

# Check DT_PAAS_TOKEN
if echo "$SETTINGS" | grep -q "DT_PAAS_TOKEN"; then
    print_info "DT_PAAS_TOKEN = <configured>"
else
    print_error "DT_PAAS_TOKEN not configured (required for OneAgent)"
fi

# Check DT_ENDPOINT (for logs)
if echo "$SETTINGS" | grep -q "DT_ENDPOINT"; then
    DT_ENDPOINT=$(echo "$SETTINGS" | jq -r '.[] | select(.name=="DT_ENDPOINT") | .value')
    print_info "DT_ENDPOINT = $DT_ENDPOINT"
else
    print_warning "DT_ENDPOINT not set (only needed for custom log API)"
fi

# Check DT_API_TOKEN (for logs)
if echo "$SETTINGS" | grep -q "DT_API_TOKEN"; then
    print_info "DT_API_TOKEN = <configured>"
else
    print_warning "DT_API_TOKEN not set (only needed for custom log API)"
fi

#########################################
# Test Application Endpoints
#########################################
print_section "Application Endpoint Test"
BASE_URL="https://$URL"

echo "Testing health endpoint..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/api/health" 2>/dev/null || echo "failed")
if [ "$HEALTH_STATUS" = "200" ]; then
    print_info "Health endpoint: $HEALTH_STATUS OK"
else
    print_error "Health endpoint: $HEALTH_STATUS (expected 200)"
fi

echo "Testing error endpoint (should return 500)..."
ERROR_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$BASE_URL/api/products/error/500" 2>/dev/null || echo "failed")
if [ "$ERROR_STATUS" = "500" ]; then
    print_info "Error endpoint: $ERROR_STATUS (working)"
else
    print_warning "Error endpoint: $ERROR_STATUS (expected 500)"
fi

#########################################
# Check Recent Logs
#########################################
print_section "Recent Application Logs"
echo "Fetching last 50 log entries..."

az webapp log download --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --log-file "diagnostic_logs.zip" &>/dev/null || true

if [ -f "diagnostic_logs.zip" ]; then
    print_info "Logs downloaded to: diagnostic_logs.zip"
    print_warning "Check LogFiles/Application/*.txt for OneAgent messages"
    rm -f diagnostic_logs.zip
fi

#########################################
# Recommendations
#########################################
print_section "Recommendations"

echo ""
echo "Next Steps:"
echo ""
echo "1. Check if service is detected in Dynatrace:"
echo "   → https://${DT_TENANT}.live.dynatrace.com/ui/services"
echo "   → Search for: $APP_NAME"
echo ""
echo "2. If service is NOT detected:"
echo "   → OneAgent may not be instrumenting the app"
echo "   → Reinstall OneAgent extension"
echo "   → Restart the app service"
echo ""
echo "3. Generate test load:"
echo "   → cd scripts"
echo "   → ./generate-problems.sh $URL"
echo ""
echo "4. Check for Problems (after 10-15 minutes):"
echo "   → https://${DT_TENANT}.live.dynatrace.com/ui/problems"
echo ""
echo "5. If Problems still don't appear:"
echo "   → Lower anomaly detection thresholds"
echo "   → Check Settings → Anomaly detection → Services"
echo "   → Set sensitivity to 'High' for testing"
echo ""

print_warning "Problems require ~10-30 minutes for baseline learning"
print_warning "First-time deployments may need 30-60 minutes"

echo ""
echo "=========================================="
echo "  Diagnostic Complete"
echo "=========================================="
