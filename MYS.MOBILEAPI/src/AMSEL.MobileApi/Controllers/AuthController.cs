using AMSEL.MobileApi.Auth;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using AMSEL.MobileApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace AMSEL.MobileApi.Controllers;

/// <summary>
/// Login/refresh both run before any JWT exists, so each resolves its own
/// tenant directly from ITenantRegistry (by username, or — for refresh —
/// from a tenant code prefix baked into the refresh token itself, since
/// there's no directory lookup available once the access token has
/// expired and only the opaque refresh token remains) and sets
/// ITenantContext itself, rather than relying on the tenant-resolution
/// middleware (which only has a JWT's "tenant" claim to work from).
/// </summary>
[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IRefreshTokenStore _refreshTokenStore;
    private readonly ITenantRegistry _tenantRegistry;
    private readonly ITenantContext _tenantContext;

    public AuthController(
        IAuthService authService, IJwtTokenService jwtTokenService, IRefreshTokenStore refreshTokenStore,
        ITenantRegistry tenantRegistry, ITenantContext tenantContext)
    {
        _authService = authService;
        _jwtTokenService = jwtTokenService;
        _refreshTokenStore = refreshTokenStore;
        _tenantRegistry = tenantRegistry;
        _tenantContext = tenantContext;
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request)
    {
        var tenant = await _tenantRegistry.FindByUsernameAsync(request.Username);
        if (tenant is null) return Unauthorized(new { message = "Invalid username or password." });
        _tenantContext.ConnectionString = tenant.ConnectionString;

        var user = await _authService.ValidatePasswordAsync(request.Username, request.Password);
        if (user is null) return Unauthorized(new { message = "Invalid username or password." });

        var (token, expiresAt) = _jwtTokenService.GenerateAccessToken(user, tenant.TenantCode);
        var refreshToken = await _refreshTokenStore.IssueAsync(user.UserId, request.DeviceId);

        return Ok(new AuthResponse(token, expiresAt, TenantPrefixedToken.Wrap(tenant.TenantCode, refreshToken), user.IsDriver));
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshRequest request)
    {
        if (!TenantPrefixedToken.TryUnwrap(request.RefreshToken, out var tenantCode, out var rawToken))
            return Unauthorized(new { message = "Refresh token is invalid or expired." });

        var tenant = await _tenantRegistry.GetByCodeAsync(tenantCode);
        if (tenant is null) return Unauthorized(new { message = "Refresh token is invalid or expired." });
        _tenantContext.ConnectionString = tenant.ConnectionString;

        var (userId, newToken) = await _refreshTokenStore.ValidateAndRotateAsync(rawToken, request.DeviceId);
        if (userId is null || newToken is null) return Unauthorized(new { message = "Refresh token is invalid or expired." });

        var user = await _authService.FindByIdAsync(userId.Value);
        if (user is null) return Unauthorized();

        var (token, expiresAt) = _jwtTokenService.GenerateAccessToken(user, tenant.TenantCode);
        return Ok(new AuthResponse(token, expiresAt, TenantPrefixedToken.Wrap(tenant.TenantCode, newToken), user.IsDriver));
    }
}
