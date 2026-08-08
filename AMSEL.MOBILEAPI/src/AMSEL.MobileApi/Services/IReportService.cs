using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IReportService
{
    Task<IReadOnlyList<SalesOrderSummaryDto>> GetSummaryAsync(int locationId, int? customerId, string? salesOrderNo, DateTime fromDate, DateTime toDate);
    Task<OrderDetailDto?> GetOrderDetailAsync(int locationId, int salesOrderId);
    Task<IReadOnlyList<GraphDataPointDto>> GetGraphDataAsync(int locationId, string groupBy, int? year);
    Task<IReadOnlyList<EntryNumberDto>> SearchEntryNumbersAsync(int locationId, string? search);
}

/// <summary>
/// Reports scope to the caller's own location and exclude cancelled orders,
/// matching how the rest of the mobile API is location-scoped.
/// </summary>
public class ReportService : IReportService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    private static readonly string[] MonthLabels =
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    public ReportService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<SalesOrderSummaryDto>> GetSummaryAsync(
        int locationId, int? customerId, string? salesOrderNo, DateTime fromDate, DateTime toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{salesOrderNo}%";
        var rows = await connection.QueryAsync<SalesOrderSummaryDto>(
            """
            SELECT SO.SALESORDERID AS SalesOrderId, SO.ENTRYNO AS EntryNo, SO.ENTRYDATE AS EntryDate,
                   SO.CUSTOMERNAME AS CustomerName, ISNULL(SO.MOBILENO, '') AS MobileNo, SO.NETAMOUNT AS NetAmount
            FROM SALESORDER SO
            WHERE SO.LOCATIONID = @LocationId
              AND SO.CANCEL = 0
              AND CAST(SO.ENTRYDATE AS DATE) BETWEEN @FromDate AND @ToDate
              AND (@CustomerId IS NULL OR SO.CUSTOMERID = @CustomerId)
              AND (@SalesOrderNo IS NULL OR SO.ENTRYNO LIKE @Like)
            ORDER BY SO.ENTRYDATE DESC, SO.SALESORDERID DESC
            """,
            new
            {
                LocationId = locationId,
                CustomerId = customerId,
                SalesOrderNo = salesOrderNo,
                Like = like,
                FromDate = fromDate.Date,
                ToDate = toDate.Date,
            });

        return rows.ToList();
    }

    public async Task<OrderDetailDto?> GetOrderDetailAsync(int locationId, int salesOrderId)
    {
        using var connection = _connectionFactory.CreateConnection();

        var header = await connection.QueryFirstOrDefaultAsync(
            """
            SELECT SALESORDERID, ENTRYNO, ENTRYDATE, CUSTOMERNAME, ISNULL(MOBILENO, '') AS MOBILENO,
                   ISNULL(SHIPPINGADDRESS, '') AS SHIPPINGADDRESS, TAXABLEVALUE, TOTALTAX, ROUNDOFF, NETAMOUNT
            FROM SALESORDER
            WHERE SALESORDERID = @SalesOrderId AND LOCATIONID = @LocationId
            """,
            new { SalesOrderId = salesOrderId, LocationId = locationId });

        if (header is null) return null;

        var lines = await connection.QueryAsync<OrderDetailLineDto>(
            """
            SELECT ISNULL(PR.PRODUCTNAME, '') AS ProductName, SD.QTY AS Qty, SD.RATE AS Rate,
                   SD.TAXABLEVALUE AS TaxableValue, SD.CGSTAMOUNT AS CgstAmount, SD.SGSTAMOUNT AS SgstAmount,
                   SD.TOTALAMOUNT AS TotalAmount
            FROM SALESORDER_DETAILS SD
            LEFT JOIN PRODUCT PR ON PR.PRODUCTID = SD.PRODUCTID
            WHERE SD.SALESORDERID = @SalesOrderId
            ORDER BY SD.SALESORDERDETID
            """,
            new { SalesOrderId = salesOrderId });

        return new OrderDetailDto(
            (int)header.SALESORDERID,
            (string)header.ENTRYNO,
            (DateTime)header.ENTRYDATE,
            (string)header.CUSTOMERNAME,
            (string)header.MOBILENO,
            (string)header.SHIPPINGADDRESS,
            (decimal)header.TAXABLEVALUE,
            (decimal)header.TOTALTAX,
            (decimal)header.ROUNDOFF,
            (decimal)header.NETAMOUNT,
            lines.ToList());
    }

    public async Task<IReadOnlyList<GraphDataPointDto>> GetGraphDataAsync(int locationId, string groupBy, int? year)
    {
        using var connection = _connectionFactory.CreateConnection();

        if (string.Equals(groupBy, "year", StringComparison.OrdinalIgnoreCase))
        {
            var rows = await connection.QueryAsync<(int Year, decimal Total)>(
                """
                SELECT YEAR(ENTRYDATE) AS Year, SUM(NETAMOUNT) AS Total
                FROM SALESORDER
                WHERE LOCATIONID = @LocationId AND CANCEL = 0
                GROUP BY YEAR(ENTRYDATE)
                ORDER BY YEAR(ENTRYDATE)
                """,
                new { LocationId = locationId });

            return rows.Select(r => new GraphDataPointDto(r.Year.ToString(), r.Total)).ToList();
        }
        else
        {
            var targetYear = year ?? DateTime.Now.Year;
            var rows = (await connection.QueryAsync<(int Month, decimal Total)>(
                """
                SELECT MONTH(ENTRYDATE) AS Month, SUM(NETAMOUNT) AS Total
                FROM SALESORDER
                WHERE LOCATIONID = @LocationId AND CANCEL = 0 AND YEAR(ENTRYDATE) = @Year
                GROUP BY MONTH(ENTRYDATE)
                """,
                new { LocationId = locationId, Year = targetYear }))
                .ToDictionary(r => r.Month, r => r.Total);

            return Enumerable.Range(1, 12)
                .Select(m => new GraphDataPointDto(MonthLabels[m - 1], rows.GetValueOrDefault(m, 0)))
                .ToList();
        }
    }

    public async Task<IReadOnlyList<EntryNumberDto>> SearchEntryNumbersAsync(int locationId, string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<EntryNumberDto>(
            """
            SELECT TOP 50 SALESORDERID AS SalesOrderId, ENTRYNO AS EntryNo
            FROM SALESORDER
            WHERE LOCATIONID = @LocationId
              AND CANCEL = 0
              AND (@Search IS NULL OR ENTRYNO LIKE @Like)
            ORDER BY ENTRYDATE DESC, SALESORDERID DESC
            """,
            new { LocationId = locationId, Search = search, Like = like });

        return rows.ToList();
    }
}
