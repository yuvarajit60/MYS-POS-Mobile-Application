using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/types")]
public class TypesController : ControllerBase
{
    private readonly ITypeService _typeService;

    public TypesController(ITypeService typeService)
    {
        _typeService = typeService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<TypeDto>>> Search([FromQuery] string? search)
        => Ok(await _typeService.SearchAsync(search));
}
