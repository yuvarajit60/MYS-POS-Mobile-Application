class ProductType {
  final int typeId;
  final String typeName;

  ProductType({required this.typeId, required this.typeName});

  factory ProductType.fromJson(Map<String, dynamic> json) => ProductType(
        typeId: json['typeId'] as int,
        typeName: json['typeName'] as String,
      );
}
