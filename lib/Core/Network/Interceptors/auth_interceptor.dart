import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Core/Services/force_logout_service.dart';

/// Interceptor to automatically attach the Firebase ID Token to every request,
/// and to translate server-side session termination (401/403) into a hard
/// client-side logout via ForceLogoutService.
class AuthInterceptor extends Interceptor {
  final Dio _dio;

  AuthInterceptor(this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      debugPrint('🔍 AuthInterceptor: Checking user for path: ${options.path}');
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        debugPrint('👤 AuthInterceptor: Found user ${user.email}. Fetching token...');
        // Fast Path: Use cached token (valid for 1 hour)
        try {
          String? token = await user.getIdToken();

          if (token == null) {
            debugPrint('⚠️ AuthInterceptor: Cached token null, forcing refresh...');
            token = await user.getIdToken(true);
          }

          if (token != null) {
            final authHeader = 'Bearer $token';
            options.headers['Authorization'] = authHeader;

            debugPrint('────────────────────────────────────────────────────────');
            debugPrint('🔐 AUTH HANDSHAKE: Firebase ID Token Attached');
            debugPrint('Token Length: ${token.length} chars');
            debugPrint('Path: ${options.path}');
            debugPrint('────────────────────────────────────────────────────────');
          } else {
            debugPrint('❌ AuthInterceptor: Token fetch returned null');
          }
        } on FirebaseAuthException catch (e) {
          debugPrint('🚨 AuthInterceptor FirebaseAuthException: ${e.code}');
          if (e.code == 'user-token-expired' || e.code == 'invalid-credential') {
            try {
              debugPrint('🔄 AuthInterceptor: Token expired, forcing refresh...');
              final newToken = await user.getIdToken(true);
              if (newToken != null) {
                options.headers['Authorization'] = 'Bearer $newToken';
              }
            } catch (refreshError) {
              debugPrint('🚨 AuthInterceptor: Token refresh failed: $refreshError');
            }
          }
        } catch (e) {
          debugPrint('🚨 AuthInterceptor Error: $e');
        }
      } else {
        debugPrint('⚠️ AuthInterceptor: NO AUTHENTICATED USER FOUND! Header will be MISSING.');
        debugPrint('Current Path: ${options.path}');
      }
    } catch (e) {
      debugPrint('🚨 AuthInterceptor Global Error: $e');
    }

    debugPrint('📤 Request Headers: ${options.headers.keys.join(', ')}');
    return handler.next(options);
  }

  /// Server-driven logout translation.
  /// 401 → expired token → refresh and retry, or session revoked / device mismatch
  /// 403 → account blocked / proxy attempt / hardware violation
  /// Pattern matches the Student app interceptor; keep them in sync.
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;

    if (statusCode == 401) {
      final detail = _extractDetail(err);

      // Check for security revocation first (don't retry these)
      if (_isSecurityRevocation(detail)) {
        ForceLogoutService().execute(
          reason: ForceLogoutReason.sessionRevoked,
          message: detail,
        );
        return handler.next(err);
      }

      // Check for device/hardware mismatch (don't retry)
      if (detail?.toLowerCase().contains('hardware') == true ||
          detail?.toLowerCase().contains('device') == true) {
        ForceLogoutService().execute(
          reason: ForceLogoutReason.deviceMismatch,
          message: detail,
        );
        return handler.next(err);
      }

      // Attempt token refresh and retry for all other 401s (likely expired token)
      debugPrint('🔄 AuthInterceptor: 401 received. Attempting token refresh and retry...');
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final newToken = await user.getIdToken(true);
          if (newToken != null && err.requestOptions.headers.containsKey('Authorization')) {
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final response = await _dio.fetch(err.requestOptions);
            return handler.resolve(response);
          }
        }
      } catch (refreshError) {
        debugPrint('🚨 AuthInterceptor: Token refresh + retry failed: $refreshError');
      }

      // Refresh + retry failed. Fall through to ForceLogout.
      ForceLogoutService().execute(
        reason: ForceLogoutReason.sessionRevoked,
        message: detail ?? 'Session expired. Please login again.',
      );
      return handler.next(err);
    }

    if (statusCode == 403) {
      final detail = _extractDetail(err);
      debugPrint('🚨 AuthInterceptor: 403 Forbidden — $detail');

      if (detail?.toUpperCase().contains('ACCOUNT_SUSPENDED') == true ||
          detail?.toUpperCase().contains('BLOCKED') == true ||
          detail?.toLowerCase().contains('suspend') == true) {
        ForceLogoutService().execute(
          reason: ForceLogoutReason.accountBlocked,
          message: detail,
        );
        return handler.next(err);
      }

      if (detail?.toUpperCase().contains('DEVICE_MISMATCH') == true ||
          detail?.toUpperCase().contains('PROXY') == true ||
          detail?.toLowerCase().contains('hardware') == true) {
        ForceLogoutService().execute(
          reason: ForceLogoutReason.deviceMismatch,
          message: detail,
        );
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  String? _extractDetail(DioException err) {
    try {
      final data = err.response?.data;
      if (data is Map) {
        return data['message'] as String? ?? 
               data['detail'] as String? ?? 
               data['error'] as String?;
      }
      if (data is String) {
        return data;
      }
    } catch (_) {}
    return err.message;
  }

  bool _isSecurityRevocation(String? detail) {
    if (detail == null) return false;
    final lower = detail.toLowerCase();
    return lower.contains('revoked') ||
           lower.contains('terminated') ||
           lower.contains('session has been revoked');
  }
}
