import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/driver.dart';
import '../models/employee_vehicle_mapping.dart';
import '../models/vehicle.dart';

class EmployeeVehicleMappingServiceException implements Exception {
  final String message;
  EmployeeVehicleMappingServiceException(this.message);
}

class EmployeeVehicleMappingService {
  Future<List<EmployeeVehicleMapping>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/employee-vehicle-mappings', queryParameters: {'search': query});
    return (response.data as List).map((e) => EmployeeVehicleMapping.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EmployeeVehicleMapping> getById(int mappingId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/employee-vehicle-mappings/$mappingId');
      return EmployeeVehicleMapping.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw EmployeeVehicleMappingServiceException(_messageFrom(e, 'Could not load the mapping.'));
    }
  }

  Future<EmployeeVehicleMapping> create({
    required Driver driver,
    required Vehicle vehicle,
    required DateTime validStartDate,
    DateTime? validEndDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/employee-vehicle-mappings', data: {
        'employeeId': driver.employeeId,
        'vehicleId': vehicle.vehicleId,
        'validStartDate': validStartDate.toIso8601String(),
        'validEndDate': validEndDate?.toIso8601String(),
      });
      return EmployeeVehicleMapping.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw EmployeeVehicleMappingServiceException(_messageFrom(e, 'Could not save the mapping.'));
    }
  }

  Future<EmployeeVehicleMapping> update({
    required int mappingId,
    required Driver driver,
    required Vehicle vehicle,
    required DateTime validStartDate,
    DateTime? validEndDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.put('/api/employee-vehicle-mappings/$mappingId', data: {
        'employeeId': driver.employeeId,
        'vehicleId': vehicle.vehicleId,
        'validStartDate': validStartDate.toIso8601String(),
        'validEndDate': validEndDate?.toIso8601String(),
      });
      return EmployeeVehicleMapping.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw EmployeeVehicleMappingServiceException(_messageFrom(e, 'Could not update the mapping.'));
    }
  }

  Future<void> delete(int mappingId) async {
    try {
      await ApiClient.instance.dio.delete('/api/employee-vehicle-mappings/$mappingId');
    } on DioException catch (e) {
      throw EmployeeVehicleMappingServiceException(_messageFrom(e, 'Could not delete the mapping.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
