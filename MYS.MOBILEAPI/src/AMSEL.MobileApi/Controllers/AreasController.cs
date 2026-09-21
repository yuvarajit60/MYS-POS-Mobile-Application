using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/areas")]
public class AreasController : ControllerBase
{
    private readonly IAreaService _areaService;

    public AreasController(IAreaService areaService)
    {
        _areaService = areaService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AreaDto>>> Search([FromQuery] string? search, [FromQuery] int? cityId)
        => Ok(await _areaService.SearchAsync(search, cityId));

    [HttpPost]
    public async Task<ActionResult<AreaDto>> Create(CreateAreaRequest request)
    {
        try
        {
            var result = await _areaService.CreateAsync(request, User.GetUsername());
            return Ok(result);
        }
        catch (DuplicateAreaNameException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{areaId:int}")]
    public async Task<ActionResult<AreaDto>> Update(int areaId, UpdateAreaRequest request)
    {
        try
        {
            var result = await _areaService.UpdateAsync(areaId, request, User.GetUsername());
            return Ok(result);
        }
        catch (DuplicateAreaNameException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpDelete("{areaId:int}")]
    public async Task<IActionResult> Delete(int areaId)
    {
        var deleted = await _areaService.DeleteAsync(areaId, User.GetUsername());
        return deleted ? NoContent() : NotFound();
    }
}
