import 'product.dart';

/// A row in the sales-order line-items grid. Qty, MRP, and Rate are all
/// mutable and kept in sync by whichever the rep edits last: MRP is
/// tax-inclusive, Rate is tax-exclusive (MRP / (1 + GST%)), so editing
/// either one recomputes the other from the product's own GST%. Both
/// default from [Product.rate], which is actually PRODUCT.MRP.
///
/// [discountEnabled] swaps the Rate field for a flat Discount Amount
/// (tax-exclusive, subtracted from Rate x Qty before tax) — Rate itself
/// stops being rep-editable while a discount is active and just tracks
/// MRP as usual. Disabling the discount reverts to the undiscounted
/// calculation (discountAmount is reset to 0, matching pre-discount
/// behavior exactly since a zero discount is a no-op).
///
/// TotalAmount is tax-inclusive (taxable value x qty, plus CGST/SGST on
/// that amount) and, so long as Rate/MRP are left at their defaults and
/// no discount is active, comes back out to MRP x qty.
class SalesOrderLine {
  final Product product;
  double qty;
  double mrp;
  double rate;
  bool discountEnabled;
  double discountAmount;

  SalesOrderLine({required this.product, this.qty = 1})
      : mrp = product.rate,
        rate = _taxExclusiveRate(product.rate, _gstPercent(product)),
        discountEnabled = false,
        discountAmount = 0;

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

  void setDiscountEnabled(bool enabled) {
    discountEnabled = enabled;
    if (!enabled) discountAmount = 0;
  }

  void updateFromDiscount(double newDiscount) {
    discountAmount = newDiscount < 0 ? 0 : newDiscount;
  }

  static double _gstPercent(Product product) => product.salesCgstPercentage + product.salesSgstPercentage;

  static double _taxExclusiveRate(double mrp, double gstPercent) => mrp / (1 + gstPercent / 100);

  double get grossAmount => rate * qty;

  double get taxableValue {
    if (!discountEnabled) return grossAmount;
    final net = grossAmount - discountAmount;
    return net < 0 ? 0 : net;
  }

  double get cgstAmount => taxableValue * product.salesCgstPercentage / 100;

  double get sgstAmount => taxableValue * product.salesSgstPercentage / 100;

  double get totalAmount => taxableValue + cgstAmount + sgstAmount;
}
