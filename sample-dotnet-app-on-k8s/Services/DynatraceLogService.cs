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
