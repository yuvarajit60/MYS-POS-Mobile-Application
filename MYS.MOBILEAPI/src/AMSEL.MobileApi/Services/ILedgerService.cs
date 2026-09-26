using System.Data;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ILedgerService
{
    Task<IReadOnlyList<LedgerEntryDto>> GetAsync(int locationId, int customerId, DateTime? fromDate, DateTime? toDate);
    Task<LedgerSummaryDto> GetSummaryAsync(int locationId, DateTime? fromDate, DateTime? toDate);
}

/// <summary>
/// Customer ledger — Delivery rows (from DELIVERY_DETAILS, valued
/// proportionally against each line's SALESORDER_DETAILS.TOTALAMOUNT since
/// DELIVERY_DETAILS itself carries no amount), Trip Entry rows (from
/// TRIPENTRY.NETAMOUNT directly) and Payment rows (from PAYMENT_DETAILS),
/// with a running Outstanding Amount. See SP_MOBILE_GET_CUSTOMER_LEDGER
/// (028_ledger_include_trip_entry.sql) for why that running balance is
/// computed over the customer's entire history rather than just the
/// optional fromDate/toDate window passed here — the filter only narrows
/// which rows come back, it never resets the balance on them.
///
/// GetSummaryAsync backs the "no customer selected" view — an all-customers
/// aggregate instead of one customer's running ledger.
/// </summary>
public class LedgerService : ILedgerService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public LedgerService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<LedgerEntryDto>> GetAsync(int locationId, int customerId, DateTime? fromDate, DateTime? toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<LedgerEntryDto>(
            "dbo.SP_MOBILE_GET_CUSTOMER_LEDGER",
            new
            {
                LOCATIONID = locationId,
                CUSTOMERID = customerId,
                FROMDATE = fromDate?.Date,
                TODATE = toDate?.Date,
            },
            commandType: CommandType.StoredProcedure);

        return rows.ToList();
    }

    public async Task<LedgerSummaryDto> GetSummaryAsync(int locationId, DateTime? fromDate, DateTime? toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var summary = await connection.QuerySingleAsync<LedgerSummaryDto>(
            """
            WITH DeliveryAgg AS (
                SELECT SO.CUSTOMERID, SUM((SOD.TOTALAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY) AS Amount
                FROM DELIVERY_DETAILS DD
                INNER JOIN SALESORDER_DETAILS SOD ON SOD.SALESORDERDETID = DD.SALESORDERDETID
                INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
                WHERE SO.LOCATIONID = @LocationId
                  AND (@FromDate IS NULL OR CAST(DD.DELIVERDATE AS DATE) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(DD.DELIVERDATE AS DATE) <= @ToDate)
                GROUP BY SO.CUSTOMERID
            ),
            TripAgg AS (
                SELECT TE.CUSTOMERID, SUM(TE.NETAMOUNT) AS Amount
                FROM TRIPENTRY TE
                WHERE TE.LOCATIONID = @LocationId AND TE.CANCEL = 0
                  AND (@FromDate IS NULL OR CAST(TE.TRIPDATE AS DATE) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(TE.TRIPDATE AS DATE) <= @ToDate)
                GROUP BY TE.CUSTOMERID
            ),
            PaymentAgg AS (
                SELECT PD.CUSTOMERID, SUM(PD.AMOUNT) AS Amount
                FROM PAYMENT_DETAILS PD
                WHERE PD.LOCATIONID = @LocationId
                  AND (@FromDate IS NULL OR CAST(PD.PAYMENTDATE AS DATE) >= @FromDate)
                  AND (@ToDate IS NULL OR CAST(PD.PAYMENTDATE AS DATE) <= @ToDate)
                GROUP BY PD.CUSTOMERID
            ),
            AllCustomers AS (
                SELECT CUSTOMERID FROM DeliveryAgg
                UNION
                SELECT CUSTOMERID FROM TripAgg
                UNION
                SELECT CUSTOMERID FROM PaymentAgg
            )
            SELECT
                (SELECT COUNT(*) FROM AllCustomers) AS TotalCustomers,
                ISNULL((SELECT SUM(Amount) FROM DeliveryAgg), 0) AS TotalDeliveryAmount,
                ISNULL((SELECT SUM(Amount) FROM TripAgg), 0) AS TotalTripEntryAmount,
                ISNULL((SELECT SUM(Amount) FROM PaymentAgg), 0) AS TotalPaymentAmount
            """,
            new { LocationId = locationId, FromDate = fromDate?.Date, ToDate = toDate?.Date });

        return summary;
    }
}
