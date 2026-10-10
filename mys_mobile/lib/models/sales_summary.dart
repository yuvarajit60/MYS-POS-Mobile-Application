class SalesSummary {
  final int salesId;
  final String entryNo;
  final DateTime entryDate;
  final String customerName;
  final String mobileNo;
  final double netAmount;

  SalesSummary({
    required this.salesId,
    required this.entryNo,
    required this.entryDate,
    required this.customerName,
    required this.mobileNo,
    required this.netAmount,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
        salesId: json['salesId'] as int,
        entryNo: json['entryNo'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String),
        customerName: json['customerName'] as String? ?? '',
        mobileNo: json['mobileNo'] as String? ?? '',
        netAmount: (json['netAmount'] as num).toDouble(),
      );
}
