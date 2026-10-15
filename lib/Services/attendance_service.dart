import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';

/// Service responsible for managing the real-time attendance state
/// via WebSocket from AttendanceRepository — no Firestore listeners.
class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal();

  final ValueNotifier<int> attendanceCount = ValueNotifier(0);
  final ValueNotifier<bool> isSessionLive = ValueNotifier(false);
  final ValueNotifier<String?> liveCourseName = ValueNotifier(null);
  final ValueNotifier<List<StudentAttendance>> students = ValueNotifier([]);

  void startSessionMonitoring(String sessionId, {String? courseName}) {
    liveCourseName.value = courseName;
    debugPrint("📡 [AttendanceService] Session monitoring started via WebSocket — no Firestore listeners.");
  }

  void stopMonitoring() {
    isSessionLive.value = false;
    liveCourseName.value = null;
    students.value = [];
    attendanceCount.value = 0;
  }
}
