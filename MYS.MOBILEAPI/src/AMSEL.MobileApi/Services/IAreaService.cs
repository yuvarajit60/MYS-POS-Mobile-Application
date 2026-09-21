using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IAreaService
{
    Task<IReadOnlyList<AreaDto>> SearchAsync(string? search, int? cityId);
    Task<AreaDto> CreateAsync(CreateAreaRequest request, string username);
    Task<AreaDto> UpdateAsync(int areaId, UpdateAreaRequest request, string username);
    Task<bool> DeleteAsync(int areaId, string username);
}

public class DuplicateAreaNameException : Exception
{
    public DuplicateAreaNameException(string areaName)
        : base($"An area named \"{areaName}\" already exists for this city.") { }
}

/// <summary>
/// dbo.AREA already existed by hand on db_ams_pos_test with real data and
/// its own PascalCase schema (AreaId/AreaName/CityId/IsActive/CreatedOn/
/// CreatedBy/UpdatedOn/UpdatedBy) — not this project's usual ALLCAPS
/// legacy-desktop convention — see 022_area_master.sql for the full
/// story. This service matches that shape exactly. CreatedBy/UpdatedBy
/// store the acting user's username (string), not a numeric ID.
/// </summary>
public class AreaService : IAreaService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public AreaService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<AreaDto>> SearchAsync(string? search, int? cityId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<AreaDto>(
            """
            SELECT TOP 50 A.AreaId AS AreaId, A.AreaName AS AreaName, A.CityId AS CityId, ISNULL(C.CITYNAME, '') AS CityName
            FROM AREA A
            LEFT JOIN CITY C ON C.CITYID = A.CityId
            WHERE A.IsActive = 1
              AND (@CityId IS NULL OR A.CityId = @CityId)
              AND (@Search IS NULL OR A.AreaName LIKE @Like)
            ORDER BY A.AreaName
            """,
            new { Search = search, Like = like, CityId = cityId });

        return rows.ToList();
    }

    private async Task<bool> NameExistsAsync(Microsoft.Data.SqlClient.SqlConnection connection, int cityId, string areaName, int? excludingAreaId, Microsoft.Data.SqlClient.SqlTransaction? transaction = null)
    {
        var count = await connection.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*) FROM AREA
            WHERE IsActive = 1 AND CityId = @CityId AND AreaName = @AreaName
              AND (@ExcludingAreaId IS NULL OR AreaId <> @ExcludingAreaId)
            """,
            new { CityId = cityId, AreaName = areaName, ExcludingAreaId = excludingAreaId },
            transaction);

        return count > 0;
    }

    public async Task<AreaDto> CreateAsync(CreateAreaRequest request, string username)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await NameExistsAsync(connection, request.CityId, request.AreaName, null, transaction))
            throw new DuplicateAreaNameException(request.AreaName);

        var areaId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO AREA (AreaName, CityId, IsActive, CreatedOn, CreatedBy, UpdatedOn, UpdatedBy)
            OUTPUT INSERTED.AreaId
            VALUES (@AreaName, @CityId, 1, SYSDATETIME(), @Username, SYSDATETIME(), @Username)
            """,
            new { request.AreaName, request.CityId, Username = username },
            transaction);

        transaction.Commit();

        return await GetByIdAsync(areaId);
    }

    public async Task<AreaDto> UpdateAsync(int areaId, UpdateAreaRequest request, string username)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await NameExistsAsync(connection, request.CityId, request.AreaName, areaId, transaction))
            throw new DuplicateAreaNameException(request.AreaName);

        await connection.ExecuteAsync(
            """
            UPDATE AREA
            SET AreaName = @AreaName, CityId = @CityId, UpdatedOn = SYSDATETIME(), UpdatedBy = @Username
            WHERE AreaId = @AreaId AND IsActive = 1
            """,
            new { AreaId = areaId, request.AreaName, request.CityId, Username = username },
            transaction);

        transaction.Commit();

        return await GetByIdAsync(areaId);
    }

    /// <summary>Soft delete (IsActive=0) — matches CUSTOMER/SITE's convention; existing SITE rows keep their own AreaName snapshot, unaffected.</summary>
    public async Task<bool> DeleteAsync(int areaId, string username)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rowsAffected = await connection.ExecuteAsync(
            """
            UPDATE AREA
            SET IsActive = 0, UpdatedOn = SYSDATETIME(), UpdatedBy = @Username
            WHERE AreaId = @AreaId AND IsActive = 1
            """,
            new { AreaId = areaId, Username = username });

        return rowsAffected > 0;
    }

    private async Task<AreaDto> GetByIdAsync(int areaId)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QuerySingleAsync<AreaDto>(
            """
            SELECT A.AreaId AS AreaId, A.AreaName AS AreaName, A.CityId AS CityId, ISNULL(C.CITYNAME, '') AS CityName
            FROM AREA A
            LEFT JOIN CITY C ON C.CITYID = A.CityId
            WHERE A.AreaId = @AreaId
            """,
            new { AreaId = areaId });
    }
}
