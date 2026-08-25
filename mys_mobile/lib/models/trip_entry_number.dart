class TripEntryNumber {
  final int tripEntryId;
  final String entryNo;

  TripEntryNumber({required this.tripEntryId, required this.entryNo});

  factory TripEntryNumber.fromJson(Map<String, dynamic> json) => TripEntryNumber(
        tripEntryId: json['tripEntryId'] as int,
        entryNo: json['entryNo'] as String,
      );
}
