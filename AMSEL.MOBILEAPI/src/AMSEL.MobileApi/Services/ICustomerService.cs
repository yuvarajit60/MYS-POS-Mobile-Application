using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ICustomerService
{
    Task<IReadOnlyList<CustomerDto>> SearchAsync(string? search);
    Task<CustomerDto> CreateAsync(CreateCustomerRequest request, int locationId, int userId, int employeeId);
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

    /// <summary>
    /// Mirrors the desktop CUSTOMER.vb form's field-copying convention
    /// (PRINTNAME defaults to CUSTOMERNAME, PRINTADDRESS defaults to ADDRESS)
    /// for the NOT NULL columns the desktop UI doesn't separately collect.
    /// </summary>
    public async Task<CustomerDto> CreateAsync(CreateCustomerRequest request, int locationId, int userId, int employeeId)
    {
        var address = request.Address ?? "";

        using var connection = _connectionFactory.CreateConnection();
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
            });

        return new CustomerDto(customerId, request.CustomerName, request.MobileNo);
    }
}
