import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/live_monitor/live_monitor_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/live_monitor/live_monitor_controller.dart';
import 'package:intelli_attend_faculty/Data/Repositories/attendance_repository.dart';
import 'package:intelli_attend_faculty/Services/websocket_service.dart';
import 'package:intelli_attend_faculty/Core/Models/websocket_event.dart';

class LiveDashboardScreen extends StatefulWidget {
  final String sessionId;
  final String courseName;

  const LiveDashboardScreen({
    Key? key,
    required this.sessionId,
    this.courseName = '',
  }) : super(key: key);

  @override
  State<LiveDashboardScreen> createState() => _LiveDashboardScreenState();
}

class _LiveDashboardScreenState extends State<LiveDashboardScreen> {
  final List<_ScanEvent> _scanFeed = [];
  StreamSubscription? _wsEventSub;

  @override
  void initState() {
    super.initState();
    _setupScanFeedListener();
  }

  void _setupScanFeedListener() {
    final wsService = WebSocketService();
    _wsEventSub = wsService.events.listen((event) {
      if (!mounted) return;
      switch (event.type) {
        case WsEventType.studentVerified:
        case WsEventType.attendanceUpdate:
          final studentId = event.get<String>('student_id') ?? event.get<String>('roll_number') ?? '';
          final studentName = event.get<String>('student_name') ?? event.get<String>('name') ?? '';
          final seat = event.get<String>('seat') ?? '';
          setState(() {
            _scanFeed.insert(0, _ScanEvent(
              studentId: studentId,
              studentName: studentName,
              seat: seat,
              timestamp: DateTime.now(),
            ));
            if (_scanFeed.length > 20) {
              _scanFeed.removeLast();
            }
          });
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _wsEventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardController = context.read<DashboardController>();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            if (widget.courseName.isNotEmpty)
              Text(widget.courseName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context))),
            Text("Live Dashboard", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.text(context))),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.grid_view_rounded, color: AppTheme.accentTeal, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (context) => LiveMonitorController(
                      context.read<AttendanceRepository>(),
                      widget.sessionId,
                      courseId: dashboardController.activeSession?['course_id'],
                      sectionId: dashboardController.activeSession?['section_id'],
                      onSessionEnded: () {
                        dashboardController.clearActiveSession();
                        Navigator.pop(context);
                      },
                    ),
                    child: LiveMonitorScreen(courseName: widget.courseName),
                  ),
                ),
              );
            },
            tooltip: "Open Full Monitor",
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: AppTheme.text(context), size: 22),
            onPressed: () {
              dashboardController.clearActiveSession();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Consumer<DashboardController>(
        builder: (context, controller, child) {
          final present = controller.presentCount;
          final absent = controller.absentCount;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _buildStatsRow(context, present, absent),
              const SizedBox(height: 20),
              _buildScanFeedHeader(context),
              const SizedBox(height: 8),
              Expanded(child: _buildScanFeed(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, int present, int absent) {
    final total = present + absent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              label: "Present",
              value: present.toString(),
              color: const Color(0xFFA3E635),
              icon: Icons.check_circle_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              label: "Absent",
              value: absent.toString(),
              color: AppTheme.errorRed,
              icon: Icons.cancel_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              label: "Total",
              value: total.toString(),
              color: AppTheme.accentTeal,
              icon: Icons.people_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String label, required String value, required Color color, required IconData icon}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanFeedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Latest Scans",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.text(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "${_scanFeed.length} scan${_scanFeed.length == 1 ? '' : 's'}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanFeed(BuildContext context) {
    if (_scanFeed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppTheme.textSecondary(context), size: 48),
            const SizedBox(height: 16),
            Text(
              "Waiting for scans...",
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _scanFeed.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final scan = _scanFeed[index];
        return _buildScanTile(context, scan);
      },
    );
  }

  Widget _buildScanTile(BuildContext context, _ScanEvent scan) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = '${scan.timestamp.hour.toString().padLeft(2, '0')}:${scan.timestamp.minute.toString().padLeft(2, '0')}:${scan.timestamp.second.toString().padLeft(2, '0')}';
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFA3E635),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.studentName.isNotEmpty ? scan.studentName : scan.studentId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (scan.studentName.isNotEmpty && scan.studentId.isNotEmpty)
                    Text(
                      scan.studentId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (scan.seat.isNotEmpty)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    scan.seat,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.accentTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                timeStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary(context),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanEvent {
  final String studentId;
  final String studentName;
  final String seat;
  final DateTime timestamp;

  _ScanEvent({
    required this.studentId,
    required this.studentName,
    required this.seat,
    required this.timestamp,
  });
}
