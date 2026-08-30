namespace AMSEL.MobileApi.Data.Dto;

public record DeliverySummaryDto(
    int DeliveryId,
    DateTime DeliveryDate,
    string SalesOrderNo,
    string CustomerName,
    string ProductName,
    decimal DeliveryQty,
    decimal BalanceQty,
    string DriverName,
    string? VehicleNumber);
