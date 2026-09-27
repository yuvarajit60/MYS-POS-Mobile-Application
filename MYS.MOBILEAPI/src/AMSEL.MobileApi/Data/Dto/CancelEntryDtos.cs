namespace AMSEL.MobileApi.Data.Dto;

public record CancelEntryOptionDto(string EntryNo, string CustomerName, DateTime EntryDate, decimal TotalAmount);

public record CancelEntryRequest(string TransactionType, string EntryNo, DateTime CancelDate, string? Remarks);
