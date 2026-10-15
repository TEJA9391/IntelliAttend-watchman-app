import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Data/Repositories/Messaging/messaging_repository.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/call_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/peer_avatar.dart';

/// Full-screen phone/video call UI driven by [CallController].
class CallScreen extends StatelessWidget {
  final StudentContact peer;
  final CallType type;
  final CallDirection direction;
  final MessagingRepository repository;
  final CallController? controller;
  final String? callId;

  const CallScreen({
    super.key,
    required this.peer,
    required this.type,
    required this.direction,
    required this.repository,
    this.controller,
    this.callId,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return ChangeNotifierProvider.value(
        value: controller!,
        child: const _CallScreenView(),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => CallController(
        repository: repository,
        peer: peer,
        type: type,
        direction: direction,
        callId: callId,
      ),
      child: const _CallScreenView(),
    );
  }
}

class _CallScreenView extends StatefulWidget {
  const _CallScreenView();

  @override
  State<_CallScreenView> createState() => _CallScreenViewState();
}

class _CallScreenViewState extends State<_CallScreenView> {
  CameraController? _cameraController;
  bool _cameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final controller = context.read<CallController>();
    if (controller.type != CallType.video) return;

    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final camera = controller.isCameraFront
          ? cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => cameras.first,
            )
          : cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => cameras.first,
            );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraInitialized = true);
    } catch (e) {
      debugPrint('Camera init failed: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallController>();
    final peer = controller.peer;
    final isConnected = controller.state == CallState.connected;
    final isEnded = controller.isEnded;
    final isVideo = controller.type == CallType.video;
    final isIncoming = controller.direction == CallDirection.incoming &&
        !isConnected &&
        !isEnded;

    return PopScope(
      canPop: isEnded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !controller.isEnded) {
          controller.endCall();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Full-screen camera preview for video calls
              if (isVideo && _cameraInitialized && _cameraController != null)
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(_cameraController!),
                    ),
                  ),
                ),

              // Dark overlay gradient for readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: isVideo ? 0.4 : 0.0),
                        Colors.black.withValues(alpha: isVideo ? 0.2 : 0.0),
                        Colors.black.withValues(alpha: isVideo ? 0.6 : 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              if (isEnded)
                _CallEndedPanel(
                  controller: controller,
                  onRedial: () => _redial(context, controller),
                  onClose: () => Navigator.of(context).pop(),
                )
              else ...[
                // Peer info + timer
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isConnected ? controller.stateLabel : controller.stateLabel,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 24),
                      PeerAvatar(name: peer.name, radius: 52, isOnline: true, showOnlineDot: true),
                      const SizedBox(height: 18),
                      Text(peer.displayTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(
                        isVideo ? 'Video call' : 'Voice call',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (isConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _formatElapsed(controller.elapsed),
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),

                // Local camera PIP (top-right corner) for video calls
                if (isVideo && _cameraInitialized && _cameraController != null && isConnected)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        controller.flipCamera();
                        _flipCamera();
                      },
                      child: Container(
                        width: 110,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize!.height,
                            height: _cameraController!.value.previewSize!.width,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Incoming call controls
                if (isIncoming)
                  Positioned(
                    bottom: 70,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BigButton(
                          icon: Icons.call_end_rounded,
                          color: AppTheme.errorRed,
                          onTap: () {
                            controller.declineCall();
                            HapticService.medium();
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 56),
                        _BigButton(
                          icon: Icons.call_rounded,
                          color: const Color(0xFF22C55E),
                          onTap: () {
                            HapticService.light();
                            controller.acceptCall();
                          },
                        ),
                      ],
                    ),
                  ),

                // Outgoing / connected controls
                if (!isIncoming)
                  Positioned(
                    bottom: 70,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        if (isConnected) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ControlButton(
                                icon: controller.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                label: 'Mute',
                                active: controller.isMuted,
                                onTap: controller.toggleMute,
                              ),
                              const SizedBox(width: 20),
                              _ControlButton(
                                icon: controller.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                                label: 'Speaker',
                                active: controller.isSpeakerOn,
                                onTap: controller.toggleSpeaker,
                              ),
                              if (isVideo) ...[
                                const SizedBox(width: 20),
                                _ControlButton(
                                  icon: controller.isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                                  label: 'Camera',
                                  active: !controller.isCameraOn,
                                  onTap: () {
                                    controller.toggleCamera();
                                    _toggleCameraPreview();
                                  },
                                ),
                                const SizedBox(width: 20),
                                _ControlButton(
                                  icon: Icons.cameraswitch_rounded,
                                  label: 'Flip',
                                  active: false,
                                  onTap: () {
                                    controller.flipCamera();
                                    _flipCamera();
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 40),
                          _BigButton(
                            icon: Icons.call_end_rounded,
                            color: AppTheme.errorRed,
                            onTap: () async {
                              HapticService.medium();
                              await controller.endCall();
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                        ] else ...[
                          Text(
                            'Cancel',
                            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          _BigButton(
                            icon: Icons.call_end_rounded,
                            color: AppTheme.errorRed,
                            onTap: () async {
                              HapticService.medium();
                              await controller.endCall();
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _flipCamera() async {
    if (_cameraController == null) return;
    final controller = context.read<CallController>();
    try {
      final cameras = await availableCameras();
      final newDirection = controller.isCameraFront
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == newDirection,
        orElse: () => cameras.first,
      );
      await _cameraController!.dispose();
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Camera flip failed: $e');
    }
  }

  void _toggleCameraPreview() {
    if (!mounted) return;
    setState(() {});
  }

  void _redial(BuildContext context, CallController controller) {
    HapticService.medium();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peer: controller.peer,
          type: controller.type,
          direction: CallDirection.outgoing,
          repository: controller.repository,
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}

class _CallEndedPanel extends StatelessWidget {
  final CallController controller;
  final VoidCallback onRedial;
  final VoidCallback onClose;

  const _CallEndedPanel({
    required this.controller,
    required this.onRedial,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final peer = controller.peer;
    final duration = controller.call.durationSeconds > 0
        ? controller.call.durationSeconds
        : controller.elapsed.inSeconds;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PeerAvatar(name: peer.name, radius: 48, isOnline: true, showOnlineDot: true),
            const SizedBox(height: 18),
            Text(peer.displayTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(controller.stateLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w600)),
            if (duration > 0) ...[
              const SizedBox(height: 4),
              Text('Duration ${_formatSeconds(duration)}',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BigButton(
                  icon: Icons.close_rounded,
                  color: Colors.white24,
                  onTap: onClose,
                ),
                const SizedBox(width: 48),
                _BigButton(
                  icon: controller.type == CallType.video
                      ? Icons.videocam_rounded
                      : Icons.call_rounded,
                  color: const Color(0xFF22C55E),
                  onTap: onRedial,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Call again',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BigButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppTheme.accentGold : Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
