import 'package:flutter/foundation.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/faculty_message.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/messaging_repository.dart';

class MessagingController extends ChangeNotifier {
  final MessagingRepository _repository;

  List<FacultyMessage> _messages = [];
  List<MessageThread> _threads = [];
  List<MessageTemplate> _templates = [];
  bool _isLoading = false;
  String? _error;
  MessageType? _selectedType;
  String _searchQuery = '';
  MessageFilter _filter = const MessageFilter();

  int _currentPage = 1;
  static const int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool _isSending = false;
  bool _isExporting = false;

  List<FacultyMessage> _scheduledMessages = [];

  MessagingController(this._repository);

  List<FacultyMessage> get messages => _messages;
  List<MessageThread> get threads => _threads;
  List<MessageTemplate> get templates => _templates;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  MessageType? get selectedType => _selectedType;
  String get searchQuery => _searchQuery;
  bool get isSending => _isSending;
  bool get isExporting => _isExporting;
  MessageFilter get filter => _filter;
  List<FacultyMessage> get scheduledMessages => _scheduledMessages;

  List<FacultyMessage> get unreadMessages =>
      _messages.where((m) => !m.isRead).toList();

  int get unreadCount => unreadMessages.length;

  Future<void> loadMessages({
    MessageType? type,
    String? query,
    MessageFilter? filter,
    bool sentOnly = false,
  }) async {
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    _hasMore = true;
    if (type != null) _selectedType = type;
    if (query != null) _searchQuery = query;
    if (filter != null) _filter = filter;
    notifyListeners();

    try {
      _messages = await _repository.fetchMessages(
        type: _selectedType,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        filter: _filter,
        page: 1,
        pageSize: _pageSize,
        sentOnly: sentOnly,
      );
      _hasMore = _messages.length >= _pageSize;
    } catch (e) {
      _error = 'Failed to load messages: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreMessages({bool sentOnly = false}) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final moreMessages = await _repository.fetchMessages(
        type: _selectedType,
        query: _searchQuery.isNotEmpty ? _searchQuery : null,
        filter: _filter,
        page: _currentPage,
        pageSize: _pageSize,
        sentOnly: sentOnly,
      );
      if (moreMessages.isEmpty) {
        _hasMore = false;
      } else {
        _messages.addAll(moreMessages);
        _hasMore = moreMessages.length >= _pageSize;
      }
    } catch (e) {
      _currentPage--;
      _error = 'Failed to load more messages: $e';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadThreads() async {
    try {
      _threads = await _repository.fetchThreads();
    } catch (e) {
      _error = 'Failed to load threads: $e';
    }
    notifyListeners();
  }

  Future<void> loadTemplates() async {
    _templates = _repository.getTemplates();
    notifyListeners();
  }

  Future<void> loadScheduledMessages() async {
    try {
      _scheduledMessages = await _repository.fetchScheduledMessages();
    } catch (e) {
      _error = 'Failed to load scheduled messages: $e';
    }
    notifyListeners();
  }

  Future<bool> sendMessage({
    required String recipientId,
    required String subject,
    required String body,
    MessageType type = MessageType.individual,
    MessagePriority priority = MessagePriority.normal,
    MessageCategory category = MessageCategory.text,
    List<String>? attachments,
    DateTime? scheduledAt,
    String? courseCode,
    String? section,
    RecipientGroup recipientGroup = RecipientGroup.individual,
    List<String>? recipientIds,
    String? notes,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final newMessage = await _repository.sendMessage(
        recipientId: recipientId,
        subject: subject,
        body: body,
        type: type,
        priority: priority,
        category: category,
        attachments: attachments,
        scheduledAt: scheduledAt,
        courseCode: courseCode,
        section: section,
        recipientGroup: recipientGroup,
        recipientIds: recipientIds,
        notes: notes,
      );
      _messages.insert(0, newMessage);
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to send message: $e';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await _repository.markAsRead(messageId);
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.read,
          readAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to mark message as read: $e';
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _repository.deleteMessage(messageId);
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete message: $e';
      notifyListeners();
    }
  }

  Future<void> cancelScheduledMessage(String messageId) async {
    try {
      await _repository.cancelScheduledMessage(messageId);
      _scheduledMessages.removeWhere((m) => m.id == messageId);
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to cancel scheduled message: $e';
      notifyListeners();
    }
  }

  void setTypeFilter(MessageType? type) {
    if (_selectedType == type) {
      _selectedType = null;
    } else {
      _selectedType = type;
    }
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  void setFilter(MessageFilter filter) {
    _filter = filter;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  void clearFilters() {
    _selectedType = null;
    _searchQuery = '';
    _filter = const MessageFilter();
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadMessages();
    await loadThreads();
    await loadTemplates();
  }
}
