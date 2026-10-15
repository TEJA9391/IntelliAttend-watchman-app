import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/mark_attendance_repository.dart';
import 'package:intelli_attend_faculty/Data/Repositories/course_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/draft_attendance_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/mark_attendance_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Utils/responsive.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

const Color _presentGreen = Color(0xFF22C55E);
const Color _absentRed = Color(0xFFEF4444);
const Color _lateAmber = Color(0xFFFBBF24);
const Color _leavePurple = Color(0xFF2DD4BF);

class MarkAttendanceScreen extends StatefulWidget {
  final String courseCode;
  final String courseName;
  final String? sectionId;
  final String sessionId;
  final String initialSection;
  final List<String> sections;
  final MarkAttendanceController? controller;

  const MarkAttendanceScreen({
    super.key,
    required this.courseCode,
    required this.courseName,
    this.sectionId,
    required this.sessionId,
    this.initialSection = 'A',
    this.sections = const ['A', 'B', 'C', 'D', 'E'],
    this.controller,
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final MarkAttendanceController _controller;
  late final TextEditingController _searchController;
  late final AnimationController _shimmerController;
  Timer? _debounceTimer;
  String _selectedSection = 'A';
  bool _hasSearchText = false;
  String? _activeQuickAction;
  bool _isClassOngoing = false;
  bool _isCheckingSchedule = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        MarkAttendanceController(
          MarkAttendanceRepository(),
          courseCode: widget.courseCode,
        );
    _searchController = TextEditingController();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _selectedSection = widget.initialSection;
    _checkClassOngoing();
  }

  Future<void> _checkClassOngoing() async {
    setState(() => _isCheckingSchedule = true);
    try {
      final email = FacultyService.canonicalId ?? '';
      if (email.isEmpty) {
        setState(() {
          _isClassOngoing = false;
          _isCheckingSchedule = false;
        });
        return;
      }

      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      final courseRepo = CourseRepository();
      final schedule = await courseRepo.watchTodaySchedule(email).first;

      ScheduledClass? ongoingClass;
      for (final sc in schedule) {
        final sm = sc.startMinutes ?? 0;
        final em = sc.endMinutes ?? 0;
        if (sc.sectionId == widget.sectionId &&
            currentMinutes >= sm &&
            currentMinutes <= em) {
          ongoingClass = sc;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _isClassOngoing = ongoingClass != null;
          _isCheckingSchedule = false;
        });

        if (_isClassOngoing) {
          _loadRoster();
        }
      }
    } catch (e) {
      debugPrint("MarkAttendance: Schedule check error: $e");
      if (mounted) {
        setState(() {
          _isClassOngoing = false;
          _isCheckingSchedule = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _shimmerController.dispose();
    if (widget.controller == null) {
      _controller.saveDraftNow();
      _controller.dispose();
    }
    super.dispose();
  }

  String _sectionId(String section) {
    if (widget.sectionId != null && widget.sectionId!.isNotEmpty) {
      return widget.sectionId!;
    }
    return 'SEC_${section}_${widget.courseCode}';
  }

  Future<void> _loadRoster() async {
    if (!_isClassOngoing) return;
    await _controller.loadRoster(
      widget.courseCode,
      section: _selectedSection,
      sectionId: _sectionId(_selectedSection),
    );
    if (!mounted) return;
    if (_controller.error == null && _controller.roster.isNotEmpty) {
      _maybeRestoreDraft();
    }
  }

  Future<void> _maybeRestoreDraft() async {
    final draft = await DraftAttendanceService.instance
        .loadDraft(_controller.draftKey);
    if (draft == null || draft.attendanceMap.isEmpty) return;
    if (!mounted) return;
    final restore = await _confirmRestoreDraft(draft);
    if (!mounted) return;
    if (restore) {
      await _controller.restoreDraft();
      if (!mounted) return;
      _showSnack(
        'Draft restored · ${draft.attendanceMap.length} students marked',
      );
    } else {
      await _controller.clearDraft();
    }
  }

  Future<bool> _confirmRestoreDraft(DraftAttendance draft) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.card(context),
        title: Text(
          'Restore draft?',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          'You have an unsaved draft with ${draft.attendanceMap.length} '
          'marked students saved at ${_formatDraftTime(draft.savedAt)}. '
          'Restore it?',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Discard',
              style: GoogleFonts.inter(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Restore',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _formatDraftTime(DateTime time) {
    final now = DateTime.now();
    if (now.difference(time).inMinutes < 1) return 'just now';
    if (now.difference(time).inMinutes < 60) {
      return '${now.difference(time).inMinutes} min ago';
    }
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return 'today at $h:$m';
  }

  void _showSnack(String message, {Color? background}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(),
        ),
        backgroundColor: background ?? AppTheme.accentTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _onSectionChanged(String section) async {
    if (section == _selectedSection) return;
    if (_controller.hasUnsavedChanges && _controller.roster.isNotEmpty) {
      final action = await _confirmDiscardOrSave();
      if (action == null || !mounted) return;
      if (action == 'save') {
        await _controller.saveDraftNow();
      } else if (action == 'discard') {
        await _controller.clearDraft();
      }
    }
    if (!mounted) return;
    HapticService.light();
    setState(() => _selectedSection = section);
    _searchController.clear();
    _hasSearchText = false;
    _controller.clearSearch();
    _loadRoster();
  }

  Future<String?> _confirmDiscardOrSave() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.card(context),
        title: Text(
          'Unsaved changes',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          'This section has marked students. Save a draft before switching, '
          'or discard your changes.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(
              'Discard',
              style: GoogleFonts.inter(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Save Draft',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.card(context),
        title: Text(
          'Leave session?',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Your progress is saved as a draft and can be restored when you '
          'open this section again.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Stay',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await _controller.saveDraftNow();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Leave',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  void _onSearchChanged(String query) {
    final hasText = query.isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() => _hasSearchText = hasText);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _controller.search(query);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _hasSearchText = false);
    _controller.clearSearch();
  }

  Future<void> _onSubmit() async {
    _showSubmittingOverlay();
    final success = await _controller.submitAttendance();
    if (!mounted) return;
    _hideOverlay();

    if (success) {
      _showSuccessScreen();
    } else {
      _showSubmitError();
    }
  }

  void _showSubmittingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.card(context),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  'Submitting attendance…',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hideOverlay() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _showSubmitError() {
    final message = _controller.error ?? 'Unable to submit attendance.';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.card(context),
        title: Text(
          'Submission failed',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onSubmit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubmitConfirmation() {
    final map = _controller.attendanceMap;
    final present =
        map.values.where((s) => s == AttendanceStatus.present).length;
    final absent =
        map.values.where((s) => s == AttendanceStatus.absent).length;
    final late = map.values.where((s) => s == AttendanceStatus.late).length;
    final leave = map.values.where((s) => s == AttendanceStatus.leave).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.card(context),
        title: Text(
          'Confirm Submission',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Review the attendance summary before submitting.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            _buildDialogSummaryRow('Present', present, _presentGreen),
            const SizedBox(height: 8),
            _buildDialogSummaryRow('Absent', absent, _absentRed),
            const SizedBox(height: 8),
            _buildDialogSummaryRow('Late', late, _lateAmber),
            const SizedBox(height: 8),
            _buildDialogSummaryRow('Leave', leave, _leavePurple),
            const SizedBox(height: 12),
            Divider(color: AppTheme.border(context), height: 1),
            const SizedBox(height: 12),
            _buildDialogSummaryRow('Total', map.length, AppTheme.accentTeal),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onSubmit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Submit',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessScreen() {
    if (!mounted) return;
    final refId = _controller.submitReferenceId ?? '—';
    final offline = _controller.wasSubmittedOffline;
    final counts = _controller.attendanceMap.length;
    final now = DateTime.now();
    final timestamp =
        '${now.day}/${now.month}/${now.year} · '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.card(context),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AnimatedSuccessCheck(),
            const SizedBox(height: 16),
            Text(
              offline ? 'Attendance Saved Offline' : 'Attendance Submitted!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$counts students recorded · $timestamp',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 12,
              ),
            ),
            if (offline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _lateAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _lateAmber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, color: _lateAmber, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Queued offline. Will sync when network returns.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: _lateAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: refId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reference ID copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.border(context).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.accentTeal.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tag_rounded,
                            color: AppTheme.textSecondary(context), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'Reference ID',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      refId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.accentTeal,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the reference ID to copy it.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context).withValues(alpha: 0.7),
                fontSize: 9,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogSummaryRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.text(context),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          '$count',
          maxLines: 1,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return PopScope(
      canPop: !_controller.hasUnsavedChanges || _controller.roster.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: _buildAppBar(responsive),
        body: _isCheckingSchedule
            ? _buildScheduleCheckingSkeleton(responsive)
            : _isClassOngoing
                ? ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      if (_controller.isLoading) {
                        return _buildShimmerSkeleton(responsive);
                      }
                      if (_controller.error != null && _controller.roster.isEmpty) {
                        return _buildErrorState();
                      }
                      return _buildContent(responsive);
                    },
                  )
                : _buildNoClassOngoingView(responsive),
        floatingActionButton: _isClassOngoing ? _buildSubmitFAB(responsive) : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Responsive responsive) {
    return AppBar(
      backgroundColor: AppTheme.bg(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text(context)),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mark Attendance',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.text(context),
              fontWeight: FontWeight.bold,
              fontSize: responsive.fontSizeM,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.courseCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.accentTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Responsive responsive) {
    final students = _controller.filteredRoster;
    final hasError = _controller.error != null;

    return Column(
      children: [
        if (hasError) _buildErrorBanner(),
        _buildSummaryBar(responsive),
        _buildSearchBar(responsive),
        _buildQuickActions(responsive),
        if (students.isEmpty)
          Expanded(child: _buildEmptyState())
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                responsive.paddingM,
                responsive.spacingS,
                responsive.paddingM,
                80,
              ),
              itemCount: students.length,
              itemBuilder: (context, index) =>
                  _buildStudentCard(students[index], responsive),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _controller.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _controller.clearError(),
            child: const Icon(Icons.close_rounded, color: AppTheme.errorRed, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(Responsive responsive) {
    final unmarked = _controller.unmarkedCount;
    return Container(
      margin: EdgeInsets.fromLTRB(
        responsive.paddingM,
        responsive.spacingS,
        responsive.paddingM,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildSummaryMetric('Total', _controller.totalCount, AppTheme.accentTeal, responsive),
              _buildDivider(),
              _buildSummaryMetric('Marked', _controller.markedCount, _presentGreen, responsive),
              _buildDivider(),
              _buildSummaryMetric('Unmarked', unmarked, _absentRed, responsive),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusMetric('Present', _controller.presentCount, _presentGreen, responsive),
              _buildStatusMetric('Absent', _controller.absentCount, _absentRed, responsive),
              _buildStatusMetric('Late', _controller.lateCount, _lateAmber, responsive),
              _buildStatusMetric('Leave', _controller.leaveCount, _leavePurple, responsive),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (_controller.presentCount > 0)
                    Expanded(
                      flex: _controller.presentCount,
                      child: Container(color: _presentGreen),
                    ),
                  if (_controller.absentCount > 0)
                    Expanded(
                      flex: _controller.absentCount,
                      child: Container(color: _absentRed),
                    ),
                  if (_controller.lateCount > 0)
                    Expanded(
                      flex: _controller.lateCount,
                      child: Container(color: _lateAmber),
                    ),
                  if (_controller.leaveCount > 0)
                    Expanded(
                      flex: _controller.leaveCount,
                      child: Container(color: _leavePurple),
                    ),
                  if (unmarked > 0)
                    Expanded(
                      flex: unmarked,
                      child: Container(color: AppTheme.border(context)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppTheme.border(context),
    );
  }

  Widget _buildSummaryMetric(
    String label,
    int count,
    Color color,
    Responsive responsive,
  ) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedCountText(
            count: count,
            style: GoogleFonts.inter(
              color: color,
              fontSize: responsive.fontSizeM,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMetric(
    String label,
    int count,
    Color color,
    Responsive responsive,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedCountText(
              count: count,
              style: GoogleFonts.inter(
                color: color,
                fontSize: responsive.fontSizeS,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
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

  Widget _buildSearchBar(Responsive responsive) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.paddingM,
        responsive.spacingS,
        responsive.paddingM,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AppTheme.textSecondary(context), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by name or roll number...',
                  hintStyle: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_hasSearchText)
              GestureDetector(
                onTap: _clearSearch,
                child: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context), size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(Responsive responsive) {
    final processing = _controller.isProcessingQuickAction;
    final canBulk = _controller.canPerformBulkActions && !processing;
    final permissionTooltip =
        canBulk ? null : 'You do not have permission to modify this class.';

    final allPresent = _QuickActionSpec(
      key: 'all_present',
      label: 'All Present',
      icon: Icons.check_circle_outline_rounded,
      color: _presentGreen,
      action: () => _controller.quickMarkAll(AttendanceStatus.present),
      skipMessage: 'All students are already marked Present.',
      successMessage: '${_controller.totalCount} students marked Present',
      confirmTitle: 'Mark all Present?',
      confirmMessage:
          'Mark all ${_controller.totalCount} students as Present?',
      confirmLabel: 'Mark All',
    );
    final allAbsent = _QuickActionSpec(
      key: 'all_absent',
      label: 'All Absent',
      icon: Icons.cancel_outlined,
      color: _absentRed,
      action: () => _controller.quickMarkAll(AttendanceStatus.absent),
      skipMessage: 'All students are already marked Absent.',
      successMessage: '${_controller.totalCount} students marked Absent',
      confirmTitle: 'Mark all Absent?',
      confirmMessage:
          'Mark all ${_controller.totalCount} students as Absent?',
      confirmLabel: 'Mark All',
    );
    final deselect = _QuickActionSpec(
      key: 'deselect',
      label: 'Deselect',
      icon: Icons.deselect_rounded,
      color: AppTheme.textSecondary(context),
      action: () => _controller.quickDeselectAll(),
      skipMessage: 'No students are currently marked.',
      successMessage: 'All ${_controller.totalCount} students unmarked',
      confirmTitle: 'Deselect all?',
      confirmMessage:
          'Remove attendance status for all ${_controller.markedCount} marked students?',
      confirmLabel: 'Deselect',
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        responsive.paddingM,
        responsive.spacingS,
        responsive.paddingM,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionChip(
              label: allPresent.label,
              icon: allPresent.icon,
              color: allPresent.color,
              onTap: () => _executeQuickAction(allPresent),
              responsive: responsive,
              enabled: canBulk,
              isProcessing: processing && _activeQuickAction == allPresent.key,
              tooltip: permissionTooltip,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionChip(
              label: allAbsent.label,
              icon: allAbsent.icon,
              color: allAbsent.color,
              onTap: () => _executeQuickAction(allAbsent),
              responsive: responsive,
              enabled: canBulk,
              isProcessing: processing && _activeQuickAction == allAbsent.key,
              tooltip: permissionTooltip,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionChip(
              label: deselect.label,
              icon: deselect.icon,
              color: deselect.color,
              onTap: () => _executeQuickAction(deselect),
              responsive: responsive,
              enabled: canBulk,
              isProcessing: processing && _activeQuickAction == deselect.key,
              tooltip: permissionTooltip,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeQuickAction(
    _QuickActionSpec spec, {
    bool confirm = true,
  }) async {
    if (_activeQuickAction != null || _controller.isProcessingQuickAction) {
      return;
    }

    if (confirm) {
      final ok = await _confirmBulkAction(
        title: spec.confirmTitle,
        message: spec.confirmMessage,
        confirmLabel: spec.confirmLabel,
        color: spec.color,
      );
      if (!ok || !mounted) return;
    }

    setState(() => _activeQuickAction = spec.key);
    try {
      final result = await spec.action();
      if (!mounted) return;
      switch (result) {
        case QuickActionResult.success:
          _showQuickActionSnackBar(spec.successMessage, undoable: true);
          break;
        case QuickActionResult.skipped:
          _showQuickActionSnackBar(spec.skipMessage, isWarning: true);
          break;
        case QuickActionResult.offline:
          _showQuickActionSnackBar(
            '${spec.successMessage} · Saved offline. Will sync when back online.',
            undoable: true,
          );
          break;
        case QuickActionResult.failed:
          _showQuickActionSnackBar(
            'Unable to update attendance.',
            retry: () => _executeQuickAction(spec, confirm: false),
          );
          break;
      }
    } finally {
      if (mounted) setState(() => _activeQuickAction = null);
    }
  }

  Future<bool> _confirmBulkAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Color color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.card(context),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              confirmLabel,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showQuickActionSnackBar(
    String message, {
    bool undoable = false,
    bool isWarning = false,
    VoidCallback? retry,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(),
        ),
        backgroundColor: isWarning ? AppTheme.errorRed : AppTheme.accentTeal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: (undoable || retry != null) ? 5 : 3),
        action: undoable
            ? SnackBarAction(
                label: 'UNDO',
                textColor: Colors.black,
                onPressed: () => _controller.quickUndo(),
              )
            : (retry != null
                ? SnackBarAction(
                    label: 'RETRY',
                    textColor: Colors.black,
                    onPressed: retry,
                  )
                : null),
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Responsive responsive,
    bool enabled = true,
    bool isProcessing = false,
    bool isSelected = false,
    String? tooltip,
  }) {
    final canTap = enabled && !isProcessing;
    final chipColor = enabled ? color : color.withValues(alpha: 0.4);

    Widget child = GestureDetector(
      onTap: canTap ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: isSelected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: chipColor.withValues(alpha: isSelected ? 0.6 : 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isProcessing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(chipColor),
                ),
              )
            else
              Icon(icon, color: chipColor, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: chipColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      child = Tooltip(message: tooltip, child: child);
    }

    return Semantics(
      button: true,
      enabled: canTap,
      label: label,
      child: child,
    );
  }

  Widget _buildStudentCard(ClassStudent student, Responsive responsive) {
    final status = _controller.attendanceMap[student.id];
    final pct = student.attendancePercentage;
    final pctColor = _eligibilityColor(pct);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(student.name, pctColor, responsive),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildHighlightedText(
                            student.name,
                            _controller.searchQuery,
                            GoogleFonts.inter(
                              color: AppTheme.text(context),
                              fontSize: responsive.fontSizeS,
                              fontWeight: FontWeight.w600,
                            ),
                            _presentGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildEligibilityBadge(student),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${student.rollNumber} \u00B7 ${student.attendedClasses}/${student.totalClasses} classes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          maxLines: 1,
                          style: GoogleFonts.inter(
                            color: pctColor,
                            fontSize: responsive.fontSizeS,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatusChip(
                  label: 'Present',
                  color: _presentGreen,
                  isSelected: status == AttendanceStatus.present,
                  onTap: () {
                    HapticService.light();
                    _controller.markStudent(student.id, AttendanceStatus.present);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildStatusChip(
                  label: 'Absent',
                  color: _absentRed,
                  isSelected: status == AttendanceStatus.absent,
                  onTap: () {
                    HapticService.light();
                    _controller.markStudent(student.id, AttendanceStatus.absent);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildStatusChip(
                  label: 'Late',
                  color: _lateAmber,
                  isSelected: status == AttendanceStatus.late,
                  onTap: () {
                    HapticService.light();
                    _controller.markStudent(student.id, AttendanceStatus.late);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildStatusChip(
                  label: 'Leave',
                  color: _leavePurple,
                  isSelected: status == AttendanceStatus.leave,
                  onTap: () {
                    HapticService.light();
                    _controller.markStudent(student.id, AttendanceStatus.leave);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, Color color, Responsive responsive) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Container(
      width: responsive.iconM,
      height: responsive.iconM,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: color,
            fontSize: responsive.fontSizeS,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _eligibilityColor(double pct) {
    if (pct >= 75) return _presentGreen;
    if (pct >= 65) return _lateAmber;
    return _absentRed;
  }

  Widget _buildEligibilityBadge(ClassStudent student) {
    final pct = student.attendancePercentage;
    final isEligible = pct >= 75;
    final isWarning = pct >= 65 && pct < 75;
    final color = isEligible
        ? _presentGreen
        : isWarning
            ? _lateAmber
            : _absentRed;
    final label = isEligible
        ? 'Eligible'
        : isWarning
            ? 'Warning'
            : 'Defaulter';
    final icon = isEligible
        ? Icons.check_circle_rounded
        : isWarning
            ? Icons.warning_amber_rounded
            : Icons.warning_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: isSelected ? color : color.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    TextStyle style,
    Color highlightColor,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = trimmed.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      final end = idx + lowerQuery.length;
      spans.add(
        TextSpan(
          text: text.substring(idx, end),
          style: style.copyWith(
            color: highlightColor,
            fontWeight: FontWeight.bold,
            backgroundColor: highlightColor.withValues(alpha: 0.16),
          ),
        ),
      );
      start = end;
    }

    if (spans.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubmitFAB(Responsive responsive) {
    final canSubmit = _controller.allMarked && !_controller.isSubmitting;
    final fabColor = canSubmit
        ? AppTheme.accentTeal
        : AppTheme.textSecondary(context).withValues(alpha: 0.2);
    final textColor = canSubmit
        ? Colors.black
        : AppTheme.textSecondary(context).withValues(alpha: 0.5);

    return FloatingActionButton.extended(
      onPressed: canSubmit ? _showSubmitConfirmation : null,
      backgroundColor: fabColor,
      foregroundColor: textColor,
      elevation: canSubmit ? 4 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controller.isSubmitting)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            )
          else
            Icon(Icons.send_rounded, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(
            'Submit Attendance',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: responsive.fontSizeXS,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSkeleton(Responsive responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final highlightColor =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            responsive.paddingM,
            responsive.spacingS,
            responsive.paddingM,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _shimmerBlock(baseColor, highlightColor, height: 48, radius: 12),
              SizedBox(height: responsive.spacingS),
              _shimmerBlock(baseColor, highlightColor, height: 40, radius: 12),
              SizedBox(height: responsive.spacingS),
              _shimmerBlock(baseColor, highlightColor, height: 40, radius: 12),
              SizedBox(height: responsive.spacingS),
              ...List.generate(
                5,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _shimmerBlock(
                    baseColor,
                    highlightColor,
                    height: 110,
                    radius: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBlock(
    Color base,
    Color highlight, {
    double height = 80,
    double radius = 14,
  }) {
    final start = (_shimmerController.value - 0.3).clamp(0.0, 1.0);
    final center = _shimmerController.value.clamp(0.0, 1.0);
    final end = (_shimmerController.value + 0.3).clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [start, center, end],
          colors: [base, highlight, base],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.accentTeal.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_outline_rounded,
                        size: 56,
                        color: AppTheme.accentTeal.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _hasSearchText ? 'No Student Found' : 'No students found',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasSearchText
                          ? 'No students match your search query'
                          : 'No roster available for this section.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _loadRoster,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Retry',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentTeal,
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: AppTheme.errorRed.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load roster',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.error ?? 'An unexpected error occurred.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                _controller.clearError();
                _loadRoster();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCheckingSkeleton(Responsive responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final highlightColor =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            responsive.paddingM,
            responsive.spacingS,
            responsive.paddingM,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _shimmerBlock(baseColor, highlightColor, height: 80, radius: 16),
              SizedBox(height: responsive.spacingS),
              _shimmerBlock(baseColor, highlightColor, height: 40, radius: 12),
              SizedBox(height: responsive.spacingS),
              _shimmerBlock(baseColor, highlightColor, height: 40, radius: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoClassOngoingView(Responsive responsive) {
    final now = DateTime.now();
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final displayH = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final timeStr = '$displayH:$m $ampm';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule_rounded,
                size: 56,
                color: AppTheme.accentTeal.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Class Ongoing',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current time: $timeStr',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.accentTeal,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Students will be available for marking only during scheduled class hours.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _checkClassOngoing,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Refresh',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionSpec {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Future<QuickActionResult> Function() action;
  final String skipMessage;
  final String successMessage;
  final String confirmTitle;
  final String confirmMessage;
  final String confirmLabel;

  const _QuickActionSpec({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.action,
    required this.skipMessage,
    required this.successMessage,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.confirmLabel,
  });
}

class _AnimatedCountText extends StatelessWidget {
  final int count;
  final TextStyle style;

  const _AnimatedCountText({required this.count, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: count),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Text(
        '$value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _AnimatedSuccessCheck extends StatelessWidget {
  const _AnimatedSuccessCheck();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _presentGreen.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_rounded,
          color: _presentGreen,
          size: 48,
        ),
      ),
    );
  }
}
