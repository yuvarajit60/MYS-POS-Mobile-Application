import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/payment_report_entry.dart';

class PaymentReportServiceException implements Exception {
  final String message;
  PaymentReportServiceException(this.message);
}

class PaymentReportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<PaymentReportEntry>> getSummary({
    int? customerId,
    String? paymentType,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/payments/summary', queryParameters: {
        'customerId': ?customerId,
        'paymentType': ?paymentType,
        'fromDate': _dateFormat.format(fromDate),
        'toDate': _dateFormat.format(toDate),
      });
      return (response.data as List).map((e) => PaymentReportEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw PaymentReportServiceException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Could not load the report.';
  }
}
