import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/brand.dart';
import '../models/product.dart';
import '../models/product_group.dart';
import '../models/product_type.dart';

class ProductServiceException implements Exception {
  final String message;
  ProductServiceException(this.message);
}

class ProductService {
  Future<List<Product>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/products', queryParameters: {'search': query});
    return (response.data as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Product> create({
    required String productName,
    required double mrp,
    required ProductGroup productGroup,
    required Brand brand,
    required ProductType type,
    required double salesGstPercentage,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/products', data: {
        'productName': productName,
        'mrp': mrp,
        'productGroupId': productGroup.productGroupId,
        'brandId': brand.brandId,
        'typeId': type.typeId,
        'salesGstPercentage': salesGstPercentage,
      });
      return Product.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String) ? data['message'] as String : 'Could not save the product.';
      throw ProductServiceException(message);
    }
  }
}
