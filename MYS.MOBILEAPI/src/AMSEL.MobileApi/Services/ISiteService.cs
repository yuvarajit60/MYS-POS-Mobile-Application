using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ISiteService
{
    Task<IReadOnlyList<SiteDto>> SearchAsync(string? search);
}

/// <summary>
/// Searched by site name (not scoped by customer) — Trip Entry picks the
/// site first, then derives the customer from SITE.CUSTOMERID, rather than
/// picking a customer first.
/// </summary>
public class SiteService : ISiteService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public SiteService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<SiteDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<SiteDto>(
            """
            SELECT TOP 50 S.SITEID AS SiteId, ISNULL(S.SITENAME, '') AS SiteName, ISNULL(S.AREANAME, '') AS AreaName,
                   S.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName, ISNULL(C.MOBILENO, '') AS MobileNo
            FROM SITE S
            INNER JOIN CUSTOMER C ON C.CUSTOMERID = S.CUSTOMERID
            WHERE S.STATUS = 1 AND C.STATUS = 1
              AND (@Search IS NULL OR S.SITENAME LIKE @Like)
            ORDER BY S.SITENAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }
}
