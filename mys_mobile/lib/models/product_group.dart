class ProductGroup {
  final int productGroupId;
  final String productGroupName;

  ProductGroup({required this.productGroupId, required this.productGroupName});

  factory ProductGroup.fromJson(Map<String, dynamic> json) => ProductGroup(
        productGroupId: json['productGroupId'] as int,
        productGroupName: json['productGroupName'] as String,
      );
}
