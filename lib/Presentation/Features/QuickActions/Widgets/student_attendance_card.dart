import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';

class StudentAttendanceCard extends StatelessWidget {
  final ClassStudent student;
  final AttendanceStatus? status;
  final bool isSelected;
  final bool isSelectionMode;
  final ValueChanged<AttendanceStatus>? onStatusChanged;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onUndoTap;
  final String? note;
  final ValueChanged<String>? onNoteChanged;
  final bool showLastAttendance;
  final DateTime? lastAttendanceDate;
  final bool canUndo;

  const StudentAttendanceCard({
    Key? key,
    required this.student,
    this.status,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onStatusChanged,
    this.onTap,
    this.onLongPress,
    this.onHistoryTap,
    this.onUndoTap,
    this.note,
    this.onNoteChanged,
    this.showLastAttendance = false,
    this.lastAttendanceDate,
    this.canUndo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AttendanceStatus? currentStatus = status;
    final Color statusColor = currentStatus == null
        ? textSec
        : _statusColor(currentStatus);
    final String statusLabel =
        currentStatus == null ? 'Unmarked' : _statusLabel(currentStatus);
    final initials = student.name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();
    final attendanceColor = student.attendancePercentage >= 75
        ? (student.attendancePercentage >= 90 ? const Color(0xFF22C55E) : AppTheme.accentTeal)
        : AppTheme.errorRed;
    final isDefaulter = student.isDefaulter || student.attendancePercentage < 65;

    return GestureDetector(
      onTap: () {
        HapticService.light();
        if (isSelectionMode) {
          onLongPress?.call();
        } else {
          onTap?.call();
        }
      },
      onLongPress: () {
        HapticService.medium();
        onLongPress?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentTeal.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentTeal.withValues(alpha: 0.3)
                : isDefaulter
                    ? AppTheme.errorRed.withValues(alpha: 0.3)
                    : AppTheme.border(context),
            width: isSelected || isDefaulter ? 1.5 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                if (isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? AppTheme.accentTeal : textSec,
                      size: 22,
                    ),
                  ),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Text(
                        initials,
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isDefaulter)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.warning_rounded, color: Colors.white, size: 7),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              student.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: textCol,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isDefaulter) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'RISK',
                                style: GoogleFonts.inter(
                                  color: AppTheme.errorRed,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              student.rollNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: textSec,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: attendanceColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "${student.attendancePercentage.toStringAsFixed(0)}%",
                              style: GoogleFonts.inter(
                                color: attendanceColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (student.gender != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              student.gender == 'Male' ? Icons.male_rounded : Icons.female_rounded,
                              color: student.gender == 'Male' ? const Color(0xFF60A5FA) : const Color(0xFFF472B6),
                              size: 12,
                            ),
                          ],
                          if (student.section != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              student.section!,
                              style: GoogleFonts.inter(
                                color: textSec,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (showLastAttendance && student.lastSeen != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          "Last: ${_formatLastSeen(student.lastSeen!)}",
                          style: GoogleFonts.inter(
                            color: textSec.withValues(alpha: 0.7),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!isSelectionMode && canUndo) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          HapticService.light();
                          onUndoTap?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.undo_rounded, color: AppTheme.accentPurple, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                'Undo',
                                style: GoogleFonts.inter(
                                  color: AppTheme.accentPurple,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (!isSelectionMode) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildStatusButton(context, 'Present', AttendanceStatus.present, currentStatus, const Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  _buildStatusButton(context, 'Absent', AttendanceStatus.absent, currentStatus, AppTheme.errorRed),
                  const SizedBox(width: 6),
                  _buildStatusButton(context, 'Late', AttendanceStatus.late, currentStatus, const Color(0xFFFBBF24)),
                  const SizedBox(width: 6),
                  _buildStatusButton(context, 'Leave', AttendanceStatus.leave, currentStatus, const Color(0xFF60A5FA)),
                ],
              ),
              if (note != null && note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.note_alt_rounded, color: AppTheme.accentPurple.withValues(alpha: 0.6), size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: textSec.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (onHistoryTap != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    HapticService.light();
                    onHistoryTap?.call();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, color: AppTheme.accentTeal.withValues(alpha: 0.7), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'View History',
                        style: GoogleFonts.inter(
                          color: AppTheme.accentTeal.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context, String label, AttendanceStatus targetStatus, AttendanceStatus? currentStatus, Color color) {
    final isActive = currentStatus == targetStatus;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService.selection();
          onStatusChanged?.call(targetStatus);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.1),
              width: isActive ? 1 : 0.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? color : AppTheme.textSecondary(context),
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present: return const Color(0xFF22C55E);
      case AttendanceStatus.absent: return AppTheme.errorRed;
      case AttendanceStatus.late: return const Color(0xFFFBBF24);
      case AttendanceStatus.leave: return const Color(0xFF60A5FA);
      case AttendanceStatus.holiday: return AppTheme.accentPurple;
    }
  }

  String _statusLabel(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present: return 'Present';
      case AttendanceStatus.absent: return 'Absent';
      case AttendanceStatus.late: return 'Late';
      case AttendanceStatus.leave: return 'Leave';
      case AttendanceStatus.holiday: return 'Holiday';
    }
  }

  String _formatLastSeen(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
