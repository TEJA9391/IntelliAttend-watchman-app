/// Enums shared across the Messaging / Chat feature.
///
/// These mirror the existing codebase conventions (enum + snake_case JSON keys)
/// and are stable for persistence in Hive and serialization over REST/WebSocket.

/// The kind of content carried by a [ChatMessage].
enum MessageContentType {
  text,
  image,
  document,
  pdf,
  word,
  excel,
  powerpoint,
  audio,
  voice,
  video,
  gif,
  emoji,
  location,
  contact,
  zip,
  attendanceReport,
  assignment,
  announcement,
  system;

  static MessageContentType fromJson(String? value) {
    switch (value) {
      case 'image':
        return MessageContentType.image;
      case 'document':
        return MessageContentType.document;
      case 'pdf':
        return MessageContentType.pdf;
      case 'word':
        return MessageContentType.word;
      case 'excel':
        return MessageContentType.excel;
      case 'powerpoint':
        return MessageContentType.powerpoint;
      case 'audio':
        return MessageContentType.audio;
      case 'voice':
      case 'voice_note':
        return MessageContentType.voice;
      case 'video':
        return MessageContentType.video;
      case 'gif':
        return MessageContentType.gif;
      case 'emoji':
        return MessageContentType.emoji;
      case 'location':
        return MessageContentType.location;
      case 'contact':
        return MessageContentType.contact;
      case 'zip':
        return MessageContentType.zip;
      case 'attendance_report':
        return MessageContentType.attendanceReport;
      case 'assignment':
        return MessageContentType.assignment;
      case 'announcement':
        return MessageContentType.announcement;
      case 'system':
        return MessageContentType.system;
      case 'text':
      default:
        return MessageContentType.text;
    }
  }

  String toJson() {
    switch (this) {
      case MessageContentType.voice:
        return 'voice';
      case MessageContentType.attendanceReport:
        return 'attendance_report';
      case MessageContentType.zip:
      case MessageContentType.assignment:
      case MessageContentType.announcement:
      case MessageContentType.text:
      case MessageContentType.image:
      case MessageContentType.document:
      case MessageContentType.pdf:
      case MessageContentType.word:
      case MessageContentType.excel:
      case MessageContentType.powerpoint:
      case MessageContentType.audio:
      case MessageContentType.video:
      case MessageContentType.gif:
      case MessageContentType.emoji:
      case MessageContentType.location:
      case MessageContentType.contact:
      case MessageContentType.system:
        return name;
    }
  }

  bool get isFile => this == MessageContentType.document ||
      this == MessageContentType.pdf ||
      this == MessageContentType.word ||
      this == MessageContentType.excel ||
      this == MessageContentType.powerpoint ||
      this == MessageContentType.zip;
}

/// Delivery lifecycle of an outgoing message.
enum MessageStatus {
  pending, // queued offline, not yet attempted
  sending,
  sent,
  delivered,
  read,
  failed;

  static MessageStatus fromJson(String? value) {
    switch (value) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      case 'pending':
      default:
        return MessageStatus.pending;
    }
  }

  String toJson() => name;
}

/// Direction of a message relative to the current faculty user.
enum MessageDirection {
  outgoing,
  incoming;

  static MessageDirection fromJson(String? value) =>
      value == 'incoming' ? MessageDirection.incoming : MessageDirection.outgoing;
}

/// The subject of a call session.
enum CallType {
  audio,
  video;

  static CallType fromJson(String? value) =>
      value == 'video' ? CallType.video : CallType.audio;
}

/// Direction of a call relative to the current faculty user.
enum CallDirection {
  outgoing,
  incoming;

  static CallDirection fromJson(String? value) =>
      value == 'incoming' ? CallDirection.incoming : CallDirection.outgoing;
}

/// Lifecycle state of a call shown on the call screen.
enum CallState {
  calling, // outgoing - dialing
  ringing, // outgoing - the peer device is ringing
  incoming, // incoming - asking the user to accept
  connecting,
  connected,
  ended,
  missed,
  rejected,
  busy,
  failed;

  static CallState fromJson(String? value) {
    switch (value) {
      case 'ringing':
        return CallState.ringing;
      case 'incoming':
        return CallState.incoming;
      case 'connecting':
        return CallState.connecting;
      case 'connected':
        return CallState.connected;
      case 'ended':
        return CallState.ended;
      case 'missed':
        return CallState.missed;
      case 'rejected':
        return CallState.rejected;
      case 'busy':
        return CallState.busy;
      case 'failed':
        return CallState.failed;
      case 'calling':
      default:
        return CallState.calling;
    }
  }

  String toJson() => name;
}

/// Grouping for the forward / new-message picker.
enum ForwardTargetType {
  student,
  multipleStudents,
  classGroup,
  department,
  faculty,
  chat;
}
