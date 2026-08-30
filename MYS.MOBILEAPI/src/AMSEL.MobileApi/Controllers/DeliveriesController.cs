using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/deliveries")]
public class DeliveriesController : ControllerBase
{
    private readonly IDeliveryService _deliveryService;

    public DeliveriesController(IDeliveryService deliveryService)
    {
        _deliveryService = deliveryService;
    }

    [HttpGet("pending-customers")]
    public async Task<ActionResult<IReadOnlyList<CustomerDto>>> PendingCustomers([FromQuery] string? search)
        => Ok(await _deliveryService.GetPendingCustomersAsync(User.GetLocationId(), search));

    [HttpGet("pending-lines")]
    public async Task<ActionResult<IReadOnlyList<PendingDeliveryLineDto>>> PendingLines([FromQuery] int customerId)
        => Ok(await _deliveryService.GetPendingLinesAsync(User.GetLocationId(), customerId));

    [HttpPost]
    public async Task<ActionResult<CreateDeliveryResponse>> Create(CreateDeliveryRequest request)
    {
        try
        {
            var result = await _deliveryService.CreateAsync(request, User.GetLocationId(), User.GetUsername());
            return Ok(result);
        }
        catch (Microsoft.Data.SqlClient.SqlException ex)
        {
            // Business-rule failures raised by SP_MOBILE_CREATE_DELIVERY (e.g. balance
            // exceeded, line no longer exists) surface as RAISERROR — client error, not 500.
            return BadRequest(new { message = ex.Message });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
