using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/change-date")]
public class ChangeDateController : ControllerBase
{
    private readonly IChangeDateService _changeDateService;

    public ChangeDateController(IChangeDateService changeDateService)
    {
        _changeDateService = changeDateService;
    }

    [HttpGet]
    public async Task<ActionResult<ChangeDateDto>> Get() => Ok(await _changeDateService.GetAsync());
}
