namespace AMSEL.MobileApi.Data.Dto;

public record SalesEntryOptionDto(
    string SourceType,
    string EntryNo,
    string CustomerName,
    DateTime EntryDate,
    decimal TotalQty,
    decimal TotalAmount,
    bool CustomerHasGst,
    int? TripEntryId);

public record SalesEntrySourceDto(string SourceType, string EntryNo);

public record CreateSalesEntryRequest(IReadOnlyList<SalesEntrySourceDto> Sources);

public record CreateSalesEntryResponse(IReadOnlyList<string> EntryNumbers);
