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
        : base($"A site named \"{siteName}\" already exists in this area.") { }
}

/// <summary>
/// Site data now lives across two tables (see 026_site_customer_mapping_split.sql):
/// dbo.SITE is pure site master data (SiteName + AreaId only — City is
/// derived via AREAID -> AREA.CityId -> CITY.CITYID), owned by the "Site"
/// master (this file's Create/Update/Delete). dbo.SITE_MAPPING owns the
/// Site-to-Customer mapping exclusively, via AssignCustomerAsync — STATUS=1
/// marks the one currently-active mapping row per site, and
/// remapping/unmapping closes the old row (STATUS=0) rather than
/// overwriting it, so mapping history is kept.
///
/// Trip Entry picks the site first and derives the customer from the
/// active SITE_MAPPING row when one exists, falling back to a manual
/// customer picker when the site has none.
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
            SELECT TOP 50 S.SITEID AS SiteId, ISNULL(S.SITENAME, '') AS SiteName, ISNULL(A.AreaName, '') AS AreaName,
                   SM.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName, ISNULL(C.MOBILENO, '') AS MobileNo
            FROM SITE S
            LEFT JOIN AREA A ON A.AreaId = S.AREAID
            LEFT JOIN SITE_MAPPING SM ON SM.SITEID = S.SITEID AND SM.STATUS = 1
            LEFT JOIN CUSTOMER C ON C.CUSTOMERID = SM.CUSTOMERID AND C.STATUS = 1
            WHERE S.STATUS = 1
              AND (@CustomerId IS NULL OR SM.CUSTOMERID = @CustomerId)
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
            SELECT S.SITEID AS SiteId, ISNULL(S.SITENAME, '') AS SiteName,
                   S.AREAID AS AreaId, ISNULL(A.AreaName, '') AS AreaName,
                   A.CityId AS CityId, ISNULL(CI.CITYNAME, '') AS CityName,
                   SM.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName
            FROM SITE S
            LEFT JOIN AREA A ON A.AreaId = S.AREAID
            LEFT JOIN CITY CI ON CI.CITYID = A.CityId
            LEFT JOIN SITE_MAPPING SM ON SM.SITEID = S.SITEID AND SM.STATUS = 1
            LEFT JOIN CUSTOMER C ON C.CUSTOMERID = SM.CUSTOMERID AND C.STATUS = 1
            WHERE S.SITEID = @SiteId AND S.STATUS = 1
            """,
            new { SiteId = siteId });
    }

    private async Task<bool> NameExistsAsync(Microsoft.Data.SqlClient.SqlConnection connection, int areaId, string siteName, int? excludingSiteId, Microsoft.Data.SqlClient.SqlTransaction? transaction = null)
    {
        var count = await connection.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*) FROM SITE
            WHERE STATUS = 1 AND AREAID = @AreaId AND SITENAME = @SiteName
              AND (@ExcludingSiteId IS NULL OR SITEID <> @ExcludingSiteId)
            """,
            new { AreaId = areaId, SiteName = siteName, ExcludingSiteId = excludingSiteId },
            transaction);

        return count > 0;
    }

    public async Task<SiteDetailDto> CreateAsync(CreateSiteRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await NameExistsAsync(connection, request.AreaId, request.SiteName, null, transaction))
            throw new DuplicateSiteNameException(request.SiteName);

        var siteId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO SITE
                (SITENAME, AREAID, STATUS,
                 CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            OUTPUT INSERTED.SITEID
            VALUES
                (@SiteName, @AreaId, 1,
                 @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @EmployeeId, @EmployeeId)
            """,
            new
            {
                request.SiteName,
                request.AreaId,
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

        if (await NameExistsAsync(connection, request.AreaId, request.SiteName, siteId, transaction))
            throw new DuplicateSiteNameException(request.SiteName);

        await connection.ExecuteAsync(
            """
            UPDATE SITE
            SET SITENAME = @SiteName, AREAID = @AreaId,
                MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE SITEID = @SiteId AND STATUS = 1
            """,
            new
            {
                SiteId = siteId,
                request.SiteName,
                request.AreaId,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return (await GetByIdAsync(siteId))!;
    }

    /// <summary>
    /// Sets or clears (unmap, CustomerId = null) the Customer Site Mapping
    /// for an existing site. Closes the currently-active SITE_MAPPING row
    /// (if any) and, when a new CustomerId is given, inserts a fresh active
    /// row rather than updating in place — so past mappings stay as
    /// STATUS = 0 history instead of being overwritten.
    /// </summary>
    public async Task<SiteDetailDto?> AssignCustomerAsync(int siteId, AssignSiteCustomerRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        var siteExists = await connection.ExecuteScalarAsync<int>(
            "SELECT COUNT(*) FROM SITE WHERE SITEID = @SiteId AND STATUS = 1",
            new { SiteId = siteId },
            transaction);
        if (siteExists == 0)
        {
            transaction.Rollback();
            return null;
        }

        await connection.ExecuteAsync(
            """
            UPDATE SITE_MAPPING
            SET STATUS = 0, MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE SITEID = @SiteId AND STATUS = 1
            """,
            new { SiteId = siteId, LocationId = locationId, UserId = userId, EmployeeId = employeeId },
            transaction);

        if (request.CustomerId is not null)
        {
            await connection.ExecuteAsync(
                """
                INSERT INTO SITE_MAPPING
                    (SITEID, CUSTOMERID, STATUS,
                     CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                     USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
                VALUES
                    (@SiteId, @CustomerId, 1,
                     @LocationId, @LocationId, @UserId, @UserId,
                     GETDATE(), GETDATE(), @EmployeeId, @EmployeeId)
                """,
                new { SiteId = siteId, request.CustomerId, LocationId = locationId, UserId = userId, EmployeeId = employeeId },
                transaction);
        }

        transaction.Commit();

        return await GetByIdAsync(siteId);
    }

    /// <summary>Soft delete (STATUS=0) — matches CUSTOMER/PRODUCT's convention. Also closes any active mapping, since a deleted site shouldn't keep an active SITE_MAPPING row. Existing TRIPENTRY rows keep their own SITENAME snapshot, unaffected.</summary>
    public async Task<bool> DeleteAsync(int siteId, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        var rowsAffected = await connection.ExecuteAsync(
            """
            UPDATE SITE
            SET STATUS = 0, MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE SITEID = @SiteId AND STATUS = 1
            """,
            new { SiteId = siteId, LocationId = locationId, UserId = userId, EmployeeId = employeeId },
            transaction);

        if (rowsAffected > 0)
        {
            await connection.ExecuteAsync(
                """
                UPDATE SITE_MAPPING
                SET STATUS = 0, MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                    LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
                WHERE SITEID = @SiteId AND STATUS = 1
                """,
                new { SiteId = siteId, LocationId = locationId, UserId = userId, EmployeeId = employeeId },
                transaction);
        }

        transaction.Commit();

        return rowsAffected > 0;
    }
}
