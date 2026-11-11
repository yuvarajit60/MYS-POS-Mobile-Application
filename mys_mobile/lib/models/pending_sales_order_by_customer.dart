class PendingSalesOrderByCustomer {
  final String customerName;
  final double pendingQty;

  PendingSalesOrderByCustomer({required this.customerName, required this.pendingQty});

  factory PendingSalesOrderByCustomer.fromJson(Map<String, dynamic> json) => PendingSalesOrderByCustomer(
        customerName: json['customerName'] as String,
        pendingQty: (json['pendingQty'] as num).toDouble(),
      );
}
