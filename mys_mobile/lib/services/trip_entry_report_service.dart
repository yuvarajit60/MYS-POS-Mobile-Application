import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/graph_data_point.dart';
import '../models/trip_entry_detail.dart';
import '../models/trip_entry_number.dart';
import '../models/trip_entry_summary.dart';

class TripEntryReportServiceException implements Exception {
  final String message;
  TripEntryReportServiceException(this.message);
}

class TripEntryReportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<TripEntrySummary>> getSummary({
    int? customerId,
    String? tripEntryNo,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/trip-entries/summary', queryParameters: {
        'customerId': ?customerId,
        'tripEntryNo': ?(tripEntryNo?.isEmpty == true ? null : tripEntryNo),
        'fromDate': _dateFormat.format(fromDate),
        'toDate': _dateFormat.format(toDate),
      });
      return (response.data as List).map((e) => TripEntrySummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw TripEntryReportServiceException(_messageFrom(e));
    }
  }

  Future<TripEntryDetail> getTripEntryDetail(int tripEntryId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/trip-entries/$tripEntryId');
      return TripEntryDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw TripEntryReportServiceException(_messageFrom(e));
    }
  }

  Future<List<GraphDataPoint>> getGraphData({required String groupBy, int? year}) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/trip-entries/graph', queryParameters: {
        'groupBy': groupBy,
        'year': ?year,
      });
      return (response.data as List).map((e) => GraphDataPoint.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw TripEntryReportServiceException(_messageFrom(e));
    }
  }

  Future<List<TripEntryNumber>> searchTripEntryNumbers(String query) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/trip-entries/entry-numbers', queryParameters: {
        'search': query,
      });
      return (response.data as List).map((e) => TripEntryNumber.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw TripEntryReportServiceException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Could not load the report.';
  }
}
