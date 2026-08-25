using System.Security.Cryptography;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IOtpService
{
    /// <summary>Looks up the user registered against this mobile number and sends an OTP there. Returns false if no user has this mobile number on file.</summary>
    Task<bool> RequestOtpAsync(string mobileNo);

    /// <summary>Validates a submitted OTP against the same mobile number. Returns the user on success, null on failure.</summary>
    Task<AuthenticatedUser?> VerifyOtpAsync(string mobileNo, string otp);
}

public class SmsDeliveryException : Exception
{
    public SmsDeliveryException(string message, Exception inner) : base(message, inner) { }
}

public class OtpService : IOtpService
{
    private static readonly TimeSpan OtpLifetime = TimeSpan.FromMinutes(5);

    private readonly IAuthService _authService;
    private readonly ISqlConnectionFactory _connectionFactory;
    private readonly ISmsGateway _smsGateway;

    public OtpService(IAuthService authService, ISqlConnectionFactory connectionFactory, ISmsGateway smsGateway)
    {
        _authService = authService;
        _connectionFactory = connectionFactory;
        _smsGateway = smsGateway;
    }

    public async Task<bool> RequestOtpAsync(string mobileNo)
    {
        var user = await _authService.FindByMobileNoAsync(mobileNo);
        if (user is null) return false;

        var otp = RandomNumberGenerator.GetInt32(100000, 999999).ToString();

        using var connection = _connectionFactory.CreateConnection();
        await connection.ExecuteAsync(
            """
            INSERT INTO dbo.MOBILE_OTP (USERID, OTP, MOBILENO, EXPIRESAT)
            VALUES (@UserId, @Otp, @MobileNo, DATEADD(MINUTE, @Minutes, GETDATE()))
            """,
            new { UserId = user.UserId, Otp = otp, MobileNo = mobileNo, Minutes = OtpLifetime.TotalMinutes });

        try
        {
            await _smsGateway.SendAsync(mobileNo, $"Your MYS mobile app verification code is {otp}. Valid for 5 minutes.");
        }
        catch (Exception ex)
        {
            // The OTP row is already saved (verify still works if the code reaches the user
            // some other way); surface delivery failure distinctly so the controller can
            // return a clean 502 instead of leaking transport details to the client.
            throw new SmsDeliveryException("Failed to send the OTP SMS.", ex);
        }

        return true;
    }

    public async Task<AuthenticatedUser?> VerifyOtpAsync(string mobileNo, string otp)
    {
        var user = await _authService.FindByMobileNoAsync(mobileNo);
        if (user is null) return null;

        using var connection = _connectionFactory.CreateConnection();
        var otpId = await connection.QuerySingleOrDefaultAsync<int?>(
            """
            SELECT TOP 1 OTPID FROM dbo.MOBILE_OTP
            WHERE USERID = @UserId AND MOBILENO = @MobileNo AND OTP = @Otp AND CONSUMED = 0 AND EXPIRESAT > GETDATE()
            ORDER BY OTPID DESC
            """,
            new { UserId = user.UserId, MobileNo = mobileNo, Otp = otp });

        if (otpId is null) return null;

        await connection.ExecuteAsync(
            "UPDATE dbo.MOBILE_OTP SET CONSUMED = 1 WHERE OTPID = @OtpId",
            new { OtpId = otpId });

        return user;
    }
}
