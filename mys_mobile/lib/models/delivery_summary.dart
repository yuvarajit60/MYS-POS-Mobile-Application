class DeliverySummary {
  final String deliveryNo;
  final DateTime deliveryDate;
  final String customerName;
  final String driverName;
  final String? vehicleNumber;
  final double totalQty;
  final int lineCount;

  DeliverySummary({
    required this.deliveryNo,
    required this.deliveryDate,
    required this.customerName,
    required this.driverName,
    required this.vehicleNumber,
    required this.totalQty,
    required this.lineCount,
  });

  factory DeliverySummary.fromJson(Map<String, dynamic> json) => DeliverySummary(
        deliveryNo: json['deliveryNo'] as String,
        deliveryDate: DateTime.parse(json['deliveryDate'] as String),
        customerName: json['customerName'] as String,
        driverName: json['driverName'] as String? ?? '',
        vehicleNumber: json['vehicleNumber'] as String?,
        totalQty: (json['totalQty'] as num).toDouble(),
        lineCount: json['lineCount'] as int,
      );
}
