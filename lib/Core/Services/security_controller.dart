import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';
import 'package:intelli_attend_faculty/Core/Services/key_enrollment_service.dart';
import 'package:intelli_attend_faculty/Services/permission_service.dart';
import 'package:intelli_attend_faculty/Services/time_sync_service.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';

enum SecurityState { checking, permissionsMissing, authenticating, ready, compromised }

class SecurityController extends ChangeNotifier with WidgetsBindingObserver {
  static SecurityController? _instance;
  final LocalAuthentication _auth = LocalAuthentication();

  /// App starts UNLOCKED. Never blocks the UI after login.
  /// Lock only activates when user enables biometric lock in Settings.
  bool _isLocked = false;
  bool get isLocked => _isLocked;

  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;

  bool _isCompromised = false;
  bool get isCompromised => _isCompromised;

  String _violationReason = '';
  String get violationReason => _violationReason;

  bool _bypassDetected = false;
  bool get bypassDetected => _bypassDetected;

  String? _deviceFingerprint;
  String? get deviceFingerprint => _deviceFingerprint;

  bool _initialCheckComplete = false;
  AppLifecycleState _lifecycleState = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  AppLifecycleState get lifecycleState => _lifecycleState;

  /// When true, lock on background and require biometric to unlock.
  bool _biometricLockEnabled = false;
  bool get biometricLockEnabled => _biometricLockEnabled;

  SecurityState get state {
    if (_isCompromised) return SecurityState.compromised;
    if (!_initialCheckComplete) return SecurityState.checking;
    if (_isAuthenticating) return SecurityState.authenticating;
    if (_isLocked) return SecurityState.permissionsMissing;
    return SecurityState.ready;
  }

  bool _notificationsOk = false;
  bool _autoTimeOk = true;
  bool _autoTimeZoneOk = true;
  bool _timezoneIndiaOk = true;

  bool _getCachedPermission(String key, {bool defaultValue = false}) {
    if (PersistenceService.isInitialized) {
      return PersistenceService.prefs.getBool('security_pillar_$key') ?? defaultValue;
    }
    return defaultValue;
  }

  bool get notificationsOk => _initialCheckComplete ? _notificationsOk : _getCachedPermission('notifications');
  bool get autoTimeOk => _initialCheckComplete ? _autoTimeOk : _getCachedPermission('autoTime', defaultValue: true);
  bool get autoTimeZoneOk => _initialCheckComplete ? _autoTimeZoneOk : _getCachedPermission('autoTimeZone', defaultValue: true);
  bool get timezoneIndiaOk => _initialCheckComplete ? _timezoneIndiaOk : _getCachedPermission('timezoneIndia', defaultValue: true);

  bool get arePermissionsOk => notificationsOk;

  SecurityController() {
    _instance = this;
    _loadBiometricPreference();
    _performInitialSecurityCheck();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _isCameraActive = false;

  void setCameraActive(bool active) {
    _isCameraActive = active;
  }

  Future<void> _loadBiometricPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _biometricLockEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
      _safeNotify();
    } catch (_) {}
  }

  /// Toggle biometric lock from Settings. Enabling requires biometric verification.
  Future<void> setBiometricLockEnabled(bool enabled) async {
    _biometricLockEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_lock_enabled', enabled);
    } catch (_) {}
    if (!enabled && _isLocked) {
      unlock();
    }
    _safeNotify();
  }

  /// Lifecycle — lock on background ONLY if biometric lock is enabled.
  /// NEVER authenticate on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;

    if (_isAuthenticating && state == AppLifecycleState.inactive) return;
    if (_isCameraActive && state == AppLifecycleState.inactive) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (state == AppLifecycleState.inactive && !_isAuthenticating)) {
      if (_biometricLockEnabled) {
        debugPrint('🔒 Security: Biometric lock enabled. Locking on background.');
        lock();
      }
    }

    if (state == AppLifecycleState.resumed) {
      HardwareService.clearCache();
      Future.delayed(const Duration(milliseconds: 100), () async {
        await _performInitialSecurityCheck();
        await TimeSyncService.compensateDrift();
        await performSecurityAudit();
      });
    }
  }

  void _setLocked(bool locked) {
    if (_isLocked == locked) return;
    _isLocked = locked;
    debugPrint('🔒 Security: Portal ${_isLocked ? "Locked" : "Unlocked"}.');
  }

  void unlock() {
    _setLocked(false);
    _bypassDetected = false;
    _safeNotify();
  }

  void lock() {
    _setLocked(true);
    _bypassDetected = false;
    _safeNotify();
  }

  static void resetAll() {
    final inst = _instance;
    if (inst == null) return;
    inst._setLocked(true);
    inst._isCompromised = false;
    inst._violationReason = '';
    inst._bypassDetected = false;
    inst._initialCheckComplete = false;
    inst._checkPermissionsSilently();
    inst._safeNotify();
  }

  /// Biometric authentication with 15s timeout.
  /// Only called from explicit user actions: LockScreen tap, Settings toggle, protected actions.
  /// Never called automatically on startup or resume.
  Future<bool> authenticate() async {
    if (_isCompromised) return false;
    if (!_isLocked) return true;
    if (_isAuthenticating) return false;

    _isAuthenticating = true;
    _safeNotify();

    try {
      final bioResults = await Future.wait([
        _auth.canCheckBiometrics,
        _auth.isDeviceSupported(),
      ]);
      final bool canCheck = bioResults[0];
      final bool isSupported = bioResults[1];

      if (!canCheck || !isSupported) {
        debugPrint('🔒 Security: Biometrics unavailable. Auto-unlocking.');
        _isAuthenticating = false;
        _setLocked(false);
        _bypassDetected = false;
        _safeNotify();
        FacultyService.onAppResume();
        return true;
      }

      final stopwatch = Stopwatch()..start();
      final authFuture = _auth.authenticate(
        localizedReason: 'Authenticate to access IntelliAttend',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      final bool didAuthenticate = await authFuture.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('🔒 Security: Auth timed out after 15s.');
          return false;
        },
      );
      stopwatch.stop();
      _isAuthenticating = false;

      if (didAuthenticate) {
        if (stopwatch.elapsedMilliseconds < 350) {
          debugPrint('🔒 Security: Bypass Detected ($stopwatch.elapsedMilliseconds ms). Rejecting.');
          _bypassDetected = true;
          _setLocked(true);
        } else {
          _setLocked(false);
          _bypassDetected = false;
          debugPrint('🔒 Security: Identity Verified. App Unlocked.');
          FacultyService.onAppResume();
        }
      } else {
        _setLocked(true);
      }

      _safeNotify();
      return didAuthenticate;
    } catch (e) {
      debugPrint('🔒 Security: Auth error: $e');
      _isAuthenticating = false;
      _bypassDetected = false;
      _safeNotify();
      return false;
    }
  }

  void _safeNotify() {
    if (!hasListeners) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _performInitialSecurityCheck() async {
    try {
      final snapshot = await HardwareService.getDeviceSnapshot();
      _deviceFingerprint = snapshot.fingerprint;

      if (snapshot.isRooted) {
        _isCompromised = true;
        _violationReason = "SEC_ROOT_DETECTED";
        await executeScorchedEarth('SEC_ROOT_DETECTED');
        _initialCheckComplete = true;
        _safeNotify();
        return;
      }

      await _checkPermissionsSilently();
      _initialCheckComplete = true;
      _safeNotify();
    } catch (e) {
      _initialCheckComplete = true;
      _safeNotify();
      debugPrint('Security Init Error: $e');
    }
  }

  Future<void> performSecurityAudit() async {
    if (!wasCompromised) {
      final snapshot = await HardwareService.getDeviceSnapshot();
      if (snapshot.isRooted) {
        _isCompromised = true;
        _violationReason = "SEC_ROOT_DETECTED";
        await executeScorchedEarth('SEC_ROOT_DETECTED');
        _safeNotify();
        return;
      }
    }

    await _checkPermissionsSilently();
  }

  bool get wasCompromised => _isCompromised;

  Future<bool> verifyIntegrityOnScan() async {
    try {
      final snapshot = await HardwareService.getDeviceSnapshot(forceRefresh: true);
      if (snapshot.isRooted) {
        _isCompromised = true;
        _violationReason = 'SEC_ROOT_DETECTED_SCAN';
        await executeScorchedEarth('SEC_ROOT_DETECTED_SCAN');
        _safeNotify();
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> autoRequestPermissions() async {
    if (arePermissionsOk) return;
    debugPrint('🔒 Security: Auto-Requesting Pillars...');
    await PermissionService().requestAll();
    await _checkPermissionsSilently();
  }

  Future<void> _checkPermissionsSilently() async {
    final service = PermissionService();
    _notificationsOk = await service.isNotificationGranted();
    _autoTimeOk = await HardwareService.isAutoTimeEnabled();
    _autoTimeZoneOk = await HardwareService.isAutoTimeZoneEnabled();
    _timezoneIndiaOk = _isIndiaTimezone();
    _safeNotify();
  }

  bool _isIndiaTimezone() {
    final int offsetMin = DateTime.now().timeZoneOffset.inMinutes;
    return offsetMin == 330;
  }

  Future<void> executeScorchedEarth(String reason) async {
    try {
      final monotonic = await HardwareService.getMonotonicTime();
      final deviceId = _deviceFingerprint ?? 'unknown';

      String? sig;
      String? pub;

      if (await HardwareService.isKeyPairGenerated()) {
        pub = await HardwareService.getPublicKey();
        sig = await HardwareService.signPayload('$reason:$monotonic');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await ApiClient().dio.post(
            '/api/v1/faculty/device/compromised',
            options: Options(headers: {
              'Content-Type': 'application/json',
              'X-Device-ID': deviceId,
            }),
            data: {
              'email': user.email,
              'device_id': deviceId,
              'reason': reason,
              'monotonic_timestamp_ms': monotonic,
              'nonce_or_pill_id': '${user.email}_${DateTime.now().millisecondsSinceEpoch}',
              'signature': sig ?? '',
            },
          );
        } catch (_) {}
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }

      await HardwareService.deleteKeyPair();
      await KeyEnrollmentService.revoke();
    } catch (_) {}
  }
}
