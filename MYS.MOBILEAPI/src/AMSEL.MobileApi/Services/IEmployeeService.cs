using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IEmployeeService
{
    Task<IReadOnlyList<DriverDto>> GetDriversAsync(string? search);
    Task<DriverVehicleDto> GetDriverVehicleAsync(int employeeId);

    Task<IReadOnlyList<EmployeeDto>> SearchAsync(string? search);
    Task<EmployeeDetailDto?> GetByIdAsync(int id);
    Task<EmployeeDto> CreateAsync(CreateEmployeeRequest request, int locationId, int userId, int employeeId);
    Task<EmployeeDto> UpdateAsync(int id, UpdateEmployeeRequest request, int locationId, int userId, int employeeId);
    Task<bool> DeleteAsync(int id, int locationId, int userId, int employeeId);
}

public class DuplicateEmployeeException : Exception
{
    public DuplicateEmployeeException(string mobileNo)
        : base($"An employee with mobile number \"{mobileNo}\" already exists.") { }
}

public class EmployeeService : IEmployeeService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public EmployeeService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    /// <summary>Global, not location-scoped — matches CustomerService/ProductService's SearchAsync convention (search reads aren't location-filtered; only writes stamp LOCATIONID).</summary>
    public async Task<IReadOnlyList<DriverDto>> GetDriversAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<DriverDto>(
            """
            SELECT TOP 50 EMPLOYEEID AS EmployeeId, EMPLOYEENAME AS EmployeeName, ISNULL(MOBILENO, '') AS MobileNo
            FROM EMPLOYEE
            WHERE STATUS = 1 AND ISDRIVER = 1
              AND (@Search IS NULL OR EMPLOYEENAME LIKE @Like)
            ORDER BY EMPLOYEENAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }

    /// <summary>
    /// EMPLOYEE_VEHICLE_MAPPING stores EMPLOYEEID/VEHICLEID as VARCHAR (legacy
    /// column typing) — cast to INT to join. Picks the mapping that's valid
    /// right now (VALIDENDDATE NULL or in the future), most recently started
    /// first, in case more than one is somehow open at once.
    /// </summary>
    public async Task<DriverVehicleDto> GetDriverVehicleAsync(int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var row = await connection.QueryFirstOrDefaultAsync<DriverVehicleDto>(
            """
            SELECT TOP 1 V.VEHICLEID AS VehicleId, V.VEHICLENAME AS VehicleName
            FROM EMPLOYEE_VEHICLE_MAPPING M
            INNER JOIN VEHICLE V ON V.VEHICLEID = TRY_CAST(M.VEHICLEID AS INT)
            WHERE TRY_CAST(M.EMPLOYEEID AS INT) = @EmployeeId
              AND M.VALIDSTARTDATE <= GETDATE()
              AND (M.VALIDENDDATE IS NULL OR M.VALIDENDDATE >= GETDATE())
            ORDER BY M.VALIDSTARTDATE DESC
            """,
            new { EmployeeId = employeeId });

        return row ?? new DriverVehicleDto(null, null);
    }

    /// <summary>Global, not location-scoped — same reasoning as GetDriversAsync above.</summary>
    public async Task<IReadOnlyList<EmployeeDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<EmployeeDto>(
            """
            SELECT TOP 50 EMPLOYEEID AS EmployeeId, EMPLOYEENAME AS EmployeeName, ISNULL(MOBILENO, '') AS MobileNo,
                   CAST(ISNULL(ISDRIVER, 0) AS BIT) AS IsDriver
            FROM EMPLOYEE
            WHERE STATUS = 1
              AND (@Search IS NULL OR EMPLOYEENAME LIKE @Like OR MOBILENO LIKE @Like)
            ORDER BY EMPLOYEENAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }

    public async Task<EmployeeDetailDto?> GetByIdAsync(int id)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<EmployeeDetailDto>(
            """
            SELECT E.EMPLOYEEID AS EmployeeId, E.EMPLOYEENAME AS EmployeeName, ISNULL(E.PRINTNAME, '') AS PrintName,
                   ISNULL(E.EMPLOYEECODE, '') AS EmployeeCode, ISNULL(E.ADDRESS, '') AS Address,
                   E.CITYID AS CityId, ISNULL(CI.CITYNAME, '') AS CityName,
                   ISNULL(E.PINCODE, '') AS PinCode, ISNULL(E.PHONENO, '') AS PhoneNo, ISNULL(E.MOBILENO, '') AS MobileNo,
                   ISNULL(E.EMAILID, '') AS EmailId, CAST(ISNULL(E.ISDRIVER, 0) AS BIT) AS IsDriver
            FROM EMPLOYEE E
            LEFT JOIN CITY CI ON CI.CITYID = E.CITYID
            WHERE E.EMPLOYEEID = @Id AND E.STATUS = 1
            """,
            new { Id = id });
    }

    private async Task<bool> MobileNoExistsAsync(Microsoft.Data.SqlClient.SqlConnection connection, string mobileNo, int? excludingId, Microsoft.Data.SqlClient.SqlTransaction? transaction = null)
    {
        if (string.IsNullOrWhiteSpace(mobileNo)) return false;

        var count = await connection.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*) FROM EMPLOYEE
            WHERE STATUS = 1 AND MOBILENO = @MobileNo
              AND (@ExcludingId IS NULL OR EMPLOYEEID <> @ExcludingId)
            """,
            new { MobileNo = mobileNo, ExcludingId = excludingId },
            transaction);

        return count > 0;
    }

    public async Task<EmployeeDto> CreateAsync(CreateEmployeeRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await MobileNoExistsAsync(connection, request.MobileNo, null, transaction))
            throw new DuplicateEmployeeException(request.MobileNo);

        var newId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO EMPLOYEE
                (EMPLOYEENAME, PRINTNAME, EMPLOYEECODE, ADDRESS, CITYID, PINCODE, PHONENO, MOBILENO, EMAILID, STATUS, ISDRIVER,
                 LOCATIONID, CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            OUTPUT INSERTED.EMPLOYEEID
            VALUES
                (@EmployeeName, @PrintName, @EmployeeCode, @Address, @CityId, @PinCode, @PhoneNo, @MobileNo, @EmailId, 1, @IsDriver,
                 @LocationId, @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @EmployeeId, @EmployeeId)
            """,
            new
            {
                request.EmployeeName,
                PrintName = request.PrintName ?? request.EmployeeName,
                EmployeeCode = request.EmployeeCode ?? "",
                Address = request.Address ?? "",
                request.CityId,
                PinCode = request.PinCode ?? "",
                PhoneNo = request.PhoneNo ?? "",
                request.MobileNo,
                EmailId = request.EmailId ?? "",
                IsDriver = request.IsDriver ? 1 : 0,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return new EmployeeDto(newId, request.EmployeeName, request.MobileNo, request.IsDriver);
    }

    public async Task<EmployeeDto> UpdateAsync(int id, UpdateEmployeeRequest request, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await MobileNoExistsAsync(connection, request.MobileNo, id, transaction))
            throw new DuplicateEmployeeException(request.MobileNo);

        await connection.ExecuteAsync(
            """
            UPDATE EMPLOYEE
            SET EMPLOYEENAME = @EmployeeName, PRINTNAME = @PrintName, EMPLOYEECODE = @EmployeeCode,
                ADDRESS = @Address, CITYID = @CityId, PINCODE = @PinCode, PHONENO = @PhoneNo,
                MOBILENO = @MobileNo, EMAILID = @EmailId, ISDRIVER = @IsDriver,
                MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE EMPLOYEEID = @Id AND STATUS = 1
            """,
            new
            {
                Id = id,
                request.EmployeeName,
                PrintName = request.PrintName ?? request.EmployeeName,
                EmployeeCode = request.EmployeeCode ?? "",
                Address = request.Address ?? "",
                request.CityId,
                PinCode = request.PinCode ?? "",
                PhoneNo = request.PhoneNo ?? "",
                request.MobileNo,
                EmailId = request.EmailId ?? "",
                IsDriver = request.IsDriver ? 1 : 0,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return new EmployeeDto(id, request.EmployeeName, request.MobileNo, request.IsDriver);
    }

    /// <summary>Soft delete (STATUS=0) — matches CUSTOMER/PRODUCT/SITE's convention; historical TRIPENTRY/DELIVERY_DETAILS rows store their own driver snapshot rather than joining live.</summary>
    public async Task<bool> DeleteAsync(int id, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rowsAffected = await connection.ExecuteAsync(
            """
            UPDATE EMPLOYEE
            SET STATUS = 0, MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE EMPLOYEEID = @Id AND STATUS = 1
            """,
            new { Id = id, LocationId = locationId, UserId = userId, EmployeeId = employeeId });

        return rowsAffected > 0;
    }
}
