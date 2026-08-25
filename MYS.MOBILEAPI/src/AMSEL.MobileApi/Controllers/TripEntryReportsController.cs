using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/reports/trip-entries")]
public class TripEntryReportsController : ControllerBase
{
    private readonly ITripEntryReportService _tripEntryReportService;

    public TripEntryReportsController(ITripEntryReportService tripEntryReportService)
    {
        _tripEntryReportService = tripEntryReportService;
    }

    [HttpGet("summary")]
    public async Task<ActionResult<IReadOnlyList<TripEntrySummaryDto>>> Summary(
        [FromQuery] int? customerId, [FromQuery] string? tripEntryNo,
        [FromQuery] DateTime fromDate, [FromQuery] DateTime toDate)
        => Ok(await _tripEntryReportService.GetSummaryAsync(User.GetLocationId(), customerId, tripEntryNo, fromDate, toDate));

    // Drill-down from a Summary row: full header + line items for one trip entry.
    [HttpGet("{tripEntryId:int}")]
    public async Task<ActionResult<TripEntryDetailDto>> TripEntryDetail(int tripEntryId)
    {
        var detail = await _tripEntryReportService.GetTripEntryDetailAsync(User.GetLocationId(), tripEntryId);
        return detail is null ? NotFound() : Ok(detail);
    }

    [HttpGet("graph")]
    public async Task<ActionResult<IReadOnlyList<GraphDataPointDto>>> Graph(
        [FromQuery] string groupBy, [FromQuery] int? year)
        => Ok(await _tripEntryReportService.GetGraphDataAsync(User.GetLocationId(), groupBy, year));

    [HttpGet("entry-numbers")]
    public async Task<ActionResult<IReadOnlyList<TripEntryNumberDto>>> EntryNumbers([FromQuery] string? search)
        => Ok(await _tripEntryReportService.SearchTripEntryNumbersAsync(User.GetLocationId(), search));
}
