using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Route("api/company")]
public class CompanyController : ControllerBase
{
    private readonly ICompanyService _companyService;

    public CompanyController(ICompanyService companyService)
    {
        _companyService = companyService;
    }

    // Anonymous: the company name/branding needs to display on the login
    // screen too, before any session exists. Not sensitive information.
    [HttpGet]
    [AllowAnonymous]
    public async Task<ActionResult<CompanyDto>> Get()
    {
        var company = await _companyService.GetAsync();
        return company is null ? NotFound() : Ok(company);
    }
}
