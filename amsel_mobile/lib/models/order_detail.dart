class OrderDetailLine {
  final String productName;
  final double qty;
  final double rate;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double totalAmount;

  OrderDetailLine({
    required this.productName,
    required this.qty,
    required this.rate,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalAmount,
  });

  factory OrderDetailLine.fromJson(Map<String, dynamic> json) => OrderDetailLine(
        productName: json['productName'] as String,
        qty: (json['qty'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        taxableValue: (json['taxableValue'] as num).toDouble(),
        cgstAmount: (json['cgstAmount'] as num).toDouble(),
        sgstAmount: (json['sgstAmount'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
      );
}

class OrderDetail {
  final int salesOrderId;
  final String entryNo;
  final DateTime entryDate;
  final String customerName;
  final String mobileNo;
  final String shippingAddress;
  final double taxableValue;
  final double totalTax;
  final double roundOff;
  final double netAmount;
  final List<OrderDetailLine> lines;

  OrderDetail({
    required this.salesOrderId,
    required this.entryNo,
    required this.entryDate,
    required this.customerName,
    required this.mobileNo,
    required this.shippingAddress,
    required this.taxableValue,
    required this.totalTax,
    required this.roundOff,
    required this.netAmount,
    required this.lines,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) => OrderDetail(
        salesOrderId: json['salesOrderId'] as int,
        entryNo: json['entryNo'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String),
        customerName: json['customerName'] as String,
        mobileNo: json['mobileNo'] as String? ?? '',
        shippingAddress: json['shippingAddress'] as String? ?? '',
        taxableValue: (json['taxableValue'] as num).toDouble(),
        totalTax: (json['totalTax'] as num).toDouble(),
        roundOff: (json['roundOff'] as num).toDouble(),
        netAmount: (json['netAmount'] as num).toDouble(),
        lines: (json['lines'] as List).map((e) => OrderDetailLine.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
