class LedgerEntry {
  final DateTime txnDate;
  final String txnType;
  final String txnNo;
  final double totalAmount;
  final double receivedAmount;
  final double outstandingAmount;

  LedgerEntry({
    required this.txnDate,
    required this.txnType,
    required this.txnNo,
    required this.totalAmount,
    required this.receivedAmount,
    required this.outstandingAmount,
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        txnDate: DateTime.parse(json['txnDate'] as String),
        txnType: json['txnType'] as String,
        txnNo: json['txnNo'] as String,
        totalAmount: (json['totalAmount'] as num).toDouble(),
        receivedAmount: (json['receivedAmount'] as num).toDouble(),
        outstandingAmount: (json['outstandingAmount'] as num).toDouble(),
      );
}
