using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/sales-orders")]
public class SalesOrdersController : ControllerBase
{
    private readonly ISalesOrderService _salesOrderService;

    public SalesOrdersController(ISalesOrderService salesOrderService)
    {
        _salesOrderService = salesOrderService;
    }

    [HttpPost]
    public async Task<ActionResult<CreateSalesOrderResponse>> Create(CreateSalesOrderRequest request)
    {
        try
        {
            var result = await _salesOrderService.CreateAsync(
                request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex)
        {
            // Business-rule failures raised by SP_MOBILE_CREATE_SALESORDER (e.g. no valid
            // price or no stock) surface as RAISERROR — treat as a client error, not a 500.
            return BadRequest(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
