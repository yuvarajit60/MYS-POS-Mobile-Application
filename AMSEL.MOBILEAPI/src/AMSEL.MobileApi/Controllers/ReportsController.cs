using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/reports/sales-orders")]
public class ReportsController : ControllerBase
{
    private readonly IReportService _reportService;

    public ReportsController(IReportService reportService)
    {
        _reportService = reportService;
    }

    [HttpGet("summary")]
    public async Task<ActionResult<IReadOnlyList<SalesOrderSummaryDto>>> Summary(
        [FromQuery] int? customerId, [FromQuery] string? salesOrderNo,
        [FromQuery] DateTime fromDate, [FromQuery] DateTime toDate)
        => Ok(await _reportService.GetSummaryAsync(User.GetLocationId(), customerId, salesOrderNo, fromDate, toDate));

    // Drill-down from a Summary row: full header + line items for one order.
    [HttpGet("{salesOrderId:int}")]
    public async Task<ActionResult<OrderDetailDto>> OrderDetail(int salesOrderId)
    {
        var detail = await _reportService.GetOrderDetailAsync(User.GetLocationId(), salesOrderId);
        return detail is null ? NotFound() : Ok(detail);
    }

    [HttpGet("graph")]
    public async Task<ActionResult<IReadOnlyList<GraphDataPointDto>>> Graph(
        [FromQuery] string groupBy, [FromQuery] int? year)
        => Ok(await _reportService.GetGraphDataAsync(User.GetLocationId(), groupBy, year));

    [HttpGet("entry-numbers")]
    public async Task<ActionResult<IReadOnlyList<EntryNumberDto>>> EntryNumbers([FromQuery] string? search)
        => Ok(await _reportService.SearchEntryNumbersAsync(User.GetLocationId(), search));
}
