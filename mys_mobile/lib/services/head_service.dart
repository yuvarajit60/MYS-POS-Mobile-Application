import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/head.dart';
import '../models/head_detail.dart';

class HeadServiceException implements Exception {
  final String message;
  HeadServiceException(this.message);
}

class HeadService {
  Future<List<Head>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/heads', queryParameters: {'search': query});
    return (response.data as List).map((e) => Head.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<HeadDetail> getById(int headId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/heads/$headId');
      return HeadDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw HeadServiceException(_messageFrom(e, 'Could not load the head.'));
    }
  }

  Future<Head> create({
    required String headName,
    String? printName,
    required String incomeOrExpenses,
    String? mappedMaster,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/heads', data: {
        'headName': headName,
        'printName': printName,
        'incomeOrExpenses': incomeOrExpenses,
        'mappedMaster': mappedMaster,
      });
      return Head.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw HeadServiceException(_messageFrom(e, 'Could not save the head.'));
    }
  }

  Future<Head> update({
    required int headId,
    required String headName,
    String? printName,
    required String incomeOrExpenses,
    String? mappedMaster,
    required bool status,
  }) async {
    try {
      final response = await ApiClient.instance.dio.put('/api/heads/$headId', data: {
        'headName': headName,
        'printName': printName,
        'incomeOrExpenses': incomeOrExpenses,
        'mappedMaster': mappedMaster,
        'status': status,
      });
      return Head.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw HeadServiceException(_messageFrom(e, 'Could not update the head.'));
    }
  }

  Future<void> delete(int headId) async {
    try {
      await ApiClient.instance.dio.delete('/api/heads/$headId');
    } on DioException catch (e) {
      throw HeadServiceException(_messageFrom(e, 'Could not delete the head.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
