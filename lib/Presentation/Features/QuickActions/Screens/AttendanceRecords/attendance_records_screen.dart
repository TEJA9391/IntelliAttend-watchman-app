import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';

import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Utils/responsive.dart';
import 'package:intelli_attend_faculty/Presentation/Widgets/skeleton_loader.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/attendance_records_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Screens/AttendanceRecords/record_detail_screen.dart';

final DateFormat _fmtDate = DateFormat('MMM d, yyyy');
final DateFormat _fmtTime = DateFormat('h:mm a');

enum _DateFilter { today, yesterday, last7Days, last30Days, custom }

enum _SortOption { date, name, rollNumber, attendancePercent, time, status }

class AttendanceRecordsScreen extends StatefulWidget {
  const AttendanceRecordsScreen({super.key});

  @override
  State<AttendanceRecordsScreen> createState() =>
      _AttendanceRecordsScreenState();
}

class _AttendanceRecordsScreenState extends State<AttendanceRecordsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _sessionsScrollCtrl = ScrollController();
  Timer? _debounce;

  _DateFilter _dateFilter = _DateFilter.last7Days;
  DateTime? _customFrom;
  DateTime? _customTo;
  String? _expandedSessionId;
  bool _isExpandingSession = false;

  _SortOption _sortOption = _SortOption.date;
  bool _sortAsc = false;
  String _filterCourse = '';
  String _filterSection = '';
  Set<AttendanceStatus> _filterStatuses = {};
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  String _filterStudentQuery = '';

  List<AttendanceRecord> _historyRecords = [];
  bool _isLoadingHistory = false;

  static const Color _cPresent = Color(0xFF22C55E);
  static const Color _cAbsent = Color(0xFFEF4444);
  static const Color _cLate = Color(0xFFFBBF24);
  static const Color _cLeave = Color(0xFF2DD4BF);
  static const Color _cHoliday = Color(0xFF60A5FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _sessionsScrollCtrl.addListener(_onScroll);
    _tabController.addListener(_onTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyDateFilter();
      context.read<AttendanceRecordsController>().loadSummary();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _sessionsScrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1 &&
        _historyRecords.isEmpty &&
        !_isLoadingHistory) {
      _loadAllHistoryRecords();
    }
  }

  void _onScroll() {
    final pos = _sessionsScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      context.read<AttendanceRecordsController>().loadMore();
    }
  }

  void _applyDateFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? from;
    DateTime? to;
    switch (_dateFilter) {
      case _DateFilter.today:
        from = today;
        to = today
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
      case _DateFilter.yesterday:
        from = today.subtract(const Duration(days: 1));
        to = today.subtract(const Duration(seconds: 1));
      case _DateFilter.last7Days:
        from = today.subtract(const Duration(days: 6));
        to = today
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
      case _DateFilter.last30Days:
        from = today.subtract(const Duration(days: 29));
        to = today
            .add(const Duration(days: 1))
            .subtract(const Duration(seconds: 1));
      case _DateFilter.custom:
        from = _customFrom;
        to = _customTo;
    }
    context
        .read<AttendanceRecordsController>()
        .loadSessions(dateFrom: from, dateTo: to);
  }

  Future<void> _onRefresh() async {
    final c = context.read<AttendanceRecordsController>();
    _applyDateFilter();
    await c.loadSummary();
    if (_tabController.index == 1) await _loadAllHistoryRecords();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<AttendanceRecordsController>().search(q);
    });
  }

  Future<void> _loadAllHistoryRecords() async {
    setState(() => _isLoadingHistory = true);
    final c = context.read<AttendanceRecordsController>();
    final List<AttendanceRecord> all = [];
    for (final s in c.sessions) {
      await c.loadSessionRecords(s.sessionId);
      all.addAll(c.currentSessionRecords);
    }
    if (!mounted) return;
    setState(() {
      _historyRecords = all;
      _isLoadingHistory = false;
    });
  }

  Future<void> _toggleExpansion(AttendanceSession session) async {
    HapticService.light();
    if (_expandedSessionId == session.sessionId) {
      setState(() => _expandedSessionId = null);
      return;
    }
    setState(() {
      _expandedSessionId = session.sessionId;
      _isExpandingSession = true;
    });
    await context
        .read<AttendanceRecordsController>()
        .loadSessionRecords(session.sessionId);
    if (mounted) setState(() => _isExpandingSession = false);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.accentTeal,
            onPrimary: Colors.white,
            surface: AppTheme.card(context),
            onSurface: AppTheme.text(context),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateFilter = _DateFilter.custom;
        _customFrom = picked.start;
        _customTo = picked.end;
      });
      _applyDateFilter();
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        filterCourse: _filterCourse,
        filterSection: _filterSection,
        filterStatuses: _filterStatuses,
        filterDateFrom: _filterDateFrom,
        filterDateTo: _filterDateTo,
        filterStudentQuery: _filterStudentQuery,
        sessions: context.read<AttendanceRecordsController>().sessions,
        onApply: (course, section, statuses, df, dt, sq) {
          setState(() {
            _filterCourse = course;
            _filterSection = section;
            _filterStatuses = statuses;
            _filterDateFrom = df;
            _filterDateTo = dt;
            _filterStudentQuery = sq;
          });
        },
      ),
    );
  }

  List<AttendanceRecord> get _filteredHistory {
    var list = List<AttendanceRecord>.from(_historyRecords);
    if (_filterCourse.isNotEmpty) {
      list = list.where((e) => e.courseCode == _filterCourse).toList();
    }
    if (_filterSection.isNotEmpty) {
      list = list.where((e) => e.section == _filterSection).toList();
    }
    if (_filterStatuses.isNotEmpty) {
      list = list.where((e) => _filterStatuses.contains(e.status)).toList();
    }
    if (_filterDateFrom != null) {
      list = list.where((e) => !e.date.isBefore(_filterDateFrom!)).toList();
    }
    if (_filterDateTo != null) {
      final end = DateTime(
          _filterDateTo!.year, _filterDateTo!.month, _filterDateTo!.day, 23, 59, 59);
      list = list.where((e) => !e.date.isAfter(end)).toList();
    }
    if (_filterStudentQuery.isNotEmpty) {
      final q = _filterStudentQuery.toLowerCase();
      list = list
          .where((e) =>
              e.studentName.toLowerCase().contains(q) ||
              e.rollNumber.toLowerCase().contains(q) ||
              e.studentId.toLowerCase().contains(q))
          .toList();
    }
    final dir = _sortAsc ? 1 : -1;
    switch (_sortOption) {
      case _SortOption.date:
        list.sort((a, b) => dir * a.date.compareTo(b.date));
      case _SortOption.name:
        list.sort((a, b) => dir * a.studentName.compareTo(b.studentName));
      case _SortOption.rollNumber:
        list.sort((a, b) => dir * a.rollNumber.compareTo(b.rollNumber));
      case _SortOption.attendancePercent:
        list.sort((a, b) =>
            dir * (a.attendancePercentage ?? 0).compareTo(b.attendancePercentage ?? 0));
      case _SortOption.time:
        list.sort((a, b) {
          final aTime = a.checkInTime ?? DateTime(2000);
          final bTime = b.checkInTime ?? DateTime(2000);
          return dir * aTime.compareTo(bTime);
        });
      case _SortOption.status:
        const order = {
          AttendanceStatus.present: 0,
          AttendanceStatus.late: 1,
          AttendanceStatus.absent: 2,
          AttendanceStatus.leave: 3,
          AttendanceStatus.holiday: 4,
        };
        list.sort((a, b) =>
            dir * (order[a.status] ?? 5).compareTo(order[b.status] ?? 5));
    }
    return list;
  }

  Color _sColor(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => _cPresent,
        AttendanceStatus.absent => _cAbsent,
        AttendanceStatus.late => _cLate,
        AttendanceStatus.leave => _cLeave,
        AttendanceStatus.holiday => _cHoliday,
      };

  String _sLabel(AttendanceStatus s) =>
      s.name[0].toUpperCase() + s.name.substring(1);

  IconData _sIcon(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => Icons.check_circle_outline_rounded,
        AttendanceStatus.absent => Icons.cancel_outlined,
        AttendanceStatus.late => Icons.access_time_rounded,
        AttendanceStatus.leave => Icons.event_busy_rounded,
        AttendanceStatus.holiday => Icons.celebration_rounded,
      };

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• BUILD â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAppBar(r),
            _buildTabBar(r),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSessionsTab(r),
                  _buildHistoryTab(r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(Responsive r) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: r.paddingXS, vertical: r.spacingXS),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: EdgeInsets.all(r.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: r.iconS, color: AppTheme.text(context)),
            ),
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Attendance Records',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: r.fontSizeL,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'View and manage attendance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context),
                    fontSize: r.fontSizeXS,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.spacingS),
          GestureDetector(
            onTap: _showExportSheet,
            child: Container(
              padding: EdgeInsets.all(r.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.file_download_rounded,
                  size: r.iconS, color: AppTheme.accentTeal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(Responsive r) {
    return Container(
      margin:
          EdgeInsets.symmetric(horizontal: r.paddingM, vertical: r.spacingXS),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppTheme.accentTeal,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary(context),
        labelStyle:
            GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        splashBorderRadius: BorderRadius.circular(10),
        tabs: const [
          Tab(text: 'Sessions'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• SESSIONS TAB â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSessionsTab(Responsive r) {
    return Consumer<AttendanceRecordsController>(
      builder: (context, ctrl, _) {
        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppTheme.accentTeal,
          backgroundColor: AppTheme.card(context),
          child: CustomScrollView(
            controller: _sessionsScrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildSummary(ctrl, r)),
              SliverToBoxAdapter(child: _buildDateChips(r)),
              if (ctrl.isLoading && ctrl.sessions.isEmpty)
                SliverToBoxAdapter(child: _buildSkeleton(r))
              else if (ctrl.error != null && ctrl.sessions.isEmpty)
                SliverToBoxAdapter(child: _buildError(ctrl, r))
              else if (ctrl.sessions.isEmpty)
                SliverToBoxAdapter(
                    child: _buildEmpty('No Sessions Found',
                        'No attendance sessions match your current filters.', r))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      if (i >= ctrl.sessions.length) {
                        return _buildLoadMoreSpinner();
                      }
                      return _buildSessionCard(ctrl.sessions[i], ctrl, r);
                    },
                    childCount:
                        ctrl.sessions.length + (ctrl.hasMore ? 1 : 0),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• SUMMARY â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSummary(AttendanceRecordsController ctrl, Responsive r) {
    final sm = ctrl.summary;
    final sessions = ctrl.sessions;
    final int totalSessions = sessions.isNotEmpty
        ? sessions.length
        : (sm['totalSessions'] as int? ?? 0);
    final double avg = sessions.isNotEmpty
        ? sessions.map((s) => s.attendanceRate).reduce((a, b) => a + b) / sessions.length
        : (sm['averageAttendance'] as double? ?? 0.0);
    AttendanceSession? best;
    AttendanceSession? worst;
    if (sessions.isNotEmpty) {
      best = sessions
          .reduce((a, b) => a.attendanceRate > b.attendanceRate ? a : b);
      worst = sessions
          .reduce((a, b) => a.attendanceRate < b.attendanceRate ? a : b);
      if (best.attendanceRate == worst.attendanceRate) worst = null;
    }

    return Container(
      margin:
          EdgeInsets.fromLTRB(r.paddingM, r.spacingS, r.paddingM, r.spacingS),
      padding: EdgeInsets.all(r.paddingM),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(r.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics_outlined,
                    size: r.iconM, color: AppTheme.accentTeal),
              ),
              SizedBox(width: r.spacingS),
              Flexible(
                child: Text(
                  'Attendance Overview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: r.fontSizeM,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text(context),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingM),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                    '$totalSessions', 'Sessions', AppTheme.accentTeal, r),
              ),
              SizedBox(width: r.spacingS),
              Expanded(
                child: _metricCard(
                  '${avg.toStringAsFixed(1)}%',
                  'Avg Attendance',
                  avg >= 75 ? _cPresent : avg >= 50 ? _cLate : _cAbsent,
                  r,
                ),
              ),
            ],
          ),
          if (best != null) ...[
            SizedBox(height: r.spacingS),
            _bestWorstLine(Icons.trending_up_rounded, 'Best',
                '${best.courseCode} Sec ${best.section}', best.attendanceRate, _cPresent, r),
          ],
          if (worst != null) ...[
            SizedBox(height: r.spacingXS),
            _bestWorstLine(Icons.trending_down_rounded, 'Worst',
                '${worst.courseCode} Sec ${worst.section}', worst.attendanceRate, _cAbsent, r),
          ],
        ],
      ),
    );
  }

  Widget _metricCard(String v, String l, Color c, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.spacingS),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(v,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: r.fontSizeL,
                    fontWeight: FontWeight.w800,
                    color: c)),
          ),
          SizedBox(height: r.spacingXS),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(l,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: r.fontSizeXS,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary(context))),
          ),
        ],
      ),
    );
  }

  Widget _bestWorstLine(IconData icon, String label, String course,
      double rate, Color c, Responsive r) {
    return Row(
      children: [
        Icon(icon, size: r.iconS, color: c),
        SizedBox(width: r.spacingXS),
        Text('$label:',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: r.fontSizeXS,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary(context))),
        SizedBox(width: r.spacingXS),
        Flexible(
          child: Text('$course (${rate.toStringAsFixed(1)}%)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: r.fontSizeXS,
                  fontWeight: FontWeight.w700,
                  color: c)),
        ),
      ],
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• DATE FILTER CHIPS â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildDateChips(Responsive r) {
    final filters = [
      (_DateFilter.today, 'Today'),
      (_DateFilter.yesterday, 'Yesterday'),
      (_DateFilter.last7Days, 'Last 7 Days'),
      (_DateFilter.last30Days, 'Last 30 Days'),
      (_DateFilter.custom, 'Custom'),
    ];
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
            horizontal: r.paddingM, vertical: r.spacingS),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: r.spacingXS),
        itemBuilder: (_, i) {
          final (f, label) = filters[i];
          final active = _dateFilter == f;
          final isCustomRange = f == _DateFilter.custom && _customFrom != null;
          return GestureDetector(
            onTap: () {
              HapticService.selection();
              if (f == _DateFilter.custom) {
                _pickCustomRange();
              } else {
                setState(() => _dateFilter = f);
                _applyDateFilter();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                  horizontal: r.spacingM, vertical: r.spacingXS),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.accentTeal.withValues(alpha: 0.15)
                    : AppTheme.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? AppTheme.accentTeal.withValues(alpha: 0.3)
                      : AppTheme.border(context),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCustomRange) ...[
                    Icon(Icons.calendar_today_rounded,
                        size: r.iconS * 0.8,
                        color: active
                            ? AppTheme.accentTeal
                            : AppTheme.textSecondary(context)),
                    SizedBox(width: r.spacingXS),
                  ],
                  Flexible(
                    child: Text(
                      isCustomRange
                          ? '${_fmtDate.format(_customFrom!)} - ${_fmtDate.format(_customTo!)}'
                          : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: r.fontSizeXS,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppTheme.accentTeal
                            : AppTheme.textSecondary(context),
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

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• SESSION CARD â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSessionCard(
      AttendanceSession s, AttendanceRecordsController ctrl, Responsive r) {
    final expanded = _expandedSessionId == s.sessionId;
    final rate = s.attendanceRate;
    final rateColor = rate >= 75 ? _cPresent : rate >= 50 ? _cLate : _cAbsent;

    return Container(
      margin: EdgeInsets.fromLTRB(r.paddingM, 0, r.paddingM, r.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded
              ? AppTheme.accentTeal.withValues(alpha: 0.3)
              : AppTheme.border(context),
          width: expanded ? 1.0 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: expanded ? 0.08 : 0.03),
            blurRadius: expanded ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _toggleExpansion(s),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(r.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${s.courseCode} - ${s.courseName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: r.fontSizeM,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text(context),
                              ),
                            ),
                            SizedBox(height: r.spacingXS),
                            Row(
                              children: [
                                Icon(Icons.group_outlined,
                                    size: r.iconS * 0.8,
                                    color: AppTheme.textSecondary(context)),
                                SizedBox(width: r.spacingXS),
                                Flexible(
                                  child: Text(
                                    'Section ${s.section}  \u2022  ${_fmtDate.format(s.date)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: r.fontSizeXS,
                                      color:
                                          AppTheme.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: r.spacingS),
                      _rateBadge(rate, rateColor, r),
                    ],
                  ),
                  SizedBox(height: r.spacingM),
                  _countRow(s, r),
                  SizedBox(height: r.spacingS),
                  _attBar(s),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? _expandedDetails(ctrl, r)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _rateBadge(double rate, Color c, Responsive r) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: r.spacingS, vertical: r.spacingXS),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${rate.toStringAsFixed(0)}%',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: r.fontSizeM,
            fontWeight: FontWeight.w800,
            color: c,
          ),
        ),
      ),
    );
  }

  Widget _countRow(AttendanceSession s, Responsive r) {
    return Row(
      children: [
        _dot('P', s.presentCount, _cPresent, r),
        SizedBox(width: r.spacingS),
        _dot('A', s.absentCount, _cAbsent, r),
        SizedBox(width: r.spacingS),
        _dot('L', s.lateCount, _cLate, r),
        SizedBox(width: r.spacingS),
        _dot('Lv', s.leaveCount, _cLeave, r),
        const Spacer(),
        AnimatedRotation(
          turns: _expandedSessionId == s.sessionId ? 0.5 : 0,
          duration: const Duration(milliseconds: 250),
          child: Icon(Icons.expand_more_rounded,
              size: r.iconM, color: AppTheme.textSecondary(context)),
        ),
      ],
    );
  }

  Widget _dot(String label, int count, Color c, Responsive r) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: r.spacingS,
          height: r.spacingS,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        SizedBox(width: r.spacingXS),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$label: $count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: r.fontSizeXS,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _attBar(AttendanceSession s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final t = s.totalStudents;
        if (t == 0) return const SizedBox.shrink();
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (s.presentCount > 0)
                Expanded(
                    flex: s.presentCount,
                    child: Container(color: _cPresent)),
              if (s.lateCount > 0)
                Expanded(
                    flex: s.lateCount, child: Container(color: _cLate)),
              if (s.absentCount > 0)
                Expanded(
                    flex: s.absentCount,
                    child: Container(color: _cAbsent)),
              if (s.leaveCount > 0)
                Expanded(
                    flex: s.leaveCount,
                    child: Container(color: _cLeave)),
            ],
          ),
        );
      },
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• EXPANDED DETAILS â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _expandedDetails(AttendanceRecordsController ctrl, Responsive r) {
    if (_isExpandingSession) {
      return Padding(
        padding: EdgeInsets.all(r.paddingM),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
            ),
          ),
        ),
      );
    }
    final records = ctrl.currentSessionRecords;
    if (records.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(r.paddingM),
        child: Center(
          child: Text(
            'No records available',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: r.fontSizeXS,
                color: AppTheme.textSecondary(context)),
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: AppTheme.border(context)),
        ...records.map((rec) => _expandedTile(rec, r)),
        SizedBox(height: r.spacingXS),
      ],
    );
  }

  Widget _expandedTile(AttendanceRecord rec, Responsive r) {
    final c = _sColor(rec.status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.paddingM, vertical: r.spacingS),
      child: Row(
        children: [
          Container(
            width: r.spacingL,
            height: r.spacingL,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_sIcon(rec.status),
                size: r.iconS * 0.9, color: c),
          ),
          SizedBox(width: r.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(rec.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: r.fontSizeS,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text(context))),
                Text(rec.rollNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: r.fontSizeXS,
                        color: AppTheme.textSecondary(context))),
              ],
            ),
          ),
          SizedBox(width: r.spacingS),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.spacingS,
                    vertical: r.spacingXS * 0.5),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_sLabel(rec.status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: r.fontSizeXS * 0.85,
                        fontWeight: FontWeight.w700,
                        color: c)),
              ),
              if (rec.checkInTime != null)
                Text(_fmtTime.format(rec.checkInTime!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: r.fontSizeXS * 0.8,
                        color: AppTheme.textSecondary(context))),
            ],
          ),
        ],
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• HISTORY TAB â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildHistoryTab(Responsive r) {
    if (_isLoadingHistory) return _buildSkeleton(r);
    final records = _filteredHistory;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSearchBar(r),
        _buildSortBar(r),
        Expanded(
          child: records.isEmpty
              ? _buildEmpty('No Records Found',
                  'No attendance records match your search or filters.', r)
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppTheme.accentTeal,
                  backgroundColor: AppTheme.card(context),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    padding: EdgeInsets.symmetric(
                        horizontal: r.paddingM, vertical: r.spacingS),
                    itemCount: records.length,
                    itemBuilder: (_, i) => _historyCard(records[i], r),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(Responsive r) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          r.paddingM, r.spacingS, r.paddingM, r.spacingXS),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(
                  color: AppTheme.text(context), fontSize: r.fontSizeS),
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Search by name, roll, or ID...',
                hintStyle: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context)
                        .withValues(alpha: 0.5),
                    fontSize: r.fontSizeS),
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppTheme.textSecondary(context),
                    size: r.iconM),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        child: Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary(context),
                            size: r.iconM),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.card(context),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: r.spacingM, vertical: r.spacingS),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(width: r.spacingS),
          GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              padding: EdgeInsets.all(r.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.border(context), width: 0.5),
              ),
              child: Icon(Icons.tune_rounded,
                  size: r.iconM, color: AppTheme.accentTeal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar(Responsive r) {
    final opts = [
      (_SortOption.date, 'Date', Icons.calendar_today_rounded),
      (_SortOption.name, 'Name', Icons.sort_by_alpha_rounded),
      (_SortOption.rollNumber, 'Roll No', Icons.tag_rounded),
      (_SortOption.attendancePercent, '%', Icons.percent_rounded),
      (_SortOption.time, 'Time', Icons.access_time_rounded),
      (_SortOption.status, 'Status', Icons.sort_rounded),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
            horizontal: r.paddingM, vertical: r.spacingXS),
        itemCount: opts.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: r.spacingXS),
        itemBuilder: (_, i) {
          if (i == opts.length) {
            return GestureDetector(
              onTap: () {
                HapticService.selection();
                setState(() => _sortAsc = !_sortAsc);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                    horizontal: r.spacingS, vertical: r.spacingXS),
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.border(context),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sortAsc
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: r.iconS * 0.7,
                      color: AppTheme.accentTeal,
                    ),
                    SizedBox(width: r.spacingXS),
                    Flexible(
                      child: Text(
                        _sortAsc ? 'Asc' : 'Desc',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: r.fontSizeXS,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final (opt, label, icon) = opts[i];
          final active = _sortOption == opt;
          return GestureDetector(
            onTap: () {
              HapticService.selection();
              setState(() {
                if (_sortOption == opt) {
                  _sortAsc = !_sortAsc;
                } else {
                  _sortOption = opt;
                  _sortAsc = opt == _SortOption.name;
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                  horizontal: r.spacingM, vertical: r.spacingXS),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.accentTeal.withValues(alpha: 0.15)
                    : AppTheme.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active
                      ? AppTheme.accentTeal.withValues(alpha: 0.3)
                      : AppTheme.border(context),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: r.iconS * 0.7,
                      color: active
                          ? AppTheme.accentTeal
                          : AppTheme.textSecondary(context)),
                  SizedBox(width: r.spacingXS),
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: r.fontSizeXS,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppTheme.accentTeal
                              : AppTheme.textSecondary(context),
                        )),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _historyCard(AttendanceRecord rec, Responsive r) {
    final c = _sColor(rec.status);
    return GestureDetector(
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(record: rec),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: r.spacingS),
        padding: EdgeInsets.all(r.paddingM),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(rec.studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: r.fontSizeS,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text(context))),
                      SizedBox(height: r.spacingXS * 0.5),
                      Text('${rec.rollNumber}  \u2022  ${rec.courseCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: r.fontSizeXS,
                              color: AppTheme.textSecondary(context))),
                    ],
                  ),
                ),
                SizedBox(width: r.spacingS),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.spacingS,
                      vertical: r.spacingXS * 0.7),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_sIcon(rec.status),
                          size: r.iconS * 0.7, color: c),
                      SizedBox(width: r.spacingXS),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _sLabel(rec.status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: r.fontSizeXS * 0.9,
                            fontWeight: FontWeight.w700,
                            color: c,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.spacingS),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: r.iconS * 0.6,
                    color: AppTheme.textSecondary(context)),
                SizedBox(width: r.spacingXS),
                Flexible(
                  child: Text(
                    _fmtDate.format(rec.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: r.fontSizeXS,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                ),
                if (rec.checkInTime != null) ...[
                  SizedBox(width: r.spacingM),
                  Icon(Icons.access_time_rounded,
                      size: r.iconS * 0.6,
                      color: AppTheme.textSecondary(context)),
                  SizedBox(width: r.spacingXS),
                  Flexible(
                    child: Text(
                      _fmtTime.format(rec.checkInTime!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: r.fontSizeXS,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: r.iconS, color: AppTheme.textSecondary(context).withValues(alpha: 0.5)),
              ],
            ),
            if (rec.notes != null && rec.notes!.isNotEmpty) ...[
              SizedBox(height: r.spacingS),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.spacingS),
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rec.notes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: r.fontSizeXS,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• SHARED WIDGETS â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

  Widget _buildSkeleton(Responsive r) {
    return Padding(
      padding: EdgeInsets.all(r.paddingM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          4,
          (_) => Container(
            margin: EdgeInsets.only(bottom: r.spacingS),
            padding: EdgeInsets.all(r.paddingM),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SkeletonLoader(
                        width: r.screenWidth * 0.5,
                        height: r.fontSizeM,
                        borderRadius: 8),
                    const Spacer(),
                    SkeletonLoader(
                        width: r.wp(12),
                        height: r.fontSizeL,
                        borderRadius: 10),
                  ],
                ),
                SizedBox(height: r.spacingS),
                SkeletonLoader(
                    width: r.screenWidth * 0.35,
                    height: r.fontSizeXS,
                    borderRadius: 6),
                SizedBox(height: r.spacingM),
                Row(
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: EdgeInsets.only(right: r.spacingS),
                      child: SkeletonLoader(
                          width: r.wp(14),
                          height: r.fontSizeXS,
                          borderRadius: 6),
                    ),
                  ),
                ),
                SizedBox(height: r.spacingS),
                SkeletonLoader(
                    width: double.infinity, height: 8, borderRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String subtitle, Responsive r) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 64,
                color: AppTheme.accentTeal.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text(context))),
            const SizedBox(height: 8),
            Text(subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary(context))),
          ],
        ),
      ),
    );
  }

  Widget _buildError(AttendanceRecordsController ctrl, Responsive r) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 64, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 24),
            Text('Something went wrong',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text(context))),
            const SizedBox(height: 8),
            Text(ctrl.error ?? 'An unexpected error occurred',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary(context))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                HapticService.light();
                _applyDateFilter();
                ctrl.loadSummary();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Retry',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreSpinner() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
          ),
        ),
      ),
    );
  }

  void _showExportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportSheet(
        recordCount: _tabController.index == 1 ? _filteredHistory.length : null,
        onExportCsv: _exportCsv,
        onExportExcel: _exportExcel,
        onExportPdf: _exportPdf,
        onExportShare: _exportShare,
      ),
    );
  }

  Future<void> _exportCsv() async {
    Navigator.pop(context);
    final records = _tabController.index == 1 ? _filteredHistory : [];
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No records to export',
              style: GoogleFonts.inter(fontSize: 14)),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('IntelliAttend - Faculty Attendance Management');
    buffer.writeln('');
    buffer.writeln(
        'Student Name,Roll Number,Student ID,Course Code,Course Name,Section,Date,Status,Check In,Check Out,Faculty,Department,Session Type,Sync Status,Notes');
    for (final r in records) {
      buffer.writeln(
        '"${r.studentName}","${r.rollNumber}","${r.studentId}","${r.courseCode}","${r.courseName}","${r.section}","${_fmtDate.format(r.date)}","${r.status.name}","${r.checkInTime != null ? _fmtTime.format(r.checkInTime!) : ''}","${r.checkOutTime != null ? _fmtTime.format(r.checkOutTime!) : ''}","${r.facultyName ?? ''}","${r.department ?? ''}","${r.sessionType ?? ''}","${r.syncStatus ?? ''}","${(r.notes ?? '').replaceAll('"', '""')}"',
      );
    }
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: 'Attendance Records CSV'),
    );
  }

  Future<void> _exportShare() async {
    Navigator.pop(context);
    final records = _tabController.index == 1 ? _filteredHistory : [];
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No records to share',
              style: GoogleFonts.inter(fontSize: 14)),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('IntelliAttend - Faculty Attendance Management');
    buffer.writeln('');
    buffer.writeln('=== Attendance Records Report ===');
    buffer.writeln('Generated: ${_fmtDate.format(DateTime.now())}');
    buffer.writeln('Total Records: ${records.length}');
    buffer.writeln('');
    for (final r in records) {
      buffer.writeln(
          '${r.studentName} (${r.rollNumber}) - ${r.courseCode} - ${_sLabel(r.status)} - ${_fmtDate.format(r.date)}');
    }
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(text: buffer.toString(), subject: 'Attendance Report'),
    );
  }

  Future<void> _exportExcel() async {
    Navigator.pop(context);
    final records = _tabController.index == 1 ? _filteredHistory : [];
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No records to export', style: GoogleFonts.inter(fontSize: 14)),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final excel = xl.Excel.createExcel();
    final sheet = excel['Attendance Records'];

    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#1A9E8F'),
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: xl.HorizontalAlign.Center,
    );

    final headers = ['Student Name', 'Roll Number', 'Student ID', 'Course', 'Section', 'Date', 'Status', 'Check In', 'Check Out', 'Faculty', 'Department'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = xl.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final row = i + 1;
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = xl.TextCellValue(r.studentName);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = xl.TextCellValue(r.rollNumber);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = xl.TextCellValue(r.studentId);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = xl.TextCellValue(r.courseCode);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = xl.TextCellValue(r.section);
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = xl.TextCellValue(_fmtDate.format(r.date));
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = xl.TextCellValue(_sLabel(r.status));
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = xl.TextCellValue(r.checkInTime != null ? _fmtTime.format(r.checkInTime!) : '');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value = xl.TextCellValue(r.checkOutTime != null ? _fmtTime.format(r.checkOutTime!) : '');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value = xl.TextCellValue(r.facultyName ?? '');
      sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value = xl.TextCellValue(r.department ?? '');
    }

    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnAutoFit(i);
    }

    final bytes = excel.save();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/attendance_records.xlsx');
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open Excel file', style: GoogleFonts.inter(fontSize: 14)),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    Navigator.pop(context);
    final records = _tabController.index == 1 ? _filteredHistory : [];
    if (records.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No records to export', style: GoogleFonts.inter(fontSize: 14)),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('IntelliAttend - Attendance Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Generated: ${_fmtDate.format(DateTime.now())}  |  Total Records: ${records.length}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          pw.Divider(),
        ],
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.centerLeft,
          headerAlignment: pw.Alignment.centerLeft,
          headers: ['Student Name', 'Roll No', 'Course', 'Section', 'Date', 'Status', 'Check In'],
          data: records.map((r) => [
            r.studentName,
            r.rollNumber,
            r.courseCode,
            r.section,
            _fmtDate.format(r.date),
            _sLabel(r.status),
            r.checkInTime != null ? _fmtTime.format(r.checkInTime!) : '-',
          ]).toList(),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.0),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(1.0),
            6: const pw.FlexColumnWidth(1.2),
          },
        ),
      ],
    ));

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/attendance_records.pdf');
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open PDF file', style: GoogleFonts.inter(fontSize: 14)),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}


// ─────────────────── EXPORT BOTTOM SHEET ───────────────────

class _ExportSheet extends StatelessWidget {
  final int? recordCount;
  final VoidCallback onExportCsv;
  final VoidCallback onExportExcel;
  final VoidCallback onExportPdf;
  final VoidCallback onExportShare;

  const _ExportSheet({
    required this.recordCount,
    required this.onExportCsv,
    required this.onExportExcel,
    required this.onExportPdf,
    required this.onExportShare,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                r.paddingM, r.spacingM, r.paddingM, r.spacingS),
            child: Row(
              children: [
                Icon(Icons.file_download_rounded,
                    size: r.iconM, color: AppTheme.accentTeal),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Export Records',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: r.fontSizeL,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text(context),
                        ),
                      ),
                      if (recordCount != null)
                        Text(
                          '$recordCount records will be exported',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: r.fontSizeXS,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                r.paddingM, r.spacingS, r.paddingM, r.paddingM),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _exportOption(context,
                  Icons.table_chart_rounded,
                  'Export as CSV',
                  'Spreadsheet-compatible format',
                  onExportCsv,
                  r,
                ),
                SizedBox(height: r.spacingS),
                _exportOption(context,
                  Icons.grid_on_rounded,
                  'Export as Excel',
                  'Microsoft Excel format (.xlsx)',
                  onExportExcel,
                  r,
                ),
                SizedBox(height: r.spacingS),
                _exportOption(context,
                  Icons.picture_as_pdf_rounded,
                  'Export as PDF',
                  'Formatted PDF document',
                  onExportPdf,
                  r,
                ),
                SizedBox(height: r.spacingS),
                _exportOption(context,
                  Icons.share_rounded,
                  'Share as Text',
                  'Plain text summary for sharing',
                  onExportShare,
                  r,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportOption(BuildContext context,
      IconData icon, String title, String subtitle, VoidCallback onTap, Responsive r) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.paddingM),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border(context), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(r.spacingS),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: r.iconM, color: AppTheme.accentTeal),
            ),
            SizedBox(width: r.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: r.fontSizeS,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text(context))),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: r.fontSizeXS,
                          color: AppTheme.textSecondary(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: r.iconM, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â• FILTER BOTTOM SHEET â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _FilterSheet extends StatefulWidget {
  final String filterCourse;
  final String filterSection;
  final Set<AttendanceStatus> filterStatuses;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final String filterStudentQuery;
  final List<AttendanceSession> sessions;
  final void Function(
    String course,
    String section,
    Set<AttendanceStatus> statuses,
    DateTime? dateFrom,
    DateTime? dateTo,
    String studentQuery,
  ) onApply;

  const _FilterSheet({
    required this.filterCourse,
    required this.filterSection,
    required this.filterStatuses,
    this.filterDateFrom,
    this.filterDateTo,
    required this.filterStudentQuery,
    required this.sessions,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _selectedCourse;
  late String _selectedSection;
  late Set<AttendanceStatus> _selectedStatuses;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  late TextEditingController _studentCtrl;

  static const Color _cPresent = Color(0xFF22C55E);
  static const Color _cAbsent = Color(0xFFEF4444);
  static const Color _cLate = Color(0xFFFBBF24);
  static const Color _cLeave = Color(0xFF2DD4BF);
  static const Color _cHoliday = Color(0xFF60A5FA);

  List<String> get _courses =>
      widget.sessions.map((s) => s.courseCode).toSet().toList()..sort();

  List<String> get _sections =>
      widget.sessions.map((s) => s.section).toSet().toList()..sort();

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.filterCourse;
    _selectedSection = widget.filterSection;
    _selectedStatuses = Set.from(widget.filterStatuses);
    _dateFrom = widget.filterDateFrom;
    _dateTo = widget.filterDateTo;
    _studentCtrl = TextEditingController(text: widget.filterStudentQuery);
  }

  @override
  void dispose() {
    _studentCtrl.dispose();
    super.dispose();
  }

  Color _sColor(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => _cPresent,
        AttendanceStatus.absent => _cAbsent,
        AttendanceStatus.late => _cLate,
        AttendanceStatus.leave => _cLeave,
        AttendanceStatus.holiday => _cHoliday,
      };

  String _sLabel(AttendanceStatus s) =>
      s.name[0].toUpperCase() + s.name.substring(1);

  void _apply() {
    widget.onApply(
      _selectedCourse,
      _selectedSection,
      _selectedStatuses,
      _dateFrom,
      _dateTo,
      _studentCtrl.text,
    );
    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      _selectedCourse = '';
      _selectedSection = '';
      _selectedStatuses.clear();
      _dateFrom = null;
      _dateTo = null;
      _studentCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final hasFilters = _selectedCourse.isNotEmpty ||
        _selectedSection.isNotEmpty ||
        _selectedStatuses.isNotEmpty ||
        _dateFrom != null ||
        _dateTo != null ||
        _studentCtrl.text.isNotEmpty;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppTheme.textSecondary(context).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                r.paddingM, r.spacingM, r.paddingM, r.spacingS),
            child: Row(
              children: [
                Icon(Icons.tune_rounded,
                    size: r.iconM, color: AppTheme.accentTeal),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: Text(
                    'Filter Records',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: r.fontSizeL,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text(context),
                    ),
                  ),
                ),
                if (hasFilters)
                  GestureDetector(
                    onTap: _clearAll,
                    child: Text(
                      'Clear All',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: r.fontSizeS,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.errorRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  EdgeInsets.symmetric(horizontal: r.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterSection('Course', _courses, _selectedCourse,
                      (v) {
                    setState(() =>
                        _selectedCourse = v == _selectedCourse ? '' : v);
                  }, r),
                  SizedBox(height: r.spacingM),
                  _buildFilterSection('Section', _sections, _selectedSection,
                      (v) {
                    setState(() =>
                        _selectedSection = v == _selectedSection ? '' : v);
                  }, r),
                  SizedBox(height: r.spacingM),
                  _buildStatusFilter(r),
                  SizedBox(height: r.spacingM),
                  _buildDateRangeFilter(r),
                  SizedBox(height: r.spacingM),
                  _buildStudentSearch(r),
                  SizedBox(height: r.spacingM),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                r.paddingM, r.spacingS, r.paddingM, r.paddingM),
            child: GestureDetector(
              onTap: _apply,
              child: Container(
                width: double.infinity,
                padding:
                    EdgeInsets.symmetric(vertical: r.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Apply Filters',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: r.fontSizeM,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    String selected,
    ValueChanged<String> onTap,
    Responsive r,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: r.fontSizeS,
                fontWeight: FontWeight.w600,
                color: AppTheme.text(context))),
        SizedBox(height: r.spacingS),
        Wrap(
          spacing: r.spacingXS,
          runSpacing: r.spacingXS,
          children: options.map((opt) {
            final active = selected == opt;
            return GestureDetector(
              onTap: () {
                HapticService.selection();
                onTap(opt);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                    horizontal: r.spacingM, vertical: r.spacingXS),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.accentTeal.withValues(alpha: 0.15)
                      : AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? AppTheme.accentTeal.withValues(alpha: 0.3)
                        : AppTheme.border(context),
                    width: 0.5,
                  ),
                ),
                child: Text(opt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: r.fontSizeXS,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppTheme.accentTeal
                            : AppTheme.textSecondary(context))),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusFilter(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Status',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: r.fontSizeS,
                fontWeight: FontWeight.w600,
                color: AppTheme.text(context))),
        SizedBox(height: r.spacingS),
        Wrap(
          spacing: r.spacingXS,
          runSpacing: r.spacingXS,
          children: AttendanceStatus.values.map((status) {
            final active = _selectedStatuses.contains(status);
            final c = _sColor(status);
            return GestureDetector(
              onTap: () {
                HapticService.selection();
                setState(() {
                  if (active) {
                    _selectedStatuses.remove(status);
                  } else {
                    _selectedStatuses.add(status);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                    horizontal: r.spacingM, vertical: r.spacingXS),
                decoration: BoxDecoration(
                  color: active
                      ? c.withValues(alpha: 0.15)
                      : AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? c.withValues(alpha: 0.3)
                        : AppTheme.border(context),
                    width: 0.5,
                  ),
                ),
                child: Text(_sLabel(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: r.fontSizeXS,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? c
                            : AppTheme.textSecondary(context))),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Date Range',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: r.fontSizeS,
                fontWeight: FontWeight.w600,
                color: AppTheme.text(context))),
        SizedBox(height: r.spacingS),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDate: _dateFrom ?? DateTime.now(),
                  );
                  if (picked != null) setState(() => _dateFrom = picked);
                },
                child: _dateChip(
                    _dateFrom != null ? _fmtDate.format(_dateFrom!) : 'From',
                    _dateFrom == null,
                    r),
              ),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: _dateFrom ?? DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDate: _dateTo ?? DateTime.now(),
                  );
                  if (picked != null) setState(() => _dateTo = picked);
                },
                child: _dateChip(
                    _dateTo != null ? _fmtDate.format(_dateTo!) : 'To',
                    _dateTo == null,
                    r),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dateChip(String text, bool placeholder, Responsive r) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.spacingM, vertical: r.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded,
              size: r.iconS * 0.7,
              color: placeholder
                  ? AppTheme.textSecondary(context)
                  : AppTheme.accentTeal),
          SizedBox(width: r.spacingXS),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: r.fontSizeXS,
                    fontWeight: FontWeight.w600,
                    color: placeholder
                        ? AppTheme.textSecondary(context)
                        : AppTheme.text(context))),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSearch(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Student',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: r.fontSizeS,
                fontWeight: FontWeight.w600,
                color: AppTheme.text(context))),
        SizedBox(height: r.spacingS),
        TextField(
          controller: _studentCtrl,
          style: GoogleFonts.inter(
              color: AppTheme.text(context), fontSize: r.fontSizeS),
          maxLines: 1,
          decoration: InputDecoration(
            hintText: 'Search by name or roll number...',
            hintStyle: GoogleFonts.inter(
                color: AppTheme.textSecondary(context)
                    .withValues(alpha: 0.5),
                fontSize: r.fontSizeS),
            prefixIcon: Icon(Icons.person_search_rounded,
                color: AppTheme.textSecondary(context),
                size: r.iconM),
            filled: true,
            fillColor: AppTheme.surface(context),
            contentPadding: EdgeInsets.symmetric(
                horizontal: r.spacingM, vertical: r.spacingS),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
