namespace AMSEL.MobileApi.Data.Dto;

public record CancelEntryOptionDto(string EntryNo, string Description);

public record CancelEntryRequest(string TransactionType, string EntryNo, DateTime CancelDate, string? Remarks);
