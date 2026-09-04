using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/sites")]
public class SitesController : ControllerBase
{
    private readonly ISiteService _siteService;

    public SitesController(ISiteService siteService)
    {
        _siteService = siteService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<SiteDto>>> Search([FromQuery] string? search)
        => Ok(await _siteService.SearchAsync(search));

    [HttpGet("{siteId:int}")]
    public async Task<ActionResult<SiteDetailDto>> GetById(int siteId)
    {
        var site = await _siteService.GetByIdAsync(siteId);
        return site is null ? NotFound() : Ok(site);
    }

    [HttpPost]
    public async Task<ActionResult<SiteDetailDto>> Create(CreateSiteRequest request)
    {
        try
        {
            var result = await _siteService.CreateAsync(
                request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateSiteNameException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{siteId:int}")]
    public async Task<ActionResult<SiteDetailDto>> Update(int siteId, UpdateSiteRequest request)
    {
        try
        {
            var result = await _siteService.UpdateAsync(
                siteId, request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateSiteNameException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpDelete("{siteId:int}")]
    public async Task<IActionResult> Delete(int siteId)
    {
        var deleted = await _siteService.DeleteAsync(
            siteId, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
        return deleted ? NoContent() : NotFound();
    }
}
