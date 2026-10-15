import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';
import 'Interceptors/security_interceptor.dart';
import 'Interceptors/auth_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient({String? customBaseUrl}) {
    _instance._init(customBaseUrl: customBaseUrl);
    return _instance;
  }
  ApiClient._internal();

  static const _defaultBaseUrl = 'https://api-dev.balaseetharamanjaneyulu.com';
  static final List<String> _pinnedFingerprints = _readEnv('PINNED_CERT_FINGERPRINTS', '')
      .split(',')
      .where((s) => s.trim().isNotEmpty)
      .toList(growable: false);

  String _baseUrl = '';
  String get baseUrl => _baseUrl;

  late final Dio dio;

  void _init({String? customBaseUrl}) {
    if (_baseUrl.isNotEmpty) return;

    _baseUrl = customBaseUrl ?? dotenv.env['API_BASE_URL'] ?? _defaultBaseUrl;

    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    _setupCertPinning();

    dio.interceptors.add(RetryInterceptor());
    dio.interceptors.add(AuthInterceptor(dio));
    dio.interceptors.add(SecurityInterceptor());

    if (!kReleaseMode) {
      dio.interceptors.add(LogInterceptor(
        requestHeader: true, requestBody: true, responseBody: true, error: true,
      ));
    }
  }

  void _setupCertPinning() {
    try {
      if (dio.httpClientAdapter is IOHttpClientAdapter) {
        final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
        adapter.createHttpClient = _createPinningClient;
      }
    } catch (e) {
      debugPrint('[CertPinning] Setup skipped ($e)');
    }
  }

  HttpClient _createPinningClient() {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      if (_pinnedFingerprints.isEmpty) {
        return kDebugMode;
      }
      return _verifyPinnedFingerprint(cert, host);
    };
    return client;
  }

  bool _verifyPinnedFingerprint(X509Certificate cert, String host) {
    try {
      final hash = sha256.convert(cert.der).toString();
      final matched = _pinnedFingerprints.any((f) => hash == f.trim());
      if (!matched && kDebugMode) {
        debugPrint('[CertPinning] No matching fingerprint for $host');
        debugPrint('[CertPinning]   Got: $hash');
      }
      return matched;
    } catch (e) {
      debugPrint('[CertPinning] Error: $e');
      return false;
    }
  }

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    if (dio.options.baseUrl != newUrl) {
      dio.options.baseUrl = newUrl;
    }
  }

  static String _readEnv(String key, String fallback) {
    return dotenv.env[key] ?? fallback;
  }
}


class RetryInterceptor extends Interceptor {
  static const _maxRetries = 2;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retries = err.requestOptions.extra['retry_count'] as int? ?? 0;

    if (retries >= _maxRetries) {
      return handler.next(err);
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      await Future.delayed(Duration(seconds: (retries + 1) * 2));
      err.requestOptions.extra['retry_count'] = retries + 1;
      try {
        final response = await Dio().fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (_) {}
    }
    return handler.next(err);
  }
}
