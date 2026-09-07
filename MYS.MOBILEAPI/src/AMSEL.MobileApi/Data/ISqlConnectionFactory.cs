using Microsoft.Data.SqlClient;

namespace AMSEL.MobileApi.Data;

public interface ISqlConnectionFactory
{
    SqlConnection CreateConnection();
}

/// <summary>
/// Every connection now goes to whichever tenant's database was resolved
/// for this request (see ITenantContext) — there is no single fixed
/// "MobileApiDb" anymore. Registered Scoped (not Singleton) since it
/// depends on the per-request ITenantContext.
/// </summary>
public class SqlConnectionFactory : ISqlConnectionFactory
{
    private readonly ITenantContext _tenantContext;

    public SqlConnectionFactory(ITenantContext tenantContext)
    {
        _tenantContext = tenantContext;
    }

    public SqlConnection CreateConnection()
    {
        var connectionString = _tenantContext.ConnectionString
            ?? throw new InvalidOperationException("No tenant has been resolved for this request yet.");
        return new SqlConnection(connectionString);
    }
}
