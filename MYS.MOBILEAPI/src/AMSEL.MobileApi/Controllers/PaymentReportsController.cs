using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/reports/payments")]
public class PaymentReportsController : ControllerBase
{
    private readonly IPaymentReportService _paymentReportService;

    public PaymentReportsController(IPaymentReportService paymentReportService)
    {
        _paymentReportService = paymentReportService;
    }

    [HttpGet("summary")]
    public async Task<ActionResult<IReadOnlyList<PaymentReportEntryDto>>> Summary(
        [FromQuery] int? customerId, [FromQuery] string? paymentType,
        [FromQuery] DateTime fromDate, [FromQuery] DateTime toDate)
        => Ok(await _paymentReportService.GetSummaryAsync(User.GetLocationId(), customerId, paymentType, fromDate, toDate));
}
