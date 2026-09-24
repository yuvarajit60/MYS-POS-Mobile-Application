namespace AMSEL.MobileApi.Data.Dto;

public record CreatePaymentRequest(int CustomerId, decimal Amount, string PaymentType = "Cash", DateTime? PaymentDate = null);

public record CreatePaymentResponse(string PaymentNo);
