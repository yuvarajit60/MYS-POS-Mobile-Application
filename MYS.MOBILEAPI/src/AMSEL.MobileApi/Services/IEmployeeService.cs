using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IEmployeeService
{
    Task<IReadOnlyList<DriverDto>> GetDriversAsync(string? search);
    Task<DriverVehicleDto> GetDriverVehicleAsync(int employeeId);
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
}
