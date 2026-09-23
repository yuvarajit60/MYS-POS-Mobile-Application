class PaymentReportEntry {
  final String paymentNo;
  final String customerName;
  final DateTime paymentDate;
  final String paymentType;
  final double amount;

  PaymentReportEntry({
    required this.paymentNo,
    required this.customerName,
    required this.paymentDate,
    required this.paymentType,
    required this.amount,
  });

  factory PaymentReportEntry.fromJson(Map<String, dynamic> json) => PaymentReportEntry(
        paymentNo: json['paymentNo'] as String,
        customerName: json['customerName'] as String,
        paymentDate: DateTime.parse(json['paymentDate'] as String),
        paymentType: json['paymentType'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}
