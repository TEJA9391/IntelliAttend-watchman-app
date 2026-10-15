import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/Components/custom_app_bar.dart';

class LateStudentsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> roster;
  final Map<String, dynamic> cohort;
  final int lateCount;
  final int totalCount;
  final Set<String>? lateIds;

  const LateStudentsScreen({
    Key? key,
    required this.roster,
    required this.cohort,
    required this.lateCount,
    required this.totalCount,
    this.lateIds,
  }) : super(key: key);

  @override
  State<LateStudentsScreen> createState() => _LateStudentsScreenState();
}

class _LateStudentsScreenState extends State<LateStudentsScreen> {
  String _searchQuery = '';
  int _sortIndex = 0;

  List<Map<String, dynamic>> get _lateStudents {
    final ids = widget.lateIds;
    var list = widget.roster.where((s) {
      if (ids != null && ids.isNotEmpty) {
        final id = (s['id'] ?? s['roll_number'] ?? s['student_id'] ?? '').toString();
        return ids.contains(id);
      }
      final pct = _pct(s);
      return pct >= 0.50 && pct < 0.75;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final roll = (s['roll_number'] ?? '').toString().toLowerCase();
        return name.contains(q) || roll.contains(q);
      }).toList();
    }

    if (widget.lateIds != null && widget.lateIds!.isNotEmpty) {
      list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
    } else {
      switch (_sortIndex) {
        case 0:
          list.sort((a, b) => _pct(a).compareTo(_pct(b)));
          break;
        case 1:
          list.sort((a, b) => _pct(b).compareTo(_pct(a)));
          break;
        default:
          list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      }
    }

    return list;
  }

  Color _getAvatarColor(String name) {
    const colors = [
      Color(0xFF2DD4BF),
      Color(0xFF6366F1),
      Color(0xFFF43F5E),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  double _pct(Map<String, dynamic> s) {
    final a = (s['attended'] as num?)?.toDouble() ?? 0;
    final t = (s['total'] as num?)?.toDouble() ?? 1;
    return t > 0 ? a / t : 0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final students = _lateStudents;
    final avgDelay = students.isNotEmpty
        ? (students.map<double>(_pct).reduce((a, b) => a + b) / students.length * 100).toStringAsFixed(0)
        : '0';
    final textScaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBar(
        title: "Late Students",
        subtitle: "${widget.cohort['course_name'] ?? ''}",
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Hero(
                tag: 'attendance_late',
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFBBF24).withValues(alpha: 0.12),
                            const Color(0xFFFBBF24).withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.schedule_rounded, color: Color(0xFFFBBF24), size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${students.length} Students",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppTheme.text(context),
                                  fontSize: textScaler.scale(20),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "At Risk (50–74%)",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: textScaler.scale(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "$avgDelay%",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFFBBF24),
                                  fontSize: textScaler.scale(22),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Avg Attendance",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textSecondary(context),
                                  fontSize: textScaler.scale(10),
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
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: AppTheme.textSecondary(context), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: textScaler.scale(13)),
                            decoration: InputDecoration(
                              hintText: "Search by name or roll number...",
                              hintStyle: GoogleFonts.inter(
                                color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
                                fontSize: textScaler.scale(12),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _searchQuery = ''),
                            child: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context), size: 16),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildSortChip("Highest Risk", 0),
                      _buildSortChip("Lowest Risk", 1),
                      _buildSortChip("Name", 2),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          if (students.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 48, color: AppTheme.textSecondary(context).withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text("No at-risk students", style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: textScaler.scale(14))),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildStudentRow(context, students[i], textScaler),
                  childCount: students.length,
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, int index) {
    final selected = _sortIndex == index;
    const color = Color(0xFFFBBF24);
    final textScaler = MediaQuery.textScalerOf(context);
    return GestureDetector(
      onTap: () {
        HapticService.light();
        setState(() => _sortIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.3) : AppTheme.textSecondary(context).withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: selected ? color : AppTheme.textSecondary(context),
            fontSize: textScaler.scale(11),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRow(BuildContext context, Map<String, dynamic> student, TextScaler textScaler) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final name = student['name'] ?? 'Unknown';
    final roll = student['roll_number'] ?? '';
    final id = student['id'] ?? '';
    final pct = _pct(student);
    final attended = (student['attended'] as num?)?.toInt() ?? 0;
    final total = (student['total'] as num?)?.toInt() ?? 0;
    final missedCount = total - attended;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getAvatarColor(name.toString()).withValues(alpha: 0.3),
                    _getAvatarColor(name.toString()).withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${name.toString().isNotEmpty ? name[0] : 'S'}'.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: _getAvatarColor(name.toString()),
                    fontWeight: FontWeight.bold,
                    fontSize: textScaler.scale(16),
                  ),
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
                    name.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.text(context),
                      fontSize: textScaler.scale(13),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (roll.toString().isNotEmpty)
                        Flexible(
                          child: Text(
                            roll.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              color: AppTheme.textSecondary(context),
                              fontSize: textScaler.scale(10),
                            ),
                          ),
                        ),
                      if (roll.toString().isNotEmpty && id.toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(width: 1, height: 10, color: AppTheme.textSecondary(context).withValues(alpha: 0.2)),
                        ),
                      Flexible(
                        child: Text(
                          "$attended/$total classes",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary(context),
                            fontSize: textScaler.scale(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.lateIds != null && widget.lateIds!.isNotEmpty) ...[
                    const Icon(Icons.schedule_rounded, color: Color(0xFFFBBF24), size: 20),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Late",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFBBF24),
                          fontSize: textScaler.scale(10),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      "${(pct * 100).toInt()}%",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFBBF24),
                        fontWeight: FontWeight.bold,
                        fontSize: textScaler.scale(15),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (missedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "$missedCount missed",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFBBF24),
                            fontSize: textScaler.scale(9),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
