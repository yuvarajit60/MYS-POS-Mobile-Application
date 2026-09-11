using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/employees")]
public class EmployeesController : ControllerBase
{
    private readonly IEmployeeService _employeeService;

    public EmployeesController(IEmployeeService employeeService)
    {
        _employeeService = employeeService;
    }

    [HttpGet("drivers")]
    public async Task<ActionResult<IReadOnlyList<DriverDto>>> GetDrivers([FromQuery] string? search)
        => Ok(await _employeeService.GetDriversAsync(search));

    [HttpGet("{employeeId:int}/vehicle")]
    public async Task<ActionResult<DriverVehicleDto>> GetVehicle(int employeeId)
        => Ok(await _employeeService.GetDriverVehicleAsync(employeeId));

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<EmployeeDto>>> Search([FromQuery] string? search)
        => Ok(await _employeeService.SearchAsync(search));

    [HttpGet("{employeeId:int}")]
    public async Task<ActionResult<EmployeeDetailDto>> GetById(int employeeId)
    {
        var employee = await _employeeService.GetByIdAsync(employeeId);
        return employee is null ? NotFound() : Ok(employee);
    }

    [HttpPost]
    public async Task<ActionResult<EmployeeDto>> Create(CreateEmployeeRequest request)
    {
        try
        {
            var result = await _employeeService.CreateAsync(
                request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateEmployeeException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{employeeId:int}")]
    public async Task<ActionResult<EmployeeDto>> Update(int employeeId, UpdateEmployeeRequest request)
    {
        try
        {
            var result = await _employeeService.UpdateAsync(
                employeeId, request, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateEmployeeException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpDelete("{employeeId:int}")]
    public async Task<IActionResult> Delete(int employeeId)
    {
        var deleted = await _employeeService.DeleteAsync(
            employeeId, User.GetLocationId(), User.GetUserId(), User.GetEmployeeId());
        return deleted ? NoContent() : NotFound();
    }
}
