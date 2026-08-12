using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/customers")]
public class CustomersController : ControllerBase
{
    private readonly ICustomerService _customerService;

    public CustomersController(ICustomerService customerService)
    {
        _customerService = customerService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<CustomerDto>>> Search([FromQuery] string? search)
        => Ok(await _customerService.SearchAsync(search));

    [HttpGet("{customerId:int}")]
    public async Task<ActionResult<CustomerDetailDto>> GetById(int customerId)
    {
        var customer = await _customerService.GetByIdAsync(customerId);
        return customer is null ? NotFound() : Ok(customer);
    }

    [HttpPost]
    public async Task<ActionResult<CustomerDto>> Create(CreateCustomerRequest request)
    {
        var result = await _customerService.CreateAsync(
            request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
        return Ok(result);
    }

    [HttpPut("{customerId:int}")]
    public async Task<ActionResult<CustomerDto>> Update(int customerId, UpdateCustomerRequest request)
    {
        var result = await _customerService.UpdateAsync(
            customerId, request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
        return Ok(result);
    }

    [HttpDelete("{customerId:int}")]
    public async Task<IActionResult> Delete(int customerId)
    {
        var deleted = await _customerService.DeleteAsync(
            customerId, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
        return deleted ? NoContent() : NotFound();
    }
}
