using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/reports/deliveries")]
public class DeliveryReportsController : ControllerBase
{
    private readonly IDeliveryReportService _deliveryReportService;

    public DeliveryReportsController(IDeliveryReportService deliveryReportService)
    {
        _deliveryReportService = deliveryReportService;
    }

    [HttpGet("summary")]
    public async Task<ActionResult<IReadOnlyList<DeliverySummaryDto>>> Summary(
        [FromQuery] int? customerId, [FromQuery] string? deliveryNo,
        [FromQuery] DateTime fromDate, [FromQuery] DateTime toDate)
        => Ok(await _deliveryReportService.GetSummaryAsync(User.GetLocationId(), customerId, deliveryNo, fromDate, toDate));

    // DeliveryNo is passed as a query param (not a path segment) because it
    // contains slashes (e.g. "DLV/25-26/0001") which would otherwise clash
    // with ASP.NET Core's path routing.
    [HttpGet("detail")]
    public async Task<ActionResult<DeliveryDetailDto>> Detail([FromQuery] string deliveryNo)
    {
        var detail = await _deliveryReportService.GetDeliveryDetailAsync(User.GetLocationId(), deliveryNo);
        return detail is null ? NotFound() : Ok(detail);
    }

    [HttpGet("delivery-numbers")]
    public async Task<ActionResult<IReadOnlyList<DeliveryNumberDto>>> DeliveryNumbers([FromQuery] string? search)
        => Ok(await _deliveryReportService.SearchDeliveryNumbersAsync(User.GetLocationId(), search));
}
