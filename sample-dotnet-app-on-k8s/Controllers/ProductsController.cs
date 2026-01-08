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
