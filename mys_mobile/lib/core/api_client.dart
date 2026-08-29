import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'session.dart';

class ApiClient {
  ApiClient._internal() {
    dio = _build();
  }

  static final ApiClient instance = ApiClient._internal();

  /// The real hosted API, deployed on Render.
  static const String _publicApiUrl = 'https://mys-pos-mobile-application.onrender.com';

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5263';
    if (Platform.isAndroid || Platform.isIOS) return _publicApiUrl;
    return 'http://localhost:5263';
  }

  late final Dio dio;

  Dio _build() {
    final client = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
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
