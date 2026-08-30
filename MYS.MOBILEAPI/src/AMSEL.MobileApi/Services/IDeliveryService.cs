using System.Data;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AMSEL.MobileApi.Services;

public interface IDeliveryService
{
    Task<IReadOnlyList<CustomerDto>> GetPendingCustomersAsync(int locationId, string? search);
    Task<IReadOnlyList<PendingDeliveryLineDto>> GetPendingLinesAsync(int locationId, int customerId);
    Task<CreateDeliveryResponse> CreateAsync(CreateDeliveryRequest request, int locationId, string username);
}

/// <summary>
/// Delivery Entry — fulfils already-created Sales Order lines. "Pending"
/// means SALESORDER_DETAILS.SALESQTY - DELIVERYQTY > 0. Writes go through
/// SP_MOBILE_CREATE_DELIVERY (raw ADO.NET, same reason as SalesOrderService/
/// TripEntryService: the proc takes a table-valued parameter).
/// </summary>
public class DeliveryService : IDeliveryService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public DeliveryService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<CustomerDto>> GetPendingCustomersAsync(int locationId, string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<CustomerDto>(
            """
            SELECT DISTINCT TOP 50 C.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName, ISNULL(C.MOBILENO, '') AS MobileNo
            FROM CUSTOMER C
            INNER JOIN SALESORDER SO ON SO.CUSTOMERID = C.CUSTOMERID
            INNER JOIN SALESORDER_DETAILS SOD ON SOD.SALESORDERID = SO.SALESORDERID
            WHERE SO.LOCATIONID = @LocationId AND SO.CANCEL = 0
              AND (SOD.SALESQTY - SOD.DELIVERYQTY) > 0
              AND (@Search IS NULL OR C.CUSTOMERNAME LIKE @Like)
            ORDER BY C.CUSTOMERNAME
            """,
            new { LocationId = locationId, Search = search, Like = like });

        return rows.ToList();
    }

    public async Task<IReadOnlyList<PendingDeliveryLineDto>> GetPendingLinesAsync(int locationId, int customerId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<PendingDeliveryLineDto>(
            """
            SELECT SOD.SALESORDERDETID AS SalesOrderDetId, SO.SALESORDERID AS SalesOrderId, SO.ENTRYNO AS SalesOrderNo,
                   SOD.PRODUCTID AS ProductId, ISNULL(PR.PRODUCTNAME, '') AS ProductName,
                   SOD.SALESQTY AS SalesQty, CAST(SOD.DELIVERYQTY AS NUMERIC(18,3)) AS DeliveryQty,
                   (SOD.SALESQTY - SOD.DELIVERYQTY) AS BalanceQty
            FROM SALESORDER_DETAILS SOD
            INNER JOIN SALESORDER SO ON SO.SALESORDERID = SOD.SALESORDERID
            LEFT JOIN PRODUCT PR ON PR.PRODUCTID = SOD.PRODUCTID
            WHERE SO.CUSTOMERID = @CustomerId AND SO.LOCATIONID = @LocationId AND SO.CANCEL = 0
              AND (SOD.SALESQTY - SOD.DELIVERYQTY) > 0
            ORDER BY SO.ENTRYDATE, SO.ENTRYNO, SOD.SALESORDERDETID
            """,
            new { CustomerId = customerId, LocationId = locationId });

        return rows.ToList();
    }

    public async Task<CreateDeliveryResponse> CreateAsync(CreateDeliveryRequest request, int locationId, string username)
    {
        if (request.Lines is null || request.Lines.Count == 0)
            throw new ArgumentException("At least one line item is required.");

        var linesTable = new DataTable();
        linesTable.Columns.Add("SALESORDERDETID", typeof(int));
        linesTable.Columns.Add("SALESORDERID", typeof(int));
        linesTable.Columns.Add("PRODUCTID", typeof(int));
        linesTable.Columns.Add("DELIVERYQTY", typeof(decimal));
        foreach (var line in request.Lines)
            linesTable.Rows.Add(line.SalesOrderDetId, line.SalesOrderId, line.ProductId, line.CurrentDelivery);

        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();

        using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "dbo.SP_MOBILE_CREATE_DELIVERY";

        command.Parameters.Add(new SqlParameter("@LOCATIONID", SqlDbType.Int) { Value = locationId });
        command.Parameters.Add(new SqlParameter("@DRIVERID", SqlDbType.Int) { Value = request.DriverEmployeeId });
        command.Parameters.Add(new SqlParameter("@VEHICLENUMBER", SqlDbType.VarChar, 50) { Value = (object?)request.VehicleNumber ?? DBNull.Value });
        command.Parameters.Add(new SqlParameter("@CREATEUSER", SqlDbType.VarChar, 50) { Value = username });

        var linesParam = new SqlParameter("@LINES", SqlDbType.Structured)
        {
            TypeName = "dbo.TVP_MOBILE_DELIVERY_LINES",
            Value = linesTable
        };
        command.Parameters.Add(linesParam);

        var deliveryNoParam = new SqlParameter("@DELIVERYNO", SqlDbType.VarChar, -1) { Direction = ParameterDirection.Output };
        command.Parameters.Add(deliveryNoParam);

        await command.ExecuteNonQueryAsync();

        var deliveryNo = deliveryNoParam.Value as string ?? "";

        return new CreateDeliveryResponse(request.Lines.Count, deliveryNo);
    }
}
