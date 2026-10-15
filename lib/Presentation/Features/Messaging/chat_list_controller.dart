import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:intelli_attend_faculty/Core/Models/websocket_event.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Services/chat_realtime_service.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';
import 'package:intelli_attend_faculty/Services/websocket_service.dart';

/// Manages the conversation (chat list) screen.
///
/// Loads conversations from the backend, falls back to the local Hive cache.
/// Subscribes to realtime events to live-update previews, unread counts,
/// presence and typing indicators.
class ChatListController extends ChangeNotifier {
  final MessagingRepository repository;
  final MessageCacheService cache;

  List<ChatConversation> _conversations = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String _searchQuery = '';
  bool _backendAvailable = false;

  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;
  StreamSubscription<WsConnectionState>? _connSub;

  ChatListController({
    required this.repository,
    MessageCacheService? cache,
  }) : cache = cache ?? MessageCacheService.instance {
    _init();
  }

  List<ChatConversation> get conversations {
    final filtered = _searchQuery.trim().isEmpty
        ? List<ChatConversation>.from(_conversations)
        : _conversations
            .where((c) =>
                c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (c.peer.rollNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                (c.peer.section?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
            .toList();

    filtered.sort((a, b) {
      final aPinned = cache.isPinned(a.id);
      final bPinned = cache.isPinned(b.id);
      if (aPinned != bPinned) return aPinned ? -1 : 1;
      final aTime = a.lastMessageTime ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageTime ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return filtered;
  }

  List<ChatConversation> get allConversations => _conversations;

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isBackendAvailable => _backendAvailable;
  String get searchQuery => _searchQuery;

  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  /// Presence/typing state delegates straight to the realtime service.
  PresenceSnapshot? presenceFor(String peerId) =>
      ChatRealtimeService.instance.presenceFor(peerId);

  bool isTypingIn(String conversationId) =>
      ChatRealtimeService.instance.isTypingIn(conversationId);

  bool isRecording(String peerId) =>
      ChatRealtimeService.instance.isRecording(peerId);

  void _init() {
    _realtimeSub = ChatRealtimeService.instance.events.listen(_onRealtimeEvent);
    _connSub = WebSocketService().connectionState.listen((_) {});
    _bootstrapRealtime();
    Future(() => load());
  }

  void _bootstrapRealtime() {
    Future(() {
      ChatRealtimeService.instance.connect();
      ChatRealtimeService.instance.sendPresence(online: true);
    });
  }

  /// Initial load: backend first, cache fallback, demo catalog last.
  Future<void> load({bool forceRefresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    _backendAvailable = await repository.isBackendAvailable;

    final response = await repository.fetchConversations();
    if (response.success && response.data != null) {
      final fresh = response.data!;
      _mergeFromBackend(fresh);
      await cache.saveConversations(_conversations);
      _hasMore = fresh.length >= 30;
    } else {
      await _hydrateFromCacheOrDemo();
    }

    _isLoading = false;
    notifyListeners();
    if (forceRefresh) {
      _refreshPresenceFlags();
    }
  }

  /// Pulls to refresh.
  Future<void> refresh() async {
    await load(forceRefresh: true);
  }

  void _mergeFromBackend(List<ChatConversation> fresh) {
    final map = <String, ChatConversation>{};
    for (final c in _conversations) {
      map[c.id] = c;
    }
    for (final c in fresh) {
      // Preserve locally known unread + muted flags from cache.
      final cached = map[c.id];
      final cachedUnread = cached?.unreadCount ?? cache.loadConversations()
          .where((cc) => cc.id == c.id)
          .firstOrNull
          ?.unreadCount;
      map[c.id] = c.copyWith(
        unreadCount: cachedUnread ?? c.unreadCount,
        isMuted: cache.isMuted(c.id),
        isBlocked: cache.isBlocked(c.id),
      );
    }
    _conversations = map.values.toList();
  }

  Future<void> _hydrateFromCacheOrDemo() async {
    await cache.pruneDemoData();
    _conversations = cache.loadConversations();
  }

  /// Opens a conversation (marks read locally when a chat screen opens).
  ChatConversation? conversationFor(String conversationId) {
    for (final c in _conversations) {
      if (c.id == conversationId) return c;
    }
    return null;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> markConversationRead(String conversationId) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    if (_conversations[index].unreadCount > 0) {
      _conversations[index] = _conversations[index].resetUnread();
      await cache.upsertConversation(_conversations[index]);
      NotificationService().syncBadgeCount(cache.totalUnreadCount);
      notifyListeners();
    }
    // Fire-and-forget backend read receipt.
    repository.markConversationRead(conversationId);
  }

  Future<void> toggleMute(ChatConversation conversation) async {
    final muted = !conversation.isMuted;
    await cache.setMuted(conversation.id, muted);
    await _updateFlag(conversation.id, (c) => c.copyWith(isMuted: muted));
    repository.setMuted(conversation.id, muted);
  }

  Future<void> togglePin(ChatConversation conversation) async {
    final pinned = !conversation.isPinned;
    await cache.setPinned(conversation.id, pinned);
    await _updateFlag(conversation.id, (c) => c.copyWith(isPinned: pinned));
    notifyListeners();
  }

  Future<void> toggleBlock(ChatConversation conversation) async {
    final blocked = !conversation.isBlocked;
    await cache.setBlocked(conversation.id, blocked);
    await _updateFlag(conversation.id, (c) => c.copyWith(isBlocked: blocked));
    repository.setBlocked(conversation.id, blocked);
  }

  Future<void> setArchived(ChatConversation conversation, bool archived) async {
    await cache.setArchived(conversation.id, archived);
    await _updateFlag(conversation.id, (c) => c.copyWith(isArchived: archived));
  }

  Future<void> _updateFlag(
      String conversationId, ChatConversation Function(ChatConversation) update) async {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    _conversations[index] = update(_conversations[index]);
    await cache.upsertConversation(_conversations[index]);
    notifyListeners();
  }

  /// Hard-deletes the conversation from the device + backend.
  Future<void> deleteConversation(ChatConversation conversation) async {
    _conversations.removeWhere((c) => c.id == conversation.id);
    await cache.removeConversation(conversation.id);
    notifyListeners();
    repository.deleteConversation(conversation.id);
  }

  void _refreshPresenceFlags() {
    notifyListeners();
  }

  // ── Realtime handling ─────────────────────────────────────────────────

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    switch (event.kind) {
      case 'message_new':
        _handleIncomingMessage(event);
      case 'receipt':
      case 'read':
      case 'delivered':
        _handleReceipt(event);
      case 'typing':
        // Typing handled by ChatRealtimeService.typingStatus; a notify keeps
        // the conversation list subtitle up to date.
        notifyListeners();
      case 'presence':
        notifyListeners();
      case 'call':
        break;
      case 'ack':
      case 'edited':
      case 'deleted':
      case 'pinned':
      case 'sync':
        notifyListeners();
      default:
        break;
    }
  }

  void _handleIncomingMessage(ChatRealtimeEvent event) {
    final convId = event.conversationId;
    if (convId == null) return;
    final index = _conversations.indexWhere((c) => c.id == convId);
    if (index == -1) return;

    final data = event.data;
    final text = data['text']?.toString() ?? data['content_summary']?.toString() ?? 'New message';
    final messageTime = DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now();

    // The global ChatNotificationService already bumped the cached unread
    // count (and handled the system/in-app alert). Refresh the in-memory
    // conversation from the cache so the list reflects it immediately.
    final cached = cache.loadConversations().where((c) => c.id == convId).firstOrNull;
    _conversations[index] = (cached ?? _conversations[index]).copyWith(
      lastMessage: text,
      lastMessageStatus: MessageStatus.sent,
      lastMessageTime: messageTime,
      unreadCount: cached?.unreadCount ?? _conversations[index].unreadCount,
    );
    cache.upsertConversation(_conversations[index]);
    notifyListeners();
  }

  void _handleReceipt(ChatRealtimeEvent event) {
    final convId = event.conversationId;
    if (convId == null) return;
    final index = _conversations.indexWhere((c) => c.id == convId);
    if (index == -1) return;
    final statusStr = event.kind == 'read'
        ? 'read'
        : event.kind == 'delivered'
            ? 'delivered'
            : event.status;
    if (statusStr == 'read') {
      _conversations[index] = _conversations[index].copyWith(
        lastMessageStatus: MessageStatus.read,
      );
      cache.upsertConversation(_conversations[index]);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
