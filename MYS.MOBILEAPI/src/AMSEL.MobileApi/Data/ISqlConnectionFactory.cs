using Microsoft.Data.SqlClient;

namespace AMSEL.MobileApi.Data;

public interface ISqlConnectionFactory
{
    SqlConnection CreateConnection();
}

public class SqlConnectionFactory : ISqlConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("MobileApiDb")
            ?? throw new InvalidOperationException("Connection string 'MobileApiDb' is not configured.");
    }

    public SqlConnection CreateConnection() => new(_connectionString);
}
