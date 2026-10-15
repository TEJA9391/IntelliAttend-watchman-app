import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:dio/dio.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String sectionId;
  final String courseCode;
  final String courseName;

  const MarkAttendanceScreen({
    Key? key,
    required this.sectionId,
    required this.courseCode,
    required this.courseName,
  }) : super(key: key);

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  List<Map<String, dynamic>> _roster = [];
  List<Map<String, dynamic>> _filteredRoster = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _activeSessionId;
  final Set<String> _selectedStudents = {};
  String _selectedReason = 'late_arrival';

  final List<Map<String, String>> _reasons = [
    {'value': 'late_arrival', 'label': 'Late Arrival', 'icon': '🕐'},
    {'value': 'missed_scan', 'label': 'Missed Scan', 'icon': '📱'},
    {'value': 'system_error', 'label': 'System Error', 'icon': '⚙️'},
    {'value': 'other', 'label': 'Other', 'icon': '📝'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _loadRoster();
      await _fetchActiveSession();
    } catch (e) {
      debugPrint("MarkAttendance: Load error: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _loadRoster() {
    try {
      final raw = PersistenceService.academicBox.get('roster_${widget.sectionId}');
      if (raw != null) {
        _roster = (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
        _filteredRoster = List.from(_roster);
      }
    } catch (e) {
      debugPrint("MarkAttendance: Error loading roster: $e");
    }
  }

  Future<void> _fetchActiveSession() async {
    try {
      final response = await ApiClient().dio.get(
        '/api/v1/session/current-state',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final state = data['state']?.toString() ?? '';
        if (state != 'IDLE' && state != 'CLOSED') {
          _activeSessionId = data['session_id']?.toString();
        }
      }
    } catch (e) {
      debugPrint("MarkAttendance: Session check error: $e");
    }
  }

  void _filterRoster(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredRoster = List.from(_roster);
      } else {
        final q = query.toLowerCase();
        _filteredRoster = _roster.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final roll = (s['roll_number'] ?? '').toString().toLowerCase();
          final id = (s['id'] ?? '').toString().toLowerCase();
          return name.contains(q) || roll.contains(q) || id.contains(q);
        }).toList();
      }
    });
  }

  void _toggleStudent(String studentId) {
    HapticService.light();
    setState(() {
      if (_selectedStudents.contains(studentId)) {
        _selectedStudents.remove(studentId);
      } else {
        _selectedStudents.add(studentId);
      }
    });
  }

  void _selectAll() {
    HapticService.light();
    setState(() {
      if (_selectedStudents.length == _filteredRoster.length) {
        _selectedStudents.clear();
      } else {
        _selectedStudents.clear();
        for (final s in _filteredRoster) {
          final id = s['id'] ?? s['roll_number'] ?? '';
          if (id.toString().isNotEmpty) {
            _selectedStudents.add(id.toString());
          }
        }
      }
    });
  }

  Future<void> _submitAttendance() async {
    if (_activeSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No active session found. Start a session first.", style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEF4444),
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

    setState(() => _isSubmitting = true);

    int successCount = 0;
    int failCount = 0;

    for (final studentId in _selectedStudents) {
      final student = _roster.firstWhere(
        (s) => (s['id']?.toString() == studentId || s['roll_number']?.toString() == studentId),
        orElse: () => {},
      );
      final studentEmail = student['email']?.toString() ?? '';

      if (studentEmail.isEmpty) {
        failCount++;
        continue;
      }

      try {
        final response = await ApiClient().dio.post(
          '/api/v1/faculty/attendance/correction',
          data: {
            'session_id': _activeSessionId,
            'student_id': studentEmail,
            'reason': _selectedReason,
          },
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          successCount++;
        } else {
          failCount++;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          failCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      _selectedStudents.clear();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.card(context),
          title: Text(
            "Attendance Updated",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (successCount > 0)
                _buildResultRow(context, "$successCount students marked present", const Color(0xFF2DD4BF), Icons.check_circle_rounded),
              if (failCount > 0)
                _buildResultRow(context, "$failCount students failed", const Color(0xFFEF4444), Icons.error_rounded),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: GoogleFonts.inter(color: AppTheme.accentTeal, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildResultRow(BuildContext context, String text, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14))),
        ],
      ),
    );
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
          "Mark Attendance",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (_selectedStudents.isNotEmpty)
            TextButton(
              onPressed: _isSubmitting ? null : _submitAttendance,
              child: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2DD4BF)))
                  : Text(
                      "Submit (${_selectedStudents.length})",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: const Color(0xFF2DD4BF), fontWeight: FontWeight.bold),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentTeal))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSessionBanner(),
        _buildReasonSelector(),
        _buildSearchAndSelectAll(),
        Expanded(child: _buildStudentList()),
      ],
    );
  }

  Widget _buildSessionBanner() {
    final hasSession = _activeSessionId != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasSession
            ? const Color(0xFF2DD4BF).withValues(alpha: 0.1)
            : const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSession
              ? const Color(0xFF2DD4BF).withValues(alpha: 0.3)
              : const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasSession ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: hasSession ? const Color(0xFF2DD4BF) : const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasSession ? "Active session — marking will update live" : "No active session — start one first",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: hasSession ? const Color(0xFF2DD4BF) : const Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reason for marking",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _reasons.map((r) {
                final selected = _selectedReason == r['value'];
                return GestureDetector(
                  onTap: () {
                    HapticService.light();
                    setState(() => _selectedReason = r['value']!);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.accentTeal.withValues(alpha: 0.15) : AppTheme.card(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppTheme.accentTeal.withValues(alpha: 0.4)
                            : AppTheme.border(context),
                      ),
                    ),
                    child: Text(
                      "${r['icon']} ${r['label']}",
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
      ),
    );
  }

  Widget _buildSearchAndSelectAll() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: AppTheme.textSecondary(context), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: _filterRoster,
                      style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Search students...",
                        hintStyle: GoogleFonts.inter(
                          color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _selectAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.25)),
              ),
              child: Text(
                _selectedStudents.length == _filteredRoster.length && _filteredRoster.isNotEmpty ? "Deselect All" : "Select All",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: AppTheme.accentTeal, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_filteredRoster.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: AppTheme.textSecondary(context).withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text("No students found", maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _filteredRoster.length,
      itemBuilder: (context, index) {
        final student = _filteredRoster[index];
        final id = (student['id'] ?? student['roll_number'] ?? '').toString();
        final name = (student['name'] ?? 'Unknown').toString();
        final roll = (student['roll_number'] ?? '').toString();
        final attended = (student['attended'] as num?)?.toInt() ?? 0;
        final total = (student['total'] as num?)?.toInt() ?? 0;
        final pct = total > 0 ? attended / total : 0.0;
        final isSelected = _selectedStudents.contains(id);
        final pctColor = pct >= 0.75 ? const Color(0xFF2DD4BF) : pct >= 0.60 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444);

        return GestureDetector(
          onTap: () => _toggleStudent(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentTeal.withValues(alpha: 0.08)
                  : AppTheme.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppTheme.accentTeal.withValues(alpha: 0.4)
                    : AppTheme.border(context),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accentTeal : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppTheme.accentTeal : AppTheme.textSecondary(context).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: pctColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${name.isNotEmpty ? name[0] : 'S'}'.toUpperCase(),
                      style: GoogleFonts.inter(color: pctColor, fontWeight: FontWeight.bold, fontSize: 14),
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        roll.isNotEmpty ? "$roll · $attended/$total" : "$attended/$total classes",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${(pct * 100).toInt()}%",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: pctColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation(pctColor),
                          minHeight: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
