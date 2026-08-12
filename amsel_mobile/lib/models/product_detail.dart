class ProductDetail {
  final int productId;
  final String productName;
  final double mrp;
  final int productGroupId;
  final String productGroupName;
  final int brandId;
  final String brandName;
  final int typeId;
  final String typeName;
  final double salesGstPercentage;

  ProductDetail({
    required this.productId,
    required this.productName,
    required this.mrp,
    required this.productGroupId,
    required this.productGroupName,
    required this.brandId,
    required this.brandName,
    required this.typeId,
    required this.typeName,
    required this.salesGstPercentage,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        productId: json['productId'] as int,
        productName: json['productName'] as String,
        mrp: (json['mrp'] as num).toDouble(),
        productGroupId: json['productGroupId'] as int,
        productGroupName: json['productGroupName'] as String? ?? '',
        brandId: json['brandId'] as int,
        brandName: json['brandName'] as String? ?? '',
        typeId: json['typeId'] as int,
        typeName: json['typeName'] as String? ?? '',
        salesGstPercentage: (json['salesGstPercentage'] as num).toDouble(),
      );
}
