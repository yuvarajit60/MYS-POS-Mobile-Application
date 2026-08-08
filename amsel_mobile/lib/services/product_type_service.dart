import '../core/api_client.dart';
import '../models/product_type.dart';

class ProductTypeService {
  Future<List<ProductType>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/types', queryParameters: {'search': query});
    return (response.data as List).map((e) => ProductType.fromJson(e as Map<String, dynamic>)).toList();
  }
}
