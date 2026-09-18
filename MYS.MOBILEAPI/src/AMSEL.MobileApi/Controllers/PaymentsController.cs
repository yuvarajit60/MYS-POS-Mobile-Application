using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/payments")]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _paymentService;

    public PaymentsController(IPaymentService paymentService)
    {
        _paymentService = paymentService;
    }

    [HttpGet("delivered-customers")]
    public async Task<ActionResult<IReadOnlyList<CustomerDto>>> DeliveredCustomers([FromQuery] string? search)
        => Ok(await _paymentService.SearchDeliveredCustomersAsync(User.GetLocationId(), search));

    [HttpPost]
    public async Task<ActionResult<CreatePaymentResponse>> Create(CreatePaymentRequest request)
    {
        try
        {
            var result = await _paymentService.CreateAsync(request, User.GetLocationId(), User.GetUsername());
            return Ok(result);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
