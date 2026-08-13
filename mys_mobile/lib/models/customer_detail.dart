class CustomerDetail {
  final int customerId;
  final String customerName;
  final String mobileNo;
  final int cityId;
  final String cityName;
  final String address;

  CustomerDetail({
    required this.customerId,
    required this.customerName,
    required this.mobileNo,
    required this.cityId,
    required this.cityName,
    required this.address,
  });

  factory CustomerDetail.fromJson(Map<String, dynamic> json) => CustomerDetail(
        customerId: json['customerId'] as int,
        customerName: json['customerName'] as String,
        mobileNo: json['mobileNo'] as String? ?? '',
        cityId: json['cityId'] as int,
        cityName: json['cityName'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );
}
