class Customer {
  final int customerId;
  final String customerName;
  final String mobileNo;

  Customer({required this.customerId, required this.customerName, required this.mobileNo});

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        customerId: json['customerId'] as int,
        customerName: json['customerName'] as String,
        mobileNo: json['mobileNo'] as String? ?? '',
      );
}
