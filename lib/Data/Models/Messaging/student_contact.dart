import 'chat_enums.dart';

/// Contact / peer profile used inside conversations.
///
/// The `id` is the canonical backend identity (student id / email). The
/// [StudentContact] also carries the presence fields needed by the chat
/// header (online, last seen, custom status).
class StudentContact {
  final String id;
  final String name;
  final String? rollNumber;
  final String? email;
  final String? phone;
  final String? department;
  final String? section;
  final String? courseCode;
  final String? courseName;
  final String? avatarUrl;
  final String? initials;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? customStatus;
  final bool isFaculty;

  const StudentContact({
    required this.id,
    required this.name,
    this.rollNumber,
    this.email,
    this.phone,
    this.department,
    this.section,
    this.courseCode,
    this.courseName,
    this.avatarUrl,
    this.initials,
    this.isOnline = false,
    this.lastSeen,
    this.customStatus,
    this.isFaculty = false,
  });

  factory StudentContact.fromJson(Map<String, dynamic> json) {
    return StudentContact(
      id: json['id']?.toString() ?? json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      rollNumber: json['roll_number']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      department: json['department']?.toString(),
      section: json['section']?.toString(),
      courseCode: json['course_code']?.toString(),
      courseName: json['course_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      initials: json['initials']?.toString(),
      isOnline: json['is_online'] == true,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString())
          : null,
      customStatus: json['custom_status']?.toString(),
      isFaculty: json['is_faculty'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roll_number': rollNumber,
      'email': email,
      'phone': phone,
      'department': department,
      'section': section,
      'course_code': courseCode,
      'course_name': courseName,
      'avatar_url': avatarUrl,
      'initials': initials,
      'is_online': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'custom_status': customStatus,
      'is_faculty': isFaculty,
    };
  }

  StudentContact copyWith({
    bool? isOnline,
    DateTime? lastSeen,
    String? customStatus,
    String? avatarUrl,
    String? name,
  }) {
    return StudentContact(
      id: id,
      name: name ?? this.name,
      rollNumber: rollNumber,
      email: email,
      phone: phone,
      department: department,
      section: section,
      courseCode: courseCode,
      courseName: courseName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      initials: initials,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      customStatus: customStatus ?? this.customStatus,
      isFaculty: isFaculty,
    );
  }

  /// Two-letter initials derived from the name (for avatar fallback).
  String get initialsValue {
    if (initials != null && initials!.isNotEmpty) return initials!;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get displayTitle {
    if (rollNumber != null && rollNumber!.isNotEmpty) {
      return '$name • $rollNumber';
    }
    return name;
  }
}

/// An excerpt of the message being replied to / forwarded preview.
class ReplyPreview {
  final String messageId;
  final String senderName;
  final String text;
  final MessageContentType type;

  const ReplyPreview({
    required this.messageId,
    required this.senderName,
    required this.text,
    required this.type,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      messageId: json['message_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      type: MessageContentType.fromJson(json['type']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'sender_name': senderName,
      'text': text,
      'type': type.toJson(),
    };
  }
}
