import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'persistence_service.dart';
import 'faculty_service.dart';

enum SyncResult {
  unchanged,
  updated,
  firstSync,
  error,
  noNetwork,
}

class FacultyHydrationService {
  static final FacultyHydrationService _instance = FacultyHydrationService._internal();
  factory FacultyHydrationService() => _instance;
  FacultyHydrationService._internal();

  /// Fired after manifest data (including schedule) is persisted to Hive.
  /// DashboardController registers here to re-read from cache after hydration.
  static void Function()? onDataChanged;

  static const String _manifestCollection = 'faculty_manifests';
  static const String _hashKey = 'manifest_hash';
  static const String _versionKey = 'manifest_version';
  static const String _lastSyncKey = 'last_sync_timestamp';

  Future<SyncResult> syncIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      debugPrint("❌ HYDRATION: No authenticated user");
      return SyncResult.error;
    }

    final email = user.email!.toLowerCase().trim();

    try {
      final localHash = PersistenceService.academicBox.get(_hashKey) as String?;
      final localProfileRaw = PersistenceService.facultyBox.get('profile');
      Map<String, dynamic>? localProfile;
      try {
        localProfile = localProfileRaw != null ? Map<String, dynamic>.from(localProfileRaw as Map) : null;
      } catch (e) {
        debugPrint("⚠️ HYDRATION: Corrupt profile cache, forcing resync");
        await _wipeLocalData();
        await PersistenceService.academicBox.delete(_hashKey);
        localProfile = null;
      }

      // v14.0 HYDRATION FIX: If we have both cached profile and manifest hash,
      // skip the server call entirely — data is already hydrated from cache.
      // Server sync only needed on: first install, new registration, or
      // when forceWipeAndResync() is called explicitly.
      if (localHash != null && localProfile != null) {
        final localCohorts = PersistenceService.academicBox.get('cohorts');
        if (localCohorts == null || (localCohorts as List).isEmpty) {
          debugPrint("⚠️ HYDRATION: Hash+profile exist but cohorts empty, forcing resync");
          await _wipeLocalData();
        } else {
          debugPrint("✅ HYDRATION: Cache populated (hash: ${localHash.substring(0, 8)}...), skipping server call");
          await _updateLastSyncTimestamp();
          return SyncResult.unchanged;
        }
      }

      final response = await ApiClient().dio.get(
        '/api/v1/faculty/sync',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        debugPrint("⚠️ HYDRATION: Sync failed with status ${response.statusCode}");
        return SyncResult.error;
      }

      final data = response.data as Map<String, dynamic>;
      final remoteHash = data['manifest_hash'] as String?;
      final remoteVersion = data['manifest_version'] as int? ?? 1;

      if (localHash == null) {
        debugPrint("🆕 HYDRATION: First sync for $email");
        await _persistManifest(data);
        return SyncResult.firstSync;
      }

      if (localHash == remoteHash) {
        debugPrint("✅ HYDRATION: Manifest unchanged (v$remoteVersion)");
        await _updateLastSyncTimestamp();
        return SyncResult.unchanged;
      }

      debugPrint("🔄 HYDRATION: Manifest changed, wiping and re-syncing...");
      await _wipeLocalData();
      await _persistManifest(data);
      return SyncResult.updated;

    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        debugPrint("📴 HYDRATION: Network timeout, serving from cache");
        return SyncResult.noNetwork;
      }
      if (e.type == DioExceptionType.connectionError) {
        debugPrint("📴 HYDRATION: No network, serving from cache");
        return SyncResult.noNetwork;
      }
      debugPrint("❌ HYDRATION: Dio error: ${e.message}");
      return SyncResult.error;
    } catch (e) {
      debugPrint("❌ HYDRATION: Unexpected error: $e");
      return SyncResult.error;
    }
  }

  Future<void> _persistManifest(Map<String, dynamic> data) async {
    final facultyBox = PersistenceService.facultyBox;
    final academicBox = PersistenceService.academicBox;

    final profile = data['faculty_profile'] as Map<String, dynamic>?;
    if (profile != null) {
      await facultyBox.put('profile', profile);
      await facultyBox.put('is_registered', profile['is_registered'] ?? false);
    }

    final cohorts = data['cohorts'] as List<dynamic>?;
    if (cohorts != null) {
      debugPrint("📦 HYDRATION: Persisting ${cohorts.length} cohorts");
      if (cohorts.isNotEmpty) {
        debugPrint("📦 HYDRATION: First cohort keys: ${(cohorts[0] as Map).keys.toList()}");
      }
      await academicBox.put('cohorts', cohorts);
      FacultyService.deriveCoursesFromCohorts();
    } else {
      debugPrint("⚠️ HYDRATION: No cohorts in response");
    }

    final schedule = data['schedule'] as Map<String, dynamic>?;
    if (schedule != null) {
      debugPrint("📦 HYDRATION: Persisting schedule for days: ${schedule.keys.toList()}");
      for (final entry in schedule.entries) {
        final daySlots = entry.value;
        if (daySlots is List && daySlots.isNotEmpty) {
          debugPrint("📦 HYDRATION: ${entry.key} first slot keys: ${(daySlots[0] as Map).keys.toList()}");
        }
        await academicBox.put('schedule_${entry.key.toLowerCase()}', entry.value);
      }
      await academicBox.put('schedule_days', schedule.keys.map((k) => k.toLowerCase()).toList());
    } else {
      debugPrint("⚠️ HYDRATION: No schedule in response");
    }

    final rosters = data['rosters'] as Map<String, dynamic>?;
    if (rosters != null) {
      for (final entry in rosters.entries) {
        await academicBox.put('roster_${entry.key}', entry.value);
      }
      await academicBox.put('roster_keys', rosters.keys.toList());
    }

    final adhocSessions = data['adhoc_sessions'] as List<dynamic>?;
    if (adhocSessions != null) {
      await academicBox.put('adhoc_sessions', adhocSessions);
    }

    await academicBox.put(_hashKey, data['manifest_hash']);
    await academicBox.put(_versionKey, data['manifest_version']);
    await _updateLastSyncTimestamp();

    debugPrint("✅ HYDRATION: Manifest persisted (v${data['manifest_version']})");

    if (onDataChanged != null) {
      Future.microtask(onDataChanged!);
    }
  }

  Future<void> _wipeLocalData() async {
    final academicBox = PersistenceService.academicBox;

    final scheduleDays = academicBox.get('schedule_days') as List<dynamic>?;
    if (scheduleDays != null) {
      for (final day in scheduleDays) {
        await academicBox.delete('schedule_$day');
      }
    }

    final rosterKeys = academicBox.get('roster_keys') as List<dynamic>?;
    if (rosterKeys != null) {
      for (final key in rosterKeys) {
        await academicBox.delete('roster_$key');
        await academicBox.delete('eligibility_students_$key');
      }
    }

    await academicBox.delete('cohorts');
    await academicBox.delete('schedule_days');
    await academicBox.delete('roster_keys');
    await academicBox.delete('adhoc_sessions');
    await academicBox.delete('courses');
    await academicBox.delete('subjects_cache');
    await academicBox.delete('student_rosters');

    debugPrint("🗑️ HYDRATION: Local academic data wiped");
  }

  Future<void> _updateLastSyncTimestamp() async {
    final now = DateTime.now().toUtc().toIso8601String();
    await PersistenceService.academicBox.put(_lastSyncKey, now);
  }

  String? getLastSyncTimestamp() {
    return PersistenceService.academicBox.get(_lastSyncKey) as String?;
  }

  int? getLocalVersion() {
    return PersistenceService.academicBox.get(_versionKey) as int?;
  }

  Future<void> forceWipeAndResync() async {
    debugPrint("🔄 HYDRATION: Force wipe triggered");
    await _wipeLocalData();
    await PersistenceService.academicBox.delete(_hashKey);
    await PersistenceService.academicBox.delete(_versionKey);
    await PersistenceService.academicBox.delete(_lastSyncKey);
    await syncIfNeeded();
  }

  List<Map<String, dynamic>> getCohortsFromCache() {
    final cohorts = PersistenceService.academicBox.get('cohorts') as List<dynamic>?;
    if (cohorts == null) return [];
    return cohorts.map((c) => Map<String, dynamic>.from(c as Map)).toList();
  }

  List<Map<String, dynamic>> getScheduleForDay(String day) {
    final slots = PersistenceService.academicBox.get('schedule_${day.toLowerCase()}') as List<dynamic>?;
    if (slots == null) return [];
    return slots.map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }

  List<Map<String, dynamic>> getRosterForCohort(String cohortKey) {
    final students = PersistenceService.academicBox.get('roster_$cohortKey') as List<dynamic>?;
    if (students == null) return [];
    return students.map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }

  List<Map<String, dynamic>> getAdhocSessions() {
    final sessions = PersistenceService.academicBox.get('adhoc_sessions') as List<dynamic>?;
    if (sessions == null) return [];
    return sessions.map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }
}
