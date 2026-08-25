import '../core/api_client.dart';
import '../models/driver.dart';
import '../models/driver_vehicle.dart';

class EmployeeService {
  Future<List<Driver>> searchDrivers(String query) async {
    final response = await ApiClient.instance.dio.get('/api/employees/drivers', queryParameters: {'search': query});
    return (response.data as List).map((e) => Driver.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DriverVehicle> getVehicle(int employeeId) async {
    final response = await ApiClient.instance.dio.get('/api/employees/$employeeId/vehicle');
    return DriverVehicle.fromJson(response.data as Map<String, dynamic>);
  }
}
