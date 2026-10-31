using AMSEL.MobileApi.Data;
using AMSEL.MobileApi.Data.Dto;
using Dapper;

namespace AMSEL.MobileApi.Services;

public interface IIncomeExpenseReportService
{
    Task<IReadOnlyList<IncomeExpenseSummaryDto>> GetSummaryAsync(int locationId, string? entryNo, DateTime fromDate, DateTime toDate);
    Task<IReadOnlyList<IncomeExpenseEntryNumberDto>> SearchEntryNumbersAsync(int locationId, string? search);
}

/// <summary>
/// Flat list of dbo.INCOMEOREXPENSES rows (see Income or Expenses) —
/// mirrors the desktop app's own "Income And Expense Document" report
/// (same columns: Entry No/Date/Time/Type/Particulars/Amount, same Grand
/// Total = sum of every row regardless of Income vs Expenses). No line
/// items on this table, so a plain parameterized query is enough — no
/// stored procedure and no drill-down detail screen needed.
/// </summary>
public class IncomeExpenseReportService : IIncomeExpenseReportService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public IncomeExpenseReportService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IReadOnlyList<IncomeExpenseSummaryDto>> GetSummaryAsync(
        int locationId, string? entryNo, DateTime fromDate, DateTime toDate)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{entryNo}%";
        var rows = await connection.QueryAsync<IncomeExpenseSummaryDto>(
            """
            SELECT IE.ENTRYNO AS EntryNo, IE.ENTRYDATE AS EntryDate, IE.ENTRYTIME AS EntryTime,
                   ISNULL(IE.INCOMEOREXPENSES, '') AS IncomeOrExpenses, ISNULL(IE.PARTICULARS, '') AS Particulars,
                   IE.AMOUNT AS Amount
            FROM INCOMEOREXPENSES IE
            WHERE IE.LOCATIONID = @LocationId
              AND IE.CANCEL = 0
              AND CAST(IE.ENTRYDATE AS DATE) BETWEEN @FromDate AND @ToDate
              AND (@EntryNo IS NULL OR IE.ENTRYNO LIKE @Like)
            ORDER BY IE.ENTRYDATE DESC, IE.INCOMEOREXPENSESID DESC
            """,
            new
            {
                LocationId = locationId,
                EntryNo = entryNo,
                Like = like,
                FromDate = fromDate.Date,
                ToDate = toDate.Date,
            });

        return rows.ToList();
    }

    public async Task<IReadOnlyList<IncomeExpenseEntryNumberDto>> SearchEntryNumbersAsync(int locationId, string? search)
    {
        using var connection = _connectionFactory.CreateConnection();
        var like = $"%{search}%";
        var rows = await connection.QueryAsync<IncomeExpenseEntryNumberDto>(
            """
            SELECT TOP 50 INCOMEOREXPENSESID AS IncomeOrExpensesId, ENTRYNO AS EntryNo
            FROM INCOMEOREXPENSES
            WHERE LOCATIONID = @LocationId
              AND CANCEL = 0
              AND (@Search IS NULL OR ENTRYNO LIKE @Like)
            ORDER BY ENTRYDATE DESC, INCOMEOREXPENSESID DESC
            """,
            new { LocationId = locationId, Search = search, Like = like });

        return rows.ToList();
    }
}
