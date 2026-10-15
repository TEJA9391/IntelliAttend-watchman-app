import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';

/// Hardware Keypair Lifecycle Service — Faculty App
///
/// Two-phase enrollment:
///   Phase 1 (boot-time, pre-DI): Generates the hardware keypair in
///   Android KeyStore / iOS Secure Enclave. Local-only, no network.
///   Safe to call from main.dart with `unawaited()`.
///
///   Phase 2 (post-DI): Sends the public key + attestation to the server.
///   Requires the Faculty backend to expose `/api/v1/faculty/enrollment`
///   endpoints. Until those endpoints are deployed, Phase 2 is a no-op
///   and the public key is sent with every session mutation request.
class KeyEnrollmentService {
  static const String _prefsKey = 'keystore_enrolled_v2';

  static bool _enrolled = false;
  static bool get isEnrolled => _enrolled;

  /// Phase 1 (boot-time, pre-DI). Generates the hardware keypair once and
  /// persists the enrolled flag. Does NOT reach out to the server.
  ///
  /// Called from main.dart with `unawaited(KeyEnrollmentService.enroll())`.
  static Future<bool> enroll() async {
    if (_enrolled) return true;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) == true) {
      _enrolled = true;
      debugPrint('[KeyEnrollment] Already enrolled (disk)');
      return true;
    }

    try {
      final generated = await HardwareService.generateKeyPair();
      if (!generated) {
        debugPrint('[KeyEnrollment] Key pair generation failed');
        return false;
      }
      await prefs.setBool(_prefsKey, true);
      _enrolled = true;
      debugPrint('[KeyEnrollment] Hardware key pair enrolled successfully');
      return true;
    } catch (e) {
      debugPrint('[KeyEnrollment] Enrollment failed: $e');
      return false;
    }
  }

  /// Phase 2 (post-DI). Sends the public key to the server for enrollment.
  ///
  /// NOTE: This requires the Faculty backend to expose enrollment endpoints.
  /// Until then, this is a graceful no-op — the public key is sent with
  /// every API request via SecurityInterceptor.
  static Future<void> synchronizeWithServer() async {
    try {
      final publicKey = await HardwareService.getPublicKey();
      if (publicKey == null || publicKey.isEmpty) {
        debugPrint('[KeyEnrollment] No public key to sync — generate first');
        return;
      }

      // TODO: Implement when Faculty backend enrollment endpoints are deployed.
      // POST /api/v1/faculty/enrollment with publicKey + attestationCert.
      debugPrint('[KeyEnrollment] Server sync skipped — backend endpoints pending');
    } catch (e) {
      debugPrint('[KeyEnrollment] Server sync failed: $e');
    }
  }

  /// Revoke the hardware keypair and clear the enrolled flag.
  static Future<void> revoke() async {
    await HardwareService.deleteKeyPair();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _enrolled = false;
    debugPrint('[KeyEnrollment] Hardware key pair revoked');
  }
}
