import 'chat_attachment.dart';
import 'chat_enums.dart';
import 'student_contact.dart';

/// A single message inside a [ChatConversation].
///
/// Persisted to Hive (offline cache) and serialized over REST / WebSocket.
/// The transient fields (`uploadProgress`, `isUploading`, `isSelected`)
/// are excluded from [toJson].
class ChatMessage {
  final String id;
  final String localId;
  final String conversationId;

  final MessageDirection direction;
  final MessageContentType type;
  final String text;
  final List<ChatAttachment> attachments;

  final String senderId;
  final String senderName;

  final DateTime timestamp;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? editedAt;

  MessageStatus status;
  bool isEdited;
  bool isForwarded;
  bool isPinned;
  bool isStarred;
  bool isDeletedForMe;
  bool isDeletedForEveryone;

  final ReplyPreview? replyTo;
  final int threadCount;
  final List<String> reactions;

  // Transient — not persisted.
  double uploadProgress;
  bool isUploading;
  bool isSelected;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.direction,
    required this.type,
    this.text = '',
    List<ChatAttachment>? attachments,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    this.status = MessageStatus.sent,
    this.isEdited = false,
    this.isForwarded = false,
    this.isPinned = false,
    this.isStarred = false,
    this.isDeletedForMe = false,
    this.isDeletedForEveryone = false,
    this.replyTo,
    this.threadCount = 0,
    List<String>? reactions,
    this.uploadProgress = 0,
    this.isUploading = false,
    this.isSelected = false,
    String? localId,
  })  : attachments = attachments ?? const [],
        reactions = reactions ?? const [],
        localId = localId ?? 'local_${DateTime.now().microsecondsSinceEpoch}_${id}';

  /// Creates an optimistic outgoing message before the server round-trip.
  factory ChatMessage.local({
    required String conversationId,
    required String senderId,
    required String senderName,
    required MessageContentType type,
    String text = '',
    List<ChatAttachment>? attachments,
    ReplyPreview? replyTo,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    return ChatMessage(
      id: 'local_${now.microsecondsSinceEpoch}',
      conversationId: conversationId,
      direction: MessageDirection.outgoing,
      type: type,
      text: text,
      attachments: attachments,
      senderId: senderId,
      senderName: senderName,
      timestamp: now,
      status: MessageStatus.pending,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      localId: json['local_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      direction: MessageDirection.fromJson(json['direction']?.toString()),
      type: MessageContentType.fromJson(json['type']?.toString()),
      text: json['text']?.toString() ?? '',
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => ChatAttachment.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'].toString())
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'].toString())
          : null,
      status: MessageStatus.fromJson(json['status']?.toString()),
      isEdited: json['is_edited'] == true,
      isForwarded: json['is_forwarded'] == true,
      isPinned: json['is_pinned'] == true,
      isStarred: json['is_starred'] == true,
      isDeletedForMe: json['is_deleted_for_me'] == true,
      isDeletedForEveryone: json['is_deleted_for_everyone'] == true,
      replyTo: json['reply_to'] != null
          ? ReplyPreview.fromJson(Map<String, dynamic>.from(json['reply_to'] as Map))
          : null,
      threadCount: (json['thread_count'] as num?)?.toInt() ?? 0,
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'local_id': localId,
      'conversation_id': conversationId,
      'direction': direction == MessageDirection.outgoing ? 'outgoing' : 'incoming',
      'type': type.toJson(),
      'text': text,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'sender_id': senderId,
      'sender_name': senderName,
      'timestamp': timestamp.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
      'status': status.toJson(),
      'is_edited': isEdited,
      'is_forwarded': isForwarded,
      'is_pinned': isPinned,
      'is_starred': isStarred,
      'is_deleted_for_me': isDeletedForMe,
      'is_deleted_for_everyone': isDeletedForEveryone,
      'reply_to': replyTo?.toJson(),
      'thread_count': threadCount,
      'reactions': reactions,
    };
  }

  /// Human readable summary used by the conversation list preview.
  String get contentSummary {
    switch (type) {
      case MessageContentType.text:
      case MessageContentType.emoji:
        return text;
      case MessageContentType.image:
        return attachments.isEmpty ? 'Photo' : '📷 ${attachments.first.name}';
      case MessageContentType.gif:
        return 'GIF';
      case MessageContentType.video:
        return attachments.isEmpty ? 'Video' : '🎬 ${attachments.first.name}';
      case MessageContentType.voice:
        return '🎤 Voice message';
      case MessageContentType.audio:
        return attachments.isEmpty ? 'Audio' : '🎵 ${attachments.first.name}';
      case MessageContentType.document:
        return attachments.isEmpty ? 'Document' : '📄 ${attachments.first.name}';
      case MessageContentType.pdf:
        return attachments.isEmpty ? 'PDF' : '📕 ${attachments.first.name}';
      case MessageContentType.word:
        return attachments.isEmpty ? 'Document' : '📘 ${attachments.first.name}';
      case MessageContentType.excel:
        return attachments.isEmpty ? 'Spreadsheet' : '📗 ${attachments.first.name}';
      case MessageContentType.powerpoint:
        return attachments.isEmpty ? 'Presentation' : '📙 ${attachments.first.name}';
      case MessageContentType.location:
        return '📍 Location';
      case MessageContentType.contact:
        return attachments.isEmpty
            ? '👤 Contact'
            : '👤 ${attachments.first.contactName ?? 'Contact'}';
      case MessageContentType.zip:
        return attachments.isEmpty ? '🗜 Archive' : '🗜 ${attachments.first.name}';
      case MessageContentType.attendanceReport:
        return '📊 Attendance report';
      case MessageContentType.assignment:
        return '📝 ${attachments.isEmpty ? 'Assignment' : attachments.first.name}';
      case MessageContentType.announcement:
        return '📢 ${attachments.isEmpty ? 'Announcement' : attachments.first.name}';
      case MessageContentType.system:
        return text;
    }
  }

  bool get hasAttachment => attachments.isNotEmpty;

  bool get isDeleted => isDeletedForEveryone || isDeletedForMe;

  bool get isSystem => type == MessageContentType.system;

  ChatMessage copyWith({
    MessageStatus? status,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? editedAt,
    bool? isEdited,
    bool? isForwarded,
    bool? isPinned,
    bool? isStarred,
    bool? isDeletedForMe,
    bool? isDeletedForEveryone,
    String? id,
    String? text,
    String? conversationId,
    List<ChatAttachment>? attachments,
    ReplyPreview? replyTo,
    int? threadCount,
    List<String>? reactions,
    double? uploadProgress,
    bool? isUploading,
    bool? isSelected,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      localId: localId,
      conversationId: conversationId ?? this.conversationId,
      direction: direction,
      type: type,
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      senderId: senderId,
      senderName: senderName,
      timestamp: timestamp ?? this.timestamp,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      editedAt: editedAt ?? this.editedAt,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      isForwarded: isForwarded ?? this.isForwarded,
      isPinned: isPinned ?? this.isPinned,
      isStarred: isStarred ?? this.isStarred,
      isDeletedForMe: isDeletedForMe ?? this.isDeletedForMe,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      replyTo: replyTo ?? this.replyTo,
      threadCount: threadCount ?? this.threadCount,
      reactions: reactions ?? this.reactions,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isUploading: isUploading ?? this.isUploading,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
