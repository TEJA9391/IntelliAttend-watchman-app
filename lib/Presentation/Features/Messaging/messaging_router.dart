import 'package:flutter/material.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/main.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_screen.dart';

/// Opens screens from notification payloads.
///
/// Supported payloads:
///   - `chat:<conversationId>` → opens the conversation in the chat screen.
class MessagingRouter {
  MessagingRouter._();

  static String? _pendingConversationId;

  /// Called when a notification with a `chat:` payload is tapped.
  static void openChatFromPayload(String payload) {
    if (!payload.startsWith('chat:')) return;
    final conversationId = payload.substring('chat:'.length).trim();
    if (conversationId.isEmpty) return;

    final navigator = IntelliAttendApp.navigatorKey.currentState;
    if (navigator == null) {
      _pendingConversationId = conversationId;
      return;
    }
    _openConversation(navigator, conversationId);
  }

  /// Invoked by the app shell once the navigator is ready (e.g. right after
  /// first frame) to flush any pending deep-link.
  static void flushPending() {
    final pending = _pendingConversationId;
    if (pending == null) return;
    _pendingConversationId = null;
    final navigator = IntelliAttendApp.navigatorKey.currentState;
    if (navigator != null) {
      _openConversation(navigator, pending);
    }
  }

  static void _openConversation(NavigatorState navigator, String conversationId) {
    final cache = MessageCacheService.instance;
    final conversations = cache.loadConversations();

    ChatConversation? conversation;
    for (final c in conversations) {
      if (c.id == conversationId) {
        conversation = c;
        break;
      }
    }

    if (conversation == null) {
      // Reconstruct a shell from a direct peer id.
      final peerId = conversationId.startsWith('direct_')
          ? conversationId.substring('direct_'.length)
          : conversationId;
      final peer = StudentContact(id: peerId, name: 'Student');
      conversation = ChatConversation(
        id: conversationId,
        peer: peer,
        createdAt: DateTime.now(),
      );
      cache.upsertConversation(conversation);
    }

    navigator.push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation!)),
    );
  }
}
