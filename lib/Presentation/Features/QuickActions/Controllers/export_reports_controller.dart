import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import 'package:intelli_attend_faculty/Data/Models/QuickActions/export_report.dart';
import 'package:intelli_attend_faculty/Data/Repositories/QuickActions/export_reports_repository.dart';

class ExportReportsController extends ChangeNotifier {
  final ExportReportsRepository _repository;

  List<ExportReport> _reports = [];
  bool _isLoading = false;
  bool _isGenerating = false;
  bool _isExporting = false;
  String? _error;
  double _exportProgress = 0.0;
  String _exportStatusText = '';

  ReportType? _selectedType;
  ExportFormat _selectedFormat = ExportFormat.pdf;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _courseCode;
  String? _section;
  String? _semester;

  ExportReportsController(this._repository);

  Map<String, List<String>> _filterOptions = {'courses': [], 'sections': [], 'semesters': []};
  Map<String, List<String>> get filterOptions => _filterOptions;

  List<String> get availableCourses => _filterOptions['courses'] ?? [];
  List<String> get availableSections => _filterOptions['sections'] ?? [];
  List<String> get availableSemesters => _filterOptions['semesters'] ?? [];

  List<ExportReport> get reports => _reports;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  bool get isExporting => _isExporting;
  bool get hasMore => false;
  String? get error => _error;
  ReportType? get selectedType => _selectedType;
  ExportFormat get selectedFormat => _selectedFormat;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;
  String? get courseCode => _courseCode;
  String? get section => _section;
  String? get semester => _semester;
  double get exportProgress => _exportProgress;
  String get exportStatusText => _exportStatusText;

  Future<void> loadReports({ReportType? type}) async {
    _isLoading = true;
    _error = null;
    if (type != null) _selectedType = type;
    notifyListeners();

    try {
      _filterOptions = _repository.fetchFilterOptions();
      _reports = _repository.fetchReports(type: _selectedType);
    } catch (e) {
      _error = 'Failed to load reports: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {}

  Future<ExportReport?> generateReport({
    required ReportType type,
    required ExportFormat format,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? courseCode,
    String? section,
    String? semester,
  }) async {
    _isGenerating = true;
    _isExporting = true;
    _exportProgress = 0.0;
    _exportStatusText = 'Preparing data...';
    _error = null;
    notifyListeners();

    try {
      _exportProgress = 0.2;
      _exportStatusText = 'Generating ${format.name.toUpperCase()} file...';
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 200));

      _exportProgress = 0.5;
      _exportStatusText = 'Processing attendance records...';
      notifyListeners();

      final report = await _repository.generateReport(
        type: type,
        format: format,
        dateFrom: dateFrom ?? _dateFrom,
        dateTo: dateTo ?? _dateTo,
        courseCode: courseCode ?? _courseCode,
        section: section ?? _section,
        semester: semester ?? _semester,
      );

      _exportProgress = 0.9;
      _exportStatusText = 'Finalizing export...';
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 300));

      _reports = _repository.fetchReports(type: _selectedType);
      _exportProgress = 1.0;
      _exportStatusText = 'Complete!';
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 500));

      _isGenerating = false;
      _isExporting = false;
      _exportProgress = 0.0;
      _exportStatusText = '';
      notifyListeners();
      return report;
    } catch (e) {
      _error = 'Failed to generate report: $e';
      _isGenerating = false;
      _isExporting = false;
      _exportProgress = 0.0;
      _exportStatusText = '';
      notifyListeners();
      return null;
    }
  }

  Future<String?> downloadReport(String reportId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final report = _reports.firstWhere((r) => r.id == reportId);
      if (report.filePath != null) {
        final file = File(report.filePath!);
        if (await file.exists()) {
          _isLoading = false;
          notifyListeners();
          return report.filePath;
        }
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Report not found';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> openReport(String reportId) async {
    try {
      final report = _reports.firstWhere((r) => r.id == reportId);
      await _repository.openReport(report);
    } catch (e) {
      _error = 'Failed to open report: $e';
      notifyListeners();
    }
  }

  Future<void> shareReport(String reportId) async {
    try {
      final report = _reports.firstWhere((r) => r.id == reportId);
      await _repository.shareReport(report);
    } catch (e) {
      _error = 'Failed to share report: $e';
      notifyListeners();
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      final report = _reports.firstWhere((r) => r.id == reportId);
      await _repository.deleteReport(report);
      _reports = _repository.fetchReports(type: _selectedType);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete report: $e';
      notifyListeners();
    }
  }

  Future<void> printReport(String reportId) async {
    try {
      final report = _reports.firstWhere((r) => r.id == reportId);
      if (report.filePath != null && report.format == ExportFormat.pdf) {
        final file = File(report.filePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => bytes,
            name: report.title,
          );
        }
      }
    } catch (e) {
      _error = 'Failed to print report: $e';
      notifyListeners();
    }
  }

  void setTypeFilter(ReportType? type) {
    if (_selectedType == type) {
      _selectedType = null;
    } else {
      _selectedType = type;
    }
    notifyListeners();
  }

  void setFormat(ExportFormat format) {
    _selectedFormat = format;
    notifyListeners();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _dateFrom = from;
    _dateTo = to;
    notifyListeners();
  }

  void setCourseCode(String? code) {
    _courseCode = code;
    notifyListeners();
  }

  void setSection(String? sec) {
    _section = sec;
    notifyListeners();
  }

  void setSemester(String? sem) {
    _semester = sem;
    notifyListeners();
  }

  void clearFilters() {
    _selectedType = null;
    _selectedFormat = ExportFormat.pdf;
    _dateFrom = null;
    _dateTo = null;
    _courseCode = null;
    _section = null;
    _semester = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadReports();
  }
}
