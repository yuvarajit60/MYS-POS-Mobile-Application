class CancelEntryOption {
  final String entryNo;
  final String customerName;
  final DateTime entryDate;
  final double totalAmount;

  CancelEntryOption({
    required this.entryNo,
    required this.customerName,
    required this.entryDate,
    required this.totalAmount,
  });

  factory CancelEntryOption.fromJson(Map<String, dynamic> json) => CancelEntryOption(
        entryNo: json['entryNo'] as String,
        customerName: json['customerName'] as String? ?? '',
        entryDate: DateTime.parse(json['entryDate'] as String),
        totalAmount: (json['totalAmount'] as num).toDouble(),
      );
}
