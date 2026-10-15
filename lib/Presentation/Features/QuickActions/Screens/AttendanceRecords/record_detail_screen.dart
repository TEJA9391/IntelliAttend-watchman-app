import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Utils/responsive.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';

final DateFormat _fmtDate = DateFormat('MMM d, yyyy');
final DateFormat _fmtDateTime = DateFormat('MMM d, yyyy  h:mm a');
final DateFormat _fmtTime = DateFormat('h:mm a');

class RecordDetailScreen extends StatelessWidget {
  final AttendanceRecord record;

  const RecordDetailScreen({super.key, required this.record});

  static const Color _cPresent = Color(0xFF22C55E);
  static const Color _cAbsent = Color(0xFFEF4444);
  static const Color _cLate = Color(0xFFFBBF24);
  static const Color _cLeave = Color(0xFF2DD4BF);
  static const Color _cHoliday = Color(0xFF60A5FA);

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

  Color _syncColor(String status) => switch (status) {
        'synced' => _cPresent,
        'pending' => _cLate,
        'failed' => _cAbsent,
        _ => const Color(0xFF94A3B8),
      };

  IconData _syncIcon(String status) => switch (status) {
        'synced' => Icons.cloud_done_rounded,
        'pending' => Icons.cloud_upload_rounded,
        'failed' => Icons.cloud_off_rounded,
        _ => Icons.help_outline_rounded,
      };

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final sc = _sColor(record.status);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, r),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context, sc, r)),
                  SliverToBoxAdapter(child: _buildSessionInfo(context, r)),
                  if (record.remarks != null && record.remarks!.isNotEmpty)
                    SliverToBoxAdapter(child: _buildRemarks(context, r)),
                  if (record.notes != null && record.notes!.isNotEmpty)
                    SliverToBoxAdapter(child: _buildNotes(context, r)),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Responsive r) {
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
                  'Record Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.text(context),
                    fontSize: r.fontSizeL,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color sc, Responsive r) {
    return Container(
      margin: EdgeInsets.fromLTRB(r.paddingM, r.spacingS, r.paddingM, 0),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_sIcon(record.status), size: 28, color: sc),
              ),
              SizedBox(width: r.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: r.fontSizeL,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text(context),
                      ),
                    ),
                    SizedBox(height: r.spacingXS),
                    Text(
                      '${record.rollNumber}  \u2022  ${record.studentId}',
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
          SizedBox(height: r.spacingM),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: r.spacingM, vertical: r.spacingS),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_sIcon(record.status), size: r.iconM, color: sc),
                SizedBox(width: r.spacingS),
                Text(
                  _sLabel(record.status),
                  style: GoogleFonts.inter(
                    fontSize: r.fontSizeM,
                    fontWeight: FontWeight.w800,
                    color: sc,
                  ),
                ),
              ],
            ),
          ),
          if (record.attendancePercentage != null) ...[
            SizedBox(height: r.spacingM),
            Row(
              children: [
                Expanded(
                  child: _miniMetric(
                    context,
                    'Overall',
                    '${record.attendancePercentage!.toStringAsFixed(1)}%',
                    (record.attendancePercentage! >= 75)
                        ? _cPresent
                        : (record.attendancePercentage! >= 50)
                            ? _cLate
                            : _cAbsent,
                    r,
                  ),
                ),
                SizedBox(width: r.spacingS),
                Expanded(
                  child: _miniMetric(
                    context,
                    'Session',
                    _sLabel(record.status),
                    sc,
                    r,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniMetric(BuildContext context, String label, String value, Color c, Responsive r) {
    return Container(
      padding: EdgeInsets.all(r.spacingS),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: r.fontSizeXS * 0.8,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary(context))),
          SizedBox(height: r.spacingXS * 0.5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: r.fontSizeM,
                    fontWeight: FontWeight.w800,
                    color: c)),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfo(BuildContext context, Responsive r) {
    return _section(
      context,
      'Session Information',
      Icons.school_rounded,
      [
        _infoRow(context, 'Course', '${record.courseCode} - ${record.courseName}', r),
        _infoRow(context, 'Section', record.section, r),
        _infoRow(context, 'Date', _fmtDate.format(record.date), r),
        if (record.facultyName != null)
          _infoRow(context, 'Faculty', record.facultyName!, r),
        if (record.department != null)
          _infoRow(context, 'Department', record.department!, r),
        if (record.sessionType != null)
          _infoRow(context, 'Session Type',
              record.sessionType![0].toUpperCase() + record.sessionType!.substring(1), r),
        if (record.markedBy != null)
          _infoRow(context, 'Marked By',
              record.markedBy![0].toUpperCase() + record.markedBy!.substring(1), r),
      ],
      r,
    );
  }

  Widget _buildTimingInfo(BuildContext context, Responsive r) {
    return _section(
      context,
      'Timing Details',
      Icons.schedule_rounded,
      [
        if (record.checkInTime != null)
          _infoRow(context, 'Check In', _fmtDateTime.format(record.checkInTime!), r)
        else
          _infoRow(context, 'Check In', 'Not recorded', r),
        if (record.checkOutTime != null)
          _infoRow(context, 'Check Out', _fmtDateTime.format(record.checkOutTime!), r)
        else
          _infoRow(context, 'Check Out', 'Not recorded', r),
        if (record.checkInTime != null && record.checkOutTime != null)
          _infoRow(context, 'Duration',
              _formatDuration(record.checkOutTime!.difference(record.checkInTime!)), r),
      ],
      r,
    );
  }

  Widget _buildRemarks(BuildContext context, Responsive r) {
    return _section(
      context,
      'Remarks',
      Icons.comment_rounded,
      [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.spacingS),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            record.remarks!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: r.fontSizeS,
              color: AppTheme.text(context),
            ),
          ),
        ),
      ],
      r,
    );
  }

  Widget _buildNotes(BuildContext context, Responsive r) {
    return _section(
      context,
      'Notes',
      Icons.note_rounded,
      [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.spacingS),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            record.notes!,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: r.fontSizeS,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ),
      ],
      r,
    );
  }

  Widget _buildVerificationInfo(BuildContext context, Responsive r) {
    return _section(
      context,
      'Verification',
      Icons.verified_rounded,
      [
        Row(
          children: [
            Expanded(
              child: _verifyBadge(context, 'Location', record.locationVerified ?? false, Icons.location_on_rounded, r),
            ),
            SizedBox(width: r.spacingS),
            Expanded(
              child: _verifyBadge(context, 'Device', record.deviceVerified ?? false, Icons.phone_android_rounded, r),
            ),
          ],
        ),
      ],
      r,
    );
  }

  Widget _verifyBadge(BuildContext context, String label, bool verified, IconData icon, Responsive r) {
    final color = verified ? _cPresent : _cAbsent;
    return Container(
      padding: EdgeInsets.all(r.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: r.iconS, color: color),
          SizedBox(width: r.spacingXS),
          Flexible(
            child: Text(
              '$label: ${verified ? 'Verified' : 'Not Verified'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: r.fontSizeXS,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Responsive r) {
    return _section(
      context,
      'Record Metadata',
      Icons.info_outline_rounded,
      [
        _infoRow(context, 'Record ID', record.id, r),
        _infoRow(context, 'Student ID', record.studentId, r),
        _infoRow(context, 'Session ID', record.sessionId, r),
        if (record.syncStatus != null) _infoRow(context, 'Sync Status', record.syncStatus!, r),
      ],
      r,
    );
  }

  Widget _section(BuildContext context, String title, IconData icon, List<Widget> children, Responsive r) {
    return Container(
      margin: EdgeInsets.fromLTRB(r.paddingM, r.spacingS, r.paddingM, 0),
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
              Container(
                padding: EdgeInsets.all(r.spacingXS),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: r.iconS, color: AppTheme.accentTeal),
              ),
              SizedBox(width: r.spacingS),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: r.fontSizeS,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.text(context),
                ),
              ),
            ],
          ),
          SizedBox(height: r.spacingM),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, Responsive r) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.screenWidth * 0.3,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: r.fontSizeXS,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
          SizedBox(width: r.spacingS),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: r.fontSizeXS,
                fontWeight: FontWeight.w600,
                color: AppTheme.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
