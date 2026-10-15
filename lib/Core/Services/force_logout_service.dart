import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Core/Services/security_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Auth/login_screen.dart';

/// Reasons the server may force-eject this client. Mirrors the Student app
/// enum so audit logs and UX strings stay aligned across roles.
enum ForceLogoutReason {
  sessionRevoked,
  deviceMismatch,
  accountBlocked,
  securityViolation,
  adminForceLogout,
  multipleDevicesDetected,
  appDeprecated,
}

/// Server-driven logout pipeline.
///
/// Triggered from the auth/security interceptors when a 401/403 indicates
/// the server has terminated this session (Redis kill switch, BLOCKED
/// status, device-mismatch, etc). Wipes every piece of local state in a
/// fixed order, then routes to the LoginScreen with a reason message.
///
/// Faculty version differs from Student: there is no PendingScansService
/// because faculty never queue offline scans.
class ForceLogoutService {
  static final ForceLogoutService _instance = ForceLogoutService._internal();
  factory ForceLogoutService() => _instance;
  ForceLogoutService._internal();

  static BuildContext? _navigatorContext;
  static bool _isExecuting = false;

  /// Wired from `main.dart` `MaterialApp.builder` so the service can navigate
  /// from outside the widget tree (interceptor callbacks have no context).
  static void setNavigatorContext(BuildContext context) {
    _navigatorContext = context;
  }

  Future<void> execute({
    required ForceLogoutReason reason,
    String? message,
  }) async {
    debugPrint('ForceLogout bypassed — authentication is removed for Watchman App');
  }

  String _defaultMessage(ForceLogoutReason reason) {
    switch (reason) {
      case ForceLogoutReason.sessionRevoked:
        return 'Your session has been terminated. Please log in again.';
      case ForceLogoutReason.deviceMismatch:
        return 'Security violation: Device mismatch detected. Use your registered device.';
      case ForceLogoutReason.accountBlocked:
        return 'Your account has been suspended due to a security violation. Contact administration.';
      case ForceLogoutReason.securityViolation:
        return 'Your session was terminated for security reasons.';
      case ForceLogoutReason.adminForceLogout:
        return 'An administrator has terminated your session. Please log in again.';
      case ForceLogoutReason.multipleDevicesDetected:
        return 'Login detected on another device. You have been signed out.';
      case ForceLogoutReason.appDeprecated:
        return 'This app version is no longer supported. Please update to the latest version.';
    }
  }

  void _navigateToLogin(String message) {
    if (_navigatorContext == null || !_navigatorContext!.mounted) {
      debugPrint('⚠️ ForceLogoutService: No navigator context, cannot redirect to login');
      return;
    }

    Navigator.of(_navigatorContext!, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialError: message),
        settings: const RouteSettings(name: 'LoginScreen'),
      ),
      (route) => false,
    );
  }
}
