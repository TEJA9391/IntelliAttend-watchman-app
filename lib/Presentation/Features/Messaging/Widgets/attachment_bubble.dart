import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_time_format.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/peer_avatar.dart';

/// Renders a single [ChatAttachment] inside a bubble, honoring its type.
/// Handles images, video, voice/audio, documents and contact cards, and
/// opens / plays them with real tooling.
class AttachmentBubble extends StatefulWidget {
  final ChatAttachment attachment;
  final Color bubbleColor;
  final Color textColor;
  final bool isOutgoing;
  final double maxWidth;

  const AttachmentBubble({
    super.key,
    required this.attachment,
    required this.bubbleColor,
    required this.textColor,
    required this.isOutgoing,
    this.maxWidth = 300,
  });

  @override
  State<AttachmentBubble> createState() => _AttachmentBubbleState();
}

class _AttachmentBubbleState extends State<AttachmentBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  CancelToken? _downloadToken;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.attachment.durationMs ?? 0);
    _positionSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _downloadToken?.cancel('disposed');
    _positionSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String? get _sourcePath =>
      widget.attachment.localPath ?? widget.attachment.remoteUrl;

  /// Sanitises a filename by stripping path separators, null bytes and
  /// trimming to a reasonable length so it can be used as a cache file.
  String _sanitizeFileName(String name) {
    var safe = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00]'), '_').trim();
    if (safe.isEmpty) safe = 'file';
    if (safe.length > 80) safe = safe.substring(0, 80);
    return safe;
  }

  Future<String> _resolveLocalPath() async {
    final local = widget.attachment.localPath;
    if (local != null && File(local).existsSync()) return local;
    final remote = widget.attachment.remoteUrl;
    if (remote != null) {
      final dir = await getTemporaryDirectory();
      final fileName = widget.attachment.name.isNotEmpty
          ? _sanitizeFileName(widget.attachment.name)
          : 'download_${widget.attachment.id}';
      final file = File('${dir.path}/$fileName');
      if (!file.existsSync()) {
        _downloadToken = CancelToken();
        try {
          await ApiClient().dio.download(
            remote,
            file.path,
            cancelToken: _downloadToken,
          );
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) rethrow;
          debugPrint('[AttachmentBubble] download failed: $e');
          return '';
        } catch (e) {
          debugPrint('[AttachmentBubble] download error: $e');
          return '';
        } finally {
          _downloadToken = null;
        }
      }
      return file.path;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    switch (a.type) {
      case MessageContentType.image:
        return _buildImage(context, a);
      case MessageContentType.video:
        return _buildVideo(context, a);
      case MessageContentType.voice:
        return _buildVoice(context, a);
      case MessageContentType.audio:
        return _buildAudio(context, a);
      case MessageContentType.location:
        return _buildLocation(context, a);
      case MessageContentType.contact:
        return _buildContact(context, a);
      case MessageContentType.pdf:
      case MessageContentType.word:
      case MessageContentType.excel:
      case MessageContentType.powerpoint:
      case MessageContentType.zip:
      case MessageContentType.document:
        return _buildDocument(context, a);
      case MessageContentType.attendanceReport:
      case MessageContentType.assignment:
      case MessageContentType.announcement:
        return _buildRichCard(context, a);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Image ─────────────────────────────────────────────────────────────

  Widget _buildImage(BuildContext context, ChatAttachment a) {
    final local = a.localPath;
    final remote = a.remoteUrl;
    final child = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: local != null && File(local).existsSync()
          ? Image.file(File(local), fit: BoxFit.cover,
              width: widget.maxWidth, height: 240,
              errorBuilder: (_, error, stack) => _imageError(context, error.toString(), stack))
          : remote != null
              ? CachedNetworkImage(
                  imageUrl: remote,
                  fit: BoxFit.cover,
                  width: widget.maxWidth,
                  height: 240,
                  placeholder: (_, __) => Container(
                    width: widget.maxWidth,
                    height: 240,
                    color: Colors.black12,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, error, __) =>
                      _imageError(context, error.toString(), null),
                )
              : _imageError(context, '', null),
    );
    return GestureDetector(
      onTap: () => _openImageFullScreen(context, a),
      child: child,
    );
  }

  Widget _imageError(BuildContext context, String error, StackTrace? stack) {
    return _imageErrorPlaceholder(context);
  }

  Widget _imageErrorPlaceholder(BuildContext context) {
    return Container(
      width: widget.maxWidth,
      height: 200,
      color: widget.bubbleColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined, size: 36, color: Colors.white54),
          const SizedBox(height: 8),
          Text('Image unavailable',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _openImageFullScreen(BuildContext context, ChatAttachment a) async {
    final source = a.localPath ?? a.remoteUrl;
    if (source == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenMedia(
          source: source,
          isLocal: a.localPath != null,
          isVideo: false,
          title: a.name,
        ),
      ),
    );
  }

  // ── Video ─────────────────────────────────────────────────────────────

  Widget _buildVideo(BuildContext context, ChatAttachment a) {
    final local = a.localPath;
    return GestureDetector(
      onTap: () {
        final source = local ?? a.remoteUrl;
        if (source == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullScreenMedia(
              source: source,
              isLocal: local != null,
              isVideo: true,
              title: a.name,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: widget.maxWidth,
          height: 220,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (local != null && File(local).existsSync())
                Image.file(File(local), fit: BoxFit.cover, width: widget.maxWidth, height: 220)
              else if (a.thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: a.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: widget.maxWidth,
                  height: 220,
                  errorWidget: (_, __, ___) => Container(
                    width: widget.maxWidth,
                    height: 220,
                    color: Colors.black87,
                    child: const Icon(Icons.movie_rounded, size: 56, color: Colors.white30),
                  ),
                )
              else
                Container(
                  width: widget.maxWidth,
                  height: 220,
                  color: Colors.black87,
                  child: const Icon(Icons.movie_rounded, size: 56, color: Colors.white30),
                ),
              const Center(
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.black45,
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 34),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 10,
                child: Text(
                  ChatTimeFormat.duration(Duration(milliseconds: a.durationMs ?? 0)),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Voice / audio ─────────────────────────────────────────────────────

  Widget _buildVoice(BuildContext context, ChatAttachment a) {
    return _buildAudioBar(context, a, isVoice: true);
  }

  Widget _buildAudio(BuildContext context, ChatAttachment a) {
    return _buildAudioBar(context, a, isVoice: false);
  }

  Widget _buildAudioBar(BuildContext context, ChatAttachment a, {required bool isVoice}) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final path = _sourcePath;
              if (path == null) return;
              if (_isPlaying) {
                await _player.pause();
                setState(() => _isPlaying = false);
                return;
              }
              await _player.play(DeviceFileSource(path));
              setState(() => _isPlaying = true);
            },
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppTheme.primary(context),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isVoice
                    ? _buildWaveform(context, progress)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ChatTimeFormat.duration(_position),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '-${ChatTimeFormat.duration(_duration - _position)}',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isVoice) ...[
            const SizedBox(width: 6),
            Icon(Icons.mic_none_rounded, size: 18, color: Colors.white70),
          ] else ...[
            const SizedBox(width: 6),
            Icon(Icons.music_note_rounded, size: 18, color: Colors.white70),
          ],
        ],
      ),
    );
  }

  /// Tap/drag on the waveform to seek within the voice note.
  Widget _buildWaveform(BuildContext context, double progress) {
    final activeBars = (progress * 18).round();
    return GestureDetector(
      onTapUp: (details) => _seekTo(context, details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _seekTo(context, details.localPosition.dx),
      child: SizedBox(
        height: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(18, (i) {
            final height = 6.0 + ((i * 7) % 11);
            final active = i < activeBars;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }

  Future<void> _seekTo(BuildContext context, double dx) async {
    if (_duration.inMilliseconds <= 0) return;
    final width = 240.0 - 24 - 44 - 10 - 30; // outer padding + play btn + mic
    final ratio = (dx / width).clamp(0.0, 1.0);
    final target = Duration(milliseconds: (_duration.inMilliseconds * ratio).round());
    await _player.seek(target);
    if (mounted) setState(() => _position = target);
  }

  // ── Location ──────────────────────────────────────────────────────────

  Widget _buildLocation(BuildContext context, ChatAttachment a) {
    final lat = a.latitude;
    final lng = a.longitude;
    return GestureDetector(
      onTap: () {
        if (lat == null || lng == null) return;
        launchUrl(
          Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
          mode: LaunchMode.externalApplication,
        );
      },
      child: Container(
        width: 260,
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black,
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: Icon(Icons.map_rounded, size: 90, color: Colors.white12),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              right: 12,
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppTheme.errorRed, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      a.name.isNotEmpty ? a.name : '$lat, $lng',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contact card ──────────────────────────────────────────────────────

  Widget _buildContact(BuildContext context, ChatAttachment a) {
    final name = a.contactName ?? a.name;
    final phone = a.contactPhone;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          PeerAvatar(name: name, radius: 20, backgroundColor: AppTheme.primary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                if (phone != null && phone.isNotEmpty)
                  Text(phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                if (phone != null && phone.isNotEmpty)
                  const SizedBox(height: 8),
                if (phone != null && phone.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Save contact',
                        style: GoogleFonts.inter(
                            color: AppTheme.primary(context), fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: Colors.white, size: 20),
            onPressed: () {
              if (phone != null && phone.isNotEmpty) {
                launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Documents ─────────────────────────────────────────────────────────

  IconData _docIcon(MessageContentType t) {
    switch (t) {
      case MessageContentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case MessageContentType.word:
        return Icons.description_rounded;
      case MessageContentType.excel:
        return Icons.table_chart_rounded;
      case MessageContentType.powerpoint:
        return Icons.slideshow_rounded;
      case MessageContentType.zip:
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _docColor(MessageContentType t) {
    switch (t) {
      case MessageContentType.pdf:
        return AppTheme.errorRed;
      case MessageContentType.word:
        return const Color(0xFF3B82F6);
      case MessageContentType.excel:
        return const Color(0xFF22C55E);
      case MessageContentType.powerpoint:
        return const Color(0xFFF59E0B);
      case MessageContentType.zip:
        return const Color(0xFFEA580C);
      default:
        return AppTheme.accentPurple;
    }
  }

  Widget _buildDocument(BuildContext context, ChatAttachment a) {
    return GestureDetector(
      onTap: () => _openDocument(context, a),
      onLongPress: () => _shareDocument(context, a),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _docColor(a.type).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_docIcon(a.type), color: _docColor(a.type), size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${a.sizeBytes > 0 ? ChatTimeFormat.fileSize(a.sizeBytes) : a.fileExtension.toUpperCase()} • tap to open',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(BuildContext context, ChatAttachment a) async {
    try {
      final path = await _resolveLocalPath();
      if (path.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download the file')),
        );
        return;
      }
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        await Share.shareXFiles([XFile(path)], text: a.name);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the file')),
        );
      }
    }
  }

  Future<void> _shareDocument(BuildContext context, ChatAttachment a) async {
    final path = await _resolveLocalPath();
    if (path.isEmpty) return;
    await Share.shareXFiles([XFile(path)], text: a.name);
  }

  // ── Rich cards (attendance report / assignment / announcement) ────────

  (IconData, Color, String) _richMeta(MessageContentType t) {
    switch (t) {
      case MessageContentType.attendanceReport:
        return (Icons.assessment_rounded, AppTheme.accentTeal, 'Attendance Report');
      case MessageContentType.assignment:
        return (Icons.assignment_rounded, const Color(0xFF3B82F6), 'Assignment');
      case MessageContentType.announcement:
        return (Icons.campaign_rounded, const Color(0xFFF59E0B), 'Announcement');
      default:
        return (Icons.article_rounded, AppTheme.accentPurple, 'Message');
    }
  }

  Widget _buildRichCard(BuildContext context, ChatAttachment a) {
    final (icon, color, fallbackTitle) = _richMeta(a.type);
    final title = a.name.isNotEmpty ? a.name : fallbackTitle;
    final body = a.caption ?? '';
    return GestureDetector(
      onTap: () => _openRichCard(context, a),
      onLongPress: () => _shareRichCard(context, a),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12.5, height: 1.35)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text('View details',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _richCardText(ChatAttachment a) {
    final (_, _, fallbackTitle) = _richMeta(a.type);
    final title = a.name.isNotEmpty ? a.name : fallbackTitle;
    final body = a.caption ?? '';
    return [title, if (body.isNotEmpty) body].join('\n\n');
  }

  Future<void> _openRichCard(BuildContext context, ChatAttachment a) async {
    final (icon, color, fallbackTitle) = _richMeta(a.type);
    final title = a.name.isNotEmpty ? a.name : fallbackTitle;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.card(context),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: GoogleFonts.inter(
                            color: AppTheme.text(ctx), fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              if (a.caption?.isNotEmpty ?? false) ...[
                const SizedBox(height: 14),
                SelectableText(a.caption!,
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(ctx), fontSize: 14, height: 1.4)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _richCardText(a)));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _shareRichCard(context, a);
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareRichCard(BuildContext context, ChatAttachment a) async {
    await Share.share(_richCardText(a));
  }
}

/// Minimal full-screen media viewer for images and videos.
class _FullScreenMedia extends StatefulWidget {
  final String source;
  final bool isLocal;
  final bool isVideo;
  final String title;

  const _FullScreenMedia({
    required this.source,
    required this.isLocal,
    required this.isVideo,
    required this.title,
  });

  @override
  State<_FullScreenMedia> createState() => _FullScreenMediaState();
}

class _FullScreenMediaState extends State<_FullScreenMedia> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = widget.isLocal
          ? VideoPlayerController.file(File(widget.source))
          : VideoPlayerController.networkUrl(Uri.parse(widget.source));
      _videoController!.initialize().then((_) {
        if (mounted) setState(() {});
        _videoController!.play();
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      body: Center(
        child: widget.isVideo
            ? _buildVideo()
            : InteractiveViewer(
                child: widget.isLocal
                    ? Image.file(File(widget.source), fit: BoxFit.contain)
                    : CachedNetworkImage(
                        imageUrl: widget.source,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const CircularProgressIndicator(),
                      ),
              ),
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          controller.value.isPlaying ? controller.pause() : controller.play();
        });
      },
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            if (!controller.value.isPlaying)
              const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 64),
          ],
        ),
      ),
    );
  }
}
