import 'slot_type.dart';

class TimetableSlot {
  final String id;
  final String sectionId;
  final int dayOfWeek;
  final SlotType slotType;
  final ClassType classType;
  final String subjectCode;
  final String subjectName;
  final String roomNumber;
  final List<String> facultyEmails;
  final int startMinutes;
  final int endMinutes;
  final int durationMinutes;
  final String institutionTimezone;
  final String? overrideFacultyEmail;
  final String? breakLabel;

  const TimetableSlot({
    required this.id,
    required this.sectionId,
    required this.dayOfWeek,
    required this.slotType,
    required this.classType,
    required this.subjectCode,
    required this.subjectName,
    required this.roomNumber,
    required this.facultyEmails,
    required this.startMinutes,
    required this.endMinutes,
    this.durationMinutes = 0,
    required this.institutionTimezone,
    this.overrideFacultyEmail,
    this.breakLabel,
  });

  int get computedDuration => durationMinutes > 0 ? durationMinutes : endMinutes - startMinutes;
  bool get isBreak => slotType == SlotType.institutionalBreak;
  bool get isValid => endMinutes > startMinutes;

  bool contains(int currentMinutes) =>
      currentMinutes >= startMinutes && currentMinutes < endMinutes;

  factory TimetableSlot.fromFirestore(Map<String, dynamic> json, String documentId) {
    final rawStart = json['start_minutes'];
    final rawEnd = json['end_minutes'];
    return TimetableSlot(
      id: documentId,
      sectionId: json['section_id'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as int? ?? 1,
      slotType: json['slot_type'] != null
          ? SlotType.fromWire(json['slot_type'] as String)
          : SlotType.regularClass,
      classType: json['class_type'] != null
          ? ClassType.fromWire(json['class_type'] as String)
          : ClassType.lecture,
      subjectCode: json['subject_code'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      roomNumber: json['room_number'] as String? ?? '',
      facultyEmails: _parseStringList(json['faculty_emails']),
      startMinutes: rawStart is int ? rawStart : 570,
      endMinutes: rawEnd is int ? rawEnd : 630,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      institutionTimezone: json['institution_timezone'] as String? ?? 'Asia/Kolkata',
      overrideFacultyEmail: json['override_faculty_email'] as String?,
      breakLabel: json['break_label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'section_id': sectionId,
        'day_of_week': dayOfWeek,
        'slot_type': slotType.wire,
        'class_type': classType.wire,
        'subject_code': subjectCode,
        'subject_name': subjectName,
        'room_number': roomNumber,
        'faculty_emails': facultyEmails,
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'duration_minutes': computedDuration,
        'institution_timezone': institutionTimezone,
        'override_faculty_email': overrideFacultyEmail,
        'break_label': breakLabel,
      };

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    return [];
  }
}
