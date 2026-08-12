import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/city.dart';
import '../models/customer.dart';
import '../models/customer_detail.dart';

class CustomerServiceException implements Exception {
  final String message;
  CustomerServiceException(this.message);
}

class CustomerService {
  Future<List<Customer>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/customers', queryParameters: {'search': query});
    return (response.data as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CustomerDetail> getById(int customerId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/customers/$customerId');
      return CustomerDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw CustomerServiceException(_messageFrom(e, 'Could not load the customer.'));
    }
  }

  Future<Customer> create({
    required String customerName,
    required String mobileNo,
    required City city,
    String? address,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/customers', data: {
        'customerName': customerName,
        'mobileNo': mobileNo,
        'cityId': city.cityId,
        'address': address,
      });
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw CustomerServiceException(_messageFrom(e, 'Could not save the customer.'));
    }
  }

  Future<Customer> update({
    required int customerId,
    required String customerName,
    required String mobileNo,
    required City city,
    String? address,
  }) async {
    try {
      final response = await ApiClient.instance.dio.put('/api/customers/$customerId', data: {
        'customerName': customerName,
        'mobileNo': mobileNo,
        'cityId': city.cityId,
        'address': address,
      });
      return Customer.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw CustomerServiceException(_messageFrom(e, 'Could not update the customer.'));
    }
  }

  Future<void> delete(int customerId) async {
    try {
      await ApiClient.instance.dio.delete('/api/customers/$customerId');
    } on DioException catch (e) {
      throw CustomerServiceException(_messageFrom(e, 'Could not delete the customer.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
