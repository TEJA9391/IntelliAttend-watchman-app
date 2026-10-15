import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';

/// Result wrapper for every repository call so controllers can distinguish
/// a live network response from a cached/offline one without throwing.
class MessagingApiResponse<T> {
  final T? data;
  final String? error;
  final bool fromCache;
  final bool success;

  const MessagingApiResponse._({
    this.data,
    this.error,
    this.fromCache = false,
    this.success = true,
  });

  const MessagingApiResponse.success(T data, {bool fromCache = false})
      : this._(data: data, fromCache: fromCache, success: true);

  const MessagingApiResponse.failure(String error, {bool fromCache = false})
      : this._(error: error, fromCache: fromCache, success: false);
}

/// Repository for the Messaging / Chat feature.
///
/// Every method performs a REAL call to the IntelliAttend backend through the
/// shared [ApiClient] (Firebase-token auth + device headers are attached by the
/// existing interceptors). When the backend endpoints are not yet deployed the
/// call fails gracefully and controllers fall back to the local cache
/// ([MessageCacheService]) seeded by [ChatDemoData].
class MessagingRepository {
  final ApiClient _apiClient;
  bool _backendCheckDone = false;
  bool _backendAvailable = false;

  MessagingRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Dio get _dio => _apiClient.dio;

  String? get currentFacultyId => FacultyService.canonicalId;
  String get currentFacultyName =>
      FacultyService.profile.value?.name ?? 'Faculty';

  /// Whether the messaging backend endpoints respond. Checked once per app
  /// session, cached afterwards.
  Future<bool> get isBackendAvailable async {
    if (_backendCheckDone) return _backendAvailable;
    try {
      final res = await _dio.get('/api/v1/messaging/health',
          options: Options(receiveTimeout: const Duration(seconds: 6)));
      _backendAvailable = res.statusCode == 200;
    } catch (_) {
      _backendAvailable = false;
    }
    _backendCheckDone = true;
    return _backendAvailable;
  }

  bool _isUnavailable(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.response?.statusCode == 404 ||
        e.response?.statusCode == 501;
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['detail']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString() ??
          e.message ??
          'Request failed';
    }
    if (e.response?.statusCode == 401) return 'Session expired. Please sign in again.';
    if (e.type == DioExceptionType.connectionError) return 'You are offline. Check your connection.';
    return e.message ?? 'Request failed';
  }

  // ── Conversations ─────────────────────────────────────────────────────

  /// Fetches the list of conversations. Supports search & a cursor for
  /// infinite scroll. When the backend is unavailable a [ChatNotAvailable]
  /// is returned so the caller can hydrate from the demo catalog.
  Future<MessagingApiResponse<List<ChatConversation>>> fetchConversations({
    String? query,
    String? cursor,
    int limit = 30,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/messaging/conversations',
        queryParameters: {
          if (query != null && query.isNotEmpty) 'query': query,
          if (cursor != null) 'cursor': cursor,
          'limit': limit,
        },
      );
      final list = res.data is List
          ? res.data as List
          : (res.data is Map ? (res.data['conversations'] ?? []) : const []);
      final convs = (list as List)
          .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return MessagingApiResponse.success(convs);
    } on DioException catch (e) {
      debugPrint('[Messaging] fetchConversations failed: $e');
      return MessagingApiResponse.failure(
        _isUnavailable(e)
            ? 'Messaging endpoints unavailable on backend'
            : _extractError(e),
      );
    } catch (e) {
      return MessagingApiResponse.failure(e.toString());
    }
  }

  /// Fetches a single conversation (used when opening from a notification).
  Future<MessagingApiResponse<ChatConversation?>> fetchConversation(String conversationId) async {
    try {
      final res = await _dio.get('/api/v1/messaging/conversations/$conversationId');
      final json = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      if (json == null) {
        return const MessagingApiResponse.failure('Conversation not found');
      }
      return MessagingApiResponse.success(ChatConversation.fromJson(json));
    } on DioException catch (e) {
      return MessagingApiResponse.failure(
        _isUnavailable(e) ? 'Messaging endpoints unavailable on backend' : _extractError(e),
      );
    }
  }

  // ── Messages (paginated) ──────────────────────────────────────────────

  /// Loads older messages for a conversation (infinite scroll / lazy loading).
  /// `before` returns messages older than that timestamp; `limit` caps page size.
  Future<MessagingApiResponse<List<ChatMessage>>> fetchMessages({
    required String conversationId,
    DateTime? before,
    int limit = 25,
    String? filter,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/messaging/conversations/$conversationId/messages',
        queryParameters: {
          if (before != null) 'before': before.toIso8601String(),
          'limit': limit,
          if (filter != null && filter.isNotEmpty) 'filter': filter,
        },
      );
      final list = res.data is List
          ? res.data as List
          : (res.data is Map ? (res.data['messages'] ?? []) : const []);
      final msgs = (list as List)
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return MessagingApiResponse.success(msgs);
    } on DioException catch (e) {
      debugPrint('[Messaging] fetchMessages failed: $e');
      return MessagingApiResponse.failure(
        _isUnavailable(e) ? 'Messaging endpoints unavailable on backend' : _extractError(e),
      );
    } catch (e) {
      return MessagingApiResponse.failure(e.toString());
    }
  }

  /// Sends a text/emoji message. Returns the server-persisted message.
  Future<MessagingApiResponse<ChatMessage?>> sendMessage({
    required String conversationId,
    required ChatMessage message,
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/messaging/conversations/$conversationId/messages',
        data: {
          'message_id': message.id,
          'local_id': message.localId,
          'type': message.type.toJson(),
          'text': message.text,
          'attachments': message.attachments.map((a) => a.toJson()).toList(),
          'reply_to_message_id': message.replyTo?.messageId,
          'sender_id': currentFacultyId,
          'timestamp': message.timestamp.toIso8601String(),
        },
      );
      if (res.data is Map) {
        final json = Map<String, dynamic>.from(res.data as Map);
        final serverMsg = json.containsKey('message')
            ? Map<String, dynamic>.from(json['message'] as Map)
            : json;
        return MessagingApiResponse.success(ChatMessage.fromJson(serverMsg));
      }
      return MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Uploads an attachment for a conversation with progress reporting.
  /// `cancelToken` lets the UI cancel an in-flight upload.
  Future<MessagingApiResponse<ChatAttachment?>> uploadAttachment({
    required String conversationId,
    required File file,
    required String fileName,
    required String mimeType,
    void Function(double)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });
      final res = await _dio.post(
        '/api/v1/messaging/conversations/$conversationId/messages/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 10),
        ),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );
      if (res.data is Map) {
        final json = Map<String, dynamic>.from(res.data as Map);
        final attachmentJson = json.containsKey('attachment')
            ? Map<String, dynamic>.from(json['attachment'] as Map)
            : json;
        return MessagingApiResponse.success(ChatAttachment.fromJson(attachmentJson));
      }
      return const MessagingApiResponse.failure('Upload returned no attachment');
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return const MessagingApiResponse.failure('Upload cancelled');
      }
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Marks a conversation as read (sends read receipts for peer messages).
  Future<MessagingApiResponse<void>> markConversationRead(String conversationId) async {
    try {
      await _dio.post('/api/v1/messaging/conversations/$conversationId/read');
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  // ── Message mutations ─────────────────────────────────────────────────

  Future<MessagingApiResponse<ChatMessage?>> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    try {
      final res = await _dio.patch(
        '/api/v1/messaging/conversations/$conversationId/messages/$messageId',
        data: {'text': newText, 'action': 'edit'},
      );
      if (res.data is Map) {
        final json = Map<String, dynamic>.from(res.data as Map);
        return MessagingApiResponse.success(
            ChatMessage.fromJson(json.containsKey('message') ? Map<String, dynamic>.from(json['message'] as Map) : json));
      }
      return const MessagingApiResponse.failure('Edit failed');
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<void>> deleteMessage({
    required String conversationId,
    required String messageId,
    bool forEveryone = false,
  }) async {
    try {
      await _dio.delete(
        '/api/v1/messaging/conversations/$conversationId/messages/$messageId',
        data: {'for_everyone': forEveryone},
      );
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<void>> pinMessage({
    required String conversationId,
    required String messageId,
    bool pin = true,
  }) async {
    try {
      await _dio.post(
        '/api/v1/messaging/conversations/$conversationId/messages/$messageId/pin',
        data: {'pin': pin},
      );
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<void>> starMessage({
    required String conversationId,
    required String messageId,
    bool star = true,
  }) async {
    try {
      await _dio.post(
        '/api/v1/messaging/conversations/$conversationId/messages/$messageId/star',
        data: {'star': star},
      );
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Adds/removes an emoji reaction on a message.
  Future<MessagingApiResponse<void>> reactMessage({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _dio.post(
        '/api/v1/messaging/conversations/$conversationId/messages/$messageId/reactions',
        data: {'emoji': emoji},
      );
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Forwards a message to one or more target conversations.
  Future<MessagingApiResponse<void>> forwardMessage({
    required String sourceConversationId,
    required String messageId,
    required List<String> targetConversationIds,
  }) async {
    try {
      await _dio.post(
        '/api/v1/messaging/conversations/$sourceConversationId/messages/$messageId/forward',
        data: {'target_conversation_ids': targetConversationIds},
      );
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Translates a message into the given locale (backend LLM endpoint).
  Future<MessagingApiResponse<String>> translateMessage({
    required String conversationId,
    required String messageId,
    String targetLanguage = 'en',
  }) async {
    try {
      final res = await _dio.post(
        '/api/v1/messaging/conversations/$conversationId/messages/$messageId/translate',
        data: {'target_language': targetLanguage},
      );
      if (res.data is Map) {
        final translated = (res.data as Map)['translated_text']?.toString();
        if (translated != null) return MessagingApiResponse.success(translated);
      }
      return const MessagingApiResponse.failure('Translation failed');
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Searches messages in a conversation (realtime filtering on the server).
  ///
  /// [filter] accepts `all | messages | pdf | media | assignment |
  /// attendance_report | links | replies`; [dateFrom]/[dateTo] restrict the
  /// result set to a window (ISO-8601).
  Future<MessagingApiResponse<List<ChatMessage>>> searchMessages({
    required String conversationId,
    required String query,
    String? filter, // all | messages | pdf | media | assignment | attendance_report | links | replies
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/messaging/conversations/$conversationId/search',
        queryParameters: {
          'query': query,
          if (filter != null && filter.isNotEmpty) 'filter': filter,
          if (dateFrom != null) 'date_from': dateFrom.toIso8601String(),
          if (dateTo != null) 'date_to': dateTo.toIso8601String(),
        },
      );
      final list = res.data is List
          ? res.data as List
          : (res.data is Map ? (res.data['results'] ?? []) : const []);
      final msgs = (list as List)
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return MessagingApiResponse.success(msgs);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Media/files/links summary for the "View Profile > Media" gallery.
  Future<MessagingApiResponse<List<ChatMessage>>> fetchMedia({
    required String conversationId,
    required String kind, // media | documents | links
  }) async {
    try {
      final res = await _dio.get(
        '/api/v1/messaging/conversations/$conversationId/media',
        queryParameters: {'kind': kind},
      );
      final list = res.data is List
          ? res.data as List
          : (res.data is Map ? (res.data['items'] ?? []) : const []);
      final msgs = (list as List)
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return MessagingApiResponse.success(msgs);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  // ── Conversation settings ─────────────────────────────────────────────

  Future<MessagingApiResponse<void>> setMuted(String conversationId, bool muted) async {
    try {
      await _dio.post('/api/v1/messaging/conversations/$conversationId/mute',
          data: {'muted': muted});
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<void>> setBlocked(String conversationId, bool blocked) async {
    try {
      await _dio.post('/api/v1/messaging/conversations/$conversationId/block',
          data: {'blocked': blocked});
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<void>> clearConversation(String conversationId) async {
    try {
      await _dio.delete('/api/v1/messaging/conversations/$conversationId/messages');
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<void>> deleteConversation(String conversationId) async {
    try {
      await _dio.delete('/api/v1/messaging/conversations/$conversationId');
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<void>> reportConversation(String conversationId, String reason) async {
    try {
      await _dio.post('/api/v1/messaging/conversations/$conversationId/report',
          data: {'reason': reason});
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Exports the conversation (PDF/CSV). Returns a signed download URL when ready.
  Future<MessagingApiResponse<String?>> exportConversation(String conversationId, String format) async {
    try {
      final res = await _dio.post(
        '/api/v1/messaging/conversations/$conversationId/export',
        data: {'format': format},
      );
      if (res.data is Map) {
        final url = (res.data as Map)['url']?.toString();
        return MessagingApiResponse.success(url);
      }
      return const MessagingApiResponse.failure('Export failed');
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  // ── Contacts ──────────────────────────────────────────────────────────

  /// Contacts catalog used by Forward & the chat list (roster from backend).
  Future<MessagingApiResponse<List<StudentContact>>> fetchContacts({String? query}) async {
    try {
      final res = await _dio.get('/api/v1/messaging/contacts',
          queryParameters: {if (query != null && query.isNotEmpty) 'query': query});
      final list = res.data is List
          ? res.data as List
          : (res.data is Map ? (res.data['contacts'] ?? []) : const []);
      final contacts = (list as List)
          .map((e) => StudentContact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return MessagingApiResponse.success(contacts);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  // ── Calls ─────────────────────────────────────────────────────────────

  /// Initiates an audio/video call. Returns the created call record.
  Future<MessagingApiResponse<ChatCall?>> initiateCall({
    required String peerId,
    required CallType type,
  }) async {
    try {
      final res = await _dio.post('/api/v1/messaging/calls', data: {
        'peer_id': peerId,
        'type': type.name,
        'direction': 'outgoing',
      });
      if (res.data is Map) {
        final json = Map<String, dynamic>.from(res.data as Map);
        return MessagingApiResponse.success(
            ChatCall.fromJson(json.containsKey('call') ? Map<String, dynamic>.from(json['call'] as Map) : json));
      }
      return const MessagingApiResponse.failure('Call initiation failed');
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<void>> endCall(String callId, int durationSeconds) async {
    try {
      await _dio.post('/api/v1/messaging/calls/$callId/end',
          data: {'duration_seconds': durationSeconds});
      return const MessagingApiResponse.success(null);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  Future<MessagingApiResponse<List<ChatCall>>> fetchCallHistory(String peerId) async {
    try {
      final res = await _dio.get('/api/v1/messaging/calls',
          queryParameters: {'peer_id': peerId});
      final list = res.data is List
          ? res.data as List
          : (res.data is Map ? (res.data['calls'] ?? []) : const []);
      final calls = (list as List)
          .map((e) => ChatCall.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return MessagingApiResponse.success(calls);
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  // ── Presence ──────────────────────────────────────────────────────────

  Future<MessagingApiResponse<StudentContact?>> fetchPresence(String peerId) async {
    try {
      final res = await _dio.get('/api/v1/messaging/presence/$peerId');
      if (res.data is Map) {
        final json = Map<String, dynamic>.from(res.data as Map);
        return MessagingApiResponse.success(StudentContact.fromJson(
            json.containsKey('contact') ? Map<String, dynamic>.from(json['contact'] as Map) : json));
      }
      return const MessagingApiResponse.failure('Presence not found');
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }

  /// Creates (or returns) a conversation with a contact for new-chat/forward.
  Future<MessagingApiResponse<ChatConversation?>> openConversationWith(String peerId) async {
    try {
      final res = await _dio.post('/api/v1/messaging/conversations', data: {
        'peer_id': peerId,
      });
      if (res.data is Map) {
        final json = Map<String, dynamic>.from(res.data as Map);
        return MessagingApiResponse.success(ChatConversation.fromJson(json));
      }
      return const MessagingApiResponse.failure('Conversation open failed');
    } on DioException catch (e) {
      return MessagingApiResponse.failure(_extractError(e));
    }
  }
}
