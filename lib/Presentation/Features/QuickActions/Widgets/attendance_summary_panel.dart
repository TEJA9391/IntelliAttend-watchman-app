import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class AttendanceSummaryPanel extends StatelessWidget {
  final int totalCount;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final double attendancePercent;
  final bool showChart;

  const AttendanceSummaryPanel({
    Key? key,
    required this.totalCount,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
    required this.attendancePercent,
    this.showChart = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final marked = presentCount + absentCount + lateCount + leaveCount;
    final remaining = totalCount - marked;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showChart) ...[
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      progress: attendancePercent / 100,
                      color: AppTheme.accentTeal,
                      bgColor: textSec.withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: Text(
                        "${attendancePercent.toStringAsFixed(0)}%",
                        style: GoogleFonts.inter(
                          color: textCol,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Attendance Summary",
                      style: GoogleFonts.inter(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$marked of $totalCount marked · $remaining remaining",
                      style: GoogleFonts.inter(
                        color: textSec,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatChip(context, "Present", "$presentCount", const Color(0xFF22C55E)),
              const SizedBox(width: 6),
              _buildStatChip(context, "Absent", "$absentCount", AppTheme.errorRed),
              const SizedBox(width: 6),
              _buildStatChip(context, "Late", "$lateCount", const Color(0xFFFBBF24)),
              const SizedBox(width: 6),
              _buildStatChip(context, "Leave", "$leaveCount", const Color(0xFF60A5FA)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (presentCount > 0)
                    Expanded(
                      flex: presentCount,
                      child: Container(color: const Color(0xFF22C55E)),
                    ),
                  if (absentCount > 0)
                    Expanded(
                      flex: absentCount,
                      child: Container(color: AppTheme.errorRed),
                    ),
                  if (lateCount > 0)
                    Expanded(
                      flex: lateCount,
                      child: Container(color: const Color(0xFFFBBF24)),
                    ),
                  if (leaveCount > 0)
                    Expanded(
                      flex: leaveCount,
                      child: Container(color: const Color(0xFF60A5FA)),
                    ),
                  if (remaining > 0)
                    Expanded(
                      flex: remaining,
                      child: Container(color: textSec.withValues(alpha: 0.15)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary(context),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _DonutChartPainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final strokeWidth = 7.0;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final angle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      angle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
