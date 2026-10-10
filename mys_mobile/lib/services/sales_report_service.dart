import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/sales_detail.dart';
import '../models/sales_entry_number.dart';
import '../models/sales_summary.dart';

class SalesReportServiceException implements Exception {
  final String message;
  SalesReportServiceException(this.message);
}

class SalesReportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<SalesSummary>> getSummary({
    int? customerId,
    String? salesNo,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/sales/summary', queryParameters: {
        'customerId': ?customerId,
        'salesNo': ?(salesNo?.isEmpty == true ? null : salesNo),
        'fromDate': _dateFormat.format(fromDate),
        'toDate': _dateFormat.format(toDate),
      });
      return (response.data as List).map((e) => SalesSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw SalesReportServiceException(_messageFrom(e));
    }
  }

  Future<SalesDetail> getSalesDetail(int salesId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/sales/$salesId');
      return SalesDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SalesReportServiceException(_messageFrom(e));
    }
  }

  Future<List<SalesEntryNumber>> searchEntryNumbers(String query) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/sales/entry-numbers', queryParameters: {
        'search': query,
      });
      return (response.data as List).map((e) => SalesEntryNumber.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw SalesReportServiceException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Could not load the report.';
  }
}
