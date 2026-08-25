using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using AMSEL.MobileApi.Data.Dto;
using Microsoft.IdentityModel.Tokens;

namespace AMSEL.MobileApi.Auth;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAt) GenerateAccessToken(AuthenticatedUser user);
}

public class JwtTokenService : IJwtTokenService
{
    private readonly IConfiguration _configuration;

    public JwtTokenService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public (string Token, DateTime ExpiresAt) GenerateAccessToken(AuthenticatedUser user)
    {
        var signingKey = _configuration["Jwt:SigningKey"]
            ?? throw new InvalidOperationException("Jwt:SigningKey is not configured.");
        var issuer = _configuration["Jwt:Issuer"];
        var audience = _configuration["Jwt:Audience"];
        var minutes = _configuration.GetValue("Jwt:AccessTokenMinutes", 45);

        var expiresAt = DateTime.UtcNow.AddMinutes(minutes);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.UserId.ToString()),
            new("username", user.UserName),
            new("locationId", user.LocationId.ToString()),
            new("employeeId", user.EmployeeId.ToString()),
            new("branchId", user.BranchId.ToString()),
            new("isDriver", user.IsDriver ? "1" : "0"),
        };

        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(signingKey)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: expiresAt,
            signingCredentials: credentials);

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }
}
