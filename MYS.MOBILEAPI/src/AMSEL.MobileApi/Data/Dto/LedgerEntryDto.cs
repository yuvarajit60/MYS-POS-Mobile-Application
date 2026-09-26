namespace AMSEL.MobileApi.Data.Dto;

public record LedgerEntryDto(
    DateTime TxnDate,
    string TxnType,
    string TxnNo,
    decimal TotalAmount,
    decimal ReceivedAmount,
    decimal OutstandingAmount);

/// <summary>
/// One row of the all-customers ledger register, shown instead of a single
/// customer's running ledger when no customer is selected in the filter.
/// Unlike LedgerEntryDto's OutstandingAmount (a running balance within one
/// customer's history), this one is row-level (TotalAmount - ReceivedAmount)
/// since rows from different customers are interleaved chronologically —
/// a running total across customers wouldn't mean anything.
/// </summary>
public record LedgerAllCustomersRowDto(
    DateTime TxnDate,
    string CustomerName,
    string TxnType,
    string TxnNo,
    decimal Qty,
    decimal TotalAmount,
    decimal ReceivedAmount,
    decimal OutstandingAmount);
