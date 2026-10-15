import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Services/eligibility_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/Components/custom_app_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'present_students_screen.dart';
import 'absent_students_screen.dart';
import 'late_students_screen.dart';
import 'leave_students_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Screens/MarkAttendance/mark_attendance_screen.dart' as qa;
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Screens/AttendanceRecords/attendance_records_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_list_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Screens/ExportReports/export_reports_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Screens/ClassStudents/class_students_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Screens/ClassStudents/class_student_profile_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/attendance_records_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/QuickActions/Controllers/class_students_controller.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/attendance_records_repository.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/students_repository.dart';
import 'package:provider/provider.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_controller.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/course_topic.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Data/Repositories/course_repository.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/course_topics_screen.dart';
import 'subject_class_topics_section.dart';

class MyClassScreen extends StatefulWidget {
  final String? initialSubjectCode;

  const MyClassScreen({Key? key, this.initialSubjectCode}) : super(key: key);

  @override
  State<MyClassScreen> createState() => _MyClassScreenState();
}

class _MyClassScreenState extends State<MyClassScreen> {
  List<Map<String, dynamic>> _cohorts = [];
  int _selectedCohortIndex = 0;
  List<Map<String, dynamic>> _roster = [];

  late PageController _pageController;
  late PageController _tabPageController;
  Map<int, Map<String, dynamic>> _statsCache = {};

  Map<String, dynamic>? _activeSession;
  String _sessionState = 'IDLE';
  bool _isLoadingSession = false;
  Timer? _sessionRefreshTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tabPageController = PageController(viewportFraction: 0.35);
    _loadCohorts();
    _fetchActiveSession();
    _startSessionRefreshTimer();
    FacultyService.courses.addListener(_onCoursesChanged);
  }

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel();
    FacultyService.courses.removeListener(_onCoursesChanged);
    _pageController.dispose();
    _tabPageController.dispose();
    super.dispose();
  }

  void _startSessionRefreshTimer() {
    _sessionRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchActiveSession();
    });
  }

  void _onCoursesChanged() {
    _loadCohorts();
    _fetchActiveSession();
  }

  Future<void> _fetchActiveSession() async {
    if (_isLoadingSession) return;
    _isLoadingSession = true;
    try {
      final response = await ApiClient().dio.get(
        '/api/v1/session/current-state',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (mounted && response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final state = data['state']?.toString() ?? 'IDLE';
        setState(() {
          _sessionState = state;
          if (state != 'IDLE') {
            _activeSession = data;
          }
        });
      }
    } catch (e) {
      debugPrint("MyClass: Session fetch error: $e");
    } finally {
      _isLoadingSession = false;
    }
  }

  List<CourseTopic> _getTopicsForCohort(Map<String, dynamic> cohort) {
    final rawTopics = cohort['topics'];
    if (rawTopics is List && rawTopics.isNotEmpty) {
      return rawTopics.whereType<Map<String, dynamic>>().map(CourseTopic.fromJson).toList();
    }

    final sectionId = (cohort['section_id'] ?? '').toString();
    final courseCode = (cohort['course_code'] ?? '').toString();
    final now = DateTime.now();
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = dayNames[now.weekday - 1];
    final cached = CourseRepository().getCachedSchedule(dayName);
    for (final sc in cached) {
      if (sc.topics.isNotEmpty &&
          (sc.sectionId == sectionId || sc.subjectCode == courseCode)) {
        return sc.topics;
      }
    }
    return [];
  }

  ScheduledClass _buildScheduledClassFromCohort(Map<String, dynamic> cohort, List<CourseTopic> topics) {
    return ScheduledClass(
      id: cohort['section_id'] ?? '',
      subjectName: cohort['course_name'] ?? '',
      subjectCode: cohort['course_code'] ?? '',
      roomNumber: '',
      startTime: '--:--',
      endTime: '--:--',
      dayOfWeek: DateTime.now().weekday,
      sectionId: cohort['section_id']?.toString(),
      topics: topics,
    );
  }

  void _navigateToAllTopics(Map<String, dynamic> cohort) {
    final topics = _getTopicsForCohort(cohort);
    final scheduledClass = _buildScheduledClassFromCohort(cohort, topics);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CourseTopicsScreen(scheduledClass: scheduledClass),
    ));
  }

  void _navigateToTopic(Map<String, dynamic> cohort, int topicIndex) {
    final topics = _getTopicsForCohort(cohort);
    final scheduledClass = _buildScheduledClassFromCohort(cohort, topics);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CourseTopicsScreen(
        scheduledClass: scheduledClass,
        initialTopicIndex: topicIndex,
      ),
    ));
  }

  void _loadCohorts() {
    try {
      final raw = PersistenceService.academicBox.get('cohorts');
      if (raw != null) {
        _cohorts = (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint("MyClass: Error loading cohorts: $e");
    }

    if (widget.initialSubjectCode != null && _cohorts.isNotEmpty) {
      final code = widget.initialSubjectCode!;
      final matchIdx = _cohorts.indexWhere(
        (c) => (c['course_code'] ?? '').toString().toLowerCase() == code.toLowerCase(),
      );
      if (matchIdx >= 0) {
        _selectedCohortIndex = matchIdx;
      }
    }

    if (_cohorts.isNotEmpty) {
      _loadRoster(_selectedCohortIndex);
    }
    if (mounted) {
      setState(() {});
      if (_selectedCohortIndex > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_tabPageController.hasClients) {
            _tabPageController.jumpToPage(_selectedCohortIndex);
          }
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_selectedCohortIndex);
          }
        });
      }
    }
  }

  void _loadRoster(int index) {
    if (index < 0 || index >= _cohorts.length) return;
    _selectedCohortIndex = index;

    final sectionId = _cohorts[index]['section_id'] ?? '';
    try {
      final raw = PersistenceService.academicBox.get('roster_$sectionId');
      if (raw != null) {
        _roster = (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _roster = [];
      }
    } catch (e) {
      debugPrint("MyClass: Error loading roster: $e");
      _roster = [];
    }
    final dashboard = context.read<DashboardController>();
    dashboard.rosterStudents
      ..clear()
      ..addAll(_roster);
    dashboard.presentStudentIds; // trigger compute
    EligibilityService.switchCourse(_cohorts[index]['course_code'] ?? '');
    if (mounted) setState(() {});
  }

  void _loadRosterNoSetState(int index) {
    if (index < 0 || index >= _cohorts.length) return;

    final sectionId = _cohorts[index]['section_id'] ?? '';
    try {
      final raw = PersistenceService.academicBox.get('roster_$sectionId');
      if (raw != null) {
        _roster = (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _roster = [];
      }
    } catch (e) {
      debugPrint("MyClass: Error loading roster: $e");
      _roster = [];
    }
    _statsCache.remove(index);
    EligibilityService.switchCourse(_cohorts[index]['course_code'] ?? '');
  }

  Map<String, dynamic> _computeStats(int index) {
    if (_statsCache.containsKey(index)) return _statsCache[index]!;
    final eligible = _roster.where((s) => _pct(s) >= 0.75).toList();
    final defaulters = _roster.where((s) => _pct(s) < 0.75).toList();
    final total = _roster.length;
    final avg = total > 0 ? _roster.fold<double>(0, (sum, s) => sum + _pct(s)) / total : 0.0;
    final stats = <String, dynamic>{
      'eligible': eligible.length,
      'defaulters': defaulters.length,
      'total': total,
      'avgPct': avg,
      'highestPct': total > 0 ? _roster.map<double>(_pct).reduce((a, b) => a > b ? a : b) : 0.0,
      'lowestPct': total > 0 ? _roster.map<double>(_pct).reduce((a, b) => a < b ? a : b) : 0.0,
      'highestStudent': total > 0 ? _roster.firstWhere((s) => _pct(s) == (total > 0 ? _roster.map<double>(_pct).reduce((a, b) => a > b ? a : b) : 0.0), orElse: () => _roster.first) : null,
      'lowestStudent': total > 0 ? _roster.firstWhere((s) => _pct(s) == (total > 0 ? _roster.map<double>(_pct).reduce((a, b) => a < b ? a : b) : 0.0), orElse: () => _roster.first) : null,
    };
    _statsCache[index] = stats;
    return stats;
  }

  double _pct(Map<String, dynamic> s) {
    final a = (s['attended'] as num?)?.toDouble() ?? 0;
    final t = (s['total'] as num?)?.toDouble() ?? 1;
    return t > 0 ? a / t : 0;
  }

  ClassStudent _toClassStudent(Map<String, dynamic> s) {
    final attended = (s['attended'] as num?)?.toDouble() ?? 0;
    final total = (s['total'] as num?)?.toDouble() ?? 0;
    final pct = total > 0 ? attended / total * 100 : 0.0;
    return ClassStudent(
      id: (s['id'] ?? s['student_id'] ?? '').toString(),
      name: (s['name'] ?? 'Unknown').toString(),
      rollNumber: (s['roll_number'] ?? '').toString(),
      email: (s['email'] ?? '').toString(),
      phone: s['phone']?.toString(),
      department: s['department']?.toString(),
      section: s['section']?.toString(),
      courseCode: s['course_code']?.toString(),
      courseName: s['course_name']?.toString(),
      semester: s['semester']?.toString(),
      attendancePercentage: pct,
      totalClasses: total.toInt(),
      attendedClasses: attended.toInt(),
      isEligible: pct >= 75,
      isDefaulter: pct < 75,
      gender: s['gender']?.toString(),
      guardianName: s['guardian_name']?.toString(),
      guardianPhone: s['guardian_phone']?.toString(),
      bloodGroup: s['blood_group']?.toString(),
    );
  }

  bool _isR22Cohort(Map<String, dynamic> c) =>
      (c['course_code'] ?? '').toString().toUpperCase() == 'R22A6201';

  int _r22SectionIndex(int index) {
    var r22Index = 0;
    for (var i = 0; i < index; i++) {
      if (_isR22Cohort(_cohorts[i])) r22Index++;
    }
    return r22Index;
  }

  String _mappedSection(Map<String, dynamic> c, int index) {
    if (_isR22Cohort(c)) {
      return 'AIML-${String.fromCharCode(65 + (_r22SectionIndex(index) % 26))}';
    }
    final sectionId = (c['section_id'] ?? '').toUpperCase();

    if (sectionId.contains(RegExp(r'AIML[_-]?[A-E]'))) {
      final match = RegExp(r'AIML[_-]?([A-E])').firstMatch(sectionId);
      if (match != null) return 'AIML-${match.group(1)}';
    }
    if (sectionId.contains(RegExp(r'SEC[_-]?[A-E]'))) {
      final match = RegExp(r'SEC[_-]?([A-E])').firstMatch(sectionId);
      if (match != null) return 'Sec ${match.group(1)}';
    }
    if (sectionId.contains(RegExp(r'_([A-E])_'))) {
      final match = RegExp(r'_([A-E])_').firstMatch(sectionId);
      if (match != null) return 'Sec ${match.group(1)}';
    }

    final name = (c['section_name'] ?? c['section'] ?? '').toString();
    if (name.isNotEmpty) return name;
    return '';
  }

  String _mappedYear(Map<String, dynamic> c) {
    if (_isR22Cohort(c)) return '4th Year';
    final sectionId = (c['section_id'] ?? '').toUpperCase();

    if (sectionId.contains('1ST') || sectionId.contains('_1_')) return '1st Year';
    if (sectionId.contains('2ND') || sectionId.contains('_2_')) return '2nd Year';
    if (sectionId.contains('3RD') || sectionId.contains('_3_')) return '3rd Year';
    if (sectionId.contains('4TH') || sectionId.contains('_4_')) return '4th Year';
    if (sectionId.contains('_2026')) return '4th Year';
    if (sectionId.contains('_2027')) return '3rd Year';
    if (sectionId.contains('_2028')) return '2nd Year';
    if (sectionId.contains('_2029')) return '1st Year';

    final year = (c['academic_year'] ?? c['year'] ?? '').toString();
    if (year.isNotEmpty) return year;
    final sem = (c['semester'] ?? '').toString();
    if (sem.isNotEmpty && !sem.contains(RegExp(r'^\d{4}'))) return sem;
    return '';
  }

  String _buildCohortLabel(Map<String, dynamic> c, int index) {
    if (_isR22Cohort(c)) {
      return '4th Year • AIML-${String.fromCharCode(65 + (_r22SectionIndex(index) % 26))}';
    }
    final year = (c['academic_year'] ?? c['year'] ?? c['semester'] ?? '').toString().trim();
    var dept = (c['department'] ?? c['branch'] ?? c['dept'] ?? '').toString().trim();
    var section = (c['section'] ?? c['section_name'] ?? '').toString().trim();
    if (dept.isEmpty && section.contains('-')) {
      final idx = section.lastIndexOf('-');
      dept = section.substring(0, idx).trim();
      section = section.substring(idx + 1).trim();
    }
    if (year.isEmpty && dept.isEmpty && section.isEmpty) {
      return 'Year • Department-Section';
    }
    return '${year.isEmpty ? 'Year' : year} • '
        '${dept.isEmpty ? 'Department' : dept}-${section.isEmpty ? 'Section' : section}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: CustomAppBar(
        title: "My Class",
        showBackButton: false,
      ),
      body: Column(
        children: [
          if (_cohorts.length > 1)
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_selectedCohortIndex > 0) {
                        HapticService.light();
                        _pageController.animateToPage(
                          _selectedCohortIndex - 1,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: _selectedCohortIndex > 0
                            ? AppTheme.accentTeal
                            : AppTheme.textSecondary(context).withValues(alpha: 0.3),
                        size: 28,
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _tabPageController,
                      physics: const BouncingScrollPhysics(
                        decelerationRate: ScrollDecelerationRate.fast,
                      ),
                      itemCount: _cohorts.length,
                      onPageChanged: (index) {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      itemBuilder: (context, index) {
                        final c = _cohorts[index];
                        final selected = index == _selectedCohortIndex;
                        final year = _mappedYear(c);
                        final section = _mappedSection(c, index);
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (year.isNotEmpty)
                                Text(
                                  year,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: selected ? AppTheme.accentTeal : AppTheme.textSecondary(context),
                                    fontSize: selected ? 12 : 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (year.isNotEmpty && section.isNotEmpty) const SizedBox(height: 2),
                              if (section.isNotEmpty)
                                Text(
                                  section,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: selected ? AppTheme.text(context) : AppTheme.textSecondary(context),
                                    fontSize: selected ? 14 : 12,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              if (year.isEmpty && section.isEmpty)
                                Text(
                                  c['course_name'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: selected ? AppTheme.text(context) : AppTheme.textSecondary(context),
                                    fontSize: selected ? 14 : 12,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_selectedCohortIndex < _cohorts.length - 1) {
                        HapticService.light();
                        _pageController.animateToPage(
                          _selectedCohortIndex + 1,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: _selectedCohortIndex < _cohorts.length - 1
                            ? AppTheme.accentTeal
                            : AppTheme.textSecondary(context).withValues(alpha: 0.3),
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: _cohorts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 48,
                          color: AppTheme.textSecondary(context).withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No classes assigned",
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(
                      decelerationRate: ScrollDecelerationRate.fast,
                    ),
                    allowImplicitScrolling: false,
                    itemCount: _cohorts.length,
                    onPageChanged: (index) {
                      HapticService.light();
                      _selectedCohortIndex = index;
                      _loadRosterNoSetState(index);
                      if (_tabPageController.hasClients) {
                        _tabPageController.jumpToPage(index);
                      }
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (context, index) {
                      return _buildClassPage(context, _cohorts[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassPage(BuildContext context, Map<String, dynamic> cohort, int cohortIndex) {
    final eligible = _roster.where((s) => _pct(s) >= 0.75).toList();
    final defaulters = _roster.where((s) => _pct(s) < 0.75).toList();
    final totalStudents = _roster.length;
    final attendanceRequired = defaulters.length;

    final avgPct = totalStudents > 0
        ? _roster.fold<double>(0, (sum, s) => sum + _pct(s)) / totalStudents
        : 0.0;
    final highestPct = totalStudents > 0
        ? _roster.map<double>(_pct).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final lowestPct = totalStudents > 0
        ? _roster.map<double>(_pct).reduce((a, b) => a < b ? a : b)
        : 0.0;
    final highestStudent = totalStudents > 0
        ? _roster.firstWhere((s) => _pct(s) == highestPct, orElse: () => _roster.first)
        : null;
    final lowestStudent = totalStudents > 0
        ? _roster.firstWhere((s) => _pct(s) == lowestPct, orElse: () => _roster.first)
        : null;

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: _buildOverviewCard(context, cohort, cohortIndex, totalStudents, eligible.length, defaulters.length),
        ),

        const SizedBox(height: 16),

        _buildAttendanceSummary(context, totalStudents, eligible.length, defaulters.length),

        const SizedBox(height: 20),

        _buildQuickActions(context, cohort),

        const SizedBox(height: 24),

        SubjectClassTopicsSection(
          topics: _getTopicsForCohort(cohort),
          scheduledClass: _buildScheduledClassFromCohort(cohort, _getTopicsForCohort(cohort)),
          onSeeAll: () => _navigateToAllTopics(cohort),
          onTopicTap: (topicIndex) => _navigateToTopic(cohort, topicIndex),
        ),

        const SizedBox(height: 24),

        _buildClassStatistics(context, highestStudent, lowestStudent, highestPct, lowestPct, avgPct, attendanceRequired),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildOverviewCard(BuildContext context, Map<String, dynamic> cohort, int cohortIndex, int total, int eligible, int defaulters) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.class_rounded, color: AppTheme.accentTeal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cohort['course_name'] ?? 'Course',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${_mappedSection(cohort, cohortIndex)} · ${_mappedYear(cohort)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "CLASS TEACHER",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.accentTeal,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMiniStat("$total", "Students")),
              Expanded(child: _buildMiniStat("$eligible", "Eligible")),
              Expanded(child: _buildMiniStat("$defaulters", "At Risk")),
              Expanded(child: _buildMiniStat(cohort['course_code'] ?? '', "Code")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceSummary(BuildContext context, int total, int eligibleCount, int defaulterCount) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasSessionData = _activeSession != null;
    final bool isLive = _sessionState != 'IDLE' && _sessionState != 'CLOSED';
    final int present = hasSessionData ? (_activeSession!['present'] as int? ?? _activeSession!['present_count'] as int? ?? 0) : 0;
    final int absent = hasSessionData ? (_activeSession!['absent'] as int? ?? _activeSession!['absent_count'] as int? ?? 0) : 0;
    final int late = hasSessionData ? (_activeSession!['late'] as int? ?? _activeSession!['late_count'] as int? ?? 0) : 0;
    final int leave = hasSessionData ? (_activeSession!['leave'] as int? ?? _activeSession!['leave_count'] as int? ?? 0) : 0;
    final int sessionTotal = present + absent + late + leave;

    String headerText;
    if (isLive) {
      headerText = "Today's Attendance";
    } else if (hasSessionData) {
      headerText = "Last Session";
    } else {
      headerText = "No Session Today";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.04),
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
                if (isLive) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  headerText,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (hasSessionData) ...[
              const SizedBox(height: 4),
              Text(
                "${_activeSession!['session_id'] ?? ''} · ${_activeSession!['subject_code'] ?? _activeSession!['course_code'] ?? ''}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary(context),
                  fontSize: 10,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildSummaryChip(context, "Present", "$present", const Color(0xFF2DD4BF), Icons.check_circle_rounded, () {
                  final dashboard = context.read<DashboardController>();
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PresentStudentsScreen(
                      roster: _roster,
                      cohort: _cohorts[_selectedCohortIndex],
                      presentCount: present,
                      totalCount: hasSessionData ? sessionTotal : total,
                      presentIds: hasSessionData ? dashboard.presentStudentIds : null,
                    ),
                  ));
                })),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryChip(context, "Absent", "$absent", const Color(0xFFEF4444), Icons.cancel_rounded, () {
                  final dashboard = context.read<DashboardController>();
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AbsentStudentsScreen(
                      roster: _roster,
                      cohort: _cohorts[_selectedCohortIndex],
                      absentCount: absent,
                      totalCount: hasSessionData ? sessionTotal : total,
                      presentIds: hasSessionData ? dashboard.presentStudentIds : null,
                    ),
                  ));
                })),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryChip(context, "Late", "$late", const Color(0xFFFBBF24), Icons.schedule_rounded, () {
                  final dashboard = context.read<DashboardController>();
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => LateStudentsScreen(
                      roster: _roster,
                      cohort: _cohorts[_selectedCohortIndex],
                      lateCount: late,
                      totalCount: hasSessionData ? sessionTotal : total,
                      lateIds: hasSessionData ? dashboard.lateStudentIds : null,
                    ),
                  ));
                })),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryChip(context, "Leave", "$leave", const Color(0xFFA3E635), Icons.event_busy_rounded, () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => LeaveStudentsScreen(
                      roster: _roster,
                      cohort: _cohorts[_selectedCohortIndex],
                      leaveCount: leave,
                      totalCount: hasSessionData ? sessionTotal : total,
                    ),
                  ));
                })),
              ],
            ),
            if (hasSessionData && _roster.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildStudentGrid(context, isDark, present, absent, late, leave, sessionTotal),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentGrid(BuildContext context, bool isDark, int present, int absent, int late, int leave, int sessionTotal) {
    final dashboard = context.read<DashboardController>();
    final presentIds = dashboard.presentStudentIds;

    final presentStudents = _roster.where((s) {
      final id = (s['id'] ?? s['roll_number'] ?? s['student_id'] ?? '').toString();
      return presentIds.contains(id);
    }).toList();
    final absentStudents = _roster.where((s) {
      final id = (s['id'] ?? s['roll_number'] ?? s['student_id'] ?? '').toString();
      return !presentIds.contains(id);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (presentStudents.isNotEmpty) ...[
          Text(
            "Present (${presentStudents.length})",
            style: GoogleFonts.inter(
              color: const Color(0xFF2DD4BF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: presentStudents.take(12).map((s) {
              final name = (s['name'] ?? s['student_name'] ?? '').toString();
              final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  initials.isNotEmpty ? initials : '?',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF2DD4BF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList()..addAll(presentStudents.length > 12 ? [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4BF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${presentStudents.length - 12}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF2DD4BF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] : []),
          ),
        ],
        if (absentStudents.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            "Absent (${absentStudents.length})",
            style: GoogleFonts.inter(
              color: const Color(0xFFEF4444),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: absentStudents.take(12).map((s) {
              final name = (s['name'] ?? s['student_name'] ?? '').toString();
              final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  initials.isNotEmpty ? initials : '?',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList()..addAll(absentStudents.length > 12 ? [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${absentStudents.length - 12}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] : []),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryChip(BuildContext context, String label, String count, Color color, IconData icon, VoidCallback? onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Semantics(
          label: '$label Students',
          button: true,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    count,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, Map<String, dynamic> cohort) {
    final sectionId = cohort['section_id'] ?? '';
    final courseCode = cohort['course_code'] ?? '';
    final courseName = cohort['course_name'] ?? '';

    final actions = <_QuickAction>[
      _QuickAction(Icons.fact_check_rounded, "Mark Attendance", const Color(0xFF2DD4BF), () {
        final sessionId = _activeSession != null ? _activeSession!['session_id']?.toString() : null;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => qa.MarkAttendanceScreen(
            courseCode: courseCode,
            courseName: courseName,
            sectionId: sectionId,
            sessionId: sessionId ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
          ),
        ));
      }),
      _QuickAction(Icons.receipt_long_rounded, "Attendance Records", const Color(0xFFA3E635), () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => AttendanceRecordsController(AttendanceRecordsRepository()),
            child: const AttendanceRecordsScreen(),
          ),
        ));
      }),
      _QuickAction(Icons.people_rounded, "Students", const Color(0xFF22C55E), () {
        final controller = ClassStudentsController(StudentsRepository());
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: controller,
            child: ClassStudentsScreen(
              controller: controller,
              section: sectionId,
              courseCode: courseCode,
            ),
          ),
        ));
      }),
      _QuickAction(Icons.mail_outline_rounded, "Send Message", const Color(0xFFFBBF24), () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const ChatListScreen(),
        ));
      }),
      _QuickAction(Icons.file_download_outlined, "Export Reports", const Color(0xFF2DD4BF), () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const ExportReportsScreen(),
        ));
      }),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Quick Actions",
            style: GoogleFonts.inter(
              color: AppTheme.text(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: actions.map((a) => _buildActionButton(context, a.icon, a.label, a.color, a.onTap)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.text(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassStatistics(BuildContext context, Map<String, dynamic>? highestStudent, Map<String, dynamic>? lowestStudent, double highestPct, double lowestPct, double avgPct, int attentionCount) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA3E635).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Color(0xFFA3E635), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Class Statistics",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            _buildStatRow(context, "Highest Attendance", highestStudent != null ? "${highestStudent['name']} · ${(highestPct * 100).toInt()}%" : "N/A", const Color(0xFF2DD4BF), Icons.arrow_upward_rounded, onTap: highestStudent != null ? () {
              HapticService.light();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ClassStudentProfileScreen(student: _toClassStudent(highestStudent)),
              ));
            } : null),
            const SizedBox(height: 12),
            _buildStatRow(context, "Lowest Attendance", lowestStudent != null ? "${lowestStudent['name']} · ${(lowestPct * 100).toInt()}%" : "N/A", const Color(0xFFEF4444), Icons.arrow_downward_rounded, onTap: lowestStudent != null ? () {
              HapticService.light();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ClassStudentProfileScreen(student: _toClassStudent(lowestStudent)),
              ));
            } : null),
            const SizedBox(height: 12),
            _buildStatRow(context, "Average Attendance", "${(avgPct * 100).toInt()}%", const Color(0xFFA3E635), Icons.leaderboard_rounded),
            const SizedBox(height: 12),
            _buildStatRow(context, "Students Needing Attention", "$attentionCount students", const Color(0xFFFBBF24), Icons.info_outline_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 12,
              ),
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      color: onTap != null ? AppTheme.accentTeal : AppTheme.text(context),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: AppTheme.accentTeal, size: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
}
