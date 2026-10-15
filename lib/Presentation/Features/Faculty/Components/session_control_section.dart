import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/engine/engine.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/live_monitor/live_monitor_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/live_monitor/live_monitor_controller.dart';
import 'package:intelli_attend_faculty/Data/Repositories/attendance_repository.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/attendance_code_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Widgets/dynamic_pulse_dot.dart';
import 'package:intelli_attend_faculty/Presentation/Widgets/skeleton_loader.dart';



// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _cleanRoom(String raw) =>
    raw.replaceFirst(RegExp(r'^[Rr]oom[_\s]*'), '').trim();


class _SectionHeader extends StatelessWidget {
  final DashboardController ctrl;

  const _SectionHeader({required this.ctrl});

  HeartbeatState _getHeartbeatState() {
    if (ctrl.activeSession != null) return HeartbeatState.pending;
    if (ctrl.isBreak) return HeartbeatState.idle;
    return HeartbeatState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final HeartbeatState state = _getHeartbeatState();
    final bool showPulse = state != HeartbeatState.idle;
    final ts = ctrl.timetableEngine.snapshot;

    String title;
    if (ctrl.activeSession != null) {
      title = 'Ongoing Session';
    } else if (ts.phase == TimetablePhase.beforeFirstClass) {
      title = 'Good Morning';
    } else if (ctrl.isBreak) {
      title = ctrl.breakLabel;
    } else if (ts.isClassActive) {
      title = 'Class in Progress';
    } else if (ts.phase == TimetablePhase.afterLastClass && ctrl.mainCardClass != null) {
      title = 'Upcoming Session';
    } else if (ts.phase == TimetablePhase.weekend && ctrl.mainCardClass != null) {
      title = 'Upcoming Session';
    } else {
      title = ctrl.breakLabel.isNotEmpty ? ctrl.breakLabel : 'Upcoming Session';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (showPulse)
            RepaintBoundary(child: DynamicPulseDot(state: state)),
        ],
      ),
    );
  }
}

class SessionControlSection extends StatelessWidget {
  const SessionControlSection({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<DashboardController>();
    final activeSession = ctrl.activeSession;
    final mainCard = ctrl.mainCardClass;
    final bool isOngoing = activeSession != null;
    final bool isBreak = ctrl.isBreak;
    final ts = ctrl.timetableEngine.snapshot;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ctrl.displayShimmer
              ? _ShimmerSectionHeader()
              : _SectionHeader(ctrl: ctrl),
          const SizedBox(height: 12),
          if (ctrl.displayShimmer)
            _buildShimmerCard(context)
          else if (isOngoing)
            _buildSessionCard(context, ctrl, mainCard, activeSession)
          else if (ts.phase == TimetablePhase.beforeFirstClass)
            _buildGoodMorningCard(context, ctrl)
          else if (isBreak && ts.phase != TimetablePhase.afterLastClass)
            _buildBreakCard(context, ctrl)
          else if (mainCard != null)
            _buildUpcomingCard(context, mainCard, ctrl)
          else
            _buildEmptyState(context, ctrl),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    DashboardController ctrl,
    dynamic mainCard,
    Map<String, dynamic> session,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectName = (mainCard?.subjectName as String?) ?? session['subject_name'] ?? 'Live Session';
    final subjectCode = (mainCard?.subjectCode as String?) ?? session['subject_code'] ?? 'ACTIVE';
    final roomNumber = _cleanRoom((mainCard?.roomNumber as String?) ?? session['room_number'] ?? 'N/A');
    final isTutorialOrLibrary = subjectCode.toLowerCase().contains('tutorial') ||
        subjectCode.toLowerCase().contains('library') ||
        subjectName.toLowerCase().contains('tutorial') ||
        subjectName.toLowerCase().contains('library');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                child: _CountdownBadge(endTime: mainCard?.endTime ?? session['end_time'] ?? ''),
              ),
              const SizedBox(height: 14),
              Text(
                "$subjectCode - $subjectName",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              _buildDetailRow(
                context,
                Icons.location_on_rounded,
                roomNumber,
                color: const Color(0xFF84CC16),
                onTap: () => showRoomInfoSheet(context, roomNumber),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildDetailRow(context, Icons.group_outlined, "",
                    richText: TextSpan(
                      children: [
                        TextSpan(
                          text: "${session['present_count'] ?? 0}",
                          style: GoogleFonts.inter(
                            color: const Color(0xFFA3E635),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: "/${session['total_count'] ?? 0} Present",
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isTutorialOrLibrary)
                    _buildViewLiveButton(context, session['id'] ?? '', subjectName, mainCard?.id ?? '', mainCard?.sectionId ?? ''),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoodMorningCard(BuildContext context, DashboardController ctrl) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = ctrl.timetableEngine.snapshot;
    final nextBlock = ts.nextBlock;
    final nextTime = nextBlock != null
        ? _formatStartMinutes(nextBlock.startMinutes)
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeBadge(context, "GOOD MORNING", color: const Color(0xFFF59E0B)),
              const SizedBox(height: 14),
              Text(
                "Good Morning!",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              if (nextTime.isNotEmpty)
                _buildDetailRow(
                  context,
                  Icons.schedule_rounded,
                  "Class starts at $nextTime",
                  color: AppTheme.accentTeal,
                )
              else
                _buildDetailRow(
                  context,
                  Icons.event_busy_rounded,
                  "No class scheduled for today",
                  color: AppTheme.textSecondary(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatStartMinutes(int? minutes) {
    if (minutes == null || minutes < 0) return '';
    final h = (minutes ~/ 60) % 12;
    final m = minutes % 60;
    final period = minutes ~/ 60 >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : h;
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }

  Widget _buildBreakCard(BuildContext context, DashboardController ctrl) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String label = ctrl.breakLabel.toUpperCase();
    final IconData icon = label.contains('LUNCH')
        ? Icons.restaurant_rounded
        : label.contains('BIO')
            ? Icons.coffee_rounded
            : Icons.free_breakfast_rounded;
    final ts = ctrl.timetableEngine.snapshot;
    final nextBlock = ts.nextBlock;
    final nextTime = nextBlock != null
        ? _formatStartMinutes(nextBlock.startMinutes)
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeBadge(context, "BREAK"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(icon, color: AppTheme.textSecondary(context), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                nextTime.isNotEmpty
                    ? "Next class starts at $nextTime"
                    : "No session can be started during break",
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(BuildContext context, dynamic mainCard, DashboardController ctrl) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectName = ctrl.resolveSubjectName(mainCard);
    final subjectCode = mainCard.subjectCode;
    final roomNumber = _cleanRoom((mainCard.roomNumber as String?) ?? 'N/A');
    final isTutorialOrLibrary = subjectCode.toLowerCase().contains('tutorial') ||
        subjectCode.toLowerCase().contains('library') ||
        subjectName.toLowerCase().contains('tutorial') ||
        subjectName.toLowerCase().contains('library');

    final ts = ctrl.timetableEngine.snapshot;

    String badgeText = "UPCOMING";
    if (ts.isClassActive) {
      badgeText = "IN PROGRESS";
    } else if ((ts.isAfterLastClass || ts.isWeekend) && ts.nextBlock != null) {
      final label = ts.breakLabel ?? 'TOMORROW';
      badgeText = label.toUpperCase();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeBadge(context, badgeText,
                  color: badgeText == 'IN PROGRESS' ? const Color(0xFF84CC16) : AppTheme.accentTeal),
              const SizedBox(height: 14),
              Text(
                "$subjectCode - $subjectName",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              _buildDetailRow(
                context,
                Icons.location_on_rounded,
                roomNumber,
                color: const Color(0xFF84CC16),
                onTap: () => showRoomInfoSheet(context, roomNumber),
              ),
              const SizedBox(height: 24),
              if (ts.isAfterLastClass || ts.isWeekend)
                _buildStatusRow(context, 'Classes ended for today', Icons.done_all_rounded)
              else if (isTutorialOrLibrary)
                _buildStatusRow(context, subjectName, Icons.event_seat_rounded)
              else
                _buildSwipeToStart(context, mainCard),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double cardWidth = MediaQuery.of(context).size.width - 40;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonLoader(width: 120, height: 24, borderRadius: 12),
          const SizedBox(height: 16),
          SkeletonLoader(width: cardWidth * 0.75, height: 28, borderRadius: 6),
          const SizedBox(height: 8),
          SkeletonLoader(width: cardWidth * 0.5, height: 20, borderRadius: 6),
          const SizedBox(height: 24),
          SkeletonLoader(width: cardWidth * 0.6, height: 52, borderRadius: 16),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DashboardController ctrl) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final breakLabel = ctrl.breakLabel;
    final mainCard = ctrl.mainCardClass;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -40,
                    right: -40,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTimeBadge(context, "END OF DAY"),
              const SizedBox(height: 14),
              Text(
                breakLabel.isNotEmpty ? breakLabel : "No Active Session",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              _buildDetailRow(
                context,
                Icons.event_busy_rounded,
                "No class schedule for today",
                color: AppTheme.textSecondary(context),
              ),
              const SizedBox(height: 24),
              if (mainCard != null)
                _buildStatusRow(context, 'Classes ended for today', Icons.done_all_rounded)
              else
                _buildStatusRow(context, 'See you tomorrow!', Icons.wb_sunny_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBadge(BuildContext context, String text) {
    return PremiumClockBadge(
      text: text,
      icon: Icons.schedule_rounded,
      iconColor: AppTheme.accentTeal,
    );
  }

  Widget _buildTimeBadge(BuildContext context, String text, {Color color = AppTheme.accentTeal}) {
    return PremiumClockBadge(
      text: text,
      icon: Icons.schedule_rounded,
      iconColor: color,
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String text, {InlineSpan? richText, Color? color, VoidCallback? onTap}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color defaultColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B);
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color ?? defaultColor, size: 18),
          const SizedBox(width: 8),
          if (richText != null)
            Flexible(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: GoogleFonts.inter(
                    color: color ?? defaultColor,
                    fontSize: 14,
                    fontWeight: color != null ? FontWeight.bold : FontWeight.w500,
                  ),
                  children: [richText],
                ),
              ),
            )
          else
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: color ?? defaultColor,
                  fontSize: 14,
                  fontWeight: color != null ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline_rounded,
              size: 12,
              color: (color ?? defaultColor).withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String msg, IconData icon) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.textSecondary(context), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              msg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeToStart(BuildContext context, dynamic mainCard) {
    return SwipeToStartSession(
      onComplete: () async {
        final controller = context.read<DashboardController>();

        controller.refreshData();

        if (context.mounted) {
          await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => AttendanceCodeScreen(
                courseName: controller.resolveSubjectName(mainCard),
                room: mainCard.roomNumber,
                scheduledClass: mainCard,
              ),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                return FadeTransition(
                  opacity: curved,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
                    child: child,
                  ),
                );
              },
            ),
          );

          if (context.mounted) {
            controller.refreshData();
          }
        }
      },
    );
  }

  Widget _buildViewLiveButton(BuildContext context, String sessionId, String courseName, String courseId, String sectionId) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (context) => LiveMonitorController(
                context.read<AttendanceRepository>(),
                sessionId,
                courseId: courseId.isEmpty ? null : courseId,
                sectionId: sectionId.isEmpty ? null : sectionId,
              ),
              child: LiveMonitorScreen(courseName: courseName),
            ),
          ),
        );
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.accentTeal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "View Live",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, color: Colors.black, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer header
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerSectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SkeletonLoader(width: 120, height: 22, borderRadius: 6),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium swipe-to-start session widget
// ─────────────────────────────────────────────────────────────────────────────

enum _SwipeState { idle, loading, error }

class SwipeToStartSession extends StatefulWidget {
  final Future<void> Function() onComplete;

  const SwipeToStartSession({Key? key, required this.onComplete}) : super(key: key);

  @override
  State<SwipeToStartSession> createState() => _SwipeToStartSessionState();
}

class _SwipeToStartSessionState extends State<SwipeToStartSession>
    with TickerProviderStateMixin {
  _SwipeState _state = _SwipeState.idle;
  bool _requestInFlight = false;

  late AnimationController _handleController;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerProgress;

  double _maxDrag = 0;
  static const double _handleSize = 56;
  static const Duration _snapDuration = Duration(milliseconds: 250);
  static const Duration _errorDisplayDuration = Duration(seconds: 3);

  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _handleController = AnimationController(
      vsync: this,
      duration: _snapDuration,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerProgress = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _handleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _onSwipeComplete() {
    if (_requestInFlight) return;
    _requestInFlight = true;
    HapticService.heavy();
    setState(() => _state = _SwipeState.loading);
    _executeSession();
  }

  Future<void> _executeSession() async {
    try {
      await widget.onComplete();
      if (mounted) {
        _snapBack();
      }
    } catch (e) {
      if (!mounted) return;
      final message = _friendlyError(e);
      setState(() {
        _state = _SwipeState.error;
        _errorMessage = message;
      });
      debugPrint("SwipeToStart error: $e");

      // Show SnackBar
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                    Expanded(child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis)),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Animate handle back and reset after delay
      await Future.delayed(_errorDisplayDuration);
      if (!mounted) return;
      _snapBack();
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SLOT_NOT_CURRENT') || msg.contains('not currently active')) {
      return 'This class is not currently in session.';
    }
    if (msg.contains('ALREADY_ACTIVE') || msg.contains('already active')) {
      return 'A session is already active. End it first.';
    }
    if (msg.contains('AUTH') || msg.contains('401') || msg.contains('token')) {
      return 'Authentication expired. Please log in again.';
    }
    if (msg.contains('NOT_FOUND') || msg.contains('404') || msg.contains('Course not')) {
      return 'Course not assigned to you.';
    }
    if (msg.contains('timeout') || msg.contains('Connection')) {
      return 'Server unavailable. Check your connection.';
    }
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return 'Server error. Please try again.';
    }
    if (msg.contains('Authentication required')) {
      return 'Authentication expired. Please log in again.';
    }
    // Strip Exception wrapper for display
    final cleaned = msg.replaceFirst('Exception: ', '');
    return cleaned.length > 80 ? '${cleaned.substring(0, 77)}...' : cleaned;
  }

  void _snapBack() {
    _handleController.animateTo(
      0.0,
      duration: _snapDuration,
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (mounted) {
        setState(() {
          _state = _SwipeState.idle;
          _errorMessage = '';
        });
        _requestInFlight = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final tealColor = AppTheme.accentTeal;

    return LayoutBuilder(
      builder: (context, constraints) {
        _maxDrag = constraints.maxWidth - _handleSize;

        final handleLeft = _state == _SwipeState.loading || _state == _SwipeState.error
            ? _maxDrag
            : _handleController.value * _maxDrag;

        final progressFraction = (_state == _SwipeState.idle)
            ? (_maxDrag > 0 ? handleLeft / _maxDrag : 0.0)
            : 1.0;

        final Color stateColor;
        switch (_state) {
          case _SwipeState.loading:
            stateColor = tealColor;
            break;
          case _SwipeState.error:
            stateColor = AppTheme.errorRed;
            break;
          case _SwipeState.idle:
            stateColor = tealColor;
        }

        return Container(
          width: double.infinity,
          height: _handleSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _state == _SwipeState.error
                  ? AppTheme.errorRed.withValues(alpha: 0.3)
                  : _state == _SwipeState.loading
                      ? tealColor.withValues(alpha: 0.3)
                      : isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _state == _SwipeState.error
                    ? AppTheme.errorRed.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Progress fill track
              if (progressFraction > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: handleLeft + (_handleSize / 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          stateColor.withValues(alpha: 0.12),
                          stateColor.withValues(alpha: 0.04),
                        ],
                      ),
                    ),
                  ),
                ),

              // Shimmer during loading
              if (_state == _SwipeState.loading || _state == _SwipeState.error)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerProgress,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ShimmerPainter(
                          progress: _shimmerProgress.value,
                          color: _state == _SwipeState.error
                              ? AppTheme.errorRed
                              : tealColor,
                        ),
                      );
                    },
                  ),
                ),

              // Center hint text
              if (_state == _SwipeState.idle && progressFraction < 0.3)
                Center(
                  child: Opacity(
                    opacity: (1.0 - (progressFraction / 0.3)).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "SWIPE TO START SESSION",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Loading text
              if (_state == _SwipeState.loading)
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(tealColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Starting attendance session...",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF475569),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Error text
              if (_state == _SwipeState.error)
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _errorMessage,
                          style: GoogleFonts.inter(
                            color: AppTheme.errorRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // Draggable handle
              if (_state == _SwipeState.idle)
                AnimatedPositioned(
                  duration: _snapDuration,
                  curve: Curves.easeOutCubic,
                  left: handleLeft,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_requestInFlight) return;
                      final newValue = (_handleController.value * _maxDrag + details.delta.dx)
                          .clamp(0.0, _maxDrag);
                      _handleController.value = newValue / _maxDrag;
                    },
                    onHorizontalDragEnd: (details) {
                      if (_requestInFlight) return;
                      if (_handleController.value >= 0.95) {
                        _handleController.animateTo(1.0, duration: const Duration(milliseconds: 80), curve: Curves.easeOut);
                        _onSwipeComplete();
                      } else {
                        _snapBack();
                      }
                    },
                    child: Container(
                      width: _handleSize,
                      height: _handleSize,
                      margin: const EdgeInsets.all(0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            tealColor,
                            tealColor.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: tealColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.black,
                        size: 18,
                      ),
                    ),
                  ),
                ),

              // Loading/error handle (locked at end)
              if (_state == _SwipeState.loading || _state == _SwipeState.error)
                Positioned(
                  left: _maxDrag,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: _handleSize,
                    height: _handleSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _state == _SwipeState.error
                            ? [AppTheme.errorRed, AppTheme.errorRed.withValues(alpha: 0.85)]
                            : [tealColor, tealColor.withValues(alpha: 0.85)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _state == _SwipeState.error ? Icons.close_rounded : Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.06),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(
        size.width * progress - size.width * 0.3,
        0,
        size.width * 0.6,
        size.height,
      ));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown badge
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownBadge extends StatefulWidget {
  final String endTime;
  const _CountdownBadge({required this.endTime});

  @override
  State<_CountdownBadge> createState() => _CountdownBadgeState();
}

class _CountdownBadgeState extends State<_CountdownBadge> {
  Timer? _timer;
  String _display = "";

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    try {
      final parts = widget.endTime.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && hour < 12) hour += 12;
        if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
      final now = DateTime.now();
      final end = DateTime(now.year, now.month, now.day, hour, minute);
      final diff = end.difference(now);
      if (diff.isNegative) {
        setState(() => _display = "00:00:00");
        return;
      }
      String d(int n) => n.toString().padLeft(2, "0");
      setState(() {
        _display = "${d(diff.inHours)}:${d(diff.inMinutes.remainder(60))}:${d(diff.inSeconds.remainder(60))} LEFT";
      });
    } catch (_) {
      setState(() => _display = "00:00:00");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, color: AppTheme.accentTeal, size: 16),
          const SizedBox(width: 6),
          Text(
            _display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.jetBrainsMono(
              color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Room info bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

void showRoomInfoSheet(BuildContext context, String room) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  String block = 'Block A';
  String floor = 'Ground Floor';

  if (room.contains('B')) block = 'Block B';
  if (room.contains('C')) block = 'Block C';

  final match = RegExp(r'\d+').firstMatch(room);
  if (match != null) {
    final n = int.parse(match.group(0)!);
    if (n >= 400) { floor = '4th Floor'; }
    else if (n >= 300) { floor = '3rd Floor'; }
    else if (n >= 200) { floor = '2nd Floor'; }
    else if (n >= 100) { floor = '1st Floor'; }
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoomSheet(
      room: room,
      block: block,
      floor: floor,
      isDark: isDark,
    ),
  );
}

class _RoomSheet extends StatelessWidget {
  final String room;
  final String block;
  final String floor;
  final bool isDark;

  const _RoomSheet({
    required this.room,
    required this.block,
    required this.floor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const lime = AppTheme.highlightLime;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lime.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.location_on_rounded, color: lime),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room $room',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Location Details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
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
          _InfoRow(icon: Icons.business_rounded, label: 'Block', value: block, isDark: isDark),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.layers_rounded, label: 'Floor', value: floor, isDark: isDark),
          const SizedBox(height: 16),
          _InfoRow(icon: Icons.map_rounded, label: 'Navigation', value: 'Follow signs to $block', isDark: isDark),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({required this.icon, required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary(context)),
        const SizedBox(width: 16),
        Flexible(
          child: Text('$label: ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 15)),
        ),
        Flexible(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              )),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium clock/timer badge widget
// ─────────────────────────────────────────────────────────────────────────────

class PremiumClockBadge extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color iconColor;

  const PremiumClockBadge({
    super.key,
    required this.text,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.jetBrainsMono(
              color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
