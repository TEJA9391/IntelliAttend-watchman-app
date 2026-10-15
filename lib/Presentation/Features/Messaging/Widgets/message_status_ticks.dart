import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';

/// WhatsApp-style delivery ticks.
///   failed  → clock icon (retryable)
///   pending → single outlined tick
///   sent    → single tick
///   delivered → double tick
///   read    → double blue tick
class MessageStatusTicks extends StatelessWidget {
  final MessageStatus status;
  final double size;
  final Color? color;

  const MessageStatusTicks({
    super.key,
    required this.status,
    this.size = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color c;
    switch (status) {
      case MessageStatus.failed:
        return Icon(Icons.schedule, size: size, color: color);
      case MessageStatus.pending:
        return Icon(Icons.schedule, size: size, color: color);
      case MessageStatus.sending:
        c = color ?? const Color(0xFF9CA3AF);
        return Icon(Icons.done, size: size, color: c);
      case MessageStatus.sent:
        c = color ?? const Color(0xFF9CA3AF);
        return Icon(Icons.done, size: size, color: c);
      case MessageStatus.delivered:
        c = color ?? const Color(0xFF9CA3AF);
        return Icon(Icons.done_all, size: size, color: c);
      case MessageStatus.read:
        c = color ?? const Color(0xFF3B82F6);
        return Icon(Icons.done_all, size: size, color: c);
    }
  }
}
