import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/haptic_service.dart';

enum GateRecordType {
  studentsIn,
  activeVisitors,
  lateEntries,
  exitsLogged,
}

class GateDetailItem {
  final String id;
  final String name;
  final String subtitle;
  final String departmentOrPurpose;
  final String time;
  final String status;
  final Color statusColor;
  final String gate;
  final String? phone;
  final String? vehicleNo;
  final String? remark;
  final String? hostOrAdvisor;
  final bool isStudent;

  GateDetailItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.departmentOrPurpose,
    required this.time,
    required this.status,
    required this.statusColor,
    this.gate = 'Main Gate #1',
    this.phone,
    this.vehicleNo,
    this.remark,
    this.hostOrAdvisor,
    this.isStudent = true,
  });
}

class GateRecordsDetailScreen extends StatefulWidget {
  final GateRecordType recordType;
  final int totalCount;

  const GateRecordsDetailScreen({
    Key? key,
    required this.recordType,
    required this.totalCount,
  }) : super(key: key);

  @override
  State<GateRecordsDetailScreen> createState() => _GateRecordsDetailScreenState();
}

class _GateRecordsDetailScreenState extends State<GateRecordsDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  late List<GateDetailItem> _allItems;

  @override
  void initState() {
    super.initState();
    _loadItemsForType();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadItemsForType() {
    switch (widget.recordType) {
      case GateRecordType.studentsIn:
        _allItems = _mockStudentsInData;
        break;
      case GateRecordType.activeVisitors:
        _allItems = _mockVisitorsData;
        break;
      case GateRecordType.lateEntries:
        _allItems = _mockLateEntriesData;
        break;
      case GateRecordType.exitsLogged:
        _allItems = _mockExitsData;
        break;
    }
  }

  String get _screenTitle {
    switch (widget.recordType) {
      case GateRecordType.studentsIn:
        return 'Students Inside Campus';
      case GateRecordType.activeVisitors:
        return 'Active Campus Visitors';
      case GateRecordType.lateEntries:
        return 'Late Entries Log';
      case GateRecordType.exitsLogged:
        return 'Campus Exits & Out-Passes';
    }
  }

  Color get _themeColor {
    switch (widget.recordType) {
      case GateRecordType.studentsIn:
        return const Color(0xFF00D2B4);
      case GateRecordType.activeVisitors:
        return const Color(0xFFF59E0B);
      case GateRecordType.lateEntries:
        return const Color(0xFFEF4444);
      case GateRecordType.exitsLogged:
        return const Color(0xFF6366F1);
    }
  }

  IconData get _themeIcon {
    switch (widget.recordType) {
      case GateRecordType.studentsIn:
        return Icons.school_rounded;
      case GateRecordType.activeVisitors:
        return Icons.person_search_rounded;
      case GateRecordType.lateEntries:
        return Icons.timer_rounded;
      case GateRecordType.exitsLogged:
        return Icons.logout_rounded;
    }
  }

  List<String> get _filterOptions {
    switch (widget.recordType) {
      case GateRecordType.studentsIn:
        return ['All', 'CSE', 'ECE', 'ME', 'IT', 'Civil'];
      case GateRecordType.activeVisitors:
        return ['All', 'Parents', 'Vendors', 'Guests', 'Officials'];
      case GateRecordType.lateEntries:
        return ['All', '< 30m Late', '> 30m Late', 'Excused'];
      case GateRecordType.exitsLogged:
        return ['All', 'Out-Pass', 'Day-End', 'Faculty', 'Emergency'];
    }
  }

  List<GateDetailItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    return _allItems.where((item) {
      final matchesQuery = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.id.toLowerCase().contains(query) ||
          item.departmentOrPurpose.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      if (_selectedFilter == 'All') return true;

      if (widget.recordType == GateRecordType.studentsIn) {
        return item.subtitle.toLowerCase().contains(_selectedFilter.toLowerCase()) ||
            item.departmentOrPurpose.toLowerCase().contains(_selectedFilter.toLowerCase());
      } else if (widget.recordType == GateRecordType.activeVisitors) {
        return item.subtitle.toLowerCase().contains(_selectedFilter.toLowerCase()) ||
            item.departmentOrPurpose.toLowerCase().contains(_selectedFilter.toLowerCase());
      } else if (widget.recordType == GateRecordType.lateEntries) {
        if (_selectedFilter == 'Excused') {
          return item.status.toLowerCase().contains('excused') ||
              (item.remark?.toLowerCase().contains('permission') ?? false);
        } else if (_selectedFilter == '< 30m Late') {
          return item.remark?.contains('+1') == false &&
              item.remark?.contains('+2') == false &&
              (item.remark?.contains('+') ?? false);
        } else {
          return true;
        }
      } else {
        return item.subtitle.toLowerCase().contains(_selectedFilter.toLowerCase()) ||
            item.status.toLowerCase().contains(_selectedFilter.toLowerCase());
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. Custom Header ──
            _buildAppBar(isDark),

            // ── 2. Search & Filter Bar ──
            _buildSearchAndFilters(isDark),

            // ── 3. List of Records ──
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildItemCard(filtered[index], isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.border(context), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              HapticService.light();
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            splashRadius: 24,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _themeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_themeIcon, color: _themeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _screenTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.totalCount} active entries at Main Gate #1',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          // Search TextField
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context), width: 1),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search by name, roll no, department...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Horizontal Filter Chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _filterOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filterOptions[index];
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    HapticService.selection();
                    setState(() => _selectedFilter = filter);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _themeColor
                          : (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? _themeColor
                            : AppTheme.border(context),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(GateDetailItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticService.light();
            _showItemDetailsSheet(item, isDark);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar / Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: item.statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.status,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: item.statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.id,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.time,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                          if (item.remark != null) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '• ${item.remark}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: item.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showItemDetailsSheet(GateDetailItem item, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppTheme.border(context), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pill bar
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title Header
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: item.statusColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: item.statusColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.id} • ${item.subtitle}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Breakdown rows
              _buildModalRow('Gate Record ID', item.id, isDark, copyable: true),
              _buildModalRow('Department / Purpose', item.departmentOrPurpose, isDark),
              _buildModalRow('Entry / Recorded Time', item.time, isDark),
              _buildModalRow('Gate Location', item.gate, isDark),
              _buildModalRow('Status Verification', item.status, isDark, statusColor: item.statusColor),
              if (item.hostOrAdvisor != null)
                _buildModalRow('Host / Faculty Guide', item.hostOrAdvisor!, isDark),
              if (item.vehicleNo != null)
                _buildModalRow('Vehicle Number', item.vehicleNo!, isDark),
              if (item.phone != null)
                _buildModalRow('Contact Number', item.phone!, isDark),
              if (item.remark != null)
                _buildModalRow('Officer Remarks', item.remark!, isDark),

              const SizedBox(height: 24),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticService.light();
                    Clipboard.setData(ClipboardData(text: item.id));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${item.id} to clipboard'),
                        backgroundColor: _themeColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(
                    'Copy ID & Close',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themeColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value, bool isDark, {bool copyable = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded, size: 36, color: _themeColor),
          ),
          const SizedBox(height: 14),
          Text(
            'No matching records found',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching for another roll number or name',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ── Realistic Mock Datasets ──

  static final List<GateDetailItem> _mockStudentsInData = [
    GateDetailItem(
      id: '23N31A6653',
      name: 'BOORA RAVITEJA',
      subtitle: 'CSE-AIML • 2nd Year (Batch 2023-27)',
      departmentOrPurpose: 'CSE (Artificial Intelligence & ML)',
      time: '11:25 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 91335 55183',
      remark: 'MRCET Verified ID',
    ),
    GateDetailItem(
      id: '21CS042',
      name: 'K. Arjun',
      subtitle: 'CSE • 3rd Year (Sec A)',
      departmentOrPurpose: 'Computer Science & Engineering',
      time: '11:12 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 98480 11223',
    ),
    GateDetailItem(
      id: '22EC019',
      name: 'Sneha Reddy',
      subtitle: 'ECE • 2nd Year (Sec B)',
      departmentOrPurpose: 'Electronics & Communication',
      time: '10:40 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 98765 43210',
    ),
    GateDetailItem(
      id: '23ME005',
      name: 'Pooja Nair',
      subtitle: 'ME • 1st Year (Sec A)',
      departmentOrPurpose: 'Mechanical Engineering',
      time: '09:22 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 94401 23456',
    ),
    GateDetailItem(
      id: '21IT088',
      name: 'V. Siddharth',
      subtitle: 'IT • 3rd Year (Sec A)',
      departmentOrPurpose: 'Information Technology',
      time: '09:15 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 99887 76655',
    ),
    GateDetailItem(
      id: '22CS104',
      name: 'Ananya Sharma',
      subtitle: 'CSE • 2nd Year (Sec C)',
      departmentOrPurpose: 'Computer Science & Engineering',
      time: '09:05 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 97112 33445',
    ),
    GateDetailItem(
      id: '20CE014',
      name: 'M. Harish',
      subtitle: 'Civil • 4th Year (Sec A)',
      departmentOrPurpose: 'Civil Engineering',
      time: '08:55 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 95532 11223',
    ),
    GateDetailItem(
      id: '23CS012',
      name: 'Rohan Gupta',
      subtitle: 'CSE • 1st Year (Sec B)',
      departmentOrPurpose: 'Computer Science & Engineering',
      time: '08:50 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 96654 32198',
    ),
    GateDetailItem(
      id: '22ME045',
      name: 'Sai Teja',
      subtitle: 'ME • 2nd Year (Sec A)',
      departmentOrPurpose: 'Mechanical Engineering',
      time: '08:45 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 93902 44556',
    ),
    GateDetailItem(
      id: '21EC077',
      name: 'Divya Sri',
      subtitle: 'ECE • 3rd Year (Sec A)',
      departmentOrPurpose: 'Electronics & Communication',
      time: '08:40 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 98845 67789',
    ),
    GateDetailItem(
      id: '20CS001',
      name: 'K. Abhinav',
      subtitle: 'CSE • 4th Year (Sec A)',
      departmentOrPurpose: 'Computer Science & Engineering',
      time: '08:30 AM',
      status: 'Inside Campus',
      statusColor: const Color(0xFF00D2B4),
      phone: '+91 94901 88776',
    ),
  ];

  static final List<GateDetailItem> _mockVisitorsData = [
    GateDetailItem(
      id: 'VIS-402',
      name: 'Ravi Verma',
      subtitle: 'Parent • Meeting HOD ECE',
      departmentOrPurpose: 'ECE Department Meeting',
      time: '10:55 AM',
      status: 'Pass Active',
      statusColor: const Color(0xFFF59E0B),
      hostOrAdvisor: 'Dr. Raman (HOD ECE)',
      phone: '+91 98490 22334',
      vehicleNo: 'Car: AP 09 BK 4521',
      isStudent: false,
    ),
    GateDetailItem(
      id: 'VIS-403',
      name: 'Suresh Patil',
      subtitle: 'Vendor • Network Cable Setup',
      departmentOrPurpose: 'Central Server Room Maintenance',
      time: '10:15 AM',
      status: 'Pass Active',
      statusColor: const Color(0xFFF59E0B),
      hostOrAdvisor: 'Mr. Ramesh (System Admin)',
      phone: '+91 97001 55667',
      vehicleNo: 'Van: TS 08 EA 1190',
      isStudent: false,
    ),
    GateDetailItem(
      id: 'VIS-404',
      name: 'Dr. Meenakshi Sundaram',
      subtitle: 'Guest • Guest Lecturer',
      departmentOrPurpose: 'CSE AI/ML Symposium',
      time: '09:45 AM',
      status: 'Pass Active',
      statusColor: const Color(0xFFF59E0B),
      hostOrAdvisor: 'Prof. K. Venkatesh (Dean)',
      phone: '+91 94411 99887',
      vehicleNo: 'Car: KA 03 MH 8899',
      isStudent: false,
    ),
    GateDetailItem(
      id: 'VIS-405',
      name: 'G. Naresh',
      subtitle: 'Parent • Fee Clearance',
      departmentOrPurpose: 'Accounts & Finance Cell',
      time: '09:30 AM',
      status: 'Pass Active',
      statusColor: const Color(0xFFF59E0B),
      phone: '+91 99088 12345',
      vehicleNo: 'Two Wheeler: AP 21 BX 0092',
      isStudent: false,
    ),
    GateDetailItem(
      id: 'VIS-406',
      name: 'K. Balaji',
      subtitle: 'Official • University Inspector',
      departmentOrPurpose: 'JNTU Exam Inspection Cell',
      time: '09:10 AM',
      status: 'Pass Active',
      statusColor: const Color(0xFFF59E0B),
      hostOrAdvisor: 'Principal Office',
      phone: '+91 98481 00998',
      vehicleNo: 'Car: TS 09 GF 4433',
      isStudent: false,
    ),
    GateDetailItem(
      id: 'VIS-407',
      name: 'P. Venkat Rao',
      subtitle: 'Vendor • Canteen Supply',
      departmentOrPurpose: 'Campus Dining Store',
      time: '08:40 AM',
      status: 'Pass Active',
      statusColor: const Color(0xFFF59E0B),
      vehicleNo: 'Truck: AP 16 TT 8821',
      isStudent: false,
    ),
    GateDetailItem(
      id: 'VIS-408',
      name: 'B. Srilatha',
      subtitle: 'Parent • Hostel Meeting',
      departmentOrPurpose: 'Girls Hostel Warden Office',
      time: '08:20 AM',
      status: 'Pass Active',
      statusColor: const Color(0xFFF59E0B),
      hostOrAdvisor: 'Chief Warden',
      phone: '+91 96600 33441',
      isStudent: false,
    ),
  ];

  static final List<GateDetailItem> _mockLateEntriesData = [
    GateDetailItem(
      id: '23ME005',
      name: 'Pooja Nair',
      subtitle: 'ME • 1st Year',
      departmentOrPurpose: 'Mechanical Engineering',
      time: '09:22 AM',
      status: 'Late Entry',
      statusColor: const Color(0xFFEF4444),
      remark: '+22m late • Bus Breakdown',
      phone: '+91 94401 23456',
    ),
    GateDetailItem(
      id: '21CS099',
      name: 'Akash Varma',
      subtitle: 'CSE • 3rd Year',
      departmentOrPurpose: 'Computer Science & Engineering',
      time: '09:35 AM',
      status: 'Late Entry',
      statusColor: const Color(0xFFEF4444),
      remark: '+35m late • Heavy Traffic',
      phone: '+91 98492 11883',
    ),
    GateDetailItem(
      id: '22EC055',
      name: 'N. Sandeep',
      subtitle: 'ECE • 2nd Year',
      departmentOrPurpose: 'Electronics & Communication',
      time: '09:42 AM',
      status: 'Late Entry',
      statusColor: const Color(0xFFEF4444),
      remark: '+42m late • Medical Checkup Slip',
      phone: '+91 97003 44556',
    ),
    GateDetailItem(
      id: '23IT018',
      name: 'M. Bhavani',
      subtitle: 'IT • 1st Year',
      departmentOrPurpose: 'Information Technology',
      time: '09:50 AM',
      status: 'Late Entry',
      statusColor: const Color(0xFFEF4444),
      remark: '+50m late • Metro Delay',
      phone: '+91 95501 88223',
    ),
    GateDetailItem(
      id: '20CE031',
      name: 'T. Karthik',
      subtitle: 'Civil • 4th Year',
      departmentOrPurpose: 'Civil Engineering',
      time: '10:05 AM',
      status: 'Late Entry',
      statusColor: const Color(0xFFEF4444),
      remark: '+1h 05m late • HOD Permission Slip',
      phone: '+91 99882 33441',
    ),
    GateDetailItem(
      id: '22CS082',
      name: 'B. Varun',
      subtitle: 'CSE • 2nd Year',
      departmentOrPurpose: 'Computer Science & Engineering',
      time: '10:15 AM',
      status: 'Late Entry',
      statusColor: const Color(0xFFEF4444),
      remark: '+1h 15m late • Flagged by Proctor',
      phone: '+91 96602 11335',
    ),
  ];

  static final List<GateDetailItem> _mockExitsData = [
    GateDetailItem(
      id: '22EC019',
      name: 'Sneha Reddy',
      subtitle: 'ECE • 2nd Year',
      departmentOrPurpose: 'Electronics & Communication',
      time: '10:40 AM',
      status: 'Out-Pass Logged',
      statusColor: const Color(0xFF6366F1),
      remark: 'Medical Pass #OP-882',
      hostOrAdvisor: 'Approved by Dr. Raman',
      phone: '+91 98765 43210',
    ),
    GateDetailItem(
      id: '21CS015',
      name: 'Tanvi Joshi',
      subtitle: 'CSE • 3rd Year',
      departmentOrPurpose: 'Computer Science & Engineering',
      time: '11:05 AM',
      status: 'Out-Pass Logged',
      statusColor: const Color(0xFF6366F1),
      remark: 'Library Research Pass #OP-883',
      phone: '+91 98480 33441',
    ),
    GateDetailItem(
      id: 'FAC-108',
      name: 'Dr. S. Raman',
      subtitle: 'Faculty • Dept. of Physics',
      departmentOrPurpose: 'Physics Department',
      time: '11:18 AM',
      status: 'Faculty Exit',
      statusColor: const Color(0xFF6366F1),
      remark: 'Official Duty • Meeting at Univ',
      isStudent: false,
    ),
    GateDetailItem(
      id: '20ME009',
      name: 'C. Pradeep',
      subtitle: 'ME • 4th Year',
      departmentOrPurpose: 'Mechanical Engineering',
      time: '11:30 AM',
      status: 'Out-Pass Logged',
      statusColor: const Color(0xFF6366F1),
      remark: 'Campus Placement Interview',
      phone: '+91 99081 22334',
    ),
    GateDetailItem(
      id: 'VIS-398',
      name: 'K. Mohan',
      subtitle: 'Visitor • Guest Exit',
      departmentOrPurpose: 'General Administration',
      time: '11:42 AM',
      status: 'Visitor Checkout',
      statusColor: const Color(0xFF6366F1),
      remark: 'Pass Completed & Surrendered',
      isStudent: false,
    ),
  ];
}
