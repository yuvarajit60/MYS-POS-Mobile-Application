namespace AMSEL.MobileApi.Data.Dto;

public record PendingDeliveryLineDto(
    int SalesOrderDetId,
    int SalesOrderId,
    string SalesOrderNo,
    int ProductId,
    string ProductName,
    decimal SalesQty,
    decimal DeliveryQty,
    decimal BalanceQty);

public record DeliveryLineRequest(int SalesOrderDetId, int SalesOrderId, int ProductId, decimal CurrentDelivery);

public record CreateDeliveryRequest(int DriverEmployeeId, string VehicleNumber, List<DeliveryLineRequest> Lines);

public record CreateDeliveryResponse(int LinesSaved, string DeliveryNo);
