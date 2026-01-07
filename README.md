# Dynatrace AI Monitoring Demo

A complete demonstration of Azure App Service integration with Dynatrace OneAgent for comprehensive monitoring and log ingestion. This project automatically deploys a .NET 8.0 Web API to Azure with full Dynatrace instrumentation.

## 🎯 Overview

This demo showcases:
- **Automatic Dynatrace OneAgent installation** on Azure App Service
- **Custom log ingestion** to Dynatrace using the Logs API
- **Distributed tracing** for .NET applications
- **Real-time monitoring** of application performance
- **Structured logging** with context-rich attributes
- **Health checks** and readiness probes

## 📋 Prerequisites

Before running this demo, ensure you have:

### Required Tools
- **Azure CLI** - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **.NET 8.0 SDK** - [Download .NET](https://dotnet.microsoft.com/download)
- **Bash shell** (Git Bash on Windows, native on macOS/Linux)
- **Azure subscription** with sufficient permissions
- **Dynatrace environment** (SaaS or Managed)

### Azure Requirements
- Active Azure subscription
- Permissions to create:
  - Resource Groups
  - App Service Plans
  - App Services (Web Apps)

### Dynatrace Requirements
- Dynatrace tenant (e.g., `vvz65479.live.dynatrace.com`)
- Dynatrace API token with permissions:
  - **Ingest logs** (`logs.ingest`)
  - **Ingest events** (`events.ingest`)
  - **Read entities** (`entities.read`)
  - **Read configuration** (optional)

## 🚀 Quick Start

### 1. Clone and Navigate
```bash
git clone <your-repo-url>
cd dynatrace-ai-monitoring-demo
```

### 2. Configure Dynatrace Token

Create a Dynatrace API token:
1. Go to **Settings → Integration → Dynatrace API**
2. Click **Generate token**
3. Enable scopes: `logs.ingest`, `events.ingest`, `entities.read`
4. Copy the token (starts with `dt0c01.`)

Set the environment variable:
```bash
# Linux/macOS/Git Bash
export DT_TOKEN='dt0c01.XXXXX.XXXXX...'

# Windows PowerShell
$env:DT_TOKEN='dt0c01.XXXXX.XXXXX...'

# Windows CMD
set DT_TOKEN=dt0c01.XXXXX.XXXXX...
```

### 3. Update Configuration

Edit [deploy.sh](deploy.sh) and update these variables:
```bash
# Line 38-43: Azure Configuration
RESOURCE_GROUP="dynatrace-demo-rg"        # Your resource group name
APP_SERVICE_PLAN="dynatrace-demo-plan"    # Your app service plan
APP_NAME="dynatrace-demo-api-$RANDOM"     # Will be auto-generated with random suffix
LOCATION="eastus"                          # Azure region
SKU="B1"                                   # Pricing tier (B1=Basic, P1V2=Production)

# Line 45-47: Dynatrace Configuration
DT_TENANT="vvz65479"                      # Your tenant ID (before .live.dynatrace.com)
DT_DOMAIN="live.dynatrace.com"            # Your Dynatrace domain
```

### 4. Login to Azure
```bash
az login
```

### 5. Run Deployment
```bash
chmod +x deploy.sh
./deploy.sh
```

### 6. Wait and Verify
- **Deployment**: ~5 minutes
- **OneAgent initialization**: 5-10 minutes
- **Logs appearing in Dynatrace**: 10-15 minutes

## 📊 Architecture

```
┌─────────────────────────────────────────────────────┐
│              Azure App Service                       │
│  ┌──────────────────────────────────────────────┐  │
│  │         Dynatrace OneAgent                    │  │
│  │  (Auto-injected at startup)                   │  │
│  └──────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────┐  │
│  │         .NET 8.0 Web API                      │  │
│  │  ┌────────────────────────────────────────┐  │  │
│  │  │  Controllers                            │  │  │
│  │  │  - HealthController                     │  │  │
│  │  │  - ProductsController                   │  │  │
│  │  └────────────────────────────────────────┘  │  │
│  │  ┌────────────────────────────────────────┐  │  │
│  │  │  DynatraceLogService                    │  │  │
│  │  │  - Custom log ingestion                 │  │  │
│  │  │  - Structured logging                   │  │  │
│  │  └────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                      │
                      │ HTTPS
                      ▼
       ┌──────────────────────────────┐
       │    Dynatrace Platform         │
       │  - Traces                     │
       │  - Metrics                    │
       │  - Logs                       │
       │  - Events                     │
       └──────────────────────────────┘
```

## 🛠️ What the Script Does

### Step 1: Create .NET Application
- Generates a new .NET 8.0 Web API project
- Creates custom `DynatraceLogService` for log ingestion
- Implements controllers with comprehensive logging:
  - **HealthController**: Health, readiness, and liveness endpoints
  - **ProductsController**: CRUD operations with detailed logging
- Configures structured JSON logging
- Adds request/response logging middleware

### Step 2: Create Azure Resources
- Creates Azure Resource Group
- Provisions App Service Plan (Linux-based)
- Deploys Web App with .NET 8.0 runtime

### Step 3: Configure Dynatrace
- Sets Dynatrace environment variables:
  - `DT_ENDPOINT`: Dynatrace tenant URL
  - `DT_API_TOKEN`: API authentication token
  - `DT_INCLUDE`: Technologies to monitor (dotnet)
  - `DT_LOGACCESS`: Enable log access
  - Custom properties and tags
- Configures OneAgent startup command

### Step 4: Enable Logging
- Enables application logging (filesystem)
- Configures verbose logging level
- Enables detailed error messages
- Enables failed request tracing

### Step 5: Deploy Application
- Builds the .NET application
- Publishes release build
- Creates deployment ZIP package
- Deploys to Azure App Service

### Step 6: Restart for Dynatrace
- Performs first restart (OneAgent downloads)
- Waits 60 seconds for installation
- Performs second restart (OneAgent activates)

### Step 7: Send Deployment Event
- Sends custom deployment event to Dynatrace
- Records deployment metadata

### Step 8: Generate Initial Traffic
- Makes test requests to application endpoints
- Generates initial traces and logs

## 📍 API Endpoints

Once deployed, your application will have the following endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Root endpoint with API information |
| `/swagger` | GET | Interactive API documentation |
| `/api/health` | GET | Health check with Dynatrace status |
| `/api/health/ready` | GET | Readiness probe |
| `/api/health/live` | GET | Liveness probe |
| `/api/products` | GET | List all products |
| `/api/products/{id}` | GET | Get product by ID |
| `/api/products` | POST | Create new product |
| `/health` | GET | Built-in health endpoint |

## 🔍 Verifying the Deployment

### 1. Test the Application
```bash
# Get your app URL from deployment output
APP_URL="your-app-name.azurewebsites.net"

# Test endpoints
curl https://$APP_URL/
curl https://$APP_URL/api/health
curl https://$APP_URL/api/products
```

### 2. Check Azure Logs
```bash
# Real-time log streaming
az webapp log tail --resource-group dynatrace-demo-rg --name your-app-name

# Download logs
az webapp log download --resource-group dynatrace-demo-rg --name your-app-name
```

### 3. Verify in Dynatrace

#### Option A: Logs Viewer
1. Open your Dynatrace environment
2. Navigate to **Observe and explore → Logs**
3. Filter by: `service.name = "your-app-name"`
4. Or search: `your-app-name`

#### Option B: Services View
1. Go to **Services**
2. Find your service (may take 10-15 minutes to appear)
3. View traces, metrics, and logs

#### Option C: Query Logs
```
fetch logs
| filter service.name == "your-app-name"
| sort timestamp desc
| limit 100
```

## 📝 Log Structure

All logs sent to Dynatrace include:

### Standard Attributes
- `content`: Log message
- `severity`: INFO, WARN, ERROR, DEBUG
- `timestamp`: Unix timestamp (milliseconds)
- `service.name`: Application name
- `service.namespace`: "azure-appservice"
- `host.name`: Azure instance name
- `cloud.platform`: "azure_app_service"
- `deployment.environment`: Environment name

### Custom Attributes (per endpoint)
- `endpoint`: API endpoint path
- `remote_ip`: Client IP address
- `method`: HTTP method
- `http.status_code`: Response status
- `http.duration_ms`: Request duration

## 🧪 Generate Test Traffic

### Continuous Health Checks
```bash
# Send 50 requests with 2-second intervals
for i in {1..50}; do 
    curl -s https://your-app.azurewebsites.net/api/health
    sleep 2
done
```

### Product Operations
```bash
APP_URL="your-app.azurewebsites.net"

# Get all products
curl https://$APP_URL/api/products

# Get specific product
curl https://$APP_URL/api/products/1

# Create new product
curl -X POST https://$APP_URL/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Monitor","price":799.99}'
```

### Load Testing
```bash
# Generate 100 mixed requests
for i in {1..100}; do
    curl -s https://$APP_URL/ > /dev/null &
    curl -s https://$APP_URL/api/health > /dev/null &
    curl -s https://$APP_URL/api/products > /dev/null &
    sleep 1
done
```

## 🛠️ Troubleshooting

### Logs Not Appearing in Dynatrace

**Wait Time**: Logs can take 10-15 minutes to appear initially.

**Check Token Permissions**:
```bash
curl -H "Authorization: Api-Token $DT_TOKEN" \
  "https://your-tenant.live.dynatrace.com/api/v2/logs/ingest"
```
Should return: `{"error":{"code":400,"message":"Request body missing"}}`
(400 is expected - confirms auth works)

**Check Application Logs**:
```bash
az webapp log tail --resource-group dynatrace-demo-rg --name your-app-name
```
Look for: `[Dynatrace]` messages indicating log send status

### OneAgent Not Installing

**Check Startup Command**:
```bash
az webapp config show \
  --resource-group dynatrace-demo-rg \
  --name your-app-name \
  --query appCommandLine
```

**Manual Restart**:
```bash
az webapp restart --resource-group dynatrace-demo-rg --name your-app-name
sleep 60
az webapp restart --resource-group dynatrace-demo-rg --name your-app-name
```

**Check SSH** (if enabled):
```bash
az webapp ssh --resource-group dynatrace-demo-rg --name your-app-name
```

### Application Not Responding

**Check Application Status**:
```bash
az webapp show \
  --resource-group dynatrace-demo-rg \
  --name your-app-name \
  --query state
```

**View Logs**:
```bash
az webapp log tail --resource-group dynatrace-demo-rg --name your-app-name
```

**Redeploy**:
```bash
cd sample-dotnet-app/publish
az webapp deployment source config-zip \
  --resource-group dynatrace-demo-rg \
  --name your-app-name \
  --src deploy.zip
```

## 🔧 Configuration

### Environment Variables Set by Script

```bash
ASPNETCORE_ENVIRONMENT="Production"
ASPNETCORE_URLS="http://+:8080"
DT_ENDPOINT="https://tenant.live.dynatrace.com"
DT_API_TOKEN="dt0c01.XXXXX"
DT_INCLUDE="dotnet"
DT_LOGACCESS="true"
DT_LOGLEVELCON="INFO"
DT_CUSTOM_PROP="service=app-name,environment=demo,platform=azure-appservice"
DT_TAGS="environment:demo,service:app-name,platform:azure"
Logging__LogLevel__Default="Information"
Logging__LogLevel__Microsoft="Warning"
Logging__LogLevel__Microsoft.AspNetCore="Information"
```

### Customizing the Application

Edit files in `sample-dotnet-app/`:
- [Controllers/HealthController.cs](sample-dotnet-app/Controllers/HealthController.cs) - Health endpoints
- [Controllers/ProductsController.cs](sample-dotnet-app/Controllers/ProductsController.cs) - Product API
- [Services/DynatraceLogService.cs](sample-dotnet-app/Services/DynatraceLogService.cs) - Log service
- [Program.cs](sample-dotnet-app/Program.cs) - Application configuration

Then redeploy:
```bash
cd sample-dotnet-app
dotnet publish -c Release -o ./publish
cd publish
zip -r ../deploy.zip .
cd ..
az webapp deployment source config-zip \
  --resource-group dynatrace-demo-rg \
  --name your-app-name \
  --src deploy.zip
```

## 🧹 Cleanup

### Delete All Resources
```bash
# Delete resource group and all contained resources
az group delete --name dynatrace-demo-rg --yes --no-wait
```

### Selective Cleanup
```bash
# Delete only the web app
az webapp delete \
  --resource-group dynatrace-demo-rg \
  --name your-app-name

# Delete app service plan
az appservice plan delete \
  --resource-group dynatrace-demo-rg \
  --name dynatrace-demo-plan --yes
```

## 📚 Additional Resources

### Documentation
- [Dynatrace Azure App Service Integration](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/microsoft-azure-services/azure-integrations/azure-app-service-integration)
- [Dynatrace Logs API](https://www.dynatrace.com/support/help/dynatrace-api/environment-api/log-monitoring-v2)
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [.NET on Azure](https://docs.microsoft.com/en-us/azure/app-service/quickstart-dotnetcore)

### Helper Scripts
- [scripts/debug-dynatrace.sh](scripts/debug-dynatrace.sh) - Debug Dynatrace connection
- [scripts/debug-logs.sh](scripts/debug-logs.sh) - View application logs
- [scripts/check-container-logs.sh](scripts/check-container-logs.sh) - Check container logs
- [scripts/test.sh](scripts/test.sh) - Generate test traffic
- [scripts/update.sh](scripts/update.sh) - Update and redeploy application

## 🎓 Learning Objectives

This demo teaches:
1. **Dynatrace OneAgent** installation on Azure App Service
2. **Custom log ingestion** using Dynatrace Logs API
3. **Structured logging** best practices
4. **Azure App Service** deployment automation
5. **Distributed tracing** configuration
6. **Health check** implementation
7. **Monitoring strategy** for cloud applications

## 📊 Costs

Estimated Azure costs (per month):
- **B1 (Basic)**: ~$13/month - Good for demos
- **P1V2 (Production)**: ~$80/month - Recommended for production

Dynatrace costs depend on your licensing model.

**Note**: Remember to delete resources after testing to avoid charges!

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is provided as-is for demonstration purposes.

## 👥 Support

For issues:
1. Check the [Troubleshooting](#-troubleshooting) section
2. Review Azure logs: `az webapp log tail`
3. Check Dynatrace documentation
4. Open an issue in this repository

---

**Last Updated**: January 2026  
**Version**: 1.0.1
