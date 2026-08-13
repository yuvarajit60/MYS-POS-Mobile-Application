import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/secure_storage.dart';
import '../core/session.dart';

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  AuthException(this.message, {this.statusCode});
}

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  Future<void> login(String username, String password) async {
    try {
      final deviceId = await SecureStorage.instance.getOrCreateDeviceId();
      final response = await _dio.post('/api/auth/login', data: {
        'username': username,
        'password': password,
        'deviceId': deviceId,
      });
      await Session.instance.completeLogin(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_messageFrom(e, 'Invalid username or password.'));
    }
  }

  Future<void> requestOtp(String mobileNo) async {
    try {
      await _dio.post('/api/otp/request', data: {'mobileNo': mobileNo});
    } on DioException catch (e) {
      throw AuthException(_messageFrom(e, 'Could not send the OTP.'), statusCode: e.response?.statusCode);
    }
  }

  Future<void> verifyOtp(String mobileNo, String otp) async {
    try {
      final deviceId = await SecureStorage.instance.getOrCreateDeviceId();
      final response = await _dio.post('/api/otp/verify', data: {
        'mobileNo': mobileNo,
        'otp': otp,
        'deviceId': deviceId,
      });
      await Session.instance.completeLogin(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(_messageFrom(e, 'Invalid or expired OTP.'));
    }
  }

  String _messageFrom(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return fallback;
  }
}
