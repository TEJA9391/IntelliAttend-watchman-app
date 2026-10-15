import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/security_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Students/student_directory_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/realtime_attendance_page.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Resources/resources_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Support/live_support_chat_page.dart';
import 'package:intelli_attend_faculty/Services/attendance_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Theme/theme_controller.dart';

class AppDrawer extends StatefulWidget {
  final String facultyName;
  final String facultyRole;
  final String? profileImage;
  final VoidCallback? onLogout;
  final VoidCallback? onEmergencySOS;
  final VoidCallback? onApplyLeave;
  final VoidCallback? onBroadcast;
  final VoidCallback? onCreateAssignment;
  final VoidCallback? onSubmissions;
  final VoidCallback? onSettings;

  const AppDrawer({
    Key? key,
    required this.facultyName,
    required this.facultyRole,
    this.profileImage,
    this.onLogout,
    this.onEmergencySOS,
    this.onApplyLeave,
    this.onBroadcast,
    this.onCreateAssignment,
    this.onSubmissions,
    this.onSettings,
  }) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surface(context),
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProfileHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSectionLabel("ACADEMICS"),
                ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: FacultyService.courses,
                    builder: (context, courses, child) {
                      int totalEnrollment = 0;
                      for (var c in courses) {
                        totalEnrollment += (c['enrollment'] as int? ?? 0);
                      }
                      return _buildMenuItem(
                        context,
                        Icons.people_alt_rounded,
                        "Student Directory",
                        () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDirectoryScreen()));
                        },
                        subtitle: "$totalEnrollment Enrolled Students",
                      );
                    }),
                ValueListenableBuilder<String?>(
                    valueListenable: AttendanceService().liveCourseName,
                    builder: (context, liveCourse, child) {
                      final bool isLive = liveCourse != null;
                      return _buildMenuItem(
                        context,
                        Icons.check_circle_rounded,
                        isLive ? "Live Attendance" : "Attendance Manager",
                        () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => RealtimeAttendancePage(courseName: liveCourse ?? "General Attendance", section: "A")));
                        },
                        subtitle: isLive ? "Active: $liveCourse" : "Start or review sessions",
                        trailing: isLive ? _buildStatusBadge("LIVE", AppTheme.errorRed) : null,
                      );
                    }),
                
                const Divider(indent: 24, endIndent: 24, height: 40),
                _buildSectionLabel("CONTENT"),
                _buildMenuItem(context, Icons.folder_rounded, "Resources",
                    () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ResourcesScreen()));
                }, subtitle: "Upload & manage materials"),
                _buildMenuItem(context, Icons.assignment_rounded, "Create Assignment",
                    () {
                  Navigator.pop(context);
                  if (widget.onCreateAssignment != null) widget.onCreateAssignment!();
                }),
                _buildMenuItem(context, Icons.cloud_upload_rounded, "Submissions", () {
                  Navigator.pop(context);
                  if (widget.onSubmissions != null) widget.onSubmissions!();
                }),
                
                const Divider(indent: 24, endIndent: 24, height: 40),
                _buildSectionLabel("SECURITY & CLOUD"),
                _buildMenuItem(
                  context,
                  Icons.devices_other_rounded,
                  "Device Management",
                  () => _showDevicesDialog(context),
                  trailing: _buildStatusBadge("SECURE", AppTheme.accentTeal),
                ),
                _buildMenuItem(context, Icons.psychology_rounded, "AI Faculty Assistant", () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveSupportChatPage()));
                }),
                
                const Divider(indent: 24, endIndent: 24, height: 40),
                _buildSectionLabel("PREFERENCES"),
                _buildMenuItem(context, Icons.settings_suggest_rounded, "App Settings", () {
                  Navigator.pop(context);
                  if (widget.onSettings != null) widget.onSettings!();
                }),
                const Divider(indent: 24, endIndent: 24, height: 40),
                _buildSectionLabel("THEME"),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.themeMode,
                  builder: (context, mode, _) {
                    final bool isDark = mode == ThemeMode.dark;
                    return _buildMenuItem(
                      context,
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                      () {
                        ThemeController.toggle();
                      },
                      subtitle: "Currently: ${isDark ? 'Dark' : 'Light'}",
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // Branding at bottom
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "IntelliAttend",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.accentTeal,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        "WATCHMAN EDITION",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.accentTeal.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildBottomLogout(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 70, bottom: 32, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: AppTheme.accentTeal,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white12,
              backgroundImage: (widget.profileImage?.startsWith('http') ?? false)
                  ? NetworkImage(widget.profileImage!) as ImageProvider
                  : (widget.profileImage != null ? FileImage(File(widget.profileImage!)) : null),
              child: widget.profileImage == null ? const Icon(Icons.person, size: 36, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.facultyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
                Text(
                  widget.facultyRole,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded, color: AppTheme.highlightLime, size: 12),
                      SizedBox(width: 6),
                      Text("VERIFIED FACULTY", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 24, 12),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.slate500(context).withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap,
      {Color? iconColor, String? subtitle, Widget? trailing}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? AppTheme.accentTeal).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? AppTheme.accentTeal, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppTheme.text(context), fontSize: 15, fontWeight: FontWeight.bold),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 12))
          : null,
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.border(context)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: onTap,
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildBottomLogout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border(context)))),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (widget.onLogout != null) widget.onLogout!();
        },
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.errorRed, size: 22),
            SizedBox(width: 16),
            Flexible(
              child: Text("Sign Out", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.errorRed, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDevicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: AppTheme.accentTeal),
            SizedBox(width: 12),
            Flexible(child: Text("Active Sessions", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ValueListenableBuilder<List<DeviceInfo>>(
            valueListenable: SecurityService().activeDevices,
            builder: (context, devices, child) {
              return ListView.separated(
                shrinkWrap: true,
                itemCount: devices.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final d = devices[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.smartphone_rounded, color: d.isCurrent ? AppTheme.accentTeal : Colors.grey),
                    title: Text(d.deviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text("${d.location} • ${d.lastActive}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                    trailing: d.isCurrent
                        ? _buildStatusBadge("CURRENT", AppTheme.accentTeal)
                        : TextButton(
                            onPressed: () => SecurityService().logoutDevice(d.id),
                            child: const Text("REVOKE", style: TextStyle(color: AppTheme.errorRed, fontSize: 12, fontWeight: FontWeight.bold))),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("DONE"))],
      ),
    );
  }
}
