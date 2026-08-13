using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/products")]
public class ProductsController : ControllerBase
{
    private readonly IProductService _productService;

    public ProductsController(IProductService productService)
    {
        _productService = productService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ProductDto>>> Search([FromQuery] string? search)
        => Ok(await _productService.SearchAsync(search));

    [HttpGet("{productId:int}")]
    public async Task<ActionResult<ProductDetailDto>> GetById(int productId)
    {
        var product = await _productService.GetByIdAsync(productId);
        return product is null ? NotFound() : Ok(product);
    }

    [HttpPost]
    public async Task<ActionResult<ProductDto>> Create(CreateProductRequest request)
    {
        try
        {
            var result = await _productService.CreateAsync(
                request, User.GetUsername(), User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateProductNameException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{productId:int}")]
    public async Task<ActionResult<ProductDto>> Update(int productId, UpdateProductRequest request)
    {
        try
        {
            var result = await _productService.UpdateAsync(
                productId, request, User.GetUsername(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateProductNameException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpDelete("{productId:int}")]
    public async Task<IActionResult> Delete(int productId)
    {
        var deleted = await _productService.DeleteAsync(productId, User.GetUserId(), User.GetEmployeeId());
        return deleted ? NoContent() : NotFound();
    }
}
