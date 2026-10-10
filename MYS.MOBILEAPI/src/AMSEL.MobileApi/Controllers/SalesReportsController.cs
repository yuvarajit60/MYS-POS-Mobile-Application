using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/reports/sales")]
public class SalesReportsController : ControllerBase
{
    private readonly ISalesReportService _salesReportService;

    public SalesReportsController(ISalesReportService salesReportService)
    {
        _salesReportService = salesReportService;
    }

    [HttpGet("summary")]
    public async Task<ActionResult<IReadOnlyList<SalesSummaryDto>>> Summary(
        [FromQuery] int? customerId, [FromQuery] string? salesNo,
        [FromQuery] DateTime fromDate, [FromQuery] DateTime toDate)
        => Ok(await _salesReportService.GetSummaryAsync(User.GetLocationId(), customerId, salesNo, fromDate, toDate));

    // Drill-down from a Summary row: full header + line items for one Sales entry.
    [HttpGet("{salesId:int}")]
    public async Task<ActionResult<SalesDetailDto>> SalesDetail(int salesId)
    {
        var detail = await _salesReportService.GetSalesDetailAsync(User.GetLocationId(), salesId);
        return detail is null ? NotFound() : Ok(detail);
    }

    [HttpGet("entry-numbers")]
    public async Task<ActionResult<IReadOnlyList<SalesEntryNumberDto>>> EntryNumbers([FromQuery] string? search)
        => Ok(await _salesReportService.SearchEntryNumbersAsync(User.GetLocationId(), search));
}
