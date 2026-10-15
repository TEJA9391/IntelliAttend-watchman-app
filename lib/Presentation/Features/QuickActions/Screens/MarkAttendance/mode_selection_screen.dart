import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/mark_attendance_controller.dart';
import 'attendance_session_screen.dart';
import 'qr_attendance_screen.dart';
import 'face_recognition_screen.dart';
import 'nfc_attendance_screen.dart';
import 'bluetooth_attendance_screen.dart';

class ModeSelectionScreen extends StatefulWidget {
  final String courseCode;
  final String courseName;
  final AttendanceMode selectedMode;

  const ModeSelectionScreen({
    Key? key,
    required this.courseCode,
    required this.courseName,
    required this.selectedMode,
  }) : super(key: key);

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarkAttendanceController>().loadRoster(widget.courseCode, mode: widget.selectedMode);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final controller = context.watch<MarkAttendanceController>();

    if (controller.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Loading roster...",
                style: GoogleFonts.inter(color: textSec, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.error != null) {
      return Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorRed),
                const SizedBox(height: 16),
                Text(controller.error!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: textCol, fontSize: 14)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => controller.loadRoster(widget.courseCode, mode: widget.selectedMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: AppTheme.accentTeal, borderRadius: BorderRadius.circular(12)),
                    child: Text("Retry", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return _buildModeScreen(context, controller);
      },
    );
  }

  Widget _buildModeScreen(BuildContext context, MarkAttendanceController controller) {
    switch (widget.selectedMode) {
      case AttendanceMode.manual:
        return AttendanceSessionScreen(
          courseCode: widget.courseCode,
          courseName: widget.courseName,
        );
      case AttendanceMode.qr:
        return QrAttendanceScreen(
          courseCode: widget.courseCode,
          courseName: widget.courseName,
        );
      case AttendanceMode.face:
        return FaceRecognitionScreen(
          courseCode: widget.courseCode,
          courseName: widget.courseName,
        );
      case AttendanceMode.nfc:
        return NfcAttendanceScreen(
          courseCode: widget.courseCode,
          courseName: widget.courseName,
        );
      case AttendanceMode.bluetooth:
        return BluetoothAttendanceScreen(
          courseCode: widget.courseCode,
          courseName: widget.courseName,
        );
      case AttendanceMode.hybrid:
        return AttendanceSessionScreen(
          courseCode: widget.courseCode,
          courseName: widget.courseName,
        );
    }
  }
}
