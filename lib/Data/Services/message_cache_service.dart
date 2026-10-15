import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

/// Local offline cache + outbox for the Messaging feature.
///
/// Backed by the encrypted Hive `messaging` box. Messages, conversations,
/// drafts, call history and the offline outbox are all persisted here so the
/// chat works fully offline and syncs when connectivity returns.
class MessageCacheService {
  MessageCacheService._internal();
  static final MessageCacheService instance = MessageCacheService._internal();

  Box? get _box => PersistenceService.messagingBox;

  bool get isReady => PersistenceService.messagingBox != null;

  // ── Conversations ─────────────────────────────────────────────────────

  List<ChatConversation> loadConversations() {
    final raw = _box?.get('conversations');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveConversations(List<ChatConversation> conversations) async {
    await _box?.put('conversations',
        conversations.map((c) => c.toJson()).toList());
  }

  Future<void> upsertConversation(ChatConversation conversation) async {
    final list = loadConversations();
    final index = list.indexWhere((c) => c.id == conversation.id);
    if (index >= 0) {
      list[index] = conversation;
    } else {
      list.add(conversation);
    }
    await saveConversations(list);
  }

  Future<void> removeConversation(String conversationId) async {
    final list = loadConversations()
        .where((c) => c.id != conversationId)
        .toList();
    await saveConversations(list);
    await _box?.delete('messages_$conversationId');
  }

  int get totalUnreadCount {
    return loadConversations().fold(0, (sum, c) => sum + c.unreadCount);
  }

  // ── Messages ──────────────────────────────────────────────────────────

  List<ChatMessage> loadMessages(String conversationId) {
    final raw = _box?.get('messages_$conversationId');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _persistMessages(String conversationId, List<ChatMessage> messages) async {
    await _box?.put('messages_$conversationId',
        messages.map((m) => m.toJson()).toList());
  }

  /// Replaces the cached message set with [messages] (deduplicated, sorted).
  Future<void> saveMessages(String conversationId, List<ChatMessage> messages) async {
    final deduped = <String, ChatMessage>{};
    for (final m in messages) {
      deduped[m.id] = m;
    }
    final sorted = deduped.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await _persistMessages(conversationId, sorted);
  }

  /// Merges [incoming] into the cache, keeping existing older/newer messages.
  Future<void> mergeMessages(String conversationId, List<ChatMessage> incoming) async {
    final existing = loadMessages(conversationId);
    final map = <String, ChatMessage>{};
    for (final m in existing) {
      map[m.id] = m;
    }
    for (final m in incoming) {
      map[m.id] = m;
    }
    final sorted = map.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    await _persistMessages(conversationId, sorted);
  }

  ChatMessage? getMessage(String conversationId, String messageId) {
    for (final m in loadMessages(conversationId)) {
      if (m.id == messageId) return m;
    }
    return null;
  }

  Future<void> updateMessage(String conversationId, ChatMessage message) async {
    await mergeMessages(conversationId, [message]);
  }

  /// Marks messages deleted-for-me, retaining them in an undo buffer so the
  /// user can restore. Returns the number of messages affected.
  Future<int> deleteForMe(String conversationId, List<String> messageIds) async {
    final messages = loadMessages(conversationId);
    final affected = <ChatMessage>[];
    final updated = messages.map((m) {
      if (messageIds.contains(m.id)) {
        affected.add(m);
        return m.copyWith(isDeletedForMe: true);
      }
      return m;
    }).toList();
    if (affected.isEmpty) return 0;
    await _persistMessages(conversationId, updated);
    await _pushUndo(conversationId, affected);
    return affected.length;
  }

  /// Deletes for everyone (all devices). Kept for undo locally as well.
  Future<int> deleteForEveryone(String conversationId, List<String> messageIds) async {
    final messages = loadMessages(conversationId);
    final affected = <ChatMessage>[];
    final updated = messages.map((m) {
      if (messageIds.contains(m.id)) {
        affected.add(m);
        return m.copyWith(
          isDeletedForEveryone: true,
          text: '',
        );
      }
      return m;
    }).toList();
    if (affected.isEmpty) return 0;
    await _persistMessages(conversationId, updated);
    await _pushUndo(conversationId, affected);
    return affected.length;
  }

  /// Restores messages previously deleted (undo support).
  Future<void> undoDelete(String conversationId) async {
    final key = 'undo_$conversationId';
    final raw = _box?.get(key);
    if (raw == null) return;
    final restored = (raw as List)
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    await mergeMessages(conversationId,
        restored.map((m) => m.copyWith(isDeletedForMe: false, isDeletedForEveryone: false)).toList());
    await _box?.delete(key);
  }

  Future<void> _pushUndo(String conversationId, List<ChatMessage> messages) async {
    await _box?.put('undo_$conversationId',
        messages.map((m) => m.toJson()).toList());
  }

  /// Marks incoming messages as read locally.
  Future<void> markMessagesRead(String conversationId, List<String> messageIds) async {
    final messages = loadMessages(conversationId);
    var changed = false;
    final updated = messages.map((m) {
      if (messageIds.contains(m.id) &&
          m.direction == MessageDirection.incoming &&
          m.status != MessageStatus.read) {
        changed = true;
        return m.copyWith(status: MessageStatus.read, readAt: DateTime.now());
      }
      return m;
    }).toList();
    if (changed) await _persistMessages(conversationId, updated);
  }

  Future<void> clearConversation(String conversationId) async {
    await _persistMessages(conversationId, []);
  }

  // ── Drafts ────────────────────────────────────────────────────────────

  String? getDraft(String conversationId) =>
      _box?.get('draft_$conversationId')?.toString();

  Future<void> saveDraft(String conversationId, String draft) async {
    await _box?.put('draft_$conversationId', draft);
  }

  // ── Outbox (offline queue) ────────────────────────────────────────────

  List<ChatMessage> loadOutbox() {
    final raw = _box?.get('outbox');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> enqueueOutbox(ChatMessage message) async {
    final list = loadOutbox()..removeWhere((m) => m.id == message.id);
    list.add(message);
    await _box?.put('outbox', list.map((m) => m.toJson()).toList());
  }

  Future<void> removeFromOutbox(String messageId) async {
    final list = loadOutbox().where((m) => m.id != messageId).toList();
    await _box?.put('outbox', list.map((m) => m.toJson()).toList());
  }

  Future<void> saveOutbox(List<ChatMessage> messages) async {
    await _box?.put('outbox', messages.map((m) => m.toJson()).toList());
  }

  // ── Failed queue ──────────────────────────────────────────────────────

  List<ChatMessage> loadFailed() {
    final raw = _box?.get('failed_messages');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addFailed(ChatMessage message) async {
    final list = loadFailed()..removeWhere((m) => m.id == message.id);
    list.add(message.copyWith(status: MessageStatus.failed));
    await _box?.put('failed_messages', list.map((m) => m.toJson()).toList());
  }

  Future<void> removeFailed(String messageId) async {
    final list = loadFailed().where((m) => m.id != messageId).toList();
    await _box?.put('failed_messages', list.map((m) => m.toJson()).toList());
  }

  Future<void> saveFailed(List<ChatMessage> messages) async {
    await _box?.put('failed_messages', messages.map((m) => m.toJson()).toList());
  }

  // ── Call history ──────────────────────────────────────────────────────

  List<ChatCall> loadCallHistory(String peerId) {
    final raw = _box?.get('calls_$peerId');
    if (raw == null) return [];
    return (raw as List)
        .map((e) => ChatCall.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addCall(ChatCall call) async {
    final list = loadCallHistory(call.peer.id)
      ..removeWhere((c) => c.id == call.id)
      ..add(call)
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    await _box?.put('calls_${call.peer.id}', list.map((c) => c.toJson()).toList());
  }

  // ── Conversation flags ────────────────────────────────────────────────

  Future<void> setMuted(String conversationId, bool muted) async {
    await _box?.put('muted_$conversationId', muted);
  }

  bool isMuted(String conversationId) => _box?.get('muted_$conversationId') == true;

  Future<void> setBlocked(String conversationId, bool blocked) async {
    await _box?.put('blocked_$conversationId', blocked);
  }

  bool isBlocked(String conversationId) => _box?.get('blocked_$conversationId') == true;

  Future<void> setPinned(String conversationId, bool pinned) async {
    final list = (List<String>.from(_box?.get('pinned_conversations') ?? const []))
        .where((c) => c != conversationId)
        .toList();
    if (pinned) list.insert(0, conversationId);
    await _box?.put('pinned_conversations', list);
  }

  bool isPinned(String conversationId) =>
      (List<String>.from(_box?.get('pinned_conversations') ?? const []))
          .contains(conversationId);

  Future<void> setArchived(String conversationId, bool archived) async {
    final list = (List<String>.from(_box?.get('archived_conversations') ?? const []))
        .where((c) => c != conversationId)
        .toList();
    if (archived) list.add(conversationId);
    await _box?.put('archived_conversations', list);
  }

  bool isArchived(String conversationId) =>
      (List<String>.from(_box?.get('archived_conversations') ?? const []))
          .contains(conversationId);

  /// Wallpaper override for a conversation (color ARGB int).
  Future<void> setWallpaper(String conversationId, int color) async {
    await _box?.put('wallpaper_$conversationId', color);
  }

  int? getWallpaper(String conversationId) => _box?.get('wallpaper_$conversationId');

  /// Per-chat accent theme (index into the theme palette).
  Future<void> setChatAccent(String conversationId, int index) async {
    await _box?.put('accent_$conversationId', index);
  }

  int? getChatAccent(String conversationId) => _box?.get('accent_$conversationId');

  /// Per-chat dark mode.
  Future<void> setDarkChat(String conversationId, bool dark) async {
    await _box?.put('dark_chat_$conversationId', dark);
  }

  bool? getDarkChat(String conversationId) => _box?.get('dark_chat_$conversationId');

  /// Premium wallpaper preset id for a conversation (null/empty = default).
  Future<void> setWallpaperId(String conversationId, String? wallpaperId) async {
    if (wallpaperId == null || wallpaperId.isEmpty) {
      await _box?.delete('wallpaper_id_$conversationId');
    } else {
      await _box?.put('wallpaper_id_$conversationId', wallpaperId);
    }
  }

  String? getWallpaperId(String conversationId) =>
      _box?.get('wallpaper_id_$conversationId')?.toString();

  /// Local path to a user-picked custom wallpaper image.
  Future<void> setCustomWallpaperPath(String conversationId, String? path) async {
    if (path == null || path.isEmpty) {
      await _box?.delete('wallpaper_custom_$conversationId');
    } else {
      await _box?.put('wallpaper_custom_$conversationId', path);
    }
  }

  String? getCustomWallpaperPath(String conversationId) =>
      _box?.get('wallpaper_custom_$conversationId')?.toString();

  /// Per-chat theme mode: 'auto' | 'light' | 'dark'.
  Future<void> setChatThemeMode(String conversationId, String mode) async {
    await _box?.put('theme_mode_$conversationId', mode);
  }

  String getChatThemeMode(String conversationId) =>
      _box?.get('theme_mode_$conversationId')?.toString() ?? 'auto';

  /// Glass / blur effect toggle for the chat surface (header, input, bubbles).
  Future<void> setGlassEnabled(String conversationId, bool enabled) async {
    await _box?.put('glass_$conversationId', enabled);
  }

  bool getGlassEnabled(String conversationId) => _box?.get('glass_$conversationId') == true;

  /// Global toggle for message/typing sounds.
  Future<void> setSoundsEnabled(bool enabled) async {
    await _box?.put('chat_sounds_enabled', enabled);
  }

  bool getSoundsEnabled() => _box?.get('chat_sounds_enabled') ?? true;

  /// Starred/pinned index across all conversations (for the profile screen).
  List<ChatMessage> loadStarred() {
    final result = <ChatMessage>[];
    final convos = loadConversations();
    for (final c in convos) {
      for (final m in loadMessages(c.id)) {
        if (m.isStarred && !m.isDeleted) result.add(m);
      }
    }
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  /// Re-encodes a list of messages into a plain-text export.
  String exportAsText(String conversationId, String title) {
    final messages = loadMessages(conversationId);
    final buffer = StringBuffer();
    buffer.writeln('$title — exported ${DateTime.now().toIso8601String()}');
    buffer.writeln('-----------------------------------');
    for (final m in messages) {
      if (m.isDeletedForEveryone) continue;
      final sender = m.direction == MessageDirection.outgoing ? 'Me' : m.senderName;
      buffer.writeln('[${m.timestamp.toIso8601String()}] $sender: ${m.contentSummary}');
    }
    return buffer.toString();
  }

  /// JSON dump used by export (also fed to the PDF/CSV generators).
  String exportAsJson(String conversationId) {
    final messages = loadMessages(conversationId)
        .where((m) => !m.isDeletedForEveryone)
        .toList();
    return jsonEncode(messages.map((m) => m.toJson()).toList());
  }

  /// Removes all `demo_`-prefixed seeded data (conversations, message caches,
  /// per-chat flags) so the live backend feed is the only source of truth.
  Future<void> pruneDemoData() async {
    final box = _box;
    if (box == null) return;
    final conversations = loadConversations();
    final kept =
        conversations.where((c) => !c.id.startsWith('demo_')).toList();
    final pruned =
        conversations.where((c) => c.id.startsWith('demo_')).toList();
    if (pruned.isEmpty) return;

    // Sweep every key referencing a demo conversation.
    for (final key in box.keys.cast<String>().toList()) {
      if (key.contains('demo_')) {
        await box.delete(key);
      }
    }
    // Clean demo ids out of pinned/archived id lists.
    final pinned = List<String>.from(box.get('pinned_conversations') ?? const [])
        .where((id) => !id.startsWith('demo_'))
        .toList();
    await box.put('pinned_conversations', pinned);
    final archived =
        List<String>.from(box.get('archived_conversations') ?? const [])
            .where((id) => !id.startsWith('demo_'))
            .toList();
    await box.put('archived_conversations', archived);
    // Drop demo messages still queued in the outbox/failed queues.
    await _box?.put(
        'outbox', loadOutbox().where((m) => !m.conversationId.startsWith('demo_')).map((m) => m.toJson()).toList());
    await _box?.put(
        'failed_messages', loadFailed().where((m) => !m.conversationId.startsWith('demo_')).map((m) => m.toJson()).toList());
    await saveConversations(kept);
    debugPrint('[MessageCache] pruned ${pruned.length} demo conversations');
  }

  void logStats() {
    debugPrint('[MessageCache] conversations=${loadConversations().length} '
        'outbox=${loadOutbox().length} failed=${loadFailed().length}');
  }
}
