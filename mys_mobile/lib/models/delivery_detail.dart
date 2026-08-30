class DeliveryDetailLine {
  final String salesOrderNo;
  final String productName;
  final double deliveryQty;
  final double balanceQty;

  DeliveryDetailLine({
    required this.salesOrderNo,
    required this.productName,
    required this.deliveryQty,
    required this.balanceQty,
  });

  factory DeliveryDetailLine.fromJson(Map<String, dynamic> json) => DeliveryDetailLine(
        salesOrderNo: json['salesOrderNo'] as String,
        productName: json['productName'] as String? ?? '',
        deliveryQty: (json['deliveryQty'] as num).toDouble(),
        balanceQty: (json['balanceQty'] as num).toDouble(),
      );
}

class DeliveryDetail {
  final String deliveryNo;
  final DateTime deliveryDate;
  final String customerName;
  final String driverName;
  final String? vehicleNumber;
  final List<DeliveryDetailLine> lines;

  DeliveryDetail({
    required this.deliveryNo,
    required this.deliveryDate,
    required this.customerName,
    required this.driverName,
    required this.vehicleNumber,
    required this.lines,
  });

  factory DeliveryDetail.fromJson(Map<String, dynamic> json) => DeliveryDetail(
        deliveryNo: json['deliveryNo'] as String,
        deliveryDate: DateTime.parse(json['deliveryDate'] as String),
        customerName: json['customerName'] as String,
        driverName: json['driverName'] as String? ?? '',
        vehicleNumber: json['vehicleNumber'] as String?,
        lines: (json['lines'] as List).map((e) => DeliveryDetailLine.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
