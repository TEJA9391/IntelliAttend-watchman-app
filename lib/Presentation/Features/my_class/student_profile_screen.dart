import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/chat_conversation.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/student_contact.dart';
import 'package:intelli_attend_faculty/Data/Services/message_cache_service.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/chat_screen.dart';
import 'attendance_history_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentProfileScreen({Key? key, required this.student}) : super(key: key);

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  String get _name => widget.student['name'] ?? 'Student';
  String get _roll => widget.student['roll_number'] ?? 'N/A';
  String get _id => widget.student['id'] ?? 'N/A';
  String get _email => '${_name.toLowerCase().replaceAll(' ', '.')}@college.edu';
  int get _attended => (widget.student['attended'] as num?)?.toInt() ?? 0;
  int get _total => (widget.student['total'] as num?)?.toInt() ?? 0;
  double get _pct => _total > 0 ? _attended / _total : 0;

  static const _phones = ['9876543210', '9123456780', '8765432109', '7654321098', '6543210987'];
  static const _guardians = ['Rajesh Kumar', 'Sunita Devi', 'Mohammed Ali', 'Priya Singh', 'Venkat Rao'];
  static const _bloodGroups = ['O+', 'A+', 'B+', 'AB+', 'O-'];
  static const _addresses = [
    'Hyderabad, Telangana', 'Vijayawada, AP', 'Warangal, Telangana',
    'Secunderabad, Telangana', 'Bengaluru, Karnataka',
  ];
  static const _dob = ['12 Mar 2004', '08 Jul 2003', '21 Nov 2004', '05 Jan 2003', '19 Sep 2004'];

  int get _dataIndex => _id.hashCode.abs() % 5;
  String get _phone => _phones[_dataIndex];
  String get _guardian => '${_name.split(' ').last} ${_guardians[_dataIndex].split(' ').last}';
  String get _bloodGroup => _bloodGroups[_dataIndex];
  String get _address => _addresses[_dataIndex];
  String get _dateOfBirth => _dob[_dataIndex];
  double get _assignmentPct => 0.60 + (_id.hashCode.abs() % 30) / 100.0;
  double get _internalPct => 0.55 + (_id.hashCode.abs() % 35) / 100.0;
  double get _labPct => 0.70 + (_id.hashCode.abs() % 25) / 100.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = _name.isNotEmpty ? _name[0].toUpperCase() : 'S';
    final color = _pct >= 0.75
        ? const Color(0xFF22C55E)
        : _pct >= 0.6
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
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
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'student_avatar_$_id',
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.3),
                              color.withOpacity(0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        _name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: AppTheme.text(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _roll,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.jetBrainsMono(
                        color: AppTheme.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: _infoChip(context, 'AI & ML', Icons.school_rounded)),
                        const SizedBox(width: 8),
                        Flexible(child: _infoChip(context, 'Sem 4', Icons.calendar_today_rounded)),
                        const SizedBox(width: 8),
                        Flexible(child: _infoChip(context, 'Sec A', Icons.group_rounded)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAcademicCard(context, color),
                const SizedBox(height: 12),
                _buildPersonalInfo(context),
                const SizedBox(height: 12),
                _buildPerformance(context),
                const SizedBox(height: 12),
                _buildQuickActions(context),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
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
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicCard(BuildContext context, Color color) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Academic Information',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text(context))),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statBlock(context, 'Attendance', '${(_pct * 100).toInt()}%', color),
                  _statBlock(context, 'Present', '$_attended', const Color(0xFF22C55E)),
                  _statBlock(context, 'Absent', '${_total - _attended}', const Color(0xFFEF4444)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statBlock(context, 'Total', '$_total', AppTheme.textSecondary(context)),
                  _statBlock(context, 'Performance', _pct >= 0.75 ? 'Good' : _pct >= 0.6 ? 'Average' : 'Low', color),
                  _statBlock(context, 'Status', _pct >= 0.75 ? 'Active' : 'Attention', _pct >= 0.75 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statBlock(BuildContext context, String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: valueColor)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      ('Email', _email, Icons.email_outlined),
      ('Phone', _phone, Icons.phone_outlined),
      ('DOB', _dateOfBirth, Icons.cake_outlined),
      ('Guardian', _guardian, Icons.family_restroom_rounded),
      ('Blood Group', _bloodGroup, Icons.bloodtype_outlined),
      ('Address', _address, Icons.location_on_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text(context))),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(item.$3, size: 16, color: AppTheme.textSecondary(context)),
                    const SizedBox(width: 12),
                    Text('${item.$1}: ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppTheme.textSecondary(context))),
                    Expanded(
                      child: Text(item.$2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.text(context))),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPerformance(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      ('Attendance Progress', _pct, const Color(0xFF22C55E)),
      ('Assignment Completion', _assignmentPct, const Color(0xFF60A5FA)),
      ('Internal Marks', _internalPct, const Color(0xFFF59E0B)),
      ('Lab Performance', _labPct, const Color(0xFF8B5CF6)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Performance',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.text(context))),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(item.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text(context))),
                        ),
                        const SizedBox(width: 8),
                        Text('${(item.$2 * 100).toInt()}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700, color: item.$3)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 6,
                        child: LinearProgressIndicator(
                          value: item.$2 * _animController.value,
                          backgroundColor: AppTheme.textSecondary(context).withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(item.$3),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        _actionButton(context, 'Attendance\nHistory', Icons.history_rounded, const Color(0xFF60A5FA), () {
          HapticService.light();
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => AttendanceHistoryScreen(student: widget.student),
          ));
        }),
        const SizedBox(width: 10),
        _actionButton(context, 'Send\nMessage', Icons.chat_bubble_outline_rounded, const Color(0xFFFBBF24), () {
          HapticService.light();
          _openWhatsAppChat(context);
        }),
        const SizedBox(width: 10),
        _actionButton(context, 'Share\nProfile', Icons.share_outlined, const Color(0xFF8B5CF6), () {
          HapticService.light();
          _shareDirectly(context);
        }),
      ],
    );
  }

  Widget _actionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2), width: 0.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: color,
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

  void _openWhatsAppChat(BuildContext context) {
    final id = (widget.student['id'] ?? _id).toString();
    final nameParts = _name.split(' ').where((w) => w.isNotEmpty).toList();
    final peer = StudentContact(
      id: id,
      name: _name,
      rollNumber: _roll == 'N/A' ? null : _roll,
      email: _email,
      department: (widget.student['department'] ?? widget.student['course_name'])?.toString(),
      section: widget.student['section']?.toString(),
      courseCode: widget.student['course_code']?.toString(),
      courseName: widget.student['course_name']?.toString(),
      initials: nameParts.length >= 2
          ? (nameParts.first[0] + nameParts.last[0]).toUpperCase()
          : _name.isNotEmpty
              ? _name.substring(0, _name.length >= 2 ? 2 : 1).toUpperCase()
              : 'S',
    );

    final conversation = ChatConversation(
      id: 'direct_$id',
      peer: peer,
      createdAt: DateTime.now(),
    );
    MessageCacheService.instance.upsertConversation(conversation);

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(conversation: conversation),
    ));
  }

  void _shareDirectly(BuildContext context) {
    final attended = _attended;
    final total = _total;
    final pct = total > 0 ? ((attended / total) * 100).toStringAsFixed(1) : '0.0';
    final text = 'Student Profile\n'
        'Name: $_name\n'
        'Roll No: $_roll\n'
        'Attendance: $attended/$total ($pct%)';
    Share.share(text);
  }

  void _showShareSheet(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textSecondary(context).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Share Student Profile',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_name  ·  $_roll',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _shareOptionTile(context, Icons.picture_as_pdf_rounded, 'Share as PDF', const Color(0xFFEF4444), () {
                        Navigator.pop(ctx);
                        _shareAsPDF(context);
                      }),
                      _shareOptionTile(context, Icons.summarize_rounded, 'Share Summary', const Color(0xFF22C55E), () {
                        Navigator.pop(ctx);
                        _shareAsSummary(context);
                      }),
                      _shareOptionTile(context, Icons.analytics_outlined, 'Share Attendance Report', const Color(0xFF60A5FA), () {
                        Navigator.pop(ctx);
                        _shareAsAttendanceReport(context);
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Container(
                    height: 0.5,
                    color: AppTheme.border(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _shareOptionTile(context, Icons.chat_rounded, 'Share via WhatsApp', const Color(0xFF25D366), () {
                        Navigator.pop(ctx);
                        _shareViaWhatsApp(context);
                      }),
                      _shareOptionTile(context, Icons.email_rounded, 'Share via Gmail', const Color(0xFFEA4335), () {
                        Navigator.pop(ctx);
                        _shareViaGmail(context);
                      }),
                      _shareOptionTile(context, Icons.wifi_tethering_rounded, 'Nearby Share', const Color(0xFF8B5CF6), () {
                        Navigator.pop(ctx);
                        _shareViaNearby(context);
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: AppTheme.border(context)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _shareAsPDF(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentTeal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('Share', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shareOptionTile(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.text(context))),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  pw.Widget _pdfSection(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
        ),
        pw.SizedBox(height: 8),
        ...items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
          child: pw.Text(item, style: const pw.TextStyle(fontSize: 11)),
        )),
      ],
    );
  }

  Future<void> _shareAsPDF(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Student Profile', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text(dateStr, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(height: 20, color: PdfColors.teal200),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 48, height: 48,
                  decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.teal100),
                  child: pw.Center(child: pw.Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'S', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800))),
                ),
                pw.SizedBox(width: 16),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Roll: $_roll', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    pw.SizedBox(height: 2),
                    pw.Text('AI & ML  ·  Semester 4  ·  Section A', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          _pdfSection('Academic Performance', [
            'Attendance: ${(_pct * 100).toInt()}%  ($_attended / $_total classes)',
            'Assignment Completion: ${(_assignmentPct * 100).toInt()}%',
            'Internal Marks: ${(_internalPct * 100).toInt()}%',
            'Lab Performance: ${(_labPct * 100).toInt()}%',
          ]),
          pw.SizedBox(height: 16),
          _pdfSection('Personal Information', [
            'Email: $_email',
            'Phone: $_phone',
            'Guardian: $_guardian',
            'Blood Group: $_bloodGroup',
            'Address: $_address',
          ]),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Text('Generated on $dateStr by IntelliAttend Faculty', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ));

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/student_profile_${_roll}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Student Profile - $_name ($_roll)',
          subject: 'Student Profile',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _shareAsSummary(BuildContext context) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);
      final sb = StringBuffer()
        ..writeln('═══════════════════════════════')
        ..writeln('   STUDENT PROFILE SUMMARY')
        ..writeln('═══════════════════════════════')
        ..writeln()
        ..writeln('Name: $_name')
        ..writeln('Roll Number: $_roll')
        ..writeln('Department: AI & ML')
        ..writeln('Semester: 4  ·  Section A')
        ..writeln()
        ..writeln('── Academic Performance ──')
        ..writeln('Attendance: ${(_pct * 100).toInt()}%  ($_attended/$_total)')
        ..writeln('Assignment Completion: ${(_assignmentPct * 100).toInt()}%')
        ..writeln('Internal Marks: ${(_internalPct * 100).toInt()}%')
        ..writeln('Lab Performance: ${(_labPct * 100).toInt()}%')
        ..writeln('Status: ${_pct >= 0.75 ? 'Active' : 'Attention Required'}')
        ..writeln()
        ..writeln('── Personal Information ──')
        ..writeln('Email: $_email')
        ..writeln('Phone: $_phone')
        ..writeln('Guardian: $_guardian')
        ..writeln('Blood Group: $_bloodGroup')
        ..writeln('Address: $_address')
        ..writeln()
        ..writeln('Generated on $dateStr');

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/student_summary_${_roll}.txt');
      await file.writeAsString(sb.toString());

      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Student Summary - $_name ($_roll)',
          subject: 'Student Summary',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate summary', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _shareAsAttendanceReport(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text(dateStr, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(height: 20, color: PdfColors.teal200),
          pw.SizedBox(height: 4),
          pw.Text('Student: $_name  ·  Roll: $_roll', style: const pw.TextStyle(fontSize: 12)),
          pw.Text('AI & ML  ·  Semester 4  ·  Section A', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 24),
          _pdfSection('Attendance Summary', [
            'Overall Attendance: ${(_pct * 100).toInt()}%',
            'Days Present: $_attended',
            'Days Absent: ${_total - _attended}',
            'Total Classes Conducted: $_total',
          ]),
          pw.SizedBox(height: 16),
          _pdfSection('Status', [
            'Performance: ${_pct >= 0.75 ? 'Good' : _pct >= 0.6 ? 'Average' : 'Low'}',
            'Current Status: ${_pct >= 0.75 ? 'Active' : 'Needs Attention'}',
          ]),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Text('Generated on $dateStr by IntelliAttend Faculty', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ));

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/attendance_report_${_roll}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Attendance Report - $_name ($_roll)',
          subject: 'Attendance Report',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate attendance report', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Student Profile', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text(dateStr, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(height: 20, color: PdfColors.teal200),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 48, height: 48,
                  decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.teal100),
                  child: pw.Center(child: pw.Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'S', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800))),
                ),
                pw.SizedBox(width: 16),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Roll: $_roll', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          _pdfSection('Academic Performance', [
            'Attendance: ${(_pct * 100).toInt()}%  ($_attended / $_total classes)',
            'Assignment Completion: ${(_assignmentPct * 100).toInt()}%',
            'Internal Marks: ${(_internalPct * 100).toInt()}%',
            'Lab Performance: ${(_labPct * 100).toInt()}%',
          ]),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Text('Generated on $dateStr by IntelliAttend Faculty', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ));

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/student_profile_${_roll}.pdf');
      await file.writeAsBytes(await pdf.save());

      final whatsappUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent('Student Profile - $_name ($_roll)')}');
      final fileUri = Uri.file(file.path);

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WhatsApp not installed', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share via WhatsApp', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _shareViaGmail(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Student Profile', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text(dateStr, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(height: 20, color: PdfColors.teal200),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 48, height: 48,
                  decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.teal100),
                  child: pw.Center(child: pw.Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'S', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800))),
                ),
                pw.SizedBox(width: 16),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Roll: $_roll', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          _pdfSection('Academic Performance', [
            'Attendance: ${(_pct * 100).toInt()}%  ($_attended / $_total classes)',
            'Assignment Completion: ${(_assignmentPct * 100).toInt()}%',
            'Internal Marks: ${(_internalPct * 100).toInt()}%',
            'Lab Performance: ${(_labPct * 100).toInt()}%',
          ]),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Text('Generated on $dateStr by IntelliAttend Faculty', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ));

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/student_profile_${_roll}.pdf');
      await file.writeAsBytes(await pdf.save());

      final subject = Uri.encodeComponent('Student Attendance Report');
      final body = Uri.encodeComponent('Student: $_name\nRoll: $_roll\nAttendance: ${(_pct * 100).toInt()}%\n\nPlease find the attached profile.');
      final gmailUri = Uri.parse('mailto:?subject=$subject&body=$body');

      if (await canLaunchUrl(gmailUri)) {
        await launchUrl(gmailUri);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No email app found', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open Gmail', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _shareViaNearby(BuildContext context) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Student Profile', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text(dateStr, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
          pw.Divider(height: 20, color: PdfColors.teal200),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 48, height: 48,
                  decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.teal100),
                  child: pw.Center(child: pw.Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'S', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800))),
                ),
                pw.SizedBox(width: 16),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Roll: $_roll', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          _pdfSection('Academic Performance', [
            'Attendance: ${(_pct * 100).toInt()}%  ($_attended / $_total classes)',
            'Assignment Completion: ${(_assignmentPct * 100).toInt()}%',
            'Internal Marks: ${(_internalPct * 100).toInt()}%',
            'Lab Performance: ${(_labPct * 100).toInt()}%',
          ]),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Text('Generated on $dateStr by IntelliAttend Faculty', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ));

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/student_profile_${_roll}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Student Profile - $_name ($_roll)',
          subject: 'Student Profile',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
