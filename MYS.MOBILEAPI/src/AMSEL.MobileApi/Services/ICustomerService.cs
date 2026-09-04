using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ICustomerService
{
    Task<IReadOnlyList<CustomerDto>> SearchAsync(string? search);
    Task<CustomerDetailDto?> GetByIdAsync(int customerId);
    Task<CustomerDto> CreateAsync(CreateCustomerRequest request, int locationId, int userId, int employeeId);
    Task<CustomerDto> UpdateAsync(int customerId, UpdateCustomerRequest request, int locationId, int userId, int employeeId);
    Task<bool> DeleteAsync(int customerId, int locationId, int userId, int employeeId);
}

public class DuplicateCustomerException : Exception
{
    public DuplicateCustomerException(string mobileNo)
        : base($"A customer with mobile number \"{mobileNo}\" already exists.") { }
}

public class CustomerService : ICustomerService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public CustomerService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<CustomerDto>> SearchAsync(string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<CustomerDto>(
            """
            SELECT TOP 50 CUSTOMERID AS CustomerId, CUSTOMERNAME AS CustomerName, ISNULL(MOBILENO, '') AS MobileNo
            FROM CUSTOMER
            WHERE STATUS = 1
              AND (@Search IS NULL OR CUSTOMERNAME LIKE @Like OR MOBILENO LIKE @Like)
            ORDER BY CUSTOMERNAME
            """,
            new { Search = search, Like = like });

        return rows.ToList();
    }

    public async Task<CustomerDetailDto?> GetByIdAsync(int customerId)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<CustomerDetailDto>(
            """
            SELECT C.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName, ISNULL(C.MOBILENO, '') AS MobileNo,
                   C.CITYID AS CityId, ISNULL(CI.CITYNAME, '') AS CityName, ISNULL(C.ADDRESS, '') AS Address
            FROM CUSTOMER C
            LEFT JOIN CITY CI ON CI.CITYID = C.CITYID
            WHERE C.CUSTOMERID = @CustomerId AND C.STATUS = 1
            """,
            new { CustomerId = customerId });
    }

    private async Task<bool> MobileNoExistsAsync(Microsoft.Data.SqlClient.SqlConnection connection, string mobileNo, int? excludingCustomerId, Microsoft.Data.SqlClient.SqlTransaction? transaction = null)
    {
        if (string.IsNullOrWhiteSpace(mobileNo)) return false;

        var count = await connection.ExecuteScalarAsync<int>(
            """
            SELECT COUNT(*) FROM CUSTOMER
            WHERE STATUS = 1 AND MOBILENO = @MobileNo
              AND (@ExcludingCustomerId IS NULL OR CUSTOMERID <> @ExcludingCustomerId)
            """,
            new { MobileNo = mobileNo, ExcludingCustomerId = excludingCustomerId },
            transaction);

        return count > 0;
    }

    /// <summary>
    /// Mirrors the desktop CUSTOMER.vb form's field-copying convention
    /// (PRINTNAME defaults to CUSTOMERNAME, PRINTADDRESS defaults to ADDRESS)
    /// for the NOT NULL columns the desktop UI doesn't separately collect.
    /// </summary>
    public async Task<CustomerDto> CreateAsync(CreateCustomerRequest request, int locationId, int userId, int employeeId)
    {
        var address = request.Address ?? "";

        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await MobileNoExistsAsync(connection, request.MobileNo, null, transaction))
            throw new DuplicateCustomerException(request.MobileNo);

        var customerId = await connection.QuerySingleAsync<int>(
            """
            INSERT INTO CUSTOMER
                (CUSTOMERNAME, PRINTNAME, MOBILENO, ADDRESS, PRINTADDRESS, CITYID, STATUS,
                 LOCATIONID, CREATEDLOCATIONID, MODIFYEDLOCATIONID, CREATEDUSERID, LASTMODIFYEDUSERID,
                 USERCREATEDDATE, LASTMODIFYEDDATE, CREATEDEMPLOYEEID, MODIFYEDEMPLOYEEID)
            OUTPUT INSERTED.CUSTOMERID
            VALUES
                (@CustomerName, @CustomerName, @MobileNo, @Address, @Address, @CityId, 1,
                 @LocationId, @LocationId, @LocationId, @UserId, @UserId,
                 GETDATE(), GETDATE(), @EmployeeId, @EmployeeId)
            """,
            new
            {
                request.CustomerName,
                request.MobileNo,
                Address = address,
                request.CityId,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return new CustomerDto(customerId, request.CustomerName, request.MobileNo);
    }

    public async Task<CustomerDto> UpdateAsync(int customerId, UpdateCustomerRequest request, int locationId, int userId, int employeeId)
    {
        var address = request.Address ?? "";

        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        if (await MobileNoExistsAsync(connection, request.MobileNo, customerId, transaction))
            throw new DuplicateCustomerException(request.MobileNo);

        await connection.ExecuteAsync(
            """
            UPDATE CUSTOMER
            SET CUSTOMERNAME = @CustomerName, PRINTNAME = @CustomerName, MOBILENO = @MobileNo,
                ADDRESS = @Address, PRINTADDRESS = @Address, CITYID = @CityId,
                MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE CUSTOMERID = @CustomerId AND STATUS = 1
            """,
            new
            {
                CustomerId = customerId,
                request.CustomerName,
                request.MobileNo,
                Address = address,
                request.CityId,
                LocationId = locationId,
                UserId = userId,
                EmployeeId = employeeId,
            },
            transaction);

        transaction.Commit();

        return new CustomerDto(customerId, request.CustomerName, request.MobileNo);
    }

    /// <summary>Soft delete (STATUS=0) — preserves the customer name/mobile on any existing SALESORDER rows, which store their own snapshot rather than joining live.</summary>
    public async Task<bool> DeleteAsync(int customerId, int locationId, int userId, int employeeId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rowsAffected = await connection.ExecuteAsync(
            """
            UPDATE CUSTOMER
            SET STATUS = 0, MODIFYEDLOCATIONID = @LocationId, LASTMODIFYEDUSERID = @UserId,
                LASTMODIFYEDDATE = GETDATE(), MODIFYEDEMPLOYEEID = @EmployeeId
            WHERE CUSTOMERID = @CustomerId AND STATUS = 1
            """,
            new { CustomerId = customerId, LocationId = locationId, UserId = userId, EmployeeId = employeeId });

        return rowsAffected > 0;
    }
}
