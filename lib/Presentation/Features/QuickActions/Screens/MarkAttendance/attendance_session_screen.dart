import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/mark_attendance_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Widgets/student_attendance_card.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Widgets/attendance_summary_panel.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Widgets/search_filter_bar.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Widgets/bulk_actions_bar.dart';
import 'review_screen.dart';

class AttendanceSessionScreen extends StatefulWidget {
  final String courseCode;
  final String courseName;

  const AttendanceSessionScreen({
    Key? key,
    required this.courseCode,
    required this.courseName,
  }) : super(key: key);

  @override
  State<AttendanceSessionScreen> createState() => _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> with TickerProviderStateMixin {
  Timer? _sessionTimer;
  Timer? _shimmerTimer;
  Duration _elapsed = Duration.zero;
  AnimationController? _successAnimController;
  Animation<double>? _successScaleAnim;
  Animation<double>? _successFadeAnim;
  bool _showSuccessAnim = false;

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScaleAnim = CurvedAnimation(parent: _successAnimController!, curve: Curves.elasticOut);
    _successFadeAnim = CurvedAnimation(parent: _successAnimController!, curve: Curves.easeIn);
    _startSessionTimer();
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        final controller = context.read<MarkAttendanceController>();
        if (controller.sessionStartTime != null) {
          setState(() {
            _elapsed = DateTime.now().difference(controller.sessionStartTime!);
          });
        }
      }
    });
  }

  void _playSuccessAnimation() {
    setState(() => _showSuccessAnim = true);
    _successAnimController?.forward(from: 0);
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _shimmerTimer?.cancel();
    _successAnimController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = context.watch<MarkAttendanceController>();

    final isSubmitted = controller.sessionStatus == 'submitted' || controller.sessionStatus == 'submitted_offline';

    return PopScope(
      canPop: !controller.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && controller.hasUnsavedChanges) {
          _showCancelDialog(context, controller);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        resizeToAvoidBottomInset: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 20),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _handleBackPress(context, controller),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: textCol),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Attendance Session",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: textCol, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        ),
                        Text(
                          "${widget.courseCode} · ${controller.markedCount}/${controller.totalCount} marked${isSubmitted ? ' · Saved' : ' · Live'}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: isSubmitted ? const Color(0xFF22C55E) : textSec,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.canUndo)
                    GestureDetector(
                      onTap: () {
                        HapticService.light();
                        controller.undoLast();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.undo_rounded, color: AppTheme.accentPurple, size: 18),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      controller.toggleSelectionMode();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: controller.isSelectionMode
                            ? AppTheme.accentTeal.withValues(alpha: 0.15)
                            : AppTheme.surface(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        controller.isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                        color: controller.isSelectionMode ? AppTheme.accentTeal : textCol,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildSessionInfoHeader(context, controller, textCol, textSec, isDark),
                    if (controller.error != null)
                      _buildErrorBanner(context, controller),
                    if (controller.isLoading)
                      _buildShimmerLoading(context, isDark)
                    else ...[
                      const SizedBox(height: 8),
                      AttendanceSummaryPanel(
                        totalCount: controller.totalCount,
                        presentCount: controller.presentCount,
                        absentCount: controller.absentCount,
                        lateCount: controller.lateCount,
                        leaveCount: controller.leaveCount,
                        attendancePercent: controller.attendancePercent,
                      ),
                      const SizedBox(height: 12),
                      SearchFilterBar(
                        searchQuery: controller.searchQuery,
                        onSearchChanged: (q) => controller.search(q),
                        onClear: () => controller.clearSearch(),
                        activeFilterLabel: _filterLabel(controller.filterMode),
                        onFilterTap: () => _showFilterDialog(context, controller),
                        activeSortLabel: _sortLabel(controller.sortMode),
                        onSortTap: () => _showSortDialog(context, controller),
                        activeGenderLabel: _genderLabel(controller.genderFilter),
                        onGenderTap: () => _showGenderDialog(context, controller),
                        activeSectionLabel: _sectionLabel(controller.sectionFilter),
                        onSectionTap: () => _showSectionDialog(context, controller),
                        hasActiveFilters: controller.hasActiveFilters,
                        onClearAllFilters: () => controller.clearAllFilters(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            if (!controller.isLoading) ...[
              if (controller.filteredRoster.isEmpty)
                Expanded(
                  child: _buildEmptyState(context, textCol, textSec, controller),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: controller.filteredRoster.length,
                    itemBuilder: (context, index) {
                      final student = controller.filteredRoster[index];
                      final note = controller.studentNotes[student.id];
                      return StudentAttendanceCard(
                        student: student,
                        status: controller.attendanceMap[student.id],
                        isSelected: controller.selectedStudentIds.contains(student.id),
                        isSelectionMode: controller.isSelectionMode,
                        onStatusChanged: (status) => controller.markStudent(student.id, status),
                        onTap: () => _showStudentDetails(context, controller, student),
                        onLongPress: () {
                          if (!controller.isSelectionMode) controller.toggleSelectionMode();
                          controller.toggleStudentSelection(student.id);
                        },
                        onHistoryTap: () => _showAttendanceHistory(context, controller, student),
                        onUndoTap: () => controller.undoLast(),
                        canUndo: controller.canUndo,
                        note: note?.remark,
                        showLastAttendance: true,
                        lastAttendanceDate: student.lastSeen,
                      );
                    },
                  ),
                ),
              if (controller.isSelectionMode)
                BulkActionsBar(
                  selectedCount: controller.selectedStudentIds.length,
                  onSelectAll: () => controller.selectAllStudents(),
                  onSelectRemaining: () => controller.selectRemaining(),
                  onSelectPresent: () => controller.selectPresent(),
                  onSelectAbsent: () => controller.selectAbsent(),
                  onSelectLate: () => controller.selectLate(),
                  onSelectLeave: () => controller.selectLeave(),
                  onInvertSelection: () => controller.invertSelection(),
                  onClearSelection: () => controller.clearSelection(),
                  onMarkPresent: () => controller.markSelectedPresent(),
                  onMarkAbsent: () => controller.markSelectedAbsent(),
                  onMarkLate: () => controller.markSelectedLate(),
                  onMarkLeave: () => controller.markSelectedLeave(),
                  canUndo: controller.canUndo,
                  onUndo: controller.canUndo ? () => controller.undoLast() : null,
                  onExport: () {},
                  onSendParents: () {},
                ),
            ],
          ],
        ),
        bottomNavigationBar: isSubmitted
            ? _buildSubmittedBar(context, controller)
            : _buildBottomBar(context, controller, textCol, textSec, isDark),
      ),
    );
  }

  Widget _buildSessionInfoHeader(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
    final elapsedMin = _elapsed.inMinutes;
    final elapsedStr = '${elapsedMin.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final modeIcon = {
      AttendanceMode.manual: Icons.edit_rounded,
      AttendanceMode.qr: Icons.qr_code_2_rounded,
      AttendanceMode.face: Icons.face_rounded,
      AttendanceMode.nfc: Icons.nfc_rounded,
      AttendanceMode.bluetooth: Icons.bluetooth_rounded,
      AttendanceMode.hybrid: Icons.device_hub_rounded,
    }[controller.sessionMode] ?? Icons.edit_rounded;
    final modeLabel = {
      AttendanceMode.manual: 'Manual',
      AttendanceMode.qr: 'QR Code',
      AttendanceMode.face: 'Face Rec.',
      AttendanceMode.nfc: 'NFC Tap',
      AttendanceMode.bluetooth: 'Bluetooth',
      AttendanceMode.hybrid: 'Hybrid',
    }[controller.sessionMode] ?? 'Manual';
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final startTime = controller.sessionStartTime;
    final timeStr = startTime != null ? '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}' : '--:--';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(modeIcon, color: AppTheme.accentTeal, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${widget.courseCode} · $modeLabel",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: textCol, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  "$dateStr · Started $timeStr · Elapsed $elapsedStr",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: textSec, fontSize: 10),
                ),
              ],
            ),
          ),
          if (controller.isEditMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "EDITED",
                style: GoogleFonts.inter(color: AppTheme.accentPurple, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: controller.hasUnsavedChanges
                  ? const Color(0xFFFBBF24).withValues(alpha: 0.12)
                  : const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              controller.hasUnsavedChanges ? 'UNSAVED' : 'SYNCED',
              style: GoogleFonts.inter(
                color: controller.hasUnsavedChanges ? const Color(0xFFFBBF24) : const Color(0xFF22C55E),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, MarkAttendanceController controller) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.error!,
              style: GoogleFonts.inter(color: AppTheme.errorRed, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () => controller.clearError(),
            child: Icon(Icons.close_rounded, color: AppTheme.errorRed, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: List.generate(6, (index) => _ShimmerCard(isDark: isDark)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textCol, Color textSec, MarkAttendanceController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    controller.hasActiveFilters ? Icons.search_off_rounded : Icons.people_outline_rounded,
                    size: 56,
                    color: textSec.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    controller.hasActiveFilters ? "No students match your filters" : "No students found",
                    style: GoogleFonts.inter(color: textSec, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    controller.hasActiveFilters ? "Try adjusting your search or filter criteria" : "Roster is empty",
                    style: GoogleFonts.inter(color: textSec.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  if (controller.hasActiveFilters) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => controller.clearAllFilters(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          "Clear All Filters",
                          style: GoogleFonts.inter(color: AppTheme.accentTeal, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, MarkAttendanceController controller, Color textCol, Color textSec, bool isDark) {
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "${controller.markedCount}/${controller.totalCount}",
                        style: GoogleFonts.inter(color: textCol, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            height: 5,
                            child: LinearProgressIndicator(
                              value: controller.totalCount > 0 ? controller.markedCount / controller.totalCount : 0,
                              backgroundColor: textSec.withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                controller.allMarked ? const Color(0xFF22C55E) : AppTheme.accentTeal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (controller.hasUnsavedChanges && controller.undoStack.isNotEmpty)
                    Text(
                      "${controller.undoStack.length} unsaved change${controller.undoStack.length > 1 ? 's' : ''}",
                      style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w500),
                    )
                  else
                    Text(
                      controller.allMarked ? "All students marked" : "${controller.unmarkedCount} remaining",
                      style: GoogleFonts.inter(
                        color: controller.allMarked ? const Color(0xFF22C55E) : textSec,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: controller.allMarked
                  ? () {
                      HapticService.medium();
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: controller,
                          child: ReviewScreen(
                            courseCode: widget.courseCode,
                            courseName: widget.courseName,
                          ),
                        ),
                      ));
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: controller.allMarked ? AppTheme.accentTeal : textSec.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Review & Submit",
                      style: GoogleFonts.inter(
                        color: controller.allMarked ? Colors.white : textSec,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (controller.allMarked) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittedBar(BuildContext context, MarkAttendanceController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: const Color(0xFF22C55E).withValues(alpha: 0.2), width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_showSuccessAnim && _successScaleAnim != null)
              ScaleTransition(
                scale: _successScaleAnim!,
                child: FadeTransition(
                  opacity: _successFadeAnim!,
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 24),
                ),
              )
            else
              const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.sessionStatus == 'submitted_offline'
                        ? "Saved offline"
                        : "Attendance submitted",
                    style: GoogleFonts.inter(color: const Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (controller.lastSubmitTime != null)
                    Text(
                      "at ${controller.lastSubmitTime!.hour.toString().padLeft(2, '0')}:${controller.lastSubmitTime!.minute.toString().padLeft(2, '0')}:${controller.lastSubmitTime!.second.toString().padLeft(2, '0')}",
                      style: GoogleFonts.inter(color: const Color(0xFF22C55E).withValues(alpha: 0.7), fontSize: 10),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text("Done", style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBackPress(BuildContext context, MarkAttendanceController controller) {
    if (controller.hasUnsavedChanges) {
      _showCancelDialog(context, controller);
    } else {
      Navigator.maybePop(context);
    }
  }

  void _showFilterDialog(BuildContext context, MarkAttendanceController controller) {
    final filters = [
      FilterMode.all, FilterMode.present, FilterMode.absent, FilterMode.late,
      FilterMode.leave, FilterMode.notMarked, FilterMode.below75, FilterMode.above90,
    ];
    final labels = ['All', 'Present', 'Absent', 'Late', 'Leave', 'Not Marked', 'Below 75%', 'Above 90%'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text("Filter by Status", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(filters.length, (i) {
                final isActive = controller.filterMode == filters[i];
                return GestureDetector(
                  onTap: () {
                    HapticService.selection();
                    controller.setFilter(filters[i]);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.accentTeal.withValues(alpha: 0.15) : AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? AppTheme.accentTeal.withValues(alpha: 0.3) : AppTheme.border(context)),
                    ),
                    child: Text(labels[i], style: GoogleFonts.inter(color: isActive ? AppTheme.accentTeal : AppTheme.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSortDialog(BuildContext context, MarkAttendanceController controller) {
    final modes = [SortMode.alphabetical, SortMode.nameDesc, SortMode.rollNumber, SortMode.attendancePercent, SortMode.recentlyUpdated, SortMode.newest, SortMode.oldest];
    final labels = ['A → Z', 'Z → A', 'Roll Number', 'Attendance %', 'Recently Updated', 'Newest First', 'Oldest First'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text("Sort By", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ...List.generate(modes.length, (i) {
              final isActive = controller.sortMode == modes[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: isActive ? AppTheme.accentTeal : AppTheme.textSecondary(context), size: 20),
                title: Text(labels[i], style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14)),
                onTap: () {
                  HapticService.selection();
                  controller.setSortMode(modes[i]);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showGenderDialog(BuildContext context, MarkAttendanceController controller) {
    final options = [
      {'label': 'All Genders', 'value': null},
      {'label': 'Boys', 'value': 'Male'},
      {'label': 'Girls', 'value': 'Female'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text("Filter by Gender", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ...options.map((opt) {
              final isActive = controller.genderFilter == opt['value'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isActive ? AppTheme.accentPurple : AppTheme.textSecondary(context),
                  size: 20,
                ),
                title: Text(opt['label'] as String, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14)),
                onTap: () {
                  HapticService.selection();
                  controller.setGenderFilter(opt['value'] as String?);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showSectionDialog(BuildContext context, MarkAttendanceController controller) {
    final sections = controller.availableSections;
    final options = <Map<String, dynamic>>[
      {'label': 'All Sections', 'value': null},
      ...sections.map((s) => {'label': 'Section $s', 'value': s}),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text("Filter by Section", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ...options.map((opt) {
              final isActive = controller.sectionFilter == opt['value'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: isActive ? const Color(0xFF60A5FA) : AppTheme.textSecondary(context),
                  size: 20,
                ),
                title: Text(opt['label'] as String, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14)),
                onTap: () {
                  HapticService.selection();
                  controller.setSectionFilter(opt['value'] as String?);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showStudentDetails(BuildContext context, MarkAttendanceController controller, dynamic student) {
    final currentStatus = controller.attendanceMap[student.id] ?? AttendanceStatus.present;
    final note = controller.studentNotes[student.id];
    final editEntry = controller.editHistory[student.id];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.15),
                    child: Text(
                      student.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').join().take(2).toString(),
                      style: GoogleFonts.inter(color: AppTheme.accentTeal, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(student.rollNumber, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 13)),
                      ],
                    ),
                  ),
                  if (student.isDefaulter)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text("RISK", style: GoogleFonts.inter(color: AppTheme.errorRed, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailInfo("Department", student.department ?? 'N/A'),
              _buildDetailInfo("Section", student.section ?? 'N/A'),
              _buildDetailInfo("Gender", student.gender ?? 'N/A'),
              _buildDetailInfo("Email", student.email),
              _buildDetailInfo("Attendance", "${student.attendancePercentage.toStringAsFixed(1)}%"),
              _buildDetailInfo("Classes", "${student.attendedClasses}/${student.totalClasses}"),
              _buildDetailInfo("Eligibility", student.isEligible ? "Eligible" : "Defaulter"),
              if (student.guardianName != null)
                _buildDetailInfo("Guardian", student.guardianName!),
              if (student.bloodGroup != null)
                _buildDetailInfo("Blood Group", student.bloodGroup!),
              if (student.lastSeen != null)
                _buildDetailInfo("Last Seen", "${student.lastSeen!.day}/${student.lastSeen!.month}/${student.lastSeen!.year}"),
              if (editEntry != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: AppTheme.accentPurple, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Edited by ${editEntry.editedBy} at ${editEntry.editedAt.hour.toString().padLeft(2, '0')}:${editEntry.editedAt.minute.toString().padLeft(2, '0')}",
                          style: GoogleFonts.inter(color: AppTheme.accentPurple, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note_alt_rounded, color: AppTheme.accentPurple.withValues(alpha: 0.7), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${note.reason}: ${note.remark}",
                          style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text("Mark Attendance", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildStatusOption(context, "Present", Icons.check_circle_rounded, const Color(0xFF22C55E), currentStatus == AttendanceStatus.present, () {
                    controller.markStudent(student.id, AttendanceStatus.present);
                    Navigator.pop(context);
                  })),
                  const SizedBox(width: 6),
                  Expanded(child: _buildStatusOption(context, "Absent", Icons.cancel_rounded, AppTheme.errorRed, currentStatus == AttendanceStatus.absent, () {
                    controller.markStudent(student.id, AttendanceStatus.absent);
                    Navigator.pop(context);
                  })),
                  const SizedBox(width: 6),
                  Expanded(child: _buildStatusOption(context, "Late", Icons.schedule_rounded, const Color(0xFFFBBF24), currentStatus == AttendanceStatus.late, () {
                    controller.markStudent(student.id, AttendanceStatus.late);
                    Navigator.pop(context);
                  })),
                  const SizedBox(width: 6),
                  Expanded(child: _buildStatusOption(context, "Leave", Icons.event_busy_rounded, const Color(0xFF60A5FA), currentStatus == AttendanceStatus.leave, () {
                    controller.markStudent(student.id, AttendanceStatus.leave);
                    Navigator.pop(context);
                  })),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _showNotesDialog(context, controller, student);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      "Add Note",
                      style: GoogleFonts.inter(color: AppTheme.accentPurple, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _showAttendanceHistory(context, controller, student);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      "View Attendance History",
                      style: GoogleFonts.inter(color: AppTheme.accentTeal, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotesDialog(BuildContext context, MarkAttendanceController controller, dynamic student) {
    String selectedReason = 'General';
    final remarkController = TextEditingController();

    final reasons = ['Medical', 'Personal', 'Emergency', 'Late Arrival', 'General'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Text("Add Note for ${student.name}", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Text("Reason", style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reasons.map((r) {
                    final isActive = selectedReason == r;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedReason = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive ? AppTheme.accentPurple.withValues(alpha: 0.15) : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isActive ? AppTheme.accentPurple.withValues(alpha: 0.3) : AppTheme.border(context)),
                        ),
                        child: Text(r, style: GoogleFonts.inter(color: isActive ? AppTheme.accentPurple : AppTheme.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text("Remark", style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: remarkController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter remark...',
                    hintStyle: GoogleFonts.inter(color: AppTheme.textSecondary(context).withValues(alpha: 0.5), fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.surface(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.border(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.accentPurple),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text("Cancel", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          HapticService.medium();
                          controller.markStudentWithNote(
                            student.id,
                            controller.attendanceMap[student.id] ?? AttendanceStatus.present,
                            reason: selectedReason,
                            remark: remarkController.text,
                          );
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text("Save Note", style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAttendanceHistory(BuildContext context, MarkAttendanceController controller, dynamic student) {
    final history = controller.getStudentHistory(student.id);
    final Color textCol = AppTheme.text(context);
    final Color textSec = AppTheme.textSecondary(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${student.name} - History", style: GoogleFonts.inter(color: textCol, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("Last 31 days attendance", style: GoogleFonts.inter(color: textSec, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${student.attendancePercentage.toStringAsFixed(1)}%",
                      style: GoogleFonts.inter(color: AppTheme.accentTeal, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildMiniTrendBar(context, history),
              const SizedBox(height: 16),
              Text("Daily Log", style: GoogleFonts.inter(color: textCol, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...history.reversed.map((entry) {
                final date = entry['date'] as DateTime;
                final status = entry['status'] as AttendanceStatus;
                final checkIn = entry['checkInTime'] as DateTime?;
                final color = _statusColor(status);
                final label = _statusLabel(status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}",
                          style: GoogleFonts.inter(color: textCol, fontSize: 12),
                        ),
                      ),
                      Text(
                        label,
                        style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      if (checkIn != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          "${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}",
                          style: GoogleFonts.inter(color: textSec, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTrendBar(BuildContext context, List<Map<String, dynamic>> history) {
    final Color textSec = AppTheme.textSecondary(context);
    return SizedBox(
      height: 40,
      child: Row(
        children: history.takeLast(14).map((entry) {
          final status = entry['status'] as AttendanceStatus;
          final color = _statusColor(status);
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showBulkMarkDialog(BuildContext context, MarkAttendanceController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.textSecondary(context).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text("Bulk Mark", style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Mark all students at once", style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12)),
            const SizedBox(height: 14),
            _buildBulkOption(context, "Mark All Present", Icons.check_circle_rounded, const Color(0xFF22C55E), () {
              controller.markAllPresent();
              Navigator.pop(context);
            }),
            _buildBulkOption(context, "Mark All Absent", Icons.cancel_rounded, AppTheme.errorRed, () {
              controller.markAllAbsent();
              Navigator.pop(context);
            }),
            _buildBulkOption(context, "Reset All", Icons.restart_alt_rounded, AppTheme.accentPurple, () {
              controller.resetAll();
              Navigator.pop(context);
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkOption(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14)),
      onTap: onTap,
    );
  }

  Widget _buildDetailInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12)),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(BuildContext context, String label, IconData icon, Color color, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, MarkAttendanceController controller) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Cancel Session?", style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This will discard all unsaved attendance marks. This action cannot be undone.",
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              "${controller.markedCount} students marked, ${controller.undoStack.length} changes pending",
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Continue Session", style: GoogleFonts.inter(color: AppTheme.accentTeal)),
          ),
          TextButton(
            onPressed: () {
              controller.cancelSession();
              Navigator.pop(context);
              Navigator.maybePop(context);
            },
            child: Text("Cancel Session", style: GoogleFonts.inter(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  String _filterLabel(FilterMode mode) {
    switch (mode) {
      case FilterMode.all: return 'All';
      case FilterMode.present: return 'Present';
      case FilterMode.absent: return 'Absent';
      case FilterMode.late: return 'Late';
      case FilterMode.leave: return 'Leave';
      case FilterMode.notMarked: return 'Not Marked';
      case FilterMode.eligible: return 'Eligible';
      case FilterMode.below75: return 'Below 75%';
      case FilterMode.above90: return 'Above 90%';
    }
  }

  String _sortLabel(SortMode mode) {
    switch (mode) {
      case SortMode.alphabetical: return 'A-Z';
      case SortMode.nameDesc: return 'Z-A';
      case SortMode.rollNumber: return 'Roll No';
      case SortMode.attendancePercent: return 'Attendance %';
      case SortMode.recentlyUpdated: return 'Recent';
      case SortMode.newest: return 'Newest';
      case SortMode.oldest: return 'Oldest';
    }
  }

  String _genderLabel(String? gender) {
    if (gender == null) return 'Gender: All';
    return 'Gender: $gender';
  }

  String _sectionLabel(String? section) {
    if (section == null) return 'Section: All';
    return 'Section: $section';
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
}

extension _ListExt<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) return toList();
    return sublist(length - count);
  }
}

class _ShimmerCard extends StatefulWidget {
  final bool isDark;
  const _ShimmerCard({required this.isDark});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color textSec = AppTheme.textSecondary(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border(context), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: textSec.withValues(alpha: _animation.value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: textSec.withValues(alpha: _animation.value),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 80,
                      decoration: BoxDecoration(
                        color: textSec.withValues(alpha: _animation.value * 0.7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 50,
                height: 20,
                decoration: BoxDecoration(
                  color: textSec.withValues(alpha: _animation.value),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
