import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/mark_attendance_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Widgets/attendance_summary_panel.dart';
import 'review_screen.dart';

class QrAttendanceScreen extends StatefulWidget {
  final String courseCode;
  final String courseName;
  const QrAttendanceScreen({Key? key, required this.courseCode, required this.courseName}) : super(key: key);
  @override
  State<QrAttendanceScreen> createState() => _QrAttendanceScreenState();
}

class _QrAttendanceScreenState extends State<QrAttendanceScreen> {
  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<MarkAttendanceController>();
      controller.generateQRCode();
      _startSimulation(controller);
    });
  }

  void _startSimulation(MarkAttendanceController controller) {
    final students = controller.roster;
    if (students.isEmpty) return;
    int index = 0;
    _simulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (index >= students.length || controller.qrCodeData.isEmpty) {
        timer.cancel();
        return;
      }
      controller.simulateQRScan(students[index].id);
      index++;
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.watch<MarkAttendanceController>();

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
                      Text("QR Attendance", style: GoogleFonts.inter(color: textCol, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      Text(widget.courseCode, style: GoogleFonts.inter(color: textSec, fontSize: 12)),
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
          children: [
            _buildQRCodeCard(context, controller, textCol, textSec, isDark),
            const SizedBox(height: 16),
            AttendanceSummaryPanel(
              totalCount: controller.totalCount,
              presentCount: controller.presentCount,
              absentCount: controller.absentCount,
              lateCount: controller.lateCount,
              leaveCount: controller.leaveCount,
              attendancePercent: controller.attendancePercent,
            ),
            const SizedBox(height: 16),
            _buildScannedList(context, controller, textCol, textSec, isDark),
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
                  onTap: () {
                    HapticService.medium();
                    controller.refreshQR();
                    _startSimulation(controller);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: AppTheme.surface(context), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text("Refresh QR", style: GoogleFonts.inter(color: textCol, fontSize: 13, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    HapticService.medium();
                    controller.expireQR();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: controller,
                        child: ReviewScreen(courseCode: widget.courseCode, courseName: widget.courseName),
                      ),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: AppTheme.accentTeal, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text("Review & Submit", style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeCard(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    final isActive = controller.qrCodeData.isNotEmpty;
    final minutes = controller.qrCountdownSeconds ~/ 60;
    final seconds = controller.qrCountdownSeconds % 60;
    final timeStr = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? AppTheme.accentTeal.withValues(alpha: 0.3) : AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Scan QR Code", style: GoogleFonts.inter(color: textCol, fontSize: 15, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF22C55E).withValues(alpha: 0.12) : AppTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? "Active" : "Expired",
                  style: GoogleFonts.inter(color: isActive ? const Color(0xFF22C55E) : AppTheme.errorRed, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: isActive
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 80, color: AppTheme.accentTeal),
                        const SizedBox(height: 8),
                        Text(
                          controller.qrCodeData.substring(0, controller.qrCodeData.length.clamp(0, 20)),
                          style: GoogleFonts.jetBrainsMono(color: textSec, fontSize: 8),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded, size: 60, color: textSec.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text("QR Expired", style: GoogleFonts.inter(color: textSec, fontSize: 13)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (isActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_rounded, color: controller.qrCountdownSeconds < 30 ? AppTheme.errorRed : AppTheme.accentTeal, size: 18),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: GoogleFonts.jetBrainsMono(
                    color: controller.qrCountdownSeconds < 30 ? AppTheme.errorRed : textCol,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${controller.qrScannedStudentIds.length} students scanned",
              style: GoogleFonts.inter(color: textSec, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScannedList(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    if (controller.qrScannedStudentIds.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Scanned Students (${controller.qrScannedStudentIds.length})", style: GoogleFonts.inter(color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...controller.qrScannedStudentIds.map((id) {
          final student = controller.roster.firstWhere((s) => s.id == id, orElse: () => controller.roster.first);
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(student.name, style: GoogleFonts.inter(color: textCol, fontSize: 13, fontWeight: FontWeight.w500))),
                Text(student.rollNumber, style: GoogleFonts.inter(color: textSec, fontSize: 11)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
