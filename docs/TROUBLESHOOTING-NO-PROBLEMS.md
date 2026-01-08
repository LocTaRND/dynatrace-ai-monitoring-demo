# Troubleshooting: Logs Showing But No Problems Detected

## Problem Description
You have **308 ERROR logs** visible in Dynatrace Logs viewer, but the **Problems view is empty**. The `generate-problems.sh` script is running successfully and hitting error endpoints, but Dynatrace is not creating Problems.

## Why This Happens

### Logs vs Problems in Dynatrace

**Logs** and **Problems** are different in Dynatrace:

| Feature | Logs | Problems |
|---------|------|----------|
| **Source** | Application logging, sent via Logs API | Service health monitoring via OneAgent |
| **Purpose** | Raw event data, debugging | Anomaly detection, alerting |
| **Trigger** | Any log message sent to Dynatrace | Detected issues: error rate spikes, slow response times, exceptions |
| **Detection** | Immediate | Based on baselines and AI anomaly detection |

### The Core Issue

Your application is **only sending logs**, but **OneAgent is not properly monitoring the service**. Without OneAgent instrumentation:
- ❌ No service entity in Dynatrace
- ❌ No error rate monitoring
- ❌ No response time tracking
- ❌ No anomaly detection
- ❌ No automatic problem creation

## Diagnostic Steps

### 1. Check if OneAgent is Installed and Running

**On Azure App Service:**
```bash
# Check OneAgent installation via Azure CLI
az webapp config appsettings list \
  --name dynatrace-demo-api-30529 \
  --resource-group dynatrace-demo-rg \
  --query "[?name=='DT_TENANT' || name=='DT_CONNECTION_POINT'].{Name:name, Value:value}" \
  --output table
```

Expected output should show:
```
Name                    Value
----------------------  ----------------------------------
DT_TENANT               vvz65479
DT_CONNECTION_POINT     https://vvz65479.live.dynatrace.com
```

### 2. Check if Service is Detected in Dynatrace

1. Go to Dynatrace UI: `https://vvz65479.live.dynatrace.com`
2. Navigate to: **Services**
3. Search for: `dynatrace-demo-api-30529` or `SampleAPI`

**Expected:** You should see a service entity
**If missing:** OneAgent is not instrumenting the application

### 3. Verify OneAgent Extension is Enabled

```bash
# List all site extensions
az webapp deployment site-extension list \
  --name dynatrace-demo-api-30529 \
  --resource-group dynatrace-demo-rg \
  --output table
```

Look for `Dynatrace.OneAgent.extension` in the output.

### 4. Check Application Settings for Dynatrace

```bash
az webapp config appsettings list \
  --name dynatrace-demo-api-30529 \
  --resource-group dynatrace-demo-rg \
  --output table | grep -E "DT_|DYNATRACE"
```

Required settings for OneAgent:
```
DT_TENANT=vvz65479
DT_CONNECTION_POINT=https://vvz65479.live.dynatrace.com
DT_PAAS_TOKEN=<your-paas-token>  # Required for agent communication
```

### 5. Check App Service Logs for OneAgent

```bash
# Stream logs from Azure App Service
az webapp log tail \
  --name dynatrace-demo-api-30529 \
  --resource-group dynatrace-demo-rg
```

Look for messages like:
- `Dynatrace OneAgent started`
- `Connected to Dynatrace`
- `Service detected`

## Fixing the Issue

### Option 1: Install/Reinstall OneAgent Extension (Recommended)

Create a fix script:

```bash
#!/bin/bash
# fix-oneagent.sh

RESOURCE_GROUP="dynatrace-demo-rg"
APP_NAME="dynatrace-demo-api-30529"
DT_TENANT="vvz65479"
DT_PAAS_TOKEN=""

echo "Installing Dynatrace OneAgent extension..."

# Install OneAgent site extension
az webapp deployment site-extension install \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --slot-name production \
  --extension-name Dynatrace.OneAgent.extension

echo "Configuring Dynatrace settings..."

# Configure required app settings
az webapp config appsettings set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    DT_TENANT="$DT_TENANT" \
    DT_CONNECTION_POINT="https://${DT_TENANT}.live.dynatrace.com" \
    DT_PAAS_TOKEN="$DT_PAAS_TOKEN"

echo "Restarting app service..."
az webapp restart \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP"

echo "Done! Wait 5-10 minutes for OneAgent to initialize."
```

### Option 2: Configure Problem Detection Settings

If OneAgent IS running but Problems still aren't appearing:

**1. Adjust Anomaly Detection Thresholds**

In Dynatrace:
1. Go to: **Settings → Anomaly detection → Services**
2. Lower thresholds for testing:
   - **Error rate increase**: Set to "immediate" or "minor"
   - **Slow response time**: Lower threshold to detect faster
   - **Exception rate**: Enable and set sensitivity to "high"

**2. Create Custom Events for Alerting**

For immediate problem creation based on logs:

1. Go to: **Settings → Anomaly detection → Custom events for alerting**
2. Click **Create custom event for alerting**
3. Configure:
   - **Category**: Error event
   - **Rule**: `loglevel = "ERROR"`
   - **Severity**: Error
   - **Alert on**: More than 10 events in 5 minutes

### Option 3: Verify Application is Generating Real Service Metrics

The issue might be that Azure App Service isn't reporting proper **service** metrics, only logs.

**Generate load with proper HTTP status codes:**

```bash
# Modified problem generator that ensures service monitoring
for i in {1..50}; do
  # These generate actual HTTP errors (not just logs)
  curl -w "Status: %{http_code}\n" \
       -s -o /dev/null \
       "https://dynatrace-demo-api-30529.azurewebsites.net/api/products/error/500"
  sleep 2
done
```

## Validation

After applying fixes, verify:

### 1. Service Detection (5-10 minutes)
```
Dynatrace UI → Services → Search for "dynatrace-demo-api-30529"
```

### 2. Service Health (2-5 minutes)
```
Click on service → View details → Check:
- Request rate
- Error rate
- Response time
```

### 3. Generate Problems (5-10 minutes)
```bash
# Run problem generator again
cd scripts
./generate-problems.sh dynatrace-demo-api-30529.azurewebsites.net
```

### 4. Check Problems (5-15 minutes)
```
Dynatrace UI → Problems → Should see:
- "High error rate detected"
- "Slow response time"
- "Exception rate increased"
```

## Expected Timeline

| Action | Time Required |
|--------|---------------|
| OneAgent installation | 2-3 minutes |
| App restart | 1-2 minutes |
| OneAgent initialization | 5-10 minutes |
| Service detection | 5-10 minutes |
| Baseline learning | 10-30 minutes |
| Problem detection | 5-15 minutes after errors |

## Common Issues

### Issue 1: "No service found"
**Cause**: OneAgent not installed or not instrumenting .NET process
**Fix**: Reinstall OneAgent extension, ensure `DOTNET_STARTUP_HOOKS` is set

### Issue 2: "Logs but no metrics"
**Cause**: Only using Logs API without OneAgent
**Fix**: Install OneAgent for full instrumentation

### Issue 3: "Service detected but no problems"
**Cause**: Error rate too low or within learned baseline
**Fix**: 
- Generate more errors (100+ within 5 minutes)
- Lower anomaly detection thresholds
- Wait longer for baseline learning (30+ minutes)

### Issue 4: "Problems after long delay"
**Cause**: Dynatrace learning baseline for anomaly detection
**Fix**: Normal behavior - first problems may take 30-60 minutes

## Quick Test Command

After fixing, test immediately:

```bash
# Generate high error rate quickly
seq 1 100 | xargs -P10 -I{} curl -s -o /dev/null \
  "https://dynatrace-demo-api-30529.azurewebsites.net/api/products/error/500"
```

This generates 100 concurrent errors which should trigger a Problem if OneAgent is working correctly.

## Additional Resources

- [Dynatrace OneAgent on Azure App Service](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/microsoft-azure-services/azure-integrations/azure-app-service)
- [Problem Detection in Dynatrace](https://www.dynatrace.com/support/help/how-to-use-dynatrace/problem-detection-and-analysis)
- [Custom Events for Alerting](https://www.dynatrace.com/support/help/how-to-use-dynatrace/problem-detection-and-analysis/problem-detection/custom-events-for-alerting)
