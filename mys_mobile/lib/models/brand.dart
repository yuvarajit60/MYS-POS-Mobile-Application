class Brand {
  final int brandId;
  final String brandName;

  Brand({required this.brandId, required this.brandName});

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
        brandId: json['brandId'] as int,
        brandName: json['brandName'] as String,
      );
}
