import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// State machine for a WhatsApp-style voice note:
///
///   hold to record · slide left to cancel · lock · pause/resume ·
///   live amplitude wave · timer · preview playback · delete · send.
///
/// Recording uses the `record` plugin (AAC-LC, mono, noise suppression +
/// auto-gain). Preview playback uses `audioplayers`. No logic is faked —
/// the wave is real captured amplitude and the timer is the live duration.
class VoiceRecorderController extends ChangeNotifier {
  VoiceRecorderController({
    required void Function(String path, {int? durationMs}) onSend,
  }) : _onSend = onSend;

  final void Function(String path, {int? durationMs}) _onSend;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  static const int _maxWaveBars = 30;
  static const Duration _maxDuration = Duration(seconds: 60);
  static const Duration _minDuration = Duration(milliseconds: 700);

  bool _isRecording = false;
  bool _isPaused = false;
  bool _isLocked = false;
  bool _slideCancel = false;
  bool _isPreviewing = false;
  bool _isPlayingPreview = false;
  bool _disposed = false;

  String? _path;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  double _slideDx = 0;
  final List<double> _wave = [];

  Timer? _ticker;
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  bool get isLocked => _isLocked;
  bool get slideCancel => _slideCancel;
  bool get isPreviewing => _isPreviewing;
  bool get isPlayingPreview => _isPlayingPreview;
  String? get path => _path;
  Duration get elapsed => _elapsed;
  Duration get previewPosition => _previewPosition;
  Duration get previewDuration => _previewDuration;

  double get previewProgress {
    final total = _previewDuration.inMilliseconds;
    if (total <= 0) return 0;
    return (_previewPosition.inMilliseconds / total).clamp(0.0, 1.0);
  }

  List<double> get wave => _wave.isEmpty
      ? List<double>.filled(_maxWaveBars, 0.04)
      : List.unmodifiable(_wave);

  String get timerText => _format(_elapsed);
  String get previewPositionText => _format(_previewPosition);
  String get previewDurationText => _format(_previewDuration);

  /// Starts a new recording. Permission must already be granted by the caller.
  Future<void> startRecording() async {
    if (_isRecording || _isPreviewing || _disposed) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
          noiseSuppress: true,
          autoGain: true,
        ),
        path: path,
      );
      _path = path;
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _slideDx = 0;
      _slideCancel = false;
      _isPaused = false;
      _isLocked = false;
      _isPreviewing = false;
      _wave.clear();
      _wave.addAll(List<double>.filled(_maxWaveBars, 0.04));
      _isRecording = true;

      _ampSub?.cancel();
      _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 60))
          .listen(_onAmplitude);

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!_isRecording || _isPaused) return;
        _elapsed = DateTime.now().difference(_startedAt!);
        if (_elapsed >= _maxDuration) {
          _finishRecording();
        } else {
          notifyListeners();
        }
      });

      notifyListeners();
    } catch (_) {
      _reset();
    }
  }

  void _onAmplitude(Amplitude amp) {
    if (!_isRecording || _isPaused || _disposed) return;
    final db = amp.current.isFinite ? amp.current : -160.0;
    final level = ((db + 55) / 55).clamp(0.03, 1.0);
    _wave.removeAt(0);
    _wave.add(level);
    notifyListeners();
  }

  // ── Recording controls ────────────────────────────────────────────────

  Future<void> togglePause() async {
    if (!_isRecording) return;
    try {
      if (_isPaused) {
        await _recorder.resume();
        _isPaused = false;
      } else {
        await _recorder.pause();
        _isPaused = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  void toggleLock() {
    if (!_isRecording) return;
    _isLocked = !_isLocked;
    if (_isLocked) _slideCancel = false;
    HapticService.selection();
    notifyListeners();
  }

  /// Feeds horizontal drag deltas while holding the mic. Sliding left past
  /// a threshold arms the cancel state; releasing then deletes the take.
  void updateSlide(double dx) {
    if (!_isRecording || _isLocked) return;
    _slideDx += dx;
    final cancel = _slideDx < -80;
    if (cancel != _slideCancel) {
      _slideCancel = cancel;
      if (cancel) HapticService.light();
      notifyListeners();
    }
  }

  /// Called when the user releases the mic (or the long-press is cancelled
  /// because the drag recognizer took over). Locked recordings keep going.
  void endHold() {
    if (!_isRecording) return;
    if (_isLocked) return;
    _finishRecording();
  }

  /// Cancels a locked recording and deletes the file.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    HapticService.medium();
    try {
      await _recorder.cancel();
    } catch (_) {}
    _deleteFile();
    _reset();
  }

  /// Sends a locked recording directly without preview.
  Future<void> sendRecording() async {
    if (!_isRecording) return;
    HapticService.medium();
    await _stopRecorder();
    final path = _path;
    final durationMs = _elapsed.inMilliseconds;
    _reset();
    if (path != null) _onSend(path, durationMs: durationMs);
  }

  Future<void> _finishRecording() async {
    if (!_isRecording) return;
    await _stopRecorder();
    final path = _path;
    final elapsed = _elapsed;
    if (path == null) {
      _reset();
      return;
    }
    if (elapsed < _minDuration) {
      // Too short to be useful: silently discard.
      _deleteFile();
      _reset();
      return;
    }
    _isRecording = false;
    _isPaused = false;
    _isLocked = false;
    _slideCancel = false;
    _isPreviewing = true;
    _previewPosition = Duration.zero;
    _previewDuration = elapsed;
    notifyListeners();
  }

  Future<void> _stopRecorder() async {
    _ticker?.cancel();
    _ticker = null;
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  // ── Preview controls ──────────────────────────────────────────────────

  Future<void> togglePreviewPlayback() async {
    if (!_isPreviewing) return;
    final path = _path;
    if (path == null) return;
    try {
      if (_isPlayingPreview) {
        await _player.pause();
        _isPlayingPreview = false;
        notifyListeners();
        return;
      }
      if (_previewPosition >= _previewDuration &&
          _previewDuration > Duration.zero) {
        await _player.seek(Duration.zero);
        _previewPosition = Duration.zero;
      }
      _posSub ??= _player.onPositionChanged.listen((p) {
        if (!_isPreviewing || _disposed) return;
        _previewPosition = p;
        notifyListeners();
      });
      _durationSub ??= _player.onDurationChanged.listen((d) {
        if (d.inMilliseconds > 0) _previewDuration = d;
      });
      _completeSub ??= _player.onPlayerComplete.listen((_) {
        if (!_isPreviewing || _disposed) return;
        _isPlayingPreview = false;
        _previewPosition = _previewDuration;
        notifyListeners();
      });
      await _player.play(DeviceFileSource(path));
      _isPlayingPreview = true;
      notifyListeners();
    } catch (_) {}
  }

  void seekPreview(double fraction) {
    if (!_isPreviewing || _previewDuration.inMilliseconds <= 0) return;
    final target = Duration(
        milliseconds: (_previewDuration.inMilliseconds * fraction).round());
    _previewPosition = target;
    _player.seek(target);
    notifyListeners();
  }

  /// Discards the preview and deletes the file.
  Future<void> deletePreview() async {
    if (!_isPreviewing) return;
    HapticService.medium();
    await _player.stop();
    _previewPosition = Duration.zero;
    _previewDuration = Duration.zero;
    _deleteFile();
    _reset();
  }

  /// Sends the previewed voice note.
  Future<void> sendPreview() async {
    if (!_isPreviewing) return;
    HapticService.medium();
    await _player.stop();
    final path = _path;
    final durationMs = _previewDuration.inMilliseconds;
    _reset();
    if (path != null) _onSend(path, durationMs: durationMs);
  }

  void _deleteFile() {
    final p = _path;
    _path = null;
    if (p != null) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _ampSub?.cancel();
    _ampSub = null;
    _isRecording = false;
    _isPaused = false;
    _isLocked = false;
    _slideCancel = false;
    _slideDx = 0;
    _isPreviewing = false;
    _isPlayingPreview = false;
    _path = null;
    _startedAt = null;
    _elapsed = Duration.zero;
    _previewPosition = Duration.zero;
    _previewDuration = Duration.zero;
    _wave.clear();
    notifyListeners();
  }

  static String _format(Duration d) {
    final s = d.inSeconds;
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ampSub?.cancel();
    _posSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }
}

/// Live recording bar: real amplitude wave, timer, pause/resume, lock and
/// (when locked) delete + send. Shows the slide-to-cancel affordance.
class VoiceRecordingBar extends StatelessWidget {
  final VoiceRecorderController controller;

  const VoiceRecordingBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cancel = controller.slideCancel;
        final tint = cancel
            ? AppTheme.errorRed
            : AppTheme.primary(context);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          color: tint.withValues(alpha: 0.12),
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    controller.isPaused
                        ? Icons.fiber_manual_record_rounded
                        : Icons.graphic_eq_rounded,
                    size: 16,
                    color: cancel ? AppTheme.errorRed : AppTheme.primary(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: WaveformBars(
                      levels: controller.wave,
                      progress: 1,
                      activeColor: tint,
                      height: 26,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    controller.timerText,
                    style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  _barIcon(
                    context,
                    tooltip: controller.isPaused ? 'Resume' : 'Pause',
                    icon: controller.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    color: AppTheme.textSecondary(context),
                    onTap: controller.togglePause,
                  ),
                  _barIcon(
                    context,
                    tooltip: controller.isLocked ? 'Unlock' : 'Lock recording',
                    icon: controller.isLocked
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    color: controller.isLocked
                        ? AppTheme.primary(context)
                        : AppTheme.textSecondary(context),
                    onTap: controller.toggleLock,
                  ),
                  if (controller.isLocked) ...[
                    _barIcon(
                      context,
                      tooltip: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      color: AppTheme.errorRed,
                      onTap: controller.cancelRecording,
                    ),
                    _barSend(context),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  controller.isLocked
                      ? 'Recording locked · pause, delete or send when ready'
                      : cancel
                          ? 'Release to cancel recording'
                          : 'Hold to talk · slide left to cancel',
                  key: ValueKey('${controller.isLocked}-$cancel'),
                  style: GoogleFonts.inter(
                    color: cancel
                        ? AppTheme.errorRed
                        : AppTheme.textSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barIcon(BuildContext context,
      {required String tooltip,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 20),
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }

  Widget _barSend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton.filled(
        tooltip: 'Send',
        onPressed: controller.sendRecording,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.primary(context),
          minimumSize: const Size(34, 34),
        ),
        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 17),
      ),
    );
  }
}

/// Pre-send preview: playback with real position, seekable wave, delete and
/// send.
class VoicePreviewBar extends StatelessWidget {
  final VoiceRecorderController controller;

  const VoicePreviewBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          color: AppTheme.primary(context).withValues(alpha: 0.10),
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: controller.togglePreviewPlayback,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary(context),
                  child: Icon(
                    controller.isPlayingPreview
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTapUp: (d) =>
                      controller.seekPreview(_fraction(context, d.localPosition.dx)),
                  onHorizontalDragUpdate: (d) =>
                      controller.seekPreview(_fraction(context, d.localPosition.dx)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WaveformBars(
                        levels: controller.wave,
                        progress: controller.previewProgress,
                        activeColor: AppTheme.primary(context),
                        height: 24,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            controller.previewPositionText,
                            style: GoogleFonts.inter(
                                color: AppTheme.text(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ]),
                          ),
                          Text(
                            controller.previewDurationText,
                            style: GoogleFonts.inter(
                                color: AppTheme.textSecondary(context),
                                fontSize: 11,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Delete',
                onPressed: controller.deletePreview,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.errorRed, size: 22),
                visualDensity: VisualDensity.compact,
              ),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: controller.sendPreview,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary(context),
                  minimumSize: const Size(40, 40),
                ),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }

  double _fraction(BuildContext context, double dx) {
    final width = MediaQuery.sizeOf(context).width - 12 - 8 - 40 - 12 - 40;
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0);
  }
}

/// Animated waveform bars driven by real amplitude levels (recording) or by
/// playback progress (preview). Bars are stretched a bit for a lively look.
class WaveformBars extends StatelessWidget {
  final List<double> levels;
  final double progress;
  final Color activeColor;
  final double height;

  const WaveformBars({
    super.key,
    required this.levels,
    required this.progress,
    required this.activeColor,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    final dimColor = AppTheme.textSecondary(context).withValues(alpha: 0.25);
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < levels.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              width: 3,
              height: 5 + (levels[i] * (height - 7)).clamp(0.0, height - 7),
              decoration: BoxDecoration(
                color: (i / levels.length) <= progress
                    ? activeColor
                    : dimColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
