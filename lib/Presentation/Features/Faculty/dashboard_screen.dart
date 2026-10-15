import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Repositories/auth_repository.dart';
import 'package:intelli_attend_faculty/Presentation/Widgets/custom_sliding_nav_bar.dart';
import 'package:intelli_attend_faculty/Presentation/Widgets/app_drawer.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Auth/login_screen.dart';
import 'dashboard_controller.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Courses/courses_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Resources/resources_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/my_class/my_class_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Profile/profile_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Profile/qr_scanner_screen.dart';
import 'settings/settings_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Assignments/create_assignment_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Assignments/submissions_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/faculty_timetable_screen.dart';

// Modular Components
import 'components/dashboard_header.dart';
import 'components/session_control_section.dart';
import 'components/schedule_section.dart';
import 'components/dashboard_sections.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Watchman/watchman_dashboard_view.dart';
import 'package:intelli_attend_faculty/Services/id_card_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<WatchmanDashboardViewState> _watchmanKey = GlobalKey<WatchmanDashboardViewState>();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await FacultyService.load();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  void _showCreateAssignment() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAssignmentScreen()));
  }

  void _showSubmissions() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmissionsScreen()));
  }

  void _showSettings() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SettingsScreen(onBackPressed: () => Navigator.pop(context)),
    ));
  }

  void _handleLogout() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Authentication is disabled for Watchman App.')),
    );
  }

  void _loadDashboardData() {
    if (mounted) {
      context.read<DashboardController>().refreshData();
    }
  }


  Future<void> _openQRScanner() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      final code = result['value'] as String? ?? '';
      if (code.isEmpty) return;

      debugPrint('🔍 [WATCHMAN_SCAN] Raw code scanned: "$code"');
      final info = await IdCardService.verifyBarcodeWithServer(code);
      debugPrint('🔍 [WATCHMAN_SCAN] Parsed: id=${info.id}, name=${info.name}, valid=${info.isValid}, isServer=${info.isServerVerified}, source=${info.verificationSource}');

      if (!mounted) return;

      if (info.isValid) {
        _watchmanKey.currentState?.addVerifiedScan(info);
      }
      _showScanResultSheet(info);
    }
  }

  void _showScanResultSheet(IdCardInfo info) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final timeStr = "${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.border(context), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              if (!info.isValid) ...[
                // ── REJECTION: INVALID ID CARD ──
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    color: Color(0xFFEF4444),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Access Denied',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unrecognized Barcode',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1518) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          Text(
                            'GATE POLICY ENFORCED',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEF4444),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scanned Barcode: ${info.id}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This scanner only accepts registered Student and Faculty ID cards. Visitors must obtain a designated Visitor Pass from Security.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // ── SUCCESS: AUTHENTIC STUDENT / FACULTY ID CARD ──
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181D) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: info.type == 'Student'
                          ? const Color(0xFF00D2B4).withOpacity(0.35)
                          : const Color(0xFF10B981).withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      // ID Card Top Banner (Golden Header matching college ID)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: info.type == 'Student'
                              ? const Color(0xFFF59E0B).withOpacity(0.18)
                              : const Color(0xFF10B981).withOpacity(0.18),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  info.type == 'Student'
                                      ? Icons.badge_outlined
                                      : Icons.verified_user_rounded,
                                  size: 16,
                                  color: info.type == 'Student'
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  info.type == 'Student'
                                      ? 'STUDENT IDENTITY CARD'
                                      : 'FACULTY IDENTITY CARD',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: info.type == 'Student'
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: (info.isServerVerified ? const Color(0xFF00D2B4) : const Color(0xFF6366F1)).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    info.isServerVerified ? Icons.cloud_done_rounded : Icons.offline_pin_rounded,
                                    size: 11,
                                    color: info.isServerVerified ? const Color(0xFF00D2B4) : const Color(0xFF6366F1),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    info.isServerVerified ? 'SERVER VERIFIED' : 'GATE VERIFIED',
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: info.isServerVerified ? const Color(0xFF00D2B4) : const Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Institution
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          'Malla Reddy College of Engineering & Technology (MRCET)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Student Details Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Student Avatar / Photo
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: info.statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: info.statusColor.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  info.name.isNotEmpty ? info.name[0].toUpperCase() : 'S',
                                  style: GoogleFonts.inter(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: info.statusColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Name & Roll No
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    info.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      info.id,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF00D2B4) : const Color(0xFF0D9488),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      const Divider(height: 1),

                      // Key Metadata Fields
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          children: [
                            _buildCardMetaRow('Scan Action', info.isEntry ? '1st Scan: ENTRY (IN)' : '2nd Scan: EXIT (OUT)', isDark, highlight: true),
                            _buildCardMetaRow('Verification', info.verificationSource, isDark, highlight: true),
                            if (info.serverStatusNote != null)
                              _buildCardMetaRow('Server Record', info.serverStatusNote!, isDark),
                            _buildCardMetaRow('Program / Degree', info.program, isDark),
                            _buildCardMetaRow('Branch / Dept', info.branchOrDept, isDark),
                            _buildCardMetaRow('Batch & Year', '${info.batch} (${info.academicYear})', isDark),
                            _buildCardMetaRow('Admission Type', info.admissionType, isDark),
                            if (info.seatOrRoll.isNotEmpty)
                              _buildCardMetaRow('Seat / Roll', info.seatOrRoll, isDark),
                            if (info.dob != null)
                              _buildCardMetaRow('D.O.Birth', info.dob!, isDark),
                            if (info.bloodGroup != null)
                              _buildCardMetaRow('Blood Group', info.bloodGroup!, isDark),
                            if (info.emergencyContact != null)
                              _buildCardMetaRow('Contact Info', info.emergencyContact!, isDark),
                            _buildCardMetaRow('Gate Location', 'Main Gate #1', isDark),
                            _buildCardMetaRow('Status Timestamp', '$timeStr • ${info.isEntry ? 'Inside Campus' : 'Exited Campus'}', isDark, highlight: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: AppTheme.border(context)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D2B4),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openQRScanner();
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: Text(
                        'Scan Next',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardMetaRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: highlight
                  ? const Color(0xFF00D2B4)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color navBgColor = isDark ? const Color(0xFF16161A) : Colors.white;

    final systemOverlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: navBgColor,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlay,
      child: Consumer<DashboardController>(
        builder: (context, controller, child) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppTheme.bg(context),
            drawer: ValueListenableBuilder<FacultyProfile?>(
              valueListenable: FacultyService.profile,
              builder: (context, profile, _) => AppDrawer(
                facultyName: profile?.name ?? '',
                facultyRole: profile?.designation ?? '',
                profileImage: profile?.profileImage,
                onLogout: _handleLogout,
                onCreateAssignment: _showCreateAssignment,
                onSubmissions: _showSubmissions,
                onSettings: _showSettings,
              ),
            ),
            body: IndexedStack(
              index: _currentIndex,
              children: [
                WatchmanDashboardView(
                  key: _watchmanKey,
                  onOpenScanner: _openQRScanner,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const ProfileScreen(),
              ],
            ),
            bottomNavigationBar: CustomSlidingNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index == 0) {
                  _loadDashboardData();
                  setState(() => _currentIndex = 0);
                } else if (index == 1) {
                  _openQRScanner();
                } else if (index == 2) {
                  setState(() => _currentIndex = 1);
                }
              },
            ),
          );
        },
      ),
    );
  }

  static void _showProfileModalStatic(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ProfileModalContent(),
    );
  }

  void _showProfileModal(BuildContext context) => _showProfileModalStatic(context);
}

class ProfileModalContent extends StatelessWidget {
  const ProfileModalContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ValueListenableBuilder<FacultyProfile?>(
        valueListenable: FacultyService.profile,
        builder: (context, profile, _) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.text(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.2), width: 2),
                    ),
                    child: Builder(
                      builder: (context) {
                        final imageUrl = profile?.profileImage;
                        return CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.transparent,
                          backgroundImage: imageUrl != null 
                            ? (imageUrl.startsWith('http') 
                                ? NetworkImage(imageUrl) 
                                : FileImage(File(imageUrl)) as ImageProvider)
                            : const NetworkImage("https://ui-avatars.com/api/?name=Faculty+User&background=2DD4BF&color=000"),
                        );
                      }
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'Faculty User',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.text(context),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          profile?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildProfileInfoRow(context, Icons.badge_outlined, "Employee Code", profile?.email?.split('@')[0].toUpperCase() ?? 'N/A'),
              _buildProfileInfoRow(context, Icons.business_outlined, "Primary Dept", profile?.department ?? 'N/A'),
              _buildProfileInfoRow(context, Icons.work_outline_rounded, "Designation", profile?.designation ?? 'Faculty'),
              _buildProfileInfoRow(context, Icons.history_edu_rounded, "Experience", "8+ Years"),
              _buildProfileInfoRow(context, Icons.star_outline_rounded, "Rating", "4.9/5.0"),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.accentTeal),
          const SizedBox(width: 16),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value, 
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class MainDashboardView extends StatefulWidget {
  const MainDashboardView({Key? key}) : super(key: key);

  @override
  State<MainDashboardView> createState() => _MainDashboardViewState();
}

class _MainDashboardViewState extends State<MainDashboardView> {
  static const double _kRefreshThreshold = 80.0;
  double _dragProgress = 0.0;
  bool _isRefreshing = false;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing || notification.depth != 0) return false;

    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      if (pixels < 0) {
        final p = (pixels.abs() / _kRefreshThreshold).clamp(0.0, 1.0);
        if ((p - _dragProgress).abs() > 0.005) {
          setState(() => _dragProgress = p);
        }
      } else if (_dragProgress > 0) {
        setState(() => _dragProgress = 0.0);
      }
    } else if (notification is ScrollEndNotification) {
      if (_dragProgress >= 1.0) {
        _triggerRefresh();
      } else if (_dragProgress > 0) {
        setState(() => _dragProgress = 0.0);
      }
    }
    return false;
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _isRefreshing = true;
      _dragProgress = 0.0;
    });
    context.read<DashboardController>().refreshData();
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const barColor = AppTheme.highlightLime;
    final bool showBar = _dragProgress > 0 || _isRefreshing;
    final headerBottom = MediaQuery.of(context).padding.top + 72.0;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                expandedHeight: 72.0,
                floating: false,
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: isDark ? const Color(0xFF050505) : Colors.white,
                surfaceTintColor: Colors.transparent,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SafeArea(
                      child: DashboardHeader(
                        onProfileTap: () => _DashboardScreenState._showProfileModalStatic(context),
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SessionControlSection(),
              ),
              SliverToBoxAdapter(
                child: ScheduleSection(
                  onViewAll: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const FacultyTimetableScreen(),
                    ));
                  },
                  onCourseTap: (course) {
                    HapticService.light();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MyClassScreen(
                        initialSubjectCode: course.subjectCode,
                      ),
                    ));
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
        Positioned(
          top: headerBottom,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: showBar ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: SizedBox(
              height: showBar ? 3.0 : 0.0,
              child: LinearProgressIndicator(
                value: _isRefreshing ? null : _dragProgress,
                backgroundColor: barColor.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

