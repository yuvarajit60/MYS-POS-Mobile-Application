import '../core/api_client.dart';
import '../models/site.dart';

class SiteService {
  Future<List<Site>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/sites', queryParameters: {'search': query});
    return (response.data as List).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
  }
}
