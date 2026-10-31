namespace AMSEL.MobileApi.Data.Dto;

public record HeadDto(int HeadId, string HeadName, string IncomeOrExpenses);

public record CreateIncomeExpenseRequest(
    DateTime EntryDate,
    string IncomeOrExpenses,
    int HeadId,
    string? Particulars,
    decimal Amount,
    int? EmployeeId,
    int? VehicleId);

public record CreateIncomeExpenseResponse(string EntryNo);
