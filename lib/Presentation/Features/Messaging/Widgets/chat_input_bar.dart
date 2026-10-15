import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/attachment_preview_sheet.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/attachment_sheet.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/emoji_picker_panel.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/voice_recorder.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// Premium bottom composer:
///
///   [Emoji] [Attach] [expandable field] [Camera] [Mic ⇄ Send]
///
/// - No text  → camera shortcut + hold-to-record mic.
/// - Typing   → mic becomes a send button, a toolbar (undo/redo/paste/
///   mention) + character counter appears, and a typing indicator is
///   broadcast to the backend via [onTextChanged].
/// - Field grows to six lines, supports paste, `@`-mentions with an inline
///   picker, reply preview chips and auto-focus when replying.
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final ValueChanged<ChatAttachment> onSendAttachment;
  final void Function(String path, {int? durationMs}) onSendVoice;
  final ValueChanged<String> onTextChanged;
  final ChatMessage? replyTarget;
  final VoidCallback onClearReply;
  final bool blocked;
  final List<String> mentionSuggestions;

  /// Broadcast when the local voice-note recording starts / stops, so the
  /// peer sees the realtime "Recording audio…" presence state.
  final ValueChanged<bool>? onVoiceRecording;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onSendAttachment,
    required this.onSendVoice,
    required this.onTextChanged,
    this.replyTarget,
    required this.onClearReply,
    this.blocked = false,
    this.mentionSuggestions = const [],
    this.onVoiceRecording,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final FocusNode _focusNode = FocusNode();
  late final UndoHistoryController _undoHistory;

  late final VoiceRecorderController _voice;
  bool _voiceRecordingWasOn = false;

  @override
  void initState() {
    super.initState();
    _voice = VoiceRecorderController(
      onSend: (path, {durationMs}) =>
          widget.onSendVoice(path, durationMs: durationMs),
    )..addListener(_onVoiceChanged);
    _undoHistory = UndoHistoryController()..addListener(_onUndoChanged);
  }

  void _onVoiceChanged() {
    final recording = _voice.isRecording;
    if (recording != _voiceRecordingWasOn) {
      _voiceRecordingWasOn = recording;
      widget.onVoiceRecording?.call(recording);
    }
    if (mounted) setState(() {});
  }

  void _onUndoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-focus the composer the moment a reply is queued.
    if (oldWidget.replyTarget == null && widget.replyTarget != null) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceChanged);
    _voice.dispose();
    _undoHistory.removeListener(_onUndoChanged);
    _undoHistory.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  String get _text => widget.controller.text;

  // ── Sending ───────────────────────────────────────────────────────────

  void _send() {
    final text = widget.controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    widget.controller.clear();
    widget.onTextChanged('');
    setState(() {});
  }

  void _notifyChanged(String value) {
    widget.onTextChanged(value);
    setState(() {});
  }

  // ── Voice recording ───────────────────────────────────────────────────

  Future<void> _beginVoice() async {
    if (_voice.isRecording || _voice.isPreviewing) return;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        if (status.isPermanentlyDenied) {
          await _showMicSettingsDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required for voice messages')),
          );
        }
      }
      return;
    }
    HapticService.medium();
    await _voice.startRecording();
  }

  Future<void> _showMicSettingsDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('Microphone permission denied',
            style: GoogleFonts.inter(
                color: AppTheme.text(ctx), fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          'The microphone permission was permanently denied. Enable it in system settings to record voice messages.',
          style: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not now', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary(context)),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _micControl(BuildContext context) {
    final recording = _voice.isRecording;
    final accent = ChatThemeScope.accentOf(context);
    return GestureDetector(
      onLongPressStart: (_) async => await _beginVoice(),
      onLongPressEnd: (_) => _voice.endHold(),
      onLongPressCancel: () => _voice.endHold(),
      onHorizontalDragUpdate: (d) => _voice.updateSlide(d.delta.dx),
      onHorizontalDragEnd: (_) => _voice.endHold(),
      onHorizontalDragCancel: () => _voice.endHold(),
      onTap: () async {
        if (recording) {
          _voice.endHold();
        } else {
          await _beginVoice();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          recording ? Icons.mic_rounded : Icons.mic_rounded,
          color: recording ? accent : AppTheme.textSecondary(context),
          size: 26,
        ),
      ),
    );
  }

  // ── Camera shortcut ───────────────────────────────────────────────────

  Future<void> _openCamera() async {
    HapticService.light();
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required for attachments')),
        );
      }
      return;
    }
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (result == null || !mounted) return;
    final file = File(result.path);
    widget.onSendAttachment(ChatAttachment(
      id: 'att_${DateTime.now().microsecondsSinceEpoch}',
      name: result.name,
      type: MessageContentType.image,
      mimeType: result.mimeType ?? 'image/jpeg',
      localPath: result.path,
      sizeBytes: file.lengthSync(),
    ));
  }

  // ── Paste / undo / redo / mention ─────────────────────────────

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final controller = widget.controller;
    final sel = controller.selection;
    final start = sel.isValid ? sel.start : controller.text.length;
    final end = sel.isValid ? sel.end : start;
    final newText = controller.text.replaceRange(start, end, text);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _notifyChanged(newText);
  }

  void _insertMention() {
    final controller = widget.controller;
    final pos = controller.selection.isValid
        ? controller.selection.extentOffset
        : controller.text.length;
    final newText = controller.text.replaceRange(pos, pos, '@');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + 1),
    );
    _notifyChanged(newText);
    _focusNode.requestFocus();
  }

  /// Returns the start index + query of the active `@mention` (the last
  /// `@` token before the caret), or null when none is being typed.
  (int, String)? _activeMention() {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    if (!sel.isValid) return null;
    final caret = sel.extentOffset.clamp(0, text.length);
    for (int i = caret - 1; i >= 0; i--) {
      final ch = text[i];
      if (ch == '@') {
        final prev = i == 0 ? ' ' : text[i - 1];
        if (prev != ' ' && prev != '\n') return null;
        final query = text.substring(i + 1, caret);
        if (query.contains(' ')) return null;
        return (i, query);
      }
      if (ch == ' ' || ch == '\n') return null;
    }
    return null;
  }

  void _selectMention(String name) {
    final m = _activeMention();
    if (m == null) return;
    final controller = widget.controller;
    final caret = controller.selection.isValid
        ? controller.selection.extentOffset
        : controller.text.length;
    final newText = controller.text.replaceRange(m.$1, caret, '@$name ');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: m.$1 + name.length + 2),
    );
    _notifyChanged(newText);
    _focusNode.requestFocus();
  }

  Future<void> _openAttachmentSheet() async {
    HapticService.medium();
    final attachments = await showModalBottomSheet<List<ChatAttachment>>(
      context: context,
      backgroundColor: AppTheme.card(context),
      showDragHandle: true,
      builder: (_) => const AttachmentSheet(),
    );
    if (attachments == null || attachments.isEmpty || !mounted) return;

    final confirmed = await showModalBottomSheet<List<ChatAttachment>>(
      context: context,
      backgroundColor: AppTheme.card(context),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AttachmentPreviewSheet(attachments: attachments),
    );
    if (confirmed == null || !mounted) return;

    for (final attachment in confirmed) {
      widget.onSendAttachment(attachment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ChatThemeScope.accentOf(context);
    final dark = ChatThemeScope.isDarkOf(context);
    final glass = ChatThemeScope.glassOf(context);
    final mention = _activeMention();
    final mentionQuery = (mention?.$2 ?? '').trim().toLowerCase();
    final mentionList = mention == null
        ? const <String>[]
        : widget.mentionSuggestions
            .where((s) => s.toLowerCase().contains(mentionQuery))
            .toList();

    if (widget.blocked) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Container(
          width: double.infinity,
          color: AppTheme.card(context),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.block_rounded, color: AppTheme.errorRed, size: 20),
              const SizedBox(width: 10),
              Text('You can\'t send messages to this chat',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    final bar = Container(
      color: glass
          ? AppTheme.card(context).withValues(alpha: dark ? 0.55 : 0.62)
          : AppTheme.card(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyTarget != null)
            _ReplyChip(reply: widget.replyTarget!, onCancel: widget.onClearReply),
          if (_voice.isRecording)
            VoiceRecordingBar(controller: _voice),
          if (_voice.isPreviewing)
            VoicePreviewBar(controller: _voice),
          if (mention != null && mentionList.isNotEmpty)
            _MentionPanel(
              suggestions: mentionList,
              onSelect: _selectMention,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _roundIcon(
                  context,
                  tooltip: 'Attach',
                  icon: Icons.add_rounded,
                  color: AppTheme.textSecondary(context),
                  iconSize: 26,
                  onTap: _openAttachmentSheet,
                ),
                Expanded(
                  child: _voice.isRecording
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focusNode,
                            undoController: _undoHistory,
                            onChanged: _notifyChanged,
                            onTapOutside: (_) => _focusNode.unfocus(),
                            maxLines: 6,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.inter(
                                color: AppTheme.text(context), fontSize: 14.5, height: 1.3),
                            decoration: InputDecoration(
                              hintText: 'Message',
                              hintStyle: GoogleFonts.inter(
                                  color: AppTheme.textSecondary(context), fontSize: 14.5),
                              filled: true,
                              fillColor: AppTheme.surface(context),
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: accent, width: 1.2),
                              ),
                            ),
                          ),
                        ),
                ),
                if (_voice.isRecording)
                  _micControl(context)
                else if (_hasText)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: IconButton.filled(
                      tooltip: 'Send',
                      style: IconButton.styleFrom(
                        backgroundColor: accent,
                        minimumSize: const Size(42, 42),
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _send,
                    ),
                  )
                else ...[
                  _roundIcon(
                    context,
                    tooltip: 'Camera',
                    icon: Icons.camera_alt_rounded,
                    color: AppTheme.textSecondary(context),
                    onTap: _openCamera,
                  ),
                  _micControl(context),
                ],
              ],
            ),
          ),
          if (_hasText && !_voice.isRecording && !_voice.isPreviewing)
            _buildToolbar(context),
        ],
      ),
    );

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    Widget result;
    if (glass) {
      result = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: bar,
        ),
      );
    } else {
      result = bar;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: result,
    );
  }

  Widget _roundIcon(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double iconSize = 24,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: color, size: iconSize),
      onPressed: onTap,
      splashRadius: 20,
      padding: const EdgeInsets.all(8),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final dim = AppTheme.textSecondary(context).withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
      child: Row(
        children: [
          _ToolbarChip(
              label: 'Undo',
              enabled: _undoHistory.value.canUndo,
              onTap: _undoHistory.undo),
          _ToolbarChip(
              label: 'Redo',
              enabled: _undoHistory.value.canRedo,
              onTap: _undoHistory.redo),
          _ToolbarChip(label: 'Paste', enabled: true, onTap: _paste),
          _ToolbarChip(label: 'Mention', enabled: true, onTap: _insertMention),
          const Spacer(),
          Text(
            '${_text.length}',
            style: GoogleFonts.inter(
              color: _text.length > 4000 ? AppTheme.errorRed : dim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _ToolbarChip({required this.label, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final base = AppTheme.textSecondary(context);
    return TextButton(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        foregroundColor: enabled ? base : base.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _MentionPanel extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelect;

  const _MentionPanel({required this.suggestions, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(maxHeight: 176),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.border(context)),
        itemBuilder: (context, index) {
          final name = suggestions[index];
          return InkWell(
            onTap: () => onSelect(name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primary(context).withValues(alpha: 0.15),
                    child: Icon(Icons.person_rounded, size: 16, color: AppTheme.primary(context)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('@$name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReplyChip extends StatelessWidget {
  final ChatMessage reply;
  final VoidCallback onCancel;

  const _ReplyChip({required this.reply, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final accent = ChatThemeScope.accentOf(context);
    return Container(
      color: AppTheme.surface(context),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Replying to ${reply.senderName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: accent, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text(reply.contentSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context), size: 20),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
