namespace AMSEL.MobileApi.Data.Dto;

public record LedgerEntryDto(
    DateTime TxnDate,
    string TxnType,
    string TxnNo,
    decimal TotalAmount,
    decimal ReceivedAmount,
    decimal OutstandingAmount);
