import 'product.dart';

/// A row in the sales-order line-items grid. Qty and Rate are both mutable —
/// Rate defaults to the product's MRP but the rep can edit it per order.
/// TotalAmount is tax-inclusive (rate x qty, plus CGST/SGST on that amount)
/// and always derived, never stored separately.
class SalesOrderLine {
  final Product product;
  double qty;
  double rate;

  SalesOrderLine({required this.product, this.qty = 1}) : rate = product.rate;

  double get taxableValue => rate * qty;

  double get cgstAmount => taxableValue * product.salesCgstPercentage / 100;

  double get sgstAmount => taxableValue * product.salesSgstPercentage / 100;

  double get totalAmount => taxableValue + cgstAmount + sgstAmount;
}
