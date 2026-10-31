import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../models/income_expense_entry_number.dart';
import '../models/income_expense_summary.dart';

class IncomeExpenseReportServiceException implements Exception {
  final String message;
  IncomeExpenseReportServiceException(this.message);
}

class IncomeExpenseReportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<IncomeExpenseSummary>> getSummary({
    String? entryNo,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/income-expenses/summary', queryParameters: {
        'entryNo': ?(entryNo?.isEmpty == true ? null : entryNo),
        'fromDate': _dateFormat.format(fromDate),
        'toDate': _dateFormat.format(toDate),
      });
      return (response.data as List).map((e) => IncomeExpenseSummary.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw IncomeExpenseReportServiceException(_messageFrom(e));
    }
  }

  Future<List<IncomeExpenseEntryNumber>> searchEntryNumbers(String query) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/reports/income-expenses/entry-numbers', queryParameters: {
        'search': query,
      });
      return (response.data as List).map((e) => IncomeExpenseEntryNumber.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw IncomeExpenseReportServiceException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Could not load the report.';
  }
}
