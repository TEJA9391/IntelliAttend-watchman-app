import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:intelli_attend_faculty/Core/Models/websocket_event.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/websocket_service.dart';

/// Realtime messaging bridge.
///
/// Subscribes to the shared [WebSocketService] event stream and re-broadcasts
/// chat events to active controllers through typed streams. Also maintains
/// presence and typing state for the chat header + list UI.
class ChatRealtimeService extends ChangeNotifier with WidgetsBindingObserver {
  ChatRealtimeService._internal() {
    _subscribe();
  }

  static final ChatRealtimeService instance = ChatRealtimeService._internal();

  final WebSocketService _ws = WebSocketService();

  final StreamController<ChatRealtimeEvent> _eventController =
      StreamController<ChatRealtimeEvent>.broadcast();
  Stream<ChatRealtimeEvent> get events => _eventController.stream;

  /// conversationId -> whether the peer is currently typing.
  final ValueNotifier<Map<String, bool>> typingStatus =
      ValueNotifier<Map<String, bool>>({});

  /// peerId -> whether the peer is currently recording a voice note.
  final ValueNotifier<Map<String, bool>> recordingStatus =
      ValueNotifier<Map<String, bool>>({});

  /// peerId -> presence snapshot.
  final ValueNotifier<Map<String, PresenceSnapshot>> presence =
      ValueNotifier<Map<String, PresenceSnapshot>>({});

  /// Latest incoming call (for full-screen incoming-call UI).
  final ValueNotifier<ChatCall?> incomingCall = ValueNotifier<ChatCall?>(null);

  final ValueNotifier<WsConnectionState> connectionState =
      ValueNotifier<WsConnectionState>(WsConnectionState.disconnected);

  bool _disposed = false;
  bool _lifecycleObserved = false;
  bool _backgrounded = false;
  StreamSubscription<WebSocketEvent>? _sub;
  StreamSubscription<WsConnectionState>? _connSub;

  void _subscribe() {
    _sub = _ws.events.listen(_onEvent);
    _connSub = _ws.connectionState.listen((state) {
      if (!_disposed) {
        connectionState.value = state;
        notifyListeners();
      }
    });
  }

  void _observeLifecycle() {
    if (_lifecycleObserved || _disposed) return;
    _lifecycleObserved = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Tell peers we went offline instantly (no polling).
        _backgrounded = true;
        _ws.sendPresence(isOnline: false);
      case AppLifecycleState.resumed:
        if (_backgrounded) {
          _backgrounded = false;
          _ws.connectMessaging(facultyEmail: FacultyService.canonicalId);
          _ws.sendPresence(isOnline: true);
        }
      default:
        break;
    }
  }

  /// Connects the messaging socket (idempotent) and broadcasts presence.
  void connect() {
    _observeLifecycle();
    _ws.connectMessaging(facultyEmail: FacultyService.canonicalId);
    _ws.sendPresence(isOnline: true);
  }

  void _onEvent(WebSocketEvent event) {
    switch (event.type) {
      case WsEventType.messageNew:
        _eventController.add(ChatRealtimeEvent.messageNew(event.data));
      case WsEventType.messageAck:
        _eventController.add(ChatRealtimeEvent.messageAck(event.data));
      case WsEventType.messageRead:
        _eventController.add(ChatRealtimeEvent.messageRead(event.data));
      case WsEventType.messageDelivered:
        _eventController.add(ChatRealtimeEvent.messageDelivered(event.data));
      case WsEventType.messageEdited:
        _eventController.add(ChatRealtimeEvent.messageEdited(event.data));
      case WsEventType.messageDeleted:
        _eventController.add(ChatRealtimeEvent.messageDeleted(event.data));
      case WsEventType.messagePinned:
        _eventController.add(ChatRealtimeEvent.messagePinned(event.data));
      case WsEventType.typing:
        _handleTyping(event.data);
      case WsEventType.presenceUpdate:
        _handlePresence(event.data);
      case WsEventType.callEvent:
        _handleCall(event.data);
      case WsEventType.conversationSync:
        _eventController.add(ChatRealtimeEvent.conversationSync(event.data));
      default:
        break;
    }
  }

  void _handleTyping(Map<String, dynamic> data) {
    final convId = data['conversation_id']?.toString();
    final sender = data['sender_id']?.toString();
    if (convId == null || sender == null) return;
    if (sender == FacultyService.canonicalId) return; // ignore own typing
    final current = Map<String, bool>.from(typingStatus.value);
    final isTyping = data['is_typing'] == true;
    if (isTyping) {
      current[convId] = true;
    } else {
      current.remove(convId);
    }
    typingStatus.value = current;
    _eventController.add(ChatRealtimeEvent.typing(convId, sender, isTyping));
    notifyListeners();
  }

  void _handlePresence(Map<String, dynamic> data) {
    final peerId = data['sender_id']?.toString();
    if (peerId == null) return;
    final previous = presence.value[peerId];
    final snapshot = PresenceSnapshot(
      isOnline: data['is_online'] == true,
      lastSeen: data['last_seen'] != null
          ? DateTime.tryParse(data['last_seen'].toString())
          : previous?.lastSeen,
      customStatus: data['custom_status']?.toString() ?? previous?.customStatus,
    );
    final current = Map<String, PresenceSnapshot>.from(presence.value);
    current[peerId] = snapshot;
    presence.value = current;
    _eventController.add(ChatRealtimeEvent.presence(peerId, snapshot));
    final recording = data['is_recording'] == true;
    final rec = Map<String, bool>.from(recordingStatus.value);
    if (recording) {
      rec[peerId] = true;
    } else {
      rec.remove(peerId);
    }
    recordingStatus.value = rec;
    notifyListeners();
  }

  void _handleCall(Map<String, dynamic> data) {
    final action = data['action']?.toString();
    final callId = data['call_id']?.toString();
    final sender = data['sender_id']?.toString();
    final peerId = data['peer_id']?.toString() ?? sender;
    final direction = data['call_direction']?.toString();
    final isSelf = sender != null && sender == FacultyService.canonicalId;

    final isIncomingAction =
        action == 'incoming' || action == 'call_incoming' || action == 'call_request';

    // Raise the shell-level incoming-call overlay only for real incoming
    // requests (skip echoes of our own outgoing calls).
    if (isIncomingAction && !isSelf && direction != 'outgoing' && peerId != null) {
      incomingCall.value = ChatCall(
        id: callId ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
        peer: _resolveCallPeer(peerId, data['peer_name']?.toString()),
        type: data['call_type']?.toString() == 'video' ? CallType.video : CallType.audio,
        direction: CallDirection.incoming,
        state: CallState.incoming,
        startedAt: DateTime.now(),
      );
    } else if (action == 'call_reject' || action == 'call_end') {
      // The caller cancelled before the user responded: drop the overlay.
      final current = incomingCall.value;
      if (current != null && callId != null && current.id == callId) {
        incomingCall.value = null;
      }
    }
    _eventController.add(ChatRealtimeEvent.call(data));
    notifyListeners();
  }

  /// Hydrates the incoming caller's contact from the local cache, then the
  /// demo catalog, so the overlay shows a real name/avatar instead of a
  /// bare id.
  StudentContact _resolveCallPeer(String peerId, String? fallbackName) {
    final conversations = MessageCacheService.instance.loadConversations();
    for (final c in conversations) {
      if (c.peer.id == peerId) return c.peer;
    }
    return StudentContact(id: peerId, name: fallbackName ?? 'Unknown');
  }

  // ── Outbound ──────────────────────────────────────────────────────────

  void sendTyping(String conversationId, bool isTyping) {
    _ws.sendTyping(conversationId: conversationId, isTyping: isTyping);
  }

  void sendReadReceipt(String conversationId, List<String> messageIds) {
    _ws.sendReadReceipt(conversationId: conversationId, messageIds: messageIds);
  }

  void sendPresence({bool online = true}) {
    _ws.sendPresence(isOnline: online);
  }

  /// Broadcasts voice-note recording state to the peer of `peerId`.
  void sendRecording({required String peerId, bool isRecording = true}) {
    _ws.sendRecording(peerId: peerId, isRecording: isRecording);
  }

  void sendCallSignal({
    required String conversationId,
    required String callId,
    required String action,
    Map<String, dynamic>? payload,
  }) {
    _ws.sendCallSignal(
      conversationId: conversationId,
      callId: callId,
      action: action,
      payload: payload,
    );
  }

  void sendChatMessage({
    required String conversationId,
    required String messageId,
    required String text,
    required String messageType,
    List<Map<String, dynamic>>? attachments,
    String? replyToMessageId,
  }) {
    _ws.sendChatMessage(
      conversationId: conversationId,
      messageId: messageId,
      text: text,
      messageType: messageType,
      attachments: attachments,
      replyToMessageId: replyToMessageId,
    );
  }

  /// Looks up the presence snapshot for a peer.
  PresenceSnapshot? presenceFor(String peerId) => presence.value[peerId];

  /// Whether the peer for a conversation is typing.
  bool isTypingIn(String conversationId) => typingStatus.value[conversationId] ?? false;

  /// Whether a peer is currently recording a voice note (from backend presence).
  bool isRecording(String peerId) => recordingStatus.value[peerId] ?? false;

  void dismissIncomingCall() {
    incomingCall.value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    if (_lifecycleObserved) WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _connSub?.cancel();
    _eventController.close();
    typingStatus.dispose();
    recordingStatus.dispose();
    presence.dispose();
    incomingCall.dispose();
    connectionState.dispose();
    super.dispose();
  }
}

/// Presence snapshot for a peer.
class PresenceSnapshot {
  final bool isOnline;
  final DateTime? lastSeen;
  final String? customStatus;

  const PresenceSnapshot({required this.isOnline, this.lastSeen, this.customStatus});
}

/// Typed realtime chat event dispatched to controllers.
class ChatRealtimeEvent {
  final String kind; // message_new | receipt | read | delivered | typing | presence | call | sync | ack | edited | deleted | pinned
  final Map<String, dynamic> data;
  final String? conversationId;
  final String? senderId;
  final PresenceSnapshot? presence;
  final bool isTyping;

  const ChatRealtimeEvent._(
    this.kind,
    this.data, {
    this.conversationId,
    this.senderId,
    this.presence,
    this.isTyping = false,
  });

  factory ChatRealtimeEvent.messageNew(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('message_new', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.messageAck(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('ack', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.messageReceipt(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('receipt', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.messageRead(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('read', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.messageDelivered(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('delivered', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.messageEdited(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('edited', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.messageDeleted(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('deleted', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.messagePinned(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('pinned', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.typing(String conversationId, String senderId, bool isTyping) =>
      ChatRealtimeEvent._('typing', const {},
          conversationId: conversationId, senderId: senderId, isTyping: isTyping);

  factory ChatRealtimeEvent.presence(String peerId, PresenceSnapshot snapshot) =>
      ChatRealtimeEvent._('presence', const {}, senderId: peerId, presence: snapshot);

  factory ChatRealtimeEvent.call(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('call', data,
          conversationId: data['conversation_id']?.toString());

  factory ChatRealtimeEvent.conversationSync(Map<String, dynamic> data) =>
      ChatRealtimeEvent._('sync', data);

  String get messageId => data['message_id']?.toString() ?? '';
  String get status => data['status']?.toString() ?? '';
}
