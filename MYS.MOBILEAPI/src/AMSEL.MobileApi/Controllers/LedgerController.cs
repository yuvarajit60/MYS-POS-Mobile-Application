using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/reports/ledger")]
public class LedgerController : ControllerBase
{
    private readonly ILedgerService _ledgerService;

    public LedgerController(ILedgerService ledgerService)
    {
        _ledgerService = ledgerService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<LedgerEntryDto>>> Get(
        [FromQuery] int customerId, [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate)
        => Ok(await _ledgerService.GetAsync(User.GetLocationId(), customerId, fromDate, toDate));

    [HttpGet("summary")]
    public async Task<ActionResult<LedgerSummaryDto>> GetSummary([FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate)
        => Ok(await _ledgerService.GetSummaryAsync(User.GetLocationId(), fromDate, toDate));
}
