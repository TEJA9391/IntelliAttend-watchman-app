import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/export_report.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/export_reports_repository.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/export_reports_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Utils/responsive.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/Components/custom_app_bar.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class ExportReportsScreen extends StatefulWidget {
  const ExportReportsScreen({super.key});

  @override
  State<ExportReportsScreen> createState() => _ExportReportsScreenState();
}

class _ExportReportsScreenState extends State<ExportReportsScreen> {
  late final ExportReportsController _controller;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  ReportType? _generateType;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = ExportReportsController(ExportReportsRepository());
    _controller.addListener(_onControllerUpdate);
    _controller.loadReports();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_onControllerUpdate);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted && !_disposed) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: CustomAppBar(
        title: "Export Reports",
        subtitle: "Generate & manage reports",
        actions: [
          GestureDetector(
            onTap: () => _controller.refresh(),
            child: Container(
              margin: const EdgeInsets.only(right: 20),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: AppTheme.accentTeal, size: 20),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _controller.isLoading && _controller.reports.isEmpty
            ? _buildShimmerLoading(responsive)
            : _controller.error != null && _controller.reports.isEmpty
                ? _buildErrorState(responsive)
                : RefreshIndicator(
                    onRefresh: () => _controller.refresh(),
                    color: AppTheme.accentTeal,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.paddingM,
                            vertical: responsive.spacingS,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildGenerateSection(responsive),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.paddingM,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildRecentHeader(responsive),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: responsive.paddingM,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _buildSearchBar(responsive),
                          ),
                        ),
                        if (_controller.reports.isEmpty && !_controller.isLoading)
                          SliverPadding(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.paddingM,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _buildEmptyState(responsive),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.only(
                              top: responsive.spacingS,
                              bottom: responsive.hp(10),
                            ),
                            sliver: SliverList.builder(
                              itemCount: _filteredReports.length +
                                  (_controller.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _filteredReports.length) {
                                  return _buildLoadingMoreIndicator(responsive);
                                }
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: responsive.paddingM,
                                    vertical: responsive.spacingXS,
                                  ),
                                  child: _buildReportCard(
                                    _filteredReports[index],
                                    responsive,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  List<ExportReport> get _filteredReports {
    if (_searchQuery.isEmpty) return _controller.reports;
    final query = _searchQuery.toLowerCase();
    return _controller.reports.where((r) {
      return r.title.toLowerCase().contains(query) ||
          (r.courseCode?.toLowerCase().contains(query) ?? false) ||
          r.type.name.toLowerCase().contains(query) ||
          r.format.name.toLowerCase().contains(query) ||
          r.status.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildGenerateSection(Responsive responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.paddingM),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Generate Report",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.text(context),
              fontSize: responsive.fontSizeM,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsive.spacingM),
          Text(
            "Report Type",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: responsive.fontSizeS,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: responsive.spacingXS),
          _buildReportTypeGrid(responsive),
          SizedBox(height: responsive.spacingM),
          if (_generateType != null) ...[
            Text(
              "Filters",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: responsive.fontSizeS,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: responsive.spacingXS),
            _buildFilterOptions(responsive),
            SizedBox(height: responsive.spacingM),
          ],
          Text(
            "Export Format",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: responsive.fontSizeS,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: responsive.spacingXS),
          _buildFormatSelector(responsive),
          SizedBox(height: responsive.spacingM),
          _buildGenerateButton(responsive),
        ],
      ),
    );
  }

  Widget _buildReportTypeGrid(Responsive responsive) {
    final types = [
      (ReportType.attendance, Icons.how_to_reg_rounded, 'Attendance'),
      (ReportType.studentList, Icons.people_rounded, 'Student List'),
      (ReportType.sessionSummary, Icons.summarize_rounded, 'Session'),
      (ReportType.daily, Icons.today_rounded, 'Daily'),
      (ReportType.weekly, Icons.view_week_rounded, 'Weekly'),
      (ReportType.monthly, Icons.calendar_month_rounded, 'Monthly'),
      (ReportType.subject, Icons.subject_rounded, 'Subject'),
      (ReportType.department, Icons.domain_rounded, 'Department'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: responsive.spacingXS,
        crossAxisSpacing: responsive.spacingXS,
        childAspectRatio: 2.2,
      ),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final (type, icon, label) = types[index];
        final isSelected = _generateType == type;
        return GestureDetector(
          onTap: () {
            HapticService.light();
            setState(() => _generateType = isSelected ? null : type);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: responsive.spacingS,
              vertical: responsive.spacingXS,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentTeal.withValues(alpha: 0.15)
                  : AppTheme.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentTeal.withValues(alpha: 0.4)
                    : AppTheme.border(context),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppTheme.accentTeal
                      : AppTheme.textSecondary(context),
                  size: 18,
                ),
                SizedBox(width: responsive.spacingXS),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: isSelected
                          ? AppTheme.accentTeal
                          : AppTheme.text(context),
                      fontSize: responsive.fontSizeS * 0.9,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOptions(Responsive responsive) {
    final courses = _controller.availableCourses;
    final sections = _controller.availableSections;
    final semesters = _controller.availableSemesters;
    return Container(
      padding: EdgeInsets.all(responsive.paddingS),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDateRangeRow(responsive),
          SizedBox(height: responsive.spacingXS),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Course',
                  value: _controller.courseCode,
                  items: courses.isNotEmpty ? courses : const ['No courses found'],
                  onChanged: (v) => _controller.setCourseCode(v),
                  responsive: responsive,
                ),
              ),
              SizedBox(width: responsive.spacingXS),
              Expanded(
                child: _buildDropdown(
                  label: 'Section',
                  value: _controller.section,
                  items: sections.isNotEmpty ? sections : const ['No sections found'],
                  onChanged: (v) => _controller.setSection(v),
                  responsive: responsive,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.spacingXS),
          _buildDropdown(
            label: 'Semester',
            value: _controller.semester,
            items: semesters.isNotEmpty ? semesters : const ['No semesters found'],
            onChanged: (v) => _controller.setSemester(v),
            responsive: responsive,
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeRow(Responsive responsive) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(isFrom: true),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacingS,
                vertical: responsive.spacingXS + 2,
              ),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: AppTheme.textSecondary(context), size: 14),
                  SizedBox(width: responsive.spacingXS),
                  Flexible(
                    child: Text(
                      _controller.dateFrom != null
                          ? dateFormat.format(_controller.dateFrom!)
                          : 'From',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _controller.dateFrom != null
                            ? AppTheme.text(context)
                            : AppTheme.textSecondary(context),
                        fontSize: responsive.fontSizeS * 0.85,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: responsive.spacingXS),
        Icon(Icons.arrow_forward_rounded,
            color: AppTheme.textSecondary(context), size: 14),
        SizedBox(width: responsive.spacingXS),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickDate(isFrom: false),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.spacingS,
                vertical: responsive.spacingXS + 2,
              ),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: AppTheme.textSecondary(context), size: 14),
                  SizedBox(width: responsive.spacingXS),
                  Flexible(
                    child: Text(
                      _controller.dateTo != null
                          ? dateFormat.format(_controller.dateTo!)
                          : 'To',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _controller.dateTo != null
                            ? AppTheme.text(context)
                            : AppTheme.textSecondary(context),
                        fontSize: responsive.fontSizeS * 0.85,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Responsive responsive,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.spacingS,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: responsive.fontSizeS * 0.85,
            ),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary(context), size: 18),
          dropdownColor: AppTheme.card(context),
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: responsive.fontSizeS * 0.85,
          ),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFormatSelector(Responsive responsive) {
    return Row(
      children: [
        Expanded(
          child: _buildFormatCard(
            format: ExportFormat.pdf,
            label: 'PDF',
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFF3B82F6),
            responsive: responsive,
          ),
        ),
        SizedBox(width: responsive.spacingXS),
        Expanded(
          child: _buildFormatCard(
            format: ExportFormat.excel,
            label: 'Excel',
            icon: Icons.table_chart_rounded,
            color: const Color(0xFF22C55E),
            responsive: responsive,
          ),
        ),
        SizedBox(width: responsive.spacingXS),
        Expanded(
          child: _buildFormatCard(
            format: ExportFormat.csv,
            label: 'CSV',
            icon: Icons.code_rounded,
            color: const Color(0xFFF59E0B),
            responsive: responsive,
          ),
        ),
        SizedBox(width: responsive.spacingXS),
        Expanded(
          child: _buildFormatCard(
            format: ExportFormat.json,
            label: 'JSON',
            icon: Icons.data_object_rounded,
            color: const Color(0xFF8B5CF6),
            responsive: responsive,
          ),
        ),
      ],
    );
  }

  Widget _buildFormatCard({
    required ExportFormat format,
    required String label,
    required IconData icon,
    required Color color,
    required Responsive responsive,
  }) {
    final isSelected = _controller.selectedFormat == format;
    return GestureDetector(
      onTap: () {
        HapticService.light();
        _controller.setFormat(format);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: responsive.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : AppTheme.border(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppTheme.textSecondary(context),
              size: 20,
            ),
            SizedBox(height: responsive.spacingXS),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: isSelected ? color : AppTheme.text(context),
                fontSize: responsive.fontSizeS * 0.85,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(Responsive responsive) {
    final canGenerate = _generateType != null;
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: canGenerate && !_controller.isGenerating
              ? _handleGenerate
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentTeal,
            foregroundColor: Colors.black,
            disabledBackgroundColor: AppTheme.accentTeal.withValues(alpha: 0.3),
            disabledForegroundColor: Colors.black.withValues(alpha: 0.3),
            padding: EdgeInsets.symmetric(vertical: responsive.spacingS + 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _controller.isGenerating
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    SizedBox(width: responsive.spacingS),
                    Flexible(
                      child: Text(
                        "Generating...",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: responsive.fontSizeS,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                        "Generate Report",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: responsive.fontSizeS,
                        ),
                      ),
        ),
      ),
    );
  }

  Widget _buildRecentHeader(Responsive responsive) {
    return Padding(
      padding: EdgeInsets.only(
        top: responsive.spacingL,
        bottom: responsive.spacingXS,
      ),
      child: Row(
        children: [
          Text(
            "Recent Reports",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.text(context),
              fontSize: responsive.fontSizeM,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "${_controller.reports.length}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.accentTeal,
                fontSize: responsive.fontSizeS * 0.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Responsive responsive) {
    return Container(
      margin: EdgeInsets.only(bottom: responsive.spacingXS),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        maxLines: 1,
        style: GoogleFonts.inter(
          color: AppTheme.text(context),
          fontSize: responsive.fontSizeS,
        ),
        decoration: InputDecoration(
          hintText: 'Search reports...',
          hintStyle: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: responsive.fontSizeS,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppTheme.textSecondary(context), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary(context), size: 18),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: responsive.paddingM,
            vertical: responsive.spacingS,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(ExportReport report, Responsive responsive) {
    return Dismissible(
      key: ValueKey(report.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: responsive.paddingM),
        margin: EdgeInsets.symmetric(vertical: responsive.spacingXS / 2),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded,
            color: AppTheme.errorRed, size: 24),
      ),
      confirmDismiss: (_) => _showDeleteDialog(report),
      child: GestureDetector(
        onLongPress: () => _showReportActions(report),
        child: Container(
          padding: EdgeInsets.all(responsive.paddingS),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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
                    child: Text(
                      report.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: responsive.fontSizeS,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.spacingXS),
                  _buildStatusBadge(report.status, responsive),
                ],
              ),
              SizedBox(height: responsive.spacingXS),
              Wrap(
                spacing: responsive.spacingXS,
                runSpacing: responsive.spacingXS / 2,
                children: [
                  _buildTypeBadge(report.type, responsive),
                  _buildFormatBadge(report.format, responsive),
                ],
              ),
              SizedBox(height: responsive.spacingXS),
              Row(
                children: [
                  Icon(Icons.access_time_rounded,
                      color: AppTheme.textSecondary(context), size: 12),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _formatDate(report.generatedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context),
                        fontSize: responsive.fontSizeS * 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.receipt_long_rounded,
                      color: AppTheme.textSecondary(context), size: 12),
                  SizedBox(width: 4),
                  Text(
                    "${report.recordCount} records",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context),
                      fontSize: responsive.fontSizeS * 0.8,
                    ),
                  ),
                  SizedBox(width: responsive.spacingS),
                  Icon(Icons.storage_rounded,
                      color: AppTheme.textSecondary(context), size: 12),
                  SizedBox(width: 4),
                  Text(
                    _formatFileSize(report.fileSizeKB),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context),
                      fontSize: responsive.fontSizeS * 0.8,
                    ),
                  ),
                ],
              ),
              SizedBox(height: responsive.spacingXS),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Download',
                      icon: Icons.download_rounded,
                      color: AppTheme.accentTeal,
                      onTap: () => _handleDownload(report),
                      responsive: responsive,
                    ),
                  ),
                  SizedBox(width: responsive.spacingXS),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Share',
                      icon: Icons.share_rounded,
                      color: const Color(0xFF60A5FA),
                      onTap: () => _handleShare(report),
                      responsive: responsive,
                    ),
                  ),
                  SizedBox(width: responsive.spacingXS),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      color: AppTheme.errorRed,
                      onTap: () => _handleDelete(report),
                      responsive: responsive,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Responsive responsive) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'completed':
        color = const Color(0xFF22C55E);
        label = 'Completed';
        break;
      case 'pending':
        color = const Color(0xFFFBBF24);
        label = 'Pending';
        break;
      case 'failed':
        color = AppTheme.errorRed;
        label = 'Failed';
        break;
      default:
        color = AppTheme.textSecondary(context);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: color,
          fontSize: responsive.fontSizeS * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(ReportType type, Responsive responsive) {
    final (color, label) = _typeBadgeData(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: color,
          fontSize: responsive.fontSizeS * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFormatBadge(ExportFormat format, Responsive responsive) {
    final (color, label) = _formatBadgeData(format);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: color,
          fontSize: responsive.fontSizeS * 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Responsive responsive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: responsive.spacingXS + 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: responsive.fontSizeS * 0.75,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Responsive responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.hp(6)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_outlined,
                size: 48,
                color: AppTheme.accentTeal.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(height: responsive.spacingL),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching reports found"
                  : "No reports generated yet",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: responsive.fontSizeM,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.spacingXS),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try a different search term"
                  : "Generate your first report using the form above",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: responsive.fontSizeS,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(Responsive responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.spacingM),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accentTeal,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(Responsive responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerBase =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final shimmerHighlight =
        isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade100;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: responsive.paddingM,
        vertical: responsive.spacingS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildShimmerBlock(shimmerBase, shimmerHighlight,
              height: 300, responsive: responsive),
          SizedBox(height: responsive.spacingL),
          _buildShimmerBlock(shimmerBase, shimmerHighlight,
              height: 44, responsive: responsive),
          SizedBox(height: responsive.spacingS),
          _buildShimmerBlock(shimmerBase, shimmerHighlight,
              height: 40, responsive: responsive),
          SizedBox(height: responsive.spacingS),
          ...List.generate(
            3,
            (_) => Padding(
              padding: EdgeInsets.only(bottom: responsive.spacingS),
              child: _buildShimmerBlock(shimmerBase, shimmerHighlight,
                  height: 140, responsive: responsive),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerBlock(
    Color base,
    Color highlight, {
    required double height,
    required Responsive responsive,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildErrorState(Responsive responsive) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(responsive.paddingL),
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
                size: 48,
                color: AppTheme.errorRed.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: responsive.spacingL),
            Text(
              "Unable to load reports",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: responsive.fontSizeM,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.spacingXS),
            Text(
              _controller.error ?? "An unexpected error occurred",
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: responsive.fontSizeS,
              ),
            ),
            SizedBox(height: responsive.spacingL),
            ElevatedButton.icon(
              onPressed: () => _controller.refresh(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                "Retry",
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentTeal,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.paddingL,
                  vertical: responsive.spacingS + 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGenerate() async {
    if (_generateType == null) return;
    HapticService.medium();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ListenableBuilder(
          listenable: _controller,
          builder: (ctx, _) => AlertDialog(
            backgroundColor: AppTheme.card(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: _controller.exportProgress > 0 ? _controller.exportProgress : null,
                    color: AppTheme.accentTeal,
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  "Generating Report...",
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _controller.exportStatusText.isNotEmpty
                      ? _controller.exportStatusText
                      : "Exporting as ${_controller.selectedFormat.name.toUpperCase()}",
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
                if (_controller.exportProgress > 0) ...[
                  SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _controller.exportProgress,
                      backgroundColor: AppTheme.border(context),
                      color: AppTheme.accentTeal,
                      minHeight: 4,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '${(_controller.exportProgress * 100).toInt()}%',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final result = await _controller.generateReport(
      type: _generateType!,
      format: _controller.selectedFormat,
      dateFrom: _controller.dateFrom,
      dateTo: _controller.dateTo,
      courseCode: _controller.courseCode,
      section: _controller.section,
      semester: _controller.semester,
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result != null
                ? "Report generated (${result.fileName ?? result.title})"
                : "Failed to generate report",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(),
          ),
          backgroundColor: result != null ? AppTheme.accentTeal : AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: result != null
              ? SnackBarAction(
                  label: 'Open',
                  textColor: Colors.black,
                  onPressed: () async {
                    try {
                      await OpenFilex.open(result.filePath!);
                    } catch (_) {}
                  },
                )
              : null,
        ),
      );
    }
  }

  Future<void> _handleDownload(ExportReport report) async {
    HapticService.light();
    try {
      if (report.filePath != null) {
        final file = await _controller.downloadReport(report.id);
        if (mounted && file != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Report saved to device",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(),
              ),
              backgroundColor: AppTheme.accentTeal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.black,
                onPressed: () async {
                  try {
                    await OpenFilex.open(file);
                  } catch (_) {}
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Download failed: $e", style: GoogleFonts.inter()),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleShare(ExportReport report) async {
    HapticService.light();
    try {
      await _controller.shareReport(report.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Share failed: $e", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter()),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleOpen(ExportReport report) async {
    HapticService.light();
    try {
      await _controller.openReport(report.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Open failed: $e", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter()),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handlePrint(ExportReport report) async {
    HapticService.light();
    try {
      await _controller.printReport(report.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Print failed: $e", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter()),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleDelete(ExportReport report) {
    _showDeleteDialog(report);
  }

  Future<bool?> _showDeleteDialog(ExportReport report) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Delete Report",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Are you sure you want to delete \"${report.title}\"? This action cannot be undone.",
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "Cancel",
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await _controller.deleteReport(report.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Report deleted", style: GoogleFonts.inter()),
                    backgroundColor: AppTheme.errorRed,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: Text(
              "Delete",
              style: GoogleFonts.inter(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportActions(ExportReport report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.text(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              report.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: Responsive.of(context).spacingM),
            _buildActionSheetItem(
              icon: Icons.open_in_new_rounded,
              label: 'Open',
              color: AppTheme.accentTeal,
              onTap: () {
                Navigator.pop(ctx);
                _handleOpen(report);
              },
            ),
            SizedBox(height: Responsive.of(context).spacingXS),
            _buildActionSheetItem(
              icon: Icons.download_rounded,
              label: 'Download',
              color: AppTheme.accentTeal,
              onTap: () {
                Navigator.pop(ctx);
                _handleDownload(report);
              },
            ),
            SizedBox(height: Responsive.of(context).spacingXS),
            _buildActionSheetItem(
              icon: Icons.share_rounded,
              label: 'Share',
              color: const Color(0xFF60A5FA),
              onTap: () {
                Navigator.pop(ctx);
                _handleShare(report);
              },
            ),
            if (report.format == ExportFormat.pdf) ...[
              SizedBox(height: Responsive.of(context).spacingXS),
              _buildActionSheetItem(
                icon: Icons.print_rounded,
                label: 'Print',
                color: const Color(0xFFF97316),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePrint(report);
                },
              ),
            ],
            SizedBox(height: Responsive.of(context).spacingXS),
            _buildActionSheetItem(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppTheme.errorRed,
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteDialog(report);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSheetItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_controller.dateFrom ?? now.subtract(const Duration(days: 30)))
        : (_controller.dateTo ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.accentTeal,
              onPrimary: Colors.black,
              surface: AppTheme.card(context),
              onSurface: AppTheme.text(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (isFrom) {
        _controller.setDateRange(picked, _controller.dateTo);
      } else {
        _controller.setDateRange(_controller.dateFrom, picked);
      }
    }
  }

  (Color, String) _typeBadgeData(ReportType type) {
    switch (type) {
      case ReportType.attendance:
        return (const Color(0xFF60A5FA), 'Attendance');
      case ReportType.studentList:
        return (const Color(0xFFA78BFA), 'Student List');
      case ReportType.sessionSummary:
        return (const Color(0xFF2DD4BF), 'Session');
      case ReportType.daily:
        return (const Color(0xFFFBBF24), 'Daily');
      case ReportType.weekly:
        return (const Color(0xFFF97316), 'Weekly');
      case ReportType.monthly:
        return (const Color(0xFFEC4899), 'Monthly');
      case ReportType.subject:
        return (const Color(0xFF14B8A6), 'Subject');
      case ReportType.department:
        return (const Color(0xFF8B5CF6), 'Department');
    }
  }

  (Color, String) _formatBadgeData(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return (const Color(0xFF3B82F6), 'PDF');
      case ExportFormat.excel:
        return (const Color(0xFF22C55E), 'Excel');
      case ExportFormat.csv:
        return (const Color(0xFFF59E0B), 'CSV');
      case ExportFormat.json:
        return (const Color(0xFF8B5CF6), 'JSON');
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatFileSize(double kb) {
    if (kb < 1024) return "${kb.toStringAsFixed(1)} KB";
    return "${(kb / 1024).toStringAsFixed(1)} MB";
  }
}
