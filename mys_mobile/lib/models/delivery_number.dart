class DeliveryNumber {
  final String deliveryNo;

  DeliveryNumber({required this.deliveryNo});

  factory DeliveryNumber.fromJson(Map<String, dynamic> json) => DeliveryNumber(
        deliveryNo: json['deliveryNo'] as String,
      );
}
