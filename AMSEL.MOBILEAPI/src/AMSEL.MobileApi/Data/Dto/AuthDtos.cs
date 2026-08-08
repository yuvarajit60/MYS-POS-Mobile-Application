namespace AMSEL.MobileApi.Data.Dto;

public record LoginRequest(string Username, string Password, string DeviceId);

public record OtpRequest(string MobileNo);

public record OtpVerifyRequest(string MobileNo, string Otp, string DeviceId);

public record RefreshRequest(string RefreshToken, string DeviceId);

public record AuthResponse(string AccessToken, DateTime AccessTokenExpiresAt, string RefreshToken);

public record AuthenticatedUser(
    int UserId,
    string UserName,
    int LocationId,
    int EmployeeId,
    string EmployeeName,
    int BranchId,
    string? MobileNo);
