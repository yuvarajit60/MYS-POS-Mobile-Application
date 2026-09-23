import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/customer.dart';

class PaymentServiceException implements Exception {
  final String message;
  PaymentServiceException(this.message);
}

class PaymentResult {
  final String paymentNo;
  PaymentResult({required this.paymentNo});
}

class PaymentService {
  Future<List<Customer>> searchDeliveredCustomers(String query) async {
    final response = await ApiClient.instance.dio.get('/api/payments/delivered-customers', queryParameters: {'search': query});
    return (response.data as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PaymentResult> create({required int customerId, required double amount, required String paymentType}) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/payments', data: {
        'customerId': customerId,
        'amount': amount,
        'paymentType': paymentType,
      });
      final data = response.data as Map<String, dynamic>;
      return PaymentResult(paymentNo: data['paymentNo'] as String);
    } on DioException catch (e) {
      throw PaymentServiceException(_messageFrom(e, 'Could not save the payment.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
