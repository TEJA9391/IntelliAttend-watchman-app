import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

class AttendanceRecordsRepository {
  Future<List<AttendanceSession>> fetchSessions({
    String? courseCode,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    List<AttendanceSession> sessionsList = [];

    sessionsList = await _fetchSessionsFromAnalytics();
    if (sessionsList.isEmpty) {
      sessionsList = await _fetchSessionsFromSync();
    }

    final activeState = await _fetchCurrentState();
    if (activeState != null) {
      final activeSession = AttendanceSession(
        sessionId: activeState['session_id']?.toString() ?? '',
        courseCode: activeState['subject_code']?.toString() ?? activeState['course_code']?.toString() ?? '',
        courseName: activeState['subject_name']?.toString() ?? activeState['course_name']?.toString() ?? '',
        section: activeState['section_id']?.toString() ?? '',
        date: DateTime.now(),
        totalStudents: (activeState['present'] as int? ?? 0) +
            (activeState['absent'] as int? ?? 0) +
            (activeState['late'] as int? ?? 0) +
            (activeState['leave'] as int? ?? 0),
        presentCount: activeState['present'] as int? ?? activeState['present_count'] as int? ?? 0,
        absentCount: activeState['absent'] as int? ?? activeState['absent_count'] as int? ?? 0,
        lateCount: activeState['late'] as int? ?? activeState['late_count'] as int? ?? 0,
        leaveCount: activeState['leave'] as int? ?? activeState['leave_count'] as int? ?? 0,
        status: (activeState['state']?.toString() ?? '') == 'ACTIVE' ? 'active' : 'completed',
      );
      final existingIndex = sessionsList.indexWhere((s) => s.sessionId == activeSession.sessionId);
      if (existingIndex >= 0) {
        sessionsList[existingIndex] = activeSession;
      } else {
        sessionsList.insert(0, activeSession);
      }
    }

    List<AttendanceSession> results = sessionsList;

    if (courseCode != null && courseCode.isNotEmpty) {
      results = results.where((s) => s.courseCode == courseCode).toList();
    }
    if (dateFrom != null) {
      results = results.where((s) => !s.date.isBefore(dateFrom)).toList();
    }
    if (dateTo != null) {
      final endDate = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
      results = results.where((s) => !s.date.isAfter(endDate)).toList();
    }

    final startIndex = (page - 1) * pageSize;
    if (startIndex >= results.length) return [];
    final endIndex = (startIndex + pageSize).clamp(0, results.length);
    return results.sublist(startIndex, endIndex);
  }

  Future<List<AttendanceSession>> _fetchSessionsFromAnalytics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return [];

      final response = await ApiClient().dio.get(
        '/api/v1/analytics/faculty/${user!.email!.toLowerCase()}/summary',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final sessionsRaw = data['sessions'] as List? ?? data['history'] as List? ?? [];
        if (sessionsRaw.isEmpty) return [];

        final sessionsList = <AttendanceSession>[];
        for (final s in sessionsRaw) {
          if (s is! Map) continue;
          final m = Map<String, dynamic>.from(s);
          final sessionId = (m['session_id'] ?? m['id'] ?? '').toString();
          if (sessionId.isEmpty) continue;
          sessionsList.add(AttendanceSession(
            sessionId: sessionId,
            courseCode: (m['course_code'] ?? m['subject_code'] ?? '').toString(),
            courseName: (m['course_name'] ?? m['subject_name'] ?? '').toString(),
            section: (m['section'] ?? m['section_id'] ?? '').toString(),
            date: DateTime.tryParse((m['date'] ?? m['created_at'] ?? '').toString()) ?? DateTime.now(),
            totalStudents: (m['total_students'] as int?) ?? (m['present'] as int? ?? 0) + (m['absent'] as int? ?? 0) + (m['late'] as int? ?? 0) + (m['leave'] as int? ?? 0),
            presentCount: m['present_count'] as int? ?? m['present'] as int? ?? 0,
            absentCount: m['absent_count'] as int? ?? m['absent'] as int? ?? 0,
            lateCount: m['late_count'] as int? ?? m['late'] as int? ?? 0,
            leaveCount: m['leave_count'] as int? ?? m['leave'] as int? ?? 0,
            status: (m['status']?.toString() ?? 'completed'),
            facultyName: (m['faculty_name'] ?? '').toString(),
          ));
        }
        return sessionsList;
      }
    } catch (e) {
      print('AttendanceRecordsRepository: _fetchSessionsFromAnalytics error: $e');
    }
    return [];
  }

  Future<List<AttendanceSession>> _fetchSessionsFromSync() async {
    try {
      final response = await ApiClient().dio.get(
        '/api/v1/faculty/sync',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final sessionsList = <AttendanceSession>[];

        final cohorts = data['cohorts'] as List? ?? [];

        for (final cohort in cohorts) {
          if (cohort is! Map) continue;
          final c = Map<String, dynamic>.from(cohort);
          final code = (c['course_code'] ?? '').toString();
          final name = (c['course_name'] ?? '').toString();
          final sectionId = (c['section_id'] ?? '').toString();
          final sectionName = (c['section'] ?? c['section_name'] ?? '').toString();
          final rosterKey = 'roster_$sectionId';

          int totalStudents = 0;
          int totalAttended = 0;
          try {
            final roster = PersistenceService.academicBox.get(rosterKey);
            if (roster is List) {
              totalStudents = roster.length;
              for (final entry in roster) {
                if (entry is Map) {
                  final data = Map<String, dynamic>.from(entry);
                  final attended = data['attended'] is num ? (data['attended'] as num).toInt() : 0;
                  final total = data['total'] is num ? (data['total'] as num).toInt() : 0;
                  totalAttended += attended;
                  if (totalStudents <= 3) {
                    print('AttendanceRecords: student keys=${data.keys.toList()}');
                    print('AttendanceRecords: student attended=$attended total=$total');
                  }
                }
              }
            }
          } catch (_) {}

          sessionsList.add(AttendanceSession(
            sessionId: 'SESSION_${sectionId}_${DateTime.now().millisecondsSinceEpoch}',
            courseCode: code,
            courseName: name,
            section: sectionName.isNotEmpty ? sectionName : sectionId,
            date: DateTime.now(),
            totalStudents: totalStudents,
            presentCount: totalAttended,
            absentCount: totalStudents - totalAttended,
            lateCount: 0,
            leaveCount: 0,
            status: 'completed',
          ));
        }

        return sessionsList;
      }
    } catch (e) {
      print('AttendanceRecordsRepository: _fetchSessionsFromSync error: $e');
    }

    return [];
  }

  Future<List<AttendanceRecord>> fetchSessionRecords(String sessionId) async {
    if (sessionId.startsWith('SESSION_')) {
      return _fetchRecordsForFabricatedSession(sessionId);
    }

    try {
      final response = await ApiClient().dio.get(
        '/api/v1/session/$sessionId',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final recordsList = <AttendanceRecord>[];

        final attendanceData = data['attendance'] as List? ?? [];
        for (final item in attendanceData) {
          if (item is! Map) continue;
          final record = Map<String, dynamic>.from(item);
          recordsList.add(AttendanceRecord(
            id: record['id']?.toString() ?? '',
            studentId: record['student_id']?.toString() ?? '',
            studentName: record['student_name']?.toString() ?? '',
            rollNumber: record['roll_number']?.toString() ?? '',
            sessionId: sessionId,
            courseCode: record['course_code']?.toString() ?? data['course_code']?.toString() ?? '',
            courseName: record['course_name']?.toString() ?? data['course_name']?.toString() ?? '',
            section: record['section']?.toString() ?? data['section']?.toString() ?? '',
            date: DateTime.tryParse(record['date']?.toString() ?? '') ?? DateTime.now(),
            status: _parseStatus(record['status']?.toString() ?? 'absent'),
            checkInTime: record['check_in_time'] != null ? DateTime.tryParse(record['check_in_time'].toString()) : null,
            checkOutTime: record['check_out_time'] != null ? DateTime.tryParse(record['check_out_time'].toString()) : null,
            markedBy: record['marked_by']?.toString(),
            sessionType: record['session_type']?.toString(),
            facultyName: record['faculty_name']?.toString(),
            department: record['department']?.toString(),
            locationVerified: record['location_verified'] as bool?,
            deviceVerified: record['device_verified'] as bool?,
            syncStatus: record['sync_status']?.toString(),
            attendancePercentage: (record['attendance_percentage'] as num?)?.toDouble(),
            notes: record['notes']?.toString(),
            remarks: record['remarks']?.toString(),
          ));
        }

        if (recordsList.isEmpty) {
          final presentCount = data['present'] as int? ?? data['present_count'] as int? ?? 0;
          final absentCount = data['absent'] as int? ?? data['absent_count'] as int? ?? 0;
          final lateCount = data['late'] as int? ?? data['late_count'] as int? ?? 0;
          final leaveCount = data['leave'] as int? ?? data['leave_count'] as int? ?? 0;

          final rosterStudents = await _fetchRosterStudents(
            data['section_id']?.toString(),
          );

          int idx = 0;
          for (final student in rosterStudents) {
            AttendanceStatus status;
            if (idx < presentCount) {
              status = AttendanceStatus.present;
            } else if (idx < presentCount + lateCount) {
              status = AttendanceStatus.late;
            } else if (idx < presentCount + lateCount + leaveCount) {
              status = AttendanceStatus.leave;
            } else {
              status = AttendanceStatus.absent;
            }

            recordsList.add(AttendanceRecord(
              id: '${sessionId}_${student['id'] ?? idx}',
              studentId: (student['id'] ?? student['student_id'] ?? '').toString(),
              studentName: (student['name'] ?? '').toString(),
              rollNumber: (student['roll_number'] ?? '').toString(),
              sessionId: sessionId,
              courseCode: data['subject_code']?.toString() ?? data['course_code']?.toString() ?? '',
              courseName: data['subject_name']?.toString() ?? data['course_name']?.toString() ?? '',
              section: data['section_id']?.toString() ?? '',
              date: DateTime.now(),
              status: status,
              markedBy: 'system',
              sessionType: 'qr',
              facultyName: data['faculty_name']?.toString(),
              department: (student['department'] ?? '').toString(),
              attendancePercentage: (student['total'] != null && student['attended'] != null)
                  ? ((student['attended'] as num).toDouble() / (student['total'] as num).toDouble() * 100)
                  : null,
            ));
            idx++;
          }
        }

        return recordsList;
      }
    } catch (e) {
      print('AttendanceRecordsRepository: fetchSessionRecords error: $e');
    }

    return [];
  }

  Future<List<AttendanceRecord>> _fetchRecordsForFabricatedSession(String sessionId) async {
    final parts = sessionId.split('_');
    if (parts.length < 2) return [];
    final sectionId = parts[1];

    final rosterStudents = await _fetchRosterStudents(sectionId);
    if (rosterStudents.isEmpty) return [];

    final recordsList = <AttendanceRecord>[];
    for (int idx = 0; idx < rosterStudents.length; idx++) {
      final student = rosterStudents[idx];
      final attended = student['attended'] is num ? (student['attended'] as num).toInt() : 0;
      final total = student['total'] is num ? (student['total'] as num).toInt() : 1;
      final hasAttended = attended > 0;

      recordsList.add(AttendanceRecord(
        id: '${sessionId}_${student['id'] ?? idx}',
        studentId: (student['id'] ?? student['student_id'] ?? '').toString(),
        studentName: (student['name'] ?? '').toString(),
        rollNumber: (student['roll_number'] ?? '').toString(),
        sessionId: sessionId,
        courseCode: (student['course_code'] ?? '').toString(),
        courseName: (student['course_name'] ?? '').toString(),
        section: sectionId,
        date: DateTime.now(),
        status: hasAttended ? AttendanceStatus.present : AttendanceStatus.absent,
        markedBy: 'system',
        sessionType: 'qr',
        department: (student['department'] ?? '').toString(),
        attendancePercentage: total > 0 ? (attended / total * 100) : 0.0,
      ));
    }
    return recordsList;
  }

  Future<List<Map<String, dynamic>>> _fetchRosterStudents(String? sectionId) async {
    final students = <Map<String, dynamic>>[];

    if (sectionId != null && sectionId.isNotEmpty) {
      try {
        final raw = PersistenceService.academicBox.get('roster_$sectionId');
        if (raw is List) {
          for (final entry in raw) {
            if (entry is Map) {
              students.add(Map<String, dynamic>.from(entry));
            }
          }
        }
      } catch (_) {}
    }

    if (students.isEmpty) {
      try {
        final keys = PersistenceService.academicBox.get('roster_keys');
        if (keys is List) {
          for (final key in keys) {
            final raw = PersistenceService.academicBox.get('roster_$key');
            if (raw is List) {
              for (final entry in raw) {
                if (entry is Map) {
                  students.add(Map<String, dynamic>.from(entry));
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    return students;
  }

  Future<Map<String, dynamic>?> _fetchCurrentState() async {
    try {
      final response = await ApiClient().dio.get(
        '/api/v1/session/current-state',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final state = data['state']?.toString() ?? '';
        if (state != 'IDLE' && state != 'CLOSED') {
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> fetchSummary({
    String? courseCode,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return _emptySummary();

      final response = await ApiClient().dio.get(
        '/api/v1/analytics/faculty/${user!.email!.toLowerCase()}/summary',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final sessionsList = data['sessions'] as List? ?? data['history'] as List? ?? [];
        return {
          'totalSessions': data['totalSessions'] ?? data['total_sessions'] ?? sessionsList.length,
          'averageAttendance': (data['averageAttendance'] ?? data['average_attendance'] ?? 0.0).toDouble(),
          'totalStudents': data['totalStudents'] ?? data['total_students'] ?? 0,
        };
      }
    } catch (e) {
      print('AttendanceRecordsRepository: fetchSummary error: $e');
    }

    return _emptySummary();
  }

  Map<String, dynamic> _emptySummary() {
    return {
      'totalSessions': 0,
      'totalStudents': 0,
      'averageAttendance': 0.0,
    };
  }

  AttendanceStatus _parseStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'late':
        return AttendanceStatus.late;
      case 'leave':
        return AttendanceStatus.leave;
      case 'holiday':
        return AttendanceStatus.holiday;
      default:
        return AttendanceStatus.absent;
    }
  }
}
