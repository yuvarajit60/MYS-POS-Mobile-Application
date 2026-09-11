import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/driver.dart';
import '../models/driver_vehicle.dart';
import '../models/employee.dart';
import '../models/employee_detail.dart';

class EmployeeServiceException implements Exception {
  final String message;
  EmployeeServiceException(this.message);
}

class EmployeeService {
  Future<List<Driver>> searchDrivers(String query) async {
    final response = await ApiClient.instance.dio.get('/api/employees/drivers', queryParameters: {'search': query});
    return (response.data as List).map((e) => Driver.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DriverVehicle> getVehicle(int employeeId) async {
    final response = await ApiClient.instance.dio.get('/api/employees/$employeeId/vehicle');
    return DriverVehicle.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Employee>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/employees', queryParameters: {'search': query});
    return (response.data as List).map((e) => Employee.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EmployeeDetail> getById(int employeeId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/employees/$employeeId');
      return EmployeeDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw EmployeeServiceException(_messageFrom(e, 'Could not load the employee.'));
    }
  }

  Future<Employee> create({
    required String employeeName,
    String? printName,
    String? employeeCode,
    String? address,
    required int cityId,
    String? pinCode,
    String? phoneNo,
    required String mobileNo,
    String? emailId,
    required bool isDriver,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/employees', data: {
        'employeeName': employeeName,
        'printName': printName,
        'employeeCode': employeeCode,
        'address': address,
        'cityId': cityId,
        'pinCode': pinCode,
        'phoneNo': phoneNo,
        'mobileNo': mobileNo,
        'emailId': emailId,
        'isDriver': isDriver,
      });
      return Employee.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw EmployeeServiceException(_messageFrom(e, 'Could not save the employee.'));
    }
  }

  Future<Employee> update({
    required int employeeId,
    required String employeeName,
    String? printName,
    String? employeeCode,
    String? address,
    required int cityId,
    String? pinCode,
    String? phoneNo,
    required String mobileNo,
    String? emailId,
    required bool isDriver,
  }) async {
    try {
      final response = await ApiClient.instance.dio.put('/api/employees/$employeeId', data: {
        'employeeName': employeeName,
        'printName': printName,
        'employeeCode': employeeCode,
        'address': address,
        'cityId': cityId,
        'pinCode': pinCode,
        'phoneNo': phoneNo,
        'mobileNo': mobileNo,
        'emailId': emailId,
        'isDriver': isDriver,
      });
      return Employee.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw EmployeeServiceException(_messageFrom(e, 'Could not update the employee.'));
    }
  }

  Future<void> delete(int employeeId) async {
    try {
      await ApiClient.instance.dio.delete('/api/employees/$employeeId');
    } on DioException catch (e) {
      throw EmployeeServiceException(_messageFrom(e, 'Could not delete the employee.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
