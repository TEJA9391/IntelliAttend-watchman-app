import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/live_monitor/live_monitor_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/live_monitor/live_monitor_controller.dart';
import 'package:intelli_attend_faculty/Data/Repositories/attendance_repository.dart';
import 'smart_board_controller.dart';

class SmartBoardScreen extends StatelessWidget {
  final String courseName;
  final String room;
  final String sessionId;
  final String initialOtp;
  final int initialSeconds;

  const SmartBoardScreen({
    Key? key,
    required this.courseName,
    required this.room,
    required this.sessionId,
    required this.initialOtp,
    required this.initialSeconds,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => SmartBoardController(
        sessionId: sessionId,
        initialOtp: initialOtp,
        initialSeconds: initialSeconds,
        repository: context.read<AttendanceRepository>(),
      ),
      child: Consumer<SmartBoardController>(
        builder: (context, controller, child) {
          final isAboutToExpire = controller.secondsLeft <= 10;

          return Scaffold(
            backgroundColor: const Color(0xFF0D1117),
            body: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildHeader(),
                          const SizedBox(height: 40),
                          _buildOtpCard(context, controller, isAboutToExpire),
                          const SizedBox(height: 48),
                          _buildCountdown(context, controller, isAboutToExpire),
                          const SizedBox(height: 36),
                          _buildInstructions(),
                          const SizedBox(height: 48),
                          _buildRotateButton(controller),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text("SmartBoard Link", 
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(courseName, 
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
          child: Text("Room: $room", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildOtpCard(BuildContext context, SmartBoardController controller, bool warning) {
    final bool isExpired = controller.secondsLeft == 0;
    final String otp = controller.otp;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired 
              ? [Colors.grey.shade800, Colors.grey.shade900]
              : warning 
                  ? [Colors.redAccent.shade700, const Color(0xFF1A2A7B)] 
                  : [Color(0xFF1A2A7B), AppTheme.primary(context)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isExpired ? Colors.black : warning ? Colors.redAccent : AppTheme.primary(context)).withValues(alpha: 0.3), 
            blurRadius: 32
          )
        ],
      ),
      child: Column(
        children: [
          Text(isExpired ? "CODE EXPIRED" : "ONE-TIME PASSWORD", 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isExpired ? Colors.white38 : Colors.white60, 
              fontSize: 12, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 2
            )
          ),
          const SizedBox(height: 20),
          Text(isExpired ? "EXPIRED" : (otp.length >= 6 ? otp.substring(1, 5) : otp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isExpired ? Colors.white24 : Colors.white, 
              fontSize: isExpired ? 44 : 52, 
              fontWeight: FontWeight.w900, 
              letterSpacing: isExpired ? 0 : 4
            )
          ),
          const SizedBox(height: 16),
          Text(isExpired ? "Please refresh to continue" : "Secure Connection Active", 
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isExpired ? Colors.white30 : Colors.white54, fontSize: 13)
          ),
        ],
      ),
    );
  }

  Widget _buildCountdown(BuildContext context, SmartBoardController controller, bool warning) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120, height: 120,
          child: CircularProgressIndicator(
            value: controller.secondsLeft / controller.initialDuration,
            strokeWidth: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            color: warning ? Colors.redAccent : AppTheme.primary(context),
          ),
        ),
        Text("${controller.secondsLeft}s", 
          style: TextStyle(color: warning ? Colors.redAccent : Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildInstructions() {
    return const Text("Display this code to connect with the room's SmartBoard system.",
      textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6));
  }

  Widget _buildRotateButton(SmartBoardController controller) {
    final bool isExpired = controller.secondsLeft == 0;
    return ElevatedButton.icon(
      onPressed: isExpired ? () => controller.rotateCodeManually() : null,
      icon: const Icon(Icons.sync),
      label: Text(isExpired ? "Refresh Code" : "Wait for Expiry"),
      style: ElevatedButton.styleFrom(
        backgroundColor: isExpired ? Colors.white10 : Colors.transparent,
        foregroundColor: isExpired ? Colors.white : Colors.white24,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isExpired ? Colors.transparent : Colors.white10),
        ),
      ),
    );
  }
}
