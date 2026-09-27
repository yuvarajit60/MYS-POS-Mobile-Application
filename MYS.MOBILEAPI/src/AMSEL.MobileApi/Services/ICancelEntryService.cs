using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ICancelEntryService
{
    Task<IReadOnlyList<CancelEntryOptionDto>> SearchEntriesAsync(int locationId, string transactionType, DateTime fromDate, DateTime toDate, int? customerId);
    Task CancelAsync(int locationId, int userId, CancelEntryRequest request);
}

public class InvalidCancelEntryException : Exception
{
    public InvalidCancelEntryException(string message) : base(message) { }
}

/// <summary>
/// One cancel action shared by Sales Order, Trip Entry, Delivery and
/// Payment, matching each table's own cancel columns (CANCEL/CANCELUSERID/
/// CANCELDATETIME on SALESORDER/TRIPENTRY; CANCEL/CANCELUSERID/CANCELDATE
/// on DELIVERY_DETAILS/PAYMENT_DETAILS — added ahead of this feature — plus
/// CANCELREMARKS on all four, see 029_cancel_entry_and_ledger_updates.sql).
///
/// Delivery is the special case: a delivery has no separate header row —
/// SP_MOBILE_CREATE_DELIVERY writes one DELIVERY_DETAILS row per product
/// line, all sharing one DELIVERYNO — so cancelling one reverses every one
/// of its lines' DELIVERYQTY back out of SALESORDER_DETAILS (matched by
/// SALESORDERDETID, which already identifies the product) before marking
/// those rows cancelled, making that product pending again for a future
/// delivery against the same Sales Order.
/// </summary>
public class CancelEntryService : ICancelEntryService
{
    public const string SalesOrderType = "Sales Order";
    public const string TripEntryType = "Trip Entry";
    public const string DeliveryType = "Delivery";
    public const string PaymentType = "Payment";

    private readonly ISqlConnectionFactory _connectionFactory;

    public CancelEntryService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<CancelEntryOptionDto>> SearchEntriesAsync(int locationId, string transactionType, DateTime fromDate, DateTime toDate, int? customerId)
    {
        using var connection = _connectionFactory.CreateConnection();
        var parameters = new { LocationId = locationId, FromDate = fromDate.Date, ToDate = toDate.Date, CustomerId = customerId };

        IEnumerable<CancelEntryOptionDto> rows = transactionType switch
        {
            SalesOrderType => await connection.QueryAsync<CancelEntryOptionDto>(
                """
                SELECT ENTRYNO AS EntryNo, ISNULL(CUSTOMERNAME, '') AS CustomerName, ENTRYDATE AS EntryDate, NETAMOUNT AS TotalAmount
                FROM SALESORDER
                WHERE LOCATIONID = @LocationId AND CANCEL = 0
                  AND CAST(ENTRYDATE AS DATE) BETWEEN @FromDate AND @ToDate
                  AND (@CustomerId IS NULL OR CUSTOMERID = @CustomerId)
                ORDER BY ENTRYDATE DESC, ENTRYNO DESC
                """,
                parameters),

            TripEntryType => await connection.QueryAsync<CancelEntryOptionDto>(
                """
                SELECT TE.ENTRYNO AS EntryNo, ISNULL(C.CUSTOMERNAME, '') AS CustomerName, TE.ENTRYDATE AS EntryDate, TE.NETAMOUNT AS TotalAmount
                FROM TRIPENTRY TE
                LEFT JOIN CUSTOMER C ON C.CUSTOMERID = TE.CUSTOMERID
                WHERE TE.LOCATIONID = @LocationId AND TE.CANCEL = 0
                  AND CAST(TE.ENTRYDATE AS DATE) BETWEEN @FromDate AND @ToDate
                  AND (@CustomerId IS NULL OR TE.CUSTOMERID = @CustomerId)
                ORDER BY TE.ENTRYDATE DESC, TE.ENTRYNO DESC
                """,
                parameters),

            DeliveryType => await connection.QueryAsync<CancelEntryOptionDto>(
                """
                SELECT DD.DELIVERYNO AS EntryNo, ISNULL(MAX(SO.CUSTOMERNAME), '') AS CustomerName, MIN(DD.DELIVERDATE) AS EntryDate,
                       SUM((SOD.TOTALAMOUNT / NULLIF(SOD.SALESQTY, 0)) * DD.DELIVERYQTY) AS TotalAmount
                FROM DELIVERY_DETAILS DD
                INNER JOIN SALESORDER_DETAILS SOD ON SOD.SALESORDERDETID = DD.SALESORDERDETID
                INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
                WHERE SO.LOCATIONID = @LocationId AND (DD.CANCEL IS NULL OR DD.CANCEL = 0)
                  AND CAST(DD.DELIVERDATE AS DATE) BETWEEN @FromDate AND @ToDate
                  AND (@CustomerId IS NULL OR SO.CUSTOMERID = @CustomerId)
                GROUP BY DD.DELIVERYNO
                ORDER BY MIN(DD.DELIVERDATE) DESC, DD.DELIVERYNO DESC
                """,
                parameters),

            PaymentType => await connection.QueryAsync<CancelEntryOptionDto>(
                """
                SELECT PD.PAYMENTNO AS EntryNo, ISNULL(C.CUSTOMERNAME, '') AS CustomerName, PD.PAYMENTDATE AS EntryDate, PD.AMOUNT AS TotalAmount
                FROM PAYMENT_DETAILS PD
                LEFT JOIN CUSTOMER C ON C.CUSTOMERID = PD.CUSTOMERID
                WHERE PD.LOCATIONID = @LocationId AND (PD.CANCEL IS NULL OR PD.CANCEL = 0)
                  AND CAST(PD.PAYMENTDATE AS DATE) BETWEEN @FromDate AND @ToDate
                  AND (@CustomerId IS NULL OR PD.CUSTOMERID = @CustomerId)
                ORDER BY PD.PAYMENTDATE DESC, PD.PAYMENTNO DESC
                """,
                parameters),

            _ => throw new InvalidCancelEntryException($"Unknown transaction type \"{transactionType}\"."),
        };

        return rows.ToList();
    }

    public async Task CancelAsync(int locationId, int userId, CancelEntryRequest request)
    {
        using var connection = _connectionFactory.CreateConnection();
        await connection.OpenAsync();
        using var transaction = connection.BeginTransaction();

        int rowsAffected;
        switch (request.TransactionType)
        {
            case SalesOrderType:
                rowsAffected = await connection.ExecuteAsync(
                    """
                    UPDATE SALESORDER
                    SET CANCEL = 1, CANCELUSERID = @UserId, CANCELDATETIME = @CancelDate, CANCELREMARKS = @Remarks
                    WHERE ENTRYNO = @EntryNo AND LOCATIONID = @LocationId AND CANCEL = 0
                    """,
                    new { request.EntryNo, LocationId = locationId, UserId = userId, request.CancelDate, request.Remarks },
                    transaction);
                break;

            case TripEntryType:
                rowsAffected = await connection.ExecuteAsync(
                    """
                    UPDATE TRIPENTRY
                    SET CANCEL = 1, CANCELUSERID = @UserId, CANCELDATETIME = @CancelDate, CANCELREMARKS = @Remarks
                    WHERE ENTRYNO = @EntryNo AND LOCATIONID = @LocationId AND CANCEL = 0
                    """,
                    new { request.EntryNo, LocationId = locationId, UserId = userId, request.CancelDate, request.Remarks },
                    transaction);
                break;

            case DeliveryType:
                rowsAffected = await connection.ExecuteAsync(
                    """
                    UPDATE SOD
                    SET SOD.DELIVERYQTY = SOD.DELIVERYQTY - DD.DELIVERYQTY
                    FROM SALESORDER_DETAILS SOD
                    INNER JOIN DELIVERY_DETAILS DD ON DD.SALESORDERDETID = SOD.SALESORDERDETID
                    INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
                    WHERE DD.DELIVERYNO = @EntryNo AND SO.LOCATIONID = @LocationId AND (DD.CANCEL IS NULL OR DD.CANCEL = 0)
                    """,
                    new { request.EntryNo, LocationId = locationId },
                    transaction);

                if (rowsAffected > 0)
                {
                    await connection.ExecuteAsync(
                        """
                        UPDATE DD
                        SET DD.CANCEL = 1, DD.CANCELUSERID = @UserId, DD.CANCELDATE = @CancelDate, DD.CANCELREMARKS = @Remarks
                        FROM DELIVERY_DETAILS DD
                        INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
                        WHERE DD.DELIVERYNO = @EntryNo AND SO.LOCATIONID = @LocationId AND (DD.CANCEL IS NULL OR DD.CANCEL = 0)
                        """,
                        new { request.EntryNo, LocationId = locationId, UserId = userId, request.CancelDate, request.Remarks },
                        transaction);
                }
                break;

            case PaymentType:
                rowsAffected = await connection.ExecuteAsync(
                    """
                    UPDATE PAYMENT_DETAILS
                    SET CANCEL = 1, CANCELUSERID = @UserId, CANCELDATE = @CancelDate, CANCELREMARKS = @Remarks
                    WHERE PAYMENTNO = @EntryNo AND LOCATIONID = @LocationId AND (CANCEL IS NULL OR CANCEL = 0)
                    """,
                    new { request.EntryNo, LocationId = locationId, UserId = userId, request.CancelDate, request.Remarks },
                    transaction);
                break;

            default:
                throw new InvalidCancelEntryException($"Unknown transaction type \"{request.TransactionType}\".");
        }

        if (rowsAffected == 0)
        {
            transaction.Rollback();
            throw new InvalidCancelEntryException("Entry not found, or already cancelled.");
        }

        transaction.Commit();
    }
}
