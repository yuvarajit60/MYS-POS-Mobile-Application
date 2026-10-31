using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/reports/income-expenses")]
public class IncomeExpenseReportsController : ControllerBase
{
    private readonly IIncomeExpenseReportService _incomeExpenseReportService;

    public IncomeExpenseReportsController(IIncomeExpenseReportService incomeExpenseReportService)
    {
        _incomeExpenseReportService = incomeExpenseReportService;
    }

    [HttpGet("summary")]
    public async Task<ActionResult<IReadOnlyList<IncomeExpenseSummaryDto>>> Summary(
        [FromQuery] string? entryNo, [FromQuery] DateTime fromDate, [FromQuery] DateTime toDate)
        => Ok(await _incomeExpenseReportService.GetSummaryAsync(User.GetLocationId(), entryNo, fromDate, toDate));

    [HttpGet("entry-numbers")]
    public async Task<ActionResult<IReadOnlyList<IncomeExpenseEntryNumberDto>>> EntryNumbers([FromQuery] string? search)
        => Ok(await _incomeExpenseReportService.SearchEntryNumbersAsync(User.GetLocationId(), search));
}
