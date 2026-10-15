enum AttendanceStatus { present, absent, late, leave, holiday }

class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String section;
  final DateTime date;
  final AttendanceStatus status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? notes;
  final String? markedBy;
  final String? sessionType;
  final String? facultyName;
  final String? department;
  final bool? locationVerified;
  final bool? deviceVerified;
  final String? syncStatus;
  final double? attendancePercentage;
  final String? remarks;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.section,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.notes,
    this.markedBy,
    this.sessionType,
    this.facultyName,
    this.department,
    this.locationVerified,
    this.deviceVerified,
    this.syncStatus,
    this.attendancePercentage,
    this.remarks,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Unknown',
      rollNumber: json['roll_number']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      courseCode: json['course_code']?.toString() ?? '',
      courseName: json['course_name']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      status: _parseStatus(json['status']?.toString()),
      checkInTime: json['check_in_time'] != null
          ? DateTime.tryParse(json['check_in_time'].toString())
          : null,
      checkOutTime: json['check_out_time'] != null
          ? DateTime.tryParse(json['check_out_time'].toString())
          : null,
      notes: json['notes']?.toString(),
      markedBy: json['marked_by']?.toString(),
      sessionType: json['session_type']?.toString(),
      facultyName: json['faculty_name']?.toString(),
      department: json['department']?.toString(),
      locationVerified: json['location_verified'] as bool?,
      deviceVerified: json['device_verified'] as bool?,
      syncStatus: json['sync_status']?.toString(),
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble(),
      remarks: json['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'roll_number': rollNumber,
      'session_id': sessionId,
      'course_code': courseCode,
      'course_name': courseName,
      'section': section,
      'date': date.toIso8601String(),
      'status': status.name,
      if (checkInTime != null) 'check_in_time': checkInTime!.toIso8601String(),
      if (checkOutTime != null) 'check_out_time': checkOutTime!.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (markedBy != null) 'marked_by': markedBy,
      if (sessionType != null) 'session_type': sessionType,
      if (facultyName != null) 'faculty_name': facultyName,
      if (department != null) 'department': department,
      if (locationVerified != null) 'location_verified': locationVerified,
      if (deviceVerified != null) 'device_verified': deviceVerified,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (attendancePercentage != null) 'attendance_percentage': attendancePercentage,
      if (remarks != null) 'remarks': remarks,
    };
  }

  static AttendanceStatus _parseStatus(String? value) {
    switch (value?.toLowerCase()) {
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

class AttendanceSession {
  final String sessionId;
  final String courseCode;
  final String courseName;
  final String section;
  final DateTime date;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final String status;
  final Duration? duration;
  final String? facultyName;

  AttendanceSession({
    required this.sessionId,
    required this.courseCode,
    required this.courseName,
    required this.section,
    required this.date,
    required this.totalStudents,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.leaveCount = 0,
    this.status = 'completed',
    this.duration,
    this.facultyName,
  });

  double get attendanceRate =>
      totalStudents > 0 ? (presentCount + lateCount) / totalStudents * 100 : 0.0;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      sessionId: json['session_id']?.toString() ?? '',
      courseCode: json['course_code']?.toString() ?? '',
      courseName: json['course_name']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      totalStudents: json['total_students'] as int? ?? 0,
      presentCount: json['present_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
      leaveCount: json['leave_count'] as int? ?? 0,
      status: json['status']?.toString() ?? 'completed',
      duration: json['duration_minutes'] != null
          ? Duration(minutes: json['duration_minutes'] as int)
          : null,
      facultyName: json['faculty_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'course_code': courseCode,
      'course_name': courseName,
      'section': section,
      'date': date.toIso8601String(),
      'total_students': totalStudents,
      'present_count': presentCount,
      'absent_count': absentCount,
      'late_count': lateCount,
      'leave_count': leaveCount,
      'status': status,
      if (duration != null) 'duration_minutes': duration!.inMinutes,
      if (facultyName != null) 'faculty_name': facultyName,
    };
  }
}
