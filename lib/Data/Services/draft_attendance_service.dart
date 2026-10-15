import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';

class DraftAttendance {
  final String key;
  final Map<String, AttendanceStatus> attendanceMap;
  final Map<String, Map<String, dynamic>> studentNotes;
  final DateTime savedAt;

  const DraftAttendance({
    required this.key,
    required this.attendanceMap,
    this.studentNotes = const {},
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'attendance_map': attendanceMap.map((k, v) => MapEntry(k, v.name)),
        'student_notes': studentNotes,
        'saved_at': savedAt.toIso8601String(),
      };

  factory DraftAttendance.fromJson(Map<String, dynamic> json) {
    final rawMap = json['attendance_map'] as Map<String, dynamic>? ?? {};
    return DraftAttendance(
      key: json['key']?.toString() ?? '',
      attendanceMap: rawMap.map((k, v) => MapEntry(
            k,
            AttendanceStatus.values.firstWhere(
              (e) => e.name == v,
              orElse: () => AttendanceStatus.absent,
            ),
          )),
      studentNotes: _castNotes(json['student_notes']),
      savedAt:
          DateTime.tryParse(json['saved_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static Map<String, Map<String, dynamic>> _castNotes(dynamic raw) {
    if (raw is! Map) return {};
    final result = <String, Map<String, dynamic>>{};
    raw.forEach((k, v) {
      if (v is Map) {
        result[k.toString()] = Map<String, dynamic>.from(v);
      }
    });
    return result;
  }
}

class DraftAttendanceService {
  static const String _boxName = 'attendance_drafts';
  static DraftAttendanceService? _instance;
  static DraftAttendanceService get instance => _instance ??= DraftAttendanceService._();
  DraftAttendanceService._();

  Box? _box;

  Future<Box> get box async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  Future<void> saveDraft(DraftAttendance draft) async {
    final b = await box;
    await b.put(draft.key, jsonEncode(draft.toJson()));
  }

  Future<DraftAttendance?> loadDraft(String key) async {
    final b = await box;
    final raw = b.get(key);
    if (raw == null) return null;
    try {
      return DraftAttendance.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraft(String key) async {
    final b = await box;
    if (b.containsKey(key)) await b.delete(key);
  }

  bool isDraftPresent(String key) => _box?.containsKey(key) ?? false;
}
