import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class NotificationDetailScreen extends StatefulWidget {
  final AppNotification notification;

  const NotificationDetailScreen({Key? key, required this.notification}) : super(key: key);

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late AppNotification notification;

  @override
  void initState() {
    super.initState();
    notification = widget.notification;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notification",
          style: GoogleFonts.inter(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.text(context),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Text(
                notification.body,
                maxLines: 20,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  height: 1.7,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textSecondary(context)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    "Received on ${_formatTimestamp(notification.timestamp)}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(color: AppTheme.textSecondary(context), fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateFormat('d MMMM yyyy \'at\' h:mm a').format(local);
  }
}
