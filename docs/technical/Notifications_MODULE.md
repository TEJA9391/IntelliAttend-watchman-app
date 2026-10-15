# IntelliAttend Faculty — Notifications Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Notifications (In-App Notification List + Firebase Cloud Messaging Push Pipeline)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/HOME_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/MYCLASS_MODULE.md`, `docs/technical/PROFILE_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`NotificationsScreen` — the In-App List](#5-notificationsscreen--the-in-app-list)
6. [`NotificationDetailScreen` — the Orphaned Detail Surface](#6-notificationdetailscreen--the-orphaned-detail-surface)
7. [Dashboard Entry Point — Header Bell & Badge](#7-dashboard-entry-point--header-bell--badge)
8. [Push Infrastructure Deep Dive — FCM (`SyncFcmHandler`)](#8-push-infrastructure-deep-dive--fcm-syncfcmhandler)
9. [FCM Message Types & Local Rendering](#9-fcm-message-types--local-rendering)
10. [Deep-Link / Tap Handling (`MessagingRouter`)](#10-deep-link--tap-handling-messagingrouter)
11. [Data Models & DTOs](#11-data-models--dtos)
12. [Backend API Reference](#12-backend-api-reference)
13. [WebSocket Real-Time Protocol](#13-websocket-real-time-protocol)
14. [Navigation Map](#14-navigation-map)
15. [Sequence Diagrams](#15-sequence-diagrams)
16. [Error Handling & Edge Cases](#16-error-handling--edge-cases)
17. [Performance Engineering](#17-performance-engineering)
18. [Security](#18-security)
19. [Dependencies Used](#19-dependencies-used)
20. [File Inventory](#20-file-inventory)
21. [Appendix A — Known Design Notes & Technical Debt](#21-appendix-a--known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **Notifications module** is split into two very different halves:

1. **In-app notification list** — a local, purely client-side surface: `NotificationsScreen` renders a `ValueNotifier`-backed list of `AppNotification` objects hydrated from an encrypted Hive box. There is **no server-side notification list, no REST fetch, and no pagination**.
2. **Push infrastructure** — a full Firebase Cloud Messaging (FCM) pipeline: permission request, token generation, token upload to the backend, foreground/background data-message handlers, local notification rendering via `flutter_local_notifications`, and payload-based deep-linking into the chat feature.

### 1.2 Business Goal

- Give faculty a **bell icon with an unread badge** on the dashboard header and a full-screen list of in-app notifications.
- Keep faculty informed of **session lifecycle events** (class preparing, board recovered, late-start warnings) and **silent sync pings** that invalidate local caches.
- Route notification taps to a **conversation in the chat UI** via payload deep-linking.

### 1.3 Problem Statement

- Push is event-driven and must work in **foreground, background, and terminated** app states — three different handler contexts.
- The faculty backend must know the device's push token to target pushes; token registration must survive app restarts and token refreshes.
- In-app notification history should survive restarts (local persistence) while system-level notifications are rendered by the OS.

### 1.4 Solution

- `NotificationService` (singleton): owns the local `FlutterLocalNotificationsPlugin`, the reactive `history` notifier, Hive persistence, and the `onPayloadTap` deep-link hook (`notification_service.dart`).
- `SyncFcmHandler` (static): registers `onBackgroundMessage` + `onMessage`, obtains and uploads the FCM token, and dispatches data-message types (`sync_fcm_handler.dart`).
- `MessagingRouter`: maps a tapped payload (`chat:<conversationId>`) to the `ChatScreen`, with pending-deep-link buffering until the navigator exists.
- The in-app list is populated **only** by `NotificationService.addNotification(...)` — a method that has **no callers anywhere in the repo** (see A-2).

### 1.5 Target Users

- **Faculty members** — the bell entry point on the dashboard header; the push pipeline serves every logged-in faculty device.

### 1.6 Faculty Workflow (Notifications-driven)

```
Dashboard header bell (with unread badge) ──► NotificationsScreen
   ├─ list of AppNotification rows (title/body/category/timestamp)
   ├─ "Read All" (markAllAsRead) · "Clear All Notifications" (clearAll)
   └─ tap row → markAsRead (no navigation — detail screen unreachable, A-3)

OS notification tapped (chat:<id>) ──► MessagingRouter → ChatScreen
OS notification tapped (session_* payload) ──► no handler (A-5)
```

---

## 2. Layered Architecture & Data Flow

```
┌────────────────────────────────────────────────────────────────────────────┐
│  PRESENTATION                                                              │
│  NotificationsScreen (list) · NotificationDetailScreen (orphaned, A-3)      │
│  DashboardHeader bell/badge (entry point)                                  │
└──────────┬─────────────────────────────────────────────────────────────────┘
           │ ValueListenableBuilder<List<AppNotification>>
┌──────────▼─────────────────────────────────────────────────────────────────┐
│  SERVICES (singletons)                                                     │
│  NotificationService  → history ValueNotifier + Hive persistence           │
│                         + FlutterLocalNotificationsPlugin                   │
│                         + onPayloadTap deep-link hook                       │
│  SyncFcmHandler       → FirebaseMessaging handlers + token upload           │
│  MessagingRouter      → payload → ChatScreen routing                        │
│  FacultyHydrationService → syncIfNeeded() (SILENT_SYNC_PING target)         │
│  BoardReadinessNotifier → markReady(slot_id) (ChangeNotifier)               │
└──────┬──────────────────────────────┬───────────────────────────────────────┘
       │ Hive 'notifications' box      │ HTTPS (via ApiClient().dio, JWT)
       │ (AES-encrypted, key 'history')│
┌──────▼──────────────────┐   ┌───────▼───────────────────────────────────────┐
│  PERSISTENCE            │   │  INFRA / NETWORK                              │
│  PersistenceService     │   │  ApiClient (Dio, JWT bearer, interceptors)    │
│   - initRemainingBoxes  │   │  FirebaseMessaging (token + handlers)         │
│  SharedPreferences      │   │  FirebaseAuth (identity gate for upload)      │
│   - fcm_token           │   │  FirebaseAuth.requestPermission               │
└─────────────────────────┘   └───────────────────────────────────────────────┘
                │ HTTPS
        POST /api/v1/faculty/device/fcm-token
        POST /api/v1/auth/verify-session (embeds fcm_token)
        GET  /api/v1/faculty/sync        (SILENT_SYNC_PING trigger)
```

### 2.1 Two independent data flows

| Flow | Producer → Consumer | Transport |
|---|---|---|
| **In-app history** | `NotificationService.addNotification` → `history` notifier → `NotificationsScreen` / header badge; persisted to Hive `'notifications'` box | local only (no API) |
| **System push** | FCM data message → `onMessage` / background handler → `showSystemNotification` → OS notification | FCM + local plugin |

The two flows never meet: system-level push notifications are **not** appended to `history` (A-6), and `history` is never hydrated from the network (A-1).

---

## 3. State Management Wiring

The module uses **`ValueNotifier` + `ValueListenableBuilder`** exclusively for the in-app list, a `static` callback field for deep-linking, and plain `ChangeNotifier` (`BoardReadinessNotifier`) for board readiness.

| State / concern | Mechanism | Location |
|---|---|---|
| In-app notification list | `static final ValueNotifier<List<AppNotification>> history` | `notification_service.dart:51` |
| Unread badge state | recomputed inline by header (`history.where((n) => !n.isRead).length`) | `dashboard_header.dart:150` |
| Unread notifier (unconsumed) | `static final ValueNotifier<int> unreadCountNotifier` + `static int get unreadCount` | `notification_service.dart:53-54` |
| Deep-link hook | `static void Function(String payload)? onPayloadTap` (assigned once in `main.dart`) | `notification_service.dart:58`, `main.dart:120` |
| Board readiness (push-driven) | `BoardReadinessNotifier.instance` (`ChangeNotifier`, singleton) | `board_readiness_notifier.dart` |
| HTTP client | `ApiClient()` singleton (Dio, JWT interceptor) | `sync_fcm_handler.dart:147` |
| Identity for token upload | `FirebaseAuth.instance.currentUser` read directly | `sync_fcm_handler.dart:144` |

**Access pattern:** screens wrap the whole body in `ValueListenableBuilder<List<AppNotification>>(valueListenable: NotificationService.history, ...)`, so `markAsRead`, `markAllAsRead`, and `clearAll` propagate live with no controller. `DashboardController` registers a listener on `BoardReadinessNotifier.instance` to re-read timetable readiness (`dashboard_controller.dart:70`).

---

## 4. Screen Structure — Widget Tree

### 4.1 `NotificationsScreen`

```
Scaffold (bg: AppTheme.bg)
└─ AppBar (bg: AppTheme.surface, elevation 0, centerTitle)
   ├─ leading back (arrow_back_ios_new_rounded) → Navigator.pop
   ├─ title "Notifications" (bold, 20)
   └─ actions:
        ValueListenableBuilder(NotificationService.history)
           ├─ history.isEmpty → SizedBox.shrink()
           └─ TextButton "Read All" → service.markAllAsRead()
└─ body: ValueListenableBuilder(NotificationService.history)
     ├─ history.isEmpty → _buildEmptyState()
     │    └─ Center → Column
     │         ├─ circular tinted icon (notifications_none_rounded, 80)
     │         ├─ "No notifications yet" (18 bold)
     │         └─ "We'll notify you when something\nimportant happens."
     └─ history.isNotEmpty → Column
          ├─ Expanded(ListView.builder, padding v16)
          │    └─ _buildNotificationTile(notification, service)
          │         └─ InkWell(onTap → markAsRead(id))
          │              ├─ Container (read: transparent /
          │              │    unread: primary 0.03 tint + bottom border)
          │              ├─ _buildCategoryIcon(category)  (attendance=blue,
          │              │    assignment=orange, security=red, system=primary)
          │              ├─ Expanded Column
          │              │    ├─ Row [title (w900 unread / w600 read), 
          │              │    │      _formatTimestamp]   ("Xm ago"/"Xh ago"/MMM d)
          │              │    └─ body (13, textSecondary, maxLines 2)
          │              └─ unread dot (8x8 primary circle) when !isRead
          └─ TextButton "Clear All Notifications" → service.clearAll()
```

### 4.2 `NotificationDetailScreen`

```
Scaffold (bg: AppTheme.bg)
└─ AppBar (bg: AppTheme.bg, elevation 0, centerTitle)
   ├─ leading back → Navigator.pop
   └─ title "Notification" (GoogleFonts.inter, bold, 18)
└─ body: SingleChildScrollView (padding LTRB 20,8,20,40)
     ├─ title (inter 22 bold, maxLines 3)
     ├─ Container card (radius 16, border) → body (inter 16, height 1.7, maxLines 20)
     └─ Row [access_time icon, "Received on <d MMMM yyyy at h:mm a>"]
```

---

## 5. `NotificationsScreen` — the In-App List

**File:** `lib/Presentation/Features/Notifications/notifications_screen.dart` (229 non-blank LOC)

- `StatelessWidget` with a no-arg const constructor; a pure navigation target from the dashboard header.
- Creates a fresh `NotificationService()` each build (`notifications_screen.dart:11`) — the singleton factory returns the same instance, so this is harmless.
- Body is a `ValueListenableBuilder<List<AppNotification>>` over `NotificationService.history` (`notifications_screen.dart:44-46`).
- **Empty state** is the primary production outcome today: since nothing ever calls `addNotification`, `history` is empty and the screen always shows "No notifications yet" (A-2).
- **No pagination** — the full in-memory list is rendered by a `ListView.builder` with `itemCount: history.length` (`notifications_screen.dart:55-62`).
- **No pull-to-refresh** — no `RefreshIndicator`; the list only changes when a service method mutates `history`.
- Row tap → `service.markAsRead(notification.id)` only (`notifications_screen.dart:122`); **it does not navigate to the detail screen** (A-3).
- "Read All" (`notifications_screen.dart:37`) and "Clear All Notifications" (`notifications_screen.dart:68`) are wired to `markAllAsRead` / `clearAll`.
- Category → icon/color mapping (`notifications_screen.dart:195-226`): `attendance` (blue, `person_search_rounded`), `assignment` (orange, `assignment_turned_in_rounded`), `security` (red, `security_rounded`), `system` (primary, `info_rounded`).
- Relative timestamps (`notifications_screen.dart:228-239`): `<60m` → "Xm ago", `<24h` → "Xh ago", else `DateFormat('MMM d')`.

---

## 6. `NotificationDetailScreen` — the Orphaned Detail Surface

**File:** `lib/Presentation/Features/Notifications/notification_detail_screen.dart` (101 non-blank LOC)

- `StatefulWidget` taking a required `AppNotification` (`notification_detail_screen.dart:7-10`).
- Renders title (inter 22 bold), a card with the full body (inter 16, `maxLines: 20`), and an absolute received timestamp via `DateFormat('d MMMM yyyy \'at\' h:mm a')` (`notification_detail_screen.dart:104-107`).
- **Dead code:** a repo-wide search finds **no caller** — no screen, router, or builder ever constructs `NotificationDetailScreen`. It is unreachable from the current UI (A-3). There is no detail/body-expansion on the list screen to compensate.

---

## 7. Dashboard Entry Point — Header Bell & Badge

**File:** `lib/Presentation/Features/Faculty/Components/dashboard_header.dart` (207 non-blank LOC)

- Bell is a `GestureDetector` inside a 40x40 circular pill, wrapped in `ValueListenableBuilder<List<AppNotification>>` (`dashboard_header.dart:147-198`).
- Unread count computed inline: `history.where((n) => !n.isRead).length` (`dashboard_header.dart:150`); badge shows `'9+'` when > 9 (`dashboard_header.dart:182`).
- Tap → `Navigator.push(MaterialPageRoute(NotificationsScreen))` (`dashboard_header.dart:152-155`).
- **Because `history` is never populated (A-2), the badge is permanently absent** — the unread dot and `9+` logic are currently unreachable in production.
- The header bell is the **only** entry point to `NotificationsScreen` in the codebase.

Permission request lifecycle: `_DashboardScreenState.initState → _initData()` awaits `FacultyService.load()` then calls `_requestNotificationPermission()` (`dashboard_screen.dart:50-53`), which invokes `FirebaseMessaging.instance.requestPermission(alert, badge, sound)` inside a try/catch that only `debugPrint`s failures (`dashboard_screen.dart:55-65`).

A second, independent permission check exists in `SecurityController`: notification permission is a "security pillar" (`notificationsOk`, `security_controller.dart:72`), evaluated via `PermissionService().isNotificationGranted()` (`security_controller.dart:325`, `permission_service.dart:26`), and auto-requested through `autoRequestPermissions()` (`security_controller.dart:316-321`).

---

## 8. Push Infrastructure Deep Dive — FCM (`SyncFcmHandler`)

**File:** `lib/Services/sync_fcm_handler.dart` (138 non-blank LOC)

Bootstrapped once from `_bootstrapBackground` after the first frame: `unawaited(SyncFcmHandler.init())` (`main.dart:124`).

### 8.1 Registration & handler setup (`init`, sync_fcm_handler.dart:76-136)

```dart
final messaging = FirebaseMessaging.instance;
FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler); // sync_fcm_handler.dart:82
FirebaseMessaging.onMessage.listen((RemoteMessage message) { ... });        // sync_fcm_handler.dart:84
final token = await messaging.getToken();                                   // sync_fcm_handler.dart:128
if (token != null) { await _uploadFcmToken(token); }                        // sync_fcm_handler.dart:131
messaging.onTokenRefresh.listen(_uploadFcmToken);                           // sync_fcm_handler.dart:134
```

- `_initialized` guard (`sync_fcm_handler.dart:74-78`) makes `init` single-flight.
- Foreground handler and background handler share the same message-type switch (see §9).

### 8.2 Token upload (`_uploadFcmToken`, sync_fcm_handler.dart:138-156)

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('fcm_token', token);                       // local cache
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  await ApiClient().dio.post('/api/v1/faculty/device/fcm-token',
      data: {'fcm_token': token});                               // sync_fcm_handler.dart:147-150
}
```

- Token is cached under SharedPreferences key `fcm_token` **before** upload, then uploaded only if a Firebase user is signed in.
- The whole body is wrapped in `try/catch`; every failure is reduced to `debugPrint("FCM Token upload error: $e")` (`sync_fcm_handler.dart:153-155`). **No retry, no backoff, no queue** (A-4).
- `onTokenRefresh` re-uploads on token rotation; the refreshed token also replaces the cached one via the same `_uploadFcmToken`.

### 8.3 Token reuse at device binding (`auth_repository.dart:87-113`)

`AuthRepository.verifySession` reads the cached token from prefs (`fcm_token`) and embeds it in the `POST /api/v1/auth/verify-session` body when present (`auth_repository.dart:92,100`). So the backend can also learn the token at login/device-verification time — a second registration path distinct from the FCM handler.

### 8.4 Registration timing gap

`SyncFcmHandler.init()` runs in Track B (post-first-frame) and uploads only when a Firebase user exists at that moment. If the user signs in later (e.g., the app cold-starts to the login screen), the token was cached in prefs and will ride along on the next `verifySession` — but `getToken`/`onTokenRefresh` upload is not re-attempted after login (A-4).

---

## 9. FCM Message Types & Local Rendering

Push messages are **data messages**; both handlers key off `message.data['type']`.

| `type` | `action`/payload keys | Foreground handler | Background handler |
|---|---|---|---|
| `SILENT_SYNC_PING` | `action == 'INVALIDATE_LOCAL_DB'` | `FacultyHydrationService().syncIfNeeded()` (sync_fcm_handler.dart:88-92) | same (sync_fcm_handler.dart:16-19) |
| `SESSION_PREPARING` | `session_id`, `subject_name`, `start_time`, `slot_id` | local notification id **8888** "Class Preparing" + `BoardReadinessNotifier.markReady(slot_id)` (sync_fcm_handler.dart:94-101) | `_showClassNotification` (sync_fcm_handler.dart:21-28) |
| `BOARD_RECOVERED` | `session_id`, `subject_name`, `start_time`, `slot_id` | local notification id **8888** "Board Reconnected" + `markReady(slot_id)` (sync_fcm_handler.dart:103-110) | same (sync_fcm_handler.dart:30-37) |
| `SESSION_LATE_START` | `session_id`, `subject_name`, `end_time` | local notification id **8889** "Attendance Not Taken" (sync_fcm_handler.dart:112-125) | same via `NotificationService` (sync_fcm_handler.dart:39-54) |
| anything else | — | silently ignored | silently ignored |

### 9.1 Local notification rendering (`notification_service.dart:183-210`)

- Single Android channel `intelliattend_channel` ("Class Reminders", "Notifications for class starts and announcements"), `Importance.max`, `Priority.high` (`notification_service.dart:189-196`).
- `showSystemNotification({int id = 0, title, body, payload})` → `_notificationsPlugin.show(...)`.
- **Fixed, hard-coded notification ids** `8888` and `8889` in `sync_fcm_handler.dart` (A-12); the chat feature instead uses `DateTime.now().millisecondsSinceEpoch` as the id (`chat_list_controller.dart:328`).
- These calls never touch `history` — push events are **not** recorded in the in-app list (A-6).

### 9.2 Background handler caution (A-9)

The background isolate handler calls `NotificationService().init()` per message (`sync_fcm_handler.dart:45,62`) — re-initializing the `FlutterLocalNotificationsPlugin` (and re-registering `onDidReceiveNotificationResponse`) inside a background isolate on each event. This works today but is fragile; plugin init in background isolates is platform-sensitive.

---

## 10. Deep-Link / Tap Handling (`MessagingRouter`)

**File:** `lib/Presentation/Features/Messaging/messaging_router.dart` (66 non-blank LOC)

- `NotificationService.onPayloadTap = MessagingRouter.openChatFromPayload` is assigned once during Track B (`main.dart:120`).
- `NotificationService.init()` registers `onDidReceiveNotificationResponse` → forwards `response.payload` to `onPayloadTap` (`notification_service.dart:77-81`), and also checks `getNotificationAppLaunchDetails()` for cold-start taps (`notification_service.dart:85-91`).
- `MessagingRouter.openChatFromPayload`:
  - Accepts only payloads starting with `chat:` (`messaging_router.dart:18-21`).
  - If the navigator isn't ready yet, buffers the conversation id in `_pendingConversationId` (`messaging_router.dart:23-27`).
  - Otherwise resolves the conversation from `MessageCacheService` or reconstructs a shell (`demo_*`/`direct_*` peer prefixes, `ChatDemoData` lookup, fallback `StudentContact`) and `navigator.push(ChatScreen)` (`messaging_router.dart:43-75`).
- Pending deep-link flush: `MessagingRouter.flushPending()` runs in the first post-frame callback (`main.dart:63-71`) and pushes the buffered conversation once the `IntelliAttendApp.navigatorKey` navigator exists (`main.dart:141`, wired at `main.dart:208`).
- **Gap:** the `session_preparing:<id>` / `session_late_start:<id>` payloads produced by `sync_fcm_handler.dart:52,69,123` are never consumed by any handler (A-5).

---

## 11. Data Models & DTOs

### 11.1 `AppNotification` (`notification_service.dart:7-41`)

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | client-generated (`DateTime.now().millisecondsSinceEpoch.toString()` in `addNotification`, `notification_service.dart:118`) |
| `title` | `String` | |
| `body` | `String` | |
| `timestamp` | `DateTime` | stored/read as ISO-8601 string |
| `category` | `NotificationCategory` | stored as `category.index`; default `system` |
| `isRead` | `bool` | mutable; default `false` |

- `fromJson` (notification_service.dart:33-40): `category: NotificationCategory.values[json['category'] ?? 1]` — an **absent or null category defaults to index 1 (`system`)**; `isRead` defaults false. `DateTime.parse` is unguarded (A-10).

### 11.2 `NotificationCategory` (`notification_service.dart:5`)

```dart
enum NotificationCategory { attendance, system, assignment, security }
```

Rendered only by `NotificationsScreen._buildCategoryIcon` (attendance/assignment/security/system). Note index 0 = `attendance`, index 1 = `system` — the fallback in `fromJson`.

There are **no module-specific server DTOs** — the notification list has no network contract (A-1). FCM payloads are consumed as raw `Map<String, dynamic>` (`message.data`), keyed by `type`, `action`, `session_id`, `slot_id`, `subject_name`, `start_time`, `end_time`.

---

## 12. Backend API Reference

| Endpoint | Verb | Used by | Notes |
|---|---|---|---|
| `/api/v1/faculty/device/fcm-token` | POST | `SyncFcmHandler._uploadFcmToken` (sync_fcm_handler.dart:148) | body `{ 'fcm_token': <token> }`; no timeout override (client defaults); error swallowed |
| `/api/v1/auth/verify-session` | POST | `AuthRepository.verifySession` (auth_repository.dart:94-102) | embeds `fcm_token` from prefs when cached (auth_repository.dart:100); device binding |
| `/api/v1/faculty/sync` | GET | `FacultyHydrationService.syncIfNeeded` (faculty_hydration_service.dart:69-75) | triggered by `SILENT_SYNC_PING`; 10 s send/receive timeouts |

**There is no notification-list endpoint.** The in-app history has no server source of truth — it is a purely local, encrypted Hive-backed list (A-1). All HTTP goes through `ApiClient().dio` (JWT bearer interceptor, TLS). Base: `https://api-dev.balaseetharamanjaneya.com`.

---

## 13. WebSocket Real-Time Protocol

The Notifications module opens **no WebSocket channels** and performs **no polling** for notifications. The only push transport is **Firebase Cloud Messaging** (data messages) plus OS-local notifications rendered by `flutter_local_notifications`. The in-app list is not streamed or polled from any server — it is local-only state (A-1). (The Messaging feature, which feeds some `chat:` payloads, uses its own realtime transport via `ChatRealtimeController` — out of scope here.)

---

## 14. Navigation Map

```
DashboardHeader bell (dashboard_header.dart:152-155)
   └─► NotificationsScreen
        ├─ row tap ──► markAsRead(id)  (no navigation)
        ├─ "Read All" ──► markAllAsRead()
        └─ "Clear All Notifications" ──► clearAll()

NotificationDetailScreen ──► (unreachable — no callers, A-3)

FCM/local tap with payload:
   chat:<conversationId> ──► NotificationService.onPayloadTap
        └─ MessagingRouter.openChatFromPayload ──► ChatScreen
             (buffered via flushPending() if navigator not ready)
   session_preparing:<id> / session_late_start:<id> ──► no handler (A-5)

Chat incoming message (chat_list_controller.dart:325-334)
   └─ NotificationService().showSystemNotification(payload: 'chat:<id>')
```

All routes are anonymous `MaterialPageRoute`s; no named routes or tab for notifications. The push pipeline does not deep-link into `NotificationsScreen` or `NotificationDetailScreen`.

---

## 15. Sequence Diagrams

### 15.1 FCM token registration (app boot)

```
main() → _bootstrapBackground() (post-first-frame, main.dart:63-71)
   └─ unawaited(SyncFcmHandler.init())
        ├─ _initialized guard
        ├─ FirebaseMessaging.onBackgroundMessage(...)
        ├─ FirebaseMessaging.onMessage.listen(...)
        ├─ token = await messaging.getToken()
        │    └─ null → skip upload silently (A-4)
        ├─ _uploadFcmToken(token)
        │    ├─ prefs.setString('fcm_token', token)        (SharedPreferences)
        │    ├─ user = FirebaseAuth.currentUser
        │    │    └─ null → skip upload (token cached only)
        │    └─ dio.post('/api/v1/faculty/device/fcm-token', {fcm_token})
        │         ├─ success → debugPrint("uploaded")
        │         └─ DioException/other → debugPrint only, no retry (A-4)
        └─ messaging.onTokenRefresh.listen(_uploadFcmToken)   (rotation)

(Later) login/device binding:
   verifySession ──► reads prefs fcm_token ──► POST /auth/verify-session (+fcm_token)
```

### 15.2 Push delivery (data message)

```
FCM data message
   ├─ app foreground → onMessage.listen
   └─ app background/terminated → _firebaseMessagingBackgroundHandler
        ├─ SILENT_SYNC_PING / INVALIDATE_LOCAL_DB → FacultyHydrationService.syncIfNeeded()
        │     └─ GET /api/v1/faculty/sync → manifest hash check → wipe+rehydrate | serve cache
        ├─ SESSION_PREPARING | BOARD_RECOVERED
        │     └─ local notification id 8888 (payload session_*:<sessionId>)
        │        + BoardReadinessNotifier.markReady(slot_id) → DashboardController rebuild
        ├─ SESSION_LATE_START
        │     └─ local notification id 8889 "Attendance Not Taken"
        │        (payload session_late_start:<sessionId>)
        └─ unknown type → ignored
```

### 15.3 Tap notification → deep-link → chat

```
OS notification tapped (payload 'chat:<conversationId>')
   ├─ app running  → onDidReceiveNotificationResponse → onPayloadTap
   └─ cold start   → getNotificationAppLaunchDetails → onPayloadTap
        └─ MessagingRouter.openChatFromPayload(payload)
             ├─ not 'chat:' → return (session_* payloads drop here, A-5)
             ├─ navigator not ready → _pendingConversationId = id
             │    └─ (post-frame) flushPending() → _openConversation
             └─ _openConversation
                  ├─ MessageCacheService.loadConversations() lookup
                  ├─ miss → reconstruct shell (demo_/direct_ peer / ChatDemoData)
                  └─ navigator.push(ChatScreen(conversation))
```

---

## 16. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| `messaging.getToken()` returns null | upload silently skipped (A-4) |
| Token upload throws (network/auth/HTTP) | `debugPrint("FCM Token upload error: $e")` only — **no retry, no user feedback, no queue** (A-4) |
| No Firebase user at boot | token cached in prefs, upload deferred until next `verifySession` |
| Permission denied / `requestPermission` throws | caught in `dashboard_screen.dart:62-64` (`debugPrint`); `SecurityController` re-checks pillar |
| FCM message with unknown `type` | silently ignored by both handlers |
| Tap payload empty / not `chat:` | `onPayloadTap` skips empty; `MessagingRouter` ignores non-`chat:` payloads (session_* dropped, A-5) |
| Navigator not ready on tap | payload buffered; flushed by `MessagingRouter.flushPending()` post-frame |
| Corrupt Hive history JSON | `loadFromDisk` calls `DateTime.parse`/`fromJson` with **no try/catch** → startup throw (A-10) |
| Notification permission revoked at runtime | `SecurityController._checkPermissionsSilently` re-evaluates `notificationsOk` on resume; gate status changes |
| `history` empty | dedicated empty state ("No notifications yet") — the de facto production state (A-2) |
| Local notification plugin init in background isolate | re-initialized per message — fragile on some platforms (A-9) |

---

## 17. Performance Engineering

- **Two-track startup**: Hive boxes (incl. `notifications`) open in Track B post-first-frame (`persistence_service.dart:68-80`); `NotificationService().init()` and `SyncFcmHandler.init()` also run deferred — nothing blocks first paint.
- **Scoped rebuilds**: `ValueListenableBuilder` limits list/badge rebuilds to widgets that read `history`; the header badge and list never rebuild together unnecessarily.
- **Small, local data**: the list is an in-memory `List<AppNotification>` with Hive persistence; `ListView.builder` renders only visible rows. No server round-trip exists to be slow (but see A-1).
- **Single-flight FCM init**: `_initialized` guard prevents duplicate handler registration and `getToken` calls.
- **Token refresh handled reactively**: `onTokenRefresh` uploads without re-running the whole init sequence.
- **Relative-time formatting is O(1) per tile** (`_formatTimestamp`, `notifications_screen.dart:228-239`) — no per-frame timers; timestamps go stale until rebuild.

---

## 18. Security

- **Hive notifications box is AES-encrypted** — opened with the same `HiveAesCipher` derived from `hive_encryption_key` stored in `FlutterSecureStorage` (`persistence_service.dart:38-47,71`).
- **Token transport**: upload and verify-session rides `ApiClient().dio` (JWT bearer interceptor, TLS). Upload gated on a signed-in Firebase user (`sync_fcm_handler.dart:144-145`).
- **Token at rest**: cached under SharedPreferences key `fcm_token` in **plaintext** (A-7), and partially logged (`token.substring(0, 16)` at `sync_fcm_handler.dart:130`) — a 16-char prefix leak in debug logs.
- **Payload validation**: deep-link handler strictly requires the `chat:` prefix and a non-empty id before touching navigation (`messaging_router.dart:19-21`); unknown payload types never reach navigation.
- **Server-side targeting not verifiable from the client**: `POST /api/v1/faculty/device/fcm-token` is fire-and-forget; a failed upload leaves the backend without a working push target and no client signal (A-4).

---

## 19. Dependencies Used

| Package | Version (pubspec) | Where used |
|---|---|---|
| `firebase_messaging` | `^15.0.0` | `SyncFcmHandler` token + handlers; `requestPermission` (dashboard_screen.dart:57) |
| `flutter_local_notifications` | `^17.1.2` | `NotificationService` plugin, Android channel, payload taps |
| `hive` / `hive_flutter` | `^2.2.3` / `^1.1.0` | `notifications` box (AES-encrypted), key `history` |
| `shared_preferences` | `^2.2.1` | `fcm_token` cache; consumed by verify-session |
| `firebase_auth` | `^5.1.1` | identity gate for token upload |
| `dio` | `^5.3.3` | fcm-token upload + verify-session + sync via `ApiClient` |
| `flutter_secure_storage` | `^9.2.4` | Hive encryption key |
| `provider` | `^6.0.5` | `ApiClient` provider (indirect) |
| `google_fonts` / `intl` | `^6.1.0` / `^0.19.0` | detail-screen typography / date formatting |

---

## 20. File Inventory

> Line counts = non-blank lines (`Measure-Object -Line`).

### 20.1 Notifications feature — `lib/Presentation/Features/Notifications/`

| File | LOC | Role |
|---|---|---|
| `notifications_screen.dart` | 229 | In-app list: empty state, tiles, category icons, Read All / Clear All |
| `notification_detail_screen.dart` | 101 | Detail surface — **unreachable, no callers (A-3)** |

### 20.2 Services / infrastructure

| File | LOC | Role |
|---|---|---|
| `lib/Services/notification_service.dart` | 184 | `AppNotification` + `NotificationService` (plugin, history, Hive, payload hook) |
| `lib/Services/sync_fcm_handler.dart` | 138 | FCM background/foreground handlers, token get/upload, message-type dispatch |
| `lib/Services/persistence_service.dart` | 122 | `notifications` box open (AES), `loadFromDisk`, `clearAllData` teardown |
| `lib/Services/faculty_hydration_service.dart` | 218 | `syncIfNeeded` — target of `SILENT_SYNC_PING` |
| `lib/Services/board_readiness_notifier.dart` | 25 | `ChangeNotifier` store marked ready by SESSION_PREPARING/BOARD_RECOVERED |
| `lib/Services/permission_service.dart` | 22 | `isNotificationGranted` / `requestAll` (security pillar) |
| `lib/Data/Repositories/auth_repository.dart` | 139 | `verifySession` embeds `fcm_token` |
| `lib/Core/Services/security_controller.dart` | 325 | notification permission pillar + auto-request |

### 20.3 Presentation wiring

| File | LOC | Role |
|---|---|---|
| `lib/main.dart` | 247 | Track B bootstrap: `NotificationService().init()`, `onPayloadTap`, `SyncFcmHandler.init()`, `flushPending()`, `navigatorKey` |
| `lib/Presentation/Features/Faculty/dashboard_screen.dart` | 364 | `_requestNotificationPermission` (dashboard_screen.dart:55-65) |
| `lib/Presentation/Features/Faculty/Components/dashboard_header.dart` | 207 | Bell + unread badge + route to `NotificationsScreen` |
| `lib/Presentation/Features/Messaging/messaging_router.dart` | 66 | `chat:` payload → `ChatScreen` routing + pending flush |
| `lib/Presentation/Features/Messaging/chat_list_controller.dart` | 298 | emits incoming-chat local notifications with `chat:` payloads (chat_list_controller.dart:325-334) |

---

## 21. Appendix A — Known Design Notes & Technical Debt

### A-1. No server-side notification list — in-app history is 100% local (HIGH)

There is **no notification endpoint** in the codebase (`grep /api/v1/` finds none). `NotificationService.history` is hydrated exclusively from the encrypted Hive `notifications` box (key `history`) and mutated only by local methods. Notifications never sync across devices, are lost on reinstall, and the backend has no record of read state. The list feature has no network contract at all.

### A-2. `addNotification` is never called — the in-app list is permanently empty (HIGH)

A repo-wide search for `addNotification` finds only its definition (`notification_service.dart:112`). Nothing ever writes a new `AppNotification` into `history`. Combined with A-1, the production outcome is: `NotificationsScreen` always renders "No notifications yet", the header bell never shows a badge, and the `unread > 9 ? '9+'` logic is unreachable. The entire list UI is effectively dead until a producer (FCM handler or an API) starts calling `addNotification`.

### A-3. `NotificationDetailScreen` is orphaned dead code (MEDIUM)

No widget, router, or builder references `NotificationDetailScreen`. The list row tap only calls `markAsRead(id)` (`notifications_screen.dart:122`) and never navigates. Either wire the row tap to the detail screen or delete the file.

### A-4. FCM token upload failures are silently swallowed (HIGH)

`_uploadFcmToken` wraps the prefs write + `POST /api/v1/faculty/device/fcm-token` in a bare `try/catch` that only `debugPrint`s (`sync_fcm_handler.dart:153-155`). No retry, backoff, queue, or user signal. A transient network failure at boot permanently drops the token server-side; the app believes it succeeded ("FCM Token uploaded successfully." is printed unconditionally on the happy path only, but the failure path is equally silent). There is also no re-upload triggered by a later sign-in.

### A-5. `session_preparing:` / `session_late_start:` payloads are never handled on tap (MEDIUM)

The FCM handlers emit local notifications whose payloads are `session_preparing:<sessionId>` (`sync_fcm_handler.dart:69`) and `session_late_start:<sessionId>` (`sync_fcm_handler.dart:52,123`). `MessagingRouter.openChatFromPayload` accepts only `chat:` payloads, and no other `onPayloadTap` handler exists — tapping these notifications does nothing beyond dismissing the OS alert.

### A-6. System push notifications never enter the in-app history (MEDIUM)

All FCM-driven notifications (`8888`/`8889` and chat-incoming) are rendered via `showSystemNotification`, which bypasses `addNotification` and `history`. There are therefore **two disjoint notification stores**: the OS tray (push events) and the in-app list (empty). No code path records a push event into the list.

### A-7. FCM token cached in plaintext SharedPreferences (LOW)

`prefs.setString('fcm_token', token)` (`sync_fcm_handler.dart:141`) stores the device push token in plaintext (contrast: the Hive `notifications` box uses AES). Also, `token.substring(0, 16)` is logged at debug level (`sync_fcm_handler.dart:130`). Consider `FlutterSecureStorage` and trimming the log.

### A-8. `unreadCountNotifier` / `unreadCount` are maintained but unconsumed (LOW)

`NotificationService.unreadCountNotifier` and `unreadCount` (`notification_service.dart:53-54`) are updated by `_updateUnreadCount` on every mutation, but no widget reads them — the dashboard header recomputes the unread count inline (`dashboard_header.dart:150`). Redundant state; one source of truth should win.

### A-9. Background handler re-initializes the local-notifications plugin per message (LOW)

`_firebaseMessagingBackgroundHandler` calls `NotificationService().init()` on every `SESSION_PREPARING`/`BOARD_RECOVERED`/`SESSION_LATE_START` (`sync_fcm_handler.dart:45,62`), re-running `_notificationsPlugin.initialize` (and re-registering `onDidReceiveNotificationResponse`) inside a background isolate. Works today, but plugin init in background isolates is platform-sensitive; a single app-level init with a lightweight show path is more robust.

### A-10. `loadFromDisk` has no corruption guard (LOW)

`AppNotification.fromJson` calls `DateTime.parse` unguarded (`notification_service.dart:37`), and `loadFromDisk` (`notification_service.dart:94-104`) maps stored maps with no `try/catch`. A corrupt/legacy `history` entry in the Hive box throws during Track B startup.

### A-11. Notification permission has two requesters with no single owner (LOW)

Permission is requested from `_DashboardScreenState._initData` via `FirebaseMessaging.requestPermission` (`dashboard_screen.dart:55-65`) and independently driven by `SecurityController.autoRequestPermissions` → `PermissionService().requestAll` (`security_controller.dart:316-321`). Two paths, two permission models (`firebase_messaging` vs `permission_handler`), duplicated checks.

### A-12. Hard-coded local notification ids / channel (LOW)

`SESSION_PREPARING`/`BOARD_RECOVERED` share id **8888** and `SESSION_LATE_START` uses **8889** (`sync_fcm_handler.dart:47,64,118`) — consecutive, unrelated pushes overwrite each other in the tray; the chat flow instead uses a millisecond-epoch id. The Android channel `intelliattend_channel` ("Class Reminders") is hard-coded (`notification_service.dart:190-196`) and applies to chat notifications too.

### A-13. `NotificationService.init()`'s iOS permission flags are static (LOW)

`DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true)` (`notification_service.dart:64-68`) requests all three iOS permissions unconditionally at startup, even before any faculty consent UI; on iOS the `firebase_messaging` request at `dashboard_screen.dart:57` overlaps this. Duplicated prompt risk.

### A-14. Notification `id` is a client-side timestamp string (LOW)

`addNotification` generates `id` from `DateTime.now().millisecondsSinceEpoch.toString()` (`notification_service.dart:118`) — no server id, no dedup, no cross-device ordering. Two rapid notifications in the same millisecond collide; a server-provided id would future-proof read-state sync (A-1).

---

*End of Notifications Module technical documentation. Companion: `HOME_MODULE.md`, `COURSES_MODULE.md`, `MYCLASS_MODULE.md`, `PROFILE_MODULE.md`, `ANALYTICS_MODULE.md`.*
