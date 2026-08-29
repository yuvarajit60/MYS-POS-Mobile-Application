using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ISiteService
{
    Task<IReadOnlyList<SiteDto>> SearchAsync(string? search);
    Task<SiteDetailDto?> GetByIdAsync(int siteId);
    Task<SiteDetailDto> CreateAsync(CreateSiteRequest request, int locationId, int userId, int employeeId);
    Task<SiteDetailDto> UpdateAsync(int siteId, UpdateSiteRequest request, int locationId, int userId, int employeeId);
    Task<bool> DeleteAsync(int siteId, int locationId, int userId, int employeeId);
}

/// <summary>
/// Searched by site name (not scoped by customer) — Trip Entry picks the
/// site first, then derives the customer from SITE.CUSTOMERID, rather than
/// picking a customer first. Manage Sites (this file's CRUD half) is the
/// screen that actually maintains the site-to-customer mapping.
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

    public async Task<SiteDetailDto?> GetByIdAsync(int siteId)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<SiteDetailDto>(
            """
            SELECT S.SITEID AS SiteId, ISNULL(S.SITENAME, '') AS SiteName, ISNULL(S.AREANAME, '') AS AreaName,
                   S.CITYID AS CityId, ISNULL(CI.CITYNAME, '') AS CityName,
                   S.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName
            FROM SITE S
            LEFT JOIN CITY CI ON CI.CITYID = S.CITYID
            INNER JOIN CUSTOMER C ON C.CUSTOMERID = S.CUSTOMERID
            WHERE S.SITEID = @SiteId AND S.STATUS = 1
            """,
            new { SiteId = siteId });
    }

    public async Task<SiteDetailDto> CreateAsync(CreateSiteRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var siteId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO SITE
                (SITENAME, AREANAME, CITYID, STATUS, CUSTOMERID,
                 CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            OUTPUT INSERTED.SITEID
            VALUES
                (@SiteName, @AreaName, @CityId, 1, @CustomerId,
                 @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @EmployeeId, @EmployeeId)
            """,
            new
            {
                request.SiteName,
                request.AreaName,
                request.CityId,
                request.CustomerId,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            });

        return (await GetByIdAsync(siteId))!;
    }

    public async Task<SiteDetailDto> UpdateAsync(int siteId, UpdateSiteRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.ExecuteAsync(
            """
            UPDATE SITE
            SET SITENAME = @SiteName, AREANAME = @AreaName, CITYID = @CityId, CUSTOMERID = @CustomerId,
                MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE SITEID = @SiteId AND STATUS = 1
            """,
            new
            {
                SiteId = siteId,
                request.SiteName,
                request.AreaName,
                request.CityId,
                request.CustomerId,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            });

        return (await GetByIdAsync(siteId))!;
    }

    /// <summary>Soft delete (STATUS=0) — matches CUSTOMER/PRODUCT's convention; existing TRIPENTRY rows keep their own SITENAME snapshot, unaffected.</summary>
    public async Task<bool> DeleteAsync(int siteId, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rowsAffected = await connection.ExecuteAsync(
            """
            UPDATE SITE
            SET STATUS = 0, MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE SITEID = @SiteId AND STATUS = 1
            """,
            new { SiteId = siteId, LocationId = locationId, UserId = userId, EmployeeId = employeeId });

        return rowsAffected > 0;
    }
}
