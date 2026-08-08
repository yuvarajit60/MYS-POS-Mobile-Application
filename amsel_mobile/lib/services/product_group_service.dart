import '../core/api_client.dart';
import '../models/product_group.dart';

class ProductGroupService {
  Future<List<ProductGroup>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/product-groups', queryParameters: {'search': query});
    return (response.data as List).map((e) => ProductGroup.fromJson(e as Map<String, dynamic>)).toList();
  }
}
