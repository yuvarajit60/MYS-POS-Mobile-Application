import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/delivery_summary.dart';

class DeliveryReportServiceException implements Exception {
  final String message;
  DeliveryReportServiceException(this.message);
}

class DeliveryReportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<DeliverySummary>> getSummary({
    int? customerId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/deliveries/summary', queryParameters: {
        'customerId': ?customerId,
        'fromDate': _dateFormat.format(fromDate),
        'toDate': _dateFormat.format(toDate),
      });
      return (response.data as List).map((e) => DeliverySummary.fromJson(e as Map<String, dynamic>)).toList();
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
