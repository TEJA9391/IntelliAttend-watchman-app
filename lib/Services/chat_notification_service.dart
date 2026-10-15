import 'dart:async';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Services/chat_realtime_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';

/// App-wide chat notification coordinator.
///
/// Subscribes to the realtime socket once, at boot, so a new message produces
/// a system alert, an in-app history entry, an unread bump and a launcher
/// badge regardless of which screen is open. Skips the conversation the user
/// currently has open, muted conversations and the faculty's own sends.
///
/// FCM (foreground) and this WebSocket watcher can deliver the same message;
/// [NotificationService.claimChatNotification] guarantees exactly one system
/// alert, while the unread bump always happens.
class ChatNotificationService {
  ChatNotificationService._internal();
  static final ChatNotificationService instance = ChatNotificationService._internal();

  bool _started = false;
  StreamSubscription<ChatRealtimeEvent>? _sub;

  void start() {
    if (_started) return;
    _started = true;
    ChatRealtimeService.instance.connect();
    _sub = ChatRealtimeService.instance.events.listen(_onEvent);
  }

  /// Called by the FCM foreground handler for `chat_message` pushes.
  void handleRemoteChatMessage(Map<String, dynamic> data) {
    _processIncoming(data['conversation_id']?.toString(), data, fromFcm: true);
  }

  void _onEvent(ChatRealtimeEvent event) {
    if (event.kind != 'message_new') return;
    _processIncoming(event.conversationId, event.data, fromFcm: false);
  }

  void _processIncoming(String? convId, Map<String, dynamic> data,
      {required bool fromFcm}) {
    if (convId == null || convId.isEmpty) return;
    final senderId = data['sender_id']?.toString();
    if (senderId == null || senderId == FacultyService.canonicalId) return;
    if (NotificationService.isConversationActive(convId)) return;

    final cache = MessageCacheService.instance;
    if (cache.isMuted(convId)) return;

    final body = _bodyOf(data);
    final timestamp =
        DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now();

    ChatConversation? conversation;
    final list = cache.loadConversations();
    final index = list.indexWhere((c) => c.id == convId);
    if (index != -1) {
      final base = list[index];
      conversation = base.copyWith(
        lastMessage: body,
        lastMessageStatus: MessageStatus.sent,
        lastMessageTime: timestamp,
        unreadCount: base.unreadCount + 1,
      );
      cache.upsertConversation(conversation);
    }

    final senderName = data['sender_name']?.toString() ?? 'New message';
    final title = conversation?.title ?? senderName;

    // System alert only for the first delivery (WS or FCM, whichever arrives
    // first); the unread bump above is applied regardless.
    if (!NotificationService.claimChatNotification(
        data['message_id']?.toString() ?? '')) {
      return;
    }

    NotificationService().showChatNotification(
      conversationId: convId,
      senderName: senderName,
      message: body,
      title: title,
    );
    NotificationService().addNotification(
      title: title,
      body: body,
      category: NotificationCategory.chat,
      payload: 'chat:$convId',
    );
    NotificationService().syncBadgeCount(cache.totalUnreadCount);
  }

  String _bodyOf(Map<String, dynamic> data) {
    final text = data['text']?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
    return data['content_summary']?.toString() ?? 'New message';
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
