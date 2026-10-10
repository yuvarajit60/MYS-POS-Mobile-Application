class SalesEntryNumber {
  final int salesId;
  final String entryNo;

  SalesEntryNumber({required this.salesId, required this.entryNo});

  factory SalesEntryNumber.fromJson(Map<String, dynamic> json) => SalesEntryNumber(
        salesId: json['salesId'] as int,
        entryNo: json['entryNo'] as String,
      );
}
