using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/trip-entries")]
public class TripEntriesController : ControllerBase
{
    private readonly ITripEntryService _tripEntryService;

    public TripEntriesController(ITripEntryService tripEntryService)
    {
        _tripEntryService = tripEntryService;
    }

    [HttpPost]
    public async Task<ActionResult<CreateTripEntryResponse>> Create(CreateTripEntryRequest request)
    {
        try
        {
            var result = await _tripEntryService.CreateAsync(
                request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex)
        {
            // Business-rule failures raised by SP_MOBILE_CREATE_TRIPENTRY (e.g. site not
            // found) surface as RAISERROR — treat as a client error, not a 500.
            return BadRequest(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
