namespace AMSEL.MobileApi.Data.Dto;

public record SalesOrderSummaryDto(
    int SalesOrderId,
    string EntryNo,
    DateTime EntryDate,
    string CustomerName,
    string MobileNo,
    decimal NetAmount);

public record OrderDetailLineDto(
    string ProductName,
    decimal Qty,
    decimal Rate,
    decimal TaxableValue,
    decimal CgstAmount,
    decimal SgstAmount,
    decimal TotalAmount);

public record OrderDetailDto(
    int SalesOrderId,
    string EntryNo,
    DateTime EntryDate,
    string CustomerName,
    string MobileNo,
    string ShippingAddress,
    decimal TaxableValue,
    decimal TotalTax,
    decimal RoundOff,
    decimal NetAmount,
    List<OrderDetailLineDto> Lines);

public record GraphDataPointDto(string Label, decimal TotalAmount);

public record EntryNumberDto(int SalesOrderId, string EntryNo);
