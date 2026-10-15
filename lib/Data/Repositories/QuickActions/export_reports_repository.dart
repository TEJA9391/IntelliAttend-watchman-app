import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

import 'package:intelli_attend_faculty/Data/Models/QuickActions/export_report.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/class_student.dart';
import 'package:intelli_attend_faculty/Data/Models/QuickActions/attendance_record.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';

class ExportReportsRepository {
  final List<ExportReport> _history = [];
  int _nextId = 1;

  List<ExportReport> get history => List.unmodifiable(_history);

  Map<String, List<String>> fetchFilterOptions() {
    final courses = <String>{};
    final sections = <String>{};
    final semesters = <String>{};
    try {
      final keys = PersistenceService.academicBox.get('roster_keys');
      if (keys is List) {
        for (final key in keys) {
          final keyStr = key.toString();
          final raw = PersistenceService.academicBox.get('roster_$keyStr');
          if (raw is List) {
            for (final entry in raw) {
              if (entry is Map) {
                final data = Map<String, dynamic>.from(entry);
                final cc = (data['course_code'] ?? '').toString();
                final sec = (data['section'] ?? '').toString();
                final sem = (data['semester'] ?? '').toString();
                if (cc.isNotEmpty) courses.add(cc);
                if (sec.isNotEmpty) sections.add(sec);
                if (sem.isNotEmpty) semesters.add(sem);
              }
            }
          }
        }
      }
      final cohorts = PersistenceService.academicBox.get('cohorts');
      if (cohorts is List) {
        for (final c in cohorts) {
          if (c is Map) {
            final m = Map<String, dynamic>.from(c);
            final cc = (m['course_code'] ?? '').toString();
            final sec = (m['section'] ?? m['section_name'] ?? '').toString();
            if (cc.isNotEmpty) courses.add(cc);
            if (sec.isNotEmpty) sections.add(sec);
          }
        }
      }
    } catch (_) {}
    if (semesters.isEmpty) {
      semesters.addAll({'1', '2', '3', '4', '5', '6', '7', '8'});
    }
    return {
      'courses': courses.toList()..sort(),
      'sections': sections.toList()..sort(),
      'semesters': semesters.toList()..sort(),
    };
  }

  Future<void> init() async {
    // No initial dummy history - reports are generated from real data
  }

  List<ExportReport> _generateInitialHistory() {
    final now = DateTime.now();
    return [
      ExportReport(
        id: 'RPT001',
        title: 'CS301 Attendance Report - March 2025',
        type: ReportType.attendance,
        format: ExportFormat.pdf,
        generatedAt: now.subtract(const Duration(days: 2)),
        dateFrom: now.subtract(const Duration(days: 30)),
        dateTo: now,
        courseCode: 'CS301',
        section: 'A',
        semester: '5',
        recordCount: 62,
        fileSizeKB: 245.8,
        status: 'completed',
        exportDurationMs: 1250,
      ),
      ExportReport(
        id: 'RPT002',
        title: 'Student List - CS Department',
        type: ReportType.studentList,
        format: ExportFormat.excel,
        generatedAt: now.subtract(const Duration(days: 5)),
        courseCode: 'CS301',
        semester: '5',
        recordCount: 120,
        fileSizeKB: 89.3,
        status: 'completed',
        exportDurationMs: 980,
      ),
      ExportReport(
        id: 'RPT003',
        title: 'Session Summary - Week 12',
        type: ReportType.sessionSummary,
        format: ExportFormat.pdf,
        generatedAt: now.subtract(const Duration(days: 7)),
        dateFrom: now.subtract(const Duration(days: 14)),
        dateTo: now.subtract(const Duration(days: 7)),
        recordCount: 8,
        fileSizeKB: 156.2,
        status: 'completed',
        exportDurationMs: 1100,
      ),
      ExportReport(
        id: 'RPT004',
        title: 'Daily Attendance - 15 March 2025',
        type: ReportType.daily,
        format: ExportFormat.csv,
        generatedAt: now.subtract(const Duration(days: 10)),
        dateFrom: now.subtract(const Duration(days: 10)),
        dateTo: now.subtract(const Duration(days: 10)),
        courseCode: 'CS301',
        section: 'A',
        recordCount: 62,
        fileSizeKB: 12.4,
        status: 'completed',
        exportDurationMs: 450,
      ),
      ExportReport(
        id: 'RPT005',
        title: 'Weekly Report - Week 11',
        type: ReportType.weekly,
        format: ExportFormat.json,
        generatedAt: now.subtract(const Duration(days: 14)),
        dateFrom: now.subtract(const Duration(days: 21)),
        dateTo: now.subtract(const Duration(days: 14)),
        courseCode: 'CS301',
        recordCount: 124,
        fileSizeKB: 34.7,
        status: 'completed',
        exportDurationMs: 320,
      ),
      ExportReport(
        id: 'RPT006',
        title: 'Monthly Summary - February 2025',
        type: ReportType.monthly,
        format: ExportFormat.excel,
        generatedAt: now.subtract(const Duration(days: 20)),
        dateFrom: DateTime(2025, 2, 1),
        dateTo: DateTime(2025, 2, 28),
        courseCode: 'CS301',
        recordCount: 248,
        fileSizeKB: 445.6,
        status: 'completed',
        exportDurationMs: 2100,
      ),
      ExportReport(
        id: 'RPT007',
        title: 'Department Report - CS & EE',
        type: ReportType.department,
        format: ExportFormat.pdf,
        generatedAt: now.subtract(const Duration(days: 25)),
        dateFrom: now.subtract(const Duration(days: 60)),
        dateTo: now.subtract(const Duration(days: 25)),
        recordCount: 180,
        fileSizeKB: 567.8,
        status: 'completed',
        exportDurationMs: 3200,
      ),
    ];
  }

  List<ExportReport> fetchReports({ReportType? type}) {
    List<ExportReport> results = List.from(_history);
    if (type != null) {
      results = results.where((r) => r.type == type).toList();
    }
    results.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return results;
  }

  Future<ExportReport> generateReport({
    required ReportType type,
    required ExportFormat format,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? courseCode,
    String? section,
    String? semester,
  }) async {
    final sw = Stopwatch()..start();

    await _requestPermissions();

    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final students = _fetchRealStudents(courseCode: courseCode, section: section);
    final sessions = _fetchRealSessions(courseCode: courseCode, section: section);

    final dateRangeFrom = dateFrom ?? DateTime.now().subtract(const Duration(days: 30));
    final dateRangeTo = dateTo ?? DateTime.now();

    final filteredStudents = _filterStudents(students, courseCode, section);
    final filteredSessions = _filterSessions(sessions, courseCode, section, dateRangeFrom, dateRangeTo);

    final title = _generateTitle(type, courseCode, dateRangeFrom, dateRangeTo);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final codeLabel = (courseCode ?? 'ALL').replaceAll(RegExp(r'[^\w]'), '_');
    final ext = _fileExtension(format);
    final fileName = 'Attendance_${codeLabel}_$dateStr.$ext';
    final filePath = '${exportDir.path}/$fileName';
    final file = File(filePath);

    switch (format) {
      case ExportFormat.pdf:
        await _generatePDF(file, students, filteredSessions, type, courseCode, section, semester, dateRangeFrom, dateRangeTo);
        break;
      case ExportFormat.excel:
        await _generateExcel(file, students, filteredSessions, type, courseCode, section, semester, dateRangeFrom, dateRangeTo);
        break;
      case ExportFormat.csv:
        await _generateCSV(file, students, filteredSessions, type);
        break;
      case ExportFormat.json:
        await _generateJSON(file, students, filteredSessions, type, courseCode, section, semester, dateRangeFrom, dateRangeTo);
        break;
    }

    sw.stop();

    final fileSize = await file.length();
    final report = ExportReport(
      id: 'RPT${(_nextId + 100).toString().padLeft(3, '0')}',
      title: title,
      type: type,
      format: format,
      generatedAt: DateTime.now(),
      dateFrom: dateRangeFrom,
      dateTo: dateRangeTo,
      courseCode: courseCode,
      section: section,
      semester: semester,
      recordCount: filteredStudents.length,
      filePath: filePath,
      fileName: fileName,
      fileSizeKB: fileSize / 1024.0,
      status: 'completed',
      exportDurationMs: sw.elapsedMilliseconds,
    );

    _history.insert(0, report);
    _nextId++;
    return report;
  }

  Future<void> deleteReport(ExportReport report) async {
    if (report.filePath != null) {
      final file = File(report.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _history.removeWhere((r) => r.id == report.id);
  }

  Future<void> openReport(ExportReport report) async {
    if (report.filePath != null) {
      await OpenFilex.open(report.filePath!);
    }
  }

  Future<void> shareReport(ExportReport report) async {
    if (report.filePath != null) {
      final file = File(report.filePath!);
      if (await file.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            text: '${report.title}\nGenerated on ${DateFormat('dd MMM yyyy, hh:mm a').format(report.generatedAt)}',
            subject: report.title,
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      if (!storage.isGranted) {
        await Permission.storage.request();
      }
      final manage = await Permission.manageExternalStorage.status;
      if (!manage.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }
  }

  String _fileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.excel:
        return 'xlsx';
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.json:
        return 'json';
    }
  }

  List<ClassStudent> _filterStudents(
    List<ClassStudent> students,
    String? courseCode,
    String? section,
  ) {
    var filtered = students;
    if (section != null) {
      filtered = filtered.where((s) => s.section == section).toList();
    }
    return filtered;
  }

  List<AttendanceSession> _filterSessions(
    List<AttendanceSession> sessions,
    String? courseCode,
    String? section,
    DateTime from,
    DateTime to,
  ) {
    return sessions.where((s) {
      if (s.date.isBefore(from) || s.date.isAfter(to)) return false;
      if (courseCode != null && s.courseCode != courseCode) return false;
      if (section != null && s.section != section) return false;
      return true;
    }).toList();
  }

  String _generateTitle(
    ReportType type,
    String? courseCode,
    DateTime dateFrom,
    DateTime dateTo,
  ) {
    final prefix = courseCode ?? 'All Courses';
    final from = DateFormat('dd/MM/yyyy').format(dateFrom);
    final to = DateFormat('dd/MM/yyyy').format(dateTo);

    switch (type) {
      case ReportType.attendance:
        return '$prefix Attendance Report ($from - $to)';
      case ReportType.studentList:
        return '$prefix Student List';
      case ReportType.sessionSummary:
        return 'Session Summary ($from - $to)';
      case ReportType.daily:
        return 'Daily Attendance - $to';
      case ReportType.weekly:
        return 'Weekly Report ($from - $to)';
      case ReportType.monthly:
        return 'Monthly Report ($from - $to)';
      case ReportType.subject:
        return '$prefix Subject Report';
      case ReportType.department:
        return 'Department Report ($from - $to)';
    }
  }

  Map<String, dynamic> _computeStats(List<ClassStudent> students) {
    final total = students.length;
    final present = students.where((s) => s.attendancePercentage >= 75).length;
    final absent = students.where((s) => s.attendancePercentage < 65).length;
    final atRisk = students.where((s) => s.attendancePercentage >= 65 && s.attendancePercentage < 75).length;
    final avgPct = total > 0
        ? students.map((s) => s.attendancePercentage).reduce((a, b) => a + b) / total
        : 0.0;
    return {
      'total': total,
      'present': present,
      'absent': absent,
      'atRisk': atRisk,
      'avgPct': avgPct,
    };
  }

  // ==================== PDF ====================
  Future<void> _generatePDF(
    File file,
    List<ClassStudent> students,
    List<AttendanceSession> sessions,
    ReportType type,
    String? courseCode,
    String? section,
    String? semester,
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    final pdf = pw.Document();
    final stats = _computeStats(students);
    final now = DateTime.now();

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo_square.png');
      final logoBytes = logoData.buffer.asUint8List();
      logoImage = pw.MemoryImage(logoBytes);
    } catch (e) {
      logoImage = null;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logoImage != null) ...[
                      pw.Image(logoImage, height: 36, width: 36),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('IntelliAttend',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal700,
                            )),
                        pw.SizedBox(height: 2),
                        pw.Text('Faculty Attendance Management',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(now),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal50,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'Page ${ctx.pageNumber}',
                        style: pw.TextStyle(fontSize: 8, color: PdfColors.teal700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.teal200, thickness: 1.5),
          ],
        ),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          pw.Text(_reportTypeLabel(type),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          _pdfInfoSection(courseCode, section, semester, dateFrom, dateTo, now),
          pw.SizedBox(height: 16),
          _pdfSummarySection(stats),
          pw.SizedBox(height: 20),
          pw.Text('Student Attendance Details',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfStudentTable(students),
          pw.SizedBox(height: 20),
          if (sessions.isNotEmpty) ...[
            pw.Text('Session History',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _pdfSessionTable(sessions),
          ],
          pw.SizedBox(height: 24),
          _pdfSignatureSection(),
        ],
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('IntelliAttend \u2022 Confidential',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                pw.Text('Generated: ${DateFormat('dd MMM yyyy').format(now)}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    await file.writeAsBytes(bytes);
  }

  pw.Widget _pdfInfoSection(
    String? courseCode,
    String? section,
    String? semester,
    DateTime dateFrom,
    DateTime dateTo,
    DateTime now,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Report Information',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _pdfInfoRow('Department', 'Computer Science & Engineering'),
          _pdfInfoRow('Faculty', 'Dr. Rajesh Kumar'),
          _pdfInfoRow('Subject', courseCode ?? 'All Subjects'),
          _pdfInfoRow('Section', section ?? 'All Sections'),
          _pdfInfoRow('Semester', semester ?? 'Current'),
          _pdfInfoRow('Period', '${DateFormat('dd MMM yyyy').format(dateFrom)} - ${DateFormat('dd MMM yyyy').format(dateTo)}'),
          _pdfInfoRow('Academic Year', '2024-2025'),
          _pdfInfoRow('Generated', DateFormat('dd MMM yyyy, hh:mm a').format(now)),
        ],
      ),
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ),
          pw.Text(value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _pdfSummarySection(Map<String, dynamic> stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.teal100),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Attendance Summary',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfStatBox('Total', '${stats['total']}'),
              _pdfStatBox('Present', '${stats['present']}'),
              _pdfStatBox('Absent', '${stats['absent']}'),
              _pdfStatBox('At Risk', '${stats['atRisk']}'),
              _pdfStatBox('Avg %', '${(stats['avgPct'] as double).toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfStatBox(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700)),
        pw.SizedBox(height: 2),
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _pdfStudentTable(List<ClassStudent> students) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 20,
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      headers: ['ID', 'Name', 'Roll No', 'Dept', 'Attended', 'Total', '%', 'Status', 'Remarks'],
      data: students.map((s) {
        final pct = s.attendancePercentage;
        final status = pct >= 75 ? 'Eligible' : pct >= 65 ? 'At Risk' : 'Defaulter';
        final remarks = pct >= 85
            ? 'Excellent'
            : pct >= 75
                ? 'Good'
                : pct >= 65
                    ? 'Needs Improvement'
                    : 'Critical';
        return [
          s.id,
          s.name,
          s.rollNumber,
          s.department ?? '',
          '${s.attendedClasses}',
          '${s.totalClasses}',
          '${pct.toStringAsFixed(1)}%',
          status,
          remarks,
        ];
      }).toList(),
    );
  }

  pw.Widget _pdfSessionTable(List<AttendanceSession> sessions) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 20,
      headers: ['Date', 'Course', 'Section', 'Total', 'Present', 'Absent', 'Att %'],
      data: sessions.map((s) {
        final total = s.totalStudents;
        final present = s.presentCount;
        final absent = s.absentCount;
        final pct = total > 0 ? (present / total * 100).toStringAsFixed(1) : '0.0';
        return [
          DateFormat('dd MMM yyyy').format(s.date),
          s.courseCode,
          s.section,
          '$total',
          '$present',
          '$absent',
          '$pct%',
        ];
      }).toList(),
    );
  }

  pw.Widget _pdfSignatureSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 120, height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Faculty Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 120, height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('HOD Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  // ==================== EXCEL ====================
  Future<void> _generateExcel(
    File file,
    List<ClassStudent> students,
    List<AttendanceSession> sessions,
    ReportType type,
    String? courseCode,
    String? section,
    String? semester,
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    final excel = xl.Excel.createExcel();
    final stats = _computeStats(students);

    // Summary Sheet
    final summarySheet = excel['Summary'];
    _excelSetCell(summarySheet, 0, 0, 'IntelliAttend');
    _excelSetCell(summarySheet, 1, 0, 'Faculty Attendance Management');
    _excelSetCell(summarySheet, 2, 0, _reportTypeLabel(type));
    _excelSetCell(summarySheet, 3, 0, 'Department');
    _excelSetCell(summarySheet, 3, 1, 'Computer Science & Engineering');
    _excelSetCell(summarySheet, 4, 0, 'Subject');
    _excelSetCell(summarySheet, 4, 1, courseCode ?? 'All Subjects');
    _excelSetCell(summarySheet, 5, 0, 'Section');
    _excelSetCell(summarySheet, 5, 1, section ?? 'All');
    _excelSetCell(summarySheet, 6, 0, 'Semester');
    _excelSetCell(summarySheet, 6, 1, semester ?? 'Current');
    _excelSetCell(summarySheet, 7, 0, 'Period');
    _excelSetCell(summarySheet, 7, 1, '${DateFormat('dd MMM yyyy').format(dateFrom)} - ${DateFormat('dd MMM yyyy').format(dateTo)}');
    _excelSetCell(summarySheet, 8, 0, 'Generated');
    _excelSetCell(summarySheet, 8, 1, DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()));

    _excelSetCell(summarySheet, 11, 0, 'Attendance Summary');
    _excelSetCell(summarySheet, 12, 0, 'Total Students');
    _excelSetCell(summarySheet, 12, 1, stats['total'] as int);
    _excelSetCell(summarySheet, 13, 0, 'Present (>=75%)');
    _excelSetCell(summarySheet, 13, 1, stats['present'] as int);
    _excelSetCell(summarySheet, 14, 0, 'At Risk (65-75%)');
    _excelSetCell(summarySheet, 14, 1, stats['atRisk'] as int);
    _excelSetCell(summarySheet, 15, 0, 'Defaulter (<65%)');
    _excelSetCell(summarySheet, 15, 1, stats['absent'] as int);
    _excelSetCell(summarySheet, 16, 0, 'Average Attendance');
    _excelSetCell(summarySheet, 16, 1, '${(stats['avgPct'] as double).toStringAsFixed(1)}%');

    // Student Attendance Sheet
    final studentSheet = excel['Student Attendance'];
    final studentHeaders = ['ID', 'Name', 'Roll Number', 'Department', 'Section', 'Email', 'Attended', 'Total', 'Percentage', 'Status', 'Remarks'];
    for (int i = 0; i < studentHeaders.length; i++) {
      _excelSetCell(studentSheet, 0, i, studentHeaders[i]);
    }
    for (int r = 0; r < students.length; r++) {
      final s = students[r];
      final pct = s.attendancePercentage;
      final status = pct >= 75 ? 'Eligible' : pct >= 65 ? 'At Risk' : 'Defaulter';
      final remarks = pct >= 85 ? 'Excellent' : pct >= 75 ? 'Good' : pct >= 65 ? 'Needs Improvement' : 'Critical';
      _excelSetCell(studentSheet, r + 1, 0, s.id);
      _excelSetCell(studentSheet, r + 1, 1, s.name);
      _excelSetCell(studentSheet, r + 1, 2, s.rollNumber);
      _excelSetCell(studentSheet, r + 1, 3, s.department ?? '');
      _excelSetCell(studentSheet, r + 1, 4, s.section ?? '');
      _excelSetCell(studentSheet, r + 1, 5, s.email ?? '');
      _excelSetCell(studentSheet, r + 1, 6, s.attendedClasses);
      _excelSetCell(studentSheet, r + 1, 7, s.totalClasses);
      _excelSetCell(studentSheet, r + 1, 8, '${pct.toStringAsFixed(1)}%');
      _excelSetCell(studentSheet, r + 1, 9, status);
      _excelSetCell(studentSheet, r + 1, 10, remarks);
    }

    // Monthly Report Sheet
    final monthlySheet = excel['Monthly Report'];
    final monthlyHeaders = ['Date', 'Course', 'Section', 'Total Students', 'Present', 'Absent', 'Late', 'Leave', 'Attendance %'];
    for (int i = 0; i < monthlyHeaders.length; i++) {
      _excelSetCell(monthlySheet, 0, i, monthlyHeaders[i]);
    }
    for (int r = 0; r < sessions.length; r++) {
      final s = sessions[r];
      final total = s.totalStudents;
      final present = s.presentCount;
      final absent = s.absentCount;
      final late = s.lateCount;
      final leave = s.leaveCount;
      final pct = total > 0 ? (present / total * 100).toStringAsFixed(1) : '0.0';
      _excelSetCell(monthlySheet, r + 1, 0, DateFormat('dd MMM yyyy').format(s.date));
      _excelSetCell(monthlySheet, r + 1, 1, s.courseCode);
      _excelSetCell(monthlySheet, r + 1, 2, s.section);
      _excelSetCell(monthlySheet, r + 1, 3, total);
      _excelSetCell(monthlySheet, r + 1, 4, present);
      _excelSetCell(monthlySheet, r + 1, 5, absent);
      _excelSetCell(monthlySheet, r + 1, 6, late);
      _excelSetCell(monthlySheet, r + 1, 7, leave);
      _excelSetCell(monthlySheet, r + 1, 8, '$pct%');
    }

    // Subject Statistics Sheet
    final subjectSheet = excel['Subject Statistics'];
    _excelSetCell(subjectSheet, 0, 0, 'Subject Statistics Summary');
    _excelSetCell(subjectSheet, 2, 0, 'Metric');
    _excelSetCell(subjectSheet, 2, 1, 'Value');
    _excelSetCell(subjectSheet, 3, 0, 'Total Sessions');
    _excelSetCell(subjectSheet, 3, 1, sessions.length);
    _excelSetCell(subjectSheet, 4, 0, 'Total Students');
    _excelSetCell(subjectSheet, 4, 1, stats['total'] as int);
    _excelSetCell(subjectSheet, 5, 0, 'Average Attendance');
    _excelSetCell(subjectSheet, 5, 1, '${(stats['avgPct'] as double).toStringAsFixed(1)}%');
    _excelSetCell(subjectSheet, 6, 0, 'Eligible Students');
    _excelSetCell(subjectSheet, 6, 1, stats['present'] as int);
    _excelSetCell(subjectSheet, 7, 0, 'At Risk Students');
    _excelSetCell(subjectSheet, 7, 1, stats['atRisk'] as int);
    _excelSetCell(subjectSheet, 8, 0, 'Defaulters');
    _excelSetCell(subjectSheet, 8, 1, stats['absent'] as int);

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
    }
  }

  void _excelSetCell(xl.Sheet sheet, int row, int col, dynamic value) {
    sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value =
        value is int
            ? xl.IntCellValue(value)
            : value is double
                ? xl.DoubleCellValue(value)
                : xl.TextCellValue(value.toString());
  }

  // ==================== CSV ====================
  Future<void> _generateCSV(
    File file,
    List<ClassStudent> students,
    List<AttendanceSession> sessions,
    ReportType type,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('IntelliAttend - Faculty Attendance Management');
    buffer.writeln('');
    buffer.writeln('Student Name,Roll Number,Student ID,Department,Section,Email,Present Classes,Absent Classes,Total Classes,Attendance %,Status,Remarks');

    for (final s in students) {
      final present = s.attendedClasses;
      final absent = s.totalClasses - s.attendedClasses;
      final pct = s.attendancePercentage;
      final status = pct >= 75 ? 'Eligible' : pct >= 65 ? 'At Risk' : 'Defaulter';
      final remarks = pct >= 85 ? 'Excellent' : pct >= 75 ? 'Good' : pct >= 65 ? 'Needs Improvement' : 'Critical';

      buffer.writeln(
        '"${s.name}","${s.rollNumber}","${s.id}","${s.department ?? ''}","${s.section ?? ''}","${s.email ?? ''}",$present,$absent,${s.totalClasses},${pct.toStringAsFixed(1)}%,$status,$remarks',
      );
    }

    buffer.writeln('');
    buffer.writeln('Session History');
    buffer.writeln('Date,Course,Section,Total Students,Present,Absent,Late,Leave,Attendance %');

    for (final s in sessions) {
      final total = s.totalStudents;
      final present = s.presentCount;
      final absent = s.absentCount;
      final late = s.lateCount;
      final leave = s.leaveCount;
      final pct = total > 0 ? (present / total * 100).toStringAsFixed(1) : '0.0';
      buffer.writeln(
        '${DateFormat('dd MMM yyyy').format(s.date)},${s.courseCode},${s.section},$total,$present,$absent,$late,$leave,$pct%',
      );
    }

    await file.writeAsString(buffer.toString());
  }

  // ==================== JSON ====================
  Future<void> _generateJSON(
    File file,
    List<ClassStudent> students,
    List<AttendanceSession> sessions,
    ReportType type,
    String? courseCode,
    String? section,
    String? semester,
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    final stats = _computeStats(students);
    final now = DateTime.now();

    final data = {
      'faculty': {
        'name': 'Dr. Rajesh Kumar',
        'department': 'Computer Science & Engineering',
        'email': 'rajesh.kumar@mrcet.ac.in',
      },
      'subject': {
        'code': courseCode ?? 'ALL',
        'name': 'Attendance Report',
        'section': section ?? 'All',
        'semester': semester ?? 'Current',
      },
      'report': {
        'type': type.name,
        'title': _reportTypeLabel(type),
        'dateRange': {
          'from': dateFrom.toIso8601String(),
          'to': dateTo.toIso8601String(),
        },
        'generatedAt': now.toIso8601String(),
        'academicYear': '2024-2025',
      },
      'statistics': {
        'totalStudents': stats['total'],
        'present': stats['present'],
        'atRisk': stats['atRisk'],
        'defaulter': stats['absent'],
        'averageAttendance': double.parse((stats['avgPct'] as double).toStringAsFixed(1)),
      },
      'students': students.map((s) => {
        'id': s.id,
        'name': s.name,
        'rollNumber': s.rollNumber,
        'department': s.department,
        'section': s.section,
        'email': s.email,
        'attendedClasses': s.attendedClasses,
        'totalClasses': s.totalClasses,
        'attendancePercentage': s.attendancePercentage,
        'status': s.attendancePercentage >= 75 ? 'Eligible' : s.attendancePercentage >= 65 ? 'At Risk' : 'Defaulter',
        'remarks': s.attendancePercentage >= 85 ? 'Excellent' : s.attendancePercentage >= 75 ? 'Good' : s.attendancePercentage >= 65 ? 'Needs Improvement' : 'Critical',
      }).toList(),
      'sessions': sessions.map((s) => {
        'date': s.date.toIso8601String(),
        'courseCode': s.courseCode,
        'section': s.section,
        'totalStudents': s.totalStudents,
        'presentCount': s.presentCount,
        'absentCount': s.absentCount,
        'lateCount': s.lateCount,
        'leaveCount': s.leaveCount,
      }).toList(),
      'metadata': {
        'generatedBy': 'IntelliAttend Faculty App',
        'version': '1.0.0',
        'format': 'JSON',
      },
    };

    final encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(data));
  }

  String _reportTypeLabel(ReportType type) {
    switch (type) {
      case ReportType.attendance:
        return 'Attendance Report';
      case ReportType.studentList:
        return 'Student List Report';
      case ReportType.sessionSummary:
        return 'Session Summary Report';
      case ReportType.daily:
        return 'Daily Attendance Report';
      case ReportType.weekly:
        return 'Weekly Attendance Report';
      case ReportType.monthly:
        return 'Monthly Attendance Report';
      case ReportType.subject:
        return 'Subject Report';
      case ReportType.department:
        return 'Department Report';
    }
  }

  List<ClassStudent> _fetchRealStudents({String? courseCode, String? section}) {
    final students = <ClassStudent>[];
    try {
      final keys = PersistenceService.academicBox.get('roster_keys');
      if (keys is List) {
        for (final key in keys) {
          final keyStr = key.toString();
          final raw = PersistenceService.academicBox.get('roster_$keyStr');
          if (raw is List) {
            for (final entry in raw) {
              if (entry is Map) {
                final data = Map<String, dynamic>.from(entry);
                final id = data['id']?.toString() ?? data['student_id']?.toString() ?? '';
                final name = data['name']?.toString() ?? '';
                if (id.isEmpty || name.isEmpty) continue;

                final attended = data['attended'] is num ? (data['attended'] as num).toInt() : 0;
                final total = data['total'] is num ? (data['total'] as num).toInt() : 1;
                final pct = total > 0 ? (attended / total * 100) : 0.0;

                students.add(ClassStudent(
                  id: id,
                  name: name,
                  rollNumber: data['roll_number']?.toString() ?? '',
                  email: data['email']?.toString() ?? '',
                  phone: data['phone']?.toString() ?? '',
                  department: data['department']?.toString() ?? '',
                  section: (data['section']?.toString() ?? keyStr).replaceFirst(RegExp(r'_\d{4}$'), ''),
                  courseCode: data['course_code']?.toString() ?? courseCode ?? '',
                  courseName: data['course_name']?.toString() ?? '',
                  semester: data['semester']?.toString() ?? '',
                  attendancePercentage: double.parse(pct.toStringAsFixed(1)),
                  totalClasses: total,
                  attendedClasses: attended,
                  isEligible: pct >= 75.0,
                  isDefaulter: pct < 75.0,
                  gender: data['gender']?.toString() ?? '',
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      print('ExportReportsRepository: _fetchRealStudents error: $e');
    }
    return students;
  }

  List<AttendanceSession> _fetchRealSessions({String? courseCode, String? section}) {
    final sessions = <AttendanceSession>[];
    try {
      final keys = PersistenceService.academicBox.get('roster_keys');
      if (keys is List) {
        for (final key in keys) {
          final keyStr = key.toString();
          final raw = PersistenceService.academicBox.get('roster_$keyStr');
          if (raw is! List || raw.isEmpty) continue;

          int totalStudents = raw.length;
          int totalAttended = 0;
          String courseCodeLocal = '';
          String courseNameLocal = '';
          String sectionLocal = keyStr;

          for (final entry in raw) {
            if (entry is Map) {
              final data = Map<String, dynamic>.from(entry);
              final attended = data['attended'] is num ? (data['attended'] as num).toInt() : 0;
              totalAttended += attended;
              if (courseCodeLocal.isEmpty) courseCodeLocal = (data['course_code'] ?? '').toString();
              if (courseNameLocal.isEmpty) courseNameLocal = (data['course_name'] ?? '').toString();
              if (sectionLocal == keyStr) sectionLocal = (data['section'] ?? keyStr).toString();
            }
          }

          final presentCount = totalAttended;
          final absentCount = totalStudents - totalAttended;
          final lateCount = 0;
          final leaveCount = 0;

          sessions.add(AttendanceSession(
            sessionId: 'SESSION_$keyStr',
            courseCode: courseCode ?? courseCodeLocal,
            courseName: courseNameLocal,
            section: section ?? sectionLocal,
            date: DateTime.now(),
            totalStudents: totalStudents,
            presentCount: presentCount,
            absentCount: absentCount,
            lateCount: lateCount,
            leaveCount: leaveCount,
            status: 'completed',
          ));
        }
      }
    } catch (e) {
      print('ExportReportsRepository: _fetchRealSessions error: $e');
    }
    return sessions;
  }
}
