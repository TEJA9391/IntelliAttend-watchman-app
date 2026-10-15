import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/mark_attendance_controller.dart';
import 'review_screen.dart';

class NfcAttendanceScreen extends StatefulWidget {
  final String courseCode;
  final String courseName;
  const NfcAttendanceScreen({Key? key, required this.courseCode, required this.courseName}) : super(key: key);
  @override
  State<NfcAttendanceScreen> createState() => _NfcAttendanceScreenState();
}

class _NfcAttendanceScreenState extends State<NfcAttendanceScreen> with TickerProviderStateMixin {
  bool _isNfcActive = false;
  Timer? _nfcTimer;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late AnimationController _tapAnimController;
  late Animation<double> _tapScaleAnimation;
  String? _lastTapStudentName;
  bool _showDuplicateWarning = false;
  Timer? _warningTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _tapAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _tapScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _tapAnimController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _nfcTimer?.cancel();
    _warningTimer?.cancel();
    _pulseController.dispose();
    _tapAnimController.dispose();
    super.dispose();
  }

  void _startNfc() {
    HapticService.medium();
    final controller = context.read<MarkAttendanceController>();
    setState(() { _isNfcActive = true; });

    _nfcTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || controller.roster.isEmpty) { timer.cancel(); return; }

      final random = Random();
      final unverified = controller.roster.where((s) => !controller.nfcVerifiedIds.contains(s.id)).toList();
      if (unverified.isEmpty) { _stopNfc(); return; }

      final student = unverified[random.nextInt(unverified.length)];
      final wasDuplicate = controller.nfcVerifiedIds.contains(student.id);
      controller.simulateNFCTap(student.id);

      _tapAnimController.forward(from: 0.0);
      HapticService.light();

      setState(() {
        _lastTapStudentName = student.name;
        _showDuplicateWarning = wasDuplicate;
      });

      if (_showDuplicateWarning) {
        _warningTimer?.cancel();
        _warningTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() { _showDuplicateWarning = false; });
        });
      }
    });
  }

  void _stopNfc() {
    HapticService.heavy();
    _nfcTimer?.cancel();
    setState(() { _isNfcActive = false; });
  }

  void _navigateToReview() {
    HapticService.medium();
    final controller = context.read<MarkAttendanceController>();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: ReviewScreen(courseCode: widget.courseCode, courseName: widget.courseName),
      ),
    ));
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
                      Text("NFC Attendance", style: GoogleFonts.inter(color: textCol, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
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
            _buildNfcReaderCard(context, controller, textCol, textSec, isDark),
            const SizedBox(height: 16),
            _buildStatsRow(context, controller, textCol, textSec, isDark),
            const SizedBox(height: 16),
            _buildVerifiedList(context, controller, textCol, textSec, isDark),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, controller, textCol, isDark),
    );
  }

  Widget _buildNfcReaderCard(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isNfcActive ? AppTheme.accentPurple.withValues(alpha: 0.4) : AppTheme.border(context),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("NFC Reader", style: GoogleFonts.inter(color: textCol, fontSize: 15, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isNfcActive ? const Color(0xFF22C55E).withValues(alpha: 0.12) : AppTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isNfcActive ? "Active" : "Inactive",
                  style: GoogleFonts.inter(
                    color: _isNfcActive ? const Color(0xFF22C55E) : AppTheme.errorRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, _) {
              return AnimatedBuilder(
                animation: _tapScaleAnimation,
                builder: (context, _) {
                  final tapScale = _tapAnimController.isAnimating ? _tapScaleAnimation.value : 1.0;
                  return Transform.scale(
                    scale: _isNfcActive ? _scaleAnimation.value * tapScale : tapScale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isNfcActive ? AppTheme.accentPurple.withValues(alpha: 0.12) : AppTheme.surface(context),
                        border: Border.all(
                          color: _isNfcActive ? AppTheme.accentPurple.withValues(alpha: 0.4) : AppTheme.border(context),
                          width: _isNfcActive ? 2 : 1,
                        ),
                        boxShadow: _isNfcActive ? [
                          BoxShadow(color: AppTheme.accentPurple.withValues(alpha: 0.2), blurRadius: 24, spreadRadius: 4),
                        ] : null,
                      ),
                      child: Icon(
                        Icons.nfc_rounded,
                        size: 60,
                        color: _isNfcActive ? AppTheme.accentPurple : textSec.withValues(alpha: 0.4),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            _isNfcActive ? "Tap to simulate NFC" : "Tap 'Start NFC' to begin",
            style: GoogleFonts.inter(color: _isNfcActive ? AppTheme.accentPurple : textSec, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          if (_isNfcActive && _lastTapStudentName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: const Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Text(
                    "Last tap: $_lastTapStudentName",
                    style: GoogleFonts.inter(color: const Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          if (_showDuplicateWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Duplicate tap ignored",
                style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    final verifiedCount = controller.nfcVerifiedIds.length;
    final totalCount = controller.totalCount;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: "Verified",
            value: "$verifiedCount",
            color: const Color(0xFF22C55E),
            context: context,
            isDark: isDark,
            textCol: textCol,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: "Pending",
            value: "${totalCount - verifiedCount}",
            color: const Color(0xFFFBBF24),
            context: context,
            isDark: isDark,
            textCol: textCol,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: "Total",
            value: "$totalCount",
            color: AppTheme.accentPurple,
            context: context,
            isDark: isDark,
            textCol: textCol,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({required String label, required String value, required Color color, required BuildContext context, required bool isDark, required Color textCol}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildVerifiedList(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    if (controller.nfcVerifiedIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.nfc_rounded, size: 36, color: textSec.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Text("No taps recorded yet", style: GoogleFonts.inter(color: textSec, fontSize: 13)),
              const SizedBox(height: 4),
              Text("Students will appear here after tapping", style: GoogleFonts.inter(color: textSec.withValues(alpha: 0.6), fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Verified Students (${controller.nfcVerifiedIds.length})", style: GoogleFonts.inter(color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...controller.nfcVerifiedIds.map((id) {
          final student = controller.roster.firstWhere((s) => s.id == id, orElse: () => controller.roster.first);
          final tagId = "NFC_${id.substring(0, min(id.length, 8)).toUpperCase()}";
          final now = DateTime.now();
          final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.nfc_rounded, size: 18, color: AppTheme.accentPurple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: GoogleFonts.inter(color: textCol, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(student.rollNumber, style: GoogleFonts.inter(color: textSec, fontSize: 11)),
                          Text("  \u2022  ", style: GoogleFonts.inter(color: textSec, fontSize: 11)),
                          Text(timeStr, style: GoogleFonts.jetBrainsMono(color: textSec, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 18),
                    const SizedBox(height: 2),
                    Text(tagId, style: GoogleFonts.jetBrainsMono(color: textSec, fontSize: 8)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, MarkAttendanceController controller, Color textCol, bool isDark) {
    return Container(
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
                onTap: _isNfcActive ? _stopNfc : _startNfc,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _isNfcActive ? AppTheme.errorRed.withValues(alpha: 0.12) : AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: _isNfcActive ? Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)) : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isNfcActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: _isNfcActive ? AppTheme.errorRed : textCol,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isNfcActive ? "Stop NFC" : "Start NFC",
                          style: GoogleFonts.inter(color: _isNfcActive ? AppTheme.errorRed : textCol, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: controller.nfcVerifiedIds.isNotEmpty ? _navigateToReview : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: controller.nfcVerifiedIds.isNotEmpty ? AppTheme.accentTeal : textCol.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "Review & Submit",
                      style: GoogleFonts.inter(
                        color: controller.nfcVerifiedIds.isNotEmpty ? Colors.white : textCol.withValues(alpha: 0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
}
