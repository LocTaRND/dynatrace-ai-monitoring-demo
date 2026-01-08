#!/bin/bash

#########################################
# Dynatrace Log Ingestion Debug Script
#########################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}========================================${NC}"; }

if [ -z "$1" ]; then
    print_error "Usage: $0 <app-name> [resource-group]"
    echo "Example: $0 dynatrace-demo-api-7536 dynatrace-demo-rg"
    exit 1
fi

APP_NAME="$1"
RESOURCE_GROUP="${2:-dynatrace-demo-rg}"

print_section "Dynatrace Log Ingestion Debug"
print_info "App: $APP_NAME"
print_info "Resource Group: $RESOURCE_GROUP"

#########################################
# 1. Check App Configuration
#########################################

print_section "1. Dynatrace Environment Variables"

DT_ENDPOINT=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_ENDPOINT'].value" -o tsv)
DT_API_TOKEN=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_API_TOKEN'].value" -o tsv)
DT_INCLUDE=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_INCLUDE'].value" -o tsv)
DT_LOGSTREAM=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_LOGSTREAM'].value" -o tsv)
DT_LOGLEVELCON=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_LOGLEVELCON'].value" -o tsv)
DT_LOGLEVELFILE=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_LOGLEVELFILE'].value" -o tsv)
DT_LOGACCESS=$(az webapp config appsettings list --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[?name=='DT_LOGACCESS'].value" -o tsv)

[ -z "$DT_ENDPOINT" ] && print_error "DT_ENDPOINT not set!" || print_info "✓ DT_ENDPOINT: $DT_ENDPOINT"
[ -z "$DT_API_TOKEN" ] && print_error "DT_API_TOKEN not set!" || print_info "✓ DT_API_TOKEN: ${DT_API_TOKEN:0:20}..."
[ -z "$DT_INCLUDE" ] && print_warning "DT_INCLUDE not set!" || print_info "✓ DT_INCLUDE: $DT_INCLUDE"
[ -z "$DT_LOGSTREAM" ] && print_warning "DT_LOGSTREAM not set!" || print_info "✓ DT_LOGSTREAM: $DT_LOGSTREAM"
[ -z "$DT_LOGLEVELCON" ] && print_warning "DT_LOGLEVELCON not set!" || print_info "✓ DT_LOGLEVELCON: $DT_LOGLEVELCON"
[ -z "$DT_LOGLEVELFILE" ] && print_warning "DT_LOGLEVELFILE not set!" || print_info "✓ DT_LOGLEVELFILE: $DT_LOGLEVELFILE"
[ -z "$DT_LOGACCESS" ] && print_error "DT_LOGACCESS not set! This is REQUIRED for log ingestion!" || print_info "✓ DT_LOGACCESS: $DT_LOGACCESS"

#########################################
# 2. Check Startup Command
#########################################

print_section "2. Startup Command"

STARTUP_CMD=$(az webapp config show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query "appCommandLine" -o tsv)

if [ -z "$STARTUP_CMD" ]; then
    print_error "No startup command configured!"
else
    print_info "✓ Startup command exists"
    if echo "$STARTUP_CMD" | grep -q "DT_LOGACCESS"; then
        print_info "✓ Startup command includes DT_LOGACCESS"
    else
        print_error "Startup command missing DT_LOGACCESS parameter!"
        print_warning "This is required for log ingestion to work"
    fi
fi

#########################################
# 3. Check Application Logs
#########################################

print_section "3. Recent Application Logs"

print_info "Downloading logs..."
az webapp log download --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --log-file "debug-logs.zip" 2>/dev/null

if [ -f "debug-logs.zip" ]; then
    unzip -q -o debug-logs.zip -d debug-logs
    
    print_info "Looking for OneAgent and log-related messages..."
    
    # Find latest docker log
    LATEST_LOG=$(find debug-logs -name "*default_docker.log" -type f | sort -r | head -1)
    
    if [ -n "$LATEST_LOG" ]; then
        print_info "Latest container log: $LATEST_LOG"
        echo ""
        
        # Check for OneAgent installation
        if grep -q "liboneagentproc.so" "$LATEST_LOG"; then
            print_info "✓ OneAgent library reference found"
        else
            print_warning "OneAgent library not referenced - may not be installed"
        fi
        
        # Check for log monitoring
        echo ""
        print_info "Searching for log monitoring keywords..."
        grep -i "log\|dynatrace\|oneagent" "$LATEST_LOG" | tail -20 || print_warning "No log-related messages found"
        
        # Check for errors
        echo ""
        print_info "Checking for errors..."
        grep -i "error\|fail\|cannot" "$LATEST_LOG" | tail -10 || print_info "No errors found"
        
        # Show recent application logs
        echo ""
        print_info "Last 15 lines of application logs:"
        tail -15 "$LATEST_LOG"
    fi
    
    # Clean up
    rm -rf debug-logs debug-logs.zip
fi

#########################################
# 4. Test Dynatrace API Token
#########################################

print_section "4. Dynatrace API Token Validation"

if [ -n "$DT_API_TOKEN" ] && [ -n "$DT_ENDPOINT" ]; then
    print_info "Testing API token permissions..."
    
    TOKEN_INFO=$(curl -s -X POST "$DT_ENDPOINT/api/v2/apiTokens/lookup" \
        -H "Authorization: Api-Token $DT_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"token\": \"$DT_API_TOKEN\"}" 2>/dev/null)
    
    if [ -n "$TOKEN_INFO" ]; then
        echo "$TOKEN_INFO" | python3 -m json.tool 2>/dev/null || echo "$TOKEN_INFO"
        
        # Check for required scopes
        if echo "$TOKEN_INFO" | grep -q "logs.ingest"; then
            print_info "✓ Token has logs.ingest scope"
        else
            print_error "Token missing 'logs.ingest' scope!"
            print_warning "This scope is REQUIRED for log ingestion"
        fi
        
        if echo "$TOKEN_INFO" | grep -q "InstallerDownload"; then
            print_info "✓ Token has InstallerDownload scope"
        else
            print_warning "Token missing 'InstallerDownload' scope"
        fi
    else
        print_error "Could not validate token"
    fi
fi

#########################################
# 5. Check App Service Logs Configuration
#########################################

print_section "5. App Service Logging Configuration"

LOG_CONFIG=$(az webapp log show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" 2>/dev/null)

if [ -n "$LOG_CONFIG" ]; then
    echo "$LOG_CONFIG" | python3 -m json.tool 2>/dev/null || echo "$LOG_CONFIG"
else
    print_warning "Could not retrieve log configuration"
fi

#########################################
# 6. SSH into Container and Check OneAgent
#########################################

print_section "6. OneAgent Installation Check"

print_info "To manually check OneAgent installation, run:"
echo ""
echo "  az webapp ssh --name $APP_NAME --resource-group $RESOURCE_GROUP"
echo ""
echo "Then inside the container, run these commands:"
echo ""
echo "  # Check if OneAgent is installed"
echo "  ls -la /opt/dynatrace/oneagent/agent/lib64/"
echo ""
echo "  # Check OneAgent logs"
echo "  ls -la /opt/dynatrace/oneagent/log/"
echo "  cat /opt/dynatrace/oneagent/log/oneagent*.log"
echo ""
echo "  # Check if log monitoring is enabled"
echo "  grep -i 'log' /opt/dynatrace/oneagent/log/oneagent*.log"
echo ""
echo "  # Check environment variables"
echo "  env | grep DT_"
echo ""

#########################################
# 7. Recommendations
#########################################

print_section "7. Troubleshooting Steps"

echo ""
print_info "Common issues for log ingestion:"
echo ""
echo "1. Token Missing Scopes:"
echo "   - Create a new token with these scopes:"
echo "     • InstallerDownload"
echo "     • logs.ingest (REQUIRED)"
echo "     • metrics.ingest (recommended)"
echo ""
echo "2. Log Access Not Enabled:"
echo "   - Ensure DT_LOGACCESS=true is set"
echo "   - Ensure startup command includes DT_LOGACCESS parameter"
echo "   - Restart app TWICE after making changes"
echo ""
echo "3. Wait Time:"
echo "   - Initial log ingestion can take 10-15 minutes"
echo "   - Generate some traffic to create logs"
echo ""
echo "4. Manual Commands to Fix:"
echo "   az webapp config appsettings set -n $APP_NAME -g $RESOURCE_GROUP --settings DT_LOGACCESS=true"
echo "   az webapp restart -n $APP_NAME -g $RESOURCE_GROUP"
echo "   sleep 30"
echo "   az webapp restart -n $APP_NAME -g $RESOURCE_GROUP"
echo ""
echo "5. Generate Traffic:"
echo "   APP_URL=\$(az webapp show -n $APP_NAME -g $RESOURCE_GROUP --query defaultHostName -o tsv)"
echo "   for i in {1..10}; do curl -s https://\$APP_URL/api/health > /dev/null; done"
echo ""
echo "6. Check Dynatrace:"
echo "   - Go to Logs & Events > Log Viewer"
echo "   - Filter by: dt.entity.process_group_instance or service name"
echo "   - Look for stdout/stderr logs from your app"
echo ""

print_section "Debug Complete"
