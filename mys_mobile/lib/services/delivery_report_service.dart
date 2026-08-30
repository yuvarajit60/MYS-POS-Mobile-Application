import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/delivery_detail.dart';
import '../models/delivery_number.dart';
import '../models/delivery_summary.dart';

class DeliveryReportServiceException implements Exception {
  final String message;
  DeliveryReportServiceException(this.message);
}

class DeliveryReportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<DeliverySummary>> getSummary({
    int? customerId,
    String? deliveryNo,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/deliveries/summary', queryParameters: {
        'customerId': ?customerId,
        'deliveryNo': ?(deliveryNo?.isEmpty == true ? null : deliveryNo),
        'fromDate': _dateFormat.format(fromDate),
        'toDate': _dateFormat.format(toDate),
      });
      return (response.data as List).map((e) => DeliverySummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw DeliveryReportServiceException(_messageFrom(e));
    }
  }

  Future<DeliveryDetail> getDeliveryDetail(String deliveryNo) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/deliveries/detail', queryParameters: {
        'deliveryNo': deliveryNo,
      });
      return DeliveryDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw DeliveryReportServiceException(_messageFrom(e));
    }
  }

  Future<List<DeliveryNumber>> searchDeliveryNumbers(String query) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/deliveries/delivery-numbers', queryParameters: {
        'search': query,
      });
      return (response.data as List).map((e) => DeliveryNumber.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw DeliveryReportServiceException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Could not load the report.';
  }
}
