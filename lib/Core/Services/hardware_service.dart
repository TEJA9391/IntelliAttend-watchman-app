import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intelli_attend_faculty/Core/Models/device_data.dart';

class HardwareService {
  static const _channel = MethodChannel('com.intelliattend.faculty/hardware');

  // v14.0 PERFORMANCE CACHE
  static DeviceData? _cachedSnapshot;
  static DateTime? _lastFetchTime;
  static const _cacheDuration = Duration(seconds: 30);

  /// Force clear the cache (called on app resume for security)
  static void clearCache() {
    debugPrint('📱 HARDWARE: Security Cache Invalidated');
    _cachedSnapshot = null;
    _lastFetchTime = null;
  }

  /// Gather full security and hardware snapshot.
  /// Accepts [nonce] for Play Integrity token and [forceRefresh] to bypass cache.
  static Future<DeviceData> getDeviceSnapshot({String? nonce, bool forceRefresh = false}) async {
    // 1. Return cached if valid
    if (!forceRefresh && _cachedSnapshot != null && _lastFetchTime != null) {
      final diff = DateTime.now().difference(_lastFetchTime!);
      if (diff < _cacheDuration) {
        debugPrint('📱 HARDWARE: Returning cached snapshot (${diff.inSeconds}s old)');
        return _cachedSnapshot!;
      }
    }

    try {
      debugPrint('📱 HARDWARE: Fetching fresh device snapshot (Native Bridge)...');
      final fingerprint = await _channel.invokeMethod<String>('getDeviceFingerprint') ?? 'unknown';
      final isRooted = await _channel.invokeMethod<bool>('isDeviceRooted') ?? false;
      final metadata = await _channel.invokeMethod<Map>('getDeviceMetadata') ?? {};

      final deviceId = metadata['device_id'] ?? await _channel.invokeMethod<String>('getDeviceId') ?? 'unknown';

      // Collect extended device info in parallel
      final results = await Future.wait([
        _channel.invokeMethod<String>('getDeviceName') ?? Future.value(''),
        _channel.invokeMethod<String>('getCpuArchitecture') ?? Future.value(''),
        _channel.invokeMethod<String>('getScreenResolution') ?? Future.value(''),
        _channel.invokeMethod<String>('getLocalIpAddress') ?? Future.value(''),
        _channel.invokeMethod<String>('getNetworkType') ?? Future.value(''),
        _channel.invokeMethod<bool>('hasScreenLock') ?? Future.value(false),
      ]);

      String? integrityToken;
      if (nonce != null) {
        integrityToken = await _channel.invokeMethod<String>('getIntegrityToken', {'nonce': nonce});
        if (integrityToken?.startsWith('error_') == true) {
          debugPrint('HardwareService: Integrity Token Native Error: $integrityToken');
          integrityToken = null;
        }
      }

      final packageInfo = await PackageInfo.fromPlatform();

      final newData = DeviceData(
        deviceId: deviceId,
        fingerprint: fingerprint,
        integrityToken: integrityToken,
        model: metadata['model'] ?? 'Unknown',
        manufacturer: metadata['manufacturer'] ?? 'Unknown',
        brand: metadata['brand'] ?? '',
        osVersion: metadata['androidVersion'] ?? metadata['os_version'] ?? 'Unknown',
        sdkVersion: metadata['sdkVersion'] ?? '',
        deviceName: results[0] as String,
        cpuArchitecture: results[1] as String,
        screenResolution: results[2] as String,
        localIpAddress: results[3] as String,
        networkType: results[4] as String,
        hasScreenLock: results[5] as bool,
        isRooted: isRooted,
        appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      );

      // 2. Update cache
      _cachedSnapshot = newData;
      _lastFetchTime = DateTime.now();

      return newData;
    } catch (e) {
      debugPrint('HardwareService Error: $e');
      return DeviceData(
        deviceId: 'error',
        fingerprint: 'error',
        model: 'Error',
        manufacturer: 'Error',
        osVersion: 'Error',
        isRooted: true,
        appVersion: '0.0.0',
      );
    }
  }

  /// Check if the device is rooted (quick check)
  static Future<bool> isRooted() async {
    return await _channel.invokeMethod<bool>('isDeviceRooted') ?? false;
  }

  // ── Monotonic Clock ──────────────────────────────────────────────────────

  /// Returns the device uptime in milliseconds via the hardware monotonic clock
  /// (SystemClock.elapsedRealtime on Android / CLOCK_MONOTONIC_RAW on iOS).
  /// NOT affected by user changing the OS wall clock.
  static Future<int> getMonotonicTime() async {
    return await _channel.invokeMethod<int>('getMonotonicTime') ?? 0;
  }

  // ── Hardware Keypair Management ──────────────────────────────────────────

  /// Generate an asymmetric keypair in Android KeyStore / iOS Secure Enclave.
  /// Optionally passes an [challenge] for attestation (Play Integrity).
  static Future<bool> generateKeyPair({String? challenge}) async {
    return await _channel.invokeMethod<bool>('generateKeyPair', {
      if (challenge != null) 'challenge': challenge,
    }) ?? false;
  }

  /// Retrieve the attestation certificate chain (Android) or assertion (iOS).
  static Future<List<String>?> getAttestationCertChain() async {
    final result = await _channel.invokeMethod<List>('getAttestationCertChain');
    return result?.cast<String>();
  }

  /// Sign [data] with the hardware-backed private key.
  static Future<String?> signPayload(String data) async {
    return await _channel.invokeMethod<String>('signPayload', {'data': data});
  }

  /// Retrieve the public key from the hardware keypair.
  static Future<String?> getPublicKey() async {
    return await _channel.invokeMethod<String>('getPublicKey');
  }

  /// Check if a hardware keypair has been generated.
  static Future<bool> isKeyPairGenerated() async {
    return await _channel.invokeMethod<bool>('isKeyPairGenerated') ?? false;
  }

  /// Delete the hardware keypair (used during scorched-earth logout).
  static Future<void> deleteKeyPair() async {
    await _channel.invokeMethod<void>('deleteKeyPair');
  }

  // ── Time Integrity ───────────────────────────────────────────────────────

  /// Check if the device's auto date/time setting is enabled.
  /// On Android, this prevents manual clock manipulation.
  static Future<bool> isAutoTimeEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAutoTimeEnabled') ?? false;
    } catch (e) {
      debugPrint('📱 HARDWARE: isAutoTimeEnabled() failed — $e');
      return false;
    }
  }

  /// Check if the device's auto timezone setting is enabled.
  static Future<bool> isAutoTimeZoneEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isAutoTimeZoneEnabled') ?? false;
    } catch (e) {
      debugPrint('📱 HARDWARE: isAutoTimeZoneEnabled() failed — $e');
      return false;
    }
  }

  /// Open the OS date/time settings for the user to enable auto time.
  static Future<void> openDateSettings() async {
    try {
      await _channel.invokeMethod<void>('openDateSettings');
    } catch (_) {}
  }
}
