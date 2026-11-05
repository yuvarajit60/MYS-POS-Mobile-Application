using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/heads")]
public class HeadsController : ControllerBase
{
    private readonly IHeadService _headService;

    public HeadsController(IHeadService headService)
    {
        _headService = headService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<HeadDto>>> Search([FromQuery] string? search)
        => Ok(await _headService.SearchAsync(search));

    [HttpGet("{headId:int}")]
    public async Task<ActionResult<HeadDetailDto>> GetById(int headId)
    {
        var head = await _headService.GetByIdAsync(headId);
        return head is null ? NotFound() : Ok(head);
    }

    [HttpPost]
    public async Task<ActionResult<HeadDetailDto>> Create(CreateHeadRequest request)
    {
        try
        {
            var result = await _headService.CreateAsync(
                request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateHeadNameException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{headId:int}")]
    public async Task<ActionResult<HeadDetailDto>> Update(int headId, UpdateHeadRequest request)
    {
        try
        {
            var result = await _headService.UpdateAsync(
                headId, request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateHeadNameException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpDelete("{headId:int}")]
    public async Task<IActionResult> Delete(int headId)
    {
        var deleted = await _headService.DeleteAsync(
            headId, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
        return deleted ? NoContent() : NotFound();
    }
}
