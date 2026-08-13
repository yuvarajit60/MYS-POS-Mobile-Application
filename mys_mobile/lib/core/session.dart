import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'secure_storage.dart';

/// In-memory access token + the "am I logged in" state the app boots against.
/// Only the refresh token is ever persisted (see SecureStorage) — the access
/// token is re-derived via silent refresh on every app start.
class Session extends ChangeNotifier {
  Session._internal();
  static final Session instance = Session._internal();

  String? accessToken;
  DateTime? accessTokenExpiresAt;

  bool get isAuthenticated => accessToken != null;

  /// Called on app boot. Returns true if a stored refresh token produced a
  /// valid session (so the app can skip straight to the landing page).
  Future<bool> trySilentLogin() async {
    final refreshToken = await SecureStorage.instance.getRefreshToken();
    if (refreshToken == null) return false;
    return _refreshWith(refreshToken);
  }

  /// Used by ApiClient's 401 handler to transparently refresh mid-session.
  Future<bool> refreshAccessToken() async {
    final refreshToken = await SecureStorage.instance.getRefreshToken();
    if (refreshToken == null) return false;
    return _refreshWith(refreshToken);
  }

  Future<bool> _refreshWith(String refreshToken) async {
    try {
      final deviceId = await SecureStorage.instance.getOrCreateDeviceId();
      final response = await ApiClient.instance.dio.post('/api/auth/refresh', data: {
        'refreshToken': refreshToken,
        'deviceId': deviceId,
      });
      await _applyAuthResponse(response.data as Map<String, dynamic>);
      return true;
    } on DioException {
      return false;
    }
  }

  /// Called by AuthService after a successful login/OTP-verify.
  Future<void> completeLogin(Map<String, dynamic> authResponseJson) => _applyAuthResponse(authResponseJson);

  Future<void> _applyAuthResponse(Map<String, dynamic> json) async {
    accessToken = json['accessToken'] as String;
    accessTokenExpiresAt = DateTime.parse(json['accessTokenExpiresAt'] as String);
    await SecureStorage.instance.setRefreshToken(json['refreshToken'] as String);
    notifyListeners();
  }

  Future<void> logout() async {
    accessToken = null;
    accessTokenExpiresAt = null;
    await SecureStorage.instance.clear();
    notifyListeners();
  }
}
