#!/bin/bash

#########################################
# Dynatrace OneAgent Debug Script
#########################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Get the app name from user or find it
if [ -z "$1" ]; then
    print_error "Usage: $0 <app-name> [resource-group]"
    echo "Example: $0 dynatrace-demo-api-12345 dynatrace-demo-rg"
    exit 1
fi

APP_NAME="$1"
RESOURCE_GROUP="${2:-dynatrace-demo-rg}"

print_section "Dynatrace OneAgent Debugging"
print_info "App Name: $APP_NAME"
print_info "Resource Group: $RESOURCE_GROUP"

#########################################
# 1. Check App Service Configuration
#########################################

print_section "1. App Service Configuration"

print_info "Checking if app exists..."
if ! az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    print_error "App Service not found!"
    exit 1
fi
print_info "✓ App Service exists"

# Check runtime
RUNTIME=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "siteConfig.linuxFxVersion" -o tsv)
print_info "Runtime: $RUNTIME"

#########################################
# 2. Check Dynatrace Environment Variables
#########################################

print_section "2. Dynatrace Environment Variables"

print_info "Fetching app settings..."
DT_ENDPOINT=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_ENDPOINT'].value" -o tsv)
DT_API_TOKEN=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_API_TOKEN'].value" -o tsv)
DT_INCLUDE=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_INCLUDE'].value" -o tsv)
START_APP_CMD=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='START_APP_CMD'].value" -o tsv)

if [ -z "$DT_ENDPOINT" ]; then
    print_error "DT_ENDPOINT is not set!"
else
    print_info "✓ DT_ENDPOINT: $DT_ENDPOINT"
fi

if [ -z "$DT_API_TOKEN" ]; then
    print_error "DT_API_TOKEN is not set!"
else
    print_info "✓ DT_API_TOKEN: ${DT_API_TOKEN:0:20}... (hidden)"
fi

if [ -z "$DT_INCLUDE" ]; then
    print_warning "DT_INCLUDE is not set! Should be 'dotnet'"
else
    print_info "✓ DT_INCLUDE: $DT_INCLUDE"
fi

if [ -z "$START_APP_CMD" ]; then
    print_warning "START_APP_CMD is not set!"
else
    print_info "✓ START_APP_CMD: $START_APP_CMD"
fi

#########################################
# 3. Check Startup Command
#########################################

print_section "3. Startup Command Configuration"

STARTUP_FILE=$(az webapp config show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "appCommandLine" -o tsv)

if [ -z "$STARTUP_FILE" ]; then
    print_error "Startup command is NOT configured!"
    print_warning "OneAgent will NOT be installed without a startup command."
else
    print_info "✓ Startup command is configured"
    echo "Command: $STARTUP_FILE"
fi

#########################################
# 4. Check Application Logs
#########################################

print_section "4. Application Logs (Last 50 lines)"

print_info "Fetching application logs..."
print_warning "Looking for OneAgent installation messages..."

az webapp log tail --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --logs application 2>/dev/null | head -n 50 || {
    print_warning "Could not fetch logs. Trying download..."
    az webapp log download --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --log-file "webapp-logs.zip" 2>/dev/null
    if [ -f "webapp-logs.zip" ]; then
        print_info "Logs downloaded to webapp-logs.zip"
        unzip -q webapp-logs.zip
        print_info "Latest logs:"
        find LogFiles -name "*.log" -type f -exec tail -n 20 {} \;
    fi
}

#########################################
# 5. Test Application Endpoints
#########################################

print_section "5. Testing Application Endpoints"

APP_URL=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "defaultHostName" -o tsv)
print_info "App URL: https://$APP_URL"

# Test root endpoint
print_info "Testing root endpoint..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$APP_URL/" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_info "✓ Root endpoint: HTTP $HTTP_STATUS"
else
    print_warning "Root endpoint: HTTP $HTTP_STATUS"
fi

# Test health endpoint
print_info "Testing health endpoint..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$APP_URL/api/health" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_info "✓ Health endpoint: HTTP $HTTP_STATUS"
else
    print_warning "Health endpoint: HTTP $HTTP_STATUS"
fi

#########################################
# 6. Dynatrace Connectivity Test
#########################################

print_section "6. Dynatrace Connectivity Test"

if [ -n "$DT_ENDPOINT" ]; then
    print_info "Testing connectivity to Dynatrace endpoint..."
    
    # Test basic connectivity
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DT_ENDPOINT" 2>/dev/null || echo "000")
    if [ "$HTTP_STATUS" != "000" ]; then
        print_info "✓ Dynatrace endpoint is reachable (HTTP $HTTP_STATUS)"
    else
        print_error "Cannot reach Dynatrace endpoint!"
    fi
    
    # Test API token (if available)
    if [ -n "$DT_API_TOKEN" ]; then
        print_info "Testing API token..."
        API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Api-Token $DT_API_TOKEN" "$DT_ENDPOINT/api/v2/entities" 2>/dev/null || echo "000")
        if [ "$API_STATUS" = "200" ]; then
            print_info "✓ API token is valid"
        else
            print_error "API token test failed (HTTP $API_STATUS)"
        fi
    fi
fi

#########################################
# 7. Recommendations
#########################################

print_section "7. Troubleshooting Recommendations"

echo ""
print_info "Common issues and fixes:"
echo ""
echo "1. If OneAgent is not installing:"
echo "   - Verify startup command is set: az webapp config show -n $APP_NAME -g $RESOURCE_GROUP --query appCommandLine"
echo "   - Restart app twice: az webapp restart -n $APP_NAME -g $RESOURCE_GROUP (run twice with 30s wait)"
echo ""
echo "2. If data is not appearing in Dynatrace:"
echo "   - Wait 5-10 minutes after deployment"
echo "   - Check if domain is allowlisted in Dynatrace settings"
echo "   - Verify API token has 'Ingest data' permission"
echo ""
echo "3. View real-time logs:"
echo "   az webapp log tail -n $APP_NAME -g $RESOURCE_GROUP"
echo ""
echo "4. Check OneAgent installation in container:"
echo "   az webapp ssh -n $APP_NAME -g $RESOURCE_GROUP"
echo "   Then run: ls -la /opt/dynatrace/oneagent/"
echo ""
echo "5. Re-configure OneAgent:"
echo "   - Run the deployment script again"
echo "   - Or manually set startup command with proper environment variables"
echo ""

print_section "Debug Complete"
print_info "For more help, check: https://docs.dynatrace.com/docs/ingest-from/microsoft-azure-services/azure-integrations/azure-appservice"
