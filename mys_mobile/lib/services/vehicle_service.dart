import '../core/api_client.dart';
import '../models/vehicle.dart';

class VehicleService {
  Future<List<Vehicle>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/vehicles', queryParameters: {'search': query});
    return (response.data as List).map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
  }
}
