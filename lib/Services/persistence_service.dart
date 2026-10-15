import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'faculty_service.dart';
import 'package:intelli_attend_faculty/Theme/theme_controller.dart';

class PersistenceService {
  static final PersistenceService _instance = PersistenceService._internal();
  factory PersistenceService() => _instance;
  PersistenceService._internal();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _hiveEncryptionKey = 'hive_encryption_key';
  static const _jwtStorageKey = 'backend_jwt';

  static late Box facultyBox;
  static late Box academicBox;
  static late SharedPreferences prefs;

  static Box? notificationsBox;
  static Box? attendanceBox;
  static Box? deviceBox;
  static Box? messagingBox;

  static HiveAesCipher? _cipher;

  Future<void> _ensureEncryptionKey() async {
    String? existingKey;
    try {
      existingKey = await _secureStorage.read(key: _hiveEncryptionKey);
    } catch (e) {
      debugPrint('[PersistenceService] Corrupted secure storage key detected: $e. Resetting storage.');
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}
      existingKey = null;
    }

    if (existingKey == null) {
      final key = Hive.generateSecureKey();
      existingKey = base64Encode(key);
      try {
        await _secureStorage.write(key: _hiveEncryptionKey, value: existingKey);
      } catch (e) {
        debugPrint('[PersistenceService] Failed to write encryption key: $e');
      }
    }

    try {
      final keyBytes = base64Decode(existingKey);
      _cipher = HiveAesCipher(keyBytes);
    } catch (e) {
      debugPrint('[PersistenceService] Failed to decode encryption key: $e. Generating fallback.');
      final fallbackKey = Hive.generateSecureKey();
      _cipher = HiveAesCipher(fallbackKey);
    }
  }

  static Future<Box> _safeOpenBox(String name, {HiveCipher? cipher}) async {
    try {
      return await Hive.openBox(name, encryptionCipher: cipher);
    } catch (e) {
      debugPrint('[PersistenceService] Error opening Hive box $name: $e. Resetting corrupted box.');
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
      return await Hive.openBox(name, encryptionCipher: cipher);
    }
  }

  /// Track A — Fast persistence path.
  /// Opens only the micro-essential Hive boxes needed for instant cache lookup
  /// (faculty_profile, academic_data) plus SharedPreferences.
  /// Completes in ~100ms. The UI gate is bound to this future.
  Future<void> initMinimal() async {
    await Hive.initFlutter();
    await _ensureEncryptionKey();

    facultyBox = await _safeOpenBox('faculty_profile', cipher: _cipher);
    academicBox = await _safeOpenBox('academic_data', cipher: _cipher);
    prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  /// Track B — Deferred box opening.
  /// Opens remaining Hive boxes (attendance, notifications, device_data,
  /// messaging) after the first frame has rendered. Called from _bootstrapBackground.
  Future<void> initRemainingBoxes() async {
    attendanceBox = await _safeOpenBox('attendance', cipher: _cipher);
    notificationsBox = await _safeOpenBox('notifications', cipher: _cipher);
    deviceBox = await _safeOpenBox('device_data', cipher: _cipher);
    messagingBox = await _safeOpenBox('messaging', cipher: _cipher);
    await NotificationService().loadFromDisk();
  }

  /// Convenience: runs initMinimal + initRemainingBoxes sequentially.
  /// Used by callers that don't need the two-track split.
  Future<void> init() async {
    await initMinimal();
    await initRemainingBoxes();
  }

  static Future<void> saveSubjectsCache(Map<String, String> subjects) async {
    await academicBox.put('subjects_cache', subjects);
  }

  static Map<String, String> getSubjectsCache() {
    final data = academicBox.get('subjects_cache');
    if (data == null) return {};
    return Map<String, String>.from(data);
  }

  static Future<void> saveBackendToken(String token) async {
    await _secureStorage.write(key: _jwtStorageKey, value: token);
  }

  static Future<String?> getBackendToken() async {
    try {
      return await _secureStorage.read(key: _jwtStorageKey);
    } catch (e) {
      debugPrint('[PersistenceService] Error reading token: $e');
      return null;
    }
  }

  static Future<void> clearBackendToken() async {
    await _secureStorage.delete(key: _jwtStorageKey);
  }

  static String? get deviceId => deviceBox?.get('device_id');
  static String? get deviceFingerprint => deviceBox?.get('device_fingerprint');

  static Future<void> saveDeviceInfo({
    required String deviceId,
    required String deviceFingerprint,
  }) async {
    await deviceBox?.put('device_id', deviceId);
    await deviceBox?.put('device_fingerprint', deviceFingerprint);
  }

  /// Generic cache helpers on academicBox (ported from Student pattern).
  static Future<void> cachePut(String key, dynamic value) async {
    await academicBox.put(key, value);
  }

  static dynamic cacheGet(String key) => academicBox.get(key);

  static Future<void> cacheRemove(String key) async {
    await academicBox.delete(key);
  }

  Future<void> clearAllData() async {
    await notificationsBox?.clear();
    await attendanceBox?.clear();
    await facultyBox.clear();
    await academicBox.clear();
    await deviceBox?.clear();

    await prefs.clear();
    await _secureStorage.delete(key: _jwtStorageKey);

    NotificationService().clearAllLocally();
    await FacultyService.resetToDefaults();
    await ThemeController.resetToDefaults();
  }
}
