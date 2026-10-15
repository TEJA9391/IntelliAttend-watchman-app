import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intelli_attend_faculty/Data/Models/Messaging/messaging_models.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/chat_time_format.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/Widgets/message_bubble.dart';

/// Message info screen with delivery/read/edit timestamps.
class MessageInfoScreen extends StatelessWidget {
  final ChatMessage message;

  const MessageInfoScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.direction == MessageDirection.outgoing;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Message info',
            style: GoogleFonts.inter(color: AppTheme.text(context), fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Message preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: MessageBubble(
                message: message.copyWith(isSelected: false),
                isOutgoing: isOutgoing,
                showTail: true,
              ),
            ),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Sent by',
              value: isOutgoing ? 'You' : message.senderName,
            ),
            if (isOutgoing)
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Sent',
                value: ChatTimeFormat.full(message.timestamp),
                isPending: message.status == MessageStatus.pending,
              )
            else
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Received',
                value: ChatTimeFormat.full(message.timestamp),
              ),
            if (isOutgoing && message.deliveredAt != null)
              _InfoRow(
                icon: Icons.done_all_rounded,
                label: 'Delivered',
                value: ChatTimeFormat.full(message.deliveredAt!),
              ),
            if (isOutgoing && message.readAt != null)
              _InfoRow(
                icon: Icons.done_all_rounded,
                label: 'Read',
                value: ChatTimeFormat.full(message.readAt!),
              ),
            if (message.editedAt != null)
              _InfoRow(
                icon: Icons.edit_rounded,
                label: 'Edited',
                value: ChatTimeFormat.full(message.editedAt!),
              ),
            if (message.isForwarded)
              _InfoRow(icon: Icons.forward_rounded, label: 'Forwarded', value: 'Yes'),
            if (message.isPinned)
              _InfoRow(icon: Icons.push_pin_rounded, label: 'Pinned', value: 'Yes'),
            if (message.isStarred)
              _InfoRow(icon: Icons.star_rounded, label: 'Starred', value: 'Yes'),
            if (isOutgoing)
              _InfoRow(
                icon: Icons.verified_outlined,
                label: 'Status',
                value: _statusLabel(message.status),
              ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'ID: ${message.id}',
                style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Message age: ${now.difference(message.timestamp).inMinutes} min',
                style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(MessageStatus status) {
    switch (status) {
      case MessageStatus.pending:
        return 'Pending (offline)';
      case MessageStatus.sending:
        return 'Sending…';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.read:
        return 'Read';
      case MessageStatus.failed:
        return 'Failed to send';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPending;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: isPending ? AppTheme.accentGold : AppTheme.primary(context)),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    color: isPending ? AppTheme.accentGold : AppTheme.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
