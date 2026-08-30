/// A row in the Delivery Entry grid — one pending (undelivered) Sales
/// Order line. [currentDelivery] is the only mutable/user-entered field;
/// everything else is a read-only snapshot of what's already on record.
/// [currentDelivery] must never exceed [balanceQty] (enforced in the UI,
/// and re-validated server-side since this is a one-shot, non-editable
/// entry once saved).
class DeliveryLine {
  final int salesOrderDetId;
  final int salesOrderId;
  final String salesOrderNo;
  final int productId;
  final String productName;
  final double salesQty;
  final double deliveryQty;
  final double balanceQty;
  double currentDelivery;

  DeliveryLine({
    required this.salesOrderDetId,
    required this.salesOrderId,
    required this.salesOrderNo,
    required this.productId,
    required this.productName,
    required this.salesQty,
    required this.deliveryQty,
    required this.balanceQty,
    this.currentDelivery = 0,
  });

  factory DeliveryLine.fromJson(Map<String, dynamic> json) => DeliveryLine(
        salesOrderDetId: json['salesOrderDetId'] as int,
        salesOrderId: json['salesOrderId'] as int,
        salesOrderNo: json['salesOrderNo'] as String,
        productId: json['productId'] as int,
        productName: json['productName'] as String? ?? '',
        salesQty: (json['salesQty'] as num).toDouble(),
        deliveryQty: (json['deliveryQty'] as num).toDouble(),
        balanceQty: (json['balanceQty'] as num).toDouble(),
      );
}
