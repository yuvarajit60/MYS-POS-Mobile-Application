import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/area.dart';
import '../models/city.dart';

class AreaServiceException implements Exception {
  final String message;
  AreaServiceException(this.message);
}

class AreaService {
  Future<List<Area>> search(String query, {int? cityId}) async {
    final response = await ApiClient.instance.dio.get('/api/areas', queryParameters: {
      'search': query,
      'cityId': ?cityId,
    });
    return (response.data as List).map((e) => Area.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Area> create({required String areaName, required City city}) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/areas', data: {
        'areaName': areaName,
        'cityId': city.cityId,
      });
      return Area.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AreaServiceException(_messageFrom(e, 'Could not save the area.'));
    }
  }

  Future<Area> update({required int areaId, required String areaName, required City city}) async {
    try {
      final response = await ApiClient.instance.dio.put('/api/areas/$areaId', data: {
        'areaName': areaName,
        'cityId': city.cityId,
      });
      return Area.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AreaServiceException(_messageFrom(e, 'Could not update the area.'));
    }
  }

  Future<void> delete(int areaId) async {
    try {
      await ApiClient.instance.dio.delete('/api/areas/$areaId');
    } on DioException catch (e) {
      throw AreaServiceException(_messageFrom(e, 'Could not delete the area.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
