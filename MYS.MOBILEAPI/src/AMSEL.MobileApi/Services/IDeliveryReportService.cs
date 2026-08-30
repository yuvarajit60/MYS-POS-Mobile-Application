using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IDeliveryReportService
{
    Task<IReadOnlyList<DeliverySummaryDto>> GetSummaryAsync(int locationId, int? customerId, DateTime fromDate, DateTime toDate);
}

/// <summary>
/// DELIVERY_DETAILS has no header row (unlike SALESORDER/TRIPENTRY) — each
/// row already is a complete, final record (never edited after creation),
/// so this report is a flat list, not a summary-then-drill-down pair.
/// </summary>
public class DeliveryReportService : IDeliveryReportService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public DeliveryReportService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<DeliverySummaryDto>> GetSummaryAsync(int locationId, int? customerId, DateTime fromDate, DateTime toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var rows = await connection.QueryAsync<DeliverySummaryDto>(
            """
            SELECT DD.DELIVERYID AS DeliveryId, DD.CREATE_DATE AS DeliveryDate, SO.ENTRYNO AS SalesOrderNo,
                   C.CUSTOMERNAME AS CustomerName, ISNULL(PR.PRODUCTNAME, '') AS ProductName,
                   DD.DELIVERYQTY AS DeliveryQty, DD.BALANCEQTY AS BalanceQty,
                   ISNULL(E.EMPLOYEENAME, '') AS DriverName, DD.VEHICLENUMBER AS VehicleNumber
            FROM DELIVERY_DETAILS DD
            INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
            INNER JOIN CUSTOMER C ON C.CUSTOMERID = SO.CUSTOMERID
            LEFT JOIN PRODUCT PR ON PR.PRODUCTID = DD.PRODUCTID
            LEFT JOIN EMPLOYEE E ON E.EMPLOYEEID = DD.DRIVERID
            WHERE SO.LOCATIONID = @LocationId
              AND CAST(DD.CREATE_DATE AS DATE) BETWEEN @FromDate AND @ToDate
              AND (@CustomerId IS NULL OR SO.CUSTOMERID = @CustomerId)
            ORDER BY DD.CREATE_DATE DESC, DD.DELIVERYID DESC
            """,
            new { LocationId = locationId, CustomerId = customerId, FromDate = fromDate.Date, ToDate = toDate.Date });

        return rows.ToList();
    }
}
