namespace AMSEL.MobileApi.Data.Dto;

public record CreatePaymentRequest(int CustomerId, decimal Amount, DateTime PaymentDate, string PaymentType = "Cash");

public record CreatePaymentResponse(string PaymentNo);
