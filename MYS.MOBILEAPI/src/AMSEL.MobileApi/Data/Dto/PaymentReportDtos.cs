namespace AMSEL.MobileApi.Data.Dto;

public record PaymentReportEntryDto(
    string PaymentNo,
    string CustomerName,
    DateTime PaymentDate,
    string PaymentType,
    decimal Amount);
