# Dynatrace Problem Simulation Guide

## Overview
This guide shows how to generate various problems that will appear in Dynatrace Problems view.

## Error Endpoints Added

The deployment script now includes these error-generating endpoints:

### 1. **Exception Errors**
- **Endpoint**: `/api/products/error/exception`
- **Effect**: Throws unhandled exceptions
- **Problem Type**: Application errors, exception rate increase

### 2. **500 Internal Server Errors**
- **Endpoint**: `/api/products/error/500`
- **Effect**: Returns HTTP 500 status
- **Problem Type**: High error rate, service degradation

### 3. **Slow Requests (Timeout)**
- **Endpoint**: `/api/products/error/timeout`
- **Effect**: Delays response by 10 seconds
- **Problem Type**: Slow response time, performance degradation

### 4. **High Memory Usage**
- **Endpoint**: `/api/products/error/memory`
- **Effect**: Allocates 100MB of memory
- **Problem Type**: Memory saturation, resource contention

### 5. **High CPU Usage**
- **Endpoint**: `/api/products/error/cpu`
- **Effect**: CPU-intensive calculations
- **Problem Type**: CPU saturation, resource contention

### 6. **Database Connection Errors**
- **Endpoint**: `/api/products/error/database`
- **Effect**: Returns HTTP 503 (Service Unavailable)
- **Problem Type**: Service unavailability, connectivity issues

### 7. **404 Not Found**
- **Endpoint**: `/api/products/99999`
- **Effect**: Product not found
- **Problem Type**: High 404 rate

## How to Generate Problems

### Option 1: Use the Automated Script (Recommended)

**On Windows (PowerShell):**
```powershell
cd scripts
.\generate-problems.ps1 -AppUrl "your-app-name.azurewebsites.net"
```

**On Linux/Mac (Bash):**
```bash
cd scripts
chmod +x generate-problems.sh
./generate-problems.sh your-app-name.azurewebsites.net
```

This script will automatically generate:
- 30x HTTP 500 errors
- 20x Unhandled exceptions
- 10x Slow requests
- 25x Database connection failures
- 15x High CPU operations
- 10x High memory allocations
- 40x HTTP 404 errors
- 50x Mixed load

### Option 2: Manual Testing

**Generate specific problem types:**

```bash
# Replace YOUR_APP_URL with your actual URL
APP_URL="https://your-app-name.azurewebsites.net"

# Generate 500 errors
for i in {1..20}; do curl "$APP_URL/api/products/error/500"; sleep 1; done

# Generate exceptions
for i in {1..20}; do curl "$APP_URL/api/products/error/exception"; sleep 1; done

# Generate slow requests
for i in {1..5}; do curl "$APP_URL/api/products/error/timeout"; done

# Generate database errors
for i in {1..20}; do curl "$APP_URL/api/products/error/database"; sleep 1; done

# Generate CPU load
for i in {1..10}; do curl "$APP_URL/api/products/error/cpu"; sleep 2; done

# Generate memory load
for i in {1..10}; do curl "$APP_URL/api/products/error/memory"; sleep 3; done

# Generate 404 errors
for i in {1..30}; do curl "$APP_URL/api/products/99999"; sleep 1; done
```

**PowerShell version:**
```powershell
$AppUrl = "https://your-app-name.azurewebsites.net"

# Generate 500 errors
1..20 | ForEach-Object { 
    Invoke-WebRequest "$AppUrl/api/products/error/500" -UseBasicParsing
    Start-Sleep -Seconds 1
}

# Generate exceptions
1..20 | ForEach-Object { 
    Invoke-WebRequest "$AppUrl/api/products/error/exception" -UseBasicParsing
    Start-Sleep -Seconds 1
}
```

### Option 3: Use curl or Postman

Test individual endpoints:

```bash
# Test exception
curl https://your-app.azurewebsites.net/api/products/error/exception

# Test 500 error
curl https://your-app.azurewebsites.net/api/products/error/500

# Test slow request (will take 10 seconds)
curl https://your-app.azurewebsites.net/api/products/error/timeout

# Test database error
curl https://your-app.azurewebsites.net/api/products/error/database

# Test CPU load
curl https://your-app.azurewebsites.net/api/products/error/cpu

# Test memory load
curl https://your-app.azurewebsites.net/api/products/error/memory
```

## Expected Problems in Dynatrace

After running the problem generator, you should see:

### 1. **High Error Rate**
- **Trigger**: Multiple 500 errors
- **Detection Time**: 2-5 minutes
- **Location**: Problems → Error rate increase

### 2. **Slow Response Time**
- **Trigger**: Timeout endpoints (10s delays)
- **Detection Time**: 5-10 minutes
- **Location**: Problems → Response time degradation

### 3. **Exception Rate Increase**
- **Trigger**: Unhandled exceptions
- **Detection Time**: 2-5 minutes
- **Location**: Problems → Error rate increase

### 4. **Service Unavailability**
- **Trigger**: 503 database errors
- **Detection Time**: 2-5 minutes
- **Location**: Problems → Service unavailability

### 5. **Resource Saturation**
- **Trigger**: High CPU/Memory operations
- **Detection Time**: 5-15 minutes
- **Location**: Problems → Resource contention

### 6. **Traffic Drop**
- **Trigger**: Multiple failures causing traffic decline
- **Detection Time**: 10-15 minutes
- **Location**: Problems → Traffic drop

## Viewing Problems

1. **Go to Dynatrace Console**
   ```
   https://your-tenant.live.dynatrace.com
   ```

2. **Navigate to Problems**
   - Click **"Problems"** in the left navigation menu
   - Or go directly: `https://your-tenant.live.dynatrace.com/ui/problems`

3. **Filter Problems**
   - Filter by your service name
   - Filter by time range (last 2 hours)
   - Filter by severity (All, Error, Slowdown, etc.)

4. **Problem Details**
   Click on any problem to see:
   - Root cause analysis
   - Affected services
   - Event timeline
   - Related logs
   - Impact analysis

## Monitoring & Verification

### Check Application Logs
```bash
# Azure CLI
az webapp log tail --name your-app-name --resource-group dynatrace-demo-rg

# Or view in portal
https://portal.azure.com → Your App Service → Log stream
```

### Check Dynatrace Logs
1. Go to **Logs** in Dynatrace menu
2. Filter by:
   - `service.name = "your-app-name"`
   - `severity = ERROR` or `WARN`
3. Look for error messages from simulation

### Verify Service Health
```bash
# Check if app is responding
curl https://your-app.azurewebsites.net/api/health

# Check all endpoints
curl https://your-app.azurewebsites.net/swagger
```

## Troubleshooting

### Problems Not Appearing?

1. **Wait Longer**
   - Problem detection can take 5-15 minutes
   - Be patient, especially for first-time detection

2. **Check Dynatrace Configuration**
   - Verify OneAgent is running: Check Service in Dynatrace
   - Check app settings: `DT_ENDPOINT`, `DT_API_TOKEN`

3. **Generate More Traffic**
   - Run the problem generator multiple times
   - Increase error counts (edit script)

4. **Check Detection Settings**
   - Go to Settings → Anomaly detection
   - Ensure automatic detection is enabled
   - Check sensitivity levels

5. **Verify Service Monitoring**
   - Go to Services in Dynatrace
   - Find your app service
   - Check if it's being monitored

### Logs Not Showing?

1. **Check API Token Permissions**
   - Token must have `logs.ingest` permission
   - Verify token in environment variables

2. **Check Log Configuration**
   ```bash
   az webapp config appsettings list \
     --name your-app-name \
     --resource-group dynatrace-demo-rg \
     --query "[?name=='DT_ENDPOINT' || name=='DT_API_TOKEN']"
   ```

3. **Test Log Endpoint Manually**
   ```bash
   curl -X POST "https://your-tenant.live.dynatrace.com/api/v2/logs/ingest" \
     -H "Authorization: Api-Token YOUR_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"content":"test","severity":"INFO"}'
   ```

## Best Practices

1. **Don't overload production** - Use dedicated demo/test environments
2. **Start small** - Run a few errors first, then scale up
3. **Monitor timing** - Note when you generate errors vs when problems appear
4. **Clean up** - Stop error generation after testing
5. **Check baselines** - Let the app run normally first to establish baselines

## Re-deploying with Error Endpoints

If you've already deployed, redeploy to get the error endpoints:

```bash
cd dynatrace-ai-monitoring-demo
./deploy.sh
```

The script will:
1. Recreate the app with error endpoints
2. Deploy to Azure
3. Configure Dynatrace
4. Run initial traffic generation

## Quick Reference Commands

```bash
# Run problem generator
./scripts/generate-problems.sh your-app.azurewebsites.net

# View Dynatrace problems
open "https://your-tenant.live.dynatrace.com/ui/problems"

# View Azure logs
az webapp log tail --name your-app --resource-group dynatrace-demo-rg

# Test specific error
curl https://your-app.azurewebsites.net/api/products/error/500

# Check app health
curl https://your-app.azurewebsites.net/api/health
```

## Support

If problems still don't appear after 15-20 minutes:
1. Check Dynatrace documentation
2. Verify OneAgent installation
3. Review anomaly detection settings
4. Contact Dynatrace support with service details
