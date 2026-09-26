import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/cancel_entry_option.dart';

class CancelEntryServiceException implements Exception {
  final String message;
  CancelEntryServiceException(this.message);
}

class CancelEntryService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<CancelEntryOption>> searchEntries({
    required String transactionType,
    required DateTime date,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/cancel-entries/options', queryParameters: {
        'transactionType': transactionType,
        'date': _dateFormat.format(date),
      });
      return (response.data as List).map((e) => CancelEntryOption.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw CancelEntryServiceException(_messageFrom(e, 'Could not load entries.'));
    }
  }

  Future<void> cancel({
    required String transactionType,
    required String entryNo,
    required DateTime cancelDate,
    String? remarks,
  }) async {
    try {
      await ApiClient.instance.dio.post('/api/cancel-entries', data: {
        'transactionType': transactionType,
        'entryNo': entryNo,
        'cancelDate': cancelDate.toIso8601String(),
        'remarks': remarks,
      });
    } on DioException catch (e) {
      throw CancelEntryServiceException(_messageFrom(e, 'Could not cancel the entry.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
