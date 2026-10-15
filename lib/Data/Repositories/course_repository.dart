import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/course_topic.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

class CourseRepository {
  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Single-shot cache-first schedule fetch (no Firestore).
  Stream<List<ScheduledClass>> watchTodaySchedule(String email) {
    final now = DateTime.now();
    final dayName = _getDayName(now);
    return watchSchedule(email, dayName);
  }

  /// Single-emission stream: cache first, then server API to refresh.
  Stream<List<ScheduledClass>> watchSchedule(String email, String dayName) {
    final controller = StreamController<List<ScheduledClass>>();
    _emitScheduleOnce(controller, email, dayName);
    return controller.stream;
  }

  Future<void> _emitScheduleOnce(
      StreamController<List<ScheduledClass>> controller,
      String email,
      String dayName) async {
    final fullEmail = email.toLowerCase();
    debugPrint("🔍 [CourseRepo] Timetable -> Email: $fullEmail, Day: $dayName");

    // 1. Emit cached data immediately
    final cached = getCachedSchedule(dayName);
    if (cached.isNotEmpty && !controller.isClosed) {
      debugPrint("📦 [CourseRepo] Emitting cached schedule for $dayName (${cached.length} classes)");
      controller.add(cached);
    }

    // 2. Refresh from server API
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        if (!controller.isClosed) controller.close();
        return;
      }

      final response = await ApiClient().dio.get(
        '/api/v1/faculty/sync',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final schedule = data['schedule_list'] as List? ?? [];
        final dayIndex = _dayNames.indexOf(dayName) + 1;

        debugPrint("📋 [CourseRepo] Raw schedule keys: ${data.keys.toList()}");
        if (schedule.isNotEmpty) {
          final firstItem = Map<String, dynamic>.from(schedule.first);
          debugPrint("📋 [CourseRepo] First schedule item keys: ${firstItem.keys.toList()}");
          debugPrint("📋 [CourseRepo] First item topics field: ${firstItem['topics']}");
          debugPrint("📋 [CourseRepo] First item full: $firstItem");
        }

        final classes = schedule
            .map((item) => ScheduledClass.fromJson(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
            .where((c) => c.dayOfWeek == dayIndex)
            .toList();
        debugPrint("📋 [CourseRepo] Parsed classes with topics: ${classes.map((c) => '${c.subjectCode}(${c.topics.length})').toList()}");

        _mergeTopicsFromSyncResponse(classes, data);

        classes.sort((a, b) => _compareTimeStrings(a.startTime, b.startTime));
        _cacheSchedule(dayName, classes);
        debugPrint("✅ [CourseRepo] ${classes.length} classes for $dayName from server");
        if (!controller.isClosed) controller.add(classes);
      }
    } catch (e) {
      debugPrint("❌ [CourseRepo] Sync API error: $e");
      if (cached.isEmpty && !controller.isClosed) controller.add([]);
    }

    if (!controller.isClosed) controller.close();
  }

  String _getDayName(DateTime date) {
    return _dayNames[date.weekday - 1];
  }

  int _compareTimeStrings(String a, String b) {
    try {
      final aDate = _parseTimeString(a);
      final bDate = _parseTimeString(b);
      return aDate.compareTo(bDate);
    } catch (e) {
      return a.compareTo(b);
    }
  }

  static DateTime _parseTimeString(String timeStr) {
    final parts = timeStr.trim().split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    if (parts.length > 1) {
      if (parts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
      if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
    }
    return DateTime(2000, 1, 1, hour, minute);
  }

  // ── Cache helpers ──────────────────────────────────────────────────

  static String _dayCacheKey(String dayName) => 'schedule_${dayName.toLowerCase()}';

  void _cacheSchedule(String dayName, List<ScheduledClass> classes) {
    try {
      PersistenceService.academicBox.put(_dayCacheKey(dayName), classes.map((c) => c.toJson()).toList());
    } catch (e) {
      debugPrint('⚠️ [CourseRepo] Cache write error: $e');
    }
  }

  List<ScheduledClass> getCachedSchedule(String dayName) {
    try {
      final data = PersistenceService.academicBox.get(_dayCacheKey(dayName));
      if (data == null) return [];
      final classes = (data as List)
          .map((item) => ScheduledClass.fromJson(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
          .toList();
      _mergeTopicsFromHive(classes);
      return classes;
    } catch (e) {
      debugPrint('⚠️ [CourseRepo] Cache read error: $e');
      return [];
    }
  }

  void _mergeTopicsFromSyncResponse(List<ScheduledClass> classes, Map syncData) {
    try {
      final rawTopics = syncData['topics'];
      debugPrint("📋 [CourseRepo] Top-level topics type: ${rawTopics.runtimeType}");

      Map<String, List<CourseTopic>> topicsByCode = {};
      Map<String, List<CourseTopic>> topicsBySectionId = {};

      if (rawTopics is Map) {
        for (final entry in rawTopics.entries) {
          final key = entry.key.toString();
          final val = entry.value;
          if (val is List) {
            final topics = val.whereType<Map<String, dynamic>>().map(CourseTopic.fromJson).toList();
            if (topics.isNotEmpty) {
              topicsByCode[key] = topics;
              debugPrint("📋 [CourseRepo] Topics for '$key': ${topics.length} topics");
            }
          }
        }
      } else if (rawTopics is List) {
        debugPrint("📋 [CourseRepo] Topics is a List with ${rawTopics.length} entries");
        if (rawTopics.isNotEmpty) {
          debugPrint("📋 [CourseRepo] First topic entry: ${rawTopics.first}");
        }
      }

      final cohortsData = syncData['cohorts'];
      if (cohortsData is List) {
        for (final entry in cohortsData) {
          if (entry is! Map) continue;
          final cohort = Map<String, dynamic>.from(entry);
          final cohortTopics = cohort['topics'];
          if (cohortTopics is! List || cohortTopics.isEmpty) continue;
          final topics = cohortTopics.whereType<Map<String, dynamic>>().map(CourseTopic.fromJson).toList();
          if (topics.isEmpty) continue;
          final code = (cohort['course_code'] ?? cohort['subject_code'] ?? '').toString();
          final sectionId = (cohort['section_id'] ?? '').toString();
          debugPrint("📋 [CourseRepo] Cohort topics for code=$code, section=$sectionId: ${topics.length} topics");
          if (code.isNotEmpty && !topicsByCode.containsKey(code)) topicsByCode[code] = topics;
          if (sectionId.isNotEmpty) topicsBySectionId[sectionId] = topics;
        }
      }

      for (int i = 0; i < classes.length; i++) {
        final c = classes[i];
        if (c.topics.isNotEmpty) continue;

        final combinedKey = c.sectionId != null ? '${c.sectionId}_${c.subjectCode}' : null;
        final combinedTopics = combinedKey != null ? topicsByCode[combinedKey] : null;
        final sectionTopics = c.sectionId != null ? topicsBySectionId[c.sectionId!] : null;
        final codeTopics = topicsByCode[c.subjectCode];
        final matchedTopics = combinedTopics ?? sectionTopics ?? codeTopics;

        if (matchedTopics != null && matchedTopics.isNotEmpty) {
          classes[i] = ScheduledClass(
            id: c.id,
            subjectName: c.subjectName,
            subjectCode: c.subjectCode,
            roomNumber: c.roomNumber,
            startTime: c.startTime,
            endTime: c.endTime,
            dayOfWeek: c.dayOfWeek,
            sectionId: c.sectionId,
            smartboardId: c.smartboardId,
            startMinutes: c.startMinutes,
            endMinutes: c.endMinutes,
            topics: matchedTopics,
          );
          debugPrint("📋 [CourseRepo] ✅ Merged ${matchedTopics.length} topics for ${c.subjectCode} (section: ${c.sectionId}, key: $combinedKey)");
        } else {
          debugPrint("📋 [CourseRepo] ⚠️ No topics found for ${c.subjectCode} (section: ${c.sectionId}, tried keys: $combinedKey, ${c.subjectCode}, ${c.sectionId})");
        }
      }
    } catch (e) {
      debugPrint("⚠️ [CourseRepo] Error merging topics: $e");
    }
  }

  void _mergeTopicsFromHive(List<ScheduledClass> classes) {
    try {
      final cohortsData = PersistenceService.academicBox.get('cohorts');
      if (cohortsData == null || cohortsData is! List) return;

      Map<String, List<CourseTopic>> topicsByCode = {};
      Map<String, List<CourseTopic>> topicsBySectionId = {};

      for (final entry in cohortsData) {
        if (entry is! Map) continue;
        final cohort = Map<String, dynamic>.from(entry);
        final rawTopics = cohort['topics'];
        if (rawTopics is! List || rawTopics.isEmpty) continue;
        final topics = rawTopics.whereType<Map<String, dynamic>>().map(CourseTopic.fromJson).toList();
        if (topics.isEmpty) continue;
        final code = (cohort['course_code'] ?? cohort['subject_code'] ?? '').toString();
        final sectionId = (cohort['section_id'] ?? '').toString();
        if (code.isNotEmpty) topicsByCode[code] = topics;
        if (sectionId.isNotEmpty) topicsBySectionId[sectionId] = topics;
      }

      for (int i = 0; i < classes.length; i++) {
        final c = classes[i];
        if (c.topics.isNotEmpty) continue;
        final sectionTopics = c.sectionId != null ? topicsBySectionId[c.sectionId!] : null;
        final codeTopics = topicsByCode[c.subjectCode];
        final matchedTopics = sectionTopics ?? codeTopics;
        if (matchedTopics != null && matchedTopics.isNotEmpty) {
          classes[i] = ScheduledClass(
            id: c.id,
            subjectName: c.subjectName,
            subjectCode: c.subjectCode,
            roomNumber: c.roomNumber,
            startTime: c.startTime,
            endTime: c.endTime,
            dayOfWeek: c.dayOfWeek,
            sectionId: c.sectionId,
            smartboardId: c.smartboardId,
            startMinutes: c.startMinutes,
            endMinutes: c.endMinutes,
            topics: matchedTopics,
          );
        }
      }
    } catch (e) {
      debugPrint("⚠️ [CourseRepo] Error merging topics from Hive: $e");
    }
  }
}
