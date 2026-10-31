using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/income-expenses")]
public class IncomeExpensesController : ControllerBase
{
    private readonly IIncomeExpenseService _incomeExpenseService;

    public IncomeExpensesController(IIncomeExpenseService incomeExpenseService)
    {
        _incomeExpenseService = incomeExpenseService;
    }

    [HttpGet("heads")]
    public async Task<ActionResult<IReadOnlyList<HeadDto>>> GetHeads([FromQuery] string? incomeOrExpenses)
        => Ok(await _incomeExpenseService.GetHeadsAsync(incomeOrExpenses));

    [HttpPost]
    public async Task<ActionResult<CreateIncomeExpenseResponse>> Create(CreateIncomeExpenseRequest request)
    {
        try
        {
            var result = await _incomeExpenseService.CreateAsync(request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (InvalidIncomeExpenseException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }
}
