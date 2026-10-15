import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

class OfflineMarkAttendanceException implements Exception {}

class MarkAttendanceServerException implements Exception {
  final String message;
  MarkAttendanceServerException(this.message);

  @override
  String toString() => message;
}

class MarkAttendanceRepository {
  static final Random _random = Random(42);

  Future<List<ClassStudent>> fetchRoster(String courseCode, {String? sectionId}) async {
    List<ClassStudent> allStudents = [];

    if (sectionId != null && sectionId.isNotEmpty) {
      try {
        final raw = PersistenceService.academicBox.get('roster_$sectionId');
        if (raw is List) {
          debugPrint('[MarkAttendance] Loaded ${raw.length} students from Hive for sectionId=$sectionId');
          for (final entry in raw) {
            if (entry is Map) {
              final student = _toClassStudent(Map<String, dynamic>.from(entry), section: sectionId, courseCode: courseCode);
              if (student != null) allStudents.add(student);
            }
          }
        }
      } catch (e) {
        debugPrint('[MarkAttendance] Error loading from Hive: $e');
      }
    }

    if (allStudents.isEmpty) {
      try {
        final keys = PersistenceService.academicBox.get('roster_keys');
        if (keys is List) {
          for (final key in keys) {
            final keyStr = key.toString();
            final raw = PersistenceService.academicBox.get('roster_$keyStr');
            if (raw is List) {
              for (final entry in raw) {
                if (entry is Map) {
                  final student = _toClassStudent(Map<String, dynamic>.from(entry), section: keyStr, courseCode: courseCode);
                  if (student != null) allStudents.add(student);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[MarkAttendance] Error loading all rosters from Hive: $e');
      }
    }

    debugPrint('[MarkAttendance] Total students loaded: ${allStudents.length}');
    return allStudents;
  }

  ClassStudent? _toClassStudent(Map<String, dynamic> data, {String? section, String? courseCode}) {
    final id = data['id']?.toString() ?? data['student_id']?.toString() ?? '';
    final name = data['name']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty) return null;

    final attended = data['attended'] is num ? (data['attended'] as num).toInt() : 0;
    final total = data['total'] is num ? (data['total'] as num).toInt() : 1;
    final pct = total > 0 ? (attended / total * 100) : 0.0;

    return ClassStudent(
      id: id,
      name: name,
      rollNumber: data['roll_number']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      department: data['department']?.toString() ?? '',
      section: section ?? data['section']?.toString() ?? '',
      courseCode: courseCode ?? data['course_code']?.toString() ?? '',
      courseName: data['course_name']?.toString() ?? '',
      semester: data['semester']?.toString() ?? '',
      attendancePercentage: double.parse(pct.toStringAsFixed(1)),
      totalClasses: total,
      attendedClasses: attended,
      isEligible: pct >= 75.0,
      isDefaulter: pct < 75.0,
      gender: data['gender']?.toString() ?? '',
      lastSeen: null,
      guardianName: data['guardian_name']?.toString() ?? '',
      guardianPhone: data['guardian_phone']?.toString() ?? '',
      bloodGroup: data['blood_group']?.toString() ?? '',
    );
  }

  Future<void> submitAttendance({
    required String sessionId,
    required Map<String, AttendanceStatus> attendanceMap,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (_random.nextDouble() < 0.02) {
      throw Exception('Network error. Please try again.');
    }
  }

  Future<void> bulkUpdateAttendance({
    required String sessionId,
    required String courseCode,
    required Map<String, AttendanceStatus> attendanceMap,
  }) async {
    final present = <String>[];
    final absent = <String>[];
    final late = <String>[];
    final leave = <String>[];
    attendanceMap.forEach((studentId, status) {
      switch (status) {
        case AttendanceStatus.present:
          present.add(studentId);
          break;
        case AttendanceStatus.absent:
          absent.add(studentId);
          break;
        case AttendanceStatus.late:
          late.add(studentId);
          break;
        case AttendanceStatus.leave:
          leave.add(studentId);
          break;
        case AttendanceStatus.holiday:
          break;
      }
    });

    try {
      final response = await ApiClient().dio.post(
        '/api/v1/faculty/session/attendance/bulk',
        data: {
          'session_id': sessionId,
          'course_code': courseCode,
          'present_students': present,
          'absent_students': absent,
          'late_students': late,
          'leave_students': leave,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[MarkAttendance] Bulk update accepted: ${response.statusCode}');
        return;
      }
      throw MarkAttendanceServerException('Server returned ${response.statusCode}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw OfflineMarkAttendanceException();
      }
      final data = e.response?.data;
      String? message;
      if (data is Map) {
        message = data['message']?.toString() ?? data['error']?.toString();
      } else if (data != null) {
        message = data.toString();
      }
      throw MarkAttendanceServerException(message ?? 'Unable to update attendance.');
    } catch (e) {
      debugPrint('[MarkAttendance] Bulk update failed: $e');
      throw MarkAttendanceServerException('Unable to update attendance.');
    }
  }

  Future<List<AttendanceRecord>> fetchHistory(String studentId) async {
    return [];
  }
}
