import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/chat_conversation.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/student_contact.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/students_repository.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/my_class/attendance_history_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Utils/responsive.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class _AttendanceEntry {
  final DateTime date;
  final String session;
  final String status;

  const _AttendanceEntry({
    required this.date,
    required this.session,
    required this.status,
  });
}

class ClassStudentProfileScreen extends StatefulWidget {
  final ClassStudent student;

  const ClassStudentProfileScreen({super.key, required this.student});

  @override
  State<ClassStudentProfileScreen> createState() =>
      _ClassStudentProfileScreenState();
}

class _ClassStudentProfileScreenState extends State<ClassStudentProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _attendanceHistory = [];

  ClassStudent get student => widget.student;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadAttendanceHistory();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final repo = StudentsRepository();
      final history = await repo.fetchStudentAttendanceHistory(
        studentId: student.id,
        sectionId: student.section,
        courseCode: student.courseCode,
      );
      if (mounted) {
        setState(() {
          _attendanceHistory = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint("StudentProfile: Error loading attendance history: $e");
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Color _getAttendanceColor(double pct) {
    if (pct > 75) return AppTheme.accentTeal;
    if (pct >= 50) return AppTheme.textSecondary(context);
    return AppTheme.errorRed;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return AppTheme.highlightLime;
      case 'Late':
        return AppTheme.textSecondary(context);
      case 'Absent':
        return AppTheme.errorRed;
      case 'Leave':
        return AppTheme.textSecondary(context);
      default:
        return AppTheme.textSecondary(context);
    }
  }

  List<_AttendanceEntry> _convertToAttendanceEntries() {
    final entries = <_AttendanceEntry>[];
    for (final record in _attendanceHistory) {
      final dateStr = record['date']?.toString() ?? '';
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      final status = record['status']?.toString() ?? 'absent';
      final subject = record['subject']?.toString() ?? '';

      entries.add(_AttendanceEntry(
        date: date,
        session: subject.isNotEmpty ? subject : 'Class',
        status: status[0].toUpperCase() + status.substring(1).toLowerCase(),
      ));
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard',
            style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppTheme.accentTeal,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _sendMessage() {
    HapticService.light();
    final nameParts =
        student.name.split(' ').where((w) => w.isNotEmpty).toList();
    final peer = StudentContact(
      id: student.id,
      name: student.name,
      rollNumber: student.rollNumber,
      email: student.email,
      phone: student.phone,
      department: student.department,
      section: student.section,
      courseCode: student.courseCode,
      courseName: student.courseName,
      initials: nameParts.length >= 2
          ? (nameParts.first[0] + nameParts.last[0]).toUpperCase()
          : student.name.isNotEmpty
              ? student.name
                  .substring(0, student.name.length >= 2 ? 2 : 1)
                  .toUpperCase()
              : 'S',
    );

    final conversation = ChatConversation(
      id: 'direct_${student.id}',
      peer: peer,
      createdAt: DateTime.now(),
    );
    MessageCacheService.instance.upsertConversation(conversation);

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(conversation: conversation),
    ));
  }

  void _viewFullHistory() {
    HapticService.light();
    final studentMap = <String, dynamic>{
      'name': student.name,
      'roll_number': student.rollNumber,
      'id': student.id,
      'attended': student.attendedClasses,
      'total': student.totalClasses,
      'department': student.department,
      'section': student.section,
      'course_code': student.courseCode,
      'course_name': student.courseName,
      'semester': student.semester,
    };
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AttendanceHistoryScreen(student: studentMap),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final attendanceHistory = _convertToAttendanceEntries();
    final pct = student.attendancePercentage;
    final attended = student.attendedClasses;
    final total = student.totalClasses;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.bg(context),
              surfaceTintColor: Colors.transparent,
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
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.accentTeal.withOpacity(0.08),
                        AppTheme.bg(context),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: 'student-avatar-${student.id}',
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Hero(
                        tag: 'student-name-${student.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            student.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: AppTheme.text(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${student.rollNumber}${student.department != null ? '  ·  ${student.department}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.jetBrainsMono(
                          color: AppTheme.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAttendanceCard(),
                  const SizedBox(height: 12),
                  _buildEligibilityCard(),
                  const SizedBox(height: 12),
                  _buildContactCard(),
                  const SizedBox(height: 12),
                  _buildGuardianCard(),
                  const SizedBox(height: 16),
                  _buildAttendanceTimeline(attendanceHistory),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final color = _getAttendanceColor(student.attendancePercentage);
    final attended = student.attendedClasses;
    final total = student.totalClasses;
    final pct = student.attendancePercentage;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final animatedPct = pct * _animController.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pie_chart_rounded, size: 22, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                'Attendance',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${pct.toInt()}% · $attended / $total',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEligibilityCard() {
    final isDefaulter = student.isDefaulter;
    final color = isDefaulter ? AppTheme.errorRed : AppTheme.accentTeal;
    final icon =
        isDefaulter ? Icons.cancel_rounded : Icons.check_circle_rounded;
    final label = isDefaulter ? 'Defaulter' : 'Eligible';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isDefaulter ? 'Attendance below 75%' : 'Meets requirements',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    final email = student.email;
    final phone = student.phone ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.text(context),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _copyToClipboard(email),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined, size: 16, color: AppTheme.accentTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.text(context),
                      ),
                    ),
                  ),
                  Icon(Icons.copy_rounded, size: 12, color: AppTheme.textSecondary(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _copyToClipboard(phone),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bg(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_outlined, size: 16, color: AppTheme.accentTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.text(context),
                      ),
                    ),
                  ),
                  Icon(Icons.copy_rounded, size: 12, color: AppTheme.textSecondary(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianCard() {
    final name = student.guardianName ?? 'N/A';
    final phone = student.guardianPhone ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.family_restroom_rounded,
                size: 20, color: AppTheme.accentTeal),
          ),
          const SizedBox(height: 8),
          Text(
            'Guardian',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.text(context),
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () => _copyToClipboard(phone),
            child: Text(
              phone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.jetBrainsMono(
                fontSize: 10,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month];
  }

  Widget _buildAttendanceTimeline(List<_AttendanceEntry> history) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Attendance',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.text(context),
            ),
          ),
          const SizedBox(height: 14),
          if (_isLoadingHistory)
            SizedBox(
              height: 260,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentTeal),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading attendance history...',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (history.isEmpty)
            SizedBox(
              height: 260,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 36,
                      color: AppTheme.textSecondary(context).withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No attendance records yet',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final entry = history[index];
                  final isLast = index == history.length - 1;
                  final statusColor = _getStatusColor(entry.status);

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: AppTheme.textSecondary(context)
                                      .withOpacity(0.15),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.bg(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.session,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.text(context),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${entry.date.day.toString().padLeft(2, '0')} ${_monthName(entry.date.month)} ${entry.date.year}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    entry.status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
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
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _actionButton(
          context,
          'Send Message',
          Icons.chat_bubble_outline_rounded,
          const Color(0xFFFB923C),
          _sendMessage,
        ),
        const SizedBox(width: 12),
        _actionButton(
          context,
          'View Full History',
          Icons.history_rounded,
          AppTheme.highlightLime,
          _viewFullHistory,
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
