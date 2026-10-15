enum SessionState { idle, preparing, igniting, active, closed }

enum StudentStatus { present, absent, issue, flagged }

class StudentAttendance {
  final String id;
  final String name;
  final String? email;
  final String? image;
  final StudentStatus status;
  final DateTime? checkInTime;
  final String? deviceFingerprint;
  final bool isVerified;
  final String? markedBy;

  StudentAttendance({
    required this.id,
    required this.name,
    this.email,
    this.image,
    required this.status,
    this.checkInTime,
    this.deviceFingerprint,
    this.isVerified = false,
    this.markedBy,
  });

  factory StudentAttendance.fromJson(Map<String, dynamic> json) {
    final rawId = json['student_id']?.toString() ?? json['id']?.toString() ?? '';
    final rawEmail = json['student_email']?.toString() ?? json['email']?.toString();
    
    // Server currently might send email in student_id field.
    final effectiveEmail = (rawEmail != null && rawEmail.isNotEmpty) 
        ? rawEmail 
        : (rawId.contains('@') ? rawId : null);

    return StudentAttendance(
      id: rawId,
      name: json['student_name']?.toString() ?? json['name']?.toString() ?? 'Unknown Student',
      email: effectiveEmail,
      image: json['image']?.toString() ?? json['studentImage']?.toString(),
      status: _parseStatus(json['status']?.toString().toUpperCase()),
      checkInTime: json['recorded_at'] != null 
          ? DateTime.tryParse(json['recorded_at'].toString()) 
          : (json['timestamp'] != null ? DateTime.tryParse(json['timestamp'].toString()) : null),
      deviceFingerprint: json['deviceFingerprint']?.toString() ?? json['device_fingerprint']?.toString(),
      isVerified: json['isVerified'] == true || json['is_verified'] == true,
      markedBy: json['marked_by']?.toString() ?? json['markedBy']?.toString(),
    );
  }

  static StudentStatus _parseStatus(String? status) {
    switch (status) {
      case 'PRESENT':
      case 'present': return StudentStatus.present;
      case 'ISSUE':
      case 'issue': return StudentStatus.issue;
      case 'FLAGGED':
      case 'flagged': return StudentStatus.flagged;
      default: return StudentStatus.absent;
    }
  }
}

class SessionStateInfo {
  final SessionState state;
  final String? sessionId;
  final int presentCount;
  final int absentCount;
  final int version;
  final int stateTimestampMs;
  final String? subjectName;
  final String? subjectCode;
  final String? roomNumber;
  final String? sectionId;

  SessionStateInfo({
    required this.state,
    this.sessionId,
    this.presentCount = 0,
    this.absentCount = 0,
    this.version = 0,
    this.stateTimestampMs = 0,
    this.subjectName,
    this.subjectCode,
    this.roomNumber,
    this.sectionId,
  });

  factory SessionStateInfo.fromJson(Map<String, dynamic> json) {
    return SessionStateInfo(
      state: _parseState(json['state']?.toString() ?? ''),
      sessionId: json['session_id']?.toString(),
      presentCount: json['present'] as int? ?? json['present_count'] as int? ?? 0,
      absentCount: json['absent'] as int? ?? json['absent_count'] as int? ?? 0,
      version: json['version'] as int? ?? 0,
      stateTimestampMs: json['state_timestamp_ms'] as int? ??
                        json['last_updated'] as int? ?? 0,
      subjectName: json['subject_name']?.toString(),
      subjectCode: json['subject_code']?.toString(),
      roomNumber: json['room_number']?.toString(),
      sectionId: json['section_id']?.toString(),
    );
  }

  SessionStateInfo copyWith({
    SessionState? state,
    String? sessionId,
    int? presentCount,
    int? absentCount,
    int? version,
    int? stateTimestampMs,
    String? subjectName,
    String? subjectCode,
    String? roomNumber,
    String? sectionId,
  }) {
    return SessionStateInfo(
      state: state ?? this.state,
      sessionId: sessionId ?? this.sessionId,
      presentCount: presentCount ?? this.presentCount,
      absentCount: absentCount ?? this.absentCount,
      version: version ?? this.version,
      stateTimestampMs: stateTimestampMs ?? this.stateTimestampMs,
      subjectName: subjectName ?? this.subjectName,
      subjectCode: subjectCode ?? this.subjectCode,
      roomNumber: roomNumber ?? this.roomNumber,
      sectionId: sectionId ?? this.sectionId,
    );
  }

  static SessionState _parseState(String raw) {
    switch (raw.toUpperCase()) {
      case 'PREPARING': return SessionState.preparing;
      case 'IGNITING': return SessionState.igniting;
      case 'ACTIVE': return SessionState.active;
      case 'CLOSED': return SessionState.closed;
      default: return SessionState.idle;
    }
  }
}

class SessionInfo {
  final String sessionId;
  final String courseId;
  final String? sectionId;
  final bool isLive;
  final DateTime startTime;
  final int presentCount;
  final int expectedCount;
  final String status;
  final String? rescueSeed;

  SessionInfo({
    required this.sessionId,
    required this.courseId,
    this.sectionId,
    required this.isLive,
    required this.startTime,
    required this.presentCount,
    required this.expectedCount,
    required this.status,
    this.rescueSeed,
  });

}

class AttendanceMarkRequest {
  /// student_id is the canonical identifier: student email (e.g. john.doe@university.edu)
  final String studentId;
  final String sessionId;
  final String? notes;

  AttendanceMarkRequest({
    required this.studentId,
    required this.sessionId,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'session_id': sessionId,
    if (notes != null) 'notes': notes,
  };
}
