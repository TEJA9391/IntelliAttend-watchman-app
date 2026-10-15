import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// Preview shown before an attachment is sent. Lets the user review each
/// picked item (image, file, rich card, location or contact), add a caption
/// and either send or discard. Pops with `List<ChatAttachment>` on send or
/// `null` on cancel.
class AttachmentPreviewSheet extends StatefulWidget {
  final List<ChatAttachment> attachments;

  const AttachmentPreviewSheet({super.key, required this.attachments});

  @override
  State<AttachmentPreviewSheet> createState() => _AttachmentPreviewSheetState();
}

class _AttachmentPreviewSheetState extends State<AttachmentPreviewSheet> {
  final TextEditingController _caption = TextEditingController();
  final PageController _page = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final firstCaption = widget.attachments.firstOrNull?.caption ?? '';
    if (firstCaption.isNotEmpty) {
      _caption.text = firstCaption;
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _page.dispose();
    super.dispose();
  }

  void _send() {
    final caption = _caption.text.trim();
    final result = caption.isEmpty
        ? widget.attachments
        : [for (final a in widget.attachments) a.copyWith(caption: caption)];
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.attachments.length;
    final accent = AppTheme.primary(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Preview',
                    style: GoogleFonts.inter(
                        color: AppTheme.text(context), fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (count > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_index + 1} of $count',
                        style: GoogleFonts.inter(
                            color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (count > 1) ...[
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: count,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _Thumb(
                    attachment: widget.attachments[i],
                    selected: i == _index,
                    onTap: () => _page.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              height: 270,
              child: PageView.builder(
                controller: _page,
                itemCount: count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  child: _PreviewItem(attachment: widget.attachments[i], key: ValueKey(i)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _caption,
              maxLength: 140,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add a caption…',
                counterText: '',
                hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14),
                filled: true,
                fillColor: AppTheme.surface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary(context),
                      side: BorderSide(color: AppTheme.border(context)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: Text(count > 1 ? 'Send $count items' : 'Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The actual preview surface for a single attachment.
class _PreviewItem extends StatelessWidget {
  final ChatAttachment attachment;

  const _PreviewItem({required this.attachment, super.key});

  @override
  Widget build(BuildContext context) {
    switch (attachment.type) {
      case MessageContentType.image:
        return _imagePreview(context);
      case MessageContentType.location:
        return _locationPreview(context);
      case MessageContentType.contact:
        return _contactPreview(context);
      case MessageContentType.assignment:
      case MessageContentType.attendanceReport:
        return _richCardPreview(context);
      default:
        return _filePreview(context);
    }
  }

  Widget _imagePreview(BuildContext context) {
    final path = attachment.localPath;
    if (path == null || !File(path).existsSync()) {
      return _filePreview(context);
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, __, ___) => _filePreview(context),
          ),
        ),
      ),
    );
  }

  Widget _filePreview(BuildContext context) {
    final color = _typeColor(attachment.type);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context).withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(_typeIcon(attachment.type), color: color, size: 42),
              ),
              const SizedBox(height: 16),
              Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppTheme.text(context), fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _fileMeta(attachment),
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationPreview(BuildContext context) {
    return _infoCard(
      context,
      icon: Icons.location_on_rounded,
      color: const Color(0xFF0EA5E9),
      title: attachment.name,
      subtitle: 'Shared location',
    );
  }

  Widget _contactPreview(BuildContext context) {
    final phone = attachment.contactPhone?.trim() ?? '';
    return _infoCard(
      context,
      icon: Icons.person_rounded,
      color: const Color(0xFFEC4899),
      title: attachment.contactName ?? attachment.name,
      subtitle: phone.isEmpty ? 'Contact' : phone,
    );
  }

  Widget _richCardPreview(BuildContext context) {
    final color = _typeColor(attachment.type);
    return _infoCard(
      context,
      icon: _typeIcon(attachment.type),
      color: color,
      title: attachment.name,
      subtitle: attachment.caption?.trim().isNotEmpty == true
          ? attachment.caption!
          : _typeLabel(attachment.type),
      large: true,
    );
  }

  Widget _infoCard(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      bool large = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context).withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: color, size: 38),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: large ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context), fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fileMeta(ChatAttachment a) {
    final size = _formatSize(a.sizeBytes);
    final label = _typeLabel(a.type);
    final meta = [if (label.isNotEmpty) label, if (size.isNotEmpty) size];
    return meta.join(' · ');
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  String _typeLabel(MessageContentType type) {
    switch (type) {
      case MessageContentType.pdf:
        return 'PDF';
      case MessageContentType.word:
        return 'Word document';
      case MessageContentType.excel:
        return 'Excel spreadsheet';
      case MessageContentType.powerpoint:
        return 'PowerPoint presentation';
      case MessageContentType.zip:
        return 'Archive';
      case MessageContentType.document:
        return 'Document';
      case MessageContentType.audio:
        return 'Audio';
      case MessageContentType.video:
        return 'Video';
      case MessageContentType.assignment:
        return 'Assignment';
      case MessageContentType.attendanceReport:
        return 'Attendance Report';
      default:
        return '';
    }
  }

  Color _typeColor(MessageContentType type) {
    switch (type) {
      case MessageContentType.pdf:
        return const Color(0xFFEF4444);
      case MessageContentType.word:
        return const Color(0xFF3B82F6);
      case MessageContentType.excel:
        return const Color(0xFF22C55E);
      case MessageContentType.powerpoint:
        return const Color(0xFFF97316);
      case MessageContentType.zip:
        return const Color(0xFFEA580C);
      case MessageContentType.video:
        return const Color(0xFF8B5CF6);
      case MessageContentType.audio:
        return const Color(0xFF0EA5E9);
      case MessageContentType.assignment:
        return const Color(0xFF6366F1);
      case MessageContentType.attendanceReport:
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _typeIcon(MessageContentType type) {
    switch (type) {
      case MessageContentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case MessageContentType.word:
        return Icons.description_rounded;
      case MessageContentType.excel:
        return Icons.grid_on_rounded;
      case MessageContentType.powerpoint:
        return Icons.slideshow_rounded;
      case MessageContentType.zip:
        return Icons.folder_zip_rounded;
      case MessageContentType.video:
        return Icons.videocam_rounded;
      case MessageContentType.audio:
        return Icons.music_note_rounded;
      case MessageContentType.assignment:
        return Icons.assignment_rounded;
      case MessageContentType.attendanceReport:
        return Icons.assessment_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

/// Small thumbnail in the top strip for multi-item sends.
class _Thumb extends StatelessWidget {
  final ChatAttachment attachment;
  final bool selected;
  final VoidCallback onTap;

  const _Thumb({
    required this.attachment,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.primary(context);
    final isImage = attachment.type == MessageContentType.image &&
        attachment.localPath != null &&
        File(attachment.localPath!).existsSync();
    final child = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _thumbColor(context, isImage),
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: accent, width: 2.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: isImage
          ? Image.file(File(attachment.localPath!), fit: BoxFit.cover)
          : Icon(_thumbIcon(attachment.type),
              size: 24, color: _thumbIconColor(attachment.type)),
    );
    return GestureDetector(onTap: onTap, child: child);
  }

  Color _thumbColor(BuildContext context, bool isImage) {
    if (isImage) return Colors.black;
    final c = _thumbIconColor(attachment.type);
    return c.withValues(alpha: 0.14);
  }

  Color _thumbIconColor(MessageContentType type) {
    switch (type) {
      case MessageContentType.pdf:
        return const Color(0xFFEF4444);
      case MessageContentType.excel:
        return const Color(0xFF22C55E);
      case MessageContentType.powerpoint:
        return const Color(0xFFF97316);
      case MessageContentType.zip:
        return const Color(0xFFEA580C);
      case MessageContentType.location:
        return const Color(0xFF0EA5E9);
      case MessageContentType.contact:
        return const Color(0xFFEC4899);
      case MessageContentType.assignment:
        return const Color(0xFF6366F1);
      case MessageContentType.attendanceReport:
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _thumbIcon(MessageContentType type) {
    switch (type) {
      case MessageContentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case MessageContentType.excel:
        return Icons.grid_on_rounded;
      case MessageContentType.powerpoint:
        return Icons.slideshow_rounded;
      case MessageContentType.zip:
        return Icons.folder_zip_rounded;
      case MessageContentType.location:
        return Icons.location_on_rounded;
      case MessageContentType.contact:
        return Icons.person_rounded;
      case MessageContentType.assignment:
        return Icons.assignment_rounded;
      case MessageContentType.attendanceReport:
        return Icons.assessment_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
