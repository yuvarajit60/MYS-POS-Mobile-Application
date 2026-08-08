using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ITypeService
{
    Task<IReadOnlyList<TypeDto>> SearchAsync(string? search);
}

public class TypeService : ITypeService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public TypeService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<TypeDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<TypeDto>(
            """
            SELECT TOP 50 TYPEID AS TypeId, TYPENAME AS TypeName
            FROM TYPE
            WHERE STATUS = 1
              AND (@Search IS NULL OR TYPENAME LIKE @Like)
            ORDER BY TYPENAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }
}
