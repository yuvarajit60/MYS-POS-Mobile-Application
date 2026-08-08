using System.Security.Cryptography;
using AMSEL.MobileApi.Data;
using Dapper;

namespace AMSEL.MobileApi.Auth;

public interface IRefreshTokenStore
{
    Task<string> IssueAsync(int userId, string deviceId);

    /// <summary>Validates a presented refresh token and rotates it. UserId is null if invalid/expired/revoked.</summary>
    Task<(int? UserId, string? NewToken)> ValidateAndRotateAsync(string presentedToken, string deviceId);
}

public class RefreshTokenStore : IRefreshTokenStore
{
    private readonly ISqlConnectionFactory _connectionFactory;
    private readonly IConfiguration _configuration;

    public RefreshTokenStore(ISqlConnectionFactory connectionFactory, IConfiguration configuration)
    {
        _connectionFactory = connectionFactory;
        _configuration = configuration;
    }

    public async Task<string> IssueAsync(int userId, string deviceId)
    {
        var rawToken = GenerateRawToken();
        var days = _configuration.GetValue("Jwt:RefreshTokenDays", 60);

        using var connection = _connectionFactory.CreateConnection();
        await connection.ExecuteAsync(
            """
            INSERT INTO dbo.MOBILE_REFRESH_TOKENS (USERID, DEVICEID, TOKENHASH, ISSUEDAT, EXPIRESAT)
            VALUES (@UserId, @DeviceId, @TokenHash, GETDATE(), DATEADD(DAY, @Days, GETDATE()))
            """,
            new { UserId = userId, DeviceId = deviceId, TokenHash = Hash(rawToken), Days = days });

        return rawToken;
    }

    public async Task<(int? UserId, string? NewToken)> ValidateAndRotateAsync(string presentedToken, string deviceId)
    {
        var tokenHash = Hash(presentedToken);

        using var connection = _connectionFactory.CreateConnection();
        var userId = await connection.QuerySingleOrDefaultAsync<int?>(
            """
            SELECT USERID FROM dbo.MOBILE_REFRESH_TOKENS
            WHERE TOKENHASH = @TokenHash AND DEVICEID = @DeviceId
              AND REVOKEDAT IS NULL AND EXPIRESAT > GETDATE()
            """,
            new { TokenHash = tokenHash, DeviceId = deviceId });

        if (userId is null) return (null, null);

        await connection.ExecuteAsync(
            "UPDATE dbo.MOBILE_REFRESH_TOKENS SET REVOKEDAT = GETDATE() WHERE TOKENHASH = @TokenHash",
            new { TokenHash = tokenHash });

        var newToken = await IssueAsync(userId.Value, deviceId);
        return (userId, newToken);
    }

    private static string GenerateRawToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));

    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(value)));
}
