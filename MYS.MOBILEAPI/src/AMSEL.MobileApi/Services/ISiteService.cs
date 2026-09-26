using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ISiteService
{
    Task<IReadOnlyList<SiteDto>> SearchAsync(string? search, int? customerId = null);
    Task<SiteDetailDto?> GetByIdAsync(int siteId);
    Task<SiteDetailDto> CreateAsync(CreateSiteRequest request, int locationId, int userId, int employeeId);
    Task<SiteDetailDto> UpdateAsync(int siteId, UpdateSiteRequest request, int locationId, int userId, int employeeId);
    Task<SiteDetailDto?> AssignCustomerAsync(int siteId, AssignSiteCustomerRequest request, int locationId, int userId, int employeeId);
    Task<bool> DeleteAsync(int siteId, int locationId, int userId, int employeeId);
}

public class DuplicateSiteNameException : Exception
{
    public DuplicateSiteNameException(string siteName)
        : base($"A site named \"{siteName}\" already exists in this city.") { }
}

/// <summary>
/// SITE is shared by two masters: the "Site" master (this file's Create/
/// Update/Delete) owns SiteName/Area/City only and never sets CustomerId —
/// new sites are always created unmapped. "Customer Site Mapping" owns the
/// SITE.CUSTOMERID column exclusively, via AssignCustomerAsync, and never
/// touches Name/Area/City. CustomerId is nullable (a site can exist before
/// anyone maps it to a customer), so Search/GetById LEFT JOIN CUSTOMER.
/// Trip Entry picks the site first and derives the customer from
/// SITE.CUSTOMERID when present, falling back to a manual customer picker
/// when the site has no mapping.
/// </summary>
public class SiteService : ISiteService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public SiteService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<SiteDto>> SearchAsync(string? search, int? customerId = null)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<SiteDto>(
            """
            SELECT TOP 50 S.SITEID AS SiteId, ISNULL(S.SITENAME, '') AS SiteName, ISNULL(S.AREANAME, '') AS AreaName,
                   S.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName, ISNULL(C.MOBILENO, '') AS MobileNo
            FROM SITE S
            LEFT JOIN CUSTOMER C ON C.CUSTOMERID = S.CUSTOMERID AND C.STATUS = 1
            WHERE S.STATUS = 1
              AND (@CustomerId IS NULL OR S.CUSTOMERID = @CustomerId)
              AND (@Search IS NULL OR S.SITENAME LIKE @Like)
            ORDER BY S.SITENAME
            """,
            new { Search = search, Like = like, CustomerId = customerId });

        return rows.ToList();
    }

    public async Task<SiteDetailDto?> GetByIdAsync(int siteId)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<SiteDetailDto>(
            """
            SELECT S.SITEID AS SiteId, ISNULL(S.SITENAME, '') AS SiteName, ISNULL(S.AREANAME, '') AS AreaName,
                   S.AREAID AS AreaId, S.CITYID AS CityId, ISNULL(CI.CITYNAME, '') AS CityName,
                   S.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName
            FROM SITE S
            LEFT JOIN CITY CI ON CI.CITYID = S.CITYID
            LEFT JOIN CUSTOMER C ON C.CUSTOMERID = S.CUSTOMERID AND C.STATUS = 1
            WHERE S.SITEID = @SiteId AND S.STATUS = 1
            """,
            new { SiteId = siteId });
    }

    private async Task<bool> NameExistsAsync(Microsoft.Data.SqlClient.SqlConnection connection, int cityId, string siteName, int? excludingSiteId, Microsoft.Data.SqlClient.SqlTransaction? transaction = null)
    {
        var count = await connection.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*) FROM SITE
            WHERE STATUS = 1 AND CITYID = @CityId AND SITENAME = @SiteName
              AND (@ExcludingSiteId IS NULL OR SITEID <> @ExcludingSiteId)
            """,
            new { CityId = cityId, SiteName = siteName, ExcludingSiteId = excludingSiteId },
            transaction);

        return count > 0;
    }

    public async Task<SiteDetailDto> CreateAsync(CreateSiteRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await NameExistsAsync(connection, request.CityId, request.SiteName, null, transaction))
            throw new DuplicateSiteNameException(request.SiteName);

        var siteId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO SITE
                (SITENAME, AREANAME, AREAID, CITYID, STATUS, CUSTOMERID,
                 CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            OUTPUT INSERTED.SITEID
            VALUES
                (@SiteName, @AreaName, @AreaId, @CityId, 1, NULL,
                 @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @EmployeeId, @EmployeeId)
            """,
            new
            {
                request.SiteName,
                request.AreaName,
                request.AreaId,
                request.CityId,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return (await GetByIdAsync(siteId))!;
    }

    public async Task<SiteDetailDto> UpdateAsync(int siteId, UpdateSiteRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await NameExistsAsync(connection, request.CityId, request.SiteName, siteId, transaction))
            throw new DuplicateSiteNameException(request.SiteName);

        await connection.ExecuteAsync(
            """
            UPDATE SITE
            SET SITENAME = @SiteName, AREANAME = @AreaName, AREAID = @AreaId, CITYID = @CityId,
                MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE SITEID = @SiteId AND STATUS = 1
            """,
            new
            {
                SiteId = siteId,
                request.SiteName,
                request.AreaName,
                request.AreaId,
                request.CityId,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return (await GetByIdAsync(siteId))!;
    }

    /// <summary>Sets or clears (unmap, CustomerId = null) the Customer Site Mapping for an existing site. Never touches SiteName/Area/City.</summary>
    public async Task<SiteDetailDto?> AssignCustomerAsync(int siteId, AssignSiteCustomerRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rowsAffected = await connection.ExecuteAsync(
            """
            UPDATE SITE
            SET CUSTOMERID = @CustomerId,
                MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE SITEID = @SiteId AND STATUS = 1
            """,
            new { SiteId = siteId, request.CustomerId, LocationId = locationId, UserId = userId, EmployeeId = employeeId });

        if (rowsAffected == 0) return null;

        return await GetByIdAsync(siteId);
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
