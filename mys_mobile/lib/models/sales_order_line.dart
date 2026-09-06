import 'product.dart';

/// A row in the sales-order line-items grid. Qty, MRP, and Rate are all
/// mutable and kept in sync by whichever the rep edits last: MRP is
/// tax-inclusive, Rate is tax-exclusive (MRP / (1 + GST%)), so editing
/// either one recomputes the other from the product's own GST%. Both
/// default from [Product.rate], which is actually PRODUCT.MRP.
/// TotalAmount is tax-inclusive (rate x qty, plus CGST/SGST on that
/// amount) and, so long as Rate/MRP are left at their defaults, comes
/// back out to MRP x qty.
class SalesOrderLine {
  final Product product;
  double qty;
  double mrp;
  double rate;

  SalesOrderLine({required this.product, this.qty = 1})
      : mrp = product.rate,
        rate = _taxExclusiveRate(product.rate, _gstPercent(product));

  double get _gstPercentValue => _gstPercent(product);

  /// Rep edited MRP (tax-inclusive) — back out the new tax-exclusive Rate.
  void updateFromMrp(double newMrp) {
    mrp = newMrp;
    rate = _taxExclusiveRate(newMrp, _gstPercentValue);
  }

  /// Rep edited Rate (tax-exclusive) — gross it back up to the new MRP.
  void updateFromRate(double newRate) {
    rate = newRate;
    mrp = newRate * (1 + _gstPercentValue / 100);
  }

  static double _gstPercent(Product product) => product.salesCgstPercentage + product.salesSgstPercentage;

  static double _taxExclusiveRate(double mrp, double gstPercent) => mrp / (1 + gstPercent / 100);

  double get taxableValue => rate * qty;

  double get cgstAmount => taxableValue * product.salesCgstPercentage / 100;

  double get sgstAmount => taxableValue * product.salesSgstPercentage / 100;

  double get totalAmount => taxableValue + cgstAmount + sgstAmount;
}
