enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

enum WsEventType {
  attendanceUpdate,
  studentMarked,
  sessionPreparing,
  sessionIgniting,
  attendanceOpen,
  studentVerified,
  studentRejected,
  attendanceMarkedManual,
  attendanceUpdated,
  attendanceClosed,
  sessionArchived,
  fullStateSync,
  facultySync,
  boardConnected,
  sessionActivated,
  otpVerified,
  otpFailed,
  markAttendanceAck,
  // ── Chat / Messaging events ────────────────────────────────
  messageNew,
  messageAck,
  messageRead,
  messageDelivered,
  messageEdited,
  messageDeleted,
  messagePinned,
  typing,
  presenceUpdate,
  callEvent,
  conversationSync,
  // ── ─────────────────────────────────────────────────────────
  heartbeat,
  unknown,
}

class WebSocketEvent {
  final WsEventType type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  WebSocketEvent({
    required this.type,
    required this.data,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ?? json['event']?.toString() ?? '';
    return WebSocketEvent(
      type: _parseType(rawType),
      data: json,
    );
  }

  static WsEventType _parseType(String type) {
    switch (type) {
      // API spec primary events
      case 'attendance_update':
        return WsEventType.attendanceUpdate;
      case 'student_marked':
        return WsEventType.studentMarked;

      // Legacy/fallback events
      case 'session_preparing':
      case 'SESSION_PREPARING':
        return WsEventType.sessionPreparing;
      case 'session_igniting':
      case 'SESSION_IGNITING':
        return WsEventType.sessionIgniting;
      case 'attendance_open':
      case 'ATTENDANCE_OPEN':
        return WsEventType.attendanceOpen;
      case 'session_activated':
      case 'SESSION_ACTIVATED':
        return WsEventType.sessionActivated;
      case 'otp_verified':
      case 'OTP_VERIFIED':
        return WsEventType.otpVerified;
      case 'student_verified':
      case 'STUDENT_VERIFIED':
      case 'ATTENDANCE_MARKED':
        return WsEventType.studentVerified;
      case 'student_rejected':
      case 'STUDENT_REJECTED':
        return WsEventType.studentRejected;
      case 'attendance_marked_manual':
      case 'ATTENDANCE_MARKED_MANUAL':
        return WsEventType.attendanceMarkedManual;
      case 'attendance_updated':
      case 'ATTENDANCE_UPDATED':
        return WsEventType.attendanceUpdated;
      case 'mark_attendance_ack':
      case 'MARK_ATTENDANCE_ACK':
        return WsEventType.markAttendanceAck;
      case 'attendance_closed':
      case 'ATTENDANCE_CLOSED':
        return WsEventType.attendanceClosed;
      case 'session_archived':
      case 'SESSION_ARCHIVED':
        return WsEventType.sessionArchived;
      case 'full_state_sync':
      case 'FULL_STATE_SYNC':
        return WsEventType.fullStateSync;
      case 'faculty_sync':
      case 'FACULTY_SYNC':
        return WsEventType.facultySync;
      case 'board_connected':
      case 'BOARD_CONNECTED':
        return WsEventType.boardConnected;
      case 'otp_failed':
      case 'OTP_FAILED':
        return WsEventType.otpFailed;
      // ── Chat / Messaging ─────────────────────────────────────
      case 'message_new':
      case 'chat_message':
        return WsEventType.messageNew;
      case 'message_ack':
      case 'message_sent_ack':
        return WsEventType.messageAck;
      case 'message_read':
      case 'read_receipt':
        return WsEventType.messageRead;
      case 'message_delivered':
        return WsEventType.messageDelivered;
      case 'message_edited':
        return WsEventType.messageEdited;
      case 'message_deleted':
        return WsEventType.messageDeleted;
      case 'message_pinned':
        return WsEventType.messagePinned;
      case 'typing':
      case 'typing_indicator':
        return WsEventType.typing;
      case 'presence_update':
      case 'presence':
        return WsEventType.presenceUpdate;
      case 'call_event':
        return WsEventType.callEvent;
      case 'conversation_sync':
        return WsEventType.conversationSync;
      // ── ──────────────────────────────────────────────────────
      case 'heartbeat':
      case 'pong':
        return WsEventType.heartbeat;
      default:
        return WsEventType.unknown;
    }
  }

  T? get<T>(String key) => data[key] as T?;
}

class AttendanceUpdateData {
  final String? studentId;
  final String? status;
  final String? studentEmail;

  AttendanceUpdateData({
    this.studentId,
    this.status,
    this.studentEmail,
  });

  factory AttendanceUpdateData.fromEvent(WebSocketEvent event) {
    return AttendanceUpdateData(
      studentId: event.get<String>('student_id') ?? event.get<String>('roll_number'),
      status: event.get<String>('status'),
      studentEmail: event.get<String>('student_email') ?? event.get<String>('email'),
    );
  }
}

class StudentMarkedData {
  final String? studentId;
  final int trustScore;

  StudentMarkedData({
    this.studentId,
    required this.trustScore,
  });

  factory StudentMarkedData.fromEvent(WebSocketEvent event) {
    return StudentMarkedData(
      studentId: event.get<String>('student_id'),
      trustScore: event.get<int>('trust_score') ?? 0,
    );
  }
}

class FacultySyncData {
  final int totalPresent;
  final int totalStudents;
  final List<Map<String, dynamic>> presentStudents;

  FacultySyncData({
    required this.totalPresent,
    required this.totalStudents,
    required this.presentStudents,
  });

  factory FacultySyncData.fromEvent(WebSocketEvent event) {
    return FacultySyncData(
      totalPresent: event.get<int>('total_present') ?? 0,
      totalStudents: event.get<int>('total_students') ?? 0,
      presentStudents: (event.data['present_students'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class FullStateSyncData {
  final int totalPresent;
  final int totalStudents;
  final List<Map<String, dynamic>> roster;

  FullStateSyncData({
    required this.totalPresent,
    required this.totalStudents,
    required this.roster,
  });

  factory FullStateSyncData.fromEvent(WebSocketEvent event) {
    return FullStateSyncData(
      totalPresent: event.get<int>('total_present') ?? 0,
      totalStudents: event.get<int>('total_students') ?? 0,
      roster: (event.data['roster'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class AttendanceMarkAckData {
  final bool success;
  final String? studentId;
  final String? error;
  final Map<String, dynamic>? data;

  AttendanceMarkAckData({
    required this.success,
    this.studentId,
    this.error,
    this.data,
  });

  factory AttendanceMarkAckData.fromEvent(WebSocketEvent event) {
    return AttendanceMarkAckData(
      success: event.get<bool>('success') ?? false,
      studentId: event.get<String>('student_id'),
      error: event.get<String>('error'),
      data: event.data['data'] as Map<String, dynamic>?,
    );
  }
}

class BoardConnectedData {
  final String? sessionId;

  BoardConnectedData({this.sessionId});

  factory BoardConnectedData.fromEvent(WebSocketEvent event) {
    return BoardConnectedData(
      sessionId: event.get<String>('session_id'),
    );
  }
}

class OtpFailedData {
  final String? sessionId;
  final int attemptCount;
  final int retriesRemaining;

  OtpFailedData({
    this.sessionId,
    required this.attemptCount,
    required this.retriesRemaining,
  });

  factory OtpFailedData.fromEvent(WebSocketEvent event) {
    return OtpFailedData(
      sessionId: event.get<String>('session_id'),
      attemptCount: event.get<int>('attempt_count') ?? 1,
      retriesRemaining: event.get<int>('retries_remaining') ?? 4,
    );
  }
}
