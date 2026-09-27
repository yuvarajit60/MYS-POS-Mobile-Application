namespace AMSEL.MobileApi.Data.Dto;

public record LedgerEntryDto(
    DateTime TxnDate,
    string TxnType,
    string TxnNo,
    decimal TotalAmount,
    decimal ReceivedAmount,
    decimal OutstandingAmount);

/// <summary>
/// One row of the all-customers ledger summary, shown instead of a single
/// customer's running ledger when no customer is selected in the filter —
/// Qty/TotalAmount/ReceivedAmount/OutstandingAmount aggregated per Customer
/// + TxnType (no per-transaction EntryDate/EntryNo — this is a summary, not
/// a transaction register), sorted by customer name alphabetically.
/// </summary>
public record LedgerAllCustomersRowDto(
    string CustomerName,
    string TxnType,
    decimal Qty,
    decimal TotalAmount,
    decimal ReceivedAmount,
    decimal OutstandingAmount);
