class Product {
  final int productId;
  final String productName;
  final double rate;
  final double salesCgstPercentage;
  final double salesSgstPercentage;

  Product({
    required this.productId,
    required this.productName,
    required this.rate,
    required this.salesCgstPercentage,
    required this.salesSgstPercentage,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        productId: json['productId'] as int,
        productName: json['productName'] as String,
        rate: (json['rate'] as num).toDouble(),
        salesCgstPercentage: (json['salesCgstPercentage'] as num).toDouble(),
        salesSgstPercentage: (json['salesSgstPercentage'] as num).toDouble(),
      );
}
