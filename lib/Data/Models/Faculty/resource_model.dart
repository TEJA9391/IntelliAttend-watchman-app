class ResourceItem {
  final String id;
  final String facultyId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String scope;
  final String securityStatus;
  final String? createdAt;
  final String? institutionId;
  final List<String> allowedSections;
  final String? subjectCode;

  ResourceItem({
    required this.id,
    required this.facultyId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.scope,
    required this.securityStatus,
    this.createdAt,
    this.institutionId,
    this.allowedSections = const [],
    this.subjectCode,
  });

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      id: json['id']?.toString() ?? '',
      facultyId: json['faculty_id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? 'Unknown',
      fileSize: (json['file_size'] as int?) ?? 0,
      mimeType: json['mime_type']?.toString() ?? 'application/octet-stream',
      scope: json['scope']?.toString() ?? 'faculty_private',
      securityStatus: json['security_status']?.toString() ?? 'UNKNOWN',
      createdAt: json['created_at']?.toString(),
      institutionId: json['institution_id']?.toString(),
      allowedSections: (json['allowed_sections'] as List?)?.map((e) => e.toString()).toList() ?? [],
      subjectCode: json['subject_code']?.toString(),
    );
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1048576) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / 1048576).toStringAsFixed(1)} MB';
  }

  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  String get createdAtFormatted {
    if (createdAt == null) return '-';
    try {
      final dt = DateTime.parse(createdAt!);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return createdAt!;
    }
  }

  bool get isPdf => mimeType.contains('pdf') || fileName.endsWith('.pdf');
  bool get isPowerpoint => mimeType.contains('presentation') || fileName.endsWith('.ppt') || fileName.endsWith('.pptx');
  bool get isWord => mimeType.contains('document') || fileName.endsWith('.doc') || fileName.endsWith('.docx');
  bool get isImage => mimeType.startsWith('image/');
}
