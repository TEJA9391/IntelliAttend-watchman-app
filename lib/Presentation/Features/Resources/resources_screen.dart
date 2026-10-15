import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/resource_model.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Resources/resources_controller.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';

class ResourcesScreen extends StatefulWidget {
  final String? courseCode;
  final String? courseName;
  const ResourcesScreen({Key? key, this.courseCode, this.courseName}) : super(key: key);

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  bool _showCollegeShared = false;
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ResourcesController>().loadResources();
    });
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.courseName ?? "Resources",
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            if (widget.courseCode != null && widget.courseCode!.isNotEmpty)
              Text(
                widget.courseCode!,
                style: GoogleFonts.inter(
                  color: AppTheme.accentTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadSheet(context),
        backgroundColor: AppTheme.accentTeal,
        icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
        label: const Text("Upload", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleBar(),
          Expanded(child: _buildResourceList()),
        ],
      ),
    );
  }

  Widget _buildToggleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showCollegeShared = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _showCollegeShared ? Colors.transparent : AppTheme.accentTeal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "My Private",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: _showCollegeShared ? AppTheme.textSecondary(context) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showCollegeShared = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _showCollegeShared ? AppTheme.accentTeal : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "College Shared",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: _showCollegeShared ? Colors.white : AppTheme.textSecondary(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceList() {
    return Consumer<ResourcesController>(
      builder: (context, controller, _) {
        final resources = _showCollegeShared ? controller.collegeResources : controller.myResources;

        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (resources.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textSecondary(context).withOpacity(0.3)),
                const SizedBox(height: 16),
                Text("No resources yet", style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text("Tap Upload to add your first resource", style: GoogleFonts.inter(color: AppTheme.textSecondary(context).withOpacity(0.6), fontSize: 13)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadResources(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: resources.length,
            itemBuilder: (context, index) {
              return _buildSwipeableCard(resources[index], controller);
            },
          ),
        );
      },
    );
  }

  // ───────── SWIPEABLE CARD WRAPPER ─────────

  Widget _buildSwipeableCard(ResourceItem resource, ResourcesController controller) {
    final bool isCollegeShared = resource.scope == 'college_shared';

    if (isCollegeShared) {
      return _buildResourceCard(resource, controller);
    }

    return Dismissible(
      key: ValueKey(resource.id),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.errorRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text("Delete", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.errorRed,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text("Delete", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      confirmDismiss: (_) => _confirmDelete(context, resource, controller),
      child: _buildResourceCard(resource, controller),
    );
  }

  Widget _buildResourceCard(ResourceItem resource, ResourcesController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icon;
    Color iconColor;
    if (resource.isPdf) {
      icon = Icons.picture_as_pdf;
      iconColor = Colors.redAccent;
    } else if (resource.isPowerpoint) {
      icon = Icons.slideshow;
      iconColor = Colors.orange;
    } else if (resource.isWord) {
      icon = Icons.description;
      iconColor = Colors.blue;
    } else if (resource.isImage) {
      icon = Icons.image;
      iconColor = Colors.green;
    } else {
      icon = Icons.insert_drive_file;
      iconColor = AppTheme.textSecondary(context);
    }

    return GestureDetector(
      onTap: () => _openResource(resource),
      onLongPressStart: (_) {
        _longPressTimer = Timer(const Duration(seconds: 3), () {
          HapticService.heavy();
          _showShareToClassSheet(context, resource, controller);
        });
      },
      onLongPressEnd: (_) => _longPressTimer?.cancel(),
      onLongPressCancel: () => _longPressTimer?.cancel(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resource.fileName, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(resource.fileSizeFormatted, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11)),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 3, height: 3, decoration: BoxDecoration(color: AppTheme.textSecondary(context), shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(resource.createdAtFormatted, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showResourceMenu(context, resource, controller),
                child: Icon(Icons.more_vert, color: AppTheme.textSecondary(context), size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────── OPEN / PREVIEW DOCUMENT ─────────

  Future<void> _openResource(ResourceItem resource) async {
    _showLoadingDialog('Opening...');
    try {
      final controller = context.read<ResourcesController>();
      final result = await controller.getPresignedUrl(resource.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      if (result['success'] == false || result['url'] == null) {
        _showErrorSnackBar(result['error']?.toString() ?? 'Unable to open file.');
        return;
      }
      final url = result['url'] as String;
      final dir = await getTemporaryDirectory();
      final tempPath = '${dir.path}/preview_${resource.id}_${resource.fileName}';

      final plainDio = Dio();
      await plainDio.download(url, tempPath);

      await OpenFilex.open(tempPath);
    } catch (e) {
      debugPrint('❌ Preview error: $e');
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorSnackBar('Unable to preview this file.');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(width: 16),
            Text(message, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ───────── THREE-DOT MENU (both tabs) ─────────

  void _showResourceMenu(BuildContext context, ResourceItem resource, ResourcesController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text(resource.fileName, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text("${resource.fileSizeFormatted} • ${resource.createdAtFormatted}", style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.accentTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.share_rounded, color: AppTheme.accentTeal, size: 20)),
                title: const Text("Share", style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareFile(context, resource, controller);
                },
              ),
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.smartphone, color: Colors.blue, size: 20)),
                title: const Text("Push to SmartBoard", style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPushToClassPicker(context, resource, controller);
                },
              ),
              if (resource.scope != 'college_shared')
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20)),
                  title: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorRed)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context, resource, controller);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ───────── SHARE FILE VIA SYSTEM SHARE SHEET ─────────

  Future<void> _shareFile(BuildContext context, ResourceItem resource, ResourcesController controller) async {
    _showLoadingDialog('Preparing file...');
    try {
      final result = await controller.getPresignedUrl(resource.id);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;
      if (result['success'] == false || result['url'] == null) {
        _showErrorSnackBar(result['error'] ?? 'Unable to share file.');
        return;
      }
      final url = result['url'] as String;
      final dir = await getTemporaryDirectory();
      final tempPath = '${dir.path}/share_${resource.id}_${resource.fileName}';
      final plainDio = Dio();
      await plainDio.download(url, tempPath);
      await Share.shareXFiles([XFile(tempPath)], text: resource.fileName);
    } catch (e) {
      debugPrint('❌ Share error: $e');
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showErrorSnackBar('Unable to share this file.');
    }
  }

  // ───────── SHARE TO CLASS (long press 3 sec) ─────────

  void _showShareToClassSheet(BuildContext context, ResourceItem resource, ResourcesController controller) {
    final classes = FacultyService.courses.value;

    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No classes assigned", style: GoogleFonts.inter()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.share_rounded, color: AppTheme.accentTeal, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Share to Class",
                      style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                resource.fileName,
                style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              ...classes.map((course) {
                final String subject = course['course'] ?? course['name'] ?? 'Unknown';
                final String code = course['code'] ?? course['id'] ?? '';
                final String section = course['section']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          code.length > 4 ? code.substring(0, 2).toUpperCase() : code.toUpperCase(),
                          style: GoogleFonts.inter(color: AppTheme.accentTeal, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                    title: Text(
                      subject,
                      style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      "$code${section.isNotEmpty ? ' • Sec $section' : ''}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11),
                    ),
                    trailing: Icon(Icons.send_rounded, color: AppTheme.accentTeal, size: 20),
                    onTap: () async {
                      Navigator.pop(ctx);
                      _pushToClass(resource, controller, code, subject);
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _pushToClass(ResourceItem resource, ResourcesController controller, String classCode, String className) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Pushing to $className ($classCode)...", style: GoogleFonts.inter()),
        backgroundColor: AppTheme.accentPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    final ok = await controller.pushToSection(resource.id, classCode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? "Shared to $className" : (controller.error ?? "Push failed"),
            style: GoogleFonts.inter(),
          ),
          backgroundColor: ok ? AppTheme.accentTeal : AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ───────── CONFIRM DELETE (swipe + menu) ─────────

  Future<bool?> _confirmDelete(BuildContext context, ResourceItem resource, ResourcesController controller) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Resource", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete '${resource.fileName}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel", style: TextStyle(color: AppTheme.textSecondary(context)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, false);
              final ok = await controller.deleteResource(resource.id);
              if (mounted) _showSnackBar(ok ? "Deleted" : controller.error ?? "Delete failed");
            },
            child: const Text("Delete", style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ───────── PUSH TO SMARTBOARD (class picker) ─────────

  void _showPushToClassPicker(BuildContext context, ResourceItem resource, ResourcesController controller) {
    final classes = FacultyService.courses.value;

    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No classes assigned", style: GoogleFonts.inter()),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final double sheetHeight = MediaQuery.of(context).size.height * 0.75;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.smartphone, color: Colors.blue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Push to SmartBoard",
                          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    resource.fileName,
                    style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: classes.length,
                      itemBuilder: (ctx, index) {
                        final course = classes[index];
                        final String subject = course['course'] ?? course['name'] ?? 'Unknown';
                        final String code = course['code'] ?? course['id'] ?? '';
                        final String section = course['section']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.bg(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border(context)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  code.length > 4 ? code.substring(0, 2).toUpperCase() : code.toUpperCase(),
                                  style: GoogleFonts.inter(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ),
                            title: Text(
                              subject,
                              style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              "$code${section.isNotEmpty ? ' • Sec $section' : ''}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11),
                            ),
                            trailing: Icon(Icons.cast_connected_rounded, color: Colors.blue, size: 20),
                            onTap: () async {
                              Navigator.pop(ctx);
                              _pushToClass(resource, controller, code, subject);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ───────── UPLOAD BOTTOM SHEET ─────────

  void _showUploadSheet(BuildContext context) {
    String? pickedFilePath;
    String? pickedFileName;
    String? pickedExtension;
    int? pickedFileSize;
    String description = '';
    String category = 'Lecture Notes';
    bool isUploading = false;
    double uploadProgress = 0.0;
    String? uploadError;

    final categories = ['Lecture Notes', 'Assignment', 'Lab Manual', 'Question Bank', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: AppTheme.accentTeal, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        "Upload Resource",
                        style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (!isUploading) ...[
                    InkWell(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'csv', 'jpg', 'jpeg', 'png', 'zip'],
                        );
                        if (result != null) {
                          setSheetState(() {
                            pickedFilePath = result.files.single.path;
                            pickedFileName = result.files.single.name;
                            pickedExtension = result.files.single.extension;
                            pickedFileSize = result.files.single.size;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: pickedFilePath != null ? AppTheme.accentTeal : AppTheme.primary(context).withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(14),
                          color: pickedFilePath != null ? AppTheme.accentTeal.withOpacity(0.05) : AppTheme.primary(context).withOpacity(0.05),
                        ),
                        child: pickedFilePath == null
                            ? Column(
                                children: [
                                  Icon(Icons.attach_file, color: AppTheme.primary(context), size: 36),
                                  const SizedBox(height: 10),
                                  Text("Choose PDF, PPT, DOC, etc.", style: GoogleFonts.inter(color: AppTheme.primary(context), fontWeight: FontWeight.w500, fontSize: 13)),
                                ],
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _getFileColor(pickedExtension).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(_getFileIcon(pickedExtension), color: _getFileColor(pickedExtension), size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(pickedFileName ?? '', style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 3),
                                        Text(
                                          "${pickedExtension?.toUpperCase() ?? ''} • ${_formatFileSize(pickedFileSize ?? 0)}",
                                          style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context), size: 20),
                                    onPressed: () => setSheetState(() {
                                      pickedFilePath = null;
                                      pickedFileName = null;
                                      pickedExtension = null;
                                      pickedFileSize = null;
                                    }),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text("Category", style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isActive = category == cat;
                        return ChoiceChip(
                          label: Text(cat, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppTheme.textSecondary(context))),
                          selected: isActive,
                          onSelected: (_) => setSheetState(() => category = cat),
                          selectedColor: AppTheme.accentTeal,
                          backgroundColor: AppTheme.bg(context),
                          side: BorderSide(color: isActive ? AppTheme.accentTeal : AppTheme.border(context)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      onChanged: (v) => description = v,
                      maxLines: 2,
                      style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Description (optional)",
                        hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 13),
                        filled: true,
                        fillColor: AppTheme.bg(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border(context))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.border(context))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.accentTeal, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    if (uploadError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(uploadError!, style: TextStyle(color: AppTheme.errorRed, fontSize: 12))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: pickedFilePath == null
                            ? null
                            : () async {
                                if (pickedFilePath == null || pickedFileName == null) {
                                  setSheetState(() {
                                    uploadError = 'No file selected';
                                  });
                                  return;
                                }

                                final facultyProfile = FacultyService.profile.value;
                                final facultyId = (facultyProfile?.facultyId.isNotEmpty == true)
                                    ? facultyProfile!.facultyId
                                    : (FirebaseAuth.instance.currentUser?.email?.toLowerCase().trim() ?? '');
                                if (facultyId.isEmpty) {
                                  setSheetState(() {
                                    uploadError = 'Missing authentication. Please login again.';
                                  });
                                  return;
                                }

                                if (category.isEmpty) {
                                  setSheetState(() {
                                    uploadError = 'Missing category';
                                  });
                                  return;
                                }

                                setSheetState(() {
                                  isUploading = true;
                                  uploadProgress = 0.0;
                                  uploadError = null;
                                });

                                final rc = context.read<ResourcesController>();
                                final ok = await rc.uploadResource(
                                  filePath: pickedFilePath!,
                                  fileName: pickedFileName!,
                                  facultyId: facultyId,
                                  courseId: widget.courseCode,
                                  category: category,
                                  description: description.isNotEmpty ? description : null,
                                );
                                if (ok) {
                                  Navigator.pop(ctx);
                                  _showSnackBar("Uploaded successfully");
                                } else {
                                  setSheetState(() {
                                    isUploading = false;
                                    uploadProgress = 0.0;
                                    uploadError = rc.error ?? "Upload failed";
                                  });
                                }
                              },
                        icon: Icon(pickedFilePath == null ? Icons.cloud_upload_outlined : Icons.cloud_upload, color: Colors.white, size: 20),
                        label: Text(pickedFilePath == null ? "Select a file first" : "Upload", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pickedFilePath == null ? Colors.grey : AppTheme.accentTeal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: uploadProgress > 0 ? uploadProgress : null,
                                  strokeWidth: 5,
                                  color: AppTheme.accentTeal,
                                  backgroundColor: AppTheme.border(context),
                                ),
                                Text(
                                  "${(uploadProgress * 100).toInt()}%",
                                  style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text("Uploading to Faculty Cloud...", style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: uploadProgress > 0 ? uploadProgress : null,
                              backgroundColor: AppTheme.accentTeal.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Color _getFileColor(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf': return Colors.redAccent;
      case 'ppt':
      case 'pptx': return Colors.orange;
      case 'doc':
      case 'docx': return Colors.blue;
      case 'xls':
      case 'xlsx': return Colors.green;
      default: return AppTheme.textSecondary(context);
    }
  }

  IconData _getFileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'ppt':
      case 'pptx': return Icons.slideshow;
      case 'doc':
      case 'docx': return Icons.description;
      case 'xls':
      case 'xlsx': return Icons.table_chart;
      default: return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
