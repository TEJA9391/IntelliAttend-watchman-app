import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'live_monitor_controller.dart';
import 'seating_arrangement_widget.dart';

class LiveMonitorScreen extends StatefulWidget {
  final String courseName;

  const LiveMonitorScreen({Key? key, required this.courseName}) : super(key: key);

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LiveMonitorController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return _buildLoadingScreen(context);
        }
        if (controller.hasTimedOut) {
          return _buildTimeoutScreen(context, controller);
        }
        return _buildMainScreen(context, controller);
      },
    );
  }

  // ─── Loading ────────────────────────────────────────────────────────

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, null, isLoading: true),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Connecting to session...",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Timeout ────────────────────────────────────────────────────────

  Widget _buildTimeoutScreen(BuildContext context, LiveMonitorController controller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, controller),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_off_rounded,
                          color: AppTheme.errorRed,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Connection Timeout",
                        style: GoogleFonts.inter(
                          color: AppTheme.text(context),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Session not yet available on SmartBoard.\nUsing Seating Arrangement mode.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary(context),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => controller.retry(),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(
                            "RETRY CONNECTION",
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(child: SeatingArrangementWidget(controller: controller)),
          ],
        ),
      ),
    );
  }

  // ─── Main Screen ────────────────────────────────────────────────────

  Widget _buildMainScreen(BuildContext context, LiveMonitorController controller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, controller),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildStatusPills(context, controller)),
                  SliverToBoxAdapter(child: _buildStatsHero(context, controller)),
                  if (controller.reconcileMessage != null)
                    SliverToBoxAdapter(child: _buildReconcileBanner(context, controller)),
                  SliverToBoxAdapter(child: _buildSectionHeader(context, controller)),
                  SliverFillRemaining(
                    child: SeatingArrangementWidget(controller: controller),
                  ),
                ],
              ),
            ),
            _buildBottomBar(context, controller),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, LiveMonitorController? controller, {bool isLoading = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.text(context),
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isLoading && controller != null)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getLiveColor(controller),
                              boxShadow: [
                                BoxShadow(
                                  color: _getLiveColor(controller).withValues(
                                    alpha: 0.3 + (_pulseController.value * 0.3),
                                  ),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    Text(
                      "Live Monitor",
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getLiveColor(LiveMonitorController controller) {
    switch (controller.wsConnectionState) {
      case 'connected':
        return Colors.greenAccent;
      case 'connecting':
      case 'reconnecting':
        return Colors.amberAccent;
      default:
        return AppTheme.errorRed;
    }
  }

  // ─── Status Pills ───────────────────────────────────────────────────

  Widget _buildStatusPills(BuildContext context, LiveMonitorController controller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatusPill(
              icon: controller.isBoardConnected ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
              label: controller.isBoardConnected ? "Board Ready" : "Board Pending",
              color: controller.isBoardConnected ? Colors.greenAccent : Colors.white38,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  String _wsLabel(LiveMonitorController controller) {
    switch (controller.wsConnectionState) {
      case 'connected':
        return "Live Sync";
      case 'connecting':
        return "Connecting";
      case 'reconnecting':
        return "Reconnecting";
      default:
        return "Offline";
    }
  }

  // ─── Stats Hero ─────────────────────────────────────────────────────

  Widget _buildStatsHero(BuildContext context, LiveMonitorController controller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = controller.attendanceRate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accentTeal,
              AppTheme.accentTeal.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentTeal.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: rate / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${rate.toInt()}%",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "Attendance",
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 28),
            // Stat columns
            Expanded(
              child: Column(
                children: [
                  _StatRow(label: "Present", value: "${controller.presentCount}", color: Colors.white),
                  const SizedBox(height: 12),
                  _StatRow(label: "Absent", value: "${controller.absentCount}", color: Colors.white),
                  const SizedBox(height: 12),
                  _StatRow(label: "Total", value: "${controller.totalCount}", color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reconcile Banner ───────────────────────────────────────────────

  Widget _buildReconcileBanner(BuildContext context, LiveMonitorController controller) {
    final isCorrected = controller.reconcileMessage?.contains("corrected") ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCorrected
              ? AppTheme.highlightLime.withValues(alpha: 0.1)
              : AppTheme.accentTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCorrected
                ? AppTheme.highlightLime.withValues(alpha: 0.3)
                : AppTheme.accentTeal.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCorrected ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: isCorrected ? AppTheme.highlightLime : AppTheme.accentTeal,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.reconcileMessage ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: isCorrected ? AppTheme.highlightLime : AppTheme.accentTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (controller.isReconciling)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentTeal),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Section Header ─────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, LiveMonitorController controller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Students",
            style: GoogleFonts.inter(
              color: AppTheme.text(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconAction(
                icon: Icons.sync_rounded,
                onTap: controller.isReconciling ? null : () => controller.refreshRoster(),
                tooltip: "Refresh Roster",
                isDark: isDark,
                isLoading: controller.isReconciling,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Bottom Bar ─────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, LiveMonitorController controller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _confirmEndSession(context, controller),
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(
                "END SESSION",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed.withValues(alpha: 0.08),
                foregroundColor: AppTheme.errorRed,
                elevation: 0,
                side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.3), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
    );
  }

  void _confirmEndSession(BuildContext context, LiveMonitorController controller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("End Session?", style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        content: Text(
          "This will stop live tracking for all students.",
          style: GoogleFonts.inter(color: AppTheme.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: GoogleFonts.inter(color: AppTheme.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () {
              controller.terminateSession();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("CONFIRM", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─── Status Pill ──────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Row ─────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: color.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ─── Icon Action ──────────────────────────────────────────────────────

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool isDark;
  final bool isLoading;

  const _IconAction({
    required this.icon,
    this.onTap,
    required this.tooltip,
    required this.isDark,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.accentTeal,
                  ),
                )
              : Icon(
                  icon,
                  color: onTap != null ? AppTheme.accentTeal : AppTheme.textSecondary(context),
                  size: 18,
                ),
        ),
      ),
    );
  }
}
