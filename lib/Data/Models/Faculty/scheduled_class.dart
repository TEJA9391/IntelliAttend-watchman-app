import 'package:intelli_attend_shared/intelli_attend_shared.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/course_topic.dart';

/// Legacy timetable model. Kept for migration compatibility.
/// New code should prefer [TimetableSlot] from the shared package.
class ScheduledClass {
  final String id;
  final String subjectName;
  final String subjectCode;
  final String roomNumber;
  final String startTime;
  final String endTime;
  final int dayOfWeek;
  final String? sectionId;
  final String? smartboardId;

  final int? startMinutes;
  final int? endMinutes;

  final List<CourseTopic> topics;

  ScheduledClass({
    required this.id,
    required this.subjectName,
    required this.subjectCode,
    required this.roomNumber,
    required this.startTime,
    required this.endTime,
    required this.dayOfWeek,
    this.sectionId,
    this.smartboardId,
    this.startMinutes,
    this.endMinutes,
    this.topics = const [],
  });

  TimetableSlot toTimetableSlot({String institutionTimezone = 'Asia/Kolkata'}) {
    final sm = startMinutes ?? _parseLegacyTime(startTime);
    final em = endMinutes ?? _parseLegacyTime(endTime);
    return TimetableSlot(
      id: id,
      sectionId: sectionId ?? '',
      dayOfWeek: dayOfWeek,
      slotType: SlotType.regularClass,
      classType: ClassType.lecture,
      subjectCode: subjectCode,
      subjectName: subjectName,
      roomNumber: roomNumber,
      facultyEmails: [],
      startMinutes: sm,
      endMinutes: em,
      durationMinutes: em - sm,
      institutionTimezone: institutionTimezone,
    );
  }

  factory ScheduledClass.fromJson(Map<String, dynamic> data, String id) {
    final String subjectName = (data['subject_name'] as String?) ??
        (data['course_name'] as String?) ??
        (data['title'] as String?) ??
        (data['name'] as String?) ??
        (data['subject_id']?.toString()) ??
        'Unknown Subject';
    final String subjectCode = (data['subject_code'] as String?) ??
        (data['course_code'] as String?) ??
        (data['code'] as String?) ??
        (data['subject_id']?.toString()) ??
        'CODE';
    final rawTopics = data['topics'] as List<dynamic>?;
    final List<CourseTopic> topics = rawTopics != null
        ? rawTopics
            .whereType<Map<String, dynamic>>()
            .map(CourseTopic.fromJson)
            .toList()
        : const [];
    return ScheduledClass(
      id: id,
      subjectName: subjectName,
      subjectCode: subjectCode,
      roomNumber: data['room_number'] ?? data['classroom_id'] ?? 'N/A',
      startTime: data['start_time'] ?? '--:--',
      endTime: data['end_time'] ?? '--:--',
      dayOfWeek: _parseDay(data['day_of_week']),
      sectionId: data['section_id']?.toString(),
      smartboardId: data['smartboard_id']?.toString(),
      startMinutes: data['start_minutes'] as int?,
      endMinutes: data['end_minutes'] as int?,
      topics: topics,
    );
  }

  static int _parseDay(dynamic day) {
    if (day is int) return day;
    if (day is String) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days.indexOf(day) + 1;
    }
    return -1;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'room_number': roomNumber,
      'start_time': startTime,
      'end_time': endTime,
      'day_of_week': dayOfWeek,
      if (sectionId != null) 'section_id': sectionId,
      if (smartboardId != null) 'smartboard_id': smartboardId,
      if (startMinutes != null) 'start_minutes': startMinutes,
      if (endMinutes != null) 'end_minutes': endMinutes,
      if (topics.isNotEmpty) 'topics': topics.map((t) => t.toJson()).toList(),
    };
  }

  static int _parseLegacyTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final tp = parts[0].split(':');
      var h = int.parse(tp[0]);
      final m = int.parse(tp[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && h < 12) h += 12;
        if (parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
      }
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }
}
