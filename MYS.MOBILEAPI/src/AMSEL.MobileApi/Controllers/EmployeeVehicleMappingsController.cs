using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/employee-vehicle-mappings")]
public class EmployeeVehicleMappingsController : ControllerBase
{
    private readonly IEmployeeVehicleMappingService _mappingService;

    public EmployeeVehicleMappingsController(IEmployeeVehicleMappingService mappingService)
    {
        _mappingService = mappingService;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<EmployeeVehicleMappingDto>>> Search([FromQuery] string? search)
        => Ok(await _mappingService.SearchAsync(search));

    [HttpGet("{mappingId:int}")]
    public async Task<ActionResult<EmployeeVehicleMappingDto>> GetById(int mappingId)
    {
        var mapping = await _mappingService.GetByIdAsync(mappingId);
        return mapping is null ? NotFound() : Ok(mapping);
    }

    [HttpPost]
    public async Task<ActionResult<EmployeeVehicleMappingDto>> Create(CreateEmployeeVehicleMappingRequest request)
    {
        try
        {
            var result = await _mappingService.CreateAsync(request, User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateVehicleMappingException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPut("{mappingId:int}")]
    public async Task<ActionResult<EmployeeVehicleMappingDto>> Update(int mappingId, UpdateEmployeeVehicleMappingRequest request)
    {
        try
        {
            var result = await _mappingService.UpdateAsync(mappingId, request, User.GetUserId(), User.GetEmployeeId());
            return Ok(result);
        }
        catch (DuplicateVehicleMappingException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpDelete("{mappingId:int}")]
    public async Task<IActionResult> Delete(int mappingId)
    {
        var deleted = await _mappingService.DeleteAsync(mappingId);
        return deleted ? NoContent() : NotFound();
    }
}
