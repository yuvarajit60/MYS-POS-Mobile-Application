using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ISalesReportService
{
    Task<IReadOnlyList<SalesSummaryDto>> GetSummaryAsync(int locationId, int? customerId, string? salesNo, DateTime fromDate, DateTime toDate);
    Task<SalesDetailDto?> GetSalesDetailAsync(int locationId, int salesId);
    Task<IReadOnlyList<SalesEntryNumberDto>> SearchEntryNumbersAsync(int locationId, string? search);
}

/// <summary>
/// Reports on dbo.SALES (see Sales Entry, which creates these rows by
/// consolidating Delivery/Trip Entry activity) — mirrors ReportService's
/// Sales Order reports exactly, scoped to the caller's own location and
/// excluding cancelled Sales entries.
/// </summary>
public class SalesReportService : ISalesReportService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public SalesReportService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<SalesSummaryDto>> GetSummaryAsync(
        int locationId, int? customerId, string? salesNo, DateTime fromDate, DateTime toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{salesNo}%";
        var rows = await connection.QueryAsync<SalesSummaryDto>(
            """
            SELECT S.SALESID AS SalesId, S.ENTRYNO AS EntryNo, S.ENTRYDATE AS EntryDate,
                   ISNULL(S.CUSTOMERNAME, '') AS CustomerName, ISNULL(S.MOBILENO, '') AS MobileNo, S.NETAMOUNT AS NetAmount
            FROM SALES S
            WHERE S.LOCATIONID = @LocationId
              AND S.CANCEL = 0
              AND CAST(S.ENTRYDATE AS DATE) BETWEEN @FromDate AND @ToDate
              AND (@CustomerId IS NULL OR S.CUSTOMERID = @CustomerId)
              AND (@SalesNo IS NULL OR S.ENTRYNO LIKE @Like)
            ORDER BY S.ENTRYDATE DESC, S.SALESID DESC
            """,
            new
            {
                LocationId = locationId,
                CustomerId = customerId,
                SalesNo = salesNo,
                Like = like,
                FromDate = fromDate.Date,
                ToDate = toDate.Date,
            });

        return rows.ToList();
    }

    public async Task<SalesDetailDto?> GetSalesDetailAsync(int locationId, int salesId)
    {
        using var connection = _connectionFactory.CreateConnection();

        var header = await connection.QueryFirstOrDefaultAsync(
            """
            SELECT SALESID, ENTRYNO, ENTRYDATE, ISNULL(CUSTOMERNAME, '') AS CUSTOMERNAME, ISNULL(MOBILENO, '') AS MOBILENO,
                   TAXABLEVALUE, TOTALTAX, ROUNDOFF, NETAMOUNT
            FROM SALES
            WHERE SALESID = @SalesId AND LOCATIONID = @LocationId
            """,
            new { SalesId = salesId, LocationId = locationId });

        if (header is null) return null;

        var lines = await connection.QueryAsync<SalesDetailLineDto>(
            """
            SELECT ISNULL(PR.PRODUCTNAME, '') AS ProductName, SD.QTY AS Qty, SD.RATE AS Rate,
                   SD.TAXABLEVALUE AS TaxableValue, SD.CGSTAMOUNT AS CgstAmount, SD.SGSTAMOUNT AS SgstAmount,
                   SD.TOTALAMOUNT AS TotalAmount
            FROM SALES_DETAILS SD
            LEFT JOIN PRODUCT PR ON PR.PRODUCTID = SD.PRODUCTID
            WHERE SD.SALESID = @SalesId
            ORDER BY SD.SALESDETID
            """,
            new { SalesId = salesId });

        return new SalesDetailDto(
            (int)header.SALESID,
            (string)header.ENTRYNO,
            (DateTime)header.ENTRYDATE,
            (string)header.CUSTOMERNAME,
            (string)header.MOBILENO,
            (decimal)header.TAXABLEVALUE,
            (decimal)header.TOTALTAX,
            (decimal)header.ROUNDOFF,
            (decimal)header.NETAMOUNT,
            lines.ToList());
    }

    public async Task<IReadOnlyList<SalesEntryNumberDto>> SearchEntryNumbersAsync(int locationId, string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<SalesEntryNumberDto>(
            """
            SELECT TOP 50 SALESID AS SalesId, ENTRYNO AS EntryNo
            FROM SALES
            WHERE LOCATIONID = @LocationId
              AND CANCEL = 0
              AND (@Search IS NULL OR ENTRYNO LIKE @Like)
            ORDER BY ENTRYDATE DESC, SALESID DESC
            """,
            new { LocationId = locationId, Search = search, Like = like });

        return rows.ToList();
    }
}
