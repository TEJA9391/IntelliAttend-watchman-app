# Messaging Module

> **Module path:** `lib/Presentation/Features/Messaging/` + `lib/Data/Repositories/Messaging/`, `lib/Data/Services/message_cache_service.dart`, `lib/Data/Models/Messaging/`, `lib/Services/websocket_service.dart`, `lib/Services/chat_realtime_service.dart`, `lib/Core/Models/websocket_event.dart`
>
> **Scope:** 1:1 faculty-student chat (list + screen), attachments, voice notes, calls, threads, search, forward, reactions, presence, typing indicators, offline cache + outbox, notification deep-linking (`chat:<conversationId>`).
> **Out of scope (cross-ref only):** `lib/Presentation/Features/QuickActions/Screens/Messaging/faculty_messaging_screen.dart` (QuickActions module, not part of this feature), the `MessageCategory` model at `lib/Data/Models/QuickActions/faculty_message.dart:10`, and the attendance WebSocket session flows.
> **Version documented:** v1.0.0+1 (source of truth is the code, not this doc).
> **Complexity:** High. ~10,300 LOC (PowerShell `Measure-Object -Line`) across presentation (7,531), data/services layer (1,648) and models (1,080).

## Table of Contents

- [1. Module Overview](#1-module-overview)
- [2. Layered Architecture](#2-layered-architecture)
- [3. File Inventory](#3-file-inventory)
- [4. State Management Wiring](#4-state-management-wiring)
- [5. REAL vs DEMO Data Paths](#5-real-vs-demo-data-paths)
- [6. Screen Deep Dives](#6-screen-deep-dives)
- [7. Widgets Catalog](#7-widgets-catalog)
- [8. Data Models & DTOs](#8-data-models--dtos)
- [9. Backend API Reference](#9-backend-api-reference)
- [10. WebSocket Real-Time Protocol](#10-websocket-real-time-protocol)
- [11. Offline-First & Local Cache](#11-offline-first--local-cache)
- [12. Attachment & Media Pipeline](#12-attachment--media-pipeline)
- [13. Voice Notes](#13-voice-notes)
- [14. Calls](#14-calls)
- [15. Navigation Map](#15-navigation-map)
- [16. Sequence Diagrams](#16-sequence-diagrams)
- [17. Error Handling](#17-error-handling)
- [18. Performance](#18-performance)
- [19. Security](#19-security)
- [20. Dependencies](#20-dependencies)
- [21. Cross-Module Integration](#21-cross-module-integration)
- [22. Testing & Coverage Gaps](#22-testing--coverage-gaps)
- [23. Appendix A: Known Technical Debt](#23-appendix-a-known-technical-debt)

---

## 1. Module Overview

The Messaging module implements a WhatsApp-style 1:1 chat between a faculty user and students. It is an **offline-first** feature:

- All HTTP calls go through the shared `ApiClient().dio` (`messaging_repository.dart:48`) with Firebase-token auth + device headers attached by the existing interceptors and TLS cert pinning (`PINNED_CERT_FINGERPRINTS`).
- A per-session backend health check (`GET /api/v1/messaging/health`, checked once per app run) decides whether real REST endpoints are used or the app falls back to the local encrypted Hive cache (`MessageCacheService`) seeded by `ChatDemoData` (5 hard-coded students).
- Real-time (incoming messages, receipts, typing, presence, call signalling) runs over a shared WebSocket bridged through `ChatRealtimeService` -> typed `ChatRealtimeEvent` streams.
- Every REST write is wrapped in `MessagingApiResponse<T>` (`messaging_repository.dart:13-31`) so controllers can distinguish a live response from a cached/offline one without throwing.

Key facts a reviewer must know up front:

1. **Calls are simulated, not real media.** `CallController._configurePlatform()` is a no-op (`call_controller.dart:113-117`), the outgoing "ringing" state is a hard-coded 900 ms delay (`call_controller.dart:105-109`), and `repository.initiateCall` is never invoked. There is no audio/video capture, no WebRTC, no media stream. The call screen is a state machine rendered over signalling frames. (See A-3.)
2. **There is no incoming-call UI.** `ChatRealtimeService.incomingCall` is written by `_handleCall` but nothing subscribes to it (`chat_realtime_service.dart:124-142`). (See A-2.)
3. **The offline outbox is write-only.** Messages queued while offline are persisted to Hive but nothing ever drains the queue: `loadOutbox`/`loadFailed`/`addFailed`/`retryMessage` have no callers outside `message_cache_service.dart`. (See A-1.)
4. **REST is primary, WS is fan-out.** Sends go REST-first then re-broadcast over the socket (`chat_screen_controller.dart:237-267`); incoming events are socket-first.

---

## 2. Layered Architecture

```
Presentation (Features/Messaging)                Data (Repositories/Messaging)
+-----------------------------+                  +--------------------------------+
| ChatListScreen  (637)       |                  | MessagingRepository   (566)    |
| ChatScreen     (1611)       |                  |  - REST via ApiClient().dio   |
| CallScreen      (289)       |                  |  - /api/v1/messaging/...      |
| Forward/Thread/Search/      |  ChangeNotifier  |  - MessagingApiResponse<T>    |
| Info/Profile screens        +---------------->+  - isBackendAvailable gate    |
| Widgets/ (10 files, 2371)   |                  +--------------------------------+
+-------------+---------------+                               |
              |                                     Core/Network
              |  ChatRealtimeService (239)           ApiClient (dio + auth +
              |  - typed ChatRealtimeEvent streams    cert pinning)
              |  - typingStatus / presence / incomingCall
              v
      Services/WebSocketService (267)
      - wss://<apiBase>/ws  (Firebase id-token query param)
      - heartbeat 30s, reconnect backoff 1s..30s
      - flat frames: {type, ...}

Models (Data/Models/Messaging, 1080)   Local cache (Data/Services)
  ChatMessage / ChatConversation        MessageCacheService (309)
  ChatAttachment / ChatCall              - Hive "messaging" box (encrypted)
  StudentContact / ReplyPreview          - messages, conversations, outbox,
  ChatDemoData (demo catalog)            - drafts, flags, call history, exports

Core/Models/websocket_event.dart (267) - WsEventType / WsConnectionState / WebSocketEvent
```

---

## 3. File Inventory

Line counts are `Measure-Object -Line` (non-blank lines).

| File | Lines | Role |
|------|------:|------|
| `lib/Presentation/Features/Messaging/chat_screen.dart` | 1611 | 1:1 chat screen (header, list, composer, theme, media tabs, selection) |
| `lib/Presentation/Features/Messaging/chat_screen_controller.dart` | 740 | Conversation state machine: pagination, send/upload/retry, receipts, mutations, search, realtime |
| `lib/Presentation/Features/Messaging/chat_list_screen.dart` | 637 | Conversation list, offline banner, search delegate, NewChatSheet |
| `lib/Presentation/Features/Messaging/chat_list_controller.dart` | 298 | Conversation list state, cache/demo hydration, realtime preview updates, local notifications |
| `lib/Presentation/Features/Messaging/call_screen.dart` | 289 | Call UI (incoming/outgoing controls, timer) |
| `lib/Presentation/Features/Messaging/call_controller.dart` | 219 | Call state machine (simulated, see Section 14) |
| `lib/Presentation/Features/Messaging/forward_screen.dart` | 320 | Forward to chats / students / departments / faculty |
| `lib/Presentation/Features/Messaging/message_search_screen.dart` | 256 | In-conversation search with All/Media/Documents/Links filters |
| `lib/Presentation/Features/Messaging/message_info_screen.dart` | 172 | Delivery/read/edit timestamps + status detail |
| `lib/Presentation/Features/Messaging/thread_screen.dart` | 159 | Reply thread view + inline composer |
| `lib/Presentation/Features/Messaging/view_profile_screen.dart` | 393 | Contact profile, call buttons, mute/block/report, wallpaper |
| `lib/Presentation/Features/Messaging/messaging_router.dart` | 66 | Notification deep-link -> ChatScreen |
| `lib/Presentation/Features/Messaging/Widgets/attachment_bubble.dart` | 658 | Renders any attachment type (image/video/voice/doc/location/contact) |
| `lib/Presentation/Features/Messaging/Widgets/message_bubble.dart` | 537 | Chat bubble: reply preview, markers, ticks, reactions |
| `lib/Presentation/Features/Messaging/Widgets/chat_input_bar.dart` | 351 | Composer: text, emoji picker, attach sheet, hold-to-record voice |
| `lib/Presentation/Features/Messaging/Widgets/message_action_sheet.dart` | 247 | Long-press action sheet + quick reactions |
| `lib/Presentation/Features/Messaging/Widgets/attachment_sheet.dart` | 245 | Camera/Gallery/Video/Document/PDF/Location picker |
| `lib/Presentation/Features/Messaging/Widgets/peer_avatar.dart` | 92 | Initials avatar with presence ring |
| `lib/Presentation/Features/Messaging/Widgets/typing_indicator.dart` | 74 | Animated 3-dot typing indicator + "is typing" label |
| `lib/Presentation/Features/Messaging/Widgets/chat_time_format.dart` | 69 | WhatsApp-style time/date/size formatting |
| `lib/Presentation/Features/Messaging/Widgets/chat_theme.dart` | 57 | Per-chat accent palette + `ChatThemeScope` InheritedWidget |
| `lib/Presentation/Features/Messaging/Widgets/message_status_ticks.dart` | 41 | Delivery ticks (sent/delivered/read/failed/pending) |
| `lib/Data/Repositories/Messaging/messaging_repository.dart` | 566 | All REST endpoints + health gate + demo fallback signalling |
| `lib/Data/Services/message_cache_service.dart` | 309 | Hive offline cache, outbox, drafts, flags, exports |
| `lib/Services/websocket_service.dart` | 267 | Shared WebSocket client (heartbeat, reconnect, chat helpers) |
| `lib/Services/chat_realtime_service.dart` | 239 | Realtime bridge: typed events, presence/typing/incomingCall state |
| `lib/Core/Models/websocket_event.dart` | 267 | `WsEventType`, `WsConnectionState`, `WebSocketEvent` |
| `lib/Data/Models/Messaging/chat_message.dart` | 251 | Message entity + optimistic factory + JSON |
| `lib/Data/Models/Messaging/chat_demo_data.dart` | 198 | 5 dummy students + seeded demo threads |
| `lib/Data/Models/Messaging/chat_enums.dart` | 167 | ContentType/Status/Direction/CallType/CallDirection/CallState/ForwardTargetType |
| `lib/Data/Models/Messaging/student_contact.dart` | 152 | Contact + `ReplyPreview` |
| `lib/Data/Models/Messaging/chat_conversation.dart` | 122 | Conversation entity + `updateFromMessage` |
| `lib/Data/Models/Messaging/chat_attachment.dart` | 114 | Attachment entity |
| `lib/Data/Models/Messaging/chat_call.dart` | 67 | Call record |
| `lib/Data/Models/Messaging/messaging_models.dart` | 9 | Barrel export |

---

## 4. State Management Wiring

The module uses **plain `ChangeNotifier` + `provider`** (no Riverpod/Bloc).

| Owner | ChangeNotifier | Injected by |
|-------|----------------|-------------|
| `ChatListScreen` | `ChatListController(repository: MessagingRepository())` | Created in `chat_list_screen.dart:30-36` (initState), exposed via `ChangeNotifierProvider.value` (`chat_list_screen.dart:58-59`), consumed with `context.watch`. |
| `ChatScreen` | `ChatScreenController(repository, conversation)` | Created in `chat_screen.dart:65-68` (initState); wrapped in `ChatThemeScope` + `ChangeNotifierProvider.value` (`chat_screen.dart:164-168`); child widgets read via `Consumer<ChatScreenController>`. |
| `CallScreen` | `CallController(repository, peer, type, direction)` | Created in `call_screen.dart:26-40` inside `ChangeNotifierProvider`; view uses `context.watch<CallController>`. |
| Shared app-wide | `ChatRealtimeService.instance` (singleton `ChangeNotifier`) | No DI - accessed statically; `MessageCacheService.instance` similarly singleton. |

Key pattern: controllers subscribe directly to `ChatRealtimeService.instance.events` in `_init()` and cancel in `dispose()`:

- `chat_screen_controller.dart:103-106` (per-conversation event stream)
- `chat_list_controller.dart:79-91` (list preview updates + socket bootstrap)

`ChatThemeScope` (`chat_theme.dart:42-67`) is an `InheritedWidget` that pushes the per-chat accent color and dark-mode flag down to bubbles/input/header.

---

## 5. REAL vs DEMO Data Paths

**The single most important thing to understand about this module.**

The repository performs **real HTTP calls** to the IntelliAttend backend through `ApiClient` for every method (`messaging_repository.dart:33-39`). There is no fake/simulated send, typing or call in the repository. The demo layer exists only as a *contact/thread catalog fallback*:

### Backend availability gate

```
MessagingRepository.isBackendAvailable   (messaging_repository.dart:56-67)
  -> GET /api/v1/messaging/health  (receiveTimeout: 6s)
  -> cached in _backendCheckDone / _backendAvailable for the app session
```

`_isUnavailable(e)` (`messaging_repository.dart:69-75`) classifies a failure as "endpoint not deployed" when it is a connection error, connection timeout, receive timeout, or HTTP 404/501. All other errors (e.g. 500, 401) are surfaced as real errors.

### Fallback chain (chat list)

`ChatListController.load()` (`chat_list_controller.dart:94-116`):

```
1. backend fetchConversations()  -> success? merge + persist to Hive cache
2. else hydrate from Hive cache  (MessageCacheService.loadConversations)
3. else first-run seed from ChatDemoData.seedConversations(facultyName, facultyId)
      - builds 5 demo conversations (ids demo_stu_001..demo_stu_005)
      - generates 1-3 days of history, 8-13 deterministic messages each
      - decorates with reply threads, a pinned message, stars and reactions
      - persists to cache (chat_list_controller.dart:144-181)
```

The chat screen does the same for messages (`chat_screen_controller.dart:110-148`): hydrate from cache for instant paint, fetch fresh, merge; if the conversation id starts with `demo_` and nothing is cached yet, `_seedDemoGreeting()` (`chat_screen_controller.dart:150-166`) inserts a canned greeting *from the peer*.

### Demo catalog

`ChatDemoData` (`chat_demo_data.dart:14-215`) hard-codes 5 students:

| id | name | roll | course |
|----|------|------|--------|
| stu_001 | Aarav Sharma | 21CS001 | CS501 Operating Systems |
| stu_002 | Priya Patel | 21CS002 | CS501 Operating Systems |
| stu_003 | Rohan Verma | 21CS003 | CS502 DBMS |
| stu_004 | Sneha Reddy | 21CS004 | CS502 DBMS |
| stu_005 | Karthik Nair | 21CS005 | CS503 Software Engineering |

Presence flags are static (some `is_online: true`, some with custom statuses). `byId()` matches by id or roll number (`chat_demo_data.dart:101-106`). These same students are merged with backend `fetchContacts()` results in the NewChatSheet (`chat_list_screen.dart:571-586`) and the Forward screen (`forward_screen.dart:68-83`).

### Consequence

With the backend unreachable the user still sees a fully populated chat list, but:
- conversations are `demo_*` / `direct_*` shells stored only on-device;
- messages are the seeded demo threads (offline) plus anything the user types (queued into the outbox, never delivered);
- realtime WS frames (if the socket still connects) will match no demo conversation peer.

---

## 6. Screen Deep Dives

### 6.1 ChatListScreen / ChatListController

- Entry: pushed by the Faculty dashboard quick action (`dashboard_sections.dart:137-139`).
- `ChatListController` (`chat_list_controller.dart`):
  - `conversations` getter filters by title / roll number / section and sorts pinned-first then by `lastMessageTime ?? createdAt` desc (`chat_list_controller.dart:41-60`).
  - `load()` -> backend -> cache -> demo (Section 5).
  - `_mergeFromBackend` preserves locally-known `unreadCount`, `isMuted`, `isBlocked` over server data (`chat_list_controller.dart:123-142`).
  - Incoming realtime `message_new` updates the preview, bumps `unreadCount` (skipped when muted), upserts the cache, and - if unmuted and not self - fires a system notification with payload `chat:<conversationId>` via `NotificationService.showSystemNotification` (`chat_list_controller.dart:282-334`).
- UI (`chat_list_screen.dart`): `RefreshIndicator` + `ListView.separated` of `_ConversationTile` (Dismissible swipe-to-delete with confirm dialog), offline amber banner with Retry, `_EmptyState`, `showSearch` delegate, long-press bottom sheet (pin/mute/archive/block/delete), `NewChatSheet` (contacts = demo + backend, new conversation id `direct_<contactId>`).

### 6.2 ChatScreen / ChatScreenController

`ChatScreen` (`chat_screen.dart`) is the largest screen. Header shows `PeerAvatar` with live presence, "is typing" subtitle, voice/video call buttons, and a 14-item overflow menu (View contact, Search, Mute, Theme, Wallpaper, Starred, Pinned, Media/links/docs, Sounds, Clear, Export, Block, Report, Delete). Per-chat prefs (muted, wallpaper, dark, accent, sounds, draft) are read from `MessageCacheService` at init (`chat_screen.dart:75-85`).

`ChatScreenController` (`chat_screen_controller.dart`):
- **Loading/pagination:** hydrate cache -> `fetchMessages()` -> `_mergeIncoming` dedups + sorts by timestamp; `_hasMore = fresh.length >= 25`; `loadOlder()` keys off `before:` cursor (`chat_screen_controller.dart:110-203`).
- **Send pipeline (optimistic):** `sendText` builds `ChatMessage.local(...)` (id `local_<micros>`, status `pending`), appends + persists, then `_sendViaBackend` (`chat_screen_controller.dart:207-267`):
  - backend OK: `repository.sendMessage`; on success replace with server message (status `delivered`) + `sendChatMessage` over WS; on failure -> outbox.
  - backend down: `cache.enqueueOutbox(message.copyWith(status: pending))`, mark pending, `_isOffline = true`.
- **Attachments:** `sendAttachment` (below, Section 12). `UploadTask` (`chat_screen_controller.dart:14-34`) wraps a `CancelToken` + progress/cancelled `ValueNotifier`s.
- **Receipts:** `_autoMarkRead` on load; `markRead` also sends WS `message_read` (`chat_screen_controller.dart:410-432`).
- **Typing:** `notifyTyping` sends `typing=true` immediately and schedules a 2 s debounce to send `typing=false` (`chat_screen_controller.dart:437-447`).
- **Mutations:** delete (for-me/for-everyone via cache undo buffer + backend when available, then WS `typing=false`), undoDelete, pin, star, single-reaction toggle, edit (text + `isEdited/editedAt`), forward, translate (backend-only, `en`), clear, export (text/json local; pdf/csv backend).
- **Selection mode:** `enterSelection/toggleSelect/exitSelection`; bulk copy/star/forward/delete with UNDO snackbar (`chat_screen.dart:765-863`).
- **Search:** `searchMessages` filters the local list instantly (media/documents/links predicates) then overrides with backend `searchMessages` when available (`chat_screen_controller.dart:643-685`).
- **Realtime:** `_onRealtimeEvent` handles `message_new` (dedup, skip own/outgoing, persist, auto-read + receipt), `receipt`, `edited`, `deleted`, `pinned` (`chat_screen_controller.dart:739-819`).
- **Voice notes:** `sendVoiceNote` wraps the recorded file into a `ChatAttachment` (type `voice`, mime `audio/m4a`) and reuses `sendAttachment` (`chat_screen_controller.dart:724-735`).

### 6.3 CallScreen / CallController

`CallController` (`call_controller.dart`) is a **simulated** state machine (Section 14). `CallScreen` renders a gradient backdrop with peer avatar, a status pill, incoming accept/decline controls or outgoing mute/speaker/camera/flip + end. `PopScope` blocks back-navigation during an active call and ends it instead (`call_screen.dart:54-61`). Duration timer starts on `connected`.

### 6.4 ForwardScreen

Forward to chats, individual students, whole departments (expanded to per-student `direct_*` conversations) or faculty (`forward_screen.dart:93-151`). Multi-select with search. `_send` upserts a conversation shell for each target then either `controller.forwardMessages` (backend fan-out when available) or `_forwardOffline` (local copy + outbox) per message (`forward_screen.dart:153-205`).

### 6.5 MessageSearchScreen

Search box + filter chips (All/Media/Documents/Links) with 250 ms debounce (`message_search_screen.dart:1-50`), highlight of the matched query span, and "tap a result returns `messageId`" so the chat can jump to it (`chat_screen.dart:382-388`).

### 6.6 MessageInfoScreen

Preview bubble + rows for Sent/Received/Delivered/Read/Edited/Forwarded/Pinned/Starred/Status, plus raw `message.id` and message age (`message_info_screen.dart:51-113`).

### 6.7 ThreadScreen

Root message + replies (`m.replyTo?.messageId == root.id && !m.isSystem`), reply count in the app bar, and a full `ChatInputBar` whose send always replies to the root (`thread_screen.dart:68-77`, `151-163`).

### 6.8 ViewProfileScreen

Contact card (avatar, presence), voice/video call buttons, roll/section/department/course/email/phone rows (copyable), phone dial + WhatsApp (`wa.me`) launchers, and a settings card for mute / wallpaper / block / report (`view_profile_screen.dart:167-210`).

### 6.9 MessagingRouter

Handles `chat:<conversationId>` notification payloads (`messaging_router.dart:18-29`). Buffers the id if the navigator is not ready and flushes via `MessagingRouter.flushPending()` (called from `main.dart:65`). Resolves the conversation from cache; if missing, reconstructs a shell from `ChatDemoData` or a `StudentContact(id: peerId, name: 'Student')` fallback and pushes `ChatScreen` (`messaging_router.dart:43-75`).

---

## 7. Widgets Catalog

| Widget | Purpose |
|--------|---------|
| `MessageBubble` (`message_bubble.dart`) | Bubble with reply preview, thread count, forwarded/pinned/starred markers, attachments, delivery ticks, "edited" tag, reactions below; system and deleted messages render as separate widgets. Link spans call `_openLink` which **copies the URL to the clipboard** (does not launch the browser) - see A-5. |
| `AttachmentBubble` (`attachment_bubble.dart`) | Per-type renderers: image (full-screen viewer), video (`video_player`), voice/audio (`audioplayers`, seekable pseudo-waveform), location (Google Maps deep link), contact card (tel: + "Save contact" label), documents (per-type icon, `OpenFilex.open`; long-press shares). Remote files are downloaded through the authenticated `ApiClient().dio` (`attachment_bubble.dart:91`). |
| `ChatInputBar` (`chat_input_bar.dart`) | Growing text field (max 6 lines), emoji picker, attach sheet, hold-to-record voice (AAC-LC m4a; recordings < 1 s discarded), reply chip, blocked state banner. |
| `AttachmentSheet` (`attachment_sheet.dart`) | Camera/Gallery/Video/Document(multi)/PDF/Location. Ext maps to `MessageContentType`; camera permission gated. |
| `MessageActionSheet` (`message_action_sheet.dart`) | Long-press sheet: quick reactions + Reply/Copy/Share/Save/Forward/Star/Pin/Info/Edit/Delete/Translate/Select. |
| `MessageStatusTicks` | failed/pending = clock icon, sending/sent = single tick, delivered = double gray, read = double blue. |
| `PeerAvatar` | Deterministic pastel color from name hash; online ring; `OnlineDot`. |
| `TypingIndicator` | Animated 3-dot; `TypingLabel` caption. |
| `ChatThemeScope` / `ChatAccents` | 12-color per-chat accent palette + dark flag via InheritedWidget. |
| `ChatTimeFormat` | Time/day/date/last-seen/duration/file-size formatting. |

---

## 8. Data Models & DTOs

All JSON uses snake_case keys. Sources: `lib/Data/Models/Messaging/*`.

- **ChatMessage** (`chat_message.dart`): `id`, `localId` (defaults to `local_<micros>_<id>`), `conversationId`, `direction`, `type` (`MessageContentType`), `text`, `attachments`, `senderId/Name`, `timestamp`, `deliveredAt`, `readAt`, `editedAt`, mutable `status`, `isEdited/isForwarded/isPinned/isStarred/isDeletedForMe/isDeletedForEveryone`, `replyTo` (`ReplyPreview?`), `threadCount`, `reactions` (List<String>). Transient `uploadProgress/isUploading/isSelected` are **excluded from toJson**. `ChatMessage.local()` is the optimistic factory (`id = local_<micros>`, status `pending`). Helpers: `contentSummary`, `hasAttachment`, `isDeleted`, `isSystem`.
- **ChatConversation** (`chat_conversation.dart`): `id`, `peer` (`StudentContact`), `lastMessage`, `lastMessageStatus`, `lastMessageTime`, `unreadCount`, `isMuted/isBlocked/isPinned/isArchived/isGroup`, `groupName`, `draft`, `createdAt`. Helpers: `title`, `updateFromMessage(message)`, `resetUnread()`.
- **ChatAttachment** (`chat_attachment.dart`): `id`, `name`, `type`, `sizeBytes`, `mimeType`, `localPath`, `remoteUrl`, `thumbnailUrl`, `durationMs`, `width`, `height`, `emojiShortcode`, `latitude/longitude`, `contactName/contactPhone`.
- **ChatCall** (`chat_call.dart`): `id`, `peer`, `type`, `direction`, `state`, `startedAt`, `endedAt`, `durationSeconds`. Client ids: `call_<millis>`.
- **StudentContact** (`student_contact.dart`): `id` (from `id` or `user_id`), `name`, `rollNumber`, `email`, `phone`, `department`, `section`, `courseCode`, `courseName`, `avatarUrl`, `initials`, `isOnline`, `lastSeen`, `customStatus`, `isFaculty`. Helpers: `initialsValue`, `displayTitle`. **ReplyPreview** also lives here.
- **Enums** (`chat_enums.dart`): `MessageContentType` (text/image/document/pdf/word/excel/powerpoint/audio/voice/video/gif/emoji/location/contact/system; `isFile` covers the five office/doc types), `MessageStatus` (pending/sending/sent/delivered/read/failed), `MessageDirection`, `CallType`, `CallDirection`, `CallState` (calling/ringing/incoming/connecting/connected/ended/missed/rejected/busy/failed), `ForwardTargetType`.
- **ChatDemoData** (`chat_demo_data.dart`): static catalog + `seedConversations`. See Section 5.
- **ChatRealtimeService.PresenceSnapshot** (`chat_realtime_service.dart:214-221`): `isOnline`, `lastSeen`, `customStatus`.
- **ChatRealtimeEvent** (`chat_realtime_service.dart:223-281`): typed event with `kind` (`message_new | ack | receipt | typing | presence | call | sync | edited | deleted | pinned`), `data`, `conversationId`, `senderId`, `presence`, `isTyping`.
- **Core `WebSocketEvent`** (`websocket_event.dart`): `WsConnectionState` (disconnected/connecting/connected/reconnecting), `WsEventType` (attendance + chat types incl. `messageNew/messageAck/messageRead/messageDelivered/messageEdited/messageDeleted/messagePinned/typing/presenceUpdate/callEvent/conversationSync`), `WebSocketEvent.fromJson` reads `type` or `event` key.

> Note: `MessageCategory` (assignment templates) is **not** part of this module - it lives in `lib/Data/Models/QuickActions/faculty_message.dart:10` (QuickActions module). See Section 21.

---

## 9. Backend API Reference

Base URL: `ApiClient().baseUrl` = `customBaseUrl ?? dotenv.env['API_BASE_URL'] ?? 'https://api-dev.balaseetharamanjaneyulu.com'` (`api_client.dart:19,33`). The repo `.env` sets `API_BASE_URL=https://api.intelliattend.app`, so at runtime the base is the production-ish host. All endpoints below are relative to that base and go through the authenticated, cert-pinned Dio instance.

| Method | Endpoint | Purpose | Used by |
|--------|----------|---------|---------|
| GET | `/api/v1/messaging/health` | Backend availability gate (6 s receive timeout, cached per session) | `isBackendAvailable` (`messaging_repository.dart:56-67`) |
| GET | `/api/v1/messaging/conversations?query&cursor&limit` | Conversation list (search + cursor pagination, limit default 30) | `fetchConversations` (`messaging_repository.dart:96-127`) |
| GET | `/api/v1/messaging/conversations/{id}` | Single conversation (notification deep-link) | `fetchConversation` (`messaging_repository.dart:130-143`) |
| POST | `/api/v1/messaging/conversations` | Open/create conversation with a peer | `openConversationWith` - **dead, never called** (A-4) |
| GET | `/api/v1/messaging/conversations/{id}/messages?before&limit&filter` | Paged messages (`before` = ISO timestamp, limit default 25) | `fetchMessages` |
| POST | `/api/v1/messaging/conversations/{id}/messages` | Send text/emoji message (server echoes persisted message) | `sendMessage` |
| POST | `/api/v1/messaging/conversations/{id}/messages/upload` | Multipart attachment upload, 10 min timeouts, `onSendProgress`, `CancelToken` | `uploadAttachment` |
| POST | `/api/v1/messaging/conversations/{id}/read` | Mark conversation read (read receipts) | `markConversationRead` |
| PATCH | `/api/v1/messaging/conversations/{id}/messages/{mid}` | Edit message (`action: edit`) | `editMessage` |
| DELETE | `/api/v1/messaging/conversations/{id}/messages/{mid}` | Delete message (`for_everyone`) | `deleteMessage` |
| POST | `/api/v1/messaging/conversations/{id}/messages/{mid}/pin` | Pin/unpin (`pin`) | `pinMessage` |
| POST | `/api/v1/messaging/conversations/{id}/messages/{mid}/star` | Star/unstar (`star`) | `starMessage` |
| POST | `/api/v1/messaging/conversations/{id}/messages/{mid}/reactions` | Toggle emoji reaction (`emoji`) | `reactMessage` |
| POST | `/api/v1/messaging/conversations/{id}/messages/{mid}/forward` | Forward to `target_conversation_ids` | `forwardMessage` |
| POST | `/api/v1/messaging/conversations/{id}/messages/{mid}/translate` | Backend LLM translation (`target_language`, returns `translated_text`) | `translateMessage` |
| GET | `/api/v1/messaging/conversations/{id}/search?query&filter` | Server-side search (`results`) | `searchMessages` |
| GET | `/api/v1/messaging/conversations/{id}/media?kind` | Media/documents/links gallery (`items`) | `fetchMedia` |
| POST | `/api/v1/messaging/conversations/{id}/mute` | Mute toggle (`muted`) | `setMuted` |
| POST | `/api/v1/messaging/conversations/{id}/block` | Block toggle (`blocked`) | `setBlocked` |
| DELETE | `/api/v1/messaging/conversations/{id}/messages` | Clear conversation | `clearConversation` |
| DELETE | `/api/v1/messaging/conversations/{id}` | Delete conversation | `deleteConversation` |
| POST | `/api/v1/messaging/conversations/{id}/report` | Report (`reason`) | `reportConversation` |
| POST | `/api/v1/messaging/conversations/{id}/export` | Export PDF/CSV, returns signed `url` | `exportConversation` |
| GET | `/api/v1/messaging/contacts?query` | Contacts roster (`contacts`) | `fetchContacts` (NewChatSheet + Forward) |
| POST | `/api/v1/messaging/calls` | Initiate call (`peer_id`, `type`, `direction`) | `initiateCall` - **dead, never called** (A-4) |
| POST | `/api/v1/messaging/calls/{callId}/end` | End call (`duration_seconds`) | `endCall` (only call endpoint actually used) |
| GET | `/api/v1/messaging/calls?peer_id` | Call history (`calls`) | `fetchCallHistory` - **dead, never called** (A-4) |
| GET | `/api/v1/messaging/presence/{peerId}` | Presence lookup | `fetchPresence` - **dead, never called** (A-4) |

Response shape convention: list endpoints accept either a raw array or a map with a keyed list (`conversations` / `messages` / `results` / `items` / `contacts` / `calls`); single-object endpoints accept either the object directly or a wrapped key (`message` / `attachment` / `call` / `contact`).

---

## 10. WebSocket Real-Time Protocol

Transport: `dart:io` `WebSocket.connect` (no socket.io). Shared singleton `WebSocketService` (`websocket_service.dart`).

### Connection lifecycle

- **Messaging-only socket:** `ChatRealtimeService.connect()` (`chat_realtime_service.dart:57-60`) -> `WebSocketService.connectMessaging(facultyEmail)` (`websocket_service.dart:281-290`) with `sessionId = null`, then sends `presence_update online=true`.
- **Attendance socket:** `connectAndJoinRoom(sessionId, facultyEmail)` is used by the attendance module (out of scope here).
- **URL:** `wss://<ApiClient().baseUrl-host>/ws` + `?session_id=...&token=<firebase id-token>&token_type=firebase` (`websocket_service.dart:118-138`). The token is fetched from `FirebaseAuth.instance.currentUser.getIdToken()`.
- **Heartbeat:** JSON `{"type":"ping"}` every 30 s (`websocket_service.dart:172-179`); inbound `pong` text or heartbeat/pong events are ignored.
- **Reconnect:** on error/close, state -> disconnected, then exponential backoff `1s -> 2s -> ... cap 30s` (`websocket_service.dart:156-170`). `_isClosed` (set by `disconnect()`) stops reconnects.

### Frame format

Frames are **flat JSON maps** discriminated by a `type` key (no nested `payload` envelope):

```json
{ "type": "chat_message",
  "conversation_id": "...", "message_id": "...", "local_id": "...",
  "text": "...", "message_type": "text", "attachments": [],
  "reply_to_message_id": null, "sender_id": "faculty@..." }
```

### Outbound helpers (`websocket_service.dart:203-290`)

| Helper | Frame type | Notes |
|--------|-----------|-------|
| `sendChatMessage` | `chat_message` | Also used after REST send/upload succeeds (`chat_screen_controller.dart:251-257,325-331`) |
| `sendTyping` | `typing` | `is_typing` flag |
| `sendReadReceipt` | `message_read` | `message_ids` + `reader_id` |
| `sendPresence` | `presence_update` | `is_online` |
| `sendCallSignal` | `call_event` | `call_id` + `action` + optional `payload` |

`sendJson` silently drops frames when the socket is not open; the comment at `websocket_service.dart:205-206` defers retry to the REST outbox (which, per A-1, never happens automatically).

### Inbound mapping (`chat_realtime_service.dart:62-142`)

| WsEventType | ChatRealtimeEvent.kind | Handler |
|-------------|----------------------|---------|
| messageNew | `message_new` | controller appends message, persists, auto-reads |
| messageAck | `ack` | (listener no-op / notify) |
| messageRead / messageDelivered | `receipt` | update last-message status / message status to read/delivered |
| messageEdited | `edited` | replace text + editedAt |
| messageDeleted | `deleted` | deleted-for-me/everyone flags |
| messagePinned | `pinned` | notify |
| typing | `typing` | `typingStatus` ValueNotifier map |
| presenceUpdate | `presence` | `presence` ValueNotifier map |
| callEvent | `call` | `_handleCall` -> sets `incomingCall` (no UI listens - A-2) |
| conversationSync | `sync` | notify |

Presence/typing state is pushed to the UI via `ValueNotifier`s; controllers additionally listen to the typed event stream. Note: `_handlePresence` defaults `lastSeen` to `DateTime.now()` when the frame omits it (`chat_realtime_service.dart:110-116`), so an offline peer with no `last_seen` appears as "last seen just now" (A-9).

---

## 11. Offline-First & Local Cache

`MessageCacheService` (`message_cache_service.dart`) is a singleton backed by the encrypted Hive `messaging` box (`PersistenceService.messagingBox`).

### Hive keys

| Key | Contents |
|-----|----------|
| `conversations` | `List<ChatConversation>` JSON |
| `messages_<convId>` | `List<ChatMessage>` (deduped + sorted by timestamp) |
| `outbox` | queued `ChatMessage`s awaiting delivery (status pending) |
| `failed_messages` | failed queue (status failed) |
| `undo_<convId>` | last delete batch (restore via `undoDelete`) |
| `draft_<convId>` | saved draft text |
| `calls_<peerId>` | call history, newest first |
| `muted_<convId>` / `blocked_<convId>` | flags |
| `pinned_conversations` / `archived_conversations` | id lists |
| `wallpaper_<convId>` | ARGB int (0x00000000 = reset) |
| `accent_<convId>` | palette index |
| `dark_chat_<convId>` | per-chat dark flag |
| `chat_sounds_enabled` | global sound toggle |

### Exports

`exportAsText(convId, title)` and `exportAsJson(convId)` re-encode cached messages; used by `exportChat` for `text`/`json` formats, with PDF/CSV delegated to the backend endpoint (`chat_screen_controller.dart:602-614`). `loadStarred()` scans all conversations.

### Gap

The class docstring claims chat "syncs when connectivity returns" (`message_cache_service.dart:9-13`), but no connectivity listener, timer or worker drains `outbox` / `failed_messages`. See A-1.

---

## 12. Attachment & Media Pipeline

```
AttachmentSheet / ChatInputBar            ChatScreenController.sendAttachment
  - image_picker / file_picker            - optimistic ChatMessage.local + append
  - ChatAttachment (localPath only)       - UploadTask (CancelToken + progress)
                                           - repository.uploadAttachment
                                             (POST .../messages/upload, 10min, onSendProgress)
                                           - success: replace attachment w/ server remoteUrl,
                                             status sent, remove from outbox,
                                             sendChatMessage over WS
                                           - cancel: status pending; failure: status failed
                                             + enqueueOutbox (unless cancelled)
```

- Rendering: `AttachmentBubble` (`attachment_bubble.dart`) branches by `MessageContentType`. Images via `Image.file`/`CachedNetworkImage` + full-screen `InteractiveViewer` viewer; video via `video_player` in `_FullScreenMedia`; voice/audio via `audioplayers` with a seekable pseudo-waveform (voice) or progress bar (audio); location opens `https://www.google.com/maps/search/?api=1&query=lat,lng`; contact card shows name/phone with `tel:` call + "Save contact" chip; documents open with `OpenFilex.open`, sharing on failure or long-press.
- **Download path:** remote files are downloaded through `ApiClient().dio.download(remote, file.path)` - the *authenticated, cert-pinned* client - at `attachment_bubble.dart:91` and `chat_screen.dart:1550` (media tab). Never a bare `http` GET.
- Open/save from action sheet: `_saveAttachment` in `chat_screen.dart:1280-1285` is a stub (snackbar only) - A-10.

---

## 13. Voice Notes

`ChatInputBar` (`chat_input_bar.dart`) uses the `record` package:
- Hold-to-record on the mic; permission via `permission_handler`; recordings written to app documents as `voice_<millis>.m4a` with `RecordConfig(encoder: AudioEncoder.aacLc)` (`chat_input_bar.dart:68-99`).
- A 100 ms timer drives the "Recording mm:ss" banner; release to send (tap to discard); recordings shorter than 1 s are discarded (`chat_input_bar.dart:101-117`).
- `sendVoiceNote` (`chat_screen_controller.dart:724-735`) turns the file into a `ChatAttachment(type: voice, mimeType: audio/m4a)` and reuses the upload pipeline.

---

## 14. Calls

`CallController` (`call_controller.dart`) drives `CallScreen`. States: outgoing `calling -> ringing -> connected -> ended`; incoming `incoming -> connected/rejected`. Terminal states include `missed`, `busy`, `failed` (`isEnded`).

```
CallController._init
  - _configurePlatform()   -> NO-OP (no audio/video capture)
  - outgoing: _signal('call_request')
    + Future.delayed(900ms) -> ringing      (SIMULATED ring, call_controller.dart:105-109)
  - _persistRecord()       -> cache.addCall (local Hive only)
```

- Signalling: `_signal` sends `call_event` frames to **two** synthetic conversation ids - `direct_<peerId>` and `call_<callId>` (`call_controller.dart:121-134`).
- Buttons: mute/camera signal over WS; speaker and camera-flip are local-only toggles; `endCall` signals `call_end`, persists the record and calls `repository.endCall(callId, durationSeconds)` (`call_controller.dart:189-204`).
- `repository.initiateCall` is never called (A-4), so no server-side call record is ever created; call history is local-only and `fetchCallHistory` is dead.

**Honest summary:** the call feature is a fully-simulated UI over the signalling socket. No real media is exchanged. Incoming calls are also never surfaced to any screen (A-2).

---

## 15. Navigation Map

```
Faculty dashboard (QuickActions)          dashboard_sections.dart:137-139
      |
      v
ChatListScreen  <---- showSearch (delegate) / NewChatSheet
      |
      +-- open conversation ----------> ChatScreen
      |                                 |  - ViewProfileScreen
      |                                 |  - MessageSearchScreen
      |                                 |  - MessageInfoScreen
      |                                 |  - ThreadScreen
      |                                 |  - ForwardScreen (single/multi)
      |                                 |  - CallScreen (audio/video, outgoing)
      |                                 |  - Starred / Pinned / Media tabs (inline)
      +-- ForwardScreen
      +-- CallScreen

Push notification tap (payload 'chat:<conversationId>')
      |  main.dart:120 NotificationService.onPayloadTap = MessagingRouter.openChatFromPayload
      v
MessagingRouter.openChatFromPayload -> flushPending (main.dart:65)
      -> resolve conversation (cache / ChatDemoData shell / StudentContact fallback)
      -> push ChatScreen
```

New conversations created from `NewChatSheet` / Forward use local shell ids `direct_<contactId>` (`chat_list_screen.dart:592-597`, `forward_screen.dart:174-177`); demo threads use `demo_<studentId>`.

---

## 16. Sequence Diagrams

### 16.1 Send a text message (backend available)

```
User -> ChatScreen.sendText
  -> ChatScreenController.sendText
      1. ChatMessage.local(...) optimistic, status pending
      2. append + persist (cache.saveMessages + upsertConversation)
      3. _sendViaBackend
         a. repository.sendMessage (POST .../messages)
         b. success -> replace local w/ server msg (delivered) + outbox cleanup
         c. ChatRealtimeService.sendChatMessage (WS 'chat_message')
         d. failure -> cache.enqueueOutbox(pending), _isOffline = true
```

### 16.2 Incoming realtime message

```
Server -> WS 'message_new'
  -> WebSocketService._onMessage -> WebSocketEvent.fromJson
  -> ChatRealtimeService._onEvent -> ChatRealtimeEvent('message_new')
  -> ChatScreenController._onIncomingMessage
      1. dedup by message_id; skip outgoing/self
      2. ChatMessage.fromJson(data); add + persist + upsertConversation
      3. onIncomingMessage callback (haptic + SystemSound.click)
      4. _markRead + sendReadReceipt (WS 'message_read')
  -> (list active) ChatListController._handleIncomingMessage
      1. update preview + unreadCount (skip when muted)
      2. if unmuted & not self: NotificationService.showSystemNotification
         payload 'chat:<conversationId>'
```

### 16.3 Deep-link from notification

```
tap -> NotificationService.onPayloadTap(payload 'chat:xyz')
  -> MessagingRouter.openChatFromPayload
     - navigator null? buffer as _pendingConversationId
     - else _openConversation:
        1. cache.loadConversations() lookup id==xyz
        2. miss -> shell: ChatDemoData.byId(peerId) ?? StudentContact(name:'Student')
        3. cache.upsertConversation(shell)
        4. navigator.push(ChatScreen(shell))
  -> app boot postFrame -> MessagingRouter.flushPending() (main.dart:65)
```

### 16.4 Offline send

```
User sends while backend down / socket closed
  -> _sendViaBackend -> repository fails or _isBackendAvailable false
  -> cache.enqueueOutbox(status=pending)
  -> message stays pending in UI (clock icon)
  -> NO automatic retry (A-1); manual retryMessage is defined but unused
```

---

## 17. Error Handling

- **REST:** every repository method returns `MessagingApiResponse<T>` (`success`/`failure`, `fromCache`, `data`, `error`). `_extractError` (`messaging_repository.dart:77-89`) reads `detail` / `message` / `error` keys, special-cases 401 ("Session expired...") and connection errors ("You are offline..."). `_isUnavailable` (404/501/connection/timeout) maps to the message "Messaging endpoints unavailable on backend", which flips the offline path.
- **UI offline signalling:** amber banner with Retry on the chat list when `!isBackendAvailable` (`chat_list_screen.dart:102-103,144-184`); `ChatScreenController.isOffline`; optimistic bubbles show a clock (pending) or red `failed`.
- **Snackbars** for copy/forward/report/translate/export; confirmation dialogs for delete/clear/block/report; UNDO snackbar for deletions (`chat_screen.dart:854-863,1270-1278`).
- **WS errors:** dropped silently by `sendJson` when closed; reconnect handled by the service with exponential backoff. There is no user-visible "reconnecting" banner in the chat UI.
- **Upload:** `CancelToken.isCancel(e)` distinguishes user-cancel (`status pending`) from real failures (`status failed` + outbox) (`chat_screen_controller.dart:333-344`).

---

## 18. Performance

- **Pagination:** messages load in pages of 25 (server), older pages via `before:` cursor; `_hasMore = fresh.length >= 25`. List rendered as a `ListView.builder` (reverse) of pre-grouped rows with date separators (`chat_screen.dart:921-957`).
- **Merging:** `_mergeIncoming` and `cache.mergeMessages` dedup by message id into a map then sort once.
- **Cache-first paint:** chat hydrates from Hive before hitting the network (`chat_screen_controller.dart:118-127`).
- **Offline-first search:** local list filtered instantly, backend override applied after (`chat_screen_controller.dart:655-682`).
- **Animations are bounded:** per-message `_MessageAppear` (220 ms fade/slide) and `_MessageHighlight` (1100 ms pulse) are small controllers; `TweenAnimationBuilder` for reaction chips.
- **Known hotspots:** `_hydrateFromCacheOrDemo` re-seeds + persists on every offline first-run; `conversations` getter re-sorts the full list on every build; forward-to-department expands to N shell conversations and N outbox writes (A-12); `ChatListController` has no pagination despite `_hasMore` (A-13).

---

## 19. Security

- All HTTP (REST + `dio.download` for attachments) flows through `ApiClient` with Retry/Auth/Security interceptors and cert fingerprint pinning (`PINNED_CERT_FINGERPRINTS`). Upload/download of attachments therefore cannot bypass auth/pinning from inside the app.
- WebSocket URL carries the Firebase **id-token** as a query param (`websocket_service.dart:118-138`) - this is the primary WS credential; frame payloads do not add per-frame signing.
- `MessageCacheService` uses the encrypted Hive `messaging` box (content at rest).
- Blocked conversations: `ChatInputBar` renders a "You can't send messages to this chat" banner (`chat_input_bar.dart:145-159`); blocked flag persisted + mirrored to backend.
- **Caveats:** `sendJson` adds no per-frame auth; the demo fallback exposes fake student PII (names/rolls/phones) only when the backend is unreachable; forward/export operate on locally-cached content which may lag the server.

---

## 20. Dependencies

Confirmed in `pubspec.yaml` (versions as listed):

| Package | Used for |
|---------|----------|
| `dio` ^5.3.3 | REST + attachment upload/download |
| `provider` ^6.0.5 | ChangeNotifier wiring |
| `hive_flutter` ^1.1.0 | `MessageCacheService` Hive box |
| `google_fonts` ^6.1.0 | UI typography |
| `intl` ^0.19.0 | `ChatTimeFormat` formatting |
| `cached_network_image` ^3.3.0 | Remote image thumbnails |
| `file_picker` ^10.3.10 | Document/PDF picking |
| `image_picker` ^1.0.7 | Camera/gallery images + video |
| `permission_handler` ^11.3.1 | Mic/camera permission gates |
| `url_launcher` ^6.3.0 | tel:/wa.me/maps/external links |
| `path_provider` ^2.1.3 | temp/app-documents dirs for downloads + recordings |
| `share_plus` ^12.0.2 | Share sheet for text/files |
| `open_filex` ^4.7.0 | Open downloaded documents |
| `record` ^7.0.0 | Voice note recording (AAC-LC) |
| `emoji_picker_flutter` ^4.3.0 | Emoji picker in composer |
| `audioplayers` ^6.0.0 | Voice/audio playback |
| `video_player` ^2.9.0 | Video playback in full-screen viewer |
| `flutter_local_notifications` ^17.1.2 | Incoming-message system notifications (via NotificationService) |
| `firebase_auth` ^5.1.1 | WS id-token |
| `firebase_messaging` ^15.0.0 | FCM (payload taps wired in main.dart:120) |

---

## 21. Cross-Module Integration

- **App boot (`main.dart`):** `MessagingRouter.flushPending()` post-first-frame (`main.dart:63-65`); `NotificationService.onPayloadTap = MessagingRouter.openChatFromPayload` after notification init (`main.dart:119-120`); `import .../messaging/messaging_router.dart` (`main.dart:30`).
- **Dashboard:** Quick Actions "Chat" pushes `ChatListScreen` (`dashboard_sections.dart:137-139`).
- **Notifications module:** system notifications for incoming chats carry `chat:<id>` payloads; the Notifications deep-link diagram is documented there. Messaging does not read the in-app notification list.
- **Faculty identity:** `FacultyService.canonicalId` / `profile.value?.name` drive sender id/name and WS `sender_id`.
- **MyClass:** `student_profile_screen.dart:487` upserts a conversation into the messaging cache (reuses the Hive box).
- **Correction vs QuickActions:** the task brief assumed `MessageCategory.assignment` templates live in `messaging_repository.dart`; grep shows `MessageCategory` is defined only in `lib/Data/Models/QuickActions/faculty_message.dart:10` (QuickActions module) and is not referenced by the Messaging module. Document accordingly.

---

## 22. Testing & Coverage Gaps

- No widget/unit tests exist for the Messaging module (no `test/` files referencing these classes were found).
- `CallController._configurePlatform` is deliberately a no-op so the controller "can be tested headlessly" (`call_controller.dart:113-117`), but no tests exist.
- High-risk untested paths: outbox sync (A-1), incoming call surfacing (A-2), WS reconnect recovery, upload cancel/retry, demo-seed state transitions, `_onReceipt` status transitions.

---

## 23. Appendix A: Known Technical Debt

| ID | Title | Severity |
|----|-------|----------|
| A-1 | **Outbox/failed queue is never drained.** `loadOutbox`, `loadFailed`, `addFailed`, `retryMessage` have no callers outside `message_cache_service.dart`; no connectivity listener or worker syncs queued messages, despite the "syncs when connectivity returns" contract (`message_cache_service.dart:9-13`). Offline sends stay `pending` forever. | High |
| A-2 | **No incoming-call UI.** `ChatRealtimeService.incomingCall` is set by `_handleCall` (`chat_realtime_service.dart:124-142`) but nothing subscribes; `ChatListController` ignores `call` events (`chat_list_controller.dart:269-270`); `dismissIncomingCall` is never called. Incoming `call_event` frames are effectively dropped. | High |
| A-3 | **Calls are simulated, not real media.** `_configurePlatform()` no-op, 900 ms fake ring (`call_controller.dart:105-117`), no WebRTC/audio capture; the CallScreen is a decorative state machine. | High |
| A-4 | **Dead backend endpoints.** `repository.initiateCall`, `openConversationWith`, `fetchPresence`, `fetchCallHistory` are never invoked; new chats only create local `direct_*` shells, so server-side conversation/call records are never created and presence relies solely on WS. | Medium |
| A-5 | **Tapping a URL in a message copies it to the clipboard** instead of opening it (`message_bubble.dart:317-321` `_openLink` only calls `Clipboard.setData`). | Medium |
| A-6 | **Realtime socket bootstraps only from `ChatListController`** (`chat_list_controller.dart:86-91`). Opening `ChatScreen` directly via a `chat:` deep-link without ever opening the list leaves the socket unconnected (no realtime receive/typing/presence for that screen). | Medium |
| A-7 | **Stale docstring / missing type.** `messaging_repository.dart` comment mentions `ChatNotAvailable` which does not exist; `MessageActions.open` is defined but never produced; `_saveAttachment` (`chat_screen.dart:1280-1285`) is a snackbar-only stub. | Low |
| A-8 | **`MessageStatusTicks` maps both `failed` and `pending` to the same clock icon** (`message_status_ticks.dart:26-29`) and nothing offers a retry affordance on a failed bubble (retryMessage unused). | Low |
| A-9 | **Presence `lastSeen` defaults to `now`** when the frame omits it (`chat_realtime_service.dart:110-116`), making offline peers without `last_seen` look recently seen. | Low |
| A-10 | **Forward-to-department expands into N `direct_*` shells + N outbox writes** (`forward_screen.dart:145-186`); no server-side fan-out; can explode storage for large classes. | Medium |
| A-11 | **`endCall` sends an unrelated `typing=false`** to the synthetic conversation `call_<id>` (`call_controller.dart:203`). | Low |
| A-12 | **Conversation list has no pagination** despite `_hasMore` (`chat_list_controller.dart:106`); `conversations` getter re-sorts on every build. | Low |
| A-13 | **Demo seeding bypasses real data by design**, but `NewChatSheet`/Forward merge the 5 hard-coded students with the backend roster (`chat_list_screen.dart:571-586`, `forward_screen.dart:68-83`), so fake contacts may appear in production if the roster fetch fails silently. | Low |
| A-14 | **`MessagingRouter` fallback fabricates `StudentContact(id, name: 'Student')`** shells (`messaging_router.dart:62-63`) with no peer verification, and `double-tap` reaction hard-codes the emoji (`chat_screen.dart:1052`). | Low |
