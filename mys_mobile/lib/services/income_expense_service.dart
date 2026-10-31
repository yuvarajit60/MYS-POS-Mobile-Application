import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/head.dart';

class IncomeExpenseServiceException implements Exception {
  final String message;
  IncomeExpenseServiceException(this.message);
}

class IncomeExpenseService {
  Future<List<Head>> getHeads({required String incomeOrExpenses}) async {
    final response = await ApiClient.instance.dio.get('/api/income-expenses/heads', queryParameters: {
      'incomeOrExpenses': incomeOrExpenses,
    });
    return (response.data as List).map((e) => Head.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> create({
    required DateTime entryDate,
    required String incomeOrExpenses,
    required int headId,
    String? particulars,
    required double amount,
    int? employeeId,
    int? vehicleId,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/income-expenses', data: {
        'entryDate': entryDate.toIso8601String(),
        'incomeOrExpenses': incomeOrExpenses,
        'headId': headId,
        'particulars': particulars,
        'amount': amount,
        'employeeId': employeeId,
        'vehicleId': vehicleId,
      });
      return (response.data as Map<String, dynamic>)['entryNo'] as String;
    } on DioException catch (e) {
      throw IncomeExpenseServiceException(_messageFrom(e));
    }
  }

  String _messageFrom(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Could not save the entry.';
  }
}
