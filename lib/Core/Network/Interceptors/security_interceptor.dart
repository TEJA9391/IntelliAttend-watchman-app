import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';
import 'package:intelli_attend_faculty/Core/Services/force_logout_service.dart';

/// Interceptor to automatically attach secure device identifiers to every
/// request, and to translate server-side device/security rejections (403)
/// into a hard force-logout.
class SecurityInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final deviceData = await HardwareService.getDeviceSnapshot();

      options.headers['X-Device-ID'] = deviceData.deviceId;
      options.headers['X-Device-Fingerprint'] = deviceData.fingerprint;
      options.headers['X-Device-Model'] = deviceData.model;
      options.headers['X-App-Version'] = deviceData.appVersion;

      debugPrint('📱 SECURITY: Device Identity Attached');
      debugPrint('X-Device-ID: ${deviceData.deviceId}');
    } catch (e) {
      debugPrint('SecurityInterceptor Error: $e');
    }

    return handler.next(options);
  }

  /// Server-side device/hardware rejections (403) → ForceLogoutService.
  /// 426 (Upgrade Required) → appDeprecated force logout.
  /// Auth-related 401/403 are handled by AuthInterceptor; this interceptor
  /// only catches device-binding rejections that bypass auth (e.g., shared
  /// device detection, hardware integrity violations).
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 426 Upgrade Required — server mandates a newer app version
    if (err.response?.statusCode == 426) {
      debugPrint('🚨 SecurityInterceptor: 426 Upgrade Required');
      ForceLogoutService().execute(
        reason: ForceLogoutReason.appDeprecated,
        message: 'A mandatory update is required. Please update your app.',
      );
      return handler.next(err);
    }

    if (err.response?.statusCode == 403) {
      final detail = _extractDetail(err);
      debugPrint('🚨 SecurityInterceptor: 403 — $detail');

      final upper = detail?.toUpperCase() ?? '';
      final lower = detail?.toLowerCase() ?? '';

      if (upper.contains('SHARED_DEVICE') ||
          upper.contains('HARDWARE_VIOLATION') ||
          upper.contains('DEVICE_MISMATCH') ||
          upper.contains('PROXY') ||
          lower.contains('hardware') ||
          lower.contains('device fingerprint')) {
        ForceLogoutService().execute(
          reason: ForceLogoutReason.deviceMismatch,
          message: detail,
        );
      }
    }
    return handler.next(err);
  }

  String? _extractDetail(DioException err) {
    try {
      final data = err.response?.data;
      if (data is Map) {
        return data['message'] as String? ?? data['detail'] as String?;
      }
      if (data is String) {
        return data;
      }
    } catch (_) {}
    return err.message;
  }
}
