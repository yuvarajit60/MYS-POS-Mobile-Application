import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/company.dart';

class CompanyService {
  Future<Company?> get() async {
    try {
      final response = await ApiClient.instance.dio.get('/api/company');
      return Company.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }
}
