using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

/// <summary>
/// Both endpoints resolve tenant by mobile number before touching
/// IOtpService, same reasoning as AuthController's username-based login —
/// there's no JWT yet for the tenant-resolution middleware to read.
/// </summary>
[ApiController]
[Route("api/otp")]
public class OtpController : ControllerBase
{
    private readonly IOtpService _otpService;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IRefreshTokenStore _refreshTokenStore;
    private readonly ITenantRegistry _tenantRegistry;
    private readonly ITenantContext _tenantContext;

    public OtpController(
        IOtpService otpService, IJwtTokenService jwtTokenService, IRefreshTokenStore refreshTokenStore,
        ITenantRegistry tenantRegistry, ITenantContext tenantContext)
    {
        _otpService = otpService;
        _jwtTokenService = jwtTokenService;
        _refreshTokenStore = refreshTokenStore;
        _tenantRegistry = tenantRegistry;
        _tenantContext = tenantContext;
    }

    [HttpPost("request")]
    public async Task<IActionResult> RequestOtp(OtpRequest request)
    {
        var tenant = await _tenantRegistry.FindByMobileNoAsync(request.MobileNo);
        if (tenant is null) return NotFound(new { message = "No account is registered with this mobile number." });
        _tenantContext.ConnectionString = tenant.ConnectionString;

        try
        {
            var sent = await _otpService.RequestOtpAsync(request.MobileNo);
            if (!sent) return NotFound(new { message = "No account is registered with this mobile number." });
            return Ok(new { message = "OTP sent." });
        }
        catch (SmsDeliveryException)
        {
            return StatusCode(StatusCodes.Status502BadGateway, new { message = "Could not send the OTP SMS. Please try again later." });
        }
    }

    [HttpPost("verify")]
    public async Task<ActionResult<AuthResponse>> Verify(OtpVerifyRequest request)
    {
        var tenant = await _tenantRegistry.FindByMobileNoAsync(request.MobileNo);
        if (tenant is null) return Unauthorized(new { message = "Invalid or expired OTP." });
        _tenantContext.ConnectionString = tenant.ConnectionString;

        var user = await _otpService.VerifyOtpAsync(request.MobileNo, request.Otp);
        if (user is null) return Unauthorized(new { message = "Invalid or expired OTP." });

        var (token, expiresAt) = _jwtTokenService.GenerateAccessToken(user, tenant.TenantCode);
        var refreshToken = await _refreshTokenStore.IssueAsync(user.UserId, request.DeviceId);

        return Ok(new AuthResponse(token, expiresAt, TenantPrefixedToken.Wrap(tenant.TenantCode, refreshToken), user.IsDriver));
    }
}
