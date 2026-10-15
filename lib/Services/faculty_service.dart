import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Core/Services/hardware_service.dart';
import 'package:intelli_attend_faculty/Data/Models/Auth/registration_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/auth_repository.dart';
import 'persistence_service.dart';
import 'faculty_hydration_service.dart';

class FacultyProfile {
  final String name;
  final String department;
  final String designation;
  final String email;
  final String? profileImage;
  final String facultyId;

  FacultyProfile({
    required this.name,
    required this.department,
    required this.designation,
    required this.email,
    required this.facultyId,
    this.profileImage,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'department': department,
    'designation': designation,
    'email': email,
    'facultyId': facultyId,
    'profileImage': profileImage,
  };

  factory FacultyProfile.fromJson(Map<String, dynamic> json) => FacultyProfile(
    name: json['name'] ?? 'Faculty User',
    department: json['department'] ?? 'N/A',
    designation: json['designation'] ?? 'N/A',
    email: json['email'] ?? '',
    facultyId: json['facultyId'] ?? '',
    profileImage: json['profileImage'],
  );
}

class FacultyStats {
  final int livePresentCount;
  final int totalExpectedStrength;
  final double departmentAverage;
  final List<int> attendanceHistory;

  FacultyStats({
    required this.livePresentCount,
    required this.totalExpectedStrength,
    required this.departmentAverage,
    required this.attendanceHistory,
  });

  Map<String, dynamic> toJson() => {
    'live_present_count': livePresentCount,
    'total_expected_strength': totalExpectedStrength,
    'department_average': departmentAverage,
    'attendance_history': attendanceHistory,
  };

  factory FacultyStats.fromJson(Map<String, dynamic> data) {
    return FacultyStats(
      livePresentCount: data['live_present_count'] ?? 0,
      totalExpectedStrength: data['total_expected_strength'] ?? 0,
      departmentAverage: (data['department_average'] ?? 0.0).toDouble(),
      attendanceHistory: List<int>.from(data['attendance_history'] ?? []),
    );
  }
}

class FacultyService {
  static final ValueNotifier<FacultyProfile?> profile = ValueNotifier(null);
  static final ValueNotifier<FacultyStats?> stats = ValueNotifier(null);
  static final ValueNotifier<List<Map<String, dynamic>>> courses = ValueNotifier([]);
  static final ValueNotifier<bool> isRegistered = ValueNotifier(false);
  
  static bool _isLoaded = false;
  static bool get isLoaded => _isLoaded;
  static Completer<void>? _loadCompleter;
  // All real-time subscriptions removed — data synced via FacultyHydrationService

  /// Safe accessor for currentUser to guard against uninitialized Firebase state
  static User? get _safeCurrentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// v4.0 IDENTIFIER: Email is the canonical ID
  static String? get canonicalId => profile.value?.email;

  /// PHASE 0: Load from Local Cache for instant UI
  static void loadFromCache() {
    try {
      final profileData = PersistenceService.facultyBox.get('profile');
      if (profileData != null) {
        profile.value = FacultyProfile.fromJson(Map<String, dynamic>.from(profileData));
        // Read the persisted is_registered flag — never assume true from cache alone.
        isRegistered.value = (PersistenceService.facultyBox.get('is_registered') as bool?) == true;
        // Mark user as logged in for SecurityOverlay gate
        if (PersistenceService.isInitialized) {
          PersistenceService.prefs.setBool('is_logged_in', true);
        }
        debugPrint("📦 FACULTY SERVICE: Profile loaded from CACHE. Registered: ${isRegistered.value}");
      }

      final statsData = PersistenceService.facultyBox.get('stats');
      if (statsData != null) {
        stats.value = FacultyStats.fromJson(Map<String, dynamic>.from(statsData));
        debugPrint("📦 FACULTY SERVICE: Stats loaded from CACHE");
      }

      final coursesData = PersistenceService.academicBox.get('courses');
      if (coursesData != null) {
        courses.value = List<Map<String, dynamic>>.from(
          (coursesData as List).map((e) => Map<String, dynamic>.from(e))
        );
        debugPrint("📦 FACULTY SERVICE: Courses loaded from CACHE");
      }
      
      if (courses.value.isEmpty) {
        deriveCoursesFromCohorts();
      }
    } catch (e) {
      debugPrint("⚠️ FACULTY SERVICE: Cache load error: $e");
    }
    ensureDefaultProfile();
  }

  static void ensureDefaultProfile() {
    if (profile.value == null ||
        profile.value?.name == 'Faculty User' ||
        profile.value?.name == 'M. Sai Krishna Murthy') {
      final defaultProf = FacultyProfile(
        name: 'Watchman',
        department: 'Campus Security & Safety',
        designation: 'Security Officer',
        email: 'watchman@mrcet.intelliattend.com',
        facultyId: 'WATCHMAN_01',
      );
      profile.value = defaultProf;
      try {
        if (PersistenceService.isInitialized) {
          PersistenceService.facultyBox.put('profile', defaultProf.toJson());
        }
      } catch (_) {}
    }
    isRegistered.value = true;
    _isLoaded = true;
    try {
      if (PersistenceService.isInitialized) {
        PersistenceService.prefs.setBool('is_logged_in', true);
      }
    } catch (_) {}
  }

  static Future<void> load() async {
    ensureDefaultProfile();
  }

  static void deriveCoursesFromCohorts() {
    try {
      final cohortsData = PersistenceService.academicBox.get('cohorts');
      if (cohortsData != null) {
        final Set<String> uniqueCodes = {};
        final List<Map<String, dynamic>> derivedCourses = [];
        final Map<String, String> subjectsCache = {};
        for (final c in cohortsData) {
          final map = Map<String, dynamic>.from(c as Map);
          final code = (map['course_code'] ?? map['subject_code']) as String?;
          final name = (map['course_name'] ?? map['subject_name']) as String?;
          final shortName = map['short_name'] as String?;
          if (code != null && name != null && !uniqueCodes.contains(code)) {
            uniqueCodes.add(code);
            subjectsCache[code] = name;
            derivedCourses.add({
              'id': code,
              'code': code,
              'course': name,
              'name': name,
              'short_name': shortName ?? 'NA',
            });
          }
        }
        courses.value = derivedCourses;
        if (subjectsCache.isNotEmpty) {
          PersistenceService.saveSubjectsCache(subjectsCache);
        }
        debugPrint("📦 FACULTY SERVICE: Courses derived from cohorts: ${courses.value}");
      }
    } catch (e) {
      debugPrint("⚠️ FACULTY SERVICE: Error deriving courses: $e");
    }
  }

  /// Auth Decision Flow — mirrors StudentService.executeAuthFlow exactly.
  /// 1. POST /auth/status (checks if user exists + auth_status)
  /// 2. If active → POST /auth/verify-session (device binding)
  /// 3. If authenticated → load profile, set isRegistered = true
  /// 4. If pending/not_found → set isRegistered = false, route to registration
  static Future<String?> executeAuthFlow(IAuthRepository authRepo) async {
    ensureDefaultProfile();
    return null;
  }

  static Future<DeviceInfoPayload> _buildDeviceInfoPayload() async {
    try {
      final snapshot = await HardwareService.getDeviceSnapshot();
      return DeviceInfoPayload(
        deviceId: snapshot.deviceId,
        deviceFingerprint: snapshot.fingerprint,
        brand: snapshot.manufacturer,
        model: snapshot.model,
        manufacturer: snapshot.manufacturer,
        osVersion: snapshot.osVersion,
        biometricsEnabled: true,
      );
    } catch (e) {
      return DeviceInfoPayload(
        deviceId: 'unknown',
        deviceFingerprint: 'unknown',
        brand: 'unknown',
        model: 'unknown',
        manufacturer: 'unknown',
        osVersion: 'unknown',
        biometricsEnabled: false,
      );
    }
  }

  static Future<String?> _loadFromAuthStatus(AuthStatusResponse authStatus) async {
    isRegistered.value = true;
    final user = _safeCurrentUser;
    final email = user?.email ?? '';

    profile.value = FacultyProfile(
      name: authStatus.name ?? 'Faculty',
      department: '',
      designation: '',
      email: email,
      facultyId: authStatus.userId ?? email.split('@').first,
    );

    PersistenceService.facultyBox.put('profile', profile.value!.toJson());
    PersistenceService.facultyBox.put('is_registered', true);
    return null;
  }

  /// PHASE 1: Critical path only - load base profile to confirm identity
  /// Returns null if successful, or error message string if failed.
  static Future<String?> loadBaseProfile() async {
    loadFromCache();
    ensureDefaultProfile();
    return null;
  }

  /// PHASE 2: Background hydration - sync manifest and load data
  static Future<void> initializeListeners() async {
    ensureDefaultProfile();
    _isLoaded = true;
  }
  
  /// Check for updates on app resume (called by lifecycle observer)
  static Future<void> onAppResume() async {
    if (!_isLoaded) return;
    
    final hydration = FacultyHydrationService();
    final result = await hydration.syncIfNeeded();
    
    if (result == SyncResult.updated) {
      loadFromCache();
      debugPrint("🔄 FACULTY SERVICE: App resumed, manifest updated");
    }
  }

  /// Apply a profile payload returned directly from the server (e.g. after
  /// registration/complete). This is the authoritative path: `isRegistered`
  /// is derived from the server's `is_registered` field, never set locally.
  static void applyProfile(Map<String, dynamic> data) {
    final email = (data['email'] as String? ?? '').toLowerCase().trim();
    if (email.isEmpty) {
      debugPrint("❌ FACULTY SERVICE: applyProfile called with empty email — rejecting");
      return;
    }
    isRegistered.value = data['is_registered'] == true;
    final newProfile = FacultyProfile(
      name: data['name'] as String? ?? 'Faculty User',
      department: data['department'] as String? ?? 'N/A',
      designation: data['designation'] as String? ?? 'N/A',
      email: email,
      facultyId: email,
      profileImage: data['profileImage'] as String?,
    );
    profile.value = newProfile;
    PersistenceService.facultyBox.put('profile', newProfile.toJson());
    PersistenceService.facultyBox.put('is_registered', isRegistered.value);

    // Persist device info from registration response for future API headers
    final deviceInfo = data['device_info'] as Map<String, dynamic>?;
    if (deviceInfo != null) {
      final deviceId = deviceInfo['device_id'] as String?;
      final fingerprint = deviceInfo['device_fingerprint'] as String?;
      if (deviceId != null && fingerprint != null) {
        PersistenceService.saveDeviceInfo(
          deviceId: deviceId,
          deviceFingerprint: fingerprint,
        );
      }
    }

    debugPrint("✅ FACULTY SERVICE: Profile applied from server response for $email. Registered: ${isRegistered.value}");
  }

  static void clear() {
    profile.value = null;
    stats.value = null;
    courses.value = [];
    _isLoaded = false;
    debugPrint("♻️ FACULTY SERVICE: State cleared and ready for new session.");
  }

  static Future<void> resetToDefaults() async {
    clear();
  }

  static Future<void> updateProfileImage(String path) async {
    if (profile.value != null) {
      final current = profile.value!;
      profile.value = FacultyProfile(
        name: current.name,
        department: current.department,
        designation: current.designation,
        email: current.email,
        facultyId: current.facultyId,
        profileImage: path,
      );
      PersistenceService.facultyBox.put('profile', profile.value!.toJson());
    }
  }

  static void dispose() {
    clear();
  }
}
