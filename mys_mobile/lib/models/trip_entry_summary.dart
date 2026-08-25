class TripEntrySummary {
  final int tripEntryId;
  final String entryNo;
  final DateTime entryDate;
  final String customerName;
  final String mobileNo;
  final String siteName;
  final String driverName;
  final double netAmount;

  TripEntrySummary({
    required this.tripEntryId,
    required this.entryNo,
    required this.entryDate,
    required this.customerName,
    required this.mobileNo,
    required this.siteName,
    required this.driverName,
    required this.netAmount,
  });

  factory TripEntrySummary.fromJson(Map<String, dynamic> json) => TripEntrySummary(
        tripEntryId: json['tripEntryId'] as int,
        entryNo: json['entryNo'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String),
        customerName: json['customerName'] as String,
        mobileNo: json['mobileNo'] as String? ?? '',
        siteName: json['siteName'] as String? ?? '',
        driverName: json['driverName'] as String? ?? '',
        netAmount: (json['netAmount'] as num).toDouble(),
      );
}
