enum ExportFormat { pdf, excel, csv, json }

enum ReportType {
  attendance,
  studentList,
  sessionSummary,
  daily,
  weekly,
  monthly,
  subject,
  department,
}

class ExportReport {
  final String id;
  final String title;
  final ReportType type;
  final ExportFormat format;
  final DateTime generatedAt;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? courseCode;
  final String? section;
  final String? semester;
  final int recordCount;
  final String? filePath;
  final String? fileName;
  final double fileSizeKB;
  final String status;
  final int exportDurationMs;

  ExportReport({
    required this.id,
    required this.title,
    required this.type,
    required this.format,
    required this.generatedAt,
    this.dateFrom,
    this.dateTo,
    this.courseCode,
    this.section,
    this.semester,
    this.recordCount = 0,
    this.filePath,
    this.fileName,
    this.fileSizeKB = 0.0,
    this.status = 'completed',
    this.exportDurationMs = 0,
  });

  ExportReport copyWith({
    String? id,
    String? title,
    ReportType? type,
    ExportFormat? format,
    DateTime? generatedAt,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? courseCode,
    String? section,
    String? semester,
    int? recordCount,
    String? filePath,
    String? fileName,
    double? fileSizeKB,
    String? status,
    int? exportDurationMs,
  }) {
    return ExportReport(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      format: format ?? this.format,
      generatedAt: generatedAt ?? this.generatedAt,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      courseCode: courseCode ?? this.courseCode,
      section: section ?? this.section,
      semester: semester ?? this.semester,
      recordCount: recordCount ?? this.recordCount,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSizeKB: fileSizeKB ?? this.fileSizeKB,
      status: status ?? this.status,
      exportDurationMs: exportDurationMs ?? this.exportDurationMs,
    );
  }

  factory ExportReport.fromJson(Map<String, dynamic> json) {
    return ExportReport(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: _parseReportType(json['type']?.toString()),
      format: _parseFormat(json['format']?.toString()),
      generatedAt:
          DateTime.tryParse(json['generated_at']?.toString() ?? '') ?? DateTime.now(),
      dateFrom: json['date_from'] != null
          ? DateTime.tryParse(json['date_from'].toString())
          : null,
      dateTo: json['date_to'] != null
          ? DateTime.tryParse(json['date_to'].toString())
          : null,
      courseCode: json['course_code']?.toString(),
      section: json['section']?.toString(),
      semester: json['semester']?.toString(),
      recordCount: json['record_count'] as int? ?? 0,
      filePath: json['file_path']?.toString(),
      fileName: json['file_name']?.toString(),
      fileSizeKB: (json['file_size_kb'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'completed',
      exportDurationMs: json['export_duration_ms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.name,
      'format': format.name,
      'generated_at': generatedAt.toIso8601String(),
      if (dateFrom != null) 'date_from': dateFrom!.toIso8601String(),
      if (dateTo != null) 'date_to': dateTo!.toIso8601String(),
      if (courseCode != null) 'course_code': courseCode,
      if (section != null) 'section': section,
      if (semester != null) 'semester': semester,
      'record_count': recordCount,
      if (filePath != null) 'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      'file_size_kb': fileSizeKB,
      'status': status,
      'export_duration_ms': exportDurationMs,
    };
  }

  static ReportType _parseReportType(String? value) {
    switch (value) {
      case 'studentList':
        return ReportType.studentList;
      case 'sessionSummary':
        return ReportType.sessionSummary;
      case 'daily':
        return ReportType.daily;
      case 'weekly':
        return ReportType.weekly;
      case 'monthly':
        return ReportType.monthly;
      case 'subject':
        return ReportType.subject;
      case 'department':
        return ReportType.department;
      default:
        return ReportType.attendance;
    }
  }

  static ExportFormat _parseFormat(String? value) {
    switch (value) {
      case 'excel':
        return ExportFormat.excel;
      case 'csv':
        return ExportFormat.csv;
      case 'json':
        return ExportFormat.json;
      default:
        return ExportFormat.pdf;
    }
  }
}
