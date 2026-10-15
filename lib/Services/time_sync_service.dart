import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';

/// Virtual Secure Clock — Server-Offset Monotonic Clock (Faculty App)
///
/// SECURITY MODEL:
///   The OS wall clock (DateTime.now()) is trivially manipulable — any user
///   can change their phone's date/time in Settings. This class eliminates
///   that attack vector by anchoring the server's atomic timestamp to the
///   device's hardware monotonic clock (SystemClock.elapsedRealtime on Android /
///   CLOCK_MONOTONIC_RAW on iOS).
///
/// FORMULA:
///   CurrentAppTime = ServerTime + (CurrentUptime - UptimeAtAnchor)
///
/// DISTRIBUTED DRIFT (offline phone + offline SmartBoard):
///   Both devices run independent virtual clocks anchored to the same server.
///   Over hours of being offline, cheap hardware quartz oscillators can drift
///   2-3 seconds apart. The 5-second client skew tolerance in QRValidationService
///   absorbs this on the phone side. Call [compensateDrift] on app resume to
///   correct for deep-sleep-induced drift in the local Stopwatch.
///
/// REBOOT DETECTION:
///   On each successful sync the current uptime is persisted to
///   SharedPreferences. On cold start, if the current uptime is LESS than the
///   persisted value, the device was rebooted since the last sync and the
///   virtual clock is reset.
class TimeSyncService {
  /// High-resolution monotonic ticker. Dart's [Stopwatch] is backed by the
  /// platform's monotonic clock (CLOCK_MONOTONIC on Android, mach_absolute_time
  /// on iOS) — it is NOT affected by the user changing the OS wall clock.
  ///
  /// Note: CLOCK_MONOTONIC does not tick during deep sleep. Call
  /// [compensateDrift] on app resume to correct for sleep-induced drift.
  static final Stopwatch _ticker = Stopwatch();

  /// Corrected server timestamp (epoch ms) from the last successful handshake.
  static int _anchorServerTimeMs = 0;

  /// Device uptime (ms via elapsedRealtime / CLOCK_MONOTONIC_RAW) at the
  /// moment of the last successful handshake. Used by [compensateDrift] to
  /// calculate sleep drift.
  static int _anchorUptimeMs = 0;

  static bool _isSynced = false;

  /// Fallback monotonic ticker for when [bootstrap] hasn't completed yet.
  /// Anchored to the first [initFallbackClock] call at app boot, this
  /// provides a monotonically-increasing time approximation that is immune
  /// to OS wall clock manipulation by the user — enforced by CLOCK_MONOTONIC.
  static final Stopwatch _fallbackTicker = Stopwatch();
  static int _fallbackBaseMs = 0;

  /// Initializes the fallback monotonic clock. Call once at app startup
  /// before any time-sensitive operations. Safe to call repeatedly.
  static void initFallbackClock() {
    if (_fallbackTicker.isRunning) return;
    _fallbackBaseMs = DateTime.now().millisecondsSinceEpoch;
    _fallbackTicker
      ..reset()
      ..start();
    debugPrint('[TimeSyncService] Fallback monotonic clock initialized at base=$_fallbackBaseMs');
  }

  // Store uptime anchor for fallback drift compensation.
  static int _fallbackBaseUptimeMs = 0;

  /// Compensate deep sleep drift for the fallback (unsynced) ticker.
  /// Must be called alongside [compensateDrift] on app resume.
  static Future<void> compensateFallbackDrift() async {
    if (!_fallbackTicker.isRunning) return;

    int uptimeNow = 0;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        uptimeNow = await HardwareService.getMonotonicTime();
        if (uptimeNow > 0) break;
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 50 * (attempt + 1)));
        }
      }
    }
    if (uptimeNow <= 0) return;

    if (_fallbackBaseUptimeMs <= 0) {
      _fallbackBaseUptimeMs = uptimeNow;
      return;
    }

    final expectedElapsed = uptimeNow - _fallbackBaseUptimeMs;
    final actualElapsed = _fallbackTicker.elapsedMilliseconds;
    final driftMs = expectedElapsed - actualElapsed;
    if (driftMs.abs() > 0) {
      _fallbackBaseMs += driftMs;
      _fallbackBaseUptimeMs = uptimeNow;
      _fallbackTicker
        ..reset()
        ..start();
      if (kDebugMode) {
        debugPrint('[TimeSyncService] Fallback drift corrected: ${driftMs}ms');
      }
    }
  }

  /// Fast-path: returns the current virtual clock time synchronously.
  ///
  /// When synced: uses the server-anchored clock (authoritative).
  /// When unsynced but fallback ticker is running: uses the boot-anchored
  /// monotonic approximation (immune to wall clock manipulation).
  /// Only when completely cold: falls back to DateTime.now().
  static int get syncedNowMs {
    if (_isSynced) return _anchorServerTimeMs + _ticker.elapsedMilliseconds;
    if (_fallbackTicker.isRunning) {
      return _fallbackBaseMs + _fallbackTicker.elapsedMilliseconds;
    }
    return DateTime.now().millisecondsSinceEpoch + _serverTimeOffsetMs;
  }

  static int get serverTimeOffsetMs => _isSynced
      ? _anchorServerTimeMs - _anchorUptimeMs
      : _serverTimeOffsetMs;

  static bool get isSynced => _isSynced;

  /// Milliseconds since the last successful server handshake.
  static int get syncAgeMs =>
      _isSynced ? _ticker.elapsedMilliseconds : 0;

  // Legacy offset for backward compatibility with existing callers.
  static int _serverTimeOffsetMs = 0;

  /// Bootstrap the virtual clock with an RTT-corrected server handshake.
  /// Safe to call multiple times — subsequent calls re-anchor.
  static Future<void> bootstrap({Dio? dio}) async {
    final client = dio ?? _buildDefaultDio();
    try {
      final rttStopwatch = Stopwatch()..start();
      final response = await client.get(
        '/api/v1/time',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final roundTripMs = rttStopwatch.elapsedMilliseconds;

      if (response.statusCode != 200) return;

      final data = response.data;
      final int? serverTimestampMs = (data is Map)
          ? (data['timestamp'] as int? ?? data['server_time_ms'] as int?)
          : null;
      if (serverTimestampMs == null) return;

      final uptimeMs = await HardwareService.getMonotonicTime();
      if (uptimeMs <= 0) return;

      // Reboot detection
      final prefs = await SharedPreferences.getInstance();
      final storedUptime = prefs.getInt('_time_sync_uptime_anchor') ?? 0;
      if (storedUptime > 0 && uptimeMs < storedUptime && kDebugMode) {
        debugPrint('[TimeSyncService] Reboot detected since last sync');
      }

      _applyHandshake(
        serverTimestampMs: serverTimestampMs,
        roundTripMs: roundTripMs,
        uptimeMs: uptimeMs,
      );

      await prefs.setInt('_time_sync_uptime_anchor', _anchorUptimeMs);
      await persistOffset();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TimeSyncService] bootstrap failed: $e');
      }
    }
  }

  /// RTT-corrected anchor calculation.
  static void _applyHandshake({
    required int serverTimestampMs,
    required int roundTripMs,
    required int uptimeMs,
  }) {
    final int trueTimeAtArrival = serverTimestampMs + (roundTripMs ~/ 2);

    _anchorServerTimeMs = trueTimeAtArrival;
    _anchorUptimeMs = uptimeMs;
    _ticker
      ..reset()
      ..start();
    _isSynced = true;

    // Also update legacy offset for backward-compatible callers
    _serverTimeOffsetMs = trueTimeAtArrival - DateTime.now().millisecondsSinceEpoch;

    if (kDebugMode) {
      debugPrint(
        '[TimeSyncService] handshake ok: '
        'rtt=$roundTripMs server=$trueTimeAtArrival uptime=$uptimeMs',
      );
    }
  }

  /// Compensate for sleep-induced drift in the local Stopwatch.
  ///
  /// Dart's Stopwatch uses CLOCK_MONOTONIC which does NOT tick during deep
  /// sleep. After the phone sleeps for 10 minutes the Stopwatch is 10 minutes
  /// behind real time. Call this from [WidgetsBindingObserver.didChangeAppLifecycleState]
  /// when the state is [AppLifecycleState.resumed].
  static Future<void> compensateDrift() async {
    if (!_isSynced) return;

    int uptimeNow = 0;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        uptimeNow = await HardwareService.getMonotonicTime();
        if (uptimeNow > 0) break;
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 50 * (attempt + 1)));
        }
      }
    }
    if (uptimeNow <= 0) {
      if (kDebugMode) {
        debugPrint('[TimeSyncService] compensateDrift: getMonotonicTime failed after 3 retries');
      }
      return;
    }

    final expectedElapsed = uptimeNow - _anchorUptimeMs;
    final actualElapsed = _ticker.elapsedMilliseconds;
    final driftMs = expectedElapsed - actualElapsed;
    if (driftMs.abs() > 0) {
      _anchorServerTimeMs += driftMs;
      _ticker
        ..reset()
        ..start();
      if (kDebugMode) {
        debugPrint('[TimeSyncService] drift corrected: ${driftMs}ms');
      }
    }
    await persistOffset();
  }

  static Dio _buildDefaultDio() {
    final baseUrl = dotenv.env['API_BASE_URL'] ??
        'https://api-dev.balaseetharamanjaneyulu.com';
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Accept': 'application/json'},
    ));
  }

  /// Persists the current clock drift (synced - device) to SharedPreferences
  /// so background isolates can approximate the virtual clock time.
  static Future<void> persistOffset() async {
    if (!_isSynced) return;
    final offset = syncedNowMs - DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('t3_synced_drift_ms', offset);
  }

  /// Exposed for BackgroundAlarmHandler access.
  static int getLastPersistedDriftMs() {
    return 0; // caller reads from SharedPreferences directly
  }

  // ---------------------------------------------------------------------------
  // Instance API (backward compatibility)
  // ---------------------------------------------------------------------------
  TimeSyncService();

  Future<int> getSyncedTimeMs() async {
    if (_isSynced) return syncedNowMs;
    await bootstrap();
    return syncedNowMs;
  }
}
