import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notifications",
          style: TextStyle(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<List<AppNotification>>(
            valueListenable: NotificationService.history,
            builder: (context, history, _) {
              if (history.isEmpty) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => service.markAllAsRead(),
                child: Text("Read All", style: TextStyle(color: AppTheme.primary(context))),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<AppNotification>>(
        valueListenable: NotificationService.history,
        builder: (context, history, _) {
          if (history.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final notification = history[index];
                    return _buildNotificationTile(context, notification, service);
                  },
                ),
              ),
              if (history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: TextButton(
                    onPressed: () => service.clearAll(),
                    child: Text(
                      "Clear All Notifications",
                      style: TextStyle(color: AppTheme.slate500(context), fontSize: 13),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.primary(context).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, 
                size: 80, color: AppTheme.primary(context).withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          Text(
            "No notifications yet",
            style: TextStyle(
              color: AppTheme.text(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll notify you when something\nimportant happens.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, AppNotification notification, NotificationService service) {
    return InkWell(
      onTap: () => service.markAsRead(notification.id),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : AppTheme.primary(context).withValues(alpha: 0.03),
          border: Border(
            bottom: BorderSide(color: AppTheme.border(context).withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryIcon(context, notification.category),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.text(context),
                            fontSize: 15,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(notification.timestamp),
                        style: TextStyle(
                          color: AppTheme.slate500(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textSecondary(context),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(left: 12, top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.primary(context),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(BuildContext context, NotificationCategory category) {
    IconData icon;
    Color color;

    switch (category) {
      case NotificationCategory.attendance:
        icon = Icons.person_search_rounded;
        color = Colors.blue;
        break;
      case NotificationCategory.assignment:
        icon = Icons.assignment_turned_in_rounded;
        color = Colors.orange;
        break;
      case NotificationCategory.security:
        icon = Icons.security_rounded;
        color = Colors.red;
        break;
      case NotificationCategory.system:
        icon = Icons.info_rounded;
        color = AppTheme.primary(context);
        break;
      case NotificationCategory.chat:
        icon = Icons.chat_rounded;
        color = AppTheme.greenOnline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
