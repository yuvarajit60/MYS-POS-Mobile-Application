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
/// columns (Entry No/Date/Time/Type/Particulars/Amount), plus a mobile-only
/// RunningBalance per row (Income adds, Expenses subtracts from the
/// previous entry — same idea as the Customer Ledger's OUTSTANDINGAMOUNT,
/// see SP_MOBILE_GET_CUSTOMER_LEDGER), replacing the old "Grand Total =
/// sum of every row regardless of type" with a proper net total. The
/// running balance is computed chronologically (oldest first) over the
/// filtered rows, then the result is still returned newest-first to match
/// the existing report order — so the first row's balance is the period's
/// Net Total. No line items on this table, so a plain parameterized query
/// is enough — no stored procedure and no drill-down detail screen needed.
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
            ;WITH Filtered AS (
                SELECT IE.INCOMEOREXPENSESID, IE.ENTRYNO, IE.ENTRYDATE, IE.ENTRYTIME,
                       ISNULL(IE.INCOMEOREXPENSES, '') AS INCOMEOREXPENSES, ISNULL(IE.PARTICULARS, '') AS PARTICULARS,
                       IE.AMOUNT
                FROM INCOMEOREXPENSES IE
                WHERE IE.LOCATIONID = @LocationId
                  AND IE.CANCEL = 0
                  AND CAST(IE.ENTRYDATE AS DATE) BETWEEN @FromDate AND @ToDate
                  AND (@EntryNo IS NULL OR IE.ENTRYNO LIKE @Like)
            ),
            Running AS (
                SELECT *,
                    SUM(CASE WHEN INCOMEOREXPENSES = 'Income' THEN AMOUNT ELSE -AMOUNT END) OVER (
                        ORDER BY ENTRYDATE, ENTRYTIME, INCOMEOREXPENSESID
                        ROWS UNBOUNDED PRECEDING
                    ) AS RUNNINGBALANCE
                FROM Filtered
            )
            SELECT ENTRYNO AS EntryNo, ENTRYDATE AS EntryDate, ENTRYTIME AS EntryTime,
                   INCOMEOREXPENSES AS IncomeOrExpenses, PARTICULARS AS Particulars, AMOUNT AS Amount,
                   RUNNINGBALANCE AS RunningBalance
            FROM Running
            ORDER BY ENTRYDATE DESC, ENTRYTIME DESC, INCOMEOREXPENSESID DESC
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
