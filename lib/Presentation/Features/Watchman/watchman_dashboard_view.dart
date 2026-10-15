import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'gate_records_detail_screen.dart';
import 'package:intelli_attend_faculty/Services/id_card_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/notifications/notifications_screen.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_controller.dart';

class GateLogEntry {
  final String id;
  final String name;
  final String subtitle;
  final String type; // 'Student', 'Faculty', 'Visitor'
  final bool isEntry; // true: In, false: Out
  final String time;
  final String status; // 'Approved', 'Late Entry', 'Visitor Pass', 'Out-Pass'
  final Color statusColor;

  GateLogEntry({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.type,
    required this.isEntry,
    required this.time,
    required this.status,
    required this.statusColor,
  });
}

class WatchmanDashboardView extends StatefulWidget {
  final VoidCallback onOpenScanner;
  final VoidCallback? onOpenDrawer;
  final Function(GateLogEntry)? onAddLog;

  const WatchmanDashboardView({
    Key? key,
    required this.onOpenScanner,
    this.onOpenDrawer,
    this.onAddLog,
  }) : super(key: key);

  @override
  State<WatchmanDashboardView> createState() => WatchmanDashboardViewState();
}

class WatchmanDashboardViewState extends State<WatchmanDashboardView> {
  String _selectedFilter = 'All';

  // Pull-to-refresh state matching faculty app
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
    HapticService.medium();
    try {
      context.read<DashboardController>().refreshData();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _isRefreshing = false);
  }

  // Dynamic gate statistics
  int _studentsIn = 842;
  int _visitorsActive = 7;
  int _lateEntries = 28;
  int _exitsRecorded = 114;

  IdCardInfo? _lastScannedCard = const IdCardInfo(
    isValid: true,
    id: '23N31A6653',
    name: 'BOORA RAVITEJA',
    type: 'Student',
    program: 'B.Tech',
    branchOrDept: 'CSE-AIML',
    batch: '2023-2027',
    institution: 'MRCET',
    dob: '17.06.2006',
    status: 'Approved',
    statusColor: Color(0xFF00D2B4),
  );

  final List<GateLogEntry> _logs = [
    GateLogEntry(
      id: '23N31A6653',
      name: 'BOORA RAVITEJA',
      subtitle: 'CSE-AIML • Batch 2023-27',
      type: 'Student',
      isEntry: true,
      time: '11:25 AM',
      status: 'Approved',
      statusColor: const Color(0xFF00D2B4),
    ),
    GateLogEntry(
      id: '21CS042',
      name: 'K. Arjun',
      subtitle: 'CSE • 3rd Year',
      type: 'Student',
      isEntry: true,
      time: '11:12 AM',
      status: 'Approved',
      statusColor: const Color(0xFF10B981),
    ),
    GateLogEntry(
      id: 'FAC-108',
      name: 'Dr. S. Raman',
      subtitle: 'Dept. of Physics',
      type: 'Faculty',
      isEntry: true,
      time: '11:05 AM',
      status: 'Approved',
      statusColor: const Color(0xFF10B981),
    ),
    GateLogEntry(
      id: 'VIS-402',
      name: 'Ravi Verma',
      subtitle: 'Parent • Meeting HOD ECE',
      type: 'Visitor',
      isEntry: true,
      time: '10:55 AM',
      status: 'Visitor Pass',
      statusColor: const Color(0xFFF59E0B),
    ),
    GateLogEntry(
      id: '22EC019',
      name: 'Sneha Reddy',
      subtitle: 'ECE • 2nd Year',
      type: 'Student',
      isEntry: false,
      time: '10:40 AM',
      status: 'Out-Pass',
      statusColor: const Color(0xFF6366F1),
    ),
    GateLogEntry(
      id: '23ME005',
      name: 'Pooja Nair',
      subtitle: 'ME • 1st Year',
      type: 'Student',
      isEntry: true,
      time: '09:22 AM',
      status: 'Late Entry',
      statusColor: const Color(0xFFEF4444),
    ),
  ];

  void addVerifiedScan(IdCardInfo info) {
    if (!info.isValid) return;
    setState(() {
      _lastScannedCard = info;
      if (info.isEntry) {
        // 1st scan: ENTRY (IN)
        if (info.type == 'Student') {
          _studentsIn++;
        }
      } else {
        // 2nd scan: EXIT (OUT)
        if (info.type == 'Student' && _studentsIn > 0) {
          _studentsIn--;
        }
        _exitsRecorded++;
      }
      final now = DateTime.now();
      final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final timeStr = "${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";
      _logs.insert(
        0,
        GateLogEntry(
          id: info.id,
          name: info.name,
          subtitle: '${info.branchOrDept} • ${info.batch}',
          type: info.type,
          isEntry: info.isEntry,
          time: timeStr,
          status: info.isEntry ? 'Approved (IN)' : 'Exit Logged (OUT)',
          statusColor: info.isEntry ? const Color(0xFF00D2B4) : const Color(0xFF6366F1),
        ),
      );
    });
  }

  void addScanResult(String code) {
    final info = IdCardService.verifyBarcode(code);
    addVerifiedScan(info);
  }



  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning,";
    if (hour < 17) return "Good Afternoon,";
    return "Good Evening,";
  }

  ImageProvider _getProfileImage(FacultyProfile? profile) {
    if (profile?.profileImage != null && profile!.profileImage!.isNotEmpty) {
      if (profile.profileImage!.startsWith('http')) {
        return NetworkImage(profile.profileImage!);
      } else {
        return FileImage(File(profile.profileImage!));
      }
    }
    return const AssetImage('assets/images/logo_square.png');
  }

  void _showRoomInfoSheet(BuildContext context, String room) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    String block = 'Block A';
    String floor = 'Ground Floor';

    if (room.contains('B')) block = 'Block B';
    if (room.contains('C')) block = 'Block C';

    final match = RegExp(r'\d+').firstMatch(room);
    if (match != null) {
      final n = int.parse(match.group(0)!);
      if (n >= 400) {
        floor = '4th Floor';
      } else if (n >= 300) {
        floor = '3rd Floor';
      } else if (n >= 200) {
        floor = '2nd Floor';
      } else if (n >= 100) {
        floor = '1st Floor';
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84CC16).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Color(0xFF84CC16), size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room $room Details',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '$block • $floor',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF84CC16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cyber Security Essentials lecture scheduled in Room $room ($block, $floor).',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(bool isDark) {
    return ValueListenableBuilder<FacultyProfile?>(
      valueListenable: FacultyService.profile,
      builder: (context, profile, _) {
        final displayName = (profile?.name != null &&
                profile!.name.isNotEmpty &&
                profile.name != 'Faculty User' &&
                profile.name != 'M. Sai Krishna Murthy')
            ? profile.name
            : 'Watchman';

        return Row(
          children: [
            GestureDetector(
              onTap: () => _showWatchmanProfileModal(context),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.15) : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image(
                        image: _getProfileImage(profile),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      height: 13,
                      width: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA3E635),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFA3E635).withOpacity(0.55),
                            blurRadius: 4,
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getTimeGreeting(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<List<AppNotification>>(
              valueListenable: NotificationService.history,
              builder: (context, history, _) {
                final unread = history.where((n) => !n.isRead).length;
                return GestureDetector(
                  onTap: () {
                    HapticService.light();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                  },
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          size: 22,
                        ),
                        if (unread > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showWatchmanProfileModal(BuildContext context) {
    HapticService.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const WatchmanProfileModal(),
    );
  }

  void _showCardDetailSheet(IdCardInfo card) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.border(context), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: card.statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      card.name.isNotEmpty ? card.name[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: card.statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${card.id} • ${card.type}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00D2B4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailInfoRow(context, 'Program / Dept', '${card.program} • ${card.branchOrDept}'),
            _buildDetailInfoRow(context, 'Batch', card.batch),
            _buildDetailInfoRow(context, 'Institution', card.institution),
            if (card.dob != null) _buildDetailInfoRow(context, 'Date of Birth', card.dob!),
            _buildDetailInfoRow(context, 'Status', card.status, highlight: true),
            _buildDetailInfoRow(context, 'Verification', card.isServerVerified ? 'Server Verified' : 'Gate Verified'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailInfoRow(BuildContext context, String label, String value, {bool highlight = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
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

  Widget _buildRecentScannedCard(bool isDark) {
    final card = _lastScannedCard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recently Scanned ID',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16161A) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.40 : 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Soft teal circular background accent at top-right
                Positioned(
                  top: -24,
                  right: -24,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withOpacity(isDark ? 0.04 : 0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  child: card != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Badge: [Verified / Status]
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2DD4BF).withOpacity(0.12)
                                    : const Color(0xFF2DD4BF).withOpacity(0.14),
                                borderRadius: BorderRadius.circular(14),
                                border: isDark
                                    ? Border.all(
                                        color: const Color(0xFF2DD4BF).withOpacity(0.25),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    card.isServerVerified
                                        ? Icons.cloud_done_rounded
                                        : Icons.verified_rounded,
                                    size: 14,
                                    color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${card.type.toUpperCase()} • ${card.isEntry ? "ENTRY (IN)" : "EXIT (OUT)"}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Main Title: ID - Name
                            Text(
                              '${card.id} - ${card.name}',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 3. Location / Department Line: 📍 Branch • Batch ⓘ
                            GestureDetector(
                              onTap: () => _showCardDetailSheet(card),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 18,
                                    color: Color(0xFF84CC16),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${card.branchOrDept} • ${card.batch}',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF84CC16),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 14,
                                    color: const Color(0xFF84CC16).withOpacity(0.7),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // 4. Status Row: ✓✓ Status text
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E2028)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.done_all_rounded,
                                    size: 18,
                                    color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Gate Access ${card.status}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2DD4BF).withOpacity(0.12)
                                    : const Color(0xFF2DD4BF).withOpacity(0.14),
                                borderRadius: BorderRadius.circular(14),
                                border: isDark
                                    ? Border.all(
                                        color: const Color(0xFF2DD4BF).withOpacity(0.25),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    size: 14,
                                    color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'READY TO SCAN',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No ID Scanned Yet',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.4,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                  color: Color(0xFF84CC16),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Main Gate Security Checkpoint',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF84CC16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            GestureDetector(
                              onTap: widget.onOpenScanner,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E2028)
                                      : const Color(0xFF00D2B4).withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF2DD4BF).withOpacity(0.35)
                                        : const Color(0xFF00D2B4).withOpacity(0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_rounded,
                                      size: 18,
                                      color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tap to Scan Barcode / QR',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0D9488),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const barColor = Color(0xFFA3E635); // AppTheme.highlightLime (lime green)
    final bool showBar = _dragProgress > 0 || _isRefreshing;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── 1. PINNED TOP HEADER: Avatar, Greeting, Watchman Name, Notification Bell ──
          // Stays completely fixed and motionless when pulling down or scrolling
          Container(
            color: AppTheme.bg(context),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: _buildTopHeader(isDark),
          ),

          // ── 2. LIME GREEN PROGRESS BAR (Directly below Greeting & Name) ──
          // Fills left-to-right on pull-down and continuously sweeps during refresh
          AnimatedOpacity(
            opacity: showBar ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: SizedBox(
              height: showBar ? 3.0 : 0.0,
              child: LinearProgressIndicator(
                value: _isRefreshing ? null : _dragProgress,
                backgroundColor: barColor.withOpacity(0.18),
                valueColor: const AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 3,
              ),
            ),
          ),

          // ── 3. SCROLLABLE BODY (Pulls down & scrolls underneath the fixed header) ──
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScrollNotification,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── That Card: Recently Scanned ID ──
                    _buildRecentScannedCard(isDark),
                    const SizedBox(height: 24),

                    // ── Gate KPI Statistics ──
                    _buildKpiGrid(isDark),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY AT GATE #1',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Students In',
                value: '$_studentsIn',
                subtitle: 'Inside campus',
                icon: Icons.school_outlined,
                color: const Color(0xFF00D2B4),
                isDark: isDark,
                onTap: () => _navigateToDetail(GateRecordType.studentsIn, _studentsIn),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Active Visitors',
                value: '$_visitorsActive',
                subtitle: 'Passes active',
                icon: Icons.person_search_outlined,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                onTap: () => _navigateToDetail(GateRecordType.activeVisitors, _visitorsActive),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Late Entries',
                value: '$_lateEntries',
                subtitle: 'Post-cutoff',
                icon: Icons.timer_outlined,
                color: const Color(0xFFEF4444),
                isDark: isDark,
                onTap: () => _navigateToDetail(GateRecordType.lateEntries, _lateEntries),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                title: 'Exits Logged',
                value: '$_exitsRecorded',
                subtitle: 'Out-passes',
                icon: Icons.logout_rounded,
                color: const Color(0xFF6366F1),
                isDark: isDark,
                onTap: () => _navigateToDetail(GateRecordType.exitsLogged, _exitsRecorded),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToDetail(GateRecordType type, int count) {
    HapticService.selection();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GateRecordsDetailScreen(
          recordType: type,
          totalCount: count,
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: color.withOpacity(0.12),
          highlightColor: color.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildLiveActivitySection(bool isDark, List<GateLogEntry> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'LIVE GATE ACTIVITY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D2B4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${logs.length}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00D2B4),
                    ),
                  ),
                ),
              ],
            ),
            // Filter Pills
            Row(
              children: ['All', 'Student', 'Visitor'].map((filter) {
                final bool isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    HapticService.selection();
                    setState(() => _selectedFilter = filter);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00D2B4)
                          : (isDark ? const Color(0xFF18181B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      filter,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.black
                            : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = logs[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border(context), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (log.isEntry ? const Color(0xFF10B981) : const Color(0xFF6366F1))
                          .withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        log.isEntry ? Icons.login_rounded : Icons.logout_rounded,
                        color: log.isEntry ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                log.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: log.statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                log.status,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: log.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${log.id} • ${log.subtitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        log.time,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.isEntry ? 'Entry' : 'Exit',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class WatchmanProfileModal extends StatelessWidget {
  const WatchmanProfileModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppTheme.border(context), width: 1),
      ),
      child: ValueListenableBuilder<FacultyProfile?>(
        valueListenable: FacultyService.profile,
        builder: (context, profile, _) {
          final name = (profile?.name != null &&
                  profile!.name.isNotEmpty &&
                  profile.name != 'Faculty User' &&
                  profile.name != 'M. Sai Krishna Murthy')
              ? profile.name
              : 'Watchman';
          final email = profile?.email ?? 'watchman@mrcet.intelliattend.com';
          final employeeCode = profile?.facultyId ?? 'WATCHMAN_01';
          final department = profile?.department ?? 'Campus Security & Safety';
          final designation = profile?.designation ?? 'Security Officer';

          final initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2DD4BF).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2DD4BF).withOpacity(0.35),
                        width: 2.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2DD4BF),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initials.isNotEmpty ? initials : 'WM',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildProfileRow(context, Icons.badge_outlined, "Employee Code", employeeCode),
              _buildProfileRow(context, Icons.business_outlined, "Primary Dept", department),
              _buildProfileRow(context, Icons.work_outline_rounded, "Designation", designation),
              _buildProfileRow(context, Icons.history_edu_rounded, "Experience", "8+ Years"),
              _buildProfileRow(context, Icons.star_outline_rounded, "Rating", "4.9/5.0"),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileRow(BuildContext context, IconData icon, String label, String value) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2DD4BF)),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
