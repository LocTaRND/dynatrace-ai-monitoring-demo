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
}

public class Product
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
}
