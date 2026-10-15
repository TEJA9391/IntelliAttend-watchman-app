import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/course_topic.dart';
import 'package:intelli_attend_faculty/Core/utils/topic_completion_store.dart';

class CourseTopicsScreen extends StatefulWidget {
  final ScheduledClass scheduledClass;
  final int initialTopicIndex;

  const CourseTopicsScreen({
    Key? key,
    required this.scheduledClass,
    this.initialTopicIndex = -1,
  }) : super(key: key);

  @override
  State<CourseTopicsScreen> createState() => _CourseTopicsScreenState();
}

class _CourseTopicsScreenState extends State<CourseTopicsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late TextEditingController _searchController;
  String _searchQuery = '';
  int _selectedFilter = 0;
  bool _isSearchOpen = false;
  final List<bool> _expandedUnits = [];
  Timer? _searchDebounce;
  final ScrollController _scrollController = ScrollController();
  int _highlightedTopicIndex = -1;
  Timer? _highlightTimer;
  static const _filterLabels = ['All', 'Completed', 'In Progress', 'Pending'];

  String get _sessionId => widget.scheduledClass.id;

  bool _isTopicCompleted(CourseTopic topic) =>
      topic.isCompleted || TopicCompletionStore.isCompleted(_sessionId, topic.name);

  void _toggleTopic(CourseTopic topic) {
    HapticService.selection();
    TopicCompletionStore.toggle(_sessionId, topic.name);
    setState(() {});
  }

  List<_SyllabusUnit> get _units {
    final topics = widget.scheduledClass.topics;
    if (topics.isEmpty) return const [];
    final int unitCount = 5;
    final int topicsPerUnit = (topics.length / unitCount).ceil();
    final units = <_SyllabusUnit>[];
    for (int i = 0; i < unitCount; i++) {
      final start = i * topicsPerUnit;
      final end = (start + topicsPerUnit).clamp(0, topics.length);
      if (start >= topics.length) break;
      final unitTopics = topics.sublist(start, end);
      units.add(_SyllabusUnit(
        title: 'Unit ${i + 1}',
        topics: unitTopics,
      ));
    }
    return units;
  }

  List<CourseTopic> get _filteredTopics {
    var topics = widget.scheduledClass.topics.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      topics = topics.where((t) => t.name.toLowerCase().contains(q)).toList();
    }
    switch (_selectedFilter) {
      case 1:
        topics = topics.where((t) => _isTopicCompleted(t)).toList();
        break;
      case 2:
        topics = topics.where((t) => !_isTopicCompleted(t) && t.completedCount > 0).toList();
        break;
      case 3:
        topics = topics.where((t) => !_isTopicCompleted(t) && t.completedCount == 0).toList();
        break;
    }
    return topics;
  }

  int get _totalCount => widget.scheduledClass.topics.length;
  int get _completedCount => widget.scheduledClass.topics.where((t) => _isTopicCompleted(t)).length;
  int get _inProgressCount =>
      widget.scheduledClass.topics.where((t) => !_isTopicCompleted(t) && t.completedCount > 0).length;
  double get _progressPct => _totalCount > 0 ? _completedCount / _totalCount : 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();
    _searchController = TextEditingController();
    final units = _units;
    _expandedUnits.addAll(List.filled(units.length, false));

    final initialIdx = widget.initialTopicIndex;
    if (initialIdx >= 0 && initialIdx < widget.scheduledClass.topics.length) {
      final unitIdx = _getUnitIndexForTopic(initialIdx);
      if (unitIdx >= 0 && unitIdx < _expandedUnits.length) {
        _expandedUnits[unitIdx] = true;
      }
      _highlightedTopicIndex = initialIdx;
      _highlightTimer = Timer(const Duration(milliseconds: 2000), () {
        if (mounted) setState(() => _highlightedTopicIndex = -1);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToTopicIndex(initialIdx);
      });
    } else if (units.isNotEmpty) {
      _expandedUnits[0] = true;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    HapticService.light();
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (!_isSearchOpen) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  int _getUnitIndexForTopic(int topicIndex) {
    final topics = widget.scheduledClass.topics;
    if (topics.isEmpty) return -1;
    final int unitCount = 5;
    final int topicsPerUnit = (topics.length / unitCount).ceil();
    return (topicIndex / topicsPerUnit).floor().clamp(0, unitCount - 1);
  }

  void _scrollToTopicIndex(int topicIndex) {
    final units = _units;
    if (units.isEmpty) return;
    final unitIdx = _getUnitIndexForTopic(topicIndex);
    if (unitIdx < 0 || unitIdx >= units.length) return;

    final topicsBeforeUnit = units.take(unitIdx).fold<int>(0, (sum, u) => sum + u.topics.length);
    final localIndex = topicIndex - topicsBeforeUnit;

    double offset = 0;
    for (int i = 0; i < unitIdx; i++) {
      offset += 72;
      if (_expandedUnits.length > i && _expandedUnits[i]) {
        offset += units[i].topics.length * 56.0;
      }
    }
    offset += 72;
    offset += localIndex * 56.0;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final subjectName = widget.scheduledClass.subjectCode;

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
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppTheme.text(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subjectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppTheme.text(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        "Today's Topics",
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _toggleSearch,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isSearchOpen
                          ? AppTheme.accentTeal.withOpacity(0.15)
                          : AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                      size: 18,
                      color: _isSearchOpen
                          ? AppTheme.accentTeal
                          : AppTheme.text(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSearchOpen) _buildSearchBar(context),
          _buildProgressOverview(context),
          _buildFilterChips(context),
          Expanded(
            child: _searchQuery.isNotEmpty || _selectedFilter != 0
                ? _buildFilteredTopicList(context)
                : _buildUnitList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: (val) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 200), () {});
            setState(() => _searchQuery = val);
          },
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Search topics...',
            hintStyle: GoogleFonts.inter(
              color: AppTheme.textSecondary(context).withOpacity(0.5),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppTheme.textSecondary(context),
              size: 18,
            ),
            filled: true,
            fillColor: AppTheme.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.border(context),
                width: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOverview(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final pctText = (_progressPct * 100).round();

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.border(context),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_rounded,
                      size: 18, color: AppTheme.accentTeal),
                  const SizedBox(width: 8),
                  Text(
                    'Overall Progress',
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$pctText%',
                    style: GoogleFonts.inter(
                      color: AppTheme.accentTeal,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: LinearProgressIndicator(
                    value: _progressPct * _animController.value,
                    backgroundColor:
                        AppTheme.textSecondary(context).withOpacity(0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF84CC16)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$_completedCount / $_totalCount Topics Completed',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _filterLabels.length,
        itemBuilder: (context, index) {
          final isActive = _selectedFilter == index;
          return GestureDetector(
            onTap: () {
              HapticService.selection();
              setState(() => _selectedFilter = index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.accentTeal.withOpacity(0.15)
                    : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? AppTheme.accentTeal.withOpacity(0.3)
                      : AppTheme.border(context),
                  width: 0.5,
                ),
              ),
              child: Text(
                _filterLabels[index],
                style: GoogleFonts.inter(
                  color: isActive
                      ? AppTheme.accentTeal
                      : AppTheme.textSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredTopicList(BuildContext context) {
    final filtered = _filteredTopics;
    if (filtered.isEmpty) {
      return _buildEmptyState(context, 'No topics match your search');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final topic = filtered[index];
        final globalIdx = widget.scheduledClass.topics.indexOf(topic);
        return _buildTopicItem(context, topic, index, filtered.length, globalIndex: globalIdx);
      },
    );
  }

  Widget _buildUnitList(BuildContext context) {
    final units = _units;
    if (units.isEmpty) {
      return _buildEmptyState(context, 'Topics have not been added yet');
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: units.length,
      itemBuilder: (context, index) {
        return _buildUnitTile(context, units[index], index);
      },
    );
  }

  Widget _buildUnitTile(
      BuildContext context, _SyllabusUnit unit, int unitIndex) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpanded = _expandedUnits.length > unitIndex
        ? _expandedUnits[unitIndex]
        : false;
    final unitCompleted =
        unit.topics.where((t) => _isTopicCompleted(t)).length;
    final unitTotal = unit.topics.length;
    final unitPct = unitTotal > 0 ? (unitCompleted / unitTotal * 100).round() : 0;
    final allDone = unitCompleted == unitTotal && unitTotal > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? AppTheme.accentTeal.withOpacity(0.2)
              : AppTheme.border(context),
          width: isExpanded ? 1 : 0.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (val) {
            HapticService.light();
            setState(() {
              while (_expandedUnits.length <= unitIndex) {
                _expandedUnits.add(false);
              }
              _expandedUnits[unitIndex] = val;
            });
          },
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: allDone
                  ? const Color(0xFF84CC16).withOpacity(0.15)
                  : AppTheme.accentTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: allDone
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: Color(0xFF84CC16))
                  : Text(
                      '${unitIndex + 1}',
                      style: GoogleFonts.inter(
                        color: AppTheme.accentTeal,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  unit.title,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '$unitCompleted / $unitTotal Topics',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: unitTotal > 0 ? unitCompleted / unitTotal : 0,
                      backgroundColor:
                          AppTheme.textSecondary(context).withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        allDone
                            ? const Color(0xFF84CC16)
                            : AppTheme.accentTeal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$unitPct%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: Icon(
            isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: AppTheme.textSecondary(context),
            size: 20,
          ),
          children: unit.topics
              .asMap()
              .entries
              .map((entry) {
                final topicsBeforeUnit = _units.take(unitIndex).fold<int>(0, (sum, u) => sum + u.topics.length);
                final globalIdx = topicsBeforeUnit + entry.key;
                return _buildTopicItem(
                    context, entry.value, entry.key, unit.topics.length, globalIndex: globalIdx);
              })
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTopicItem(
      BuildContext context, CourseTopic topic, int index, int total, {int globalIndex = -1}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLast = index == total - 1;
    final bool isCompleted = _isTopicCompleted(topic);
    final bool isInProgress =
        !isCompleted && topic.completedCount > 0;
    final isFuture = !isCompleted && !isInProgress;

    final currentIdx = _getFirstIncompleteIndex();
    final bool isCurrent = !isCompleted && index == currentIdx;
    final bool isHighlighted = globalIndex == _highlightedTopicIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppTheme.accentTeal.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _toggleTopic(topic),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimelineConnector(
                topic, isCompleted, isCurrent, isLast, isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          topic.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: GoogleFonts.inter(
                            color: isFuture
                                ? AppTheme.textSecondary(context)
                                    .withOpacity(0.6)
                                : AppTheme.text(context),
                            fontSize: 14,
                            fontWeight: isCompleted
                                ? FontWeight.w600
                                : isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppTheme.textSecondary(context)
                                .withOpacity(0.3),
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF84CC16).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded,
                                  size: 10, color: const Color(0xFF84CC16)),
                              const SizedBox(width: 3),
                              Text(
                                'Done',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF84CC16),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isCurrent)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFBBF7D0),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'Current',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF16A34A),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (isInProgress)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'In Progress',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFF59E0B),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (topic.totalCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 13,
                            color: AppTheme.textSecondary(context)
                                .withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${topic.completedCount} / ${topic.totalCount} Students',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (!isCompleted)
                          SizedBox(
                            width: 50,
                            height: 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: topic.totalCount > 0
                                    ? topic.completedCount / topic.totalCount
                                    : 0,
                                backgroundColor: isCurrent
                                    ? const Color(0xFFE5E7EB)
                                    : AppTheme.textSecondary(context)
                                        .withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCurrent
                                      ? const Color(0xFF34D399)
                                      : isInProgress
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (isCompleted) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 12,
                            color: const Color(0xFF84CC16).withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(
                          topic.isCompleted ? 'Completed Today' : 'Marked Done',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF84CC16),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!isLast && _searchQuery.isEmpty && _selectedFilter == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        height: 0.5,
                        color: AppTheme.border(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTimelineConnector(
      CourseTopic topic, bool isCompleted, bool isCurrent, bool isLast, bool isDark) {
    return SizedBox(
      width: 28,
      child: Column(
        children: [
          if (isCurrent)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x2634D399),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34D399),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.circle, size: 8, color: Colors.white),
                ),
              )
            else
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF84CC16)
                    : AppTheme.textSecondary(context).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle,
                size: isCompleted ? 13 : 7,
                color: isCompleted
                    ? Colors.white
                    : AppTheme.textSecondary(context).withOpacity(0.4),
              ),
            ),
          if (!isLast)
            Container(
              width: 2,
              height: 24,
              color: isCompleted
                  ? const Color(0xFF84CC16).withOpacity(0.3)
                  : AppTheme.textSecondary(context).withOpacity(0.08),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: AppTheme.textSecondary(context).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getFirstIncompleteIndex() {
    final topics = widget.scheduledClass.topics;
    for (int i = 0; i < topics.length; i++) {
      if (!_isTopicCompleted(topics[i])) return i;
    }
    return 0;
  }
}

class _SyllabusUnit {
  final String title;
  final List<CourseTopic> topics;

  const _SyllabusUnit({
    required this.title,
    required this.topics,
  });
}
