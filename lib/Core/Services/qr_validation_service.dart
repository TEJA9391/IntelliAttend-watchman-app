import 'dart:convert';

/// QR Token Protocol v7.0 — Local Pre-Validation Service
///
/// v7.0 FORMAT (compact binary):
///   IATT::<27 Base64URL chars>
///
///   27 Base64URL chars → 20 bytes binary:
///     Bytes  0-5:  SHA-256(session_id)[:6]    — session fingerprint
///     Bytes  6-9:  Unix timestamp (seconds)    — big-endian uint32
///     Bytes 10-19: HMAC-SHA256(key, bytes[0:10])[:10]
///
/// SECURITY MODEL (server-authoritative):
///   The QR signing secret (QR_SECRET_KEY) is held only by the SmartBoard
///   and the backend server. It is NEVER transmitted to the faculty device.
///   Local HMAC verification is impossible — intentionally so.
///   The server performs the authoritative HMAC + time-window + GPS check.
///
/// LOCAL PRE-CHECKS (this class — Gate A bouncer only):
///   1. Format check — must start with IATT:: prefix.
///   2. Length check — must be exactly 33 chars (IATT:: + 27 Base64URL).
///   3. Base64URL decode — must yield exactly 20 bytes.
///   4. Timestamp drift check — must be within 7 seconds of phone's clock.
///
///   These save a server round-trip for malformed or stale tokens.
///   Anything that passes these is forwarded to the server for the real verdict.
class QRValidationService {
  static const String _prefix = 'IATT';

  /// v7.0: exact token length (IATT:: + 27 Base64URL chars)
  static const int _v7TokenLength = 33;

  /// v7.0: decoded binary payload size in bytes
  static const int _v7PayloadBytes = 20;

  /// Allowed drift for v7.0 timestamp check (7 seconds).
  static const int _allowedDriftMs = 7000;

  QRValidationService();

  /// Detects whether a raw scanned token is v7.0 format.
  static bool isV7Token(String rawToken) {
    return rawToken.length == _v7TokenLength &&
        rawToken.startsWith('$_prefix::');
  }

  /// Validates the QR token's local properties before sending to the server.
  /// Set [skipTimeCheck] to true when the device booted offline without a
  /// server clock sync — the server validates the time window instead.
  ValidationResult validate({
    required String prefix,
    required String qrPayload,
    required int facultyCurrentTimeMs,
    bool skipTimeCheck = false,
  }) {
    // 1. Prefix validation
    if (prefix != _prefix) {
      return ValidationResult.invalid(
        error: 'INVALID_QR_FORMAT',
        message: 'QR code prefix must be "$_prefix"',
      );
    }

    return _validateV7Token(
      qrPayload: qrPayload,
      facultyCurrentTimeMs: facultyCurrentTimeMs,
      skipTimeCheck: skipTimeCheck,
    );
  }

  /// v7.0 token validation: Base64URL decode → 20-byte binary → timestamp check.
  ValidationResult _validateV7Token({
    required String qrPayload,
    required int facultyCurrentTimeMs,
    bool skipTimeCheck = false,
  }) {
    // 1. Check no URL-unsafe characters in Base64URL part
    if (qrPayload.contains('+') ||
        qrPayload.contains('/') ||
        qrPayload.contains('=')) {
      return ValidationResult.invalid(
        error: 'INVALID_QR_FORMAT',
        message: 'v7.0 token contains invalid Base64URL characters',
      );
    }

    // 2. Decode Base64URL (should yield exactly 20 bytes)
    List<int> raw;
    try {
      String padded = qrPayload;
      while (padded.length % 4 != 0) {
        padded += '=';
      }
      raw = base64Url.decode(padded);
    } catch (e) {
      return ValidationResult.invalid(
        error: 'INVALID_QR_FORMAT',
        message: 'Failed to decode v7.0 QR payload',
      );
    }

    if (raw.length != _v7PayloadBytes) {
      return ValidationResult.invalid(
        error: 'INVALID_QR_FORMAT',
        message:
            'v7.0 token decoded to ${raw.length} bytes, expected $_v7PayloadBytes',
      );
    }

    // 3. Extract sidHash and timestamp, check time window
    String sidHashHex = '';
    try {
      final sidHash = raw.sublist(0, 6);
      sidHashHex =
          sidHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

      final timestampSec = (raw[6] << 24) |
          (raw[7] << 16) |
          (raw[8] << 8) |
          raw[9];
      final timestampMs = timestampSec * 1000;

      if (!skipTimeCheck) {
        final drift = (facultyCurrentTimeMs - timestampMs).abs();
        if (drift > _allowedDriftMs) {
          return ValidationResult.invalid(
            error: 'TOKEN_EXPIRED',
            message: 'v7.0 QR token expired (drift: ${drift}ms)',
          );
        }
      }
    } catch (e) {
      return ValidationResult.invalid(
        error: 'INVALID_QR_FORMAT',
        message: 'Failed to extract timestamp from v7.0 token',
      );
    }

    return ValidationResult.valid(
      sessionId: sidHashHex,
      tStart: 0,
      tEnd: 0,
    );
  }
}

/// Validation result.
class ValidationResult {
  final bool isValid;
  final String? error;
  final String? message;
  final String? sessionId;
  final int? tStart;
  final int? tEnd;

  ValidationResult._({
    required this.isValid,
    this.error,
    this.message,
    this.sessionId,
    this.tStart,
    this.tEnd,
  });

  factory ValidationResult.valid({
    required String sessionId,
    required int tStart,
    required int tEnd,
  }) {
    return ValidationResult._(
      isValid: true,
      sessionId: sessionId,
      tStart: tStart,
      tEnd: tEnd,
    );
  }

  factory ValidationResult.invalid({
    required String error,
    required String message,
  }) {
    return ValidationResult._(
      isValid: false,
      error: error,
      message: message,
    );
  }
}
