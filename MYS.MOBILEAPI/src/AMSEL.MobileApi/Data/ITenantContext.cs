namespace AMSEL.MobileApi.Data;

/// <summary>
/// Holds the resolved tenant connection string for the current HTTP request
/// (registered Scoped, so one instance per request). Something must set
/// this before any <see cref="ISqlConnectionFactory"/> call happens:
/// the tenant-resolution middleware does it for already-authenticated
/// requests (from the JWT's "tenant" claim), while login/refresh/OTP
/// endpoints set it themselves after resolving the tenant from
/// <see cref="ITenantRegistry"/> directly (they run before a JWT exists).
/// </summary>
public interface ITenantContext
{
    string? ConnectionString { get; set; }
    string? TenantCode { get; set; }
}

public class TenantContext : ITenantContext
{
    public string? ConnectionString { get; set; }
    public string? TenantCode { get; set; }
}
