#!/bin/bash

#########################################
# Complete Azure App Service Deployment
# with .NET Sample App and Dynatrace
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
LOCATION="eastus"
SKU="B1"  # Basic tier (cheap for demo, use P1V2 for production)

# Dynatrace Configuration
DT_TENANT="vvz65479"  # Your Dynatrace tenant ID
DT_DOMAIN="live.dynatrace.com"  # Your Dynatrace domain (apps.dynatrace.com or live.dynatrace.com)
DT_TOKEN=""  # Set your Dynatrace API token here or use: export DT_TOKEN='dt0c01.XXXXX...'

# Application Configuration
APP_DIR="./sample-dotnet-app"
DOTNET_VERSION="8.0"

#########################################
# VALIDATION
#########################################

print_info "Starting deployment script..."

# Check if Dynatrace token is set
if [ -z "$DT_TOKEN" ]; then
    print_error "Dynatrace token not set! Please update DT_TOKEN variable."
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
    print_error "Not logged into Azure. Running 'az login'..."
    az login
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
print_info "Using Azure subscription: $SUBSCRIPTION_NAME"

# Register required resource providers
PROVIDER_STATE=$(az provider show --namespace Microsoft.Web --query registrationState -o tsv 2>/dev/null || echo "NotRegistered")
if [ "$PROVIDER_STATE" != "Registered" ]; then
    print_info "Registering Microsoft.Web resource provider..."
    az provider register --namespace Microsoft.Web --wait
else
    print_info "Microsoft.Web resource provider already registered"
fi

#########################################
# STEP 1: CREATE SAMPLE .NET APPLICATION
#########################################

print_info "Step 1: Creating sample .NET application..."

# Remove existing directory if it exists
if [ -d "$APP_DIR" ]; then
    print_warning "Directory $APP_DIR exists. Removing..."
    rm -rf "$APP_DIR"
fi

# Create new .NET Web API project
dotnet new webapi -n SampleAPI -o "$APP_DIR" --framework net$DOTNET_VERSION

cd "$APP_DIR"

# Create Controllers directory if it doesn't exist
mkdir -p Controllers

# Create a custom controller with more endpoints
cat > Controllers/HealthController.cs << 'EOF'
using Microsoft.AspNetCore.Mvc;

namespace SampleAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    private readonly ILogger<HealthController> _logger;

    public HealthController(ILogger<HealthController> logger)
    {
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Get()
    {
        _logger.LogInformation("Health check endpoint called from {RemoteIp}", 
            HttpContext.Connection.RemoteIpAddress);
        _logger.LogInformation("Health check response: Status=Healthy, Environment={Environment}", 
            Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"));
        
        return Ok(new
        {
            Status = "Healthy",
            Timestamp = DateTime.UtcNow,
            Environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"),
            MachineName = Environment.MachineName,
            Version = "1.0.0"
        });
    }

    [HttpGet("ready")]
    public IActionResult Ready()
    {
        _logger.LogInformation("Readiness check endpoint called");
        return Ok(new { Status = "Ready", Timestamp = DateTime.UtcNow });
    }

    [HttpGet("live")]
    public IActionResult Live()
    {
        _logger.LogInformation("Liveness check endpoint called");
        return Ok(new { Status = "Live", Timestamp = DateTime.UtcNow });
    }
}
EOF

# Create a Products controller (sample business logic)
cat > Controllers/ProductsController.cs << 'EOF'
using Microsoft.AspNetCore.Mvc;

namespace SampleAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly ILogger<ProductsController> _logger;
    private static readonly List<Product> Products = new()
    {
        new Product { Id = 1, Name = "Camera", Price = 599.99m },
        new Product { Id = 2, Name = "Lens", Price = 399.99m },
        new Product { Id = 3, Name = "Tripod", Price = 89.99m }
    };

    public ProductsController(ILogger<ProductsController> logger)
    {
        _logger = logger;
    }

    [HttpGet]
    public IActionResult GetAll()
    {
        _logger.LogInformation("Getting all products");
        return Ok(Products);
    }

    [HttpGet("{id}")]
    public IActionResult GetById(int id)
    {
        _logger.LogInformation($"Getting product with id: {id}");
        var product = Products.FirstOrDefault(p => p.Id == id);
        
        if (product == null)
        {
            _logger.LogWarning($"Product with id {id} not found");
            return NotFound();
        }
        
        return Ok(product);
    }

    [HttpPost]
    public IActionResult Create(Product product)
    {
        _logger.LogInformation($"Creating new product: {product.Name}");
        product.Id = Products.Max(p => p.Id) + 1;
        Products.Add(product);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }
}

public class Product
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
}
EOF

# Update Program.cs for better logging and health checks
cat > Program.cs << 'EOF'
var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add health checks
builder.Services.AddHealthChecks();

// Configure logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();
// Configure JSON logging for better Dynatrace integration
builder.Logging.AddJsonConsole(options =>
{
    options.IncludeScopes = true;
    options.TimestampFormat = "yyyy-MM-dd HH:mm:ss ";
    options.JsonWriterOptions = new System.Text.Json.JsonWriterOptions
    {
        Indented = false
    };
});
var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment() || app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

// Map health check endpoints
app.MapHealthChecks("/health");

// Simple root endpoint
app.MapGet("/", () => Results.Ok(new
{
    Application = "DevOps Sample API",
    Version = "1.0.0",
    Environment = app.Environment.EnvironmentName,
    Endpoints = new[]
    {
        "/api/health",
        "/api/products",
        "/health",
        "/swagger"
    }
}));

app.Run();
EOF

# Build the application to verify it works
print_info "Building application..."
dotnet build

print_info "✓ Sample .NET application created successfully!"
cd ..

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

print_info "✓ Web App created"

# Get the default hostname
APP_URL=$(az webapp show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --query defaultHostName -o tsv)

print_info "App URL: https://$APP_URL"

#########################################
# STEP 3: CONFIGURE APPLICATION SETTINGS
#########################################

print_info "Step 3: Configuring application settings..."

# Disable Application Insights to prevent conflicts with Dynatrace
az webapp config appsettings set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --settings \
        ASPNETCORE_ENVIRONMENT="Production" \
        WEBSITE_TIME_ZONE="Eastern Standard Time" \
        APPINSIGHTS_INSTRUMENTATIONKEY="" \
        ApplicationInsights__InstrumentationKey="" \
    --output none

print_info "✓ Application settings configured (Application Insights disabled)"

#########################################
# STEP 4: CONFIGURE DYNATRACE
#########################################

print_info "Step 4: Configuring Dynatrace integration..."

# Set Dynatrace application settings for Linux App Service
az webapp config appsettings set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --settings \
        DT_ENDPOINT="https://$DT_TENANT.$DT_DOMAIN" \
        DT_API_TOKEN="$DT_TOKEN" \
        DT_INCLUDE="dotnet" \
        START_APP_CMD="dotnet SampleAPI.dll" \
        DT_TAGS="Environment=Demo Service=$APP_NAME Platform=Azure" \
        DT_LOGLEVELCON="INFO" \
        DT_LOGSTREAM="stdout" \
        DT_LOGLEVELFILE="INFO" \
        DT_LOGACCESS="true" \
        Logging__LogLevel__Default="Information" \
        Logging__LogLevel__Microsoft="Warning" \
        Logging__LogLevel__Microsoft.AspNetCore="Warning" \
    --output none

print_info "✓ Dynatrace settings configured"

# Configure startup command for OneAgent installation (Linux App Service)
print_info "Configuring Dynatrace OneAgent startup command with log content access..."
STARTUP_CMD='wget -O /tmp/installer-wrapper.sh -q https://raw.githubusercontent.com/dynatrace-oss/cloud-snippets/main/azure/linux-app-service/oneagent-installer.sh && DT_ENDPOINT=$DT_ENDPOINT DT_API_TOKEN=$DT_API_TOKEN DT_INCLUDE=$DT_INCLUDE DT_LOGACCESS=$DT_LOGACCESS START_APP_CMD=$START_APP_CMD sh /tmp/installer-wrapper.sh'

az webapp config set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --startup-file "$STARTUP_CMD" \
    --output none

print_info "✓ Dynatrace OneAgent startup command configured"

#########################################
# STEP 5: ENABLE LOGGING
#########################################

print_info "Step 5: Enabling application logging..."

az webapp log config \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --application-logging filesystem \
    --level information \
    --detailed-error-messages true \
    --failed-request-tracing true \
    --web-server-logging filesystem \
    --output none

print_info "✓ Logging enabled"

#########################################
# STEP 6: PUBLISH AND DEPLOY APPLICATION
#########################################

print_info "Step 6: Publishing and deploying application..."

cd "$APP_DIR"

# Publish the application
print_info "Publishing .NET application..."
dotnet publish -c Release -o ./publish

# Create deployment package
print_info "Creating deployment package..."
cd publish

# Check if zip command exists, otherwise use PowerShell on Windows
if command -v zip &> /dev/null; then
    zip -r ../deploy.zip . > /dev/null
else
    print_warning "zip not found, using PowerShell Compress-Archive..."
    powershell.exe -Command "Compress-Archive -Path * -DestinationPath ../deploy.zip -Force"
fi

cd ..

# Deploy to Azure
print_info "Deploying to Azure App Service (this may take 1-2 minutes)..."
az webapp deploy \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --src-path deploy.zip \
    --type zip \
    --output none

print_info "✓ Application deployed"

cd ..

#########################################
# STEP 7: RESTART APP SERVICE
#########################################

print_info "Step 7: Restarting App Service to initialize Dynatrace OneAgent..."

# Restart twice as recommended by Dynatrace documentation
# First restart: Initialize OneAgent installation
print_info "First restart - initializing OneAgent installation..."
az webapp restart \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --output none

print_info "Waiting 30 seconds for OneAgent to initialize..."
sleep 30

# Second restart: Start OneAgent instrumenting the application
print_info "Second restart - starting OneAgent instrumentation..."
az webapp restart \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --output none

print_info "✓ App Service restarted (twice for OneAgent initialization)"

#########################################
# STEP 8: SEND DEPLOYMENT EVENT TO DYNATRACE
#########################################

print_info "Step 8: Sending deployment event to Dynatrace..."

DEPLOYMENT_RESPONSE=$(curl -s -X POST "https://$DT_TENANT.$DT_DOMAIN/api/v2/events/ingest" \
    -H "Authorization: Api-Token $DT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "eventType": "CUSTOM_DEPLOYMENT",
        "title": "Deployment: '"$APP_NAME"'",
        "properties": {
            "deploymentName": "'"$APP_NAME"'",
            "deploymentVersion": "1.0.0",
            "deploymentProject": "DevOps Demo",
            "source": "Deployment Script",
            "environment": "Demo"
        }
    }')

if [ $? -eq 0 ]; then
    print_info "✓ Deployment event sent to Dynatrace"
else
    print_warning "Failed to send deployment event to Dynatrace"
fi

#########################################
# STEP 9: VERIFY DEPLOYMENT
#########################################

print_info "Step 9: Verifying deployment..."

# Wait for app to start
print_info "Waiting 30 seconds for application to start..."
sleep 30

# Test the application
print_info "Testing application endpoints..."

# Test root endpoint
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$APP_URL/" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_info "✓ Root endpoint responding (HTTP $HTTP_STATUS)"
else
    print_warning "Root endpoint returned HTTP $HTTP_STATUS"
fi

# Test health endpoint
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$APP_URL/api/health" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_info "✓ Health endpoint responding (HTTP $HTTP_STATUS)"
else
    print_warning "Health endpoint returned HTTP $HTTP_STATUS"
fi

# Test products endpoint
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$APP_URL/api/products" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    print_info "✓ Products endpoint responding (HTTP $HTTP_STATUS)"
else
    print_warning "Products endpoint returned HTTP $HTTP_STATUS"
fi

#########################################
# DEPLOYMENT SUMMARY
#########################################

echo ""
echo "=========================================="
echo "         DEPLOYMENT COMPLETED!            "
echo "=========================================="
echo ""
print_info "Resource Group: $RESOURCE_GROUP"
print_info "App Service Plan: $APP_SERVICE_PLAN"
print_info "App Service Name: $APP_NAME"
print_info "App URL: https://$APP_URL"
echo ""
print_info "Available Endpoints:"
echo "  • Root:          https://$APP_URL/"
echo "  • Swagger UI:    https://$APP_URL/swagger"
echo "  • Health:        https://$APP_URL/api/health"
echo "  • Products:      https://$APP_URL/api/products"
echo "  • Health Check:  https://$APP_URL/health"
echo ""
print_info "Azure Portal:"
echo "  https://portal.azure.com/#resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$APP_NAME"
echo ""
print_info "Dynatrace:"
echo "  https://$DT_TENANT.$DT_DOMAIN"
echo "  Wait 5-10 minutes for data to appear in Dynatrace"
echo ""
print_info "View Logs:"
echo "  az webapp log tail --resource-group $RESOURCE_GROUP --name $APP_NAME"
echo ""
print_info "Cleanup (delete all resources):"
echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo ""
echo "=========================================="

#########################################
# OPTIONAL: STREAM LOGS
#########################################

read -p "Do you want to stream application logs? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Streaming logs (Press Ctrl+C to stop)..."
    az webapp log tail \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_NAME"
fi