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
}
