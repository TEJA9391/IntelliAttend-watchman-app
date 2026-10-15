import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Core/utils/haptic_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';

class SendNoticeScreen extends StatefulWidget {
  final String sectionId;
  final String courseCode;
  final String courseName;

  const SendNoticeScreen({
    Key? key,
    required this.sectionId,
    required this.courseCode,
    required this.courseName,
  }) : super(key: key);

  @override
  State<SendNoticeScreen> createState() => _SendNoticeScreenState();
}

class _SendNoticeScreenState extends State<SendNoticeScreen> {
  List<Map<String, dynamic>> _roster = [];
  final Set<String> _selectedStudents = {};
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _selectAllStudents = true;
  String _noticeType = 'general';

  final List<Map<String, String>> _noticeTypes = [
    {'value': 'general', 'label': 'General', 'icon': '📢'},
    {'value': 'attendance', 'label': 'Attendance Warning', 'icon': '⚠️'},
    {'value': 'assignment', 'label': 'Assignment', 'icon': '📚'},
    {'value': 'exam', 'label': 'Exam Update', 'icon': '📝'},
    {'value': 'meeting', 'label': 'Meeting', 'icon': '🤝'},
  ];

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _loadRoster() {
    try {
      final raw = PersistenceService.academicBox.get('roster_${widget.sectionId}');
      if (raw != null) {
        _roster = (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _selectAllStudentsInRoster();
      }
    } catch (e) {
      debugPrint("SendNotice: Error loading roster: $e");
    }
    if (mounted) setState(() {});
  }

  void _selectAllStudentsInRoster() {
    _selectedStudents.clear();
    for (final s in _roster) {
      final id = (s['id'] ?? s['roll_number'] ?? '').toString();
      if (id.isNotEmpty) _selectedStudents.add(id);
    }
  }

  void _toggleStudent(String id) {
    HapticHelper.lightImpact();
    setState(() {
      if (_selectedStudents.contains(id)) {
        _selectedStudents.remove(id);
        _selectAllStudents = false;
      } else {
        _selectedStudents.add(id);
        if (_selectedStudents.length == _roster.length) {
          _selectAllStudents = true;
        }
      }
    });
  }

  void _toggleSelectAll() {
    HapticHelper.lightImpact();
    setState(() {
      _selectAllStudents = !_selectAllStudents;
      if (_selectAllStudents) {
        _selectAllStudentsInRoster();
      } else {
        _selectedStudents.clear();
      }
    });
  }

  String _buildNoticeText() {
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final facultyName = FacultyService.profile.value?.name ?? 'Faculty';
    final selectedType = _noticeTypes.firstWhere((t) => t['value'] == _noticeType);
    final typeLabel = selectedType['label'] ?? 'General';

    final buffer = StringBuffer();
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("📋 ${widget.courseName}");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("");
    buffer.writeln("📌 Type: $typeLabel");
    buffer.writeln("📅 Date: $now");
    buffer.writeln("🏫 Course: ${widget.courseCode}");
    buffer.writeln("👤 From: $facultyName");
    buffer.writeln("");
    if (_subjectController.text.isNotEmpty) {
      buffer.writeln("Subject: ${_subjectController.text}");
      buffer.writeln("");
    }
    buffer.writeln(_messageController.text);
    buffer.writeln("");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("IntelliAttend Smart Campus");
    return buffer.toString();
  }

  String _buildEmailDraft() {
    final emails = _roster
        .where((s) => _selectedStudents.contains(s['id']?.toString() ?? s['roll_number']?.toString() ?? ''))
        .map((s) => s['email']?.toString())
        .where((e) => e != null && e.isNotEmpty)
        .toList();

    if (emails.isEmpty) return '';

    final toParam = emails.join(';');
    final subject = _subjectController.text.isNotEmpty
        ? Uri.encodeComponent(_subjectController.text)
        : Uri.encodeComponent("Notice: ${widget.courseCode} - ${_noticeTypes.firstWhere((t) => t['value'] == _noticeType)['label']}");
    final body = Uri.encodeComponent(_buildNoticeText());

    return "mailto:$toParam?subject=$subject&body=$body";
  }

  void _shareNotice() {
    if (_subjectController.text.isEmpty && _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a subject or message", style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Select at least one student", style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    Share.share(
      _buildNoticeText(),
      subject: _subjectController.text.isNotEmpty
          ? _subjectController.text
          : "Notice: ${widget.courseCode}",
    );
  }

  void _shareViaEmail() {
    if (_subjectController.text.isEmpty && _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a subject or message", style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final emailCount = _roster
        .where((s) => _selectedStudents.contains(s['id']?.toString() ?? s['roll_number']?.toString() ?? ''))
        .where((s) => (s['email']?.toString() ?? '').isNotEmpty)
        .length;

    if (emailCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No student emails available", style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final url = _buildEmailDraft();
    if (url.isNotEmpty) {
      Share.shareUri(Uri.parse(url));
    } else {
      Share.share(_buildNoticeText());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Send Notice",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _shareNotice,
            child: Icon(Icons.share_rounded, color: AppTheme.accentTeal, size: 20),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNoticeTypeSelector(),
            const SizedBox(height: 20),
            _buildSubjectField(),
            const SizedBox(height: 16),
            _buildMessageField(),
            const SizedBox(height: 20),
            _buildRecipientSection(),
            const SizedBox(height: 24),
            _buildSendButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeTypeSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Notice Type",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _noticeTypes.map((type) {
              final selected = _noticeType == type['value'];
              return GestureDetector(
                onTap: () {
                  HapticHelper.lightImpact();
                  setState(() => _noticeType = type['value']!);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.accentTeal.withValues(alpha: 0.15) : AppTheme.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppTheme.accentTeal.withValues(alpha: 0.4) : AppTheme.border(context),
                    ),
                  ),
                  child: Text(
                    "${type['icon']} ${type['label']}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: selected ? AppTheme.accentTeal : AppTheme.text(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectField() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Subject",
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _subjectController,
            style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: "Enter notice subject...",
              hintStyle: GoogleFonts.inter(
                color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageField() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Message",
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _messageController,
            maxLines: 6,
            style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: "Type your notice message...",
              hintStyle: GoogleFonts.inter(
                color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                "Recipients (${_selectedStudents.length}/${_roster.length})",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: _toggleSelectAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectAllStudents ? "Deselect All" : "Select All",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppTheme.accentTeal, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_roster.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Center(
              child: Text("No students in roster", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 13)),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _roster.length,
              itemBuilder: (context, index) {
                final student = _roster[index];
                final id = (student['id'] ?? student['roll_number'] ?? '').toString();
                final name = (student['name'] ?? 'Unknown').toString();
                final email = (student['email'] ?? '').toString();
                final isSelected = _selectedStudents.contains(id);

                return InkWell(
                  onTap: () => _toggleStudent(id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary(context).withValues(alpha: 0.3),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSendButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _shareNotice,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text("Share Notice", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareViaEmail,
            icon: const Icon(Icons.email_outlined, size: 18),
            label: Text("Email Draft", maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentTeal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: AppTheme.accentTeal.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ],
    );
  }
}
