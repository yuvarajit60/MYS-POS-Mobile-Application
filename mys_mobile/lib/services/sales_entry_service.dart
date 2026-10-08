import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/sales_entry_option.dart';

class SalesEntryServiceException implements Exception {
  final String message;
  SalesEntryServiceException(this.message);
}

class SalesEntrySource {
  final String sourceType;
  final String entryNo;
  SalesEntrySource({required this.sourceType, required this.entryNo});
}

class SalesEntryService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<SalesEntryOption>> search({
    int? customerId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/sales-entries/options', queryParameters: {
        'customerId': ?customerId,
        'fromDate': _dateFormat.format(fromDate),
        'toDate': _dateFormat.format(toDate),
      });
      return (response.data as List).map((e) => SalesEntryOption.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw SalesEntryServiceException(_messageFrom(e, 'Could not load entries.'));
    }
  }

  Future<String> create(List<SalesEntrySource> sources) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/sales-entries', data: {
        'sources': sources.map((s) => {'sourceType': s.sourceType, 'entryNo': s.entryNo}).toList(),
      });
      return (response.data as Map<String, dynamic>)['entryNo'] as String;
    } on DioException catch (e) {
      throw SalesEntryServiceException(_messageFrom(e, 'Could not save the sales entry.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
