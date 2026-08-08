import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/entry_number.dart';
import '../models/graph_data_point.dart';
import '../models/order_detail.dart';
import '../models/sales_order_summary.dart';

class ReportServiceException implements Exception {
  final String message;
  ReportServiceException(this.message);
}

class ReportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<SalesOrderSummary>> getSummary({
    int? customerId,
    String? salesOrderNo,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/sales-orders/summary', queryParameters: {
        'customerId': ?customerId,
        'salesOrderNo': ?(salesOrderNo?.isEmpty == true ? null : salesOrderNo),
        'fromDate': _dateFormat.format(fromDate),
        'toDate': _dateFormat.format(toDate),
      });
      return (response.data as List).map((e) => SalesOrderSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ReportServiceException(_messageFrom(e));
    }
  }

  Future<OrderDetail> getOrderDetail(int salesOrderId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/sales-orders/$salesOrderId');
      return OrderDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ReportServiceException(_messageFrom(e));
    }
  }

  Future<List<GraphDataPoint>> getGraphData({required String groupBy, int? year}) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/sales-orders/graph', queryParameters: {
        'groupBy': groupBy,
        'year': ?year,
      });
      return (response.data as List).map((e) => GraphDataPoint.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ReportServiceException(_messageFrom(e));
    }
  }

  Future<List<EntryNumber>> searchEntryNumbers(String query) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/sales-orders/entry-numbers', queryParameters: {
        'search': query,
      });
      return (response.data as List).map((e) => EntryNumber.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ReportServiceException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Could not load the report.';
  }
}
