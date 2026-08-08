using System.Data;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Microsoft.Data.SqlClient;

namespace AMSEL.MobileApi.Services;

public interface ISalesOrderService
{
    Task<CreateSalesOrderResponse> CreateAsync(CreateSalesOrderRequest request, int locationId, int userId, int employeeId);
}

/// <summary>
/// Thin wrapper around dbo.SP_MOBILE_CREATE_SALESORDER. Writes only to
/// dbo.SALESORDER / dbo.SALESORDER_DETAILS — never dbo.STOCK_DETAILS or dbo.SALES.
/// Raw ADO.NET (not Dapper) here because the proc takes a table-valued parameter and
/// returns OUTPUT params, which Dapper handles awkwardly compared to plain SqlCommand.
/// </summary>
public class SalesOrderService : ISalesOrderService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public SalesOrderService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<CreateSalesOrderResponse> CreateAsync(CreateSalesOrderRequest request, int locationId, int userId, int employeeId)
    {
        if (request.Lines is null || request.Lines.Count == 0)
            throw new ArgumentException("At least one line item is required.");

        var linesTable = new DataTable();
        linesTable.Columns.Add("PRODUCTID", typeof(int));
        linesTable.Columns.Add("QTY", typeof(decimal));
        linesTable.Columns.Add("RATE", typeof(decimal));
        foreach (var line in request.Lines)
            linesTable.Rows.Add(line.ProductId, line.Qty, line.Rate);

        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();

        using var command = connection.CreateCommand();
        command.CommandType = CommandType.StoredProcedure;
        command.CommandText = "dbo.SP_MOBILE_CREATE_SALESORDER";

        command.Parameters.Add(new SqlParameter("@LOCATIONID", SqlDbType.Int) { Value = locationId });
        command.Parameters.Add(new SqlParameter("@CUSTOMERID", SqlDbType.Int) { Value = request.CustomerId });
        command.Parameters.Add(new SqlParameter("@CUSTOMERNAME", SqlDbType.VarChar, 100) { Value = request.CustomerName });
        command.Parameters.Add(new SqlParameter("@MOBILENO", SqlDbType.VarChar, 50) { Value = request.MobileNo });
        command.Parameters.Add(new SqlParameter("@SHIPPINGADDRESS", SqlDbType.VarChar, 500) { Value = request.ShippingAddress });
        command.Parameters.Add(new SqlParameter("@CREATEDUSERID", SqlDbType.Int) { Value = userId });
        command.Parameters.Add(new SqlParameter("@CREATEDEMPLOYEEID", SqlDbType.Int) { Value = employeeId });

        var linesParam = new SqlParameter("@LINES", SqlDbType.Structured)
        {
            TypeName = "dbo.TVP_MOBILE_SALESORDER_LINES",
            Value = linesTable
        };
        command.Parameters.Add(linesParam);

        var salesOrderIdParam = new SqlParameter("@SALESORDERID", SqlDbType.Int) { Direction = ParameterDirection.Output };
        var entryNoParam = new SqlParameter("@ENTRYNO", SqlDbType.VarChar, -1) { Direction = ParameterDirection.Output };
        command.Parameters.Add(salesOrderIdParam);
        command.Parameters.Add(entryNoParam);

        await command.ExecuteNonQueryAsync();

        var salesOrderId = salesOrderIdParam.Value is int id ? id : 0;
        var entryNo = entryNoParam.Value as string ?? "";

        return new CreateSalesOrderResponse(salesOrderId, entryNo);
    }
}
