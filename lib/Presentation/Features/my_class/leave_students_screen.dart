import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/Components/custom_app_bar.dart';

class LeaveStudentsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> roster;
  final Map<String, dynamic> cohort;
  final int leaveCount;
  final int totalCount;

  const LeaveStudentsScreen({
    Key? key,
    required this.roster,
    required this.cohort,
    required this.leaveCount,
    required this.totalCount,
  }) : super(key: key);

  @override
  State<LeaveStudentsScreen> createState() => _LeaveStudentsScreenState();
}

class _LeaveStudentsScreenState extends State<LeaveStudentsScreen> {
  String _searchQuery = '';
  int _statusFilter = 0;

  final List<Map<String, dynamic>> _leaveRecords = [];

  List<Map<String, dynamic>> get _filteredLeaves {
    if (_leaveRecords.isEmpty) return [];

    var list = List<Map<String, dynamic>>.from(_leaveRecords);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final name = (s['student_name'] ?? s['name'] ?? '').toString().toLowerCase();
        final roll = (s['roll_number'] ?? '').toString().toLowerCase();
        return name.contains(q) || roll.contains(q);
      }).toList();
    }

    if (_statusFilter == 1) {
      list = list.where((s) => (s['status'] ?? '') == 'Approved').toList();
    } else if (_statusFilter == 2) {
      list = list.where((s) => (s['status'] ?? '') == 'Pending').toList();
    } else if (_statusFilter == 3) {
      list = list.where((s) => (s['status'] ?? '') == 'Rejected').toList();
    }

    return list;
  }

  int get _approvedCount => _leaveRecords.where((s) => (s['status'] ?? '') == 'Approved').length;
  int get _pendingCount => _leaveRecords.where((s) => (s['status'] ?? '') == 'Pending').length;
  int get _rejectedCount => _leaveRecords.where((s) => (s['status'] ?? '') == 'Rejected').length;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final leaves = _filteredLeaves;
    final textScaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBar(
        title: "Students on Leave",
        subtitle: "${widget.cohort['course_name'] ?? ''}",
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
          // Leave Stats Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Hero(
                tag: 'attendance_leave',
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF60A5FA).withValues(alpha: 0.12),
                            const Color(0xFF60A5FA).withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.event_busy_rounded, color: Color(0xFF60A5FA), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${_leaveRecords.length} Total",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.text(context),
                                      fontSize: textScaler.scale(18),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Leave Requests",
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _buildMiniStat("$_approvedCount", "Approved", const Color(0xFF2DD4BF), textScaler)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildMiniStat("$_pendingCount", "Pending", const Color(0xFFFBBF24), textScaler)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildMiniStat("$_rejectedCount", "Rejected", const Color(0xFFEF4444), textScaler)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ),
          ),

          // Search and Filter
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
                              hintText: "Search by name...",
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
                      _buildFilterChip("All", 0, AppTheme.accentTeal, textScaler),
                      _buildFilterChip("Approved", 1, const Color(0xFF2DD4BF), textScaler),
                      _buildFilterChip("Pending", 2, const Color(0xFFFBBF24), textScaler),
                      _buildFilterChip("Rejected", 3, const Color(0xFFEF4444), textScaler),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Leave List or Empty State
          if (leaves.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_available_rounded, size: 48, color: AppTheme.textSecondary(context).withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text(
                      _leaveRecords.isEmpty ? "No leave records found" : "No matching leaves",
                      style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: textScaler.scale(14)),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildLeaveRow(context, leaves[i], textScaler),
                  childCount: leaves.length,
                ),
              ),
            ),
        ],
        ),
      ),
    );
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

  Widget _buildMiniStat(String value, String label, Color color, TextScaler textScaler) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: color,
              fontSize: textScaler.scale(16),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary(context),
              fontSize: textScaler.scale(11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, Color color, TextScaler textScaler) {
    final selected = _statusFilter == index;
    return GestureDetector(
      onTap: () {
        HapticService.light();
        setState(() => _statusFilter = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            fontSize: textScaler.scale(10),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveRow(BuildContext context, Map<String, dynamic> leave, TextScaler textScaler) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final name = leave['student_name'] ?? leave['name'] ?? 'Unknown';
    final leaveType = leave['leave_type'] ?? 'Personal';
    final reason = leave['reason'] ?? 'No reason provided';
    final date = leave['date'] ?? leave['leave_date'] ?? '';
    final status = leave['status'] ?? 'Pending';

    Color statusColor;
    switch (status) {
      case 'Approved':
        statusColor = const Color(0xFF2DD4BF);
        break;
      case 'Rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFFFBBF24);
    }

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getAvatarColor(name.toString()).withValues(alpha: 0.3),
                        _getAvatarColor(name.toString()).withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${name.toString().isNotEmpty ? name[0] : 'S'}'.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: _getAvatarColor(name.toString()),
                        fontWeight: FontWeight.bold,
                        fontSize: textScaler.scale(14),
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
                      const SizedBox(height: 2),
                      Text(
                        leaveType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary(context),
                          fontSize: textScaler.scale(11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: statusColor,
                        fontSize: textScaler.scale(10),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary(context),
                fontSize: textScaler.scale(12),
                height: 1.4,
              ),
            ),
            if (date.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.textSecondary(context)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      date.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary(context),
                        fontSize: textScaler.scale(11),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
