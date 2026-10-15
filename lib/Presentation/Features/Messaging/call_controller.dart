import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Services/chat_realtime_service.dart';

/// Drives the phone/video call screen state machine.
///
/// States: calling → ringing → connected → ended (outgoing) and
/// incoming → connected / rejected / missed (incoming). Mute, speaker and
/// camera-flip are local toggles; call signalling is pushed through the
/// realtime service and call records are persisted locally + on the backend.
///
/// The controller subscribes to realtime call events filtered on its own
/// [ChatCall.id], so an outgoing call only reaches `connected` when the peer
/// actually accepts (`call_accept`), and transitions to `rejected` / `busy` /
/// `missed` when the peer rejects, is busy, or cancels. Incoming calls persist
/// a record only once the user responds (accept / reject / auto-timeout).
class CallController extends ChangeNotifier {
  /// The single in-progress call across the app, used by the incoming-call
  /// overlay to auto-decline with `call_busy` when the faculty is already in
  /// a call. Cleared when the call reaches a terminal state.
  static CallController? activeCall;

  final MessagingRepository repository;
  final MessageCacheService cache;

  final StudentContact peer;
  final CallType type;
  final CallDirection direction;

  ChatCall _call;
  CallState _state;
  bool _muted = false;
  bool _speakerOn = false;
  bool _cameraOn = true;
  bool _cameraFront = true;

  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _connectedAt;

  Timer? _incomingBusyTimer;
  StreamSubscription<ChatRealtimeEvent>? _callSub;

  CallController({
    required this.repository,
    required this.peer,
    required this.type,
    required this.direction,
    this.callId,
    this.startedAt,
    MessageCacheService? cache,
  })  : cache = cache ?? MessageCacheService.instance,
        _call = ChatCall(
          id: callId ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
          peer: peer,
          type: type,
          direction: direction,
          state: direction == CallDirection.outgoing ? CallState.calling : CallState.incoming,
          startedAt: startedAt ?? DateTime.now(),
        ),
        _state = direction == CallDirection.outgoing ? CallState.calling : CallState.incoming {
    _init();
  }

  /// Realtime call id shared with the peer (from the backend signal).
  final String? callId;

  /// For incoming calls: when the call request was received. Rebuilt to the
  /// moment of acceptance once the user picks up.
  final DateTime? startedAt;

  ChatCall get call => _call;
  CallState get state => _state;
  bool get isMuted => _muted;
  bool get isSpeakerOn => _speakerOn;
  bool get isCameraOn => _cameraOn;
  bool get isCameraFront => _cameraFront;
  Duration get elapsed => _elapsed;

  bool get isEnded =>
      _state == CallState.ended ||
      _state == CallState.missed ||
      _state == CallState.rejected ||
      _state == CallState.busy ||
      _state == CallState.failed;

  String get stateLabel {
    switch (_state) {
      case CallState.calling:
        return 'Calling...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.incoming:
        return 'Incoming call';
      case CallState.connecting:
        return 'Connecting...';
      case CallState.connected:
        return _formatDuration(_elapsed);
      case CallState.ended:
        return 'Call ended';
      case CallState.missed:
        return 'Call missed';
      case CallState.rejected:
        return 'Call rejected';
      case CallState.busy:
        return 'Busy';
      case CallState.failed:
        return 'Call failed';
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${h.isNotEmpty ? '$h:' : ''}$m:$s';
  }

  void _init() {
    activeCall = this;
    _configurePlatform();
    _callSub = ChatRealtimeService.instance.events.listen(_onCallEvent);
    if (direction == CallDirection.outgoing) {
      _signal('call_request', payload: {'call_type': type.name, 'peer_id': peer.id});
      // Fallback ring indication in case the backend never echoes a
      // `call_receipt`; the real transition to `connected` only happens on
      // `call_accept`.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (_state == CallState.calling && !isEnded) {
          _transition(CallState.ringing);
        }
      });
      _persistRecord();
    } else {
      // Incoming: wait for the user (or the incoming overlay) to respond.
      // If nobody answers within the ring window, tell the caller we're busy
      // and mark the call missed.
      _incomingBusyTimer = Timer(const Duration(seconds: 45), () {
        if (_state != CallState.incoming || isEnded) return;
        _signal('call_busy');
        _transition(CallState.missed);
      });
    }
  }

  void _configurePlatform() {
    // Audio-focus / mic is requested by the OS permission gate in the UI
    // before this controller is created. Keeping this a no-op here lets
    // the controller be tested headlessly.
  }

  // ── Signalling ────────────────────────────────────────────────────────

  void _signal(String action, {Map<String, dynamic>? payload}) {
    ChatRealtimeService.instance.sendCallSignal(
      conversationId: 'direct_${peer.id}',
      callId: call.id,
      action: action,
      payload: payload,
    );
    ChatRealtimeService.instance.sendCallSignal(
      conversationId: 'call_${call.id}',
      callId: call.id,
      action: action,
      payload: payload,
    );
  }

  void _transition(CallState next) {
    if (isEnded) return;
    // A connected call can only leave the connected state by ending.
    if (_state == CallState.connected && next != CallState.ended) return;
    _state = next;
    if (next == CallState.connected) {
      _connectedAt ??= DateTime.now();
      _startTimer();
    }
    if (next == CallState.ended) {
      _stopTimer();
      _call = _call.copyWith(
        state: next,
        endedAt: DateTime.now(),
        durationSeconds: _elapsed.inSeconds,
      );
    } else {
      _call = _call.copyWith(state: next);
    }
    _persistRecord();
    if (isEnded && activeCall == this) activeCall = null;
    notifyListeners();
  }

  /// Handles realtime call events addressed to this call's id.
  void _onCallEvent(ChatRealtimeEvent event) {
    if (event.kind != 'call') return;
    final data = event.data;
    if (data['call_id']?.toString() != call.id) return;
    switch (data['action']?.toString()) {
      case 'call_accept':
      case 'call_already_answered':
        if (direction == CallDirection.outgoing) peerAccepted();
        break;
      case 'call_reject':
        if (direction == CallDirection.outgoing) peerRejected();
        break;
      case 'call_busy':
        if (direction == CallDirection.outgoing) peerBusy();
        break;
      case 'call_end':
        peerEnded();
        break;
      case 'call_receipt':
        if (data['status']?.toString() == 'ringing' &&
            direction == CallDirection.outgoing &&
            _state == CallState.calling) {
          _transition(CallState.ringing);
        }
        break;
      default:
        break;
    }
  }

  // ── Public actions (called by UI buttons) ─────────────────────────────

  /// Outgoing: the peer accepted the call.
  void peerAccepted() {
    if (direction != CallDirection.outgoing) return;
    if (isEnded || _state == CallState.connected) return;
    _transition(CallState.connected);
  }

  /// Outgoing: the peer rejected the call.
  void peerRejected() {
    if (direction != CallDirection.outgoing) return;
    if (isEnded || _state == CallState.connected) return;
    _transition(CallState.rejected);
  }

  /// Outgoing: the peer is busy.
  void peerBusy() {
    if (direction != CallDirection.outgoing) return;
    if (isEnded || _state == CallState.connected) return;
    _transition(CallState.busy);
  }

  /// Outgoing: the peer hung up / the call is gone before it connected.
  void peerEnded() {
    if (isEnded) return;
    if (_state == CallState.connected) {
      // The peer hung up mid-call — wrap the call up with its duration.
      _transition(CallState.ended);
    } else if (direction == CallDirection.incoming) {
      _transition(CallState.missed);
    } else {
      _transition(CallState.ended);
    }
  }

  /// Incoming: the user accepts. The record is (re)created with the correct
  /// call id and the moment of acceptance as the start time.
  void acceptCall() {
    if (direction != CallDirection.incoming) return;
    if (isEnded || _state == CallState.connected) return;
    _incomingBusyTimer?.cancel();
    _signal('call_accept');
    _call = _call.copyWith(state: CallState.connected, startedAt: DateTime.now());
    _transition(CallState.connected);
  }

  /// Incoming: the user declines.
  void declineCall() {
    if (direction != CallDirection.incoming) return;
    if (isEnded) return;
    _incomingBusyTimer?.cancel();
    _signal('call_reject');
    _transition(CallState.rejected);
  }

  /// Ends the call (from any state).
  Future<void> endCall() async {
    if (isEnded) return;
    _incomingBusyTimer?.cancel();
    _signal('call_end', payload: {'duration_seconds': _elapsed.inSeconds});
    _stopTimer();
    _state = CallState.ended;
    _call = _call.copyWith(
      state: CallState.ended,
      endedAt: DateTime.now(),
      durationSeconds: _elapsed.inSeconds,
    );
    _persistRecord();
    if (activeCall == this) activeCall = null;
    notifyListeners();

    await repository.endCall(call.id, _elapsed.inSeconds);
  }

  void toggleMute() {
    _muted = !_muted;
    _signal('call_media_state', payload: {'muted': _muted});
    notifyListeners();
  }

  void toggleSpeaker() {
    _speakerOn = !_speakerOn;
    _signal('call_media_state', payload: {'speaker': _speakerOn});
    notifyListeners();
  }

  void toggleCamera() {
    _cameraOn = !_cameraOn;
    _signal('call_media_state', payload: {'camera_on': _cameraOn});
    notifyListeners();
  }

  void flipCamera() {
    _cameraFront = !_cameraFront;
    notifyListeners();
  }

  // ── Duration ──────────────────────────────────────────────────────────

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed = Duration(seconds: DateTime.now().difference(_connectedAt!).inSeconds);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  Future<void> _persistRecord() async {
    await cache.addCall(_call);
  }

  @override
  void dispose() {
    _incomingBusyTimer?.cancel();
    _durationTimer?.cancel();
    _callSub?.cancel();
    if (activeCall == this) activeCall = null;
    super.dispose();
  }
}
