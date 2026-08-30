class DeliverySummary {
  final int deliveryId;
  final String deliveryNo;
  final DateTime deliveryDate;
  final String salesOrderNo;
  final String customerName;
  final String productName;
  final double deliveryQty;
  final double balanceQty;
  final String driverName;
  final String? vehicleNumber;

  DeliverySummary({
    required this.deliveryId,
    required this.deliveryNo,
    required this.deliveryDate,
    required this.salesOrderNo,
    required this.customerName,
    required this.productName,
    required this.deliveryQty,
    required this.balanceQty,
    required this.driverName,
    required this.vehicleNumber,
  });

  factory DeliverySummary.fromJson(Map<String, dynamic> json) => DeliverySummary(
        deliveryId: json['deliveryId'] as int,
        deliveryNo: json['deliveryNo'] as String? ?? '',
        deliveryDate: DateTime.parse(json['deliveryDate'] as String),
        salesOrderNo: json['salesOrderNo'] as String,
        customerName: json['customerName'] as String,
        productName: json['productName'] as String? ?? '',
        deliveryQty: (json['deliveryQty'] as num).toDouble(),
        balanceQty: (json['balanceQty'] as num).toDouble(),
        driverName: json['driverName'] as String? ?? '',
        vehicleNumber: json['vehicleNumber'] as String?,
      );
}
