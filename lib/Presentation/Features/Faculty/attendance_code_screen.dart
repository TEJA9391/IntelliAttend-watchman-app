import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/live_monitor/live_monitor_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/live_monitor/live_monitor_controller.dart';
import 'package:intelli_attend_faculty/Data/Repositories/attendance_repository.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Presentation/Widgets/rolling_digit.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_controller.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';
import 'package:intelli_attend_faculty/Services/websocket_service.dart';
import 'package:intelli_attend_faculty/Core/Models/websocket_event.dart';

class AttendanceCodeScreen extends StatefulWidget {
  final String courseName;
  final String room;
  final String? code; 
  final String? sessionId;
  final int? initialSeconds;
  final ScheduledClass? scheduledClass;

  const AttendanceCodeScreen({
    Key? key, 
    this.courseName = "Starting Session...", 
    this.room = "...", 
    this.code,
    this.sessionId,
    this.initialSeconds,
    this.scheduledClass,
  }) : super(key: key);

  @override
  State<AttendanceCodeScreen> createState() => _AttendanceCodeScreenState();
}

class _AttendanceCodeScreenState extends State<AttendanceCodeScreen>
    with TickerProviderStateMixin {
  late String _currentCode;
  late int _secondsLeft;
  bool _isRefreshing = false;
  bool _refreshFailed = false;
  int _refreshCount = 0;

  late AnimationController _progressController;
  late AnimationController _glowController;
  late AnimationController _otpChangeController;
  Timer? _countdownTimer;
  Timer? _rotateUnlockTimer;
  Timer? _activationPollTimer;
  StreamSubscription<WebSocketEvent>? _wsEventSub;
  StreamSubscription<WsConnectionState>? _wsConnSub;
  VoidCallback? _stateListener;
  DashboardController? _dashboardController;
  bool _isResponseProcessed = false;
  bool _rotateEnabled = false;

  // OTP context-awareness fields
  bool _otpVerified = false;
  int _otpAttemptCount = 0;
  bool _otpExhausted = false;
  bool _navigatingToLive = false;
  int _currentVersion = 0;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.code ?? "";
    _secondsLeft = 30;

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..addListener(() {
        setState(() {});
      });

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _otpChangeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _dashboardController = context.read<DashboardController>();
    _dashboardController!.addListener(_onSessionStateChanged);
    _stateListener = _onSessionStateChanged;

    if (_currentCode.isNotEmpty) {
      _rotateEnabled = true;
      _startTimer();
      _afterCodeReady();
    } else {
      _fetchOtpFromServer();
    }
  }

  bool _isFetchingOtp = false;

  Future<void> _fetchOtpFromServer() async {
    if (!mounted || _isFetchingOtp) return;
    _isFetchingOtp = true;

    try {
      final controller = context.read<DashboardController>();
      final scheduledClass = widget.scheduledClass;

      if (scheduledClass == null) {
        if (mounted) {
          setState(() {
            _currentCode = "!!!!";
            _rotateEnabled = true;
            _refreshFailed = true;
          });
          HapticService.heavy();
        }
        return;
      }

      final response = await controller.startSession(scheduledClass);

      if (!mounted) return;

      if (response != null && response.otp.isNotEmpty) {
        setState(() {
          _currentCode = response.otp;
          _secondsLeft = response.secondsRemaining;
          _rotateEnabled = true;
        });
        _otpChangeController.forward(from: 0.0);
        _startTimer();
        _fireOtpRevealHaptics();
        _afterCodeReady();
      } else {
        setState(() {
          _currentCode = "!!!!";
          _rotateEnabled = true;
          _refreshFailed = true;
        });
        HapticService.heavy();
      }
    } catch (e) {
      debugPrint("❌ OTP Screen: Failed to fetch OTP: $e");
      if (mounted) {
        setState(() {
          _currentCode = "!!!!";
          _rotateEnabled = true;
          _refreshFailed = true;
        });
        HapticService.heavy();
      }
    } finally {
      _isFetchingOtp = false;
    }
  }

  void _afterCodeReady() {
    final controller = context.read<DashboardController>();
    final sessionId = widget.sessionId ?? controller.activeSessionId;
    if (sessionId != null) {
      _setupWsListener(sessionId);
      _startPollingForActivation(sessionId, _currentVersion);
    }
  }

  void _onSessionStateChanged() {
    if (!mounted) return;
    final state = context.read<DashboardController>().sessionState;
    debugPrint("[OTP Screen] _onSessionStateChanged state=$state");
    switch (state) {
      case SessionState.active:
        if (_otpVerified) break;
        setState(() => _otpVerified = true);
        HapticService.light();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Flexible(child: Text("Session Activated Successfully!", maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        final sessionId = widget.sessionId ?? context.read<DashboardController>().activeSessionId;
        if (sessionId != null) {
          _activationPollTimer?.cancel();
          _navigateToLiveMonitor(sessionId);
        }

      case SessionState.closed:
        debugPrint("[OTP Screen] Session closed");

      case SessionState.igniting:
      case SessionState.preparing:
      case SessionState.idle:
        break;
    }
  }

  void _setupWsListener(String sessionId) {
    _wsEventSub?.cancel();
    _wsConnSub?.cancel();

    final wsService = WebSocketService();
    wsService.connectAndJoinRoom(sessionId: sessionId);

    _wsConnSub = wsService.connectionState.listen((state) {
      if (!mounted) return;
      if (state == WsConnectionState.disconnected) {
        debugPrint("[OTP Screen] WS disconnected");
      }
      if (state == WsConnectionState.connected) {
        debugPrint("[OTP Screen] WS reconnected — checking session state");
        _checkSessionState(sessionId);
      }
    });

    _wsEventSub = wsService.events.listen((event) {
      if (!mounted) return;

      if (event.type == WsEventType.otpFailed) {
        final attemptCount = event.get<int>('attempt_count') ?? 1;
        _otpAttemptCount = attemptCount;
        final remaining = 5 - attemptCount;
        if (remaining <= 0) {
          _otpExhausted = true;
          context.read<DashboardController>().clearActiveSession();
          return;
        }
      }

      if (event.type == WsEventType.otpVerified ||
          event.type == WsEventType.sessionActivated) {
        setState(() => _otpVerified = true);
        HapticService.light();
        _activationPollTimer?.cancel();
        _navigateToLiveMonitor(sessionId);
      }
    });
  }

  void _navigateToLiveMonitor(String sessionId) {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _countdownTimer?.cancel();
      _progressController.stop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) {
            final dbController = context.read<DashboardController>();
            final courseId = widget.scheduledClass?.id ?? dbController.activeSession?['course_id'];
            final sectionId = widget.scheduledClass?.sectionId ?? dbController.activeSession?['section_id'];
            return ChangeNotifierProvider(
              create: (context) => LiveMonitorController(
                context.read<AttendanceRepository>(),
                sessionId,
                courseId: courseId,
                sectionId: sectionId,
                onSessionEnded: () {
                  dbController.clearActiveSession();
                },
              ),
              child: LiveMonitorScreen(
                courseName: widget.courseName,
              ),
            );
          },
        ),
      );
    });
  }

  void _startPollingForActivation(String sessionId, int startVersion) {
    _currentVersion = startVersion;
    _activationPollTimer?.cancel();
    _activationPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _navigatingToLive) return;
      try {
        final data = await _dashboardController?.fetchCurrentState();
        if (data == null || !mounted) return;
        final state = data['state']?.toString() ?? '';
        final version = (data['version'] as int? ?? 0);
        if (state == 'ACTIVE' && version > _currentVersion) {
          _currentVersion = version;
          _activationPollTimer?.cancel();
          if (!mounted) return;
          _navigateToLiveMonitor(sessionId);
        }
      } catch (_) {
        // Poll errors are non-fatal; retry on next tick
      }
    });
  }

  Future<void> _checkSessionState(String sessionId) async {
    if (!mounted || _otpVerified) return;
    try {
      final data = await _dashboardController?.fetchCurrentState();
      if (data == null || !mounted) return;
      final state = data['state']?.toString() ?? '';
      if (state == 'ACTIVE') {
        _activationPollTimer?.cancel();
        _navigateToLiveMonitor(sessionId);
      }
    } catch (_) {
      debugPrint("[OTP Screen] State sync on reconnect failed");
    }
  }

  void _startTimer() {
    _progressController.duration = Duration(seconds: _secondsLeft);
    _progressController.forward(from: 0.0);

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else if (mounted) {
        timer.cancel();
        _handleOtpExpiration();
      }
    });
  }

  void _handleOtpExpiration() {
    if (!mounted) return;

    setState(() {
      _currentCode = "!!!!";
      _secondsLeft = 0;
      _rotateEnabled = true;
    });
    HapticService.heavy();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("OTP expired. Tap Rotate to get a new code."),
        backgroundColor: Colors.orangeAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleClose() {
    context.read<DashboardController>().clearActiveSession();
    WebSocketService().disconnect();
    Navigator.pop(context);
  }

  void _fireOtpRevealHaptics() {
    const delays = [0, 100, 200, 300];
    for (int i = 0; i < delays.length; i++) {
      final isLast = i == delays.length - 1;
      Future.delayed(Duration(milliseconds: delays[i]), () {
        if (mounted) {
          isLast
              ? HapticService.heavy()
              : HapticService.medium();
        }
      });
    }
  }

  Future<void> _handleRotatePressed() async {
    if (!mounted || _isRefreshing) return;
    final controller = context.read<DashboardController>();
    final sessionId = widget.sessionId ?? controller.activeSessionId;

    if (sessionId == null) {
      if (widget.scheduledClass == null) return;
      setState(() {
        _isRefreshing = true;
        _refreshFailed = false;
        _currentCode = "";
        _isResponseProcessed = false;
        _rotateEnabled = false;
      });
      _rotateUnlockTimer?.cancel();
      _rotateUnlockTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _currentCode.isEmpty) {
          setState(() {
            _currentCode = "!!!!";
            _rotateEnabled = true;
            _refreshFailed = true;
          });
          HapticService.heavy();
        }
      });
      try {
        await controller.startSession(widget.scheduledClass!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Retry failed: ${e.toString()}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isRefreshing = false);
      }
      return;
    }

    await _autoRefreshOtp(sessionId: sessionId);
  }

  Future<void> _autoRefreshOtp({String? sessionId}) async {
    if (!mounted || _isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _refreshFailed = false;
    });

    try {
      final id = sessionId ?? widget.sessionId;
      if (id == null) return;
      
      final repo = context.read<AttendanceRepository>();
      final response = await repo.refreshOtp(id);

      if (!mounted) return;

      if (response != null && response.otp.isNotEmpty) {
        setState(() {
          _currentCode = response.otp;
          _secondsLeft = response.secondsRemaining;
          _isRefreshing = false;
          _refreshFailed = false;
          _refreshCount++;
        });
        _otpChangeController.forward(from: 0.0);
        _startTimer();
        HapticService.light();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.autorenew_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Flexible(child: Text("Attendance code refreshed", maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            backgroundColor: AppTheme.primary(context),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _isRefreshing = false;
          _refreshFailed = true;
        });
      }
    } catch (e) {
      debugPrint("❌ OTP Auto-refresh error: $e");
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _refreshFailed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "Refresh failed: ${e.toString()}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _glowController.dispose();
    _otpChangeController.dispose();
    _countdownTimer?.cancel();
    _rotateUnlockTimer?.cancel();
    _activationPollTimer?.cancel();
    _wsEventSub?.cancel();
    _wsConnSub?.cancel();
    if (_stateListener != null && _dashboardController != null) {
      _dashboardController!.removeListener(_onSessionStateChanged);
    }
    WebSocketService().disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final tealColor = AppTheme.accentTeal;
    final limeColor = AppTheme.highlightLime;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tealColor.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: limeColor.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: AppTheme.text(context), size: 24),
                          onPressed: _handleClose,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Link to SmartBoard",
                                style: GoogleFonts.inter(
                                  color: AppTheme.text(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scrollable content
                  Expanded(
                    child: RefreshIndicator(
                      color: AppTheme.highlightLime,
                      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      strokeWidth: 3,
                      onRefresh: () async {
                        await _handleRotatePressed();
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                        children: [
                          const SizedBox(height: 32),
                          // OTP Card
                          _buildPremiumOtpCard(context, isDark, tealColor, limeColor),
                          const SizedBox(height: 24),
                          // Status banner
                          _buildStatusBanner(),
                          const SizedBox(height: 40),
                          // Countdown ring
                          _buildAnimatedCountdown(context, isDark, tealColor, limeColor),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  ),
                  // Bottom action
                  _buildBottomAction(context, isDark, tealColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color statusColor = _otpVerified
        ? const Color(0xFF16A34A)
        : _otpAttemptCount > 0
            ? Colors.orange
            : AppTheme.accentTeal;
    final String statusText = _otpVerified
        ? "Board Connected"
        : _otpAttemptCount > 0
            ? "Verifying..."
            : "Waiting for SmartBoard";

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            statusText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveViewChip(BuildContext context) {
    final sessionId = widget.sessionId ?? context.read<DashboardController>().activeSessionId;
    if (sessionId == null) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (context) => LiveMonitorController(
                context.read<AttendanceRepository>(),
                sessionId,
                courseId: widget.scheduledClass?.id,
                sectionId: widget.scheduledClass?.sectionId,
                onSessionEnded: () {
                  context.read<DashboardController>().clearActiveSession();
                },
              ),
              child: LiveMonitorScreen(courseName: widget.courseName),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.accentTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentTeal.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monitor_rounded, color: AppTheme.accentTeal, size: 16),
            const SizedBox(width: 4),
            Text(
              "Live",
              style: GoogleFonts.inter(
                color: AppTheme.accentTeal,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumOtpCard(BuildContext context, bool isDark, Color tealColor, Color limeColor) {
    final bool isExpired = _currentCode == "!!!!" || (_secondsLeft == 0 && _currentCode.isNotEmpty);
    final bool isFetching = _currentCode.isEmpty && _isFetchingOtp;
    
    return AnimatedBuilder(
      animation: _otpChangeController,
      builder: (context, child) {
        final scale = 1.0 + (_otpChangeController.value * 0.02);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E).withValues(alpha: 0.6)
                  : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: isDark
                  ? Border.all(
                      color: isExpired
                          ? Colors.white.withValues(alpha: 0.05)
                          : tealColor.withValues(alpha: 0.2),
                      width: 1.5,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isExpired
                      ? Colors.black.withValues(alpha: 0.05)
                      : tealColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              children: [
                // Label with icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: isExpired
                          ? AppTheme.textSecondary(context)
                          : tealColor,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "ONE-TIME PASSWORD",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: isExpired
                              ? AppTheme.textSecondary(context)
                              : tealColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // OTP Display
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RollingDigitGroup(
                    code: _currentCode.isEmpty ? null : (_currentCode.length >= 6 ? _currentCode.substring(1, 5) : _currentCode),
                    style: GoogleFonts.jetBrainsMono(
                      color: isExpired
                          ? AppTheme.textSecondary(context)
                          : AppTheme.text(context),
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Subtitle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.orange.withValues(alpha: 0.1)
                        : limeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isExpired ? Icons.warning_amber_rounded : isFetching ? Icons.hourglass_top_rounded : Icons.shield_rounded,
                        color: isExpired ? Colors.orange : isFetching ? tealColor : limeColor,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isExpired
                              ? "Code expired — tap refresh"
                              : isFetching
                                  ? "Fetching code from server..."
                                  : "IntelliAttend Smart Board",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: isExpired ? Colors.orange : limeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner() {
    if (_otpVerified) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "SmartBoard Connected Successfully",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: const Color(0xFF16A34A),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_otpAttemptCount > 0) {
      final remaining = 5 - _otpAttemptCount;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "Wrong OTP  ·  $remaining attempt${remaining == 1 ? '' : 's'} remaining",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildAnimatedCountdown(BuildContext context, bool isDark, Color tealColor, Color limeColor) {
    final bool isUrgent = _secondsLeft <= 10;
    final Color ringColor = isUrgent ? AppTheme.errorRed : limeColor;

    return AnimatedBuilder(
      animation: Listenable.merge([_progressController, _glowController]),
      builder: (context, _) {
        final progress = 1.0 - _progressController.value;
        final glowOpacity = 0.1 + (_glowController.value * 0.15);

        return Stack(
          alignment: Alignment.center,
          children: [
            // White circle fill
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            // Outer ring (background)
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFE2E8F0).withValues(alpha: 0.5),
              ),
            ),
            // Progress ring
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.transparent,
                color: ringColor,
              ),
            ),
            // Inner content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: GoogleFonts.jetBrainsMono(
                    color: ringColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                  child: Text("${_secondsLeft}s"),
                ),
                const SizedBox(height: 2),
                Text(
                  "REMAINING",
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomAction(BuildContext context, bool isDark, Color tealColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (!_rotateEnabled || _isRefreshing) ? null : _handleRotatePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2F3634) : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                disabledForegroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isRefreshing
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.white70 : Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sync_rounded, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _refreshCount > 0 ? "Refresh Code" : "Rotate Code",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
