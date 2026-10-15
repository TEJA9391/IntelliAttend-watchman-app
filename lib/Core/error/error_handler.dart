import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

/// Structured AppError for professional UI rendering.
class AppError {
  final String title;
  final String message;
  final IconData icon;
  final String actionLabel;
  final Color? color;

  const AppError({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel = 'Try Again',
    this.color,
  });
}

class ErrorHandler {
  static const AppError _genericError = AppError(
    title: 'Unexpected Error',
    message: 'We encountered an unexpected condition. Our technical team has been notified.',
    icon: Icons.error_outline_rounded,
  );

  /// Professional Error Sanitizer for Flutter
  static AppError sanitize(dynamic error) {
    if (error == null) return _genericError;

    // Handle Firebase Auth Exceptions
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
          return const AppError(
            title: 'Invalid Credentials',
            message: 'We couldn\'t verify your identity. Please check your ID and password.',
            icon: Icons.warning_rounded,
          );
        case 'user-disabled':
          return const AppError(
            title: 'Account Restricted',
            message: 'Your account has been restricted. Please visit the Academic Office for resolution.',
            icon: Icons.no_accounts_rounded,
          );
        case 'too-many-requests':
          return const AppError(
            title: 'Security Lockdown',
            message: 'Too many failed attempts. Access is temporarily restricted for your protection.',
            icon: Icons.access_time_rounded,
          );
        case 'network-request-failed':
          return const AppError(
            title: 'Network Timeout',
            message: 'We are unable to reach the portal. Please check your data connection.',
            icon: Icons.wifi_off_rounded,
          );
        default:
          return AppError(
            title: 'Authentication Error',
            message: error.message ?? 'Secure sign-in failed. Please try again.',
            icon: Icons.lock_outline_rounded,
          );
      }
    }

    // Handle Firestore Exceptions
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return const AppError(
            title: 'Access Denied',
            message: 'You do not have the required clearance to access this module.',
            icon: Icons.warning_rounded,
          );
        case 'unavailable':
          return const AppError(
            title: 'Systems Offline',
            message: 'The attendance synchronization service is temporarily unavailable.',
            icon: Icons.storage_rounded,
          );
        default:
          return AppError(
            title: 'Sync Error',
            message: error.message ?? 'Data synchronization failed.',
            icon: Icons.refresh_rounded,
          );
      }
    }

    // Handle Dio/Network Exceptions
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return const AppError(
          title: 'Gateway Timeout',
          message: 'The server is taking too long to respond. This might be due to a poor connection.',
          icon: Icons.access_time_rounded,
        );
      }
      if (error.type == DioExceptionType.connectionError) {
        return const AppError(
          title: 'No Connectivity',
          message: 'No active internet connection detected. Please verify your settings.',
          icon: Icons.wifi_off_rounded,
        );
      }
      if (error.response?.statusCode == 403) {
        return const AppError(
          title: 'Unauthorized',
          message: 'Your session credentials are no longer valid. Please re-authenticate.',
          icon: Icons.no_accounts_rounded,
          actionLabel: 'Sign In',
        );
      }
    }

    // Generic technical string filtering
    final String msg = error.toString().toLowerCase();
    if (msg.contains('firebase') || 
        msg.contains('exception') || 
        msg.contains('null') || 
        msg.contains('undefined')) {
      return _genericError;
    }

    return AppError(
      title: 'Operational Error',
      message: error.toString(),
      icon: Icons.error_outline_rounded,
    );
  }

  /// Professional Error Dialog
  static void showVisualError(BuildContext context, dynamic error) {
    final appError = sanitize(error);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ErrorSheet(appError: appError),
    );
  }
}

class _ErrorSheet extends StatelessWidget {
  final AppError appError;

  const _ErrorSheet({required this.appError});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151515) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              appError.icon,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            appError.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            appError.message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                appError.actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
