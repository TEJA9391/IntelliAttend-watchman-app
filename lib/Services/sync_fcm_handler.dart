import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'board_readiness_notifier.dart';
import 'chat_notification_service.dart';
import 'faculty_hydration_service.dart';
import 'faculty_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final data = message.data;
  final type = data['type'] ?? '';
  final action = data['action'] ?? '';

  if (type == 'SILENT_SYNC_PING' && action == 'INVALIDATE_LOCAL_DB') {
    debugPrint("FCM Background: Sync ping received — invalidating local DB");
    await FacultyHydrationService().syncIfNeeded();
  }

  if (type == 'SESSION_PREPARING') {
    await _showClassNotification(data, 'Class Preparing', 'is about to start');
    final slotId = data['slot_id'] ?? '';
    if (slotId.isNotEmpty) {
      BoardReadinessNotifier.instance.markReady(slotId);
    }
    return;
  }

  if (type == 'BOARD_RECOVERED') {
    await _showClassNotification(data, 'Board Reconnected', 'board is ready — swipe to start');
    final slotId = data['slot_id'] ?? '';
    if (slotId.isNotEmpty) {
      BoardReadinessNotifier.instance.markReady(slotId);
    }
    return;
  }

  if (type == 'SESSION_LATE_START') {
    final sessionId = data['session_id'] ?? '';
    final subjectName = data['subject_name'] ?? '';
    final endTime = data['end_time'] ?? '';
    debugPrint("FCM Background: SESSION_LATE_START — $subjectName ends at $endTime");
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.showSystemNotification(
      id: 8889,
      title: 'Attendance Not Taken',
      body: subjectName.isNotEmpty
          ? '$subjectName is ending at $endTime — no attendance recorded yet'
          : 'Class ending soon — no attendance recorded yet',
      payload: 'session_late_start:$sessionId',
    );
    return;
  }

  if (type == 'chat_message') {
    await _showChatNotificationBackground(data);
    return;
  }
}

/// Killed/background chat push: the background isolate cannot read the Hive
/// mute/active state, so it always alerts. Foreground delivery is handled by
/// [ChatNotificationService], which applies mute + open-conversation rules.
Future<void> _showChatNotificationBackground(Map<String, dynamic> data) async {
  final conversationId = data['conversation_id']?.toString();
  if (conversationId == null || conversationId.isEmpty) return;
  final senderId = data['sender_id']?.toString();
  if (senderId == FacultyService.canonicalId) return;

  final text = data['text']?.toString().trim() ?? '';
  final body = text.isNotEmpty
      ? text
      : data['content_summary']?.toString() ?? 'New message';
  final senderName = data['sender_name']?.toString() ?? 'New message';
  final title = data['title']?.toString() ?? senderName;

  final service = NotificationService();
  await service.init();
  await service.showChatNotification(
    conversationId: conversationId,
    senderName: senderName,
    message: body,
    title: title,
  );
}

Future<void> _showClassNotification(Map<String, dynamic> data, String title, String verb) async {
  final sessionId = data['session_id'] ?? '';
  final subjectName = data['subject_name'] ?? '';
  final startTime = data['start_time'] ?? '';
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.showSystemNotification(
    id: 8888,
    title: title,
    body: subjectName.isNotEmpty
        ? '$subjectName $verb${startTime.isNotEmpty ? " at $startTime" : ""}'
        : 'Your next class session $verb',
    payload: 'session_preparing:$sessionId',
  );
}

class SyncFcmHandler {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      final type = data['type'] ?? '';

      if (type == 'SILENT_SYNC_PING' && data['action'] == 'INVALIDATE_LOCAL_DB') {
        debugPrint("FCM Foreground: Sync ping received — invalidating local DB");
        FacultyHydrationService().syncIfNeeded();
        return;
      }

      if (type == 'SESSION_PREPARING') {
        _showClassNotification(data, 'Class Preparing', 'is about to start');
        final slotId = data['slot_id'] ?? '';
        if (slotId.isNotEmpty) {
          BoardReadinessNotifier.instance.markReady(slotId);
        }
        return;
      }

      if (type == 'BOARD_RECOVERED') {
        _showClassNotification(data, 'Board Reconnected', 'board is ready — swipe to start');
        final slotId = data['slot_id'] ?? '';
        if (slotId.isNotEmpty) {
          BoardReadinessNotifier.instance.markReady(slotId);
        }
        return;
      }

      if (type == 'SESSION_LATE_START') {
        final sessionId = data['session_id'] ?? '';
        final subjectName = data['subject_name'] ?? '';
        final endTime = data['end_time'] ?? '';
        debugPrint("FCM Foreground: SESSION_LATE_START — $subjectName ends at $endTime");
        NotificationService().showSystemNotification(
          id: 8889,
          title: 'Attendance Not Taken',
          body: subjectName.isNotEmpty
              ? '$subjectName is ending at $endTime — no attendance recorded yet'
              : 'Class ending soon — no attendance recorded yet',
          payload: 'session_late_start:$sessionId',
        );
        return;
      }

      // Foreground chat pushes are merged with the WebSocket stream: mute,
      // open-conversation and FCM/WS dedup are handled by the coordinator.
      if (type == 'chat_message') {
        ChatNotificationService.instance.handleRemoteChatMessage(data);
        return;
      }
    });

    // Killed state: the app was launched by tapping a notification.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      final conversationId = initialMessage.data['conversation_id']?.toString();
      if (conversationId != null && conversationId.isNotEmpty) {
        debugPrint('FCM: initial message opens chat $conversationId');
        NotificationService.onPayloadTap?.call('chat:$conversationId');
      }
    }

    // App in background/tray: user taps the notification to deep-link in.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final conversationId = message.data['conversation_id']?.toString();
      if (conversationId != null && conversationId.isNotEmpty) {
        NotificationService.onPayloadTap?.call('chat:$conversationId');
      }
    });

    final token = await messaging.getToken();
    if (token != null) {
      await _uploadFcmToken(token);
    }

    messaging.onTokenRefresh.listen(_uploadFcmToken);
    debugPrint("SyncFcmHandler initialized");
  }

  static Future<void> _uploadFcmToken(String token) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await ApiClient().dio.post(
            '/api/v1/faculty/device/fcm-token',
            data: {'fcm_token': token},
          );
        }
        debugPrint('FCM token registered.');
        return;
      } catch (e) {
        debugPrint('FCM token upload attempt $attempt/$maxAttempts failed: $e');
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
  }
}
