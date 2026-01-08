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
