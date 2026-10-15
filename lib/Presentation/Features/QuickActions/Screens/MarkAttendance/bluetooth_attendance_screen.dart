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

class _DetectedDevice {
  final String studentId;
  final String studentName;
  final double signalStrength;
  final DateTime detectedAt;
  _DetectedDevice({
    required this.studentId,
    required this.studentName,
    required this.signalStrength,
    required this.detectedAt,
  });
}

class BluetoothAttendanceScreen extends StatefulWidget {
  final String courseCode;
  final String courseName;
  const BluetoothAttendanceScreen({Key? key, required this.courseCode, required this.courseName}) : super(key: key);
  @override
  State<BluetoothAttendanceScreen> createState() => _BluetoothAttendanceScreenState();
}

class _BluetoothAttendanceScreenState extends State<BluetoothAttendanceScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  Timer? _scanTimer;
  final List<_DetectedDevice> _detectedDevices = [];
  int _scanTick = 0;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _waveController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _startScanning() {
    HapticService.medium();
    final controller = context.read<MarkAttendanceController>();
    controller.startBluetoothScan();
    setState(() {
      _isScanning = true;
      _detectedDevices.clear();
      _scanTick = 0;
    });

    _scanTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!mounted || controller.roster.isEmpty) { timer.cancel(); return; }

      final random = Random();
      final unDetected = controller.roster.where((s) => !controller.bluetoothDetectedIds.contains(s.id)).toList();
      if (unDetected.isEmpty) { _stopScanning(); return; }

      final student = unDetected[random.nextInt(unDetected.length)];
      final signal = -30.0 - random.nextDouble() * 60.0;
      controller.simulateBluetoothDetection(student.id);

      _detectedDevices.insert(0, _DetectedDevice(
        studentId: student.id,
        studentName: student.name,
        signalStrength: signal,
        detectedAt: DateTime.now(),
      ));

      setState(() { _scanTick++; });
      HapticService.light();
    });
  }

  void _stopScanning() {
    HapticService.heavy();
    final controller = context.read<MarkAttendanceController>();
    controller.stopBluetoothScan();
    _scanTimer?.cancel();
    setState(() { _isScanning = false; });
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

  Color _signalColor(double dbm) {
    if (dbm >= -50) return const Color(0xFF22C55E);
    if (dbm >= -70) return const Color(0xFFFBBF24);
    return AppTheme.errorRed;
  }

  String _signalLabel(double dbm) {
    if (dbm >= -50) return "Strong";
    if (dbm >= -70) return "Medium";
    return "Weak";
  }

  int _signalBars(double dbm) {
    if (dbm >= -50) return 3;
    if (dbm >= -70) return 2;
    return 1;
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
                      Text("Bluetooth Attendance", style: GoogleFonts.inter(color: textCol, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
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
            _buildBluetoothCard(context, controller, textCol, textSec, isDark),
            const SizedBox(height: 16),
            _buildStatsRow(context, controller, textCol, isDark),
            const SizedBox(height: 16),
            _buildDeviceList(context, controller, textCol, textSec, isDark),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context, controller, textCol, isDark),
    );
  }

  Widget _buildBluetoothCard(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isScanning ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : AppTheme.border(context),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Bluetooth Scanner", style: GoogleFonts.inter(color: textCol, fontSize: 15, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isScanning ? const Color(0xFF22C55E).withValues(alpha: 0.12) : AppTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isScanning ? "Scanning" : "Inactive",
                  style: GoogleFonts.inter(
                    color: _isScanning ? const Color(0xFF22C55E) : AppTheme.errorRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildRadioWaveAnimation(textCol, textSec, isDark),
          const SizedBox(height: 20),
          Text(
            _isScanning ? "Detecting nearby devices..." : "Tap 'Start Scan' to begin",
            style: GoogleFonts.inter(
              color: _isScanning ? const Color(0xFF3B82F6) : textSec,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_isScanning) ...[
            const SizedBox(height: 8),
            Text(
              "${controller.bluetoothDetectedIds.length} devices found",
              style: GoogleFonts.jetBrainsMono(color: textSec, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadioWaveAnimation(Color textCol, Color textSec, bool isDark) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isScanning) ...[
            AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (i) {
                    final delay = i * 0.33;
                    final progress = (_waveAnimation.value + delay) % 1.0;
                    final size = 40.0 + progress * 50.0;
                    final opacity = (1.0 - progress) * 0.4;
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: opacity),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isScanning ? const Color(0xFF3B82F6).withValues(alpha: 0.15) : AppTheme.surface(context),
              border: Border.all(
                color: _isScanning ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : AppTheme.border(context),
              ),
            ),
            child: Icon(
              Icons.bluetooth_rounded,
              size: 28,
              color: _isScanning ? const Color(0xFF3B82F6) : textSec.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, MarkAttendanceController controller, Color textCol, bool isDark) {
    final detectedCount = controller.bluetoothDetectedIds.length;
    final totalCount = controller.totalCount;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: "Detected",
            value: "$detectedCount",
            color: const Color(0xFF3B82F6),
            context: context,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            label: "Remaining",
            value: "${totalCount - detectedCount}",
            color: const Color(0xFFFBBF24),
            context: context,
            isDark: isDark,
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
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({required String label, required String value, required Color color, required BuildContext context, required bool isDark}) {
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

  Widget _buildDeviceList(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    if (_detectedDevices.isEmpty) {
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
              Icon(Icons.bluetooth_disabled_rounded, size: 36, color: textSec.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Text("No devices detected yet", style: GoogleFonts.inter(color: textSec, fontSize: 13)),
              const SizedBox(height: 4),
              Text("Students will appear when nearby", style: GoogleFonts.inter(color: textSec.withValues(alpha: 0.6), fontSize: 11)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Detected Devices (${_detectedDevices.length})", style: GoogleFonts.inter(color: textCol, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ..._detectedDevices.map((device) {
          final color = _signalColor(device.signalStrength);
          final bars = _signalBars(device.signalStrength);
          final label = _signalLabel(device.signalStrength);
          final timeStr = "${device.detectedAt.hour.toString().padLeft(2, '0')}:${device.detectedAt.minute.toString().padLeft(2, '0')}:${device.detectedAt.second.toString().padLeft(2, '0')}";

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
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bluetooth_rounded, size: 18, color: const Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.studentName, style: GoogleFonts.inter(color: textCol, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(timeStr, style: GoogleFonts.jetBrainsMono(color: textSec, fontSize: 10)),
                          Text("  \u2022  ", style: GoogleFonts.inter(color: textSec, fontSize: 10)),
                          Text("${device.signalStrength.toStringAsFixed(1)} dBm", style: GoogleFonts.jetBrainsMono(color: color, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildSignalBars(bars, color),
                    const SizedBox(height: 2),
                    Text(label, style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSignalBars(int activeBars, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final isActive = i < activeBars;
        final heights = [8.0, 12.0, 16.0];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 3,
          height: heights[i],
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
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
                onTap: controller.bluetoothDetectedIds.isNotEmpty ? _navigateToReview : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: controller.bluetoothDetectedIds.isNotEmpty ? AppTheme.accentTeal : textCol.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "Review & Submit",
                      style: GoogleFonts.inter(
                        color: controller.bluetoothDetectedIds.isNotEmpty ? Colors.white : textCol.withValues(alpha: 0.4),
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
