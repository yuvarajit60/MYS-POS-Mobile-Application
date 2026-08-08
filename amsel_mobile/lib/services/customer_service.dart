import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/city.dart';
import '../models/customer.dart';

class CustomerServiceException implements Exception {
  final String message;
  CustomerServiceException(this.message);
}

class CustomerService {
  Future<List<Customer>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/customers', queryParameters: {'search': query});
    return (response.data as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
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
      final data = e.response?.data;
      final message = (data is Map && data['message'] is String) ? data['message'] as String : 'Could not save the customer.';
      throw CustomerServiceException(message);
    }
  }
}
