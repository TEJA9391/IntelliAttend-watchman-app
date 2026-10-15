import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Models/Faculty/scheduled_class.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

String _cleanTime(String raw) {
  try {
    final parts = raw.trim().split(' ');
    final tp = parts[0].split(':');
    if (tp.length >= 3) {
      return '${tp[0]}:${tp[1]}' + (parts.length > 1 ? ' ${parts[1]}' : '');
    }
    return raw;
  } catch (_) {
    return raw;
  }
}

class FacultyTimetableScreen extends StatefulWidget {
  const FacultyTimetableScreen({super.key});

  @override
  State<FacultyTimetableScreen> createState() => _FacultyTimetableScreenState();
}

class _FacultyTimetableScreenState extends State<FacultyTimetableScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final Map<String, List<ScheduledClass>> _allSlots = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final w = DateTime.now().weekday;
    final initialIndex = w == 7 ? 6 : w - 1;
    _tabController = TabController(length: _days.length, vsync: this, initialIndex: initialIndex);
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    // 1. Load all days from cache first for instant display
    for (final day in _days) {
      final cached = _getCached(day);
      if (cached.isNotEmpty) {
        _allSlots[day] = cached;
      }
    }
    if (_allSlots.isNotEmpty && mounted) {
      setState(() => _isLoading = false);
    }

    // 2. Fetch full week from server and cache all days
    await _fetchFullWeekFromServer();
  }

  Future<void> _fetchFullWeekFromServer() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final response = await ApiClient().dio.get(
        '/api/v1/faculty/sync',
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode != 200 || response.data is! Map) return;

      final data = response.data as Map<String, dynamic>;
      final scheduleList = data['schedule_list'] as List? ?? [];

      final Map<String, List<ScheduledClass>> weekData = {};
      for (final item in scheduleList) {
        final map = Map<String, dynamic>.from(item);
        final cls = ScheduledClass.fromJson(map, map['id']?.toString() ?? '');
        final dayIdx = cls.dayOfWeek - 1;
        if (dayIdx >= 0 && dayIdx < 7) {
          final dayName = _days[dayIdx];
          weekData.putIfAbsent(dayName, () => []).add(cls);
        }
      }

      // Sort each day by start time
      for (final entry in weekData.entries) {
        entry.value.sort((a, b) => _compareTime(a.startTime, b.startTime));
      }

      // Cache each day and update UI
      if (mounted) {
        setState(() {
          for (final entry in weekData.entries) {
            _allSlots[entry.key] = entry.value;
            _cacheDay(entry.key, entry.value);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ [TimetableScreen] Full week fetch error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static int _compareTime(String a, String b) {
    try {
      return _parseTime(a).compareTo(_parseTime(b));
    } catch (_) {
      return a.compareTo(b);
    }
  }

  static DateTime _parseTime(String t) {
    final parts = t.trim().split(' ');
    final tp = parts[0].split(':');
    int h = int.parse(tp[0]);
    final m = int.parse(tp[1]);
    if (parts.length > 1) {
      if (parts[1].toUpperCase() == 'PM' && h < 12) h += 12;
      if (parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
    }
    return DateTime(2000, 1, 1, h, m);
  }

  static String _cacheKey(String day) => 'schedule_${day.toLowerCase()}';

  void _cacheDay(String day, List<ScheduledClass> classes) {
    try {
      PersistenceService.academicBox.put(_cacheKey(day), classes.map((c) => c.toJson()).toList());
    } catch (_) {}
  }

  List<ScheduledClass> _getCached(String day) {
    try {
      final data = PersistenceService.academicBox.get(_cacheKey(day));
      if (data == null) return [];
      return (data as List)
          .map((item) => ScheduledClass.fromJson(Map<String, dynamic>.from(item), item['id']?.toString() ?? ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Weekly Timetable",
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.primary(context),
          indicatorWeight: 3,
          labelColor: AppTheme.primary(context),
          unselectedLabelColor: AppTheme.textSecondary(context),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: _days.map((day) => Tab(text: day)).toList(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary(context)))
          : TabBarView(
              controller: _tabController,
              children: _days.map((day) {
                final daySlots = _allSlots[day] ?? [];
                return _buildDayView(context, day, daySlots);
              }).toList(),
            ),
    );
  }

  Widget _buildDayView(BuildContext context, String day, List<ScheduledClass> slots) {
    if (slots.isEmpty) {
      final isSunday = day == 'Sunday';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isSunday ? '\u{1F33F}' : '\u{1F4C5}',
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 16),
            Text(
              isSunday ? 'Day of Rest' : 'No classes on $day',
              style: GoogleFonts.inter(
                color: AppTheme.text(context),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSunday
                  ? 'Nothing scheduled \u2014 enjoy your weekend'
                  : 'Nothing scheduled for this day',
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        return _buildTimeSlotCard(context, slot);
      },
    );
  }

  String _buildShortName(String subjectName) {
    final words = subjectName.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return words[0].substring(0, words[0].length.clamp(0, 4)).toUpperCase();
    final abbr = words.where((w) => w.isNotEmpty && w[0].toUpperCase() == w[0]).map((w) => w[0]).join();
    if (abbr.length >= 2) return abbr.substring(0, 2.clamp(0, abbr.length)).toUpperCase();
    return subjectName.substring(0, subjectName.length.clamp(0, 4)).toUpperCase();
  }

  String _extractYear(ScheduledClass slot) {
    final section = (slot.sectionId ?? '').toUpperCase();
    if (section.contains('1ST') || section.contains('_1_')) return '1st Year';
    if (section.contains('2ND') || section.contains('_2_')) return '2nd Year';
    if (section.contains('3RD') || section.contains('_3_')) return '3rd Year';
    if (section.contains('4TH') || section.contains('_4_')) return '4th Year';
    if (section.contains('_2026')) return '4th Year';
    if (section.contains('_2027')) return '3rd Year';
    if (section.contains('_2028')) return '2nd Year';
    if (section.contains('_2029')) return '1st Year';
    return '';
  }

  String _extractSection(ScheduledClass slot) {
    final section = (slot.sectionId ?? '').toUpperCase();

    if (section.contains(RegExp(r'AIML[_-]?[A-E]'))) {
      final match = RegExp(r'AIML[_-]?([A-E])').firstMatch(section);
      if (match != null) return 'AIML-${match.group(1)}';
    }

    if (section.contains(RegExp(r'SEC[_-]?[A-E]'))) {
      final match = RegExp(r'SEC[_-]?([A-E])').firstMatch(section);
      if (match != null) return 'Sec ${match.group(1)}';
    }

    if (section.contains(RegExp(r'_([A-E])_'))) {
      final match = RegExp(r'_([A-E])_').firstMatch(section);
      if (match != null) return 'Sec ${match.group(1)}';
    }

    return '';
  }

  Widget _buildTimeSlotCard(BuildContext context, ScheduledClass slot) {
    final shortName = _buildShortName(slot.subjectName);
    final year = _extractYear(slot);
    final section = _extractSection(slot);
    final yearSection = [year, section].where((s) => s.isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cleanTime(slot.startTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.jetBrainsMono(
                    color: AppTheme.primary(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _cleanTime(slot.endTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.jetBrainsMono(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            height: 40,
            width: 1,
            color: AppTheme.border(context),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  slot.subjectCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (slot.roomNumber.isNotEmpty && slot.roomNumber != 'N/A') ...[
                      const Icon(Icons.meeting_room_rounded, size: 13, color: Color(0xFF22C55E)),
                      Text(
                        slot.roomNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF22C55E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (yearSection.isNotEmpty) ...[
                      const Icon(Icons.school_rounded, size: 13, color: Color(0xFF22C55E)),
                      Text(
                        yearSection,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF22C55E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
