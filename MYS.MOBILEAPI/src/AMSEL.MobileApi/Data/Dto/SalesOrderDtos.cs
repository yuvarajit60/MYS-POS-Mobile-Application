namespace AMSEL.MobileApi.Data.Dto;

public record SalesOrderLineRequest(int ProductId, decimal Qty, decimal Rate, decimal DiscountAmount = 0);

public record CreateSalesOrderRequest(
    int CustomerId,
    string CustomerName,
    string MobileNo,
    string ShippingAddress,
    int? SiteId,
    List<SalesOrderLineRequest> Lines);

public record CreateSalesOrderResponse(int SalesOrderId, string EntryNo);
