enum MessageType { announcement, classMessage, individual, parent }

enum MessageStatus { sending, sent, delivered, read, failed }

enum MessagePriority { normal, important, urgent, emergency }

enum MessageCategory {
  text,
  importantNotice,
  assignment,
  homework,
  examNotification,
  holidayNotice,
  eventNotification,
  emergencyAlert,
  reminder,
  custom,
}

enum RecipientGroup {
  entireClass,
  selectedStudents,
  absentStudents,
  presentStudents,
  lateStudents,
  below75,
  parents,
  individual,
  multipleClasses,
  allStudents,
}

class FacultyMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? recipientId;
  final String? recipientName;
  final String subject;
  final String body;
  final MessageType type;
  final MessageStatus status;
  final MessagePriority priority;
  final MessageCategory category;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? scheduledAt;
  final List<String> attachments;
  final String? courseCode;
  final String? section;
  final int recipientCount;
  final int readCount;
  final RecipientGroup recipientGroup;
  final List<String> recipientIds;
  final String? notes;

  FacultyMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.recipientId,
    this.recipientName,
    required this.subject,
    required this.body,
    required this.type,
    this.status = MessageStatus.sent,
    this.priority = MessagePriority.normal,
    this.category = MessageCategory.text,
    required this.createdAt,
    this.readAt,
    this.scheduledAt,
    this.attachments = const [],
    this.courseCode,
    this.section,
    this.recipientCount = 1,
    this.readCount = 0,
    this.recipientGroup = RecipientGroup.individual,
    this.recipientIds = const [],
    this.notes,
  });

  bool get isRead => status == MessageStatus.read;
  bool get isScheduled => scheduledAt != null && scheduledAt!.isAfter(DateTime.now());

  FacultyMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? recipientId,
    String? recipientName,
    String? subject,
    String? body,
    MessageType? type,
    MessageStatus? status,
    MessagePriority? priority,
    MessageCategory? category,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? scheduledAt,
    List<String>? attachments,
    String? courseCode,
    String? section,
    int? recipientCount,
    int? readCount,
    RecipientGroup? recipientGroup,
    List<String>? recipientIds,
    String? notes,
  }) {
    return FacultyMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      attachments: attachments ?? this.attachments,
      courseCode: courseCode ?? this.courseCode,
      section: section ?? this.section,
      recipientCount: recipientCount ?? this.recipientCount,
      readCount: readCount ?? this.readCount,
      recipientGroup: recipientGroup ?? this.recipientGroup,
      recipientIds: recipientIds ?? this.recipientIds,
      notes: notes ?? this.notes,
    );
  }

  factory FacultyMessage.fromJson(Map<String, dynamic> json) {
    return FacultyMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Unknown',
      recipientId: json['recipient_id']?.toString(),
      recipientName: json['recipient_name']?.toString(),
      subject: json['subject']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: _parseType(json['type']?.toString()),
      status: _parseStatus(json['status']?.toString()),
      priority: _parsePriority(json['priority']?.toString()),
      category: _parseCategory(json['category']?.toString()),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'].toString())
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      courseCode: json['course_code']?.toString(),
      section: json['section']?.toString(),
      recipientCount: json['recipient_count'] as int? ?? 1,
      readCount: json['read_count'] as int? ?? 0,
      recipientGroup: _parseRecipientGroup(json['recipient_group']?.toString()),
      recipientIds: (json['recipient_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      if (recipientId != null) 'recipient_id': recipientId,
      if (recipientName != null) 'recipient_name': recipientName,
      'subject': subject,
      'body': body,
      'type': type.name,
      'status': status.name,
      'priority': priority.name,
      'category': category.name,
      'created_at': createdAt.toIso8601String(),
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
      if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
      'attachments': attachments,
      if (courseCode != null) 'course_code': courseCode,
      if (section != null) 'section': section,
      'recipient_count': recipientCount,
      'read_count': readCount,
      'recipient_group': recipientGroup.name,
      'recipient_ids': recipientIds,
      if (notes != null) 'notes': notes,
    };
  }

  static MessageType _parseType(String? value) {
    switch (value) {
      case 'classMessage':
        return MessageType.classMessage;
      case 'individual':
        return MessageType.individual;
      case 'parent':
        return MessageType.parent;
      default:
        return MessageType.announcement;
    }
  }

  static MessageStatus _parseStatus(String? value) {
    switch (value) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  static MessagePriority _parsePriority(String? value) {
    switch (value) {
      case 'important':
        return MessagePriority.important;
      case 'urgent':
        return MessagePriority.urgent;
      case 'emergency':
        return MessagePriority.emergency;
      default:
        return MessagePriority.normal;
    }
  }

  static MessageCategory _parseCategory(String? value) {
    for (final c in MessageCategory.values) {
      if (c.name == value) return c;
    }
    return MessageCategory.text;
  }

  static RecipientGroup _parseRecipientGroup(String? value) {
    for (final g in RecipientGroup.values) {
      if (g.name == value) return g;
    }
    return RecipientGroup.individual;
  }
}

class MessageThread {
  final String threadId;
  final String participantName;
  final String? participantId;
  final FacultyMessage lastMessage;
  final int unreadCount;
  final bool isOnline;

  MessageThread({
    required this.threadId,
    required this.participantName,
    this.participantId,
    required this.lastMessage,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      threadId: json['thread_id']?.toString() ?? '',
      participantName: json['participant_name']?.toString() ?? 'Unknown',
      participantId: json['participant_id']?.toString(),
      lastMessage: FacultyMessage.fromJson(
        json['last_message'] as Map<String, dynamic>? ?? {},
      ),
      unreadCount: json['unread_count'] as int? ?? 0,
      isOnline: json['is_online'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thread_id': threadId,
      'participant_name': participantName,
      if (participantId != null) 'participant_id': participantId,
      'last_message': lastMessage.toJson(),
      'unread_count': unreadCount,
      'is_online': isOnline,
    };
  }
}

class MessageTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;
  final MessageCategory category;
  final MessagePriority priority;

  const MessageTemplate({
    required this.id,
    required this.name,
    required this.subject,
    required this.body,
    this.category = MessageCategory.text,
    this.priority = MessagePriority.normal,
  });
}

class MessageFilter {
  final String? query;
  final MessageType? type;
  final MessageStatus? status;
  final MessagePriority? priority;
  final MessageCategory? category;
  final String? courseCode;
  final String? section;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const MessageFilter({
    this.query,
    this.type,
    this.status,
    this.priority,
    this.category,
    this.courseCode,
    this.section,
    this.dateFrom,
    this.dateTo,
  });

  MessageFilter copyWith({
    String? query,
    MessageType? type,
    MessageStatus? status,
    MessagePriority? priority,
    MessageCategory? category,
    String? courseCode,
    String? section,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearType = false,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearCategory = false,
    bool clearCourseCode = false,
    bool clearSection = false,
    bool clearDateFrom = false,
    bool clearDateTo = false,
  }) {
    return MessageFilter(
      query: query ?? this.query,
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
      priority: clearPriority ? null : (priority ?? this.priority),
      category: clearCategory ? null : (category ?? this.category),
      courseCode: clearCourseCode ? null : (courseCode ?? this.courseCode),
      section: clearSection ? null : (section ?? this.section),
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
    );
  }

  bool get hasActiveFilters =>
      query != null ||
      type != null ||
      status != null ||
      priority != null ||
      category != null ||
      courseCode != null ||
      section != null ||
      dateFrom != null ||
      dateTo != null;
}
