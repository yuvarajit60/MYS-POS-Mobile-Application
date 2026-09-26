class LedgerSummary {
  final int totalCustomers;
  final double totalDeliveryAmount;
  final double totalTripEntryAmount;
  final double totalPaymentAmount;

  LedgerSummary({
    required this.totalCustomers,
    required this.totalDeliveryAmount,
    required this.totalTripEntryAmount,
    required this.totalPaymentAmount,
  });

  factory LedgerSummary.fromJson(Map<String, dynamic> json) => LedgerSummary(
        totalCustomers: json['totalCustomers'] as int,
        totalDeliveryAmount: (json['totalDeliveryAmount'] as num).toDouble(),
        totalTripEntryAmount: (json['totalTripEntryAmount'] as num).toDouble(),
        totalPaymentAmount: (json['totalPaymentAmount'] as num).toDouble(),
      );
}
