class GraphDataPoint {
  final String label;
  final double totalAmount;

  GraphDataPoint({required this.label, required this.totalAmount});

  factory GraphDataPoint.fromJson(Map<String, dynamic> json) => GraphDataPoint(
        label: json['label'] as String,
        totalAmount: (json['totalAmount'] as num).toDouble(),
      );
}
