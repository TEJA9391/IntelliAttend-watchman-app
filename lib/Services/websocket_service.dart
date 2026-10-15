import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:intelli_attend_faculty/Core/Models/websocket_event.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocket? _ws;
  bool _isClosed = false;
  String? _sessionId;
  String? _facultyEmail;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectDelaySec = 1;
  static const int _maxReconnectDelay = 30;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  final StreamController<WebSocketEvent> _eventController =
      StreamController<WebSocketEvent>.broadcast();
  final StreamController<WsConnectionState> _connectionStateController =
      StreamController<WsConnectionState>.broadcast();

  Stream<WebSocketEvent> get events => _eventController.stream;
  Stream<WsConnectionState> get connectionState =>
      _connectionStateController.stream;
  WsConnectionState get currentState => _currentState;
  bool get isConnected => _currentState == WsConnectionState.connected;
  String? get sessionId => _sessionId;
  String? get facultyEmail => _facultyEmail;

  WsConnectionState _currentState = WsConnectionState.disconnected;

  void _setState(WsConnectionState state) {
    _currentState = state;
    if (!_isClosed) {
      _connectionStateController.add(state);
    }
  }

  void connectAndJoinRoom({
    required String sessionId,
    String? facultyEmail,
  }) {
    if (_currentState == WsConnectionState.connected &&
        _sessionId == sessionId) {
      debugPrint('[WS] Already connected to session $sessionId');
      return;
    }

    _isClosed = false;
    _sessionId = sessionId;
    _facultyEmail = facultyEmail ?? FacultyService.canonicalId;
    _reconnectDelaySec = 1;
    _connect();
  }

  void _connect() {
    if (_isClosed) return;

    _setState(
        _reconnectDelaySec > 1 ? WsConnectionState.reconnecting : WsConnectionState.connecting);

    _doConnect().then((_) {}).catchError((e) {
      debugPrint('[WS] Connection failed: $e');
      _handleDisconnect();
    });
  }

  Future<void> _doConnect() async {
    await _ws?.close();
    _ws = null;

    String wsUrl;
    try {
      wsUrl = await _buildWsUrl();
    } catch (e) {
      debugPrint('[WS] URL build failed: $e');
      _handleDisconnect();
      return;
    }

    debugPrint('[WS] Connecting: $wsUrl');
    final ws = await WebSocket.connect(wsUrl);
    if (_isClosed) {
      await ws.close();
      return;
    }

    _ws = ws;
    _reconnectDelaySec = 1;
    _setState(WsConnectionState.connected);

    _startHeartbeat();

    ws.listen(
      _onMessage,
      onError: (error) {
        debugPrint('[WS] Error: $error');
        _handleDisconnect();
      },
      onDone: () {
        debugPrint('[WS] Connection closed');
        _handleDisconnect();
      },
      cancelOnError: false,
    );
  }

  Future<String> _buildWsUrl() async {
    String? firebaseToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        firebaseToken = await user.getIdToken();
      }
    } catch (_) {}

    final apiBaseUrl = ApiClient().baseUrl;
    final baseUrl = apiBaseUrl.replaceFirst('https://', 'wss://');
    debugPrint('[WS] Using baseUrl=$baseUrl (from ApiClient.baseUrl=$apiBaseUrl)');
    final tokenParam = firebaseToken != null
        ? 'token=$firebaseToken&token_type=firebase'
        : '';

    if (_sessionId != null && _sessionId!.isNotEmpty) {
      return '$baseUrl/ws?session_id=$_sessionId&$tokenParam';
    }
    return '$baseUrl/ws?$tokenParam';
  }

  void _onMessage(dynamic message) {
    if (message == 'pong') return;

    try {
      final Map<String, dynamic> data = jsonDecode(message);
      final eventType = data['type']?.toString() ?? data['event']?.toString() ?? '';

      if (eventType == 'heartbeat' || eventType == 'pong') return;

      final event = WebSocketEvent.fromJson(data);
      _eventController.add(event);
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  void _handleDisconnect() {
    if (_isClosed) return;

    _ws = null;
    _heartbeatTimer?.cancel();
    _setState(WsConnectionState.disconnected);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySec), () {
      _connect();
    });

    _reconnectDelaySec =
        (_reconnectDelaySec * 2).clamp(1, _maxReconnectDelay);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_ws?.readyState == WebSocket.open) {
        _ws!.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void sendJson(Map<String, dynamic> message) {
    if (_ws?.readyState == WebSocket.open) {
      _ws!.add(jsonEncode(message));
      debugPrint('[WS] Sent: $message');
    } else {
      debugPrint('[WS] Cannot send: not connected');
    }
  }

  void sendMarkAttendance({
    required String sessionId,
    required String studentId,
    String? facultyEmail,
  }) {
    sendJson({
      'type': 'mark_attendance',
      'session_id': sessionId,
      'student_id': studentId,
      'faculty_email': facultyEmail ?? _facultyEmail ?? FacultyService.canonicalId,
    });
  }

  // ── Messaging / Chat helpers ─────────────────────────────────────────

  /// Sends a chat message over the socket. Falls back silently when the socket
  /// is not open; the outbox (MessagingRepository) retries via REST.
  void sendChatMessage({
    required String conversationId,
    required String messageId,
    required String text,
    required String messageType,
    List<Map<String, dynamic>>? attachments,
    String? replyToMessageId,
    String? localId,
  }) {
    sendJson({
      'type': 'chat_message',
      'conversation_id': conversationId,
      'message_id': messageId,
      'local_id': localId,
      'text': text,
      'message_type': messageType,
      'attachments': attachments ?? const [],
      'reply_to_message_id': replyToMessageId,
      'sender_id': _facultyEmail ?? FacultyService.canonicalId,
    });
  }

  /// Broadcasts a typing indicator for a conversation.
  void sendTyping({required String conversationId, bool isTyping = true}) {
    sendJson({
      'type': 'typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
      'sender_id': _facultyEmail ?? FacultyService.canonicalId,
    });
  }

  /// Sends a read receipt for one or more messages.
  void sendReadReceipt({
    required String conversationId,
    List<String>? messageIds,
    String? messageId,
  }) {
    sendJson({
      'type': 'message_read',
      'conversation_id': conversationId,
      'message_ids': messageIds ?? (messageId == null ? const [] : [messageId]),
      'reader_id': _facultyEmail ?? FacultyService.canonicalId,
    });
  }

  /// Sends a presence update (online + last seen).
  void sendPresence({bool isOnline = true}) {
    sendJson({
      'type': 'presence_update',
      'sender_id': _facultyEmail ?? FacultyService.canonicalId,
      'is_online': isOnline,
    });
  }

  /// Broadcasts voice-note recording state for the given peer.
  void sendRecording({required String peerId, bool isRecording = true}) {
    sendJson({
      'type': 'presence_update',
      'sender_id': _facultyEmail ?? FacultyService.canonicalId,
      'is_online': true,
      'is_recording': isRecording,
    });
  }

  /// Sends a call signalling event (ringing, accept, reject, end, mute...).
  void sendCallSignal({
    required String conversationId,
    required String callId,
    required String action,
    Map<String, dynamic>? payload,
  }) {
    sendJson({
      'type': 'call_event',
      'conversation_id': conversationId,
      'call_id': callId,
      'action': action,
      'sender_id': _facultyEmail ?? FacultyService.canonicalId,
      if (payload != null) 'payload': payload,
    });
  }

  /// Opens a lightweight messaging-only socket (no attendance session).
  /// Idempotent: reuses the current socket when already connected.
  void connectMessaging({String? facultyEmail}) {
    if (_currentState == WsConnectionState.connected && _sessionId == null) {
      return;
    }
    _isClosed = false;
    _sessionId = null;
    _facultyEmail = facultyEmail ?? FacultyService.canonicalId;
    _reconnectDelaySec = 1;
    _connect();
  }

  void disconnect() {
    _isClosed = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _ws?.close();
    _ws = null;
    _sessionId = null;
    _facultyEmail = null;
    _setState(WsConnectionState.disconnected);
    _reconnectDelaySec = 1;
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _connectionStateController.close();
  }
}
