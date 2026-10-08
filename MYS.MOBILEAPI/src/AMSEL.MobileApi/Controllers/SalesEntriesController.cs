using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/sales-entries")]
public class SalesEntriesController : ControllerBase
{
    private readonly ISalesEntryService _salesEntryService;

    public SalesEntriesController(ISalesEntryService salesEntryService)
    {
        _salesEntryService = salesEntryService;
    }

    [HttpGet("options")]
    public async Task<ActionResult<IReadOnlyList<SalesEntryOptionDto>>> Search(
        [FromQuery] int? customerId, [FromQuery] DateTime fromDate, [FromQuery] DateTime toDate)
        => Ok(await _salesEntryService.SearchAsync(User.GetLocationId(), customerId, fromDate, toDate));

    [HttpPost]
    public async Task<ActionResult<CreateSalesEntryResponse>> Create(CreateSalesEntryRequest request)
    {
        try
        {
            var result = await _salesEntryService.CreateAsync(request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (InvalidSalesEntryException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }
}
