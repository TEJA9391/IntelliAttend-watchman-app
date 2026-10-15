import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/mark_attendance_controller.dart';

class ReviewScreen extends StatelessWidget {
  final String courseCode;
  final String courseName;

  const ReviewScreen({
    Key? key,
    required this.courseCode,
    required this.courseName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.watch<MarkAttendanceController>();

    final presentList = controller.roster.where((s) => controller.attendanceMap[s.id] == AttendanceStatus.present).toList();
    final absentList = controller.roster.where((s) => controller.attendanceMap[s.id] == AttendanceStatus.absent).toList();
    final lateList = controller.roster.where((s) => controller.attendanceMap[s.id] == AttendanceStatus.late).toList();
    final leaveList = controller.roster.where((s) => controller.attendanceMap[s.id] == AttendanceStatus.leave).toList();

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
                    decoration: BoxDecoration(color: AppTheme.surface(context), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: textCol),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Review Attendance", style: GoogleFonts.inter(color: textCol, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      Text("$courseCode · ${controller.totalCount} students", style: GoogleFonts.inter(color: textSec, fontSize: 12)),
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
            _buildSummaryCard(context, controller, textCol, textSec, isDark),
            const SizedBox(height: 20),
            _buildStatusSection(context, "Present", presentList, const Color(0xFF22C55E), controller),
            _buildStatusSection(context, "Absent", absentList, AppTheme.errorRed, controller),
            _buildStatusSection(context, "Late", lateList, const Color(0xFFFBBF24), controller),
            _buildStatusSection(context, "Leave", leaveList, const Color(0xFF60A5FA), controller),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border(context), width: 0.5)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text("Edit", style: GoogleFonts.inter(color: textCol, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: controller.isSubmitting
                      ? null
                      : () async {
                          HapticService.heavy();
                          _showSubmitConfirmation(context, controller);
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: controller.isSubmitting ? textSec.withValues(alpha: 0.3) : AppTheme.accentTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: controller.isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : Text("Submit Attendance", style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Attendance Summary", style: GoogleFonts.inter(color: textCol, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSummaryStat(context, "Total", "${controller.totalCount}", AppTheme.accentTeal),
              const SizedBox(width: 6),
              _buildSummaryStat(context, "Present", "${controller.presentCount}", const Color(0xFF22C55E)),
              const SizedBox(width: 6),
              _buildSummaryStat(context, "Absent", "${controller.absentCount}", AppTheme.errorRed),
              const SizedBox(width: 6),
              _buildSummaryStat(context, "Late", "${controller.lateCount}", const Color(0xFFFBBF24)),
              const SizedBox(width: 6),
              _buildSummaryStat(context, "Leave", "${controller.leaveCount}", const Color(0xFF60A5FA)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (controller.presentCount > 0)
                    Expanded(flex: controller.presentCount, child: Container(color: const Color(0xFF22C55E))),
                  if (controller.absentCount > 0)
                    Expanded(flex: controller.absentCount, child: Container(color: AppTheme.errorRed)),
                  if (controller.lateCount > 0)
                    Expanded(flex: controller.lateCount, child: Container(color: const Color(0xFFFBBF24))),
                  if (controller.leaveCount > 0)
                    Expanded(flex: controller.leaveCount, child: Container(color: const Color(0xFF60A5FA))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Attendance Rate: ${controller.attendancePercent.toStringAsFixed(1)}%",
            style: GoogleFonts.inter(color: textSec, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(value, style: GoogleFonts.inter(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 2),
            FittedBox(child: Text(label, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 9, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context, String title, List students, Color color, MarkAttendanceController controller) {
    if (students.isEmpty) return const SizedBox.shrink();
    final textCol = AppTheme.text(context);
    final textSec = AppTheme.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text("$title (${students.length})", style: GoogleFonts.inter(color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ...students.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    s.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join().take(2).toString(),
                    style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: textCol, fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(s.rollNumber, style: GoogleFonts.inter(color: textSec, fontSize: 10)),
                    ],
                  ),
                ),
                Text("${s.attendancePercentage.toStringAsFixed(0)}%", style: GoogleFonts.inter(color: textSec, fontSize: 11)),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  void _showSubmitConfirmation(BuildContext context, MarkAttendanceController controller) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Submit Attendance?", style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Please confirm the attendance before submitting. This action cannot be undone.",
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 14),
            _buildConfirmRow(context, "Present", "${controller.presentCount}", const Color(0xFF22C55E)),
            _buildConfirmRow(context, "Absent", "${controller.absentCount}", AppTheme.errorRed),
            _buildConfirmRow(context, "Late", "${controller.lateCount}", const Color(0xFFFBBF24)),
            _buildConfirmRow(context, "Leave", "${controller.leaveCount}", const Color(0xFF60A5FA)),
            _buildConfirmRow(context, "Total", "${controller.totalCount}", AppTheme.accentTeal),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.inter(color: AppTheme.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await controller.submitAttendance();
              if (success && context.mounted) {
                _showSuccessDialog(context, controller);
              }
            },
            child: Text("Submit", style: GoogleFonts.inter(color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, MarkAttendanceController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 36),
            ),
            const SizedBox(height: 16),
            Text("Attendance Saved!", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              controller.sessionStatus == 'submitted_offline'
                  ? "Saved offline. Will sync when network is available."
                  : "All ${controller.totalCount} attendance records have been saved successfully.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.maybePop(context);
                Navigator.maybePop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppTheme.accentTeal, borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text("Done", style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
