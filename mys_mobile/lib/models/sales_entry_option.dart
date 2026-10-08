class SalesEntryOption {
  final String sourceType;
  final String entryNo;
  final String customerName;
  final DateTime entryDate;
  final double totalQty;
  final double totalAmount;
  final bool customerHasGst;

  SalesEntryOption({
    required this.sourceType,
    required this.entryNo,
    required this.customerName,
    required this.entryDate,
    required this.totalQty,
    required this.totalAmount,
    required this.customerHasGst,
  });

  factory SalesEntryOption.fromJson(Map<String, dynamic> json) => SalesEntryOption(
        sourceType: json['sourceType'] as String,
        entryNo: json['entryNo'] as String,
        customerName: json['customerName'] as String? ?? '',
        entryDate: DateTime.parse(json['entryDate'] as String),
        totalQty: (json['totalQty'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        customerHasGst: json['customerHasGst'] as bool,
      );
}
