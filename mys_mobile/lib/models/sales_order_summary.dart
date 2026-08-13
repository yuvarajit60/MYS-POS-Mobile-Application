class SalesOrderSummary {
  final int salesOrderId;
  final String entryNo;
  final DateTime entryDate;
  final String customerName;
  final String mobileNo;
  final double netAmount;

  SalesOrderSummary({
    required this.salesOrderId,
    required this.entryNo,
    required this.entryDate,
    required this.customerName,
    required this.mobileNo,
    required this.netAmount,
  });

  factory SalesOrderSummary.fromJson(Map<String, dynamic> json) => SalesOrderSummary(
        salesOrderId: json['salesOrderId'] as int,
        entryNo: json['entryNo'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String),
        customerName: json['customerName'] as String,
        mobileNo: json['mobileNo'] as String? ?? '',
        netAmount: (json['netAmount'] as num).toDouble(),
      );
}
