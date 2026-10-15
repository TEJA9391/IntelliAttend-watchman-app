import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/Components/custom_app_bar.dart';

class PresentStudentsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> roster;
  final Map<String, dynamic> cohort;
  final int presentCount;
  final int totalCount;
  final Set<String>? presentIds;

  const PresentStudentsScreen({
    Key? key,
    required this.roster,
    required this.cohort,
    required this.presentCount,
    required this.totalCount,
    this.presentIds,
  }) : super(key: key);

  @override
  State<PresentStudentsScreen> createState() => _PresentStudentsScreenState();
}

class _PresentStudentsScreenState extends State<PresentStudentsScreen> {
  String _searchQuery = '';
  String _searchTypeIndex = 'Name';

  List<Map<String, dynamic>> get _presentStudents {
    final ids = widget.presentIds;
    var list = widget.roster.where((s) {
      if (ids != null && ids.isNotEmpty) {
        final id = (s['id'] ?? s['roll_number'] ?? s['student_id'] ?? '').toString();
        return ids.contains(id);
      }
      return _pct(s) >= 0.75;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final roll = (s['roll_number'] ?? '').toString().toLowerCase();
        final id = (s['id'] ?? '').toString().toLowerCase();
        switch (_searchTypeIndex) {
          case 'Roll No':
            return roll.contains(q);
          case 'ID':
            return id.contains(q);
          default:
            return name.contains(q) || roll.contains(q);
        }
      }).toList();
    }

    if (widget.presentIds == null || widget.presentIds!.isEmpty) {
      list.sort((a, b) => _pct(b).compareTo(_pct(a)));
    } else {
      list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
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
    final percentage = widget.totalCount > 0
        ? ((widget.presentCount / widget.totalCount) * 100).toStringAsFixed(1)
        : '0.0';
    final students = _presentStudents;
    final textScaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBar(
        title: "Present Students",
        subtitle: "${widget.cohort['course_name'] ?? ''}",
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Hero(
                tag: 'attendance_present',
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2DD4BF).withValues(alpha: 0.12),
                            const Color(0xFF2DD4BF).withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2DD4BF), size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${widget.presentCount} Students",
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
                                "Present Today",
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
                                "$percentage%",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF2DD4BF),
                                  fontSize: textScaler.scale(22),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM yyyy').format(DateTime.now()),
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
                              hintText: "Search by ${_searchTypeIndex.toLowerCase()}...",
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
                    children: ['Name', 'Roll No', 'ID'].map((type) {
                      final selected = _searchTypeIndex == type;
                      return GestureDetector(
                        onTap: () {
                          HapticService.light();
                          setState(() {
                            _searchTypeIndex = type;
                            _searchQuery = '';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF2DD4BF).withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF2DD4BF).withValues(alpha: 0.3)
                                  : AppTheme.textSecondary(context).withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.inter(
                              color: selected ? const Color(0xFF2DD4BF) : AppTheme.textSecondary(context),
                              fontSize: textScaler.scale(10),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
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
                    Text("No present students", style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: textScaler.scale(14))),
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

  Widget _buildStudentRow(BuildContext context, Map<String, dynamic> student, TextScaler textScaler) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final name = student['name'] ?? 'Unknown';
    final roll = student['roll_number'] ?? '';
    final id = student['id'] ?? '';
    final attended = (student['attended'] as num?)?.toInt() ?? 0;
    final total = (student['total'] as num?)?.toInt() ?? 0;

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
                      if (id.toString().isNotEmpty)
                        Flexible(
                          child: Text(
                            id.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              color: AppTheme.textSecondary(context).withValues(alpha: 0.6),
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
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF2DD4BF), size: 20),
                  const SizedBox(height: 2),
                  if (widget.presentIds != null && widget.presentIds!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Present",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2DD4BF),
                          fontSize: textScaler.scale(10),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Text(
                      "$attended/$total",
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
    );
  }
}
