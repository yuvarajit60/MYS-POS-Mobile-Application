using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IBrandService
{
    Task<IReadOnlyList<BrandDto>> SearchAsync(string? search);
}

public class BrandService : IBrandService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public BrandService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<BrandDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<BrandDto>(
            """
            SELECT TOP 50 BRANDID AS BrandId, BRANDNAME AS BrandName
            FROM BRAND
            WHERE STATUS = 1
              AND (@Search IS NULL OR BRANDNAME LIKE @Like)
            ORDER BY BRANDNAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }
}
