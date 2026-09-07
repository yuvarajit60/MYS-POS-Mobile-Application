using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Caching.Memory;

namespace AMSEL.MobileApi.Auth;

public record TenantInfo(string TenantCode, string TenantName, string ConnectionString);

public interface ITenantRegistry
{
    Task<TenantInfo?> FindByUsernameAsync(string username);
    Task<TenantInfo?> FindByMobileNoAsync(string mobileNo);
    Task<TenantInfo?> GetByCodeAsync(string tenantCode);
}

/// <summary>
/// Resolves which tenant (and therefore which real database) a mobile
/// login belongs to, by reading a small directory kept in its own
/// dedicated control-plane database (MYS_MOBILE_CONTROL — see
/// db/011_tenant_directory.sql), separate from every tenant's own data.
/// This is the ONE thing in the app still backed by a single fixed
/// connection string (ConnectionStrings:ControlDb) — everything else
/// goes through the per-request tenant resolved here.
///
/// The whole directory is tiny (a handful of rows per tenant) and changes
/// only when a customer is onboarded/offboarded, so it's cached in memory
/// rather than re-querying the control DB on every request.
/// </summary>
public class TenantRegistry : ITenantRegistry
{
    private const string CacheKey = "tenant-directory";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    private readonly string _controlConnectionString;
    private readonly IMemoryCache _cache;

    public TenantRegistry(IConfiguration configuration, IMemoryCache cache)
    {
        _controlConnectionString = configuration.GetConnectionString("ControlDb")
            ?? throw new InvalidOperationException("Connection string 'ControlDb' is not configured.");
        _cache = cache;
    }

    public async Task<TenantInfo?> FindByUsernameAsync(string username)
    {
        var rows = await GetDirectoryAsync();
        var row = rows.FirstOrDefault(r => string.Equals(r.Username, username, StringComparison.OrdinalIgnoreCase));
        return row is null ? null : new TenantInfo(row.TenantCode, row.TenantName, row.ConnectionString);
    }

    public async Task<TenantInfo?> FindByMobileNoAsync(string mobileNo)
    {
        var rows = await GetDirectoryAsync();
        var row = rows.FirstOrDefault(r => r.MobileNo == mobileNo);
        return row is null ? null : new TenantInfo(row.TenantCode, row.TenantName, row.ConnectionString);
    }

    public async Task<TenantInfo?> GetByCodeAsync(string tenantCode)
    {
        var rows = await GetDirectoryAsync();
        var row = rows.FirstOrDefault(r => string.Equals(r.TenantCode, tenantCode, StringComparison.OrdinalIgnoreCase));
        return row is null ? null : new TenantInfo(row.TenantCode, row.TenantName, row.ConnectionString);
    }

    private async Task<List<DirectoryRow>> GetDirectoryAsync()
    {
        var cached = await _cache.GetOrCreateAsync(CacheKey, async entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = CacheDuration;

            using var connection = new SqlConnection(_controlConnectionString);
            var rows = await connection.QueryAsync<DirectoryRow>(
                """
                SELECT D.USERNAME AS Username, D.MOBILENO AS MobileNo, D.TENANTCODE AS TenantCode,
                       T.TENANTNAME AS TenantName, T.CONNECTIONSTRING AS ConnectionString
                FROM dbo.MOBILE_USER_DIRECTORY D
                INNER JOIN dbo.TENANTS T ON T.TENANTCODE = D.TENANTCODE
                WHERE D.STATUS = 1 AND T.STATUS = 1
                """);
            return rows.ToList();
        });

        return cached ?? [];
    }

    private record DirectoryRow(string Username, string? MobileNo, string TenantCode, string TenantName, string ConnectionString);
}
