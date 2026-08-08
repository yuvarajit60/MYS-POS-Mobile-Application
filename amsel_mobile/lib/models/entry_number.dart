class EntryNumber {
  final int salesOrderId;
  final String entryNo;

  EntryNumber({required this.salesOrderId, required this.entryNo});

  factory EntryNumber.fromJson(Map<String, dynamic> json) => EntryNumber(
        salesOrderId: json['salesOrderId'] as int,
        entryNo: json['entryNo'] as String,
      );
}
