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
        [FromQuery] int? customerId, [FromQuery] DateTime fromDate, [FromQuery] DateTime toDate)
        => Ok(await _deliveryReportService.GetSummaryAsync(User.GetLocationId(), customerId, fromDate, toDate));
}
