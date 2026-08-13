import '../core/api_client.dart';
import '../models/brand.dart';

class BrandService {
  Future<List<Brand>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/brands', queryParameters: {'search': query});
    return (response.data as List).map((e) => Brand.fromJson(e as Map<String, dynamic>)).toList();
  }
}
