import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'live_monitor_controller.dart';
import 'package:google_fonts/google_fonts.dart';

class SeatingArrangementWidget extends StatefulWidget {
  final LiveMonitorController controller;

  const SeatingArrangementWidget({Key? key, required this.controller}) : super(key: key);

  @override
  State<SeatingArrangementWidget> createState() => _SeatingArrangementWidgetState();
}

class _SeatingArrangementWidgetState extends State<SeatingArrangementWidget> {
  @override
  Widget build(BuildContext context) {
    final students = widget.controller.mergedStudents;

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.accentTeal),
            const SizedBox(height: 16),
            Text(
              "Loading enrollment...",
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildLegend(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 500 ? 7 : (constraints.maxWidth > 350 ? 5 : 4);
              return GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  return _buildSeat(context, student, index);
                },
              );
            },
          ),
        ),
        _buildMarkAttendanceButton(context),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(context, "Absent", Colors.grey.withOpacity(0.2)),
          const SizedBox(width: 16),
          _buildLegendItem(context, "Selected", AppTheme.accentTeal.withOpacity(0.5)),
          const SizedBox(width: 16),
          _buildLegendItem(context, "Present", Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary(context))),
      ],
    );
  }

  Widget _buildSeat(BuildContext context, StudentAttendance student, int index) {
    final bool isSelected = widget.controller.selectedStudentIds.contains(student.id);
    final bool isPresent = student.status == StudentStatus.present;

    Color seatColor = Colors.grey.withOpacity(0.2);
    if (isPresent) {
      seatColor = Colors.greenAccent;
    } else if (isSelected) {
      seatColor = AppTheme.accentTeal.withOpacity(0.8);
    }

    // Shorten roll number (e.g. 23N31A6645 -> 45 or just use last 2 chars)
    String displayId = student.id;
    if (displayId.length > 2) {
      displayId = displayId.substring(displayId.length - 2);
    }
    
    // If it's a numeric ID but shorter than 2 digits, pad it
    if (int.tryParse(displayId) != null && displayId.length == 1) {
      displayId = "0$displayId";
    }

    return GestureDetector(
      onTap: () {
        if (isPresent) return;
        _directMarkPresent(context, student, index);
      },
      onLongPress: () => _showStudentInfoPopup(context, student, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accentTeal : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: AppTheme.accentTeal.withOpacity(0.3), blurRadius: 8)
          ] : null,
        ),
        child: Center(
          child: Text(
            displayId,
            style: GoogleFonts.inter(
              color: isPresent || isSelected ? Colors.black : AppTheme.textSecondary(context),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentInfoPopup(BuildContext context, StudentAttendance student, int seatIndex) {
    final bool isPresent = student.status == StudentStatus.present;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isPresent
                  ? Colors.greenAccent.withValues(alpha: 0.15)
                  : AppTheme.accentTeal.withValues(alpha: 0.15),
              backgroundImage: student.image != null ? NetworkImage(student.image!) : null,
              child: student.image == null
                  ? Icon(
                      Icons.person_rounded,
                      color: isPresent ? Colors.greenAccent : AppTheme.accentTeal,
                      size: 28,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Roll: ${student.id}",
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isPresent
                    ? Colors.greenAccent.withValues(alpha: 0.15)
                    : AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPresent ? "Present" : "Absent",
                style: GoogleFonts.inter(
                  color: isPresent ? Colors.greenAccent : AppTheme.errorRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CLOSE", style: GoogleFonts.inter(color: AppTheme.textSecondary(context))),
          ),
        ],
      ),
    );
  }

  void _directMarkPresent(BuildContext context, StudentAttendance student, int seatIndex) async {
    try {
      final success = await widget.controller.markStudentPresent(student.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${student.name} marked present."),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 1),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to mark attendance."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = "Failed to mark attendance.";
        if (e.toString().contains("ALREADY_MARKED")) {
          final source = e.toString().split(":").last;
          msg = "Already marked by $source";
        } else if (e.toString().contains("MISSING_EMAIL")) {
          msg = "Cannot mark: Student email missing.";
        } else if (e.toString().contains("SERVER_ERROR")) {
          msg = e.toString().replaceFirst("Exception: SERVER_ERROR:", "");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildMarkAttendanceButton(BuildContext context) {
    final count = widget.controller.selectedStudentIds.length;
    final bool isEnabled = count > 0 && !widget.controller.isMarkingSelected;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isEnabled ? () => widget.controller.markSelectedPresent() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.grey.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: widget.controller.isMarkingSelected
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  count > 0 ? "MARK ATTENDANCE ($count)" : "MARK ATTENDANCE",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
        ),
      ),
    );
  }
}
