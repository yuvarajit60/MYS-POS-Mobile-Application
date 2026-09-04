import 'product.dart';

/// A row in the sales-order line-items grid. Qty and Rate are both mutable.
/// [Product.rate] is actually PRODUCT.MRP (tax-inclusive) — Rate here
/// defaults to the tax-EXCLUSIVE price backed out of that MRP (MRP / (1 +
/// GST%)), since MRP already includes GST and shouldn't have it added a
/// second time. The rep can still edit Rate per order. TotalAmount is
/// tax-inclusive (rate x qty, plus CGST/SGST on that amount) and, so long
/// as Rate is left at its default, comes back out to MRP x qty.
class SalesOrderLine {
  final Product product;
  double qty;
  double rate;

  SalesOrderLine({required this.product, this.qty = 1}) : rate = _taxExclusiveRate(product);

  /// The product's actual MRP, for display alongside the (possibly
  /// rep-edited) tax-exclusive Rate.
  double get mrp => product.rate;

  static double _taxExclusiveRate(Product product) {
    final gstPercent = product.salesCgstPercentage + product.salesSgstPercentage;
    return product.rate / (1 + gstPercent / 100);
  }

  double get taxableValue => rate * qty;

  double get cgstAmount => taxableValue * product.salesCgstPercentage / 100;

  double get sgstAmount => taxableValue * product.salesSgstPercentage / 100;

  double get totalAmount => taxableValue + cgstAmount + sgstAmount;
}
