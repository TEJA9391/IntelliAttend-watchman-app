import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';

class EligibilityService {
  static const double threshold = 0.75;

  static final ValueNotifier<List<Map<String, dynamic>>> students = ValueNotifier([]);
  static final ValueNotifier<bool> isLoading = ValueNotifier(false);

  static void switchCourse(String courseId) {
    final cachedData = PersistenceService.academicBox.get('eligibility_students_$courseId');
    if (cachedData != null) {
      try {
        final List<Map<String, dynamic>> cachedList = List<Map<String, dynamic>>.from(
          (cachedData as List).map((e) => Map<String, dynamic>.from(e))
        );
        students.value = cachedList;
        isLoading.value = false;
        debugPrint("📦 ELIGIBILITY: Loaded ${cachedList.length} students from CACHE for course $courseId");
      } catch (e) {
        debugPrint("⚠️ ELIGIBILITY: Error loading students from cache: $e");
        isLoading.value = true;
      }
    } else {
      isLoading.value = true;
    }
    isLoading.value = false;
  }

  static List<Map<String, dynamic>> getEligibleStudents() {
    return students.value.where((s) {
      final attended = (s['attended'] as num?)?.toInt() ?? 0;
      final total = (s['total'] as num?)?.toInt() ?? 1;
      return total > 0 && (attended / total) >= threshold;
    }).toList();
  }

  static List<Map<String, dynamic>> getDefaulters() {
    return students.value.where((s) {
      final attended = (s['attended'] as num?)?.toInt() ?? 0;
      final total = (s['total'] as num?)?.toInt() ?? 1;
      return total > 0 && (attended / total) < threshold;
    }).toList();
  }

  static Map<String, dynamic> calculate(int attended, int total) {
    final pct = total > 0 ? (attended / total) * 100 : 0.0;
    return {
      'attended': attended,
      'total': total,
      'percentage': pct,
      'isEligible': pct >= threshold * 100,
      'classesNeeded': _classesNeeded(attended, total),
    };
  }

  static int _classesNeeded(int attended, int total) {
    if (total == 0) return 0;
    final needed = (threshold * total - attended) / (1 - threshold);
    return needed > 0 ? needed.ceil() : 0;
  }

  static void stopListening() {
    students.value = [];
    isLoading.value = false;
  }
}
