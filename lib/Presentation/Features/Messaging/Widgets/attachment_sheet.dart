import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

/// Professional attach sheet with a staggered animated grid of 11 options:
/// Camera, Gallery, PDF, Document, Assignment, Attendance Report, Excel,
/// PowerPoint, ZIP, Location and Contact. Picks real files / builds rich
/// cards and pops with the resulting `List<ChatAttachment>`.
class AttachmentSheet extends StatefulWidget {
  const AttachmentSheet({super.key});

  @override
  State<AttachmentSheet> createState() => _AttachmentSheetState();
}

class _AttachmentSheetState extends State<AttachmentSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  )..forward();

  static const int _columns = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Picker actions ────────────────────────────────────────────────────

  Future<void> _pickCamera() async {
    final granted = await _ensurePermission(Permission.camera, 'Camera');
    if (!granted || !mounted) return;
    HapticService.medium();
    final result =
        await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2560);
    if (result == null || !mounted) return;
    _deliver([_attachmentFromXFile(result, MessageContentType.image)]);
  }

  Future<void> _pickGallery() async {
    HapticService.medium();
    final results = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2560);
    if (results.isEmpty || !mounted) return;
    _deliver([for (final r in results) _attachmentFromXFile(r, MessageContentType.image)]);
  }

  Future<void> _pickPdf() => _pickFiles(
        ['pdf'],
        MessageContentType.pdf,
        'application/pdf',
      );

  Future<void> _pickExcel() => _pickFiles(
        ['xls', 'xlsx'],
        MessageContentType.excel,
        'application/octet-stream',
      );

  Future<void> _pickPowerPoint() => _pickFiles(
        ['ppt', 'pptx'],
        MessageContentType.powerpoint,
        'application/octet-stream',
      );

  Future<void> _pickZip() => _pickFiles(
        ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz'],
        MessageContentType.zip,
        'application/zip',
      );

  Future<void> _pickDocument() async {
    HapticService.medium();
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    final attachments = <ChatAttachment>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null) continue;
      final ext = file.extension?.toLowerCase() ?? '';
      attachments.add(ChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}_${file.name}',
        name: file.name,
        type: _typeFromExtension(ext),
        mimeType: _mimeFromExtension(ext),
        localPath: path,
        sizeBytes: _safeSize(path),
      ));
    }
    _deliver(attachments);
  }

  Future<void> _pickFiles(
      List<String> extensions, MessageContentType type, String mime) async {
    HapticService.medium();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    final file = (result == null || result.files.isEmpty) ? null : result.files.first;
    if (file == null || file.path == null || !mounted) return;
    _deliver([
      ChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        name: file.name,
        type: type,
        mimeType: mime,
        localPath: file.path,
        sizeBytes: _safeSize(file.path!),
      ),
    ]);
  }

  // ── Rich card builders ────────────────────────────────────────────────

  Future<void> _addContact() async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final data = await _showFormDialog(
      title: 'Share contact',
      fields: [
        (controller: nameC, label: 'Contact name', hint: 'e.g. Ravi Kumar'),
        (controller: phoneC, label: 'Phone number', hint: 'e.g. +91 98765 43210'),
      ],
    );
    if (data == null || !mounted) return;
    final name = data[0].trim();
    if (name.isEmpty) return;
    _deliver([
      ChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        type: MessageContentType.contact,
        contactName: name,
        contactPhone: data[1].trim(),
      ),
    ]);
  }

  Future<void> _addAttendanceReport() async {
    final noteC = TextEditingController();
    final data = await _showFormDialog(
      title: 'Attendance report',
      fields: [
        (controller: noteC, label: 'Summary', hint: 'e.g. 45 / 50 present (90%)'),
      ],
    );
    if (data == null || !mounted) return;
    _deliver([
      ChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        name: 'Attendance Report',
        type: MessageContentType.attendanceReport,
        caption: data[0].trim(),
      ),
    ]);
  }

  Future<void> _addAssignment() async {
    final titleC = TextEditingController();
    final bodyC = TextEditingController();
    final data = await _showFormDialog(
      title: 'Send assignment',
      fields: [
        (controller: titleC, label: 'Title', hint: 'e.g. Unit 2 exercises'),
        (controller: bodyC, label: 'Description', hint: 'e.g. Submit by Friday 5 PM'),
      ],
    );
    if (data == null || !mounted) return;
    final title = data[0].trim();
    if (title.isEmpty) return;
    _deliver([
      ChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        name: title,
        type: MessageContentType.assignment,
        caption: data[1].trim(),
      ),
    ]);
  }

  Future<void> _shareLocation() async {
    final controller = TextEditingController(text: 'IntelliAttend');
    final coords = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('Share location',
            style: GoogleFonts.inter(
                color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Location name or address',
            hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 14),
          ),
          style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary(context)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (coords == null || !mounted) return;
    _deliver([
      ChatAttachment(
        id: 'att_${DateTime.now().microsecondsSinceEpoch}',
        name: coords,
        type: MessageContentType.location,
      ),
    ]);
  }

  Future<List<String>?> _showFormDialog({
    required String title,
    required List<({TextEditingController controller, String label, String hint})> fields,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text(title,
            style: GoogleFonts.inter(
                color: AppTheme.text(ctx), fontSize: 17, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: f.controller,
                  keyboardType: f.label.contains('phone') ? TextInputType.phone : TextInputType.multiline,
                  maxLines: f.label == 'Summary' || f.label == 'Description' ? 3 : 1,
                  decoration: InputDecoration(
                    labelText: f.label,
                    hintText: f.hint,
                    hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(ctx), fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border(ctx)),
                    ),
                  ),
                  style: GoogleFonts.inter(color: AppTheme.text(ctx), fontSize: 14),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary(ctx))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, [for (final f in fields) f.controller.text]),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary(context)),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // ── Permissions ───────────────────────────────────────────────────────

  Future<bool> _ensurePermission(Permission permission, String label) async {
    final status = await permission.request();
    if (status.isGranted) return true;
    if (mounted) {
      if (status.isPermanentlyDenied) {
        await _showSettingsDialog(label);
      } else {
        _showPermissionSnack(label);
      }
    }
    return false;
  }

  Future<void> _showSettingsDialog(String label) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(ctx),
        title: Text('$label permission denied',
            style: GoogleFonts.inter(
                color: AppTheme.text(ctx), fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          'The $label permission was permanently denied. Enable it in system settings to continue.',
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

  void _showPermissionSnack(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label permission is required for attachments')),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _deliver(List<ChatAttachment> attachments) {
    if (!mounted || attachments.isEmpty) return;
    HapticService.selection();
    Navigator.pop(context, attachments);
  }

  ChatAttachment _attachmentFromXFile(XFile file, MessageContentType type) {
    return ChatAttachment(
      id: 'att_${DateTime.now().microsecondsSinceEpoch}_${file.name}',
      name: file.name,
      type: type,
      mimeType: file.mimeType ?? 'image/jpeg',
      localPath: file.path,
      sizeBytes: _safeSize(file.path),
    );
  }

  int _safeSize(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  MessageContentType _typeFromExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return MessageContentType.pdf;
      case 'doc':
      case 'docx':
        return MessageContentType.word;
      case 'xls':
      case 'xlsx':
        return MessageContentType.excel;
      case 'ppt':
      case 'pptx':
        return MessageContentType.powerpoint;
      case 'mp3':
      case 'wav':
      case 'm4a':
      case 'aac':
        return MessageContentType.audio;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return MessageContentType.image;
      case 'mp4':
      case 'mov':
      case 'mkv':
        return MessageContentType.video;
      default:
        return MessageContentType.document;
    }
  }

  String _mimeFromExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final options = <({IconData icon, String label, Color color, VoidCallback onTap})>[
      (icon: Icons.camera_alt_outlined, label: 'Camera', color: const Color(0xFF8B5CF6), onTap: _pickCamera),
      (icon: Icons.photo_library_outlined, label: 'Gallery', color: const Color(0xFF2DD4BF), onTap: _pickGallery),
      (icon: Icons.picture_as_pdf_outlined, label: 'PDF', color: const Color(0xFFEF4444), onTap: _pickPdf),
      (icon: Icons.description_outlined, label: 'Document', color: const Color(0xFF3B82F6), onTap: _pickDocument),
      (icon: Icons.assignment_outlined, label: 'Assignment', color: const Color(0xFF6366F1), onTap: _addAssignment),
      (icon: Icons.assessment_outlined, label: 'Attendance Report', color: const Color(0xFF10B981), onTap: _addAttendanceReport),
      (icon: Icons.grid_on_rounded, label: 'Excel', color: const Color(0xFF22C55E), onTap: _pickExcel),
      (icon: Icons.slideshow_outlined, label: 'PowerPoint', color: const Color(0xFFF97316), onTap: _pickPowerPoint),
      (icon: Icons.folder_zip_outlined, label: 'ZIP', color: const Color(0xFFEA580C), onTap: _pickZip),
      (icon: Icons.location_on_outlined, label: 'Location', color: const Color(0xFF0EA5E9), onTap: _shareLocation),
      (icon: Icons.person_add_alt_1_rounded, label: 'Contact', color: const Color(0xFFEC4899), onTap: _addContact),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeTransition(
              opacity: CurvedAnimation(parent: _controller, curve: const Interval(0, 0.35)),
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add attachment',
                        style: GoogleFonts.inter(
                            color: AppTheme.text(context), fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Share files, media and more',
                        style: GoogleFonts.inter(
                            color: AppTheme.textSecondary(context), fontSize: 12.5)),
                  ],
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: _columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 0.9,
              children: [
                for (var i = 0; i < options.length; i++)
                  _StaggeredTile(
                    controller: _controller,
                    index: i,
                    total: options.length,
                    icon: options[i].icon,
                    label: options[i].label,
                    color: options[i].color,
                    onTap: options[i].onTap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A grid cell that fades, slides up and scales in with a per-item stagger.
class _StaggeredTile extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int total;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _StaggeredTile({
    required this.controller,
    required this.index,
    required this.total,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = 0.10 + (index / total) * 0.60;
    final end = (start + 0.45).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, (1 - animation.value) * 26),
          child: Transform.scale(
            scale: 0.9 + 0.1 * animation.value,
            child: child,
          ),
        ),
      ),
      child: _tile(context),
    );
  }

  Widget _tile(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: color, size: 27),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: AppTheme.text(context), fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
