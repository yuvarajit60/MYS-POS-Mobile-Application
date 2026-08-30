namespace AMSEL.MobileApi.Data.Dto;

public record DeliverySummaryDto(
    string DeliveryNo,
    DateTime DeliveryDate,
    string CustomerName,
    string DriverName,
    string? VehicleNumber,
    decimal TotalQty,
    int LineCount);

public record DeliveryLineDetailDto(
    string SalesOrderNo,
    string ProductName,
    decimal DeliveryQty,
    decimal BalanceQty);

public record DeliveryDetailDto(
    string DeliveryNo,
    DateTime DeliveryDate,
    string CustomerName,
    string DriverName,
    string? VehicleNumber,
    List<DeliveryLineDetailDto> Lines);

public record DeliveryNumberDto(string DeliveryNo);
