namespace AMSEL.MobileApi.Data.Dto;

public record HeadDetailDto(
    int HeadId,
    string HeadName,
    string PrintName,
    string IncomeOrExpenses,
    string? MappedMaster,
    bool Status);

public record CreateHeadRequest(string HeadName, string? PrintName, string IncomeOrExpenses, string? MappedMaster);

public record UpdateHeadRequest(string HeadName, string? PrintName, string IncomeOrExpenses, string? MappedMaster, bool Status);
