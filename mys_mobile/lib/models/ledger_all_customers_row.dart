class LedgerAllCustomersRow {
  final String customerName;
  final String txnType;
  final double qty;
  final double totalAmount;
  final double receivedAmount;
  final double outstandingAmount;

  LedgerAllCustomersRow({
    required this.customerName,
    required this.txnType,
    required this.qty,
    required this.totalAmount,
    required this.receivedAmount,
    required this.outstandingAmount,
  });

  factory LedgerAllCustomersRow.fromJson(Map<String, dynamic> json) => LedgerAllCustomersRow(
        customerName: json['customerName'] as String? ?? '',
        txnType: json['txnType'] as String,
        qty: (json['qty'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        receivedAmount: (json['receivedAmount'] as num).toDouble(),
        outstandingAmount: (json['outstandingAmount'] as num).toDouble(),
      );
}
