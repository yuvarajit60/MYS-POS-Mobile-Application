import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/city.dart';
import '../models/customer.dart';
import '../models/site.dart';
import '../models/site_detail.dart';

class SiteServiceException implements Exception {
  final String message;
  SiteServiceException(this.message);
}

class SiteService {
  Future<List<Site>> search(String query) async {
    final response = await ApiClient.instance.dio.get('/api/sites', queryParameters: {'search': query});
    return (response.data as List).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SiteDetail> getById(int siteId) async {
    try {
      final response = await ApiClient.instance.dio.get('/api/sites/$siteId');
      return SiteDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SiteServiceException(_messageFrom(e, 'Could not load the site.'));
    }
  }

  Future<SiteDetail> create({
    required String siteName,
    required String areaName,
    required City city,
    required Customer customer,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post('/api/sites', data: {
        'siteName': siteName,
        'areaName': areaName,
        'cityId': city.cityId,
        'customerId': customer.customerId,
      });
      return SiteDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SiteServiceException(_messageFrom(e, 'Could not save the site.'));
    }
  }

  Future<SiteDetail> update({
    required int siteId,
    required String siteName,
    required String areaName,
    required City city,
    required Customer customer,
  }) async {
    try {
      final response = await ApiClient.instance.dio.put('/api/sites/$siteId', data: {
        'siteName': siteName,
        'areaName': areaName,
        'cityId': city.cityId,
        'customerId': customer.customerId,
      });
      return SiteDetail.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw SiteServiceException(_messageFrom(e, 'Could not update the site.'));
    }
  }

  Future<void> delete(int siteId) async {
    try {
      await ApiClient.instance.dio.delete('/api/sites/$siteId');
    } on DioException catch (e) {
      throw SiteServiceException(_messageFrom(e, 'Could not delete the site.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
