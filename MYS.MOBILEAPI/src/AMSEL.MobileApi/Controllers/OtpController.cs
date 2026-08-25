using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Route("api/otp")]
public class OtpController : ControllerBase
{
    private readonly IOtpService _otpService;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IRefreshTokenStore _refreshTokenStore;

    public OtpController(IOtpService otpService, IJwtTokenService jwtTokenService, IRefreshTokenStore refreshTokenStore)
    {
        _otpService = otpService;
        _jwtTokenService = jwtTokenService;
        _refreshTokenStore = refreshTokenStore;
    }

    [HttpPost("request")]
    public async Task<IActionResult> RequestOtp(OtpRequest request)
    {
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
        var user = await _otpService.VerifyOtpAsync(request.MobileNo, request.Otp);
        if (user is null) return Unauthorized(new { message = "Invalid or expired OTP." });

        var (token, expiresAt) = _jwtTokenService.GenerateAccessToken(user);
        var refreshToken = await _refreshTokenStore.IssueAsync(user.UserId, request.DeviceId);

        return Ok(new AuthResponse(token, expiresAt, refreshToken, user.IsDriver));
    }
}
