namespace AMSEL.MobileApi.Data.Dto;

public record CreatePaymentRequest(int CustomerId, decimal Amount);

public record CreatePaymentResponse(string PaymentNo);
