using System.Data;
using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ILedgerService
{
    Task<IReadOnlyList<LedgerEntryDto>> GetAsync(int locationId, int customerId, DateTime? fromDate, DateTime? toDate);
    Task<IReadOnlyList<LedgerAllCustomersRowDto>> GetAllCustomersAsync(int locationId, DateTime? fromDate, DateTime? toDate);
}

/// <summary>
/// Customer ledger — Delivery rows (from DELIVERY_DETAILS, valued
/// proportionally against each line's SALESORDER_DETAILS.TOTALAMOUNT since
/// DELIVERY_DETAILS itself carries no amount), Trip Entry rows (from
/// TRIPENTRY.NETAMOUNT directly) and Payment rows (from PAYMENT_DETAILS),
/// with a running Outstanding Amount. See SP_MOBILE_GET_CUSTOMER_LEDGER
/// (028_ledger_include_trip_entry.sql, 029_cancel_entry_and_ledger_updates.sql)
/// for why that running balance is computed over the customer's entire
/// history rather than just the optional fromDate/toDate window passed
/// here — the filter only narrows which rows come back, it never resets
/// the balance on them. Cancelled Delivery/Payment rows (DD.CANCEL/
/// PD.CANCEL) and cancelled Trip Entries (TE.CANCEL) are excluded.
///
/// GetAllCustomersAsync backs the "no customer selected" view — a flat
/// register of every transaction across every customer (Tally "Ledger
/// Vouchers"-style), not one customer's running ledger.
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

    public async Task<IReadOnlyList<LedgerAllCustomersRowDto>> GetAllCustomersAsync(int locationId, DateTime? fromDate, DateTime? toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<LedgerAllCustomersRowDto>(
            """
            WITH DeliveryTxns AS (
                SELECT
                    DD.DELIVERYNO AS TXNNO,
                    MIN(DD.DELIVERDATE) AS TXNDATE,
                    SO.CUSTOMERID,
                    'Delivery' AS TXNTYPE,
                    SUM(DD.DELIVERYQTY) AS QTY,
                    SUM((SOD.TOTALAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY) AS TOTALAMOUNT,
                    CAST(0 AS NUMERIC(18,2)) AS RECEIVEDAMOUNT
                FROM DELIVERY_DETAILS DD
                INNER JOIN SALESORDER_DETAILS SOD ON SOD.SALESORDERDETID = DD.SALESORDERDETID
                INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
                WHERE SO.LOCATIONID = @LocationId AND (DD.CANCEL IS NULL OR DD.CANCEL = 0)
                GROUP BY DD.DELIVERYNO, SO.CUSTOMERID
            ),
            TripTxns AS (
                SELECT
                    TE.ENTRYNO AS TXNNO,
                    TE.TRIPDATE AS TXNDATE,
                    TE.CUSTOMERID,
                    'Trip Entry' AS TXNTYPE,
                    ISNULL((SELECT SUM(TD.QTY) FROM TRIPENTRY_DETAILS TD WHERE TD.TRIPENTRYID = TE.TRIPENTRYID), 0) AS QTY,
                    TE.NETAMOUNT AS TOTALAMOUNT,
                    CAST(0 AS NUMERIC(18,2)) AS RECEIVEDAMOUNT
                FROM TRIPENTRY TE
                WHERE TE.LOCATIONID = @LocationId AND TE.CANCEL = 0
            ),
            PaymentTxns AS (
                SELECT
                    PD.PAYMENTNO AS TXNNO,
                    PD.PAYMENTDATE AS TXNDATE,
                    PD.CUSTOMERID,
                    'Payment' AS TXNTYPE,
                    CAST(0 AS NUMERIC(18,3)) AS QTY,
                    CAST(0 AS NUMERIC(18,2)) AS TOTALAMOUNT,
                    PD.AMOUNT AS RECEIVEDAMOUNT
                FROM PAYMENT_DETAILS PD
                WHERE PD.LOCATIONID = @LocationId AND (PD.CANCEL IS NULL OR PD.CANCEL = 0)
            ),
            Combined AS (
                SELECT * FROM DeliveryTxns
                UNION ALL
                SELECT * FROM TripTxns
                UNION ALL
                SELECT * FROM PaymentTxns
            )
            SELECT C.TXNDATE AS TxnDate, ISNULL(CU.CUSTOMERNAME, '') AS CustomerName, C.TXNTYPE AS TxnType, C.TXNNO AS TxnNo,
                   C.QTY AS Qty, C.TOTALAMOUNT AS TotalAmount, C.RECEIVEDAMOUNT AS ReceivedAmount,
                   (C.TOTALAMOUNT - C.RECEIVEDAMOUNT) AS OutstandingAmount
            FROM Combined C
            LEFT JOIN CUSTOMER CU ON CU.CUSTOMERID = C.CUSTOMERID
            WHERE (@FromDate IS NULL OR CAST(C.TXNDATE AS DATE) >= @FromDate)
              AND (@ToDate IS NULL OR CAST(C.TXNDATE AS DATE) <= @ToDate)
            ORDER BY C.TXNDATE, CU.CUSTOMERNAME, C.TXNNO
            """,
            new { LocationId = locationId, FromDate = fromDate?.Date, ToDate = toDate?.Date });

        return rows.ToList();
    }
}
