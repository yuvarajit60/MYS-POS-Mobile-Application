using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface ITripEntryReportService
{
    Task<IReadOnlyList<TripEntrySummaryDto>> GetSummaryAsync(int locationId, int? customerId, string? tripEntryNo, DateTime fromDate, DateTime toDate);
    Task<TripEntryDetailDto?> GetTripEntryDetailAsync(int locationId, int tripEntryId);
    Task<IReadOnlyList<GraphDataPointDto>> GetGraphDataAsync(int locationId, string groupBy, int? year);
    Task<IReadOnlyList<TripEntryNumberDto>> SearchTripEntryNumbersAsync(int locationId, string? search);
}

/// <summary>
/// Mirrors ReportService's Sales Order reports exactly, scoped to the
/// caller's own location and excluding cancelled trip entries. CUSTOMERNAME
/// isn't stored on TRIPENTRY itself (unlike SALESORDER), so it's always
/// joined from CUSTOMER via CUSTOMERID.
/// </summary>
public class TripEntryReportService : ITripEntryReportService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    private static readonly string[] MonthLabels =
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    public TripEntryReportService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<TripEntrySummaryDto>> GetSummaryAsync(
        int locationId, int? customerId, string? tripEntryNo, DateTime fromDate, DateTime toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{tripEntryNo}%";
        var rows = await connection.QueryAsync<TripEntrySummaryDto>(
            """
            SELECT TE.TRIPENTRYID AS TripEntryId, TE.ENTRYNO AS EntryNo, TE.ENTRYDATE AS EntryDate,
                   C.CUSTOMERNAME AS CustomerName, ISNULL(TE.MOBILENO, '') AS MobileNo,
                   ISNULL(TE.SITENAME, '') AS SiteName, ISNULL(EMP.EMPLOYEENAME, '') AS DriverName,
                   TE.NETAMOUNT AS NetAmount
            FROM TRIPENTRY TE
            INNER JOIN CUSTOMER C ON C.CUSTOMERID = TE.CUSTOMERID
            LEFT JOIN EMPLOYEE EMP ON EMP.EMPLOYEEID = TE.EMPLOYEEID
            WHERE TE.LOCATIONID = @LocationId
              AND TE.CANCEL = 0
              AND CAST(TE.ENTRYDATE AS DATE) BETWEEN @FromDate AND @ToDate
              AND (@CustomerId IS NULL OR TE.CUSTOMERID = @CustomerId)
              AND (@TripEntryNo IS NULL OR TE.ENTRYNO LIKE @Like)
            ORDER BY TE.ENTRYDATE DESC, TE.TRIPENTRYID DESC
            """,
            new
            {
                LocationId = locationId,
                CustomerId = customerId,
                TripEntryNo = tripEntryNo,
                Like = like,
                FromDate = fromDate.Date,
                ToDate = toDate.Date,
            });

        return rows.ToList();
    }

    public async Task<TripEntryDetailDto?> GetTripEntryDetailAsync(int locationId, int tripEntryId)
    {
        using var connection = _connectionFactory.CreateConnection();

        var header = await connection.QueryFirstOrDefaultAsync(
            """
            SELECT TE.TRIPENTRYID, TE.ENTRYNO, TE.ENTRYDATE, C.CUSTOMERNAME, ISNULL(TE.MOBILENO, '') AS MOBILENO,
                   ISNULL(TE.SITENAME, '') AS SITENAME, ISNULL(EMP.EMPLOYEENAME, '') AS DRIVERNAME,
                   TE.TAXABLEVALUE, TE.TOTALTAX, TE.ROUNDOFF, TE.NETAMOUNT
            FROM TRIPENTRY TE
            INNER JOIN CUSTOMER C ON C.CUSTOMERID = TE.CUSTOMERID
            LEFT JOIN EMPLOYEE EMP ON EMP.EMPLOYEEID = TE.EMPLOYEEID
            WHERE TE.TRIPENTRYID = @TripEntryId AND TE.LOCATIONID = @LocationId
            """,
            new { TripEntryId = tripEntryId, LocationId = locationId });

        if (header is null) return null;

        var lines = await connection.QueryAsync<TripEntryLineDetailDto>(
            """
            SELECT ISNULL(PR.PRODUCTNAME, '') AS ProductName, TD.QTY AS Qty, TD.RATE AS Rate,
                   TD.METERORHOURSID AS MeterOrHoursId, TD.TIMESTART AS TimeStart, TD.TIMECLOSE AS TimeClose,
                   TD.METERSTART AS MeterStart, TD.METERCLOSE AS MeterClose, V.VEHICLENAME AS VehicleName,
                   TD.TAXABLEVALUE AS TaxableValue, TD.CGSTAMOUNT AS CgstAmount, TD.SGSTAMOUNT AS SgstAmount,
                   TD.TOTALAMOUNT AS TotalAmount
            FROM TRIPENTRY_DETAILS TD
            LEFT JOIN PRODUCT PR ON PR.PRODUCTID = TD.PRODUCTID
            LEFT JOIN VEHICLE V ON V.VEHICLEID = TD.VEHICLEID
            WHERE TD.TRIPENTRYID = @TripEntryId
            ORDER BY TD.TRIPENTRYDETID
            """,
            new { TripEntryId = tripEntryId });

        return new TripEntryDetailDto(
            (int)header.TRIPENTRYID,
            (string)header.ENTRYNO,
            (DateTime)header.ENTRYDATE,
            (string)header.CUSTOMERNAME,
            (string)header.MOBILENO,
            (string)header.SITENAME,
            (string)header.DRIVERNAME,
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
                FROM TRIPENTRY
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
                FROM TRIPENTRY
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

    public async Task<IReadOnlyList<TripEntryNumberDto>> SearchTripEntryNumbersAsync(int locationId, string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<TripEntryNumberDto>(
            """
            SELECT TOP 50 TRIPENTRYID AS TripEntryId, ENTRYNO AS EntryNo
            FROM TRIPENTRY
            WHERE LOCATIONID = @LocationId
              AND CANCEL = 0
              AND (@Search IS NULL OR ENTRYNO LIKE @Like)
            ORDER BY ENTRYDATE DESC, TRIPENTRYID DESC
            """,
            new { LocationId = locationId, Search = search, Like = like });

        return rows.ToList();
    }
}
