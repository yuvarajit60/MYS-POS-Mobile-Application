import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/ledger_all_customers_row.dart';
import '../models/ledger_entry.dart';

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

  /// Flat register of every transaction across every customer, shown when
  /// no customer is selected in the filter.
  Future<List<LedgerAllCustomersRow>> getAllCustomers({DateTime? fromDate, DateTime? toDate}) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/ledger/all-customers', queryParameters: {
        'fromDate': ?(fromDate == null ? null : _dateFormat.format(fromDate)),
        'toDate': ?(toDate == null ? null : _dateFormat.format(toDate)),
      });
      return (response.data as List).map((e) => LedgerAllCustomersRow.fromJson(e as Map<String, dynamic>)).toList();
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
