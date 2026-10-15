import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/attendance_service.dart';
import 'package:intelli_attend_faculty/Data/Models/Attendance/attendance_models.dart';

class RealtimeAttendancePage extends StatefulWidget {
  final String courseName;
  final String section;

  const RealtimeAttendancePage({
    Key? key,
    required this.courseName,
    required this.section,
  }) : super(key: key);

  @override
  State<RealtimeAttendancePage> createState() => _RealtimeAttendancePageState();
}

class _RealtimeAttendancePageState extends State<RealtimeAttendancePage>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.courseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Text("Section ${widget.section}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppTheme.textSecondary(context), fontSize: 11)),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.text(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert_rounded, color: AppTheme.text(context)),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<StudentAttendance>>(
          valueListenable: AttendanceService().students,
          builder: (context, students, child) {
            int presentCount =
                students.where((s) => s.status == StudentStatus.present).length;
            int totalCount = students.length;
            double percent = totalCount > 0 ? (presentCount / totalCount) : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildLiveIndicator(),
                  const SizedBox(height: 16),
                  _buildMainStatsCard(presentCount, totalCount, percent),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text("RECENT LOGS",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppTheme.slate500(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5)),
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text("AUTO-SYNC ON",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppTheme.greenOnline,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final s = students[index];
                        final isPresent = s.status == StudentStatus.present;
                        return _buildStudentTile(s, isPresent);
                      },
                    ),
                  ),
                  _buildBottomControls(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulseIndicator(),
            const SizedBox(width: 8),
            Text("LIVE MONITORING",
                style: TextStyle(
                    color: AppTheme.primary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Container(
                width: 1, height: 12, color: AppTheme.primary(context).withValues(alpha: 0.2)),
            const SizedBox(width: 12),
            Icon(Icons.timer_outlined, color: AppTheme.primary(context), size: 14),
            const SizedBox(width: 4),
            Text(_formatTime(_secondsElapsed),
                style: TextStyle(
                    color: AppTheme.primary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStatsCard(int present, int total, double percent) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Attendance",
                        style: TextStyle(
                            color: AppTheme.textSecondary(context),
                            fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text("$present",
                            style: TextStyle(
                                color: AppTheme.text(context),
                                fontSize: 32,
                                fontWeight: FontWeight.w900)),
                        Text("/$total",
                            style: TextStyle(
                                color: AppTheme.textSecondary(context)
                                    .withValues(alpha: 0.5),
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 30),
                SizedBox(
                  width: 70,
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: percent,
                        strokeWidth: 8,
                        backgroundColor: AppTheme.primary(context).withValues(alpha: 0.1),
                        color: AppTheme.primary(context),
                        strokeCap: StrokeCap.round,
                      ),
                      Text("${(percent * 100).toInt()}%",
                          style: TextStyle(
                              color: AppTheme.primary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: AppTheme.primary(context).withValues(alpha: 0.05),
              color: AppTheme.primary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(StudentAttendance student, bool isPresent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isPresent
                ? AppTheme.greenOnline.withValues(alpha: 0.2)
                : AppTheme.border(context).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: student.image != null ? NetworkImage(student.image!) : null,
            child: student.image == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  Text(isPresent ? "Checked in • ${_formatTime(student.checkInTime?.second ?? 0)}" : "Not joined yet",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppTheme.textSecondary(context), fontSize: 11)),
                ],
              ),
              ),
          if (isPresent)
            const Icon(Icons.check_circle,
                color: AppTheme.greenOnline, size: 20)
          else
            Icon(Icons.info_outline,
                color: AppTheme.slate500(context).withValues(alpha: 0.5), size: 20),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.text(context),
                foregroundColor: AppTheme.bg(context),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("End Session",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: Icon(Icons.share_outlined, color: AppTheme.primary(context)),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  @override
  _PulseIndicatorState createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: AppTheme.primary(context), shape: BoxShape.circle)),
    );
  }
}
