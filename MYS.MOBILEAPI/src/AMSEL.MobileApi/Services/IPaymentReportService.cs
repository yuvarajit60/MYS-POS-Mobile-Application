using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IPaymentReportService
{
    Task<IReadOnlyList<PaymentReportEntryDto>> GetSummaryAsync(
        int locationId, int? customerId, string? paymentType, DateTime fromDate, DateTime toDate);
}

/// <summary>
/// Flat list of PAYMENT_DETAILS rows — unlike the customer ledger
/// (SP_MOBILE_GET_CUSTOMER_LEDGER), this report is payments only, no
/// Delivery rows and no running balance, so a plain parameterized query
/// is enough; no stored procedure needed.
/// </summary>
public class PaymentReportService : IPaymentReportService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public PaymentReportService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<PaymentReportEntryDto>> GetSummaryAsync(
        int locationId, int? customerId, string? paymentType, DateTime fromDate, DateTime toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<PaymentReportEntryDto>(
            """
            SELECT PD.PAYMENTNO AS PaymentNo, C.CUSTOMERNAME AS CustomerName,
                   PD.PAYMENTDATE AS PaymentDate, PD.PAYMENTTYPE AS PaymentType, PD.AMOUNT AS Amount
            FROM PAYMENT_DETAILS PD
            INNER JOIN CUSTOMER C ON C.CUSTOMERID = PD.CUSTOMERID
            WHERE PD.LOCATIONID = @LocationId
              AND CAST(PD.PAYMENTDATE AS DATE) BETWEEN @FromDate AND @ToDate
              AND (@CustomerId IS NULL OR PD.CUSTOMERID = @CustomerId)
              AND (@PaymentType IS NULL OR PD.PAYMENTTYPE = @PaymentType)
            ORDER BY PD.PAYMENTDATE DESC, PD.PAYMENTID DESC
            """,
            new
            {
                LocationId = locationId,
                CustomerId = customerId,
                PaymentType = paymentType,
                FromDate = fromDate.Date,
                ToDate = toDate.Date,
            });

        return rows.ToList();
    }
}
