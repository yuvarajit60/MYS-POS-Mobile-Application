using System.Data;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IPaymentService
{
    Task<IReadOnlyList<CustomerDto>> SearchDeliveredCustomersAsync(int locationId, string? search);
    Task<CreatePaymentResponse> CreateAsync(CreatePaymentRequest request, int locationId, string username);
}

/// <summary>
/// Payment Entry — records money received against a customer's delivered
/// goods. Customer selection is restricted to customers who have actual
/// DELIVERY_DETAILS rows (see SearchDeliveredCustomersAsync), not every
/// customer, since a payment only makes sense against delivered value.
/// Writes go through SP_MOBILE_CREATE_PAYMENT. PaymentDate is
/// rep-selectable (see 025_payment_date_selectable.sql) — trusted from
/// the client, same convention as TRIPENTRY.TRIPDATE — falling back to
/// dbo.CHANGE_DATE then GETDATE() only if the request doesn't supply one.
/// </summary>
public class PaymentService : IPaymentService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public PaymentService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<CustomerDto>> SearchDeliveredCustomersAsync(int locationId, string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<CustomerDto>(
            """
            SELECT DISTINCT TOP 50 C.CUSTOMERID AS CustomerId, C.CUSTOMERNAME AS CustomerName, ISNULL(C.MOBILENO, '') AS MobileNo
            FROM CUSTOMER C
            INNER JOIN SALESORDER SO ON SO.CUSTOMERID = C.CUSTOMERID
            INNER JOIN DELIVERY_DETAILS DD ON DD.SALESORDERID = SO.SALESORDERID
            WHERE SO.LOCATIONID = @LocationId
              AND (@Search IS NULL OR C.CUSTOMERNAME LIKE @Like)
            ORDER BY C.CUSTOMERNAME
            """,
            new { LocationId = locationId, Search = search, Like = like });

        return rows.ToList();
    }

    public async Task<CreatePaymentResponse> CreateAsync(CreatePaymentRequest request, int locationId, string username)
    {
        if (request.Amount <= 0)
            throw new ArgumentException("Payment amount must be greater than zero.");

        using var connection = _connectionFactory.CreateConnection();

        var parameters = new DynamicParameters();
        parameters.Add("@LOCATIONID", locationId);
        parameters.Add("@CUSTOMERID", request.CustomerId);
        parameters.Add("@AMOUNT", request.Amount);
        parameters.Add("@PAYMENTTYPE", request.PaymentType);
        parameters.Add("@PAYMENTDATE", request.PaymentDate);
        parameters.Add("@CREATEUSER", username);
        parameters.Add("@PAYMENTNO", dbType: DbType.String, direction: ParameterDirection.Output, size: -1);

        await connection.ExecuteAsync(
            "dbo.SP_MOBILE_CREATE_PAYMENT",
            parameters,
            commandType: CommandType.StoredProcedure);

        var paymentNo = parameters.Get<string?>("@PAYMENTNO") ?? "";
        return new CreatePaymentResponse(paymentNo);
    }
}
