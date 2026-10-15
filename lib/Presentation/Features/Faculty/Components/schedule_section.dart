import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_controller.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/course_topic.dart';
import 'package:intelli_attend_faculty/Core/utils/topic_completion_store.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/course_topics_screen.dart';
import 'package:intelli_attend_faculty/Services/time_sync_service.dart';
import 'package:intelli_attend_faculty/Presentation/Widgets/skeleton_loader.dart';

class ScheduleSection extends StatefulWidget {
  final VoidCallback onViewAll;
  final Function(ScheduledClass)? onCourseTap;

  const ScheduleSection({
    Key? key,
    required this.onViewAll,
    this.onCourseTap,
  }) : super(key: key);

  @override
  State<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<ScheduleSection> {
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  int _lastFocusIdx = -1;

  @override
  void initState() {
    super.initState();
    final view =
        WidgetsBinding.instance.platformDispatcher.views.first;
    final screenWidth =
        view.physicalSize.width / view.devicePixelRatio;
    final viewportFraction = 390.0 / screenWidth;
    _pageController = PageController(
      viewportFraction: viewportFraction.clamp(0.78, 0.92),
    );
    _autoScrollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _autoScroll(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScroll());
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _autoScroll() {
    if (!mounted) return;
    final controller = context.read<DashboardController>();
    if (controller.displayShimmer) return;
    final classes = controller.scheduledClasses;
    if (classes.isEmpty) return;
    final focusIdx = _focusIndex(classes);
    if (focusIdx < 0 || focusIdx == _lastFocusIdx) return;
    _lastFocusIdx = focusIdx;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        focusIdx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  int _focusIndex(List<ScheduledClass> classes) {
    final nowMs = TimeSyncService.syncedNowMs;
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true)
        .toLocal();
    final currentMinutes = now.hour * 60 + now.minute;

    for (int i = 0; i < classes.length; i++) {
      final slot = classes[i]
          .toTimetableSlot(institutionTimezone: 'Asia/Kolkata');
      if (currentMinutes >= slot.startMinutes &&
          currentMinutes < slot.endMinutes) {
        return i;
      }
    }

    for (int i = 0; i < classes.length; i++) {
      final slot = classes[i]
          .toTimetableSlot(institutionTimezone: 'Asia/Kolkata');
      if (slot.startMinutes > currentMinutes) {
        return i;
      }
    }

    return -1;
  }

  void _onPageChanged(int index) {
    if (_currentPage != index) {
      HapticService.selection();
      setState(() => _currentPage = index);
    }
  }

  double _containerHeight(BuildContext context, List<ScheduledClass> schedules) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final baseHeight = 300.0;
    final extraHeight = (textScale - 1.0) * 40;
    return (baseHeight + extraHeight).clamp(300.0, 380.0);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final todaySchedules = controller.scheduledClasses;
    final tomorrowSchedules = controller.tomorrowSchedule;

    final bool showTomorrow =
        todaySchedules.isEmpty && tomorrowSchedules.isNotEmpty;
    final schedules = showTomorrow ? tomorrowSchedules : todaySchedules;
    final String titleText =
        showTomorrow ? "Tomorrow's Schedule" : "Today's Schedule";
    final focusIdx = (schedules.isNotEmpty && !showTomorrow)
        ? _focusIndex(schedules)
        : -1;

    if (focusIdx >= 0 && _currentPage == 0 && schedules.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _currentPage = focusIdx;
          _pageController.jumpToPage(focusIdx);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: widget.onViewAll,
                child: Text(
                  "See All",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.accentTeal,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (controller.displayShimmer)
          _buildShimmerSchedule(context)
        else if (schedules.isEmpty && !controller.isLoading)
          _buildEmptyState(context)
        else
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _containerHeight(context, schedules),
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: schedules.length,
                  onPageChanged: _onPageChanged,
                  padEnds: true,
                  clipBehavior: Clip.none,
                  itemBuilder: (context, index) {
                    final sc = schedules[index];
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double page = 0;
                        if (_pageController.hasClients &&
                            _pageController
                                .position.hasContentDimensions) {
                          page = _pageController.page ?? 0;
                        }
                        final distance =
                            (page - index).abs().clamp(0.0, 2.0);
                        final scale =
                            1.0 - (distance * 0.05);
                        final opacity =
                            1.0 - (distance * 0.2);
                        final slideY = distance * 4.0;
                        return Transform.translate(
                          offset: Offset(0, slideY),
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity.clamp(0.4, 1.0),
                              child: _ScheduleCardWidget(
                                scheduledClass: sc,
                                isHighlighted: index == focusIdx,
                                isActive: index == _currentPage,
                                dashboardController: controller,
                                onTap: () {
                                  HapticService.heavy();
                                  widget.onCourseTap?.call(sc);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (schedules.length > 1) ...[
                const SizedBox(height: 8),
                _buildPageIndicator(schedules.length),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildPageIndicator(int count) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, _) {
        double page = 0;
        if (_pageController.hasClients &&
            _pageController.position.hasContentDimensions) {
          page = _pageController.page ?? 0;
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final distance = (page - i).abs().clamp(0.0, 1.0);
            final isActive = distance < 0.5;
            final size = lerpDouble(8, 5, distance)!;
            final color = isActive
                ? AppTheme.accentTeal
                : AppTheme.textSecondary(context)
                    .withOpacity(0.3);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(size / 2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildShimmerSchedule(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final shimmerHeight = (320.0 + (textScale - 1.0) * 40).clamp(320.0, 430.0);
    return SizedBox(
      height: shimmerHeight,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) => _buildShimmerCard(context),
      ),
    );
  }

  Widget _buildShimmerCard(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: MediaQuery.sizeOf(context).width * 0.85,
      margin:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonLoader(
              width: double.infinity,
              height: 175,
              borderRadius: 16),
          const SizedBox(height: 16),
          SkeletonLoader(width: 200, height: 18),
          const SizedBox(height: 8),
          SkeletonLoader(width: 100, height: 18),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final height = _containerHeight(context, []);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: AppTheme.accentTeal.withOpacity(0.6),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "No Active Class",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "No class schedule for today",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCardWidget extends StatefulWidget {
  final ScheduledClass scheduledClass;
  final bool isHighlighted;
  final bool isActive;
  final DashboardController dashboardController;
  final VoidCallback? onTap;

  const _ScheduleCardWidget({
    required this.scheduledClass,
    required this.isHighlighted,
    required this.isActive,
    required this.dashboardController,
    this.onTap,
  });

  @override
  State<_ScheduleCardWidget> createState() =>
      _ScheduleCardWidgetState();
}

class _ScheduleCardWidgetState extends State<_ScheduleCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _topicAnimController;
  bool _isExpanded = false;
  final ScrollController _expandedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _topicAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.isActive &&
        widget.scheduledClass.topics.isNotEmpty) {
      _topicAnimController.forward();
      _scrollToCurrentTopic(widget.scheduledClass.topics);
    }
  }

  @override
  void didUpdateWidget(covariant _ScheduleCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive &&
        !oldWidget.isActive &&
        widget.scheduledClass.topics.isNotEmpty) {
      _topicAnimController.forward(from: 0);
    }
    if (widget.scheduledClass.id != oldWidget.scheduledClass.id ||
        widget.scheduledClass.topics != oldWidget.scheduledClass.topics) {
      _scrollToCurrentTopic(widget.scheduledClass.topics);
    }
    if (widget.scheduledClass.id != oldWidget.scheduledClass.id ||
        widget.scheduledClass.topics != oldWidget.scheduledClass.topics) {
      _scrollToCurrentTopic(widget.scheduledClass.topics);
    }
  }

  @override
  void dispose() {
    _topicAnimController.dispose();
    _expandedScrollController.dispose();
    super.dispose();
  }

  bool _isTopicDone(CourseTopic topic) =>
      topic.isCompleted ||
      TopicCompletionStore.isCompleted(
          widget.scheduledClass.id, topic.name);

  int _getFirstIncompleteIndex(List<CourseTopic> topics) {
    for (int i = 0; i < topics.length; i++) {
      if (!_isTopicDone(topics[i])) return i;
    }
    return topics.length;
  }

  void _scrollToCurrentTopic(List<CourseTopic> topics) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_expandedScrollController.hasClients) return;
      if (topics.isEmpty) return;
      final idx = _getFirstIncompleteIndex(topics);
      double offset;
      if (idx <= 2) {
        offset = 0.0;
      } else if (idx >= topics.length) {
        offset = _expandedScrollController.position.maxScrollExtent;
      } else {
        offset = (idx - 2) * 48.0;
      }
      _expandedScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;
    final subjectName = widget.dashboardController
        .resolveSubjectName(widget.scheduledClass);
    final hasTopics =
        widget.scheduledClass.topics.isNotEmpty;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(
            horizontal: 5, vertical: 8),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color:
              isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isHighlighted
                ? const Color(0xFFA3E635)
                : isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFF1F5F9),
            width: widget.isHighlighted ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(isDark ? 0.3 : 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeBadgeRow(context, isDark),
            const SizedBox(height: 8),
            if (hasTopics)
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 150),
                  child: _buildTopicsContainer(context, isDark),
                ),
              )
            else
              _buildEmptyTopicsArea(context, isDark),
            const SizedBox(height: 8),
            Text(
              "${widget.scheduledClass.subjectCode} - $subjectName",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                HapticService.light();
                _showRoomInfo(
                    context, widget.scheduledClass.roomNumber);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84CC16)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF84CC16),
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "Room ${widget.scheduledClass.roomNumber}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF84CC16),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: const Color(0xFF84CC16)
                                .withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (hasTopics)
                    _buildCompletionBadge(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBadgeRow(BuildContext context, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.6)
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFFF1F5F9),
            ),
          ),
          child: Text(
            widget.scheduledClass.startTime,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.jetBrainsMono(
              color: const Color(0xFF2DD4BF),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTopicsArea(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 40, maxHeight: 150),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          "No topics available",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context).withOpacity(0.5),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionBadge(BuildContext context, bool isDark) {
    final topics = widget.scheduledClass.topics;
    final total = topics.length;
    final completed = topics.where((t) => _isTopicDone(t)).length;
    final pct = total > 0 ? (completed / total * 100).round() : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "$pct%",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            width: 50,
            height: 6,
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              backgroundColor: AppTheme.textSecondary(context)
                  .withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF84CC16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicsContainer(BuildContext context, bool isDark) {
    final topics = widget.scheduledClass.topics;
    final currentIdx = _getFirstIncompleteIndex(topics);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFE2E8F0).withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _expandedScrollController,
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
              physics: const BouncingScrollPhysics(),
              itemCount: topics.length,
              itemBuilder: (context, index) {
                return _buildTopicRow(
                  topics[index],
                  index,
                  topics.length,
                  isDark,
                );
              },
            ),
          ),
          if (topics.length > 3)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticService.light();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseTopicsScreen(
                      scheduledClass: widget.scheduledClass,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'See More',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.accentTeal,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: AppTheme.accentTeal,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicRow(
      CourseTopic topic, int index, int total, bool isDark) {
    final bool isLast = index == total - 1;
    final bool isCompleted = _isTopicDone(topic);
    final currentIdx = _getFirstIncompleteIndex(
        widget.scheduledClass.topics);
    final bool isCurrent = !isCompleted && index == currentIdx;
    final bool isFuture = !isCompleted && index > currentIdx;

    final startInterval = (index / total) * 0.6;
    final endInterval =
        (startInterval + 0.4).clamp(0.0, 1.0);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _topicAnimController,
        curve: Interval(startInterval, endInterval,
            curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _topicAnimController,
          curve: Interval(startInterval, endInterval,
              curve: Curves.easeOutCubic),
        )),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    if (isCurrent)
                      _buildGlowingCircle(topic, isDark)
                    else
                      _buildStandardCircle(topic, isDark, isFuture),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isCompleted
                              ? const Color(0xFF84CC16)
                                  .withOpacity(0.3)
                              : AppTheme.textSecondary(context)
                                  .withOpacity(0.08),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        topic.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: GoogleFonts.inter(
                          color: isFuture
                              ? AppTheme.textSecondary(context)
                                  .withOpacity(0.6)
                              : AppTheme.text(context),
                          fontSize: 13,
                          fontWeight: isCompleted
                              ? FontWeight.w600
                              : isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                        ),
                      ),
                      if (topic.totalCount > 0)
                        Text(
                          '${topic.completedCount}/${topic.totalCount}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: isCompleted
                                ? const Color(0xFF84CC16)
                                    .withOpacity(0.8)
                                : isCurrent
                                    ? const Color(0xFF34D399)
                                        .withOpacity(0.7)
                                    : AppTheme.textSecondary(
                                            context)
                                        .withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardCircle(
      CourseTopic topic, bool isDark, bool isFuture) {
    final done = _isTopicDone(topic);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF84CC16)
            : isFuture
                ? AppTheme.textSecondary(context).withOpacity(0.15)
                : AppTheme.textSecondary(context).withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        done ? Icons.check : Icons.circle,
        size: done ? 11 : 6,
        color: done
            ? Colors.white
            : isFuture
                ? AppTheme.textSecondary(context).withOpacity(0.4)
                : AppTheme.textSecondary(context).withOpacity(0.5),
      ),
    );
  }

  Widget _buildGlowingCircle(CourseTopic topic, bool isDark) {
    return Container(
      width: 18,
      height: 18,
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
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFF34D399),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.circle,
          size: 6,
          color: Colors.white,
        ),
      ),
    );
  }

  ScheduledClass? _getTomorrowFirstClass() {
    final tomorrow =
        widget.dashboardController.tomorrowSchedule;
    return tomorrow.isNotEmpty ? tomorrow.first : null;
  }

  Widget? _buildTomorrowChip(BuildContext context, bool isDark) {
    final topics = widget.scheduledClass.topics;
    final allDone = topics.every((t) => _isTopicDone(t));
    if (!allDone || topics.isEmpty) return null;

    final tomorrowClass = _getTomorrowFirstClass();
    if (tomorrowClass == null) return null;

    final tomorrowTopics = tomorrowClass.topics;
    final nextTopic =
        tomorrowTopics.isNotEmpty ? tomorrowTopics.first.name : null;
    if (nextTopic == null) return null;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(width: 6),
          Text(
            "Tomorrow: ",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF3B82F6).withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              nextTopic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFF3B82F6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRoomInfo(BuildContext context, String room) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    String block = "Block A";
    String floor = "Ground Floor";

    if (room.contains('B')) block = "Block B";
    if (room.contains('C')) block = "Block C";

    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(room);
    if (match != null) {
      int roomNum = int.parse(match.group(0)!);
      if (roomNum >= 100 && roomNum < 200) {
        floor = "1st Floor";
      }
      if (roomNum >= 200 && roomNum < 300) {
        floor = "2nd Floor";
      }
      if (roomNum >= 300 && roomNum < 400) {
        floor = "3rd Floor";
      }
      if (roomNum >= 400) floor = "4th Floor";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color:
              isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      isDark ? Colors.white10 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84CC16)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF84CC16)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Room $room",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: isDark
                            ? Colors.white
                            : Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Location Details",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color:
                            AppTheme.textSecondary(context),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildInfoRow(context, Icons.business_rounded,
                "Block", block),
            const SizedBox(height: 16),
            _buildInfoRow(context, Icons.layers_rounded,
                "Floor", floor),
            const SizedBox(height: 16),
            _buildInfoRow(
                context,
                Icons.map_rounded,
                "Navigation",
                "Follow signs to $block"),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF84CC16),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Got it", maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon,
      String label, String value) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon,
            size: 20,
            color: AppTheme.textSecondary(context)),
        const SizedBox(width: 16),
        Text(
          "$label: ",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 15,
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color:
                  isDark ? Colors.white : Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
