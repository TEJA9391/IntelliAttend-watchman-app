import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/main.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/call_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/call_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/peer_avatar.dart';
import 'package:intelli_attend_faculty/Services/chat_realtime_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// Shell-level banner shown whenever an incoming call signal arrives,
/// regardless of the screen the faculty is on.
///
/// Renders a compact "incoming call" card with accept / decline actions, a
/// pulsing avatar and a ringing vibration. Accepting pushes the full
/// [CallScreen] already connected; declining (or letting it ring out) sends
/// `call_reject` / `call_busy` back to the caller.
class IncomingCallOverlay extends StatelessWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatCall?>(
      valueListenable: ChatRealtimeService.instance.incomingCall,
      builder: (context, call, _) {
        if (call == null) return const SizedBox.shrink();
        return _IncomingCallBanner(key: ValueKey(call.id), call: call);
      },
    );
  }
}

class _IncomingCallBanner extends StatefulWidget {
  final ChatCall call;

  const _IncomingCallBanner({super.key, required this.call});

  @override
  State<_IncomingCallBanner> createState() => _IncomingCallBannerState();
}

class _IncomingCallBannerState extends State<_IncomingCallBanner>
    with SingleTickerProviderStateMixin {
  static const _ringTimeout = Duration(seconds: 45);

  Timer? _busyTimer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.92,
      upperBound: 1.0,
    )..repeat(reverse: true);
    Vibration.vibrate(pattern: const [0, 600, 300, 600], repeat: -1);
    _busyTimer = Timer(_ringTimeout, _autoBusy);
  }

  @override
  void dispose() {
    _busyTimer?.cancel();
    _pulse.dispose();
    Vibration.cancel();
    super.dispose();
  }

  ChatCall get _call => widget.call;

  /// Nobody answered: tell the caller we're busy and drop the banner.
  void _autoBusy() {
    if (!mounted) return;
    final call = _call;
    ChatRealtimeService.instance.sendCallSignal(
      conversationId: 'call_${call.id}',
      callId: call.id,
      action: 'call_busy',
    );
    ChatRealtimeService.instance.dismissIncomingCall();
  }

  Future<void> _respond(BuildContext context, {required bool accept}) async {
    final call = _call;
    final navigator = IntelliAttendApp.navigatorKey.currentState;
    ChatRealtimeService.instance.dismissIncomingCall();

    if (accept && CallController.activeCall != null) {
      // Already on another call — auto-decline as busy.
      _sendSignal(call, 'call_busy');
      return;
    }

    final controller = CallController(
      repository: MessagingRepository(),
      peer: call.peer,
      type: call.type,
      direction: CallDirection.incoming,
      callId: call.id,
    );
    if (accept) {
      controller.acceptCall();
      if (navigator == null) {
        controller.dispose();
        return;
      }
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            peer: call.peer,
            type: call.type,
            direction: CallDirection.incoming,
            repository: controller.repository,
            controller: controller,
          ),
        ),
      );
      if (mounted) controller.dispose();
    } else {
      controller.declineCall();
      controller.dispose();
    }
  }

  void _sendSignal(ChatCall call, String action) {
    ChatRealtimeService.instance.sendCallSignal(
      conversationId: 'call_${call.id}',
      callId: call.id,
      action: action,
    );
  }

  @override
  Widget build(BuildContext context) {
    final call = _call;
    final isVideo = call.type == CallType.video;

    return Positioned(
      top: 48,
      left: 16,
      right: 16,
      child: Material(
        color: const Color(0xFF101828),
        elevation: 16,
        borderRadius: BorderRadius.circular(24),
        shadowColor: Colors.black54,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            children: [
              ScaleTransition(
                scale: _pulse,
                child: PeerAvatar(name: call.peer.name, radius: 28, isOnline: true, showOnlineDot: true),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(call.peer.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: AppTheme.greenOnline, size: 15),
                        const SizedBox(width: 6),
                        Text(isVideo ? 'Incoming video call' : 'Incoming voice call',
                            style: GoogleFonts.inter(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.call_end_rounded,
                color: AppTheme.errorRed,
                onTap: () => _respond(context, accept: false),
              ),
              const SizedBox(width: 12),
              _RoundAction(
                icon: Icons.call_rounded,
                color: const Color(0xFF22C55E),
                onTap: () => _respond(context, accept: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, spreadRadius: 1)],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
