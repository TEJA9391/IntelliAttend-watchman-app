import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Services/chat_realtime_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_time_format.dart';

/// A single in-flight attachment upload with progress + cancellation.
class UploadTask {
  final String messageId;
  final String fileName;
  final CancelToken cancelToken = CancelToken();
  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<bool> cancelled = ValueNotifier(false);
  bool failed = false;
  String? error;

  UploadTask({required this.messageId, required this.fileName});

  void cancel() {
    cancelled.value = true;
    cancelToken.cancel('cancelled');
  }

  void dispose() {
    progress.dispose();
    cancelled.dispose();
  }
}

/// Manages a single conversation screen.
///
/// Handles pagination (lazy loading), optimistic sends, attachments with
/// progress/cancel/retry, offline outbox, read receipts, typing, search,
/// selection and all message mutations. Subscribes to realtime events.
class ChatScreenController extends ChangeNotifier {
  final MessagingRepository repository;
  final MessageCacheService cache;
  final ChatConversation conversation;

  final List<ChatMessage> _messages = [];
  final Map<String, UploadTask> _uploads = {};

  bool _isLoading = true;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _isBackendAvailable = false;
  bool _isOffline = false;
  String? _error;
  DateTime? _oldestLoaded;

  ChatMessage? _replyTarget;
  bool _selectionMode = false;
  final List<String> _selectedIds = [];

  String _searchQuery = '';
  List<ChatMessage> _searchResults = [];
  bool _isSearching = false;

  Timer? _typingDebounce;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  ChatScreenController({
    required this.repository,
    required this.conversation,
    MessageCacheService? cache,
  }) : cache = cache ?? MessageCacheService.instance {
    _init();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get loadingOlder => _loadingOlder;
  bool get hasMore => _hasMore;
  bool get isOffline => _isOffline;
  String? get error => _error;
  bool get isBackendAvailable => _isBackendAvailable;

  ChatMessage? get replyTarget => _replyTarget;
  bool get selectionMode => _selectionMode;
  List<String> get selectedIds => List.unmodifiable(_selectedIds);
  List<ChatMessage> get selectedMessages =>
      _messages.where((m) => _selectedIds.contains(m.id)).toList();

  String get searchQuery => _searchQuery;
  List<ChatMessage> get searchResults => List.unmodifiable(_searchResults);
  bool get isSearching => _isSearching;

  Map<String, UploadTask> get uploads => _uploads;
  bool get hasActiveUploads => _uploads.values.any((u) => !u.cancelled.value);

  /// Fired when a real-time message arrives while the chat is open.
  VoidCallback? onIncomingMessage;

  String get _myId => FacultyService.canonicalId ?? 'faculty';
  String get _myName => FacultyService.profile.value?.name ?? 'Faculty';

  void _init() {
    _realtimeSub = ChatRealtimeService.instance.events.listen(_onRealtimeEvent);
    _loadInitial();
  }

  // ── Loading / pagination ──────────────────────────────────────────────

  Future<void> _loadInitial() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _isBackendAvailable = await repository.isBackendAvailable;
    _isOffline = !_isBackendAvailable;

    // Hydrate from cache first for instant paint.
    final cached = cache.loadMessages(conversation.id);
    if (cached.isNotEmpty) {
      _messages
        ..clear()
        ..addAll(cached);
      _oldestLoaded = _messages.first.timestamp;
    }

    final response = await repository.fetchMessages(conversationId: conversation.id);
    if (response.success && response.data != null) {
      final fresh = response.data!;
      _isOffline = false;
      await cache.mergeMessages(conversation.id, fresh);
      _mergeIncoming(fresh);
      _oldestLoaded = _messages.firstOrNull?.timestamp;
      _hasMore = fresh.length >= 25;
    }

    _isLoading = false;
    notifyListeners();

    // Read receipts for any unread incoming messages at the bottom.
    _autoMarkRead();
  }

  Future<void> loadOlder() async {
    if (_loadingOlder || !_hasMore || _oldestLoaded == null) return;
    _loadingOlder = true;
    notifyListeners();

    final response = await repository.fetchMessages(
      conversationId: conversation.id,
      before: _oldestLoaded,
    );
    if (response.success && response.data != null && response.data!.isNotEmpty) {
      final older = response.data!;
      await cache.mergeMessages(conversation.id, older);
      _mergeIncoming(older);
      _oldestLoaded = _messages.firstOrNull?.timestamp;
      _hasMore = older.length >= 25;
    } else {
      _hasMore = false;
    }
    _loadingOlder = false;
    notifyListeners();
  }

  void _mergeIncoming(List<ChatMessage> incoming) {
    final map = <String, ChatMessage>{};
    for (final m in _messages) {
      map[m.id] = m;
    }
    for (final m in incoming) {
      map[m.id] = m;
    }
    final merged = map.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _messages
      ..clear()
      ..addAll(merged);
  }

  // ── Sending ───────────────────────────────────────────────────────────

  /// Sends a text/emoji message. Optimistic add, then persisted + realtime.
  Future<void> sendText(String text,
      {MessageContentType type = MessageContentType.text, ChatMessage? replyTo}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final target = replyTo ?? _replyTarget;

    final message = ChatMessage.local(
      conversationId: conversation.id,
      senderId: _myId,
      senderName: _myName,
      type: type,
      text: trimmed,
      replyTo: target != null
          ? ReplyPreview(
              messageId: target.id,
              senderName: target.senderName,
              text: target.contentSummary,
              type: target.type,
            )
          : null,
    );

    if (replyTo == null) _replyTarget = null;
    _appendAndPersist(message);
    notifyListeners();

    await _sendViaBackend(message);
  }

  Future<void> _sendViaBackend(ChatMessage message) async {
    if (_isBackendAvailable) {
      final response = await repository.sendMessage(
        conversationId: conversation.id,
        message: message,
      );
      if (response.success) {
        final serverMsg = response.data;
        if (serverMsg != null) {
          _replaceMessage(message.id, serverMsg.copyWith(status: MessageStatus.delivered));
          await cache.removeFromOutbox(message.id);
        } else {
          _markStatus(message.id, MessageStatus.delivered);
        }
        ChatRealtimeService.instance.sendChatMessage(
          conversationId: conversation.id,
          messageId: message.id,
          text: message.text,
          messageType: message.type.toJson(),
          replyToMessageId: message.replyTo?.messageId,
        );
        return;
      }
    }

    // Offline / backend failure → queue in outbox, will sync when online.
    await cache.enqueueOutbox(message.copyWith(status: MessageStatus.pending));
    _markStatus(message.id, MessageStatus.pending);
    _isOffline = true;
    notifyListeners();
  }

  /// Retries a failed/pending message (also used by the failed queue UI).
  Future<void> retryMessage(ChatMessage message) async {
    _markStatus(message.id, MessageStatus.sending);
    final fileAttachment = message.attachments.firstOrNull;
    final hasLocalFile = fileAttachment?.localPath != null &&
        File(fileAttachment!.localPath!).existsSync();
    if (_isBackendAvailable && hasLocalFile) {
      await _sendAttachmentMessage(message);
      return;
    }
    await _sendViaBackend(message.copyWith(status: MessageStatus.sending));
  }

  /// Sends an attachment-only message. Uploads first (with progress), then
  /// persists the message with the remote URL.
  Future<void> sendAttachment(ChatAttachment attachment,
      {ChatMessage? replyTo}) async {
    final target = replyTo ?? _replyTarget;
    final message = ChatMessage.local(
      conversationId: conversation.id,
      senderId: _myId,
      senderName: _myName,
      type: attachment.type,
      text: '',
      attachments: [attachment],
      replyTo: target != null
          ? ReplyPreview(
              messageId: target.id,
              senderName: target.senderName,
              text: target.contentSummary,
              type: target.type,
            )
          : null,
    );
    if (replyTo == null) _replyTarget = null;
    _appendAndPersist(message);
    notifyListeners();
    await _sendAttachmentMessage(message);
  }

  /// Uploads / dispatches an existing local attachment message. Shared by
  /// [sendAttachment] and [retryMessage] so a failed file upload can be
  /// re-uploaded against the same message.
  Future<void> _sendAttachmentMessage(ChatMessage message) async {
    final attachment = message.attachments.firstOrNull;
    final localPath = attachment?.localPath;
    final hasLocalFile = localPath != null && File(localPath).existsSync();
    if (_isBackendAvailable && hasLocalFile) {
      final att = attachment!;
      final task = UploadTask(messageId: message.id, fileName: att.name);
      _uploads[message.id] = task;
      task.progress.addListener(() => notifyListeners());
      _markStatus(message.id, MessageStatus.sending, isUploading: true);

      final response = await repository.uploadAttachment(
        conversationId: conversation.id,
        file: File(localPath),
        fileName: att.name,
        mimeType: att.mimeType ?? 'application/octet-stream',
        onProgress: (p) => task.progress.value = p,
        cancelToken: task.cancelToken,
      );

      if (response.success && response.data != null) {
        final uploaded = response.data!;
        final updated = _messages.firstWhere((m) => m.id == message.id);
        _replaceMessage(message.id, updated.copyWith(
          attachments: [uploaded],
          status: MessageStatus.sent,
          isUploading: false,
          uploadProgress: 1,
        ));
        ChatRealtimeService.instance.sendChatMessage(
          conversationId: conversation.id,
          messageId: message.id,
          text: '',
          messageType: message.type.toJson(),
          attachments: [uploaded.toJson()],
        );
        await cache.removeFromOutbox(message.id);
      } else {
        final isCancel = response.error == 'Upload cancelled' || task.cancelled.value;
        _replaceMessage(message.id, _messages.firstWhere((m) => m.id == message.id).copyWith(
              isUploading: false,
              uploadProgress: 0,
              status: isCancel ? MessageStatus.pending : MessageStatus.failed,
            ));
        if (!isCancel) {
          await cache.enqueueOutbox(
              _messages.firstWhere((m) => m.id == message.id).copyWith(status: MessageStatus.pending));
        }
      }
      task.dispose();
      _uploads.remove(message.id);
      notifyListeners();
    } else if (_isBackendAvailable && !hasLocalFile) {
      // Non-file attachments (location, contact, rich cards) ride the JSON
      // message path so they reach the backend without a multipart upload.
      final response = await repository.sendMessage(
        conversationId: conversation.id,
        message: message,
      );
      if (response.success) {
        final serverMsg = response.data;
        if (serverMsg != null) {
          _replaceMessage(message.id, serverMsg.copyWith(status: MessageStatus.delivered));
        } else {
          _markStatus(message.id, MessageStatus.delivered);
        }
        ChatRealtimeService.instance.sendChatMessage(
          conversationId: conversation.id,
          messageId: message.id,
          text: message.text,
          messageType: message.type.toJson(),
          attachments: message.attachments.map((a) => a.toJson()).toList(),
          replyToMessageId: message.replyTo?.messageId,
        );
        await cache.removeFromOutbox(message.id);
      } else {
        await cache.enqueueOutbox(message.copyWith(status: MessageStatus.pending));
        _markStatus(message.id, MessageStatus.pending);
        _isOffline = true;
      }
      notifyListeners();
    } else {
      // Offline: persist locally, queue in outbox for background sync.
      await cache.enqueueOutbox(message);
      _markStatus(message.id, MessageStatus.pending);
      notifyListeners();
    }
  }

  /// Cancels an in-flight upload.
  void cancelUpload(String messageId) {
    final task = _uploads[messageId];
    if (task != null) {
      task.cancel();
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isUploading: false,
          status: MessageStatus.pending,
          uploadProgress: 0,
        );
        _persist();
        notifyListeners();
      }
    }
  }

  Future<void> _persist() async {
    await cache.saveMessages(conversation.id, _messages);
  }

  void _appendAndPersist(ChatMessage message) {
    _messages.add(message);
    _persist();
    // Update the conversation preview in the list controller cache.
    cache.upsertConversation(conversation.updateFromMessage(message));
  }

  void _replaceMessage(String id, ChatMessage replacement) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    _messages[index] = replacement;
    _persist();
    notifyListeners();
  }

  void _markStatus(String id, MessageStatus status, {bool isUploading = false}) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    _messages[index] = _messages[index].copyWith(
      status: status,
      isUploading: isUploading,
      deliveredAt: status == MessageStatus.delivered
          ? (_messages[index].deliveredAt ?? DateTime.now())
          : _messages[index].deliveredAt,
      readAt: status == MessageStatus.read ? DateTime.now() : _messages[index].readAt,
    );
    _persist();
    notifyListeners();
  }

  // ── Read receipts ─────────────────────────────────────────────────────

  void _autoMarkRead() {
    final unread = _messages
        .where((m) => m.direction == MessageDirection.incoming && m.status != MessageStatus.read)
        .map((m) => m.id)
        .toList();
    if (unread.isEmpty) return;
    _markRead(unread);
  }

  void markRead() {
    _autoMarkRead();
    ChatRealtimeService.instance.sendReadReceipt(conversation.id, _messages
        .where((m) => m.direction == MessageDirection.incoming)
        .map((m) => m.id)
        .toList());
  }

  Future<void> _markRead(List<String> ids) async {
    await cache.markMessagesRead(conversation.id, ids);
    for (final id in ids) {
      _markStatus(id, MessageStatus.read);
    }
  }

  // ── Typing ────────────────────────────────────────────────────────────

  /// Debounced typing indicator broadcast.
  void notifyTyping(bool isTyping) {
    _typingDebounce?.cancel();
    if (isTyping) {
      ChatRealtimeService.instance.sendTyping(conversation.id, true);
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        ChatRealtimeService.instance.sendTyping(conversation.id, false);
      });
    } else {
      ChatRealtimeService.instance.sendTyping(conversation.id, false);
    }
  }

  // ── Reply ─────────────────────────────────────────────────────────────

  void setReplyTarget(ChatMessage? message) {
    _replyTarget = message;
    notifyListeners();
  }

  void clearReply() {
    _replyTarget = null;
    notifyListeners();
  }

  // ── Message mutations ─────────────────────────────────────────────────

  Future<void> deleteMessage(ChatMessage message, {required bool forEveryone}) async {
    final ids = _selectedIds.isNotEmpty ? _selectedIds : [message.id];
    if (forEveryone) {
      await cache.deleteForEveryone(conversation.id, ids);
    } else {
      await cache.deleteForMe(conversation.id, ids);
    }
    for (final id in ids) {
      final m = _messages.firstWhere((m) => m.id == id);
      final updated = forEveryone
          ? m.copyWith(isDeletedForEveryone: true, text: '')
          : m.copyWith(isDeletedForMe: true);
      _replaceMessage(id, updated);
    }
    if (_isBackendAvailable) {
      for (final id in ids) {
        repository.deleteMessage(
            conversationId: conversation.id, messageId: id, forEveryone: forEveryone);
      }
    }
    ChatRealtimeService.instance.sendTyping(conversation.id, false);
    exitSelection();
  }

  /// Restores the last deleted batch (undo support).
  Future<void> undoDelete() async {
    await cache.undoDelete(conversation.id);
    final refreshed = cache.loadMessages(conversation.id);
    _messages
      ..clear()
      ..addAll(refreshed);
    notifyListeners();
  }

  Future<void> pinMessage(ChatMessage message, {bool pin = true}) async {
    _replaceMessage(message.id, message.copyWith(isPinned: pin));
    await cache.updateMessage(conversation.id, message.copyWith(isPinned: pin));
    if (_isBackendAvailable) {
      repository.pinMessage(conversationId: conversation.id, messageId: message.id, pin: pin);
    }
  }

  Future<void> starMessage(ChatMessage message, {bool star = true}) async {
    _replaceMessage(message.id, message.copyWith(isStarred: star));
    await cache.updateMessage(conversation.id, message.copyWith(isStarred: star));
    if (_isBackendAvailable) {
      repository.starMessage(conversationId: conversation.id, messageId: message.id, star: star);
    }
  }

  /// Toggles an emoji reaction on a message (WhatsApp-style single reaction).
  Future<void> toggleReaction(ChatMessage message, String emoji) async {
    final current = List<String>.from(message.reactions);
    if (current.contains(emoji)) {
      current.remove(emoji);
    } else {
      current
        ..clear()
        ..add(emoji);
    }
    final updated = message.copyWith(reactions: current);
    _replaceMessage(message.id, updated);
    await cache.updateMessage(conversation.id, updated);
    if (_isBackendAvailable) {
      repository.reactMessage(
        conversationId: conversation.id,
        messageId: message.id,
        emoji: emoji,
      );
    }
    ChatRealtimeService.instance.sendTyping(conversation.id, false);
  }

  /// Messages pinned in this conversation (newest first).
  List<ChatMessage> get pinnedMessages {
    final pinned = _messages.where((m) => m.isPinned && !m.isDeletedForEveryone).toList();
    pinned.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return pinned;
  }

  Future<void> editMessage(ChatMessage message, String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty || trimmed == message.text) return;
    final updated = message.copyWith(
      text: trimmed,
      isEdited: true,
      editedAt: DateTime.now(),
    );
    _replaceMessage(message.id, updated);
    await cache.updateMessage(conversation.id, updated);
    if (_isBackendAvailable) {
      repository.editMessage(
          conversationId: conversation.id, messageId: message.id, newText: trimmed);
    }
    ChatRealtimeService.instance.sendTyping(conversation.id, false);
  }

  Future<void> forwardMessages(ChatMessage message, List<String> targetIds) async {
    if (_isBackendAvailable) {
      await repository.forwardMessage(
        sourceConversationId: conversation.id,
        messageId: message.id,
        targetConversationIds: targetIds,
      );
      return;
    }
    // Offline: append a forwarded copy to each target conversation locally.
    for (final target in targetIds) {
      final forwarded = message.copyWith(
        id: 'fwd_${DateTime.now().microsecondsSinceEpoch}_$target',
        conversationId: target,
        isForwarded: true,
        status: MessageStatus.pending,
        timestamp: DateTime.now(),
      );
      await cache.mergeMessages(target, [forwarded]);
      await cache.enqueueOutbox(forwarded);
    }
  }

  Future<String?> translateMessage(ChatMessage message, {String target = 'en'}) async {
    if (!_isBackendAvailable) return null;
    final response = await repository.translateMessage(
      conversationId: conversation.id,
      messageId: message.id,
      targetLanguage: target,
    );
    return response.success ? response.data : null;
  }

  Future<void> clearChat() async {
    await cache.clearConversation(conversation.id);
    _messages.clear();
    notifyListeners();
    if (_isBackendAvailable) {
      repository.clearConversation(conversation.id);
    }
  }

  Future<String?> exportChat(String format) async {
    if (format == 'text') {
      return cache.exportAsText(conversation.id, conversation.title);
    }
    if (format == 'json') {
      return cache.exportAsJson(conversation.id);
    }
    if (_isBackendAvailable) {
      final response = await repository.exportConversation(conversation.id, format);
      return response.success ? response.data : null;
    }
    return null;
  }

  // ── Selection mode ────────────────────────────────────────────────────

  void _syncSelectionFlags() {
    for (final m in _messages) {
      m.isSelected = _selectedIds.contains(m.id);
    }
  }

  void enterSelection(ChatMessage message) {
    _selectionMode = true;
    _selectedIds.clear();
    _selectedIds.add(message.id);
    _syncSelectionFlags();
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    if (_selectedIds.isEmpty) _selectionMode = false;
    _syncSelectionFlags();
    notifyListeners();
  }

  void exitSelection() {
    _selectionMode = false;
    _selectedIds.clear();
    _syncSelectionFlags();
    notifyListeners();
  }

  // ── Search (in-conversation) ──────────────────────────────────────────

  static final RegExp _linkPattern = RegExp(r'https?://', caseSensitive: false);

  ChatSearchFilter? _activeFilter;

  /// Whether a search is currently pinned (so realtime events can re-filter).
  bool get searchActive => _activeFilter?.isActive ?? false;

  Future<void> searchMessages(ChatSearchFilter filter) async {
    _activeFilter = filter;
    _searchQuery = filter.query;
    _isSearching = true;
    notifyListeners();

    if (!filter.isActive) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    await _runSearch(filter);
  }

  /// (Re)runs the search pipeline. Kept separate from [searchMessages] so
  /// realtime message events can refresh results without resetting the query.
  Future<void> _runSearch(ChatSearchFilter filter) async {
    // Always search the local cache instantly (offline-first).
    _searchResults = _localSearchResults(filter);

    if (_isBackendAvailable) {
      final response = await repository.searchMessages(
        conversationId: conversation.id,
        query: filter.hasQuery ? filter.query : '*',
        filter: filter.category.serverFilter,
        dateFrom: _dayStart(filter.date),
        dateTo: _dayEnd(filter.date),
      );
      if (response.success && response.data != null) {
        _searchResults = response.data!;
      }
    }
    _isSearching = false;
    notifyListeners();
  }

  /// Re-runs the active filter when messages change while searching.
  Future<void> recomputeSearch() async {
    final filter = _activeFilter;
    if (filter == null || !filter.isActive) return;
    await _runSearch(filter);
  }

  DateTime? _dayStart(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

  DateTime? _dayEnd(DateTime? d) => d == null
      ? null
      : DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// Offline-first local matcher shared with realtime refresh.
  List<ChatMessage> _localSearchResults(ChatSearchFilter filter) {
    final q = filter.query.trim().toLowerCase();
    return _messages.where((m) {
      if (m.isDeleted || m.isDeletedForEveryone) return false;
      if (m.isSystem) return false;
      if (!_matchesCategory(m, filter.category)) return false;
      if (filter.hasDate && !ChatTimeFormat.isSameDay(m.timestamp, filter.date!)) {
        return false;
      }
      if (q.isNotEmpty && !_messageContains(m, q)) return false;
      return true;
    }).toList();
  }

  bool _matchesCategory(ChatMessage m, ChatSearchCategory category) {
    switch (category) {
      case ChatSearchCategory.all:
        return true;
      case ChatSearchCategory.messages:
        return m.type == MessageContentType.text ||
            m.type == MessageContentType.emoji;
      case ChatSearchCategory.date:
        return true;
      case ChatSearchCategory.pdf:
        return m.type == MessageContentType.pdf ||
            m.attachments.any((a) =>
                a.type == MessageContentType.pdf ||
                (a.fileExtension == 'pdf' && a.mimeType?.contains('pdf') == true));
      case ChatSearchCategory.media:
        return m.type == MessageContentType.image ||
            m.type == MessageContentType.video ||
            m.type == MessageContentType.gif;
      case ChatSearchCategory.assignments:
        return m.type == MessageContentType.assignment;
      case ChatSearchCategory.attendance:
        return m.type == MessageContentType.attendanceReport;
      case ChatSearchCategory.links:
        return m.text.contains(_linkPattern);
      case ChatSearchCategory.replies:
        return m.replyTo != null;
    }
  }

  bool _messageContains(ChatMessage m, String q) {
    if (m.text.toLowerCase().contains(q)) return true;
    if (m.senderName.toLowerCase().contains(q)) return true;
    final reply = m.replyTo;
    if (reply != null) {
      if (reply.text.toLowerCase().contains(q)) return true;
      if (reply.senderName.toLowerCase().contains(q)) return true;
    }
    for (final a in m.attachments) {
      if (a.name.toLowerCase().contains(q)) return true;
      if ((a.caption ?? '').toLowerCase().contains(q)) return true;
    }
    return false;
  }

  void clearSearch() {
    _activeFilter = null;
    _searchQuery = '';
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }

  /// Paginates older messages until [messageId] is present locally.
  /// Used by search navigation for results that live beyond the loaded window.
  Future<bool> ensureMessageLoaded(String messageId) async {
    if (_messages.any((m) => m.id == messageId)) return true;
    var guard = 0;
    while (_hasMore && _oldestLoaded != null && guard < 40) {
      final before = _oldestLoaded;
      await loadOlder();
      if (_oldestLoaded == before) break;
      if (_messages.any((m) => m.id == messageId)) return true;
      guard++;
    }
    return _messages.any((m) => m.id == messageId);
  }

  /// Media/files/links gallery feed (for View Profile > Media).
  Future<List<ChatMessage>> fetchMedia(String kind) async {
    final local = _messages.where((m) {
      if (m.isDeletedForEveryone) return false;
      switch (kind) {
        case 'media':
          return m.type == MessageContentType.image ||
              m.type == MessageContentType.video ||
              m.type == MessageContentType.gif;
        case 'documents':
          return m.type.isFile || m.type == MessageContentType.pdf;
        case 'links':
          return m.text.contains(RegExp(r'https?://', caseSensitive: false));
        default:
          return true;
      }
    }).toList();

    if (_isBackendAvailable) {
      final response = await repository.fetchMedia(conversationId: conversation.id, kind: kind);
      if (response.success && response.data != null) {
        return response.data!;
      }
    }
    return local;
  }

  // ── Voice notes ───────────────────────────────────────────────────────

  /// Called by the voice recorder UI when a recording finishes.
  Future<void> sendVoiceNote(String filePath, {int? durationMs}) async {
    final attachment = ChatAttachment(
      id: 'att_${DateTime.now().microsecondsSinceEpoch}',
      name: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      type: MessageContentType.voice,
      mimeType: 'audio/m4a',
      localPath: filePath,
      sizeBytes: File(filePath).existsSync() ? File(filePath).lengthSync() : 0,
      durationMs: durationMs,
    );
    await sendAttachment(attachment);
  }

  // ── Realtime ──────────────────────────────────────────────────────────

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (event.conversationId != conversation.id) return;

    switch (event.kind) {
      case 'message_new':
        _onIncomingMessage(event);
      case 'receipt':
      case 'read':
      case 'delivered':
        _onReceipt(event);
      case 'edited':
        _onEdited(event);
      case 'deleted':
        _onDeleted(event);
      case 'pinned':
        notifyListeners();
      default:
        break;
    }
  }

  void _onIncomingMessage(ChatRealtimeEvent event) {
    final data = event.data;
    final messageId = data['message_id']?.toString();
    if (messageId == null) return;
    if (_messages.any((m) => m.id == messageId)) return;

    final msg = ChatMessage.fromJson(data);
    if (msg.direction == MessageDirection.outgoing) return;

    _messages.add(msg);
    _persist();
    cache.upsertConversation(conversation.updateFromMessage(msg));
    onIncomingMessage?.call();

    // Auto read receipt for messages received while the screen is open.
    _markRead([msg.id]);
    ChatRealtimeService.instance.sendReadReceipt(conversation.id, [msg.id]);
    notifyListeners();
    recomputeSearch();
  }

  void _onReceipt(ChatRealtimeEvent event) {
    final data = event.data;
    // Determine status from the event kind first, then from data['status'].
    final statusStr = event.kind == 'read'
        ? 'read'
        : event.kind == 'delivered'
            ? 'delivered'
            : data['status']?.toString() ?? '';
    if (statusStr.isEmpty) return;

    final newStatus = statusStr == 'read'
        ? MessageStatus.read
        : statusStr == 'delivered'
            ? MessageStatus.delivered
            : null;
    if (newStatus == null) return;

    // Handle both single message_id and bulk message_ids array.
    final ids = <String>[];
    final singleId = data['message_id']?.toString();
    if (singleId != null) ids.add(singleId);
    final multiIds = data['message_ids'];
    if (multiIds is List) {
      for (final id in multiIds) {
        if (id != null && !ids.contains(id.toString())) {
          ids.add(id.toString());
        }
      }
    }
    if (ids.isEmpty) return;

    var changed = false;
    for (final id in ids) {
      final index = _messages.indexWhere((m) => m.id == id);
      if (index == -1) continue;
      final current = _messages[index].status;
      if (newStatus == MessageStatus.read && current != MessageStatus.read) {
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.read,
          readAt: DateTime.now(),
        );
        changed = true;
      } else if (newStatus == MessageStatus.delivered &&
          current != MessageStatus.read &&
          current != MessageStatus.delivered) {
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.delivered,
          deliveredAt: DateTime.now(),
        );
        changed = true;
      }
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  void _onEdited(ChatRealtimeEvent event) {
    final data = event.data;
    final messageId = data['message_id']?.toString();
    if (messageId == null) return;
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final updated = _messages[index].copyWith(
      text: data['text']?.toString() ?? _messages[index].text,
      isEdited: true,
      editedAt: DateTime.tryParse(data['edited_at']?.toString() ?? '') ?? DateTime.now(),
    );
    _replaceMessage(messageId, updated);
    recomputeSearch();
  }

  void _onDeleted(ChatRealtimeEvent event) {
    final data = event.data;
    final messageId = data['message_id']?.toString();
    if (messageId == null) return;
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final forEveryone = data['for_everyone'] == true;
    final updated = _messages[index].copyWith(
      isDeletedForEveryone: forEveryone ? true : _messages[index].isDeletedForEveryone,
      isDeletedForMe: !forEveryone ? true : _messages[index].isDeletedForMe,
      text: forEveryone ? '' : _messages[index].text,
    );
    _replaceMessage(messageId, updated);
    recomputeSearch();
  }

  void requestReadReceipts() {
    _autoMarkRead();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _realtimeSub?.cancel();
    for (final task in _uploads.values) {
      task.dispose();
    }
    _uploads.clear();
    super.dispose();
  }
}
