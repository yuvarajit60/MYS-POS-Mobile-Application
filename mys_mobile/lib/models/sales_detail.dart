class SalesDetailLine {
  final String productName;
  final double qty;
  final double rate;
  final double taxableValue;
  final double cgstAmount;
  final double sgstAmount;
  final double totalAmount;

  SalesDetailLine({
    required this.productName,
    required this.qty,
    required this.rate,
    required this.taxableValue,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.totalAmount,
  });

  factory SalesDetailLine.fromJson(Map<String, dynamic> json) => SalesDetailLine(
        productName: json['productName'] as String,
        qty: (json['qty'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        taxableValue: (json['taxableValue'] as num).toDouble(),
        cgstAmount: (json['cgstAmount'] as num).toDouble(),
        sgstAmount: (json['sgstAmount'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
      );
}

class SalesDetail {
  final int salesId;
  final String entryNo;
  final DateTime entryDate;
  final String customerName;
  final String mobileNo;
  final double taxableValue;
  final double totalTax;
  final double roundOff;
  final double netAmount;
  final List<SalesDetailLine> lines;

  SalesDetail({
    required this.salesId,
    required this.entryNo,
    required this.entryDate,
    required this.customerName,
    required this.mobileNo,
    required this.taxableValue,
    required this.totalTax,
    required this.roundOff,
    required this.netAmount,
    required this.lines,
  });

  factory SalesDetail.fromJson(Map<String, dynamic> json) => SalesDetail(
        salesId: json['salesId'] as int,
        entryNo: json['entryNo'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String),
        customerName: json['customerName'] as String? ?? '',
        mobileNo: json['mobileNo'] as String? ?? '',
        taxableValue: (json['taxableValue'] as num).toDouble(),
        totalTax: (json['totalTax'] as num).toDouble(),
        roundOff: (json['roundOff'] as num).toDouble(),
        netAmount: (json['netAmount'] as num).toDouble(),
        lines: (json['lines'] as List).map((e) => SalesDetailLine.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
