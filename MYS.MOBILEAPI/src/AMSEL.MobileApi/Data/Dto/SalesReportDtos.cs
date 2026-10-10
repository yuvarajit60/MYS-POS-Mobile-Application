namespace AMSEL.MobileApi.Data.Dto;

public record SalesSummaryDto(
    int SalesId,
    string EntryNo,
    DateTime EntryDate,
    string CustomerName,
    string MobileNo,
    decimal NetAmount);

public record SalesDetailLineDto(
    string ProductName,
    decimal Qty,
    decimal Rate,
    decimal TaxableValue,
    decimal CgstAmount,
    decimal SgstAmount,
    decimal TotalAmount);

public record SalesDetailDto(
    int SalesId,
    string EntryNo,
    DateTime EntryDate,
    string CustomerName,
    string MobileNo,
    decimal TaxableValue,
    decimal TotalTax,
    decimal RoundOff,
    decimal NetAmount,
    List<SalesDetailLineDto> Lines);

public record SalesEntryNumberDto(int SalesId, string EntryNo);
