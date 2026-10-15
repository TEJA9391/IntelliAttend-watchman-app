import 'package:flutter/foundation.dart';
import 'package:flutter_badge_manager/flutter_badge_manager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

enum NotificationCategory { attendance, system, assignment, security, chat }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationCategory category;
  final String? payload;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.category = NotificationCategory.system,
    this.payload,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'category': category.index,
        'payload': payload,
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'],
        title: json['title'],
        body: json['body'],
        timestamp: DateTime.parse(json['timestamp']),
        category: NotificationCategory.values[json['category'] ?? 1],
        payload: json['payload']?.toString(),
        isRead: json['isRead'] ?? false,
      );
}

/// Central notification manager.
///
/// Owns the two Android channels (chat + system), the messaging-style chat
/// preview with a custom sound, the in-app [history] feed, and the launcher
/// unread badge. [init] is idempotent and safe to call from a background
/// isolate (FCM background handler), so notification delivery never depends on
/// the app being foregrounded.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _chatChannelId = 'chat_messages';
  static const String _systemChannelId = 'intelliattend_channel';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Reactive state for the in-app notifications screen + dashboard bell.
  static final ValueNotifier<List<AppNotification>> history =
      ValueNotifier<List<AppNotification>>([]);

  static int get unreadCount => history.value.where((n) => !n.isRead).length;
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Registered by the app shell to deep-link on notification tap
  /// (e.g. the `chat:<conversationId>` payload opens the chat screen).
  static void Function(String payload)? onPayloadTap;

  static bool _initialized = false;
  static Future<void>? _initFuture;

  /// conversationId of the conversation currently open in the chat UI.
  static String? _activeConversationId;
  static String? get activeConversationId => _activeConversationId;

  static void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  static bool isConversationActive(String conversationId) =>
      _activeConversationId == conversationId;

  /// Message key dedup: the WebSocket watcher and FCM can both deliver the
  /// same message, but only the first caller wins the right to alert.
  static String? _lastChatKey;
  static bool claimChatNotification(String key) {
    if (key.isEmpty) return true;
    if (_lastChatKey == key) return false;
    _lastChatKey = key;
    return true;
  }

  /// Idempotent, background-isolate-safe init.
  Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _doInit();
    await _initFuture;
  }

  Future<void> _doInit() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_chat');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        onPayloadTap?.call(payload);
      },
    );

    await _createChannels();

    // Cold start: the app was opened by tapping a notification.
    final details = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final payload = details?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        onPayloadTap?.call(payload);
      }
    }

    _initialized = true;
  }

  Future<void> _createChannels() async {
    final AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      _chatChannelId,
      'Chat Messages',
      description: 'New messages from your conversations',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('chat_notification'),
      vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
      enableVibration: true,
      enableLights: true,
    );

    const AndroidNotificationChannel systemChannel = AndroidNotificationChannel(
      _systemChannelId,
      'Class Reminders',
      description: 'Notifications for class starts and announcements',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(chatChannel);
      await android.createNotificationChannel(systemChannel);
    }
  }

  Future<void> loadFromDisk() async {
    await init();
    if (!Hive.isBoxOpen('notifications')) return;
    final box = Hive.box('notifications');
    final List<dynamic>? stored = box.get('history');
    if (stored != null) {
      history.value = stored
          .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      _updateUnreadCount();
    }
  }

  void _saveToDisk() {
    if (!Hive.isBoxOpen('notifications')) return;
    Hive.box('notifications').put('history', history.value.map((n) => n.toJson()).toList());
  }

  /// Adds an entry to the in-app notification history feed.
  /// (System alerts for chat are shown separately via [showChatNotification].)
  Future<void> addNotification({
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.system,
    String? payload,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      category: category,
      payload: payload,
    );

    history.value = [notification, ...history.value];
    _updateUnreadCount();
    _saveToDisk();
  }

  /// Shows the messaging-style chat alert (custom sound, group by
  /// conversation so the latest message replaces the previous one).
  Future<void> showChatNotification({
    required String conversationId,
    required String senderName,
    required String message,
    required String title,
  }) async {
    await init();

    final id = conversationId.hashCode & 0x7fffffff;
    final peer = Person(name: senderName);
    final messagingStyle = MessagingStyleInformation(
      peer,
      groupConversation: true,
      messages: [Message(message, DateTime.now(), peer)],
    );

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _chatChannelId,
      'Chat Messages',
      channelDescription: 'New messages from your conversations',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: messagingStyle,
      groupKey: 'chat_group',
      ticker: senderName,
    );

    await _notificationsPlugin.show(
      id,
      title,
      message,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'chat:$conversationId',
    );
  }

  void markAllAsRead() {
    final List<AppNotification> updated = history.value.map((n) {
      n.isRead = true;
      return n;
    }).toList();
    history.value = updated;
    _updateUnreadCount();
    _saveToDisk();
  }

  void markAsRead(String id) {
    final index = history.value.indexWhere((n) => n.id == id);
    if (index != -1) {
      final List<AppNotification> updated = List.from(history.value);
      updated[index].isRead = true;
      history.value = updated;
      _updateUnreadCount();
      _saveToDisk();
    }
  }

  void clearAll() {
    history.value = [];
    _updateUnreadCount();
    _saveToDisk();
  }

  void clearAllLocally() {
    history.value = [];
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    unreadCountNotifier.value = history.value.where((n) => !n.isRead).length;
  }

  /// Compatibility wrapper for existing calls.
  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    await showSystemNotification(id: id, title: title, body: body, payload: payload);
  }

  Future<void> showSystemNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _systemChannelId,
      'Class Reminders',
      channelDescription: 'Notifications for class starts and announcements',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Updates the launcher (home screen) unread badge. Best-effort: launchers
  /// that do not support numeric badges simply ignore the call.
  Future<void> syncBadgeCount(int count) async {
    try {
      await FlutterBadgeManager.instance.update(count);
    } catch (_) {
      // Badge unsupported on this launcher/device — never crash for this.
    }
  }
}
