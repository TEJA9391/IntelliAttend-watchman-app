import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'live_monitor_controller.dart';
import 'manual_attendance_screen.dart';

class LiveSessionScreen extends StatefulWidget {
  final String courseName;

  const LiveSessionScreen({Key? key, required this.courseName}) : super(key: key);

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LiveMonitorController>(
      builder: (context, controller, _) {
        if (controller.isLoading) {
          return _buildLoadingState();
        }
        return Scaffold(
          backgroundColor: AppTheme.bg(context),
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(context, controller),
                  _buildConnectionChip(context, controller),
                  const SizedBox(height: 16),
                  _buildStatsRow(context, controller),
                  const SizedBox(height: 20),
                  _buildStudentListHeader(context, controller),
                  const SizedBox(height: 8),
                  Expanded(child: _buildStudentList(context, controller)),
                  _buildBottomBar(context, controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.accentTeal),
            ),
            const SizedBox(height: 20),
            Text("Connecting to session...", style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context), fontSize: 14,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LiveMonitorController controller) {
    final bool isConnected = controller.wsConnectionState == 'connected';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.courseName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: isConnected ? const Color(0xFF22C55E) : AppTheme.errorRed)),
                  const SizedBox(width: 6),
                  Text(isConnected ? "Live" : "Disconnected",
                    style: GoogleFonts.inter(
                      color: isConnected ? const Color(0xFF22C55E) : AppTheme.errorRed,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accentTeal, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ManualAttendanceScreen(controller: controller))),
            tooltip: "Manual Override",
          ),
          IconButton(
            icon: Icon(Icons.sync_rounded,
              color: controller.isReconciling ? AppTheme.textSecondary(context) : AppTheme.highlightLime, size: 22),
            onPressed: controller.isReconciling ? null : () => controller.reconcileCount(),
            tooltip: "Reconcile",
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionChip(BuildContext context, LiveMonitorController controller) {
    final String state = controller.wsConnectionState;
    final Color chipColor = state == 'connected'
        ? const Color(0xFF22C55E)
        : (state == 'connecting' || state == 'reconnecting') ? Colors.amber : AppTheme.errorRed;
    final String label = state == 'connected'
        ? "SmartBoard Synced"
        : state == 'connecting' ? "Connecting..." : state == 'reconnecting' ? "Reconnecting..." : "Disconnected";
    final IconData icon = state == 'connected'
        ? Icons.wifi_rounded
        : (state == 'connecting' || state == 'reconnecting') ? Icons.wifi_find_rounded : Icons.wifi_off_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: chipColor, size: 14),
            const SizedBox(width: 6),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: chipColor, fontSize: 12, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, LiveMonitorController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _statCard(context, "Present", "${controller.presentCount}", const Color(0xFF22C55E), Icons.check_circle_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _statCard(context, "Absent", "${controller.absentCount}", AppTheme.errorRed, Icons.cancel_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _statCard(context, "Total", "${controller.totalCount}", AppTheme.accentTeal, Icons.people_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _statCard(context, "Rate", "${controller.attendanceRate.toInt()}%", AppTheme.highlightLime, Icons.trending_up_rounded)),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value, Color color, IconData icon) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value,
            style: GoogleFonts.inter(color: color, fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStudentListHeader(BuildContext context, LiveMonitorController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Students", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
          Text("${controller.presentCount}/${controller.totalCount}", style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStudentList(BuildContext context, LiveMonitorController controller) {
    final students = controller.mergedStudents;
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, color: AppTheme.textSecondary(context), size: 48),
            const SizedBox(height: 12),
            Text("Waiting for student data...", style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context), fontSize: 14)),
          ],
        ),
      );
    }

    final present = students.where((s) => s.status == StudentStatus.present).toList();
    final absent = students.where((s) => s.status != StudentStatus.present).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (present.isNotEmpty) ...[
          _buildSectionLabel(context, "Present", "${present.length}", const Color(0xFF22C55E)),
          const SizedBox(height: 8),
          ...present.map((s) => _buildStudentTile(context, s, true)),
          const SizedBox(height: 16),
        ],
        if (absent.isNotEmpty) ...[
          _buildSectionLabel(context, "Absent", "${absent.length}", AppTheme.errorRed),
          const SizedBox(height: 8),
          ...absent.map((s) => _buildStudentTile(context, s, false)),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label, String count, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Text(count, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 13)),
      ],
    );
  }

  Widget _buildStudentTile(BuildContext context, StudentAttendance student, bool isPresent) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color statusColor = isPresent ? const Color(0xFF22C55E) : AppTheme.errorRed;
    final String timeStr = student.checkInTime != null
        ? "${student.checkInTime!.hour.toString().padLeft(2, '0')}:${student.checkInTime!.minute.toString().padLeft(2, '0')}"
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor.withValues(alpha: 0.1)),
            child: student.image != null
                ? ClipOval(child: Image.network(student.image!, width: 40, height: 40, fit: BoxFit.cover))
                : Icon(Icons.person_rounded, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.w600)),
                if (student.email != null && student.email!.isNotEmpty)
                  Text(student.email!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11)),
              ],
            ),
          ),
          if (isPresent && timeStr.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(timeStr, style: GoogleFonts.inter(
                color: const Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          if (!isPresent)
            GestureDetector(
              onTap: () => _showMarkDialog(context, student),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
                ),
                child: Text("Mark", style: GoogleFonts.inter(
                  color: AppTheme.accentTeal, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  void _showMarkDialog(BuildContext context, StudentAttendance student) {
    final controller = context.read<LiveMonitorController>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(student.name, style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        content: Text("Mark ${student.name} as present?", style: GoogleFonts.inter(
          color: AppTheme.textSecondary(context), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: AppTheme.textSecondary(context)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.markStudentPresent(student.id, reason: 'live_tap');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentTeal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, LiveMonitorController controller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border(context), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => controller.generateRescueSeed(),
              icon: const Icon(Icons.vpn_key_outlined, size: 18),
              label: Text("Rescue Seed", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentTeal,
                side: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _confirmEndSession(context, controller),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text("End Session", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmEndSession(BuildContext context, LiveMonitorController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("End Session?", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.text(context))),
        content: Text("This will stop live tracking for all students.", style: GoogleFonts.inter(color: AppTheme.textSecondary(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: AppTheme.textSecondary(context)))),
          ElevatedButton(
            onPressed: () {
              controller.terminateSession();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}
