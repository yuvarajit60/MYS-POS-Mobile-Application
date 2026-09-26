import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/ledger_entry.dart';
import '../models/ledger_summary.dart';

class LedgerServiceException implements Exception {
  final String message;
  LedgerServiceException(this.message);
}

class LedgerService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<LedgerEntry>> getLedger({
    required int customerId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/ledger', queryParameters: {
        'customerId': customerId,
        'fromDate': ?(fromDate == null ? null : _dateFormat.format(fromDate)),
        'toDate': ?(toDate == null ? null : _dateFormat.format(toDate)),
      });
      return (response.data as List).map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw LedgerServiceException(_messageFrom(e));
    }
  }

  /// All-customers aggregate, shown when no customer is selected in the filter.
  Future<LedgerSummary> getSummary({DateTime? fromDate, DateTime? toDate}) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/ledger/summary', queryParameters: {
        'fromDate': ?(fromDate == null ? null : _dateFormat.format(fromDate)),
        'toDate': ?(toDate == null ? null : _dateFormat.format(toDate)),
      });
      return LedgerSummary.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw LedgerServiceException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Could not load the ledger.';
  }
}
