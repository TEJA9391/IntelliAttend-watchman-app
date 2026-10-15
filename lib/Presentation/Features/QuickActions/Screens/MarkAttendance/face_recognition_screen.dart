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

class _RecognizedFace {
  final String studentId;
  final String studentName;
  final double confidence;
  final DateTime timestamp;
  _RecognizedFace({
    required this.studentId,
    required this.studentName,
    required this.confidence,
    required this.timestamp,
  });
}

class FaceRecognitionScreen extends StatefulWidget {
  final String courseCode;
  final String courseName;
  const FaceRecognitionScreen({Key? key, required this.courseCode, required this.courseName}) : super(key: key);
  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  Timer? _scanTimer;
  double _confidenceLevel = 0.0;
  double _scanProgress = 0.0;
  Timer? _progressTimer;
  final List<_RecognizedFace> _recognizedFaces = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _progressTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startScanning() {
    HapticService.medium();
    final controller = context.read<MarkAttendanceController>();
    controller.startCamera();
    setState(() {
      _isScanning = true;
      _recognizedFaces.clear();
      _scanProgress = 0.0;
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _scanProgress = (_scanProgress + 0.02).clamp(0.0, 1.0);
      });
    });

    _scanTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || controller.roster.isEmpty) { timer.cancel(); return; }

      final random = Random();
      final unmarked = controller.roster.where(
        (s) => !controller.recognizedStudentIds.contains(s.id) && !controller.unknownFaceIds.contains(s.id),
      ).toList();

      if (unmarked.isEmpty) {
        _stopScanning();
        return;
      }

      final student = unmarked[random.nextInt(unmarked.length)];
      final confidence = 75.0 + random.nextDouble() * 25.0;

      controller.simulateFaceDetection();

      setState(() {
        _confidenceLevel = confidence;
        if (confidence > 85) {
          _recognizedFaces.insert(0, _RecognizedFace(
            studentId: student.id,
            studentName: student.name,
            confidence: confidence,
            timestamp: DateTime.now(),
          ));
        }
      });

      HapticService.light();

      if (_scanProgress >= 1.0) {
        _scanProgress = 0.0;
      }
    });
  }

  void _stopScanning() {
    HapticService.heavy();
    final controller = context.read<MarkAttendanceController>();
    controller.stopCamera();
    _scanTimer?.cancel();
    _progressTimer?.cancel();
    setState(() {
      _isScanning = false;
    });
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
                      Text("Face Recognition", style: GoogleFonts.inter(color: textCol, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
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
            _buildCameraViewfinder(context, controller, textCol, textSec, isDark),
            const SizedBox(height: 16),
            _buildStatusBar(context, controller, textCol, textSec, isDark),
            const SizedBox(height: 16),
            _buildRecognizedFacesList(context, controller, textCol, textSec, isDark),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, controller, textCol, isDark),
    );
  }

  Widget _buildCameraViewfinder(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return Container(
          height: 220,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isScanning
                  ? AppTheme.accentTeal.withValues(alpha: _pulseAnimation.value * 0.6)
                  : AppTheme.border(context),
              width: _isScanning ? 2 : 1,
            ),
            boxShadow: _isScanning ? [
              BoxShadow(
                color: AppTheme.accentTeal.withValues(alpha: 0.15 * _pulseAnimation.value),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ..._buildFaceGrid(context, isDark),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.face_rounded,
                    size: 64,
                    color: _isScanning
                        ? AppTheme.accentTeal.withValues(alpha: _pulseAnimation.value)
                        : textSec.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isScanning ? "Scanning faces..." : "Camera inactive",
                    style: GoogleFonts.inter(
                      color: _isScanning ? AppTheme.accentTeal : textSec,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isScanning) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _scanProgress,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildFaceGrid(BuildContext context, bool isDark) {
    if (!_isScanning) return [];
    return [
      Positioned(
        top: 16, left: 16,
        child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2), left: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2)))),
      ),
      Positioned(
        top: 16, right: 16,
        child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border(top: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2), right: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2)))),
      ),
      Positioned(
        bottom: 16, left: 16,
        child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2), left: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2)))),
      ),
      Positioned(
        bottom: 16, right: 16,
        child: Container(width: 40, height: 40, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2), right: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.5), width: 2)))),
      ),
    ];
  }

  Widget _buildStatusBar(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    final detectedCount = controller.recognizedStudentIds.length;
    final unknownCount = controller.unknownFaceIds.length;
    final confidenceColor = _confidenceLevel > 85
        ? const Color(0xFF22C55E)
        : _confidenceLevel > 70
            ? const Color(0xFFFBBF24)
            : AppTheme.errorRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Flexible(
            child: _buildStatusChip(
              icon: _isScanning ? Icons.play_circle_fill_rounded : Icons.pause_circle_filled_rounded,
              label: _isScanning ? "Scanning" : "Paused",
              color: _isScanning ? const Color(0xFF22C55E) : textSec,
              textCol: textCol,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _buildStatusChip(
              icon: Icons.face_rounded,
              label: "$detectedCount faces",
              color: AppTheme.accentTeal,
              textCol: textCol,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _buildStatusChip(
              icon: Icons.help_outline_rounded,
              label: "$unknownCount unknown",
              color: unknownCount > 0 ? const Color(0xFFFBBF24) : textSec,
              textCol: textCol,
              isDark: isDark,
            ),
          ),
          const Spacer(),
          if (_isScanning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: confidenceColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${_confidenceLevel.toStringAsFixed(0)}%",
                style: GoogleFonts.jetBrainsMono(color: confidenceColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({required IconData icon, required String label, required Color color, required Color textCol, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizedFacesList(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    if (_recognizedFaces.isEmpty) {
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
              Icon(Icons.face_retouching_off_rounded, size: 36, color: textSec.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Text("No faces detected yet", style: GoogleFonts.inter(color: textSec, fontSize: 13)),
              const SizedBox(height: 4),
              Text("Start scanning to detect students", style: GoogleFonts.inter(color: textSec.withValues(alpha: 0.6), fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Detected Faces (${_recognizedFaces.length})", style: GoogleFonts.inter(color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._recognizedFaces.asMap().entries.map((entry) {
          final face = entry.value;
          final confColor = face.confidence > 90
              ? const Color(0xFF22C55E)
              : face.confidence > 80
                  ? AppTheme.accentTeal
                  : const Color(0xFFFBBF24);
          final timeStr = "${face.timestamp.hour.toString().padLeft(2, '0')}:${face.timestamp.minute.toString().padLeft(2, '0')}:${face.timestamp.second.toString().padLeft(2, '0')}";

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
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.15),
                  child: Text(
                    face.studentName.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join(),
                    style: GoogleFonts.inter(color: AppTheme.accentTeal, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(face.studentName, style: GoogleFonts.inter(color: textCol, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(timeStr, style: GoogleFonts.jetBrainsMono(color: textSec, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: confColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text("${face.confidence.toStringAsFixed(1)}%", style: GoogleFonts.jetBrainsMono(color: confColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Icon(Icons.check_circle_rounded, color: const Color(0xFF22C55E), size: 20),
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
                onTap: _isScanning ? _stopScanning : _startScanning,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _isScanning ? AppTheme.errorRed.withValues(alpha: 0.12) : AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: _isScanning ? Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)) : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isScanning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: _isScanning ? AppTheme.errorRed : textCol,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isScanning ? "Stop Scan" : "Start Scan",
                          style: GoogleFonts.inter(color: _isScanning ? AppTheme.errorRed : textCol, fontSize: 13, fontWeight: FontWeight.w600),
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
                onTap: controller.recognizedStudentIds.isNotEmpty ? _navigateToReview : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: controller.recognizedStudentIds.isNotEmpty ? AppTheme.accentTeal : textCol.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "Review & Submit",
                      style: GoogleFonts.inter(
                        color: controller.recognizedStudentIds.isNotEmpty ? Colors.white : textCol.withValues(alpha: 0.4),
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
