import 'chat_enums.dart';
import 'chat_message.dart';
import 'student_contact.dart';

/// A 1:1 conversation between the faculty user and a peer ([StudentContact]).
///
/// Persisted in Hive for offline access. The list of loaded messages lives in
/// the controller; [lastMessage] is the denormalized preview for the list UI.
class ChatConversation {
  final String id;
  final StudentContact peer;
  final String? lastMessage;
  final MessageStatus? lastMessageStatus;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isMuted;
  final bool isBlocked;
  final bool isPinned;
  final bool isArchived;
  final bool isGroup;
  final String? groupName;
  final String? draft;
  final DateTime? createdAt;

  const ChatConversation({
    required this.id,
    required this.peer,
    this.lastMessage,
    this.lastMessageStatus,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isBlocked = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isGroup = false,
    this.groupName,
    this.draft,
    this.createdAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      peer: StudentContact.fromJson(
        Map<String, dynamic>.from(json['peer'] as Map? ?? const {}),
      ),
      lastMessage: json['last_message']?.toString(),
      lastMessageStatus: json['last_message_status'] != null
          ? MessageStatus.fromJson(json['last_message_status'].toString())
          : null,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.tryParse(json['last_message_time'].toString())
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isMuted: json['is_muted'] == true,
      isBlocked: json['is_blocked'] == true,
      isPinned: json['is_pinned'] == true,
      isArchived: json['is_archived'] == true,
      isGroup: json['is_group'] == true,
      groupName: json['group_name']?.toString(),
      draft: json['draft']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'peer': peer.toJson(),
      'last_message': lastMessage,
      'last_message_status': lastMessageStatus?.toJson(),
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
      'is_muted': isMuted,
      'is_blocked': isBlocked,
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'is_group': isGroup,
      'group_name': groupName,
      'draft': draft,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  String get title => isGroup ? (groupName ?? peer.name) : peer.name;

  ChatConversation copyWith({
    String? lastMessage,
    MessageStatus? lastMessageStatus,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isMuted,
    bool? isBlocked,
    bool? isPinned,
    bool? isArchived,
    String? draft,
    DateTime? createdAt,
  }) {
    return ChatConversation(
      id: id,
      peer: peer,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isBlocked: isBlocked ?? this.isBlocked,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isGroup: isGroup,
      groupName: groupName,
      draft: draft ?? this.draft,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Regenerate this conversation from the newest message (used after send/recv).
  ChatConversation updateFromMessage(ChatMessage message) {
    return copyWith(
      lastMessage: message.contentSummary,
      lastMessageStatus: message.status,
      lastMessageTime: message.timestamp,
    );
  }

  ChatConversation resetUnread() => copyWith(unreadCount: 0);
}
