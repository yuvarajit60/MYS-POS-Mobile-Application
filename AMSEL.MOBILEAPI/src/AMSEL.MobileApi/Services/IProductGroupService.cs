using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IProductGroupService
{
    Task<IReadOnlyList<ProductGroupDto>> SearchAsync(string? search);
}

public class ProductGroupService : IProductGroupService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public ProductGroupService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<ProductGroupDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<ProductGroupDto>(
            """
            SELECT TOP 50 PRODUCTGROUPID AS ProductGroupId, PRODUCTGROUPNAME AS ProductGroupName
            FROM PRODUCTGROUP
            WHERE STATUS = 1
              AND (@Search IS NULL OR PRODUCTGROUPNAME LIKE @Like)
            ORDER BY PRODUCTGROUPNAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }
}
