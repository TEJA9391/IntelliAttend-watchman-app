import 'dart:async';
import 'dart:io';

import 'package:intelli_attend_faculty/Core/Models/websocket_event.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Services/chat_realtime_service.dart';

/// Offline send queue.
///
/// Drains the outbox + failed queue whenever the messaging socket (re)connects
/// so messages composed without connectivity are delivered once the network
/// returns. Uploads local attachment files first, then dispatches over the
/// realtime socket like a live send.
class ChatOutboxService {
  ChatOutboxService._internal();
  static final ChatOutboxService instance = ChatOutboxService._internal();

  final MessagingRepository _repository = MessagingRepository();
  bool _started = false;
  bool _draining = false;
  bool _subscribed = false;

  void start() {
    if (_started) return;
    _started = true;
    if (!_subscribed) {
      _subscribed = true;
      ChatRealtimeService.instance.connectionState.addListener(_onConnectionChanged);
    }
    if (ChatRealtimeService.instance.connectionState.value ==
        WsConnectionState.connected) {
      Future.microtask(_drain);
    }
  }

  void _onConnectionChanged() {
    if (ChatRealtimeService.instance.connectionState.value ==
        WsConnectionState.connected) {
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final cache = MessageCacheService.instance;
      final queued = <String, ChatMessage>{
        for (final m in cache.loadOutbox()) m.id: m,
        for (final m in cache.loadFailed()) m.id: m,
      }.values.toList();

      for (final message in queued) {
        try {
          await _deliver(message);
        } catch (_) {
          break; // network dropped mid-drain; retry on next reconnect.
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _deliver(ChatMessage message) async {
    final cache = MessageCacheService.instance;
    final conversationId = message.conversationId;
    final attachment = message.attachments.firstOrNull;
    final localPath = attachment?.localPath;
    final hasLocalFile = localPath != null && File(localPath).existsSync();

    if (attachment != null && hasLocalFile) {
      final response = await _repository.uploadAttachment(
        conversationId: conversationId,
        file: File(localPath),
        fileName: attachment.name,
        mimeType: attachment.mimeType ?? 'application/octet-stream',
      );
      if (!response.success || response.data == null) return;
      final uploaded = response.data!;
      ChatRealtimeService.instance.sendChatMessage(
        conversationId: conversationId,
        messageId: message.id,
        text: message.text,
        messageType: message.type.toJson(),
        attachments: [uploaded.toJson()],
        replyToMessageId: message.replyTo?.messageId,
      );
    } else {
      final response = await _repository.sendMessage(
        conversationId: conversationId,
        message: message,
      );
      if (!response.success) return;
      ChatRealtimeService.instance.sendChatMessage(
        conversationId: conversationId,
        messageId: message.id,
        text: message.text,
        messageType: message.type.toJson(),
        attachments: message.attachments.map((a) => a.toJson()).toList(),
        replyToMessageId: message.replyTo?.messageId,
      );
    }

    await cache.removeFromOutbox(message.id);
    await cache.removeFailed(message.id);
  }

  void dispose() {
    if (_subscribed) {
      _subscribed = false;
      ChatRealtimeService.instance.connectionState.removeListener(_onConnectionChanged);
    }
    _started = false;
  }
}
