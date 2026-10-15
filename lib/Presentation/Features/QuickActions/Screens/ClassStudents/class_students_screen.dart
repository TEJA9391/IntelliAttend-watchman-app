import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/class_students_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Utils/responsive.dart';
import 'package:intelli_attend_faculty/Presentation/Widgets/skeleton_loader.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'class_student_profile_screen.dart';

class ClassStudentsScreen extends StatefulWidget {
  final ClassStudentsController controller;
  final String? section;
  final String? courseCode;

  const ClassStudentsScreen({
    super.key,
    required this.controller,
    this.section,
    this.courseCode,
  });

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  String? _filterDepartment;
  String? _filterGender;
  RangeValues _attendanceRange = const RangeValues(0, 100);
  String _eligibilityFilter = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;
  String? _selectedSection;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadStudents(
        section: widget.section,
        courseCode: widget.courseCode,
      );
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.controller.search(query);
    });
  }

  bool get _hasActiveFilters =>
      _filterDepartment != null ||
      _selectedSection != null ||
      _filterGender != null ||
      _attendanceRange.start > 0 ||
      _attendanceRange.end < 100 ||
      _eligibilityFilter != 'all' ||
      _sortBy != 'name';

  List<ClassStudent> get _displayedStudents {
    List<ClassStudent> result = List.from(widget.controller.students);

    if (_filterDepartment != null && _filterDepartment!.isNotEmpty) {
      result =
          result.where((s) => s.department == _filterDepartment).toList();
    }
    if (_selectedSection != null && _selectedSection!.isNotEmpty) {
      result = result.where((s) => s.section == _selectedSection).toList();
    }
    if (_filterGender != null && _filterGender!.isNotEmpty) {
      result = result.where((s) => s.gender == _filterGender).toList();
    }
    result = result
        .where((s) =>
            s.attendancePercentage >= _attendanceRange.start &&
            s.attendancePercentage <= _attendanceRange.end)
        .toList();
    if (_eligibilityFilter == 'eligible') {
      result = result.where((s) => s.isEligible).toList();
    } else if (_eligibilityFilter == 'defaulter') {
      result = result.where((s) => s.isDefaulter).toList();
    }

    result.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'roll':
          cmp = a.rollNumber.compareTo(b.rollNumber);
          break;
        case 'attendance':
          cmp = a.attendancePercentage.compareTo(b.attendancePercentage);
          break;
        case 'department':
          cmp = (a.department ?? '').compareTo(b.department ?? '');
          break;
        default:
          cmp = a.name.compareTo(b.name);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final controller = widget.controller;
    final displayed = _displayedStudents;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: _buildAppBar(responsive, controller, displayed.length),
      body: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchBar(responsive),
            _buildSectionChips(),
            if (_hasActiveFilters)
              _buildActiveFilterChips(controller),
            Expanded(
              child: controller.isLoading
                  ? _buildLoadingSkeleton(responsive)
                  : displayed.isEmpty
                      ? _buildEmptyState(controller.searchQuery)
                      : _buildStudentList(responsive, displayed),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    Responsive responsive,
    ClassStudentsController controller,
    int displayedCount,
  ) {
    return AppBar(
      backgroundColor: AppTheme.bg(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.maybePop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: AppTheme.text(context)),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              'Students',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.text(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$displayedCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentTeal,
              ),
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () {
            HapticService.light();
            _showFilterSheet(context);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hasActiveFilters
                  ? AppTheme.accentTeal.withOpacity(0.15)
                  : AppTheme.surface(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hasActiveFilters
                    ? AppTheme.accentTeal.withOpacity(0.4)
                    : AppTheme.border(context),
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: _hasActiveFilters
                  ? AppTheme.accentTeal
                  : AppTheme.textSecondary(context),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticService.light();
            setState(() {
              _sortAscending = !_sortAscending;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.border(context),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sortAscending
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 14,
                  color: AppTheme.accentTeal,
                ),
                const SizedBox(width: 4),
                Text(
                  _sortAscending ? 'A→Z' : 'Z→A',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentTeal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(Responsive responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.paddingM,
        vertical: responsive.spacingS,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppTheme.text(context),
        ),
        decoration: InputDecoration(
          hintText: 'Search by name, roll number...',
          hintStyle: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppTheme.textSecondary(context), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    widget.controller.search('');
                  },
                  child: Icon(Icons.close_rounded,
                      color: AppTheme.textSecondary(context), size: 18),
                )
              : null,
          filled: true,
          fillColor: AppTheme.card(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.border(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.border(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionChips() {
    final students = widget.controller.students;
    if (students.isEmpty) return const SizedBox.shrink();

    final sections = <String>{};
    for (final s in students) {
      if (s.section != null && s.section!.isNotEmpty) sections.add(s.section!);
    }
    final sortedSections = sections.toList()..sort();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _sectionChip('All', _selectedSection == null, () {
            setState(() => _selectedSection = null);
          }),
          for (final sec in sortedSections)
            _sectionChip(_shortSection(sec), _selectedSection == sec, () {
              setState(() => _selectedSection = sec);
            }),
        ],
      ),
    );
  }

  String _shortSection(String sectionId) {
    final upper = sectionId.toUpperCase();
    final aimlMatch = RegExp(r'AIML[_-]?([A-E])').firstMatch(upper);
    if (aimlMatch != null) return 'AIML-${aimlMatch.group(1)}';
    final secMatch = RegExp(r'SEC[_-]?([A-E])').firstMatch(upper);
    if (secMatch != null) return 'Sec ${secMatch.group(1)}';
    final letterMatch = RegExp(r'_([A-E])_').firstMatch(upper);
    if (letterMatch != null) return 'Sec ${letterMatch.group(1)}';
    return sectionId;
  }

  Widget _sectionChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentTeal.withOpacity(0.15)
              : AppTheme.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentTeal
                : AppTheme.border(context),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppTheme.accentTeal
                  : AppTheme.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChips(ClassStudentsController controller) {
    final chips = <Widget>[];

    if (_filterDepartment != null && _filterDepartment!.isNotEmpty) {
      chips.add(_filterChip('Dept: $_filterDepartment', () {
        setState(() => _filterDepartment = null);
      }));
    }
    if (_selectedSection != null && _selectedSection!.isNotEmpty) {
      chips.add(_filterChip('Sec: $_selectedSection', () {
        setState(() => _selectedSection = null);
      }));
    }
    if (_filterGender != null && _filterGender!.isNotEmpty) {
      chips.add(_filterChip('Gender: $_filterGender', () {
        setState(() => _filterGender = null);
      }));
    }
    if (_attendanceRange.start > 0 || _attendanceRange.end < 100) {
      chips.add(_filterChip(
          'Attendance: ${_attendanceRange.start.toInt()}–${_attendanceRange.end.toInt()}%', () {
        setState(() =>
            _attendanceRange = const RangeValues(0, 100));
      }));
    }
    if (_eligibilityFilter != 'all') {
      chips.add(_filterChip('Eligibility: $_eligibilityFilter', () {
        setState(() => _eligibilityFilter = 'all');
      }));
    }
    if (_sortBy != 'name') {
      chips.add(_filterChip('Sort: $_sortBy', () {
        setState(() => _sortBy = 'name');
      }));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => chips[index],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentTeal.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentTeal.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentTeal,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: AppTheme.accentTeal),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(Responsive responsive, List<ClassStudent> students) {
    return RefreshIndicator(
      color: AppTheme.accentTeal,
      backgroundColor: AppTheme.card(context),
      onRefresh: () => widget.controller.refresh(),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: responsive.paddingM,
          vertical: responsive.spacingS,
        ),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: students.length,
        itemBuilder: (context, index) => _buildStudentCard(responsive, students[index]),
      ),
    );
  }

  Widget _buildStudentCard(Responsive responsive, ClassStudent student) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticService.light();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassStudentProfileScreen(student: student),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Hero(
                  tag: 'student-avatar-${student.id}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'student-name-${student.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student.rollNumber}${student.department != null ? '  ·  ${student.department}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.jetBrainsMono(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(Responsive responsive) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: responsive.paddingM,
        vertical: responsive.spacingS,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SkeletonLoader(
                    width: 48,
                    height: 48,
                    borderRadius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(
                          width: responsive.wp(35),
                          height: 14,
                          borderRadius: 7,
                        ),
                        const SizedBox(height: 6),
                        SkeletonLoader(
                          width: responsive.wp(50),
                          height: 10,
                          borderRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  SkeletonLoader(
                    width: 56,
                    height: 22,
                    borderRadius: 6,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SkeletonLoader(
                    width: 40,
                    height: 12,
                    borderRadius: 6,
                  ),
                  const SizedBox(width: 6),
                  SkeletonLoader(
                    width: 32,
                    height: 12,
                    borderRadius: 6,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SkeletonLoader(
                width: double.infinity,
                height: 4,
                borderRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String searchQuery) {
    final isSearch = searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
                size: 36,
                color: AppTheme.accentTeal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearch ? 'No students match your search' : 'No students found',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.text(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Try adjusting your search or filters'
                  : 'Students will appear here once loaded',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
              ),
            ),
            if (!isSearch) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => widget.controller.refresh(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Retry',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final responsive = Responsive.of(context);
    String tempDepartment = _filterDepartment ?? '';
    String tempSection = _selectedSection ?? '';
    String tempGender = _filterGender ?? '';
    RangeValues tempAttendanceRange = _attendanceRange;
    String tempEligibility = _eligibilityFilter;
    String tempSortBy = _sortBy;

    final departments = <String>{};
    final sections = <String>{};
    for (final s in widget.controller.students) {
      if (s.department != null && s.department!.isNotEmpty) {
        departments.add(s.department!);
      }
      if (s.section != null && s.section!.isNotEmpty) {
        sections.add(s.section!);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: AppTheme.card(ctx),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary(ctx)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Filter & Sort',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.text(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filterSectionTitle(ctx, 'Department'),
                            const SizedBox(height: 8),
                            _buildFilterDropdown(
                              ctx,
                              tempDepartment.isEmpty
                                  ? 'All'
                                  : tempDepartment,
                              ['All', ...departments.toList()],
                              (val) {
                                setSheetState(() {
                                  tempDepartment =
                                      val == 'All' ? '' : val;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            _filterSectionTitle(ctx, 'Section'),
                            const SizedBox(height: 8),
                            _buildFilterDropdown(
                              ctx,
                              tempSection.isEmpty ? 'All' : tempSection,
                              ['All', ...sections.toList()],
                              (val) {
                                setSheetState(() {
                                  tempSection = val == 'All' ? '' : val;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            _filterSectionTitle(ctx, 'Gender'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildGenderChip(
                                    ctx, 'All', tempGender, setSheetState,
                                    (v) => tempGender = ''),
                                const SizedBox(width: 8),
                                _buildGenderChip(
                                    ctx, 'Male', tempGender, setSheetState,
                                    (v) => tempGender = v),
                                const SizedBox(width: 8),
                                _buildGenderChip(
                                    ctx, 'Female', tempGender, setSheetState,
                                    (v) => tempGender = v),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _filterSectionTitle(ctx, 'Attendance Range'),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${tempAttendanceRange.start.toInt()}%',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary(ctx),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: RangeSlider(
                                    values: tempAttendanceRange,
                                    min: 0,
                                    max: 100,
                                    divisions: 20,
                                    activeColor: AppTheme.accentTeal,
                                    inactiveColor: AppTheme.textSecondary(ctx)
                                        .withOpacity(0.1),
                                    onChanged: (val) {
                                      setSheetState(() {
                                        tempAttendanceRange = val;
                                      });
                                    },
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '${tempAttendanceRange.end.toInt()}%',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary(ctx),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _filterSectionTitle(ctx, 'Eligibility'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildEligibilityChip(
                                    ctx, 'All', tempEligibility, setSheetState,
                                    (v) => tempEligibility = v),
                                const SizedBox(width: 8),
                                _buildEligibilityChip(ctx, 'Eligible',
                                    tempEligibility, setSheetState,
                                    (v) => tempEligibility = v),
                                const SizedBox(width: 8),
                                _buildEligibilityChip(ctx, 'Defaulter',
                                    tempEligibility, setSheetState,
                                    (v) => tempEligibility = v),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _filterSectionTitle(ctx, 'Sort By'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildSortChip(ctx, 'Name', 'name',
                                    tempSortBy, setSheetState,
                                    (v) => tempSortBy = v),
                                _buildSortChip(ctx, 'Roll No', 'roll',
                                    tempSortBy, setSheetState,
                                    (v) => tempSortBy = v),
                                _buildSortChip(ctx, 'Attendance', 'attendance',
                                    tempSortBy, setSheetState,
                                    (v) => tempSortBy = v),
                                _buildSortChip(ctx, 'Department', 'department',
                                    tempSortBy, setSheetState,
                                    (v) => tempSortBy = v),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          24,
                          8,
                          24,
                          MediaQuery.of(ctx).padding.bottom + 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  tempDepartment = '';
                                  tempSection = '';
                                  tempGender = '';
                                  tempAttendanceRange =
                                      const RangeValues(0, 100);
                                  tempEligibility = 'all';
                                  tempSortBy = 'name';
                                });
                                setState(() {
                                  _filterDepartment = null;
                                  _selectedSection = null;
                                  _filterGender = null;
                                  _attendanceRange =
                                      const RangeValues(0, 100);
                                  _eligibilityFilter = 'all';
                                  _sortBy = 'name';
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                    color: AppTheme.border(ctx)),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Clear All',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color:
                                      AppTheme.textSecondary(ctx),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _filterDepartment =
                                      tempDepartment.isEmpty
                                          ? null
                                          : tempDepartment;
                                  _selectedSection = tempSection.isEmpty
                                      ? null
                                      : tempSection;
                                  _filterGender = tempGender.isEmpty
                                      ? null
                                      : tempGender;
                                  _attendanceRange = tempAttendanceRange;
                                  _eligibilityFilter = tempEligibility;
                                  _sortBy = tempSortBy;
                                });
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentTeal,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(
                                'Apply Filters',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
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
      },
    );
  }

  Widget _filterSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary(context),
      ),
    );
  }

  Widget _buildFilterDropdown(
    BuildContext context,
    String currentValue,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: DropdownButton<String>(
        value: items.contains(currentValue) ? currentValue : items.first,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppTheme.card(context),
        icon: Icon(Icons.keyboard_arrow_down_rounded,
            color: AppTheme.textSecondary(context), size: 20),
        style: GoogleFonts.inter(
          fontSize: 14,
          color: AppTheme.text(context),
        ),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.text(context),
                    ),
                  ),
                ))
            .toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }

  Widget _buildGenderChip(
    BuildContext context,
    String label,
    String currentValue,
    StateSetter setSheetState,
    ValueChanged<String> onSelected,
  ) {
    final isSelected =
        (label == 'All' && currentValue.isEmpty) || currentValue == label;
    return GestureDetector(
      onTap: () {
        setSheetState(() => onSelected(label));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentTeal.withOpacity(0.15)
              : AppTheme.bg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentTeal.withOpacity(0.4)
                : AppTheme.border(context),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildEligibilityChip(
    BuildContext context,
    String label,
    String currentValue,
    StateSetter setSheetState,
    ValueChanged<String> onSelected,
  ) {
    final selectedValue = label.toLowerCase();
    final isSelected = currentValue == selectedValue;
    return GestureDetector(
      onTap: () {
        setSheetState(() => onSelected(selectedValue));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentTeal.withOpacity(0.15)
              : AppTheme.bg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentTeal.withOpacity(0.4)
                : AppTheme.border(context),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppTheme.accentTeal
                : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(
    BuildContext context,
    String label,
    String value,
    String currentValue,
    StateSetter setSheetState,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () {
        setSheetState(() => onSelected(value));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentTeal.withOpacity(0.15)
              : AppTheme.bg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentTeal.withOpacity(0.4)
                : AppTheme.border(context),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppTheme.accentTeal
                : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
