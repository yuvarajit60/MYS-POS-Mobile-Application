class LedgerAllCustomersRow {
  final DateTime txnDate;
  final String customerName;
  final String txnType;
  final String txnNo;
  final double qty;
  final double totalAmount;
  final double receivedAmount;
  final double outstandingAmount;

  LedgerAllCustomersRow({
    required this.txnDate,
    required this.customerName,
    required this.txnType,
    required this.txnNo,
    required this.qty,
    required this.totalAmount,
    required this.receivedAmount,
    required this.outstandingAmount,
  });

  factory LedgerAllCustomersRow.fromJson(Map<String, dynamic> json) => LedgerAllCustomersRow(
        txnDate: DateTime.parse(json['txnDate'] as String),
        customerName: json['customerName'] as String? ?? '',
        txnType: json['txnType'] as String,
        txnNo: json['txnNo'] as String,
        qty: (json['qty'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        receivedAmount: (json['receivedAmount'] as num).toDouble(),
        outstandingAmount: (json['outstandingAmount'] as num).toDouble(),
      );
}
