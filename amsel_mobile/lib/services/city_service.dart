import '../core/api_client.dart';
import '../models/city.dart';

class CityService {
  Future<List<City>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/cities', queryParameters: {'search': query});
    return (response.data as List).map((e) => City.fromJson(e as Map<String, dynamic>)).toList();
  }
}
