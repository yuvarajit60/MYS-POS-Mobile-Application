using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ICityService
{
    Task<IReadOnlyList<CityDto>> SearchAsync(string? search);
}

public class CityService : ICityService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public CityService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<CityDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<CityDto>(
            """
            SELECT TOP 50 CITYID AS CityId, CITYNAME AS CityName
            FROM CITY
            WHERE STATUS = 1
              AND (@Search IS NULL OR CITYNAME LIKE @Like)
            ORDER BY CITYNAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }
}
