namespace AMSEL.MobileApi.Data.Dto;

public record LedgerEntryDto(
    DateTime TxnDate,
    string TxnType,
    string TxnNo,
    decimal TotalAmount,
    decimal ReceivedAmount,
    decimal OutstandingAmount);

/// <summary>Shown instead of a per-customer ledger when no customer is selected in the filter.</summary>
public record LedgerSummaryDto(
    int TotalCustomers,
    decimal TotalDeliveryAmount,
    decimal TotalTripEntryAmount,
    decimal TotalPaymentAmount);
