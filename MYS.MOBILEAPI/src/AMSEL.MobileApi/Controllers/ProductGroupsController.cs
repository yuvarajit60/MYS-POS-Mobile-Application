using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/product-groups")]
public class ProductGroupsController : ControllerBase
{
    private readonly IProductGroupService _productGroupService;

    public ProductGroupsController(IProductGroupService productGroupService)
    {
        _productGroupService = productGroupService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ProductGroupDto>>> Search([FromQuery] string? search)
        => Ok(await _productGroupService.SearchAsync(search));
}
