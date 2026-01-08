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
SKU="B2"  # Basic tier (cheap for demo, use P1V2 for production)

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
print_info "Using Azure subscription: $SUBSCRIPTION_NAME"

#########################################
# STEP 1: CREATE .NET APPLICATION WITH DYNATRACE LOGGING
#########################################

print_info "Step 1: Creating sample .NET application with Dynatrace log integration..."

# Remove existing directory if it exists
if [ -d "$APP_DIR" ]; then
    print_warning "Directory $APP_DIR exists. Removing..."
    rm -rf "$APP_DIR"
fi

# Create new .NET Web API project
dotnet new webapi -n SampleAPI -o "$APP_DIR" --framework net$DOTNET_VERSION --no-https

cd "$APP_DIR"

# Create Controllers and Services directories
mkdir -p Controllers Services

# Create Dynatrace Logger Service
cat > Services/DynatraceLogService.cs << 'EOF'
using System.Text;
using System.Text.Json;

namespace SampleAPI.Services;

public interface IDynatraceLogService
{
    Task SendLogAsync(string message, string severity = "INFO", Dictionary<string, string>? attributes = null);
}

public class DynatraceLogService : IDynatraceLogService
{
    private static readonly HttpClient _httpClient = new();
    private readonly string? _endpoint;
    private readonly string? _token;
    private readonly string _serviceName;
    private readonly bool _isEnabled;

    public DynatraceLogService()
    {
        _endpoint = Environment.GetEnvironmentVariable("DT_ENDPOINT");
        _token = Environment.GetEnvironmentVariable("DT_API_TOKEN");
        _serviceName = Environment.GetEnvironmentVariable("WEBSITE_SITE_NAME") ?? "unknown-service";
        _isEnabled = !string.IsNullOrEmpty(_endpoint) && !string.IsNullOrEmpty(_token);

        if (_isEnabled && !_httpClient.DefaultRequestHeaders.Contains("Authorization"))
        {
            _httpClient.DefaultRequestHeaders.Add("Authorization", $"Api-Token {_token}");
            _httpClient.Timeout = TimeSpan.FromSeconds(5);
        }
    }

    public async Task SendLogAsync(string message, string severity = "INFO", Dictionary<string, string>? attributes = null)
    {
        if (!_isEnabled) return;

        try
        {
            var logEntry = new
            {
                content = message,
                severity = severity.ToUpper(),
                timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                attributes = new Dictionary<string, string>
                {
                    ["service.name"] = _serviceName,
                    ["service.namespace"] = "azure-appservice",
                    ["host.name"] = Environment.MachineName,
                    ["cloud.platform"] = "azure_app_service",
                    ["deployment.environment"] = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "production"
                }.Concat(attributes ?? new Dictionary<string, string>())
                 .ToDictionary(kvp => kvp.Key, kvp => kvp.Value)
            };

            var json = JsonSerializer.Serialize(logEntry);
            var content = new StringContent(json, Encoding.UTF8, "application/json");

            var response = await _httpClient.PostAsync($"{_endpoint}/api/v2/logs/ingest", content);
            
            // Silent fail - don't break the application if logging fails
            if (!response.IsSuccessStatusCode)
            {
                Console.WriteLine($"[Dynatrace] Failed to send log: {response.StatusCode}");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Dynatrace] Exception sending log: {ex.Message}");
        }
    }
}
EOF

# Create Health Controller with enhanced logging
cat > Controllers/HealthController.cs << 'EOF'
using Microsoft.AspNetCore.Mvc;
using SampleAPI.Services;

namespace SampleAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    private readonly ILogger<HealthController> _logger;
    private readonly IDynatraceLogService _dtLogger;

    public HealthController(ILogger<HealthController> logger, IDynatraceLogService dtLogger)
    {
        _logger = logger;
        _dtLogger = dtLogger;
    }

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var remoteIp = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        
        _logger.LogInformation("Health check endpoint called from {RemoteIp}", remoteIp);
        
        await _dtLogger.SendLogAsync(
            $"Health check from {remoteIp}",
            "INFO",
            new Dictionary<string, string>
            {
                ["endpoint"] = "/api/health",
                ["remote_ip"] = remoteIp,
                ["method"] = "GET"
            }
        );
        
        var isDynatraceEnabled = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("DT_ENDPOINT"));
        
        return Ok(new
        {
            Status = "Healthy",
            Timestamp = DateTime.UtcNow,
            Environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"),
            MachineName = Environment.MachineName,
            DynatraceEnabled = isDynatraceEnabled,
            Version = "1.0.1"
        });
    }

    [HttpGet("ready")]
    public async Task<IActionResult> Ready()
    {
        _logger.LogInformation("Readiness check endpoint called");
        await _dtLogger.SendLogAsync("Readiness check", "INFO");
        return Ok(new { Status = "Ready", Timestamp = DateTime.UtcNow });
    }

    [HttpGet("live")]
    public async Task<IActionResult> Live()
    {
        _logger.LogInformation("Liveness check endpoint called");
        await _dtLogger.SendLogAsync("Liveness check", "INFO");
        return Ok(new { Status = "Live", Timestamp = DateTime.UtcNow });
    }
}
EOF

# Create Products Controller with enhanced logging AND ERROR SIMULATION
cat > Controllers/ProductsController.cs << 'EOF'
using Microsoft.AspNetCore.Mvc;
using SampleAPI.Services;

namespace SampleAPI.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly ILogger<ProductsController> _logger;
    private readonly IDynatraceLogService _dtLogger;
    private static readonly List<Product> Products = new()
    {
        new Product { Id = 1, Name = "Camera", Price = 599.99m },
        new Product { Id = 2, Name = "Lens", Price = 399.99m },
        new Product { Id = 3, Name = "Tripod", Price = 89.99m }
    };

    public ProductsController(ILogger<ProductsController> logger, IDynatraceLogService dtLogger)
    {
        _logger = logger;
        _dtLogger = dtLogger;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        _logger.LogInformation("Getting all products - Count: {Count}", Products.Count);
        await _dtLogger.SendLogAsync($"Retrieved all products (count: {Products.Count})", "INFO");
        return Ok(Products);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        _logger.LogInformation("Getting product with id: {ProductId}", id);
        var product = Products.FirstOrDefault(p => p.Id == id);
        
        if (product == null)
        {
            _logger.LogWarning("Product with id {ProductId} not found", id);
            await _dtLogger.SendLogAsync($"Product not found: {id}", "WARN");
            return NotFound();
        }
        
        await _dtLogger.SendLogAsync($"Retrieved product: {product.Name} (id: {id})", "INFO");
        return Ok(product);
    }

    [HttpPost]
    public async Task<IActionResult> Create(Product product)
    {
        _logger.LogInformation("Creating new product: {ProductName}", product.Name);
        product.Id = Products.Max(p => p.Id) + 1;
        Products.Add(product);
        
        await _dtLogger.SendLogAsync(
            $"Created new product: {product.Name}",
            "INFO",
            new Dictionary<string, string>
            {
                ["product.id"] = product.Id.ToString(),
                ["product.name"] = product.Name,
                ["product.price"] = product.Price.ToString()
            }
        );
        
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }

    // ERROR SIMULATION ENDPOINTS
    
    [HttpGet("error/exception")]
    public async Task<IActionResult> ThrowException()
    {
        _logger.LogError("Simulating unhandled exception");
        await _dtLogger.SendLogAsync("About to throw exception", "ERROR");
        throw new InvalidOperationException("Simulated exception for Dynatrace testing!");
    }

    [HttpGet("error/500")]
    public async Task<IActionResult> InternalError()
    {
        _logger.LogError("Simulating 500 Internal Server Error");
        await _dtLogger.SendLogAsync("500 Internal Server Error simulated", "ERROR");
        return StatusCode(500, new { Error = "Internal Server Error", Message = "Simulated error for testing" });
    }

    [HttpGet("error/timeout")]
    public async Task<IActionResult> Timeout()
    {
        _logger.LogWarning("Simulating slow request (10 seconds)");
        await _dtLogger.SendLogAsync("Slow request started", "WARN");
        await Task.Delay(10000);
        await _dtLogger.SendLogAsync("Slow request completed", "WARN");
        return Ok(new { Message = "Completed after 10 seconds" });
    }

    [HttpGet("error/memory")]
    public async Task<IActionResult> MemoryLeak()
    {
        _logger.LogWarning("Simulating high memory usage");
        await _dtLogger.SendLogAsync("High memory allocation started", "WARN");
        var list = new List<byte[]>();
        for (int i = 0; i < 100; i++)
        {
            list.Add(new byte[1024 * 1024]); // 1MB each
        }
        await Task.Delay(5000);
        await _dtLogger.SendLogAsync("High memory allocation completed", "WARN");
        return Ok(new { Message = "Allocated 100MB", Count = list.Count });
    }

    [HttpGet("error/cpu")]
    public async Task<IActionResult> CpuIntensive()
    {
        _logger.LogWarning("Simulating high CPU usage");
        await _dtLogger.SendLogAsync("CPU intensive operation started", "WARN");
        
        await Task.Run(() =>
        {
            var result = 0;
            for (int i = 0; i < 100000000; i++)
            {
                result += i * i;
            }
            return result;
        });
        
        await _dtLogger.SendLogAsync("CPU intensive operation completed", "WARN");
        return Ok(new { Message = "CPU intensive operation completed" });
    }

    [HttpGet("error/database")]
    public async Task<IActionResult> DatabaseError()
    {
        _logger.LogError("Simulating database connection error");
        await _dtLogger.SendLogAsync("Database connection failed", "ERROR", new Dictionary<string, string>
        {
            ["error.type"] = "database_connection",
            ["error.message"] = "Connection timeout"
        });
        return StatusCode(503, new { Error = "Database Unavailable", Message = "Cannot connect to database" });
    }
}

public class Product
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
}
EOF

# Create Program.cs with comprehensive logging
cat > Program.cs << 'EOF'
using SampleAPI.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHealthChecks();

// Register Dynatrace logging service
builder.Services.AddSingleton<IDynatraceLogService, DynatraceLogService>();

// Configure logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

// Configure structured JSON logging
builder.Logging.AddJsonConsole(options =>
{
    options.IncludeScopes = true;
    options.TimestampFormat = "yyyy-MM-ddTHH:mm:ss.fffZ";
    options.JsonWriterOptions = new System.Text.Json.JsonWriterOptions
    {
        Indented = false
    };
});

var app = builder.Build();

var dtLogger = app.Services.GetRequiredService<IDynatraceLogService>();

// Log application startup
await dtLogger.SendLogAsync("Application starting", "INFO", new Dictionary<string, string>
{
    ["event.type"] = "application_start",
    ["environment"] = app.Environment.EnvironmentName
});

// Middleware to log all requests
app.Use(async (context, next) =>
{
    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
    var startTime = DateTime.UtcNow;
    
    logger.LogInformation("Incoming request: {Method} {Path} from {RemoteIp}",
        context.Request.Method,
        context.Request.Path,
        context.Connection.RemoteIpAddress);
    
    await dtLogger.SendLogAsync(
        $"{context.Request.Method} {context.Request.Path}",
        "INFO",
        new Dictionary<string, string>
        {
            ["http.method"] = context.Request.Method,
            ["http.url"] = context.Request.Path,
            ["http.remote_addr"] = context.Connection.RemoteIpAddress?.ToString() ?? "unknown"
        }
    );
    
    await next();
    
    var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
    
    logger.LogInformation("Response: {StatusCode} for {Path} ({Duration}ms)",
        context.Response.StatusCode,
        context.Request.Path,
        duration);
    
    await dtLogger.SendLogAsync(
        $"Response {context.Response.StatusCode} for {context.Request.Path}",
        context.Response.StatusCode >= 400 ? "ERROR" : "INFO",
        new Dictionary<string, string>
        {
            ["http.status_code"] = context.Response.StatusCode.ToString(),
            ["http.duration_ms"] = duration.ToString("F2")
        }
    );
});

// Configure the HTTP request pipeline
app.UseSwagger();
app.UseSwaggerUI();

app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");

// Root endpoint
app.MapGet("/", async () =>
{
    await dtLogger.SendLogAsync("Root endpoint accessed", "INFO");
    
    return Results.Ok(new
    {
        Application = "Dynatrace Demo API",
        Version = "1.0.1",
        Environment = app.Environment.EnvironmentName,
        DynatraceEnabled = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable("DT_ENDPOINT")),
        Endpoints = new[]
        {
            "/api/health",
            "/api/products",
            "/health",
            "/swagger"
        }
    });
});

// Log successful startup
await dtLogger.SendLogAsync("Application started successfully", "INFO", new Dictionary<string, string>
{
    ["event.type"] = "application_ready"
});

app.Run();
EOF

# Build the application
print_info "Building application..."
dotnet build -v q

print_info "✓ Sample .NET application created with Dynatrace log integration!"
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
        DT_HOSTNAME="$APP_NAME" \
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

# az webapp deploy \
#     --resource-group "$RESOURCE_GROUP" \
#     --name "$APP_NAME" \
#     --src-path deploy.zip \
#     --type zip \
#     --timeout 300 \
#     --async true

az webapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --src deploy.zip \
    --output none \
    --timeout 300

print_info "✓ Application deployment initiated (running asynchronously)"
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

print_info "Waiting 30 seconds for OneAgent installation..."
sleep 30

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

sleep 20

print_info "Sending requests in parallel..."
for i in {1..20}; do
    curl -s "https://$APP_URL/" > /dev/null 2>&1 &
    curl -s "https://$APP_URL/api/health" > /dev/null 2>&1 &
    curl -s "https://$APP_URL/api/products" > /dev/null 2>&1 &
done
wait
echo "✓"

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