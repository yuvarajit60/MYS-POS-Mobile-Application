import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/customer.dart';
import '../models/delivery_line.dart';
import '../models/driver.dart';

class DeliveryServiceException implements Exception {
  final String message;
  DeliveryServiceException(this.message);
}

class DeliveryResult {
  final int linesSaved;
  final String deliveryNo;
  DeliveryResult({required this.linesSaved, required this.deliveryNo});
}

class DeliveryService {
  Future<List<Customer>> searchPendingCustomers(String query) async {
    final response = await ApiClient.instance.dio.get('/api/deliveries/pending-customers', queryParameters: {'search': query});
    return (response.data as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DeliveryLine>> getPendingLines(int customerId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/deliveries/pending-lines', queryParameters: {'customerId': customerId});
      return (response.data as List).map((e) => DeliveryLine.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw DeliveryServiceException(_messageFrom(e, 'Could not load pending deliveries.'));
    }
  }

  Future<DeliveryResult> create({
    required Driver driver,
    required String vehicleNumber,
    required List<DeliveryLine> lines,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/deliveries', data: {
        'driverEmployeeId': driver.employeeId,
        'vehicleNumber': vehicleNumber,
        'lines': lines
            .map((l) => {
                  'salesOrderDetId': l.salesOrderDetId,
                  'salesOrderId': l.salesOrderId,
                  'productId': l.productId,
                  'currentDelivery': l.currentDelivery,
                })
            .toList(),
      });
      final data = response.data as Map<String, dynamic>;
      return DeliveryResult(linesSaved: data['linesSaved'] as int, deliveryNo: data['deliveryNo'] as String);
    } on DioException catch (e) {
      throw DeliveryServiceException(_messageFrom(e, 'Could not save the delivery.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
