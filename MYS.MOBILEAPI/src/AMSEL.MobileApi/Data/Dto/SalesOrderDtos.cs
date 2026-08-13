namespace AMSEL.MobileApi.Data.Dto;

public record SalesOrderLineRequest(int ProductId, decimal Qty, decimal Rate);

public record CreateSalesOrderRequest(
    int CustomerId,
    string CustomerName,
    string MobileNo,
    string ShippingAddress,
    List<SalesOrderLineRequest> Lines);

public record CreateSalesOrderResponse(int SalesOrderId, string EntryNo);
