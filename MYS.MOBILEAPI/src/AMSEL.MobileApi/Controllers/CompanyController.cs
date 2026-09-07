using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Authorize]
[Route("api/company")]
public class CompanyController : ControllerBase
{
    private readonly ICompanyService _companyService;

    public CompanyController(ICompanyService companyService)
    {
        _companyService = companyService;
    }

    // Requires auth (unlike before multi-tenancy) — which tenant's company
    // to show can't be known for an anonymous pre-login request, so this
    // now resolves the same way every other endpoint does: the tenant-
    // resolution middleware reads it off the JWT's "tenant" claim. The
    // login screen's app bar just shows the generic fallback title until
    // the user is actually signed in — see CompanyProvider's doc comment.
    [HttpGet]
    public async Task<ActionResult<CompanyDto>> Get()
    {
        var company = await _companyService.GetAsync();
        return company is null ? NotFound() : Ok(company);
    }
}
