import 'package:intelli_attend_shared/intelli_attend_shared.dart';

class OverrideSlot {
  final String id;
  final String sectionId;
  final String slotId;
  final String originalFacultyEmail;
  final String substituteFacultyEmail;
  final String date;
  final String subjectCode;
  final String subjectName;
  final String roomNumber;
  final int startMinutes;
  final int endMinutes;
  final int dayOfWeek;
  final String classType;
  final String? reason;

  final String? legacyStartTime;
  final String? legacyEndTime;
  final String? legacyDayOfWeek;

  OverrideSlot({
    required this.id,
    required this.sectionId,
    required this.slotId,
    required this.originalFacultyEmail,
    required this.substituteFacultyEmail,
    required this.date,
    required this.subjectCode,
    required this.subjectName,
    required this.roomNumber,
    required this.startMinutes,
    required this.endMinutes,
    required this.dayOfWeek,
    this.classType = 'Lecture',
    this.reason,
    this.legacyStartTime,
    this.legacyEndTime,
    this.legacyDayOfWeek,
  });

  factory OverrideSlot.fromJson(Map<String, dynamic> data, String id) {
    final rawStart = data['start_minutes'];
    final rawEnd = data['end_minutes'];
    final rawDay = data['day_of_week'];
    return OverrideSlot(
      id: id,
      sectionId: data['section_id'] ?? '',
      slotId: data['slot_id'] ?? id,
      originalFacultyEmail: data['original_faculty_email'] ?? '',
      substituteFacultyEmail: data['substitute_faculty_email'] ?? '',
      date: data['date'] ?? '',
      subjectCode: data['subject_code'] ?? '',
      subjectName: data['subject_name'] ?? 'Substitute Class',
      roomNumber: data['room_number'] ?? '',
      startMinutes: rawStart is int ? rawStart : _parseLegacyTime(data['start_time'] as String? ?? '09:00'),
      endMinutes: rawEnd is int ? rawEnd : _parseLegacyTime(data['end_time'] as String? ?? '10:00'),
      dayOfWeek: rawDay is int ? rawDay : _dayStringToInt(data['day_of_week'] as String? ?? 'Monday'),
      classType: data['class_type'] ?? 'Lecture',
      reason: data['reason'],
      legacyStartTime: data['start_time'] as String?,
      legacyEndTime: data['end_time'] as String?,
      legacyDayOfWeek: data['day_of_week'] as String?,
    );
  }

  TimetableSlot toTimetableSlot(String freshId) {
    return TimetableSlot(
      id: freshId,
      sectionId: sectionId,
      dayOfWeek: dayOfWeek,
      slotType: SlotType.substitutionOverride,
      classType: ClassType.fromWire(classType.toLowerCase()),
      subjectCode: subjectCode,
      subjectName: subjectName,
      roomNumber: roomNumber,
      facultyEmails: [substituteFacultyEmail],
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      durationMinutes: endMinutes - startMinutes,
      institutionTimezone: 'Asia/Kolkata',
      overrideFacultyEmail: substituteFacultyEmail,
    );
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

  static int _dayStringToInt(String day) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days.indexOf(day) + 1;
  }
}
