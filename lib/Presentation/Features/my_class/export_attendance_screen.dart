import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Core/utils/haptic_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';

class ExportAttendanceScreen extends StatefulWidget {
  final String sectionId;
  final String courseCode;
  final String courseName;

  const ExportAttendanceScreen({
    Key? key,
    required this.sectionId,
    required this.courseCode,
    required this.courseName,
  }) : super(key: key);

  @override
  State<ExportAttendanceScreen> createState() => _ExportAttendanceScreenState();
}

class _ExportAttendanceScreenState extends State<ExportAttendanceScreen> {
  List<Map<String, dynamic>> _roster = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String _exportFormat = 'csv';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    try {
      final raw = PersistenceService.academicBox.get('roster_${widget.sectionId}');
      if (raw != null) {
        _roster = (raw as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint("ExportAttendance: Error loading roster: $e");
    }
    if (mounted) setState(() => _isLoading = false);
  }

  double _pct(Map<String, dynamic> s) {
    final a = (s['attended'] as num?)?.toDouble() ?? 0;
    final t = (s['total'] as num?)?.toDouble() ?? 1;
    return t > 0 ? a / t : 0;
  }

  String _statusLabel(double pct) {
    if (pct >= 0.75) return 'Eligible';
    if (pct >= 0.60) return 'At Risk';
    return 'Defaulter';
  }

  String _generateCsvContent() {
    final buffer = StringBuffer();
    buffer.writeln("Roll Number,Name,Email,Classes Attended,Total Classes,Attendance %,Status");

    for (final s in _roster) {
      final roll = (s['roll_number'] ?? s['id'] ?? '').toString();
      final name = (s['name'] ?? '').toString();
      final email = (s['email'] ?? '').toString();
      final attended = (s['attended'] as num?)?.toInt() ?? 0;
      final total = (s['total'] as num?)?.toInt() ?? 0;
      final pct = _pct(s);
      final status = _statusLabel(pct);
      final pctStr = "${(pct * 100).toStringAsFixed(1)}%";

      buffer.writeln('"$roll","$name","$email",$attended,$total,$pctStr,$status');
    }

    buffer.writeln("");
    buffer.writeln("Summary");
    buffer.writeln("Course,${widget.courseName}");
    buffer.writeln("Course Code,${widget.courseCode}");
    buffer.writeln("Total Students,${_roster.length}");
    buffer.writeln("Eligible,${_roster.where((s) => _pct(s) >= 0.75).length}");
    buffer.writeln("At Risk,${_roster.where((s) { final p = _pct(s); return p >= 0.60 && p < 0.75; }).length}");
    buffer.writeln("Defaulters,${_roster.where((s) => _pct(s) < 0.60).length}");
    final avg = _roster.isNotEmpty ? (_roster.fold<double>(0, (sum, s) => sum + _pct(s)) / _roster.length * 100).toStringAsFixed(1) : '0';
    buffer.writeln("Overall Average,$avg%");
    buffer.writeln("Generated On,${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}");

    return buffer.toString();
  }

  String _generateTextContent() {
    final buffer = StringBuffer();
    final now = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final facultyName = FacultyService.profile.value?.name ?? 'Faculty';

    buffer.writeln("╔══════════════════════════════════════╗");
    buffer.writeln("║     ATTENDANCE REPORT                ║");
    buffer.writeln("╚══════════════════════════════════════╝");
    buffer.writeln("");
    buffer.writeln("Course    : ${widget.courseName}");
    buffer.writeln("Code      : ${widget.courseCode}");
    buffer.writeln("Faculty   : $facultyName");
    buffer.writeln("Date      : $now");
    buffer.writeln("Students  : ${_roster.length}");
    buffer.writeln("");
    buffer.writeln("────────────────────────────────────────");

    for (int i = 0; i < _roster.length; i++) {
      final s = _roster[i];
      final roll = (s['roll_number'] ?? s['id'] ?? '').toString();
      final name = (s['name'] ?? '').toString();
      final attended = (s['attended'] as num?)?.toInt() ?? 0;
      final total = (s['total'] as num?)?.toInt() ?? 0;
      final pct = _pct(s);
      final status = _statusLabel(pct);

      buffer.writeln("${(i + 1).toString().padLeft(2)}. $name");
      buffer.writeln("    Roll: $roll | $attended/$total (${(pct * 100).toStringAsFixed(1)}%) | $status");
    }

    buffer.writeln("");
    buffer.writeln("────────────────────────────────────────");
    buffer.writeln("SUMMARY");
    buffer.writeln("────────────────────────────────────────");
    final eligible = _roster.where((s) => _pct(s) >= 0.75).length;
    final atRisk = _roster.where((s) { final p = _pct(s); return p >= 0.60 && p < 0.75; }).length;
    final defaulters = _roster.where((s) => _pct(s) < 0.60).length;
    final avg = _roster.isNotEmpty ? _roster.fold<double>(0, (sum, s) => sum + _pct(s)) / _roster.length * 100 : 0.0;

    buffer.writeln("Eligible      : $eligible (${(eligible / (_roster.length > 0 ? _roster.length : 1) * 100).toStringAsFixed(0)}%)");
    buffer.writeln("At Risk       : $atRisk");
    buffer.writeln("Defaulters    : $defaulters");
    buffer.writeln("Avg Attendance: ${avg.toStringAsFixed(1)}%");
    buffer.writeln("");
    buffer.writeln("Generated by IntelliAttend Smart Campus");

    return buffer.toString();
  }

  Future<void> _exportAttendance() async {
    if (_roster.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No student data to export", style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final content = _exportFormat == 'csv' ? _generateCsvContent() : _generateTextContent();
      final extension = _exportFormat == 'csv' ? 'csv' : 'txt';
      final fileName = "attendance_${widget.courseCode}_${DateFormat('yyyyMMdd').format(DateTime.now())}.$extension";

      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/$fileName");
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: "Attendance Report - ${widget.courseCode}",
        text: "Attendance report for ${widget.courseName} (${widget.courseCode})",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Report exported successfully", style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF2DD4BF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e", style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
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
          "Export Attendance",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviewHeader(),
                  const SizedBox(height: 20),
                  _buildStatsSummary(),
                  const SizedBox(height: 20),
                  _buildFormatSelector(),
                  const SizedBox(height: 20),
                  _buildPreviewList(),
                  const SizedBox(height: 24),
                  _buildExportButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentTeal.withValues(alpha: 0.15),
            const Color(0xFF60A5FA).withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.file_download_outlined, color: AppTheme.accentTeal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.courseCode} · ${_roster.length} students · ${DateFormat('dd MMM yyyy').format(DateTime.now())}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    final eligible = _roster.where((s) => _pct(s) >= 0.75).length;
    final atRisk = _roster.where((s) { final p = _pct(s); return p >= 0.60 && p < 0.75; }).length;
    final defaulters = _roster.where((s) => _pct(s) < 0.60).length;
    final avg = _roster.isNotEmpty ? _roster.fold<double>(0, (sum, s) => sum + _pct(s)) / _roster.length * 100 : 0.0;

    return Row(
      children: [
        _buildStatChip("Avg", "${avg.toStringAsFixed(0)}%", const Color(0xFF60A5FA)),
        const SizedBox(width: 8),
        _buildStatChip("Eligible", "$eligible", const Color(0xFF2DD4BF)),
        const SizedBox(width: 8),
        _buildStatChip("At Risk", "$atRisk", const Color(0xFFFBBF24)),
        const SizedBox(width: 8),
        _buildStatChip("Fail", "$defaulters", const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Export Format",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildFormatOption("csv", "CSV Spreadsheet", Icons.table_chart_rounded),
            const SizedBox(width: 10),
            _buildFormatOption("txt", "Text Report", Icons.description_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatOption(String format, String label, IconData icon) {
    final selected = _exportFormat == format;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticHelper.lightImpact();
          setState(() => _exportFormat = format);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentTeal.withValues(alpha: 0.1) : AppTheme.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.accentTeal.withValues(alpha: 0.4) : AppTheme.border(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? AppTheme.accentTeal : AppTheme.textSecondary(context), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: selected ? AppTheme.accentTeal : AppTheme.text(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewList() {
    if (_roster.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline_rounded, size: 40, color: AppTheme.textSecondary(context).withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text("No student data available", maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Preview (${_roster.length} students)",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
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
              final s = _roster[index];
              final name = (s['name'] ?? 'Unknown').toString();
              final roll = (s['roll_number'] ?? s['id'] ?? '').toString();
              final attended = (s['attended'] as num?)?.toInt() ?? 0;
              final total = (s['total'] as num?)?.toInt() ?? 0;
              final pct = _pct(s);
              final color = pct >= 0.75 ? const Color(0xFF2DD4BF) : pct >= 0.60 ? const Color(0xFFFBBF24) : const Color(0xFFEF4444);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      "${(index + 1).toString().padLeft(2, '0')}",
                      style: GoogleFonts.jetBrainsMono(color: AppTheme.textSecondary(context), fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 12, fontWeight: FontWeight.w500)),
                          Text(roll, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.jetBrainsMono(color: AppTheme.textSecondary(context), fontSize: 10)),
                        ],
                      ),
                    ),
                    Text(
                      "$attended/$total",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${(pct * 100).toInt()}%",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isExporting ? null : _exportAttendance,
        icon: _isExporting
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.file_download_outlined, size: 20),
        label: Text(
          _isExporting ? "Exporting..." : "Export & Share Report",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppTheme.accentTeal.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }
}
