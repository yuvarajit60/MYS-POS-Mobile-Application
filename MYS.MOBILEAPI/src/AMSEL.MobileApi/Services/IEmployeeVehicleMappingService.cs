using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IEmployeeVehicleMappingService
{
    Task<IReadOnlyList<EmployeeVehicleMappingDto>> SearchAsync(string? search);
    Task<EmployeeVehicleMappingDto?> GetByIdAsync(int mappingId);
    Task<EmployeeVehicleMappingDto> CreateAsync(CreateEmployeeVehicleMappingRequest request, int userId, int employeeId);
    Task<EmployeeVehicleMappingDto> UpdateAsync(int mappingId, UpdateEmployeeVehicleMappingRequest request, int userId, int employeeId);
    Task<bool> DeleteAsync(int mappingId);
}

public class DuplicateVehicleMappingException : Exception
{
    public DuplicateVehicleMappingException()
        : base("This driver is already mapped to this vehicle for an overlapping period.") { }
}

/// <summary>
/// EMPLOYEE_VEHICLE_MAPPING stores EMPLOYEEID/VEHICLEID as VARCHAR (legacy
/// column typing, not something introduced here) — cast to/from INT at the
/// SQL boundary. No STATUS column exists on this table (unlike CUSTOMER/
/// PRODUCT/SITE), so Delete here is a genuine hard delete rather than a
/// soft one — safe because TRIPENTRY_DETAILS.VEHICLEID is a snapshot taken
/// at trip-creation time, not a live lookup, so removing a mapping later
/// never changes historical trip records.
/// </summary>
public class EmployeeVehicleMappingService : IEmployeeVehicleMappingService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public EmployeeVehicleMappingService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<EmployeeVehicleMappingDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<EmployeeVehicleMappingDto>(
            """
            SELECT TOP 50 M.MAPPINGID AS MappingId,
                   TRY_CAST(M.EMPLOYEEID AS INT) AS EmployeeId, ISNULL(E.EMPLOYEENAME, '') AS EmployeeName,
                   TRY_CAST(M.VEHICLEID AS INT) AS VehicleId, ISNULL(V.VEHICLENAME, '') AS VehicleName,
                   M.VALIDSTARTDATE AS ValidStartDate, M.VALIDENDDATE AS ValidEndDate
            FROM EMPLOYEE_VEHICLE_MAPPING M
            LEFT JOIN EMPLOYEE E ON E.EMPLOYEEID = TRY_CAST(M.EMPLOYEEID AS INT)
            LEFT JOIN VEHICLE V ON V.VEHICLEID = TRY_CAST(M.VEHICLEID AS INT)
            WHERE (@Search IS NULL OR E.EMPLOYEENAME LIKE @Like OR V.VEHICLENAME LIKE @Like)
            ORDER BY M.VALIDSTARTDATE DESC
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }

    public async Task<EmployeeVehicleMappingDto?> GetByIdAsync(int mappingId)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<EmployeeVehicleMappingDto>(
            """
            SELECT M.MAPPINGID AS MappingId,
                   TRY_CAST(M.EMPLOYEEID AS INT) AS EmployeeId, ISNULL(E.EMPLOYEENAME, '') AS EmployeeName,
                   TRY_CAST(M.VEHICLEID AS INT) AS VehicleId, ISNULL(V.VEHICLENAME, '') AS VehicleName,
                   M.VALIDSTARTDATE AS ValidStartDate, M.VALIDENDDATE AS ValidEndDate
            FROM EMPLOYEE_VEHICLE_MAPPING M
            LEFT JOIN EMPLOYEE E ON E.EMPLOYEEID = TRY_CAST(M.EMPLOYEEID AS INT)
            LEFT JOIN VEHICLE V ON V.VEHICLEID = TRY_CAST(M.VEHICLEID AS INT)
            WHERE M.MAPPINGID = @MappingId
            """,
            new { MappingId = mappingId });
    }

    /// <summary>
    /// Two mappings for the same driver+vehicle pair "overlap" using the
    /// standard interval-overlap test (StartA <= EndB AND StartB <= EndA),
    /// treating a NULL end date as "ongoing" (far-future sentinel).
    /// </summary>
    private async Task<bool> OverlappingMappingExistsAsync(
        Microsoft.Data.SqlClient.SqlConnection connection, int employeeId, int vehicleId,
        DateTime validStartDate, DateTime? validEndDate, int? excludingMappingId, Microsoft.Data.SqlClient.SqlTransaction? transaction = null)
    {
        var count = await connection.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*) FROM EMPLOYEE_VEHICLE_MAPPING
            WHERE TRY_CAST(EMPLOYEEID AS INT) = @EmployeeId AND TRY_CAST(VEHICLEID AS INT) = @VehicleId
              AND (@ExcludingMappingId IS NULL OR MAPPINGID <> @ExcludingMappingId)
              AND VALIDSTARTDATE <= ISNULL(@ValidEndDate, '9999-12-31')
              AND ISNULL(VALIDENDDATE, '9999-12-31') >= @ValidStartDate
            """,
            new
            {
                EmployeeId = employeeId,
                VehicleId = vehicleId,
                ExcludingMappingId = excludingMappingId,
                ValidStartDate = validStartDate,
                ValidEndDate = validEndDate,
            },
            transaction);

        return count > 0;
    }

    public async Task<EmployeeVehicleMappingDto> CreateAsync(CreateEmployeeVehicleMappingRequest request, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await OverlappingMappingExistsAsync(connection, request.EmployeeId, request.VehicleId, request.ValidStartDate, request.ValidEndDate, null, transaction))
            throw new DuplicateVehicleMappingException();

        var mappingId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO EMPLOYEE_VEHICLE_MAPPING
                (EMPLOYEEID, VEHICLEID, VALIDSTARTDATE, VALIDENDDATE,
                 CREATEDUSERID, LASTMODIFYEDUSERID, USERCREATEDDATE, LASTMODIFYEDDATE,
                 CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            OUTPUT INSERTED.MAPPINGID
            VALUES
                (CAST(@EmployeeId AS VARCHAR(50)), CAST(@VehicleId AS VARCHAR(50)), @ValidStartDate, @ValidEndDate,
                 @UserId, @UserId, GETDATE(), GETDATE(),
                 @EmployeeIdAudit, @EmployeeIdAudit)
            """,
            new
            {
                request.EmployeeId,
                request.VehicleId,
                request.ValidStartDate,
                request.ValidEndDate,
                UserId = userId,
                EmployeeIdAudit = employeeId,
            },
            transaction);

        transaction.Commit();

        return (await GetByIdAsync(mappingId))!;
    }

    public async Task<EmployeeVehicleMappingDto> UpdateAsync(int mappingId, UpdateEmployeeVehicleMappingRequest request, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await OverlappingMappingExistsAsync(connection, request.EmployeeId, request.VehicleId, request.ValidStartDate, request.ValidEndDate, mappingId, transaction))
            throw new DuplicateVehicleMappingException();

        await connection.ExecuteAsync(
            """
            UPDATE EMPLOYEE_VEHICLE_MAPPING
            SET EMPLOYEEID = CAST(@EmployeeId AS VARCHAR(50)), VEHICLEID = CAST(@VehicleId AS VARCHAR(50)),
                VALIDSTARTDATE = @ValidStartDate, VALIDENDDATE = @ValidEndDate,
                LASTMODIFYEDUSERID = @UserId, LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeIdAudit
            WHERE MAPPINGID = @MappingId
            """,
            new
            {
                MappingId = mappingId,
                request.EmployeeId,
                request.VehicleId,
                request.ValidStartDate,
                request.ValidEndDate,
                UserId = userId,
                EmployeeIdAudit = employeeId,
            },
            transaction);

        transaction.Commit();

        return (await GetByIdAsync(mappingId))!;
    }

    public async Task<bool> DeleteAsync(int mappingId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rowsAffected = await connection.ExecuteAsync(
            "DELETE FROM EMPLOYEE_VEHICLE_MAPPING WHERE MAPPINGID = @MappingId",
            new { MappingId = mappingId });

        return rowsAffected > 0;
    }
}
