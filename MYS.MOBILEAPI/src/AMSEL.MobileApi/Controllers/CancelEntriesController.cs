using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/cancel-entries")]
public class CancelEntriesController : ControllerBase
{
    private readonly ICancelEntryService _cancelEntryService;

    public CancelEntriesController(ICancelEntryService cancelEntryService)
    {
        _cancelEntryService = cancelEntryService;
    }

    [HttpGet("options")]
    public async Task<ActionResult<IReadOnlyList<CancelEntryOptionDto>>> SearchEntries(
        [FromQuery] string transactionType, [FromQuery] DateTime date)
        => Ok(await _cancelEntryService.SearchEntriesAsync(User.GetLocationId(), transactionType, date));

    [HttpPost]
    public async Task<IActionResult> Cancel(CancelEntryRequest request)
    {
        try
        {
            await _cancelEntryService.CancelAsync(User.GetLocationId(), User.GetUserId(), request);
            return NoContent();
        }
        catch (InvalidCancelEntryException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }
}
