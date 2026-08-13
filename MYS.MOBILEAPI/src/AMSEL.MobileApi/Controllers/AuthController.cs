using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IRefreshTokenStore _refreshTokenStore;

    public AuthController(IAuthService authService, IJwtTokenService jwtTokenService, IRefreshTokenStore refreshTokenStore)
    {
        _authService = authService;
        _jwtTokenService = jwtTokenService;
        _refreshTokenStore = refreshTokenStore;
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request)
    {
        var user = await _authService.ValidatePasswordAsync(request.Username, request.Password);
        if (user is null) return Unauthorized(new { message = "Invalid username or password." });

        var (token, expiresAt) = _jwtTokenService.GenerateAccessToken(user);
        var refreshToken = await _refreshTokenStore.IssueAsync(user.UserId, request.DeviceId);

        return Ok(new AuthResponse(token, expiresAt, refreshToken));
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshRequest request)
    {
        var (userId, newToken) = await _refreshTokenStore.ValidateAndRotateAsync(request.RefreshToken, request.DeviceId);
        if (userId is null || newToken is null) return Unauthorized(new { message = "Refresh token is invalid or expired." });

        var user = await _authService.FindByIdAsync(userId.Value);
        if (user is null) return Unauthorized();

        var (token, expiresAt) = _jwtTokenService.GenerateAccessToken(user);
        return Ok(new AuthResponse(token, expiresAt, newToken));
    }
}
