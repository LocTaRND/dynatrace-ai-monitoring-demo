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
