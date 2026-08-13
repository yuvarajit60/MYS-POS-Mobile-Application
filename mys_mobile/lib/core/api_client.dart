import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'session.dart';

class ApiClient {
  ApiClient._internal() {
    dio = _build();
  }

  static final ApiClient instance = ApiClient._internal();

  /// Temporary: an ngrok tunnel to the dev machine's local API, so the app
  /// can be tested over real mobile data (not just the office Wi-Fi). This
  /// URL changes every time the ngrok tunnel is restarted on the dev side —
  /// swap it for the real hosted API's URL once that's deployed.
  static const String _publicApiUrl = 'https://corned-unfair-unrivaled.ngrok-free.dev';

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5263';
    if (Platform.isAndroid) return _publicApiUrl;
    return 'http://localhost:5263';
  }

  late final Dio dio;

  Dio _build() {
    final client = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      // Harmless when not using ngrok; prevents ngrok's free-tier browser
      // interstitial page from ever intercepting API responses.
      headers: {'ngrok-skip-browser-warning': 'true'},
    ));

    client.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!_isAuthEndpoint(options.path) && Session.instance.accessToken != null) {
          options.headers['Authorization'] = 'Bearer ${Session.instance.accessToken}';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        if (!_isAuthEndpoint(error.requestOptions.path) &&
            error.response?.statusCode == 401 &&
            !alreadyRetried) {
          final refreshed = await Session.instance.refreshAccessToken();
          if (refreshed) {
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer ${Session.instance.accessToken}';
            opts.extra['retried'] = true;
            try {
              final response = await client.fetch(opts);
              return handler.resolve(response);
            } catch (_) {
              return handler.next(error);
            }
          }
        }
        handler.next(error);
      },
    ));

    return client;
  }

  static bool _isAuthEndpoint(String path) => path.startsWith('/api/auth') || path.startsWith('/api/otp');
}
