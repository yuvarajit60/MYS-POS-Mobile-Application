namespace AMSEL.MobileApi.Data.Dto;

public record IncomeExpenseSummaryDto(
    string EntryNo,
    DateTime EntryDate,
    DateTime EntryTime,
    string IncomeOrExpenses,
    string Particulars,
    decimal Amount);

public record IncomeExpenseEntryNumberDto(int IncomeOrExpensesId, string EntryNo);
