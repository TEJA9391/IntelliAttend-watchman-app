import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/mark_attendance_repository.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/mark_attendance_controller.dart';
import 'mode_selection_screen.dart';

class MarkAttendanceDashboard extends StatelessWidget {
  final String courseCode;
  final String courseName;

  const MarkAttendanceDashboard({
    Key? key,
    required this.courseCode,
    required this.courseName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 20),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: textCol),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Mark Attendance",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: textCol, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                      ),
                      Text(
                        "$courseCode · $courseName",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: textSec, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessionInfoCard(context, textCol, textSec, isDark, dateStr, timeStr),
            const SizedBox(height: 20),
            _buildSessionDetails(context, textCol, textSec, isDark, dateStr, timeStr),
            const SizedBox(height: 24),
            Text(
              "Choose Attendance Mode",
              style: GoogleFonts.inter(color: textCol, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _buildModeGrid(context, textCol, textSec, isDark),
            const SizedBox(height: 24),
            _buildQuickStartSection(context, textCol, textSec, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard(BuildContext context, Color textCol, Color textSec, bool isDark, String dateStr, String timeStr) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentTeal, AppTheme.accentTeal.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentTeal.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseCode,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.25), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(child: _buildInfoChip(Icons.calendar_today_rounded, dateStr)),
              const SizedBox(width: 12),
              Flexible(child: _buildInfoChip(Icons.access_time_rounded, timeStr)),
              const SizedBox(width: 12),
              Flexible(child: _buildInfoChip(Icons.meeting_room_rounded, "Room 301")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionDetails(BuildContext context, Color textCol, Color textSec, bool isDark, String dateStr, String timeStr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Session Details", style: GoogleFonts.inter(color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildDetailRow("Faculty", "Dr. Rajesh Kumar", Icons.person_rounded, textCol, textSec),
          _buildDetailRow("Room", "Room 301", Icons.meeting_room_rounded, textCol, textSec),
          _buildDetailRow("Date", dateStr, Icons.calendar_today_rounded, textCol, textSec),
          _buildDetailRow("Time", timeStr, Icons.access_time_rounded, textCol, textSec),
          _buildDetailRow("Status", "Ready to Start", Icons.radio_button_checked_rounded, const Color(0xFF22C55E), textSec),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color valueColor, Color textSec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: textSec, size: 15),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(color: textSec, fontSize: 12)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(color: valueColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildModeGrid(BuildContext context, Color textCol, Color textSec, bool isDark) {
    final modes = [
      {'icon': Icons.edit_note_rounded, 'label': 'Manual', 'desc': 'Mark individually', 'color': const Color(0xFF2DD4BF)},
      {'icon': Icons.qr_code_scanner_rounded, 'label': 'QR Code', 'desc': 'Scan to mark', 'color': const Color(0xFF60A5FA)},
      {'icon': Icons.face_rounded, 'label': 'Face ID', 'desc': 'Recognize faces', 'color': const Color(0xFFA78BFA)},
      {'icon': Icons.nfc_rounded, 'label': 'NFC Tap', 'desc': 'Tap to verify', 'color': const Color(0xFFFBBF24)},
      {'icon': Icons.bluetooth_rounded, 'label': 'Bluetooth', 'desc': 'Nearby detect', 'color': const Color(0xFFFF6B6B)},
      {'icon': Icons.layers_rounded, 'label': 'Hybrid', 'desc': 'Combine modes', 'color': const Color(0xFF22C55E)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: modes.length,
      itemBuilder: (context, index) {
        final mode = modes[index];
        return GestureDetector(
          onTap: () {
            HapticService.light();
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => MarkAttendanceController(MarkAttendanceRepository()),
                child: ModeSelectionScreen(
                  courseCode: courseCode,
                  courseName: courseName,
                  selectedMode: AttendanceMode.values[index],
                ),
              ),
            ));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (mode['color'] as Color).withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: (mode['color'] as Color).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (mode['color'] as Color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(mode['icon'] as IconData, color: mode['color'] as Color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  mode['label'] as String,
                  style: GoogleFonts.inter(color: textCol, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  mode['desc'] as String,
                  style: GoogleFonts.inter(color: textSec, fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStartSection(BuildContext context, Color textCol, Color textSec, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: AppTheme.accentTeal, size: 18),
              const SizedBox(width: 8),
              Text("Quick Start", style: GoogleFonts.inter(color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Choose a mode above to start taking attendance. Manual mode is recommended for first-time use.",
            style: GoogleFonts.inter(color: textSec, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
