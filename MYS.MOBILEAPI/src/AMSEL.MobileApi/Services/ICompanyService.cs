using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ICompanyService
{
    Task<CompanyDto?> GetAsync();
}

/// <summary>Single-company setup — returns the one active COMPANY row.</summary>
public class CompanyService : ICompanyService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public CompanyService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<CompanyDto?> GetAsync()
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<CompanyDto>(
            """
            SELECT TOP 1
                   COMPANYNAME AS CompanyName,
                   ISNULL(ADDRESS, '') AS Address,
                   ISNULL(GSTIN, '') AS GstIn,
                   ISNULL(PHONENO, '') AS PhoneNo,
                   ISNULL(MOBILENO, '') AS MobileNo,
                   ISNULL(EMAILID, '') AS EmailId
            FROM COMPANY
            WHERE STATUS = 1
            ORDER BY COMPANYID
            """);
    }
}
