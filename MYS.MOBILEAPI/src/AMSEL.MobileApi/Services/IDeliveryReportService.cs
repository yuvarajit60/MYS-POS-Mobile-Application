using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IDeliveryReportService
{
    Task<IReadOnlyList<DeliverySummaryDto>> GetSummaryAsync(int locationId, int? customerId, string? deliveryNo, DateTime fromDate, DateTime toDate);
    Task<DeliveryDetailDto?> GetDeliveryDetailAsync(int locationId, string deliveryNo);
    Task<IReadOnlyList<DeliveryNumberDto>> SearchDeliveryNumbersAsync(int locationId, string? search);
}

/// <summary>
/// DELIVERY_DETAILS has no header row, but every line saved from one
/// Delivery Entry submission shares the same DELIVERYNO (see
/// 005_delivery_entry.sql) — so this report groups by DELIVERYNO and
/// exposes a Summary/Detail drill-down, mirroring TripEntryReportService,
/// even though the underlying table itself is still flat.
/// </summary>
public class DeliveryReportService : IDeliveryReportService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public DeliveryReportService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<DeliverySummaryDto>> GetSummaryAsync(
        int locationId, int? customerId, string? deliveryNo, DateTime fromDate, DateTime toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{deliveryNo}%";
        var rows = await connection.QueryAsync<DeliverySummaryDto>(
            """
            SELECT DD.DELIVERYNO AS DeliveryNo, MIN(DD.CREATE_DATE) AS DeliveryDate,
                   MAX(C.CUSTOMERNAME) AS CustomerName, MAX(ISNULL(E.EMPLOYEENAME, '')) AS DriverName,
                   MAX(DD.VEHICLENUMBER) AS VehicleNumber, SUM(DD.DELIVERYQTY) AS TotalQty, COUNT(*) AS LineCount
            FROM DELIVERY_DETAILS DD
            INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
            INNER JOIN CUSTOMER C ON C.CUSTOMERID = SO.CUSTOMERID
            LEFT JOIN EMPLOYEE E ON E.EMPLOYEEID = DD.DRIVERID
            WHERE SO.LOCATIONID = @LocationId
              AND CAST(DD.CREATE_DATE AS DATE) BETWEEN @FromDate AND @ToDate
              AND (@CustomerId IS NULL OR SO.CUSTOMERID = @CustomerId)
              AND (@DeliveryNo IS NULL OR DD.DELIVERYNO LIKE @Like)
            GROUP BY DD.DELIVERYNO
            ORDER BY MIN(DD.CREATE_DATE) DESC
            """,
            new
            {
                LocationId = locationId,
                CustomerId = customerId,
                DeliveryNo = deliveryNo,
                Like = like,
                FromDate = fromDate.Date,
                ToDate = toDate.Date,
            });

        return rows.ToList();
    }

    private record DeliveryHeaderRow(string DeliveryNo, DateTime DeliveryDate, string CustomerName, string DriverName, string? VehicleNumber);

    public async Task<DeliveryDetailDto?> GetDeliveryDetailAsync(int locationId, string deliveryNo)
    {
        using var connection = _connectionFactory.CreateConnection();

        var header = await connection.QueryFirstOrDefaultAsync<DeliveryHeaderRow>(
            """
            SELECT TOP 1 DD.DELIVERYNO AS DeliveryNo, DD.CREATE_DATE AS DeliveryDate, C.CUSTOMERNAME AS CustomerName,
                   ISNULL(E.EMPLOYEENAME, '') AS DriverName, DD.VEHICLENUMBER AS VehicleNumber
            FROM DELIVERY_DETAILS DD
            INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
            INNER JOIN CUSTOMER C ON C.CUSTOMERID = SO.CUSTOMERID
            LEFT JOIN EMPLOYEE E ON E.EMPLOYEEID = DD.DRIVERID
            WHERE DD.DELIVERYNO = @DeliveryNo AND SO.LOCATIONID = @LocationId
            ORDER BY DD.DELIVERYID
            """,
            new { DeliveryNo = deliveryNo, LocationId = locationId });

        if (header is null) return null;

        var lines = await connection.QueryAsync<DeliveryLineDetailDto>(
            """
            SELECT SO.ENTRYNO AS SalesOrderNo, ISNULL(PR.PRODUCTNAME, '') AS ProductName,
                   DD.DELIVERYQTY AS DeliveryQty, DD.BALANCEQTY AS BalanceQty
            FROM DELIVERY_DETAILS DD
            INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
            LEFT JOIN PRODUCT PR ON PR.PRODUCTID = DD.PRODUCTID
            WHERE DD.DELIVERYNO = @DeliveryNo AND SO.LOCATIONID = @LocationId
            ORDER BY DD.DELIVERYID
            """,
            new { DeliveryNo = deliveryNo, LocationId = locationId });

        return new DeliveryDetailDto(header.DeliveryNo, header.DeliveryDate, header.CustomerName, header.DriverName, header.VehicleNumber, lines.ToList());
    }

    public async Task<IReadOnlyList<DeliveryNumberDto>> SearchDeliveryNumbersAsync(int locationId, string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<DeliveryNumberDto>(
            """
            SELECT DISTINCT TOP 50 DD.DELIVERYNO AS DeliveryNo
            FROM DELIVERY_DETAILS DD
            INNER JOIN SALESORDER SO ON SO.SALESORDERID = DD.SALESORDERID
            WHERE SO.LOCATIONID = @LocationId
              AND (@Search IS NULL OR DD.DELIVERYNO LIKE @Like)
            ORDER BY DD.DELIVERYNO DESC
            """,
            new { LocationId = locationId, Search = search, Like = like });

        return rows.ToList();
    }
}
