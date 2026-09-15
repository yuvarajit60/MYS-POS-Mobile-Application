import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/change_date.dart';

class ChangeDateService {
  Future<ChangeDate?> get() async {
    try {
      final response = await ApiClient.instance.dio.get('/api/change-date');
      return ChangeDate.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }
}
