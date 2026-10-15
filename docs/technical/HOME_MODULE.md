# IntelliAttend Faculty — Home Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Home (Dashboard)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`, `docs/technical/PROJECT_STRUCTURE.md`, `docs/PROJECT_DOCUMENTATION.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [Provider & State Management Wiring](#3-provider--state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [App Shell — `DashboardScreen`](#5-app-shell--dashboardscreen)
6. [Home Header — `DashboardHeader`](#6-home-header--dashboardheader)
7. [Session Control Section](#7-session-control-section)
8. [Today's Schedule Section](#8-todays-schedule-section)
9. [Navigation Drawer & Quick Actions](#9-navigation-drawer--quick-actions)
10. [The Timetable Engine](#10-the-timetable-engine)
11. [DashboardController — Business Logic](#11-dashboardcontroller--business-logic)
12. [Repositories](#12-repositories)
13. [Services](#13-services)
14. [Data Models & DTOs](#14-data-models--dtos)
15. [Backend API Reference](#15-backend-api-reference)
16. [WebSocket Real-Time Protocol](#16-websocket-real-time-protocol)
17. [Navigation Map](#17-navigation-map)
18. [Sequence Diagrams](#18-sequence-diagrams)
19. [Error Handling & Edge Cases](#19-error-handling--edge-cases)
20. [Performance Engineering](#20-performance-engineering)
21. [Security](#21-security)
22. [Dependencies Used](#22-dependencies-used)
23. [File Inventory](#23-file-inventory)

---

## 1. Module Overview

### 1.1 Purpose

The **Home Module** is the primary landing surface of the IntelliAttend Faculty application. It is the daily command center for a faculty member: it displays the live timetable position, surfaces the current/next class with a one-touch session starter, streams real-time attendance counts over WebSocket, and provides the entry points into Courses, My Class, Profile, and the global navigation drawer.

### 1.2 Business Goal

- Reduce the time between a faculty member entering a classroom and attendance being open to **< 10 seconds** (single swipe gesture).
- Provide **live, tamper-proof session state** (Preparing → Igniting → Active → Closed) that survives app kills, network loss, and device reboots.
- Give the faculty member **instant, cache-first cold start** (dashboard renders from local cache in ~100 ms while the network syncs in the background).

### 1.3 Problem Statement

Traditional attendance is recorded on paper or via manual rosters, creating:
- Time friction (roster roll-call takes minutes per class).
- Verification gaps (proxy attendance, unverifiable check-ins).
- No live visibility for faculty into who is present as students scan.
- Vulnerability to device wall-clock manipulation (student/faculty changing phone time).

### 1.4 Solution

- A **server-anchored virtual clock** (`TimeSyncService`) that removes OS wall-clock trust.
- A **zero-trust session lifecycle** where each session moves through explicit server-validated states.
- **Real-time WebSocket telemetry** (`faculty_sync`, `student_marked`, `attendance_updated`) pushing live present/absent counts onto the home card.
- A **cache-first, manifest-versioned hydration** model (`FacultyHydrationService`) for offline-friendly instant UI.

### 1.5 Target Users

- **Faculty members** of the institution (primary). Email is the canonical identity.
- Admin portal and SmartBoard portal consume the same backend; the Home Module only surfaces faculty-facing data.

### 1.6 Faculty Workflow (Home-driven)

```
Login / Biometric Unlock
        │
        ▼
┌───────────────────────┐
│ HOME DASHBOARD        │  ← Header + Session Card + Today's Schedule
│  • See next/current   │
│    class card         │
│  • Swipe to start     │──► AttendanceCodeScreen (OTP/QR) ──► Session ACTIVE
│    session            │         └─► WebSocket live counts ──► "View Live" monitor
│  • Tap schedule card  │──► MyClassScreen(subject) ──► Mark Attendance / Records / Reports
│  • Drawer / tabs      │──► Courses, My Class, Profile, Reports, Resources, Chat
└───────────────────────┘
```

---

## 2. Layered Architecture & Data Flow

The Home Module follows a strict layered architecture:

```
┌────────────────────────────────────────────────────────────────────┐
│  PRESENTATION (lib/Presentation/Features/Faculty)                   │
│  DashboardScreen • DashboardHeader • SessionControlSection          │
│  ScheduleSection • AppDrawer • CustomSlidingNavBar                  │
│  ProfileModalContent (bottom sheet)                                 │
└──────────────┬─────────────────────────────────────────────────────┘
               │ watch() / read()  (Provider)
┌──────────────▼─────────────────────────────────────────────────────┐
│  CONTROLLER  DashboardController (ChangeNotifier +                 │
│              WidgetsBindingObserver)                               │
│  Holds: schedule lists, subjects cache, session metadata,          │
│  present/absent counters, recovery buffer, WS subscriptions        │
└──────┬──────────────────────────────┬──────────────────────────────┘
       │ reads/writes                 │ listens
┌──────▼─────────────────────┐   ┌────▼──────────────────────────────┐
│  DATA (Repositories)       │   │ ENGINE + SERVICES                 │
│  CourseRepository          │   │ TimetableController (1s tick)     │
│  AttendanceRepository      │   │ WebSocketService (broadcast)      │
│  OverrideRepository        │   │ TimeSyncService (virtual clock)   │
│  AuthRepository            │   │ FacultyService (ValueNotifiers)   │
│                            │   │ FacultyHydrationService (manifest)│
│                            │   │ BoardReadinessNotifier (singleton)│
└──────┬─────────────────────┘   └────▲──────────────────────────────┘
       │ Dio (interceptors)           │
┌──────▼─────────────────────────────────────────────────────────────┐
│  NETWORK  ApiClient (Dio)                                          │
│   • RetryInterceptor • AuthInterceptor • SecurityInterceptor       │
│   • TLS cert pinning • Firebase JWT Bearer • X-Device-* headers    │
└──────┬─────────────────────────────────────────────────────────────┘
       │ HTTPS + WSS
┌──────▼─────────────────────────────────────────────────────────────┐
│  BACKEND  /api/v1/faculty/sync, /start_session, /session/current-   │
│           state, /ws (WebSocket), /api/v1/time                      │
└──────┬─────────────────────────────────────────────────────────────┘
       │
┌──────▼─────────────────────────────────────────────────────────────┐
│  DATABASE  Faculty manifests, cohorts, rosters, schedule,          │
│            sessions, attendance records, device binding            │
└────────────────────────────────────────────────────────────────────┘
```

### 2.1 Data flow on cold start (two-track bootstrap)

```
main()
 ├─ Track A (~100ms): dotenv + Hive minimal boxes + prefs
 │     └─ FacultyService.loadFromCache()  → profile/stats/courses from cache
 ├─ Track B (after first frame): Firebase init + remaining Hive boxes
 │     └─ TimeSyncService.initFallbackClock() + bootstrap() (GET /api/v1/time)
 │     └─ NotificationService.init()
 │     └─ SyncFcmHandler.init() + KeyEnrollmentService.enroll()
 └─ runApp(IntelliAttendApp) → UnifiedAuthGate → DashboardScreen
```

---

## 3. Provider & State Management Wiring

Wiring is declared in `lib/main.dart` (`IntelliAttendApp.build`):

| Provider | Type | Created | Notes |
|---|---|---|---|
| `SecurityController` | `ChangeNotifierProvider` | Eager | Root overlay: lock screen, compromised device gate |
| `ApiClient` | `Provider` | Eager | Singleton Dio client with interceptors |
| `CourseRepository` | `ProxyProvider<ApiClient, CourseRepository>` | Lazy | Cache-first schedule repo |
| `AttendanceRepository` | `ProxyProvider<ApiClient, AttendanceRepository>` | Lazy | Session + attendance commands |
| `AuthRepository` | `ProxyProvider<ApiClient, AuthRepository>` | Lazy | Sign-out, auth status |
| `DashboardController` | `ChangeNotifierProxyProvider2<CourseRepository, AttendanceRepository, DashboardController>` | **Lazy** | Never initialized until `UnifiedAuthGate` passes biometrics |
| `ResourceRepository` / `ResourcesController` | Lazy | Not on the home screen, but same shell |

**Reactivity primitives used on Home:**
- `context.watch<DashboardController>()` / `context.read<DashboardController>()` — session card + schedule.
- `ValueListenableBuilder<FacultyProfile?>(valueListenable: FacultyService.profile)` — header greeting, drawer identity, profile modal.
- `ValueListenableBuilder<List<AppNotification>>(valueListenable: NotificationService.history)` — unread badge.
- `ValueListenableBuilder<FacultyStats?>(valueListenable: FacultyService.stats)` — stats card (legacy section).
- `ValueListenableBuilder<ThemeMode>(valueListenable: ThemeController.themeMode)` — drawer theme toggle.

> **Note (architectural debt):** `StatsSection` and `QuickActionsSection` in `dashboard_sections.dart` are **imported but never rendered** on the current Home screen. They are legacy/dead UI preserved for reference. Documented in §9.

---

## 4. Screen Structure — Widget Tree

```
DashboardScreen (StatefulWidget, SingleTickerProviderStateMixin)
└─ Consumer<DashboardController>
   └─ Scaffold
      ├─ drawer: AppDrawer (ValueListenableBuilder<FacultyProfile?>)
      ├─ body: IndexedStack(index:_currentIndex)
      │   ├─ [0] MainDashboardView
      │   ├─ [1] CoursesScreen
      │   ├─ [2] MyClassScreen
      │   └─ [3] ProfileScreen
      └─ bottomNavigationBar: CustomSlidingNavBar

MainDashboardView (StatefulWidget)
└─ NotificationListener<ScrollNotification>  (pull-to-refresh logic)
   └─ CustomScrollView (physics: PullDownOnlyPhysics)
      ├─ SliverAppBar (pinned, 72dp, animated LinearProgressIndicator)
      │   └─ FlexibleSpaceBar → SafeArea → DashboardHeader
      ├─ SliverToBoxAdapter → SessionControlSection
      └─ SliverToBoxAdapter → ScheduleSection(onViewAll, onCourseTap)
```

---

## 5. App Shell — `DashboardScreen`

**File:** `lib/Presentation/Features/Faculty/dashboard_screen.dart`

### 5.1 Class Summary

| Item | Detail |
|---|---|
| Class | `DashboardScreen` (StatefulWidget) |
| State | `_DashboardScreenState` with `SingleTickerProviderStateMixin` |
| State vars | `_currentIndex` (bottom nav tab), `_scaffoldKey` (GlobalKey) |
| Lifecycle | `initState()` → `_initData()` → `FacultyService.load()` + `_requestNotificationPermission()` |

### 5.2 Responsibilities

- Hosts the 4-tab shell (`IndexedStack`): Home / Courses / My Class / Profile.
- Wraps every screen in `Consumer<DashboardController>`.
- Builds the `AppDrawer` and `CustomSlidingNavBar`.
- Handles logout (`_handleLogout`), assignment/submission/settings navigation.

### 5.3 Methods & Handlers

| Method | Purpose |
|---|---|
| `_initData()` | Awaits `FacultyService.load()` (cache-first master load), then requests push permission |
| `_requestNotificationPermission()` | Calls `FirebaseMessaging.instance.requestPermission(alert, badge, sound)` |
| `_showCreateAssignment()` | Push `CreateAssignmentScreen` |
| `_showSubmissions()` | Push `SubmissionsScreen` |
| `_showSettings()` | Push `SettingsScreen(onBackPressed: pop)` |
| `_handleLogout()` | `AuthRepository.signOut()` → `FacultyService.clear()` → `SharedPreferences.setBool('is_logged_in', false)` → `pushAndRemoveUntil(LoginScreen)` |
| `_loadDashboardData()` | Calls `DashboardController.refreshData()` (invoked on re-tapping Home tab) |

### 5.4 Bottom Navigation — `CustomSlidingNavBar`

**File:** `lib/Presentation/Widgets/custom_sliding_nav_bar.dart`

- 4 items, `Expanded` row inside a padded container (64px + bottom inset).
- Items (icon / activeIcon / label):

| # | Icon | Active Icon | Label | Screen |
|---|---|---|---|---|
| 0 | `dashboard_outlined` | `dashboard_rounded` | Home | `MainDashboardView` |
| 1 | `menu_book_outlined` | `menu_book_rounded` | Courses | `CoursesScreen` |
| 2 | `group_outlined` | `group_rounded` | My Class | `MyClassScreen` |
| 3 | `person_outline_rounded` | `person_rounded` | Profile | `ProfileScreen` |

- Active color `AppTheme.accentTeal`, inactive `0xFF52525B` (dark) / `0xFF94A3B8` (light).
- **Tab switch behavior:** tapping index 0 re-triggers `DashboardController.refreshData()`; tab index stored in `_currentIndex`; screens preserved in `IndexedStack` (state retention, no rebuild).
- `onTap` per item uses `GestureDetector` with `HitTestBehavior.opaque`.

### 5.5 Drawer — `AppDrawer`

**File:** `lib/Presentation/Widgets/app_drawer.dart`
Detailed in [§9 Navigation Drawer & Quick Actions](#9-navigation-drawer--quick-actions).

### 5.6 Pull-to-Refresh (`MainDashboardView`)

- Custom `NotificationListener<ScrollNotification>` (`_handleScrollNotification`) instead of the stock `RefreshIndicator`.
- Threshold: `_kRefreshThreshold = 80.0` px of downward overscroll.
- While dragging past the top, `_dragProgress` (0→1) fills the `LinearProgressIndicator` pinned under the `SliverAppBar`.
- On `ScrollEndNotification` with `_dragProgress >= 1.0` → `_triggerRefresh()`: sets `_isRefreshing=true`, calls `refreshData()`, waits 900 ms, resets.
- Scroll physics `PullDownOnlyPhysics` (`app_theme.dart`): allows downward overscroll bounce but suppresses ballistic scroll past the end (screen "freezes" at bottom).

### 5.7 SliverAppBar

- `expandedHeight: 72`, `pinned: true`, no elevation, `surfaceTintColor: transparent`.
- Background: `0xFF050505` (dark) / white (light).
- `bottom`: `AnimatedOpacity` (180 ms) wrapping the refresh `LinearProgressIndicator` (`minHeight: 3`, lime `0xFFA3E635`).

### 5.8 Profile Bottom Sheet — `ProfileModalContent`

Opened via header avatar tap (`_showProfileModalStatic`):

| Row | Icon | Label | Value source |
|---|---|---|---|
| 1 | avatar (40dp radius) | — | `profile.profileImage` (NetworkImage/FileImage) or `ui-avatars.com` fallback |
| 2 | — | Greeting/Name | `profile.name`, `profile.email` |
| 3 | `badge_outlined` | Employee Code | `email.split('@')[0].toUpperCase()` |
| 4 | `business_outlined` | Primary Dept | `profile.department` |
| 5 | `work_outline_rounded` | Designation | `profile.designation` |
| 6 | `history_edu_rounded` | Experience | Hard-coded `"8+ Years"` |
| 7 | `star_outline_rounded` | Rating | Hard-coded `"4.9/5.0"` |

Sheet: 85% screen height, top radius 32, drag-handle bar (4×40px, 10% alpha).

---

## 6. Home Header — `DashboardHeader`

**File:** `lib/Presentation/Features/Faculty/Components/dashboard_header.dart`

### 6.1 Responsibility

Renders the pinned app-bar row: profile avatar + connectivity dot, time greeting + faculty name, and the notification bell with unread badge.

### 6.2 Components

| Component | Details |
|---|---|
| **Profile avatar** | 40×40 `Container`, circular, 2px border (`white@10%` dark / `0xFFE2E8F0` light). Image via `_getProfileImage`: `http`→`NetworkImage`, local path→`FileImage`, else `assets/images/logo_square.png` |
| **Online status dot** | `Positioned` bottom-right `AnimatedContainer` (300 ms), 12×12 circle, **lime `0xFFA3E635`** when connected, **amber** when offline, 2px border, glow shadow (`alpha 0.4`). Backed by `connectivity_plus` |
| **Greeting** | `_getTimeGreeting()`: hour < 12 → "Good Morning,", < 17 → "Good Afternoon,", else "Good Evening,". 14px, secondary color |
| **Faculty name** | `profile.name` (falls back to empty). 20px bold Inter |
| **Notification bell** | 40×40 circular (5% white dark / `0xFFF1F5F9` light), icon `notifications_none_rounded`, unread red badge `9+` cap. `onTap` → `NotificationsScreen` |

### 6.3 Connectivity Tracking

```dart
// initState
_checkConnectivity();                                       // one-shot check
_connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
  _isConnected = results.any((r) => r != ConnectivityResult.none);
});
```

`_isConnected` drives the lime/amber dot — **this is "online status" at the device-network level**, not a presence/heartbeat status.

### 6.4 Tap Targets & Navigation

| Tap | Action |
|---|---|
| Avatar | `widget.onProfileTap` → `ProfileModalContent` bottom sheet |
| Bell | `Navigator.push(NotificationsScreen)` |
| Greeting/Name | None (non-interactive) |

### 6.5 Data Sources

| UI field | Data source |
|---|---|
| `profile.name` | `ValueListenableBuilder<FacultyProfile?>` on `FacultyService.profile` |
| Unread count | `NotificationService.history` (in-memory list loaded from Hive box `notifications` → key `history`) |

---

## 7. Session Control Section

**File:** `lib/Presentation/Features/Faculty/Components/session_control_section.dart`

This is the most complex component on Home. It renders exactly one of four mutually-exclusive card variants plus the section header.

### 7.1 Section Header (`_SectionHeader`)

Title selection logic (in order):

| Condition | Title |
|---|---|
| `ctrl.activeSession != null` | "Ongoing Session" |
| `ctrl.isBreak` | `ctrl.breakLabel` |
| `ts.isClassActive` | "Class in Progress" |
| `phase == beforeFirstClass` | "Upcoming Session" |
| `phase == afterLastClass && mainCardClass != null` | "Upcoming Session" |
| `phase == weekend && mainCardClass != null` | "Upcoming Session" |
| fallback | breakLabel or "Upcoming Session" |

`DynamicPulseDot(state: pending)` is rendered when `ctrl.activeSession != null` — a slow blue pulse indicating the live session.

### 7.2 Card Variant Selection

```
if (ctrl.displayShimmer)                       → ShimmerCard
else if (isOngoing)                            → _buildSessionCard  (live session)
else if (mainCard != null)                     → _buildUpcomingCard (next/current class)
else if (ctrl.isBreak)                         → _buildBreakCard
else                                           → _buildEmptyState
```

- `isOngoing` = `activeSession != null && currentSlot != null`.
- `mainCard` = `ctrl.mainCardClass` (see §11.5).

### 7.3 Card 1 — Ongoing Session Card (`_buildSessionCard`)

Used when a session is `active` (or igniting) and it maps to the current timetable slot.

**Layout (top→bottom):**
1. Decorative blurred circles: teal `0xFF2DD4BF@8%` (top-right, 128dp), white (bottom-left, 96dp).
2. `_CountdownBadge(endTime: mainCard.endTime ?? session['end_time'])` — live HH:MM:SS countdown **to class end**.
3. Title `"$subjectCode - $subjectName"` — 24px bold.
4. Detail row: `Icons.location_on_rounded` + `_cleanRoom(roomNumber)` (strips `Room_`/`room` prefix via regex `^[Rr]oom[_\s]*`), lime `0xFF84CC16`, tappable → `showRoomInfoSheet`.
5. RichText present count: `"${session['present_count']} / ${session['total_count']} Present"` — lime bold count.
6. **"View Live"** button → pushes `ChangeNotifierProvider(LiveMonitorController(repo, sessionId, courseId, sectionId), child: LiveMonitorScreen)`.

**Data precedence:** `mainCard.subjectName` → `session['subject_name']` → `'Live Session'`.

### 7.4 Card 2 — Upcoming Card (`_buildUpcomingCard`)

Used when no active session but a class is next (or the next-in-week).

- Badge logic (`showLiveCountdown`):
  - `ts.isClassActive || ctrl.isWithinT3 || ts.isBeforeFirstClass || (ts.isBreak && ts.nextBlock != null)` → live countdown badge `"${ctrl.timeLeft} LEFT"`.
  - `afterLastClass || weekend` with a next block → `ts.breakLabel.toUpperCase()` (e.g., "TOMORROW").
  - else → "UPCOMING".
- Title `"$subjectCode - $subjectName"` via `ctrl.resolveSubjectName(mainCard)` (subjects cache).
- Room detail row (tap → room sheet).
- **If classes ended** → status row `Icons.done_all_rounded` "Classes ended for today".
- **Else** → `_buildSwipeToStart` → `SwipeToStartSession`.

### 7.5 Card 3 — Break Card (`_buildBreakCard`)

- Badge "BREAK", icon picked by label: contains `LUNCH`→`restaurant_rounded`, `BIO`→`coffee_rounded`, else `free_breakfast_rounded`.
- Caption: **"No session can be started during break"** — enforced by server `SLOT_NOT_CURRENT` guard and the fact that no SwipeToStart is rendered.

### 7.6 Card 4 — Empty State (`_buildEmptyState`)

- Badge "END OF DAY", icon `event_busy_rounded`, "No class schedule for today".
- Status row: `done_all_rounded` "Classes ended for today" (if `mainCard != null`) else `wb_sunny_rounded` "See you tomorrow!".

### 7.7 Shimmer Card (`_buildShimmerCard`)

Shown while `displayShimmer` (150 ms debounce after fetch start). Renders `SkeletonLoader` placeholders sized to the real card.

### 7.8 `SwipeToStartSession` — the Swipe-to-Start Gesture

**Internal state machine:** `enum _SwipeState { idle, loading, error }`

| Aspect | Details |
|---|---|
| Handle | 56×56 gradient teal `Container`, `arrow_forward_rounded`, glow shadow |
| Max drag | `constraints.maxWidth - 56` |
| Animations | `_handleController` (250 ms snap, easeOutCubic) + `_shimmerController` (1500 ms repeat, `_ShimmerPainter` sweep) |
| Completion | Drag ≥ 95% → `_handleController.animateTo(1.0, 80 ms)` → `HapticFeedback.heavyImpact()` → state=loading → `_executeSession()` |
| `_executeSession()` | Await `widget.onComplete()` (navigates to `AttendanceCodeScreen`), then `_snapBack()`. On error: map `_friendlyError`, set state=error, show floating `SnackBar` (errorRed, 3 s), auto-snap-back after 3 s |
| Re-entrancy | `_requestInFlight` guard blocks double-fire |
| Shimmer painter | `_ShimmerPainter` paints a `LinearGradient` sweep following `_shimmerProgress` (-1→2) |

**`_friendlyError` mapping table:**

| Detected token | User message |
|---|---|
| `SLOT_NOT_CURRENT` / "not currently active" | "This class is not currently in session." |
| `ALREADY_ACTIVE` / "already active" | "A session is already active. End it first." |
| `AUTH` / `401` / `token` / "Authentication required" | "Authentication expired. Please log in again." |
| `NOT_FOUND` / `404` / "Course not" | "Course not assigned to you." |
| `timeout` / `Connection` | "Server unavailable. Check your connection." |
| `500` / `502` / `503` | "Server error. Please try again." |
| fallback | Cleaned `Exception:` message truncated to 80 chars |

**On-complete navigation:** `PageRouteBuilder` — 500 ms `easeOutCubic`, `FadeTransition` + `ScaleTransition` (0.92→1.0) → `AttendanceCodeScreen(courseName, room, scheduledClass)`.

### 7.9 Countdown Badges & Clock

- `_CountdownBadge` (stateful, 1 s periodic timer): parses `"HH:MM AM/PM"` end time, computes diff vs `DateTime.now()`, formats `HH:MM:SS LEFT` in JetBrains Mono; clamps negatives to `00:00:00`.
- `PremiumClockBadge` (also in `premium_clock_badge.dart`): pill with icon + mono text used for "UPCOMING"/"BREAK"/countdown.

### 7.10 Room Info Bottom Sheet (`showRoomInfoSheet`)

- **Block inference:** contains `B`→Block B, `C`→Block C, else Block A.
- **Floor inference:** regex first number: ≥400→4th, ≥300→3rd, ≥200→2nd, ≥100→1st, else Ground.
- Rows: `business_rounded` Block, `layers_rounded` Floor, `map_rounded` Navigation ("Follow signs to $block").
- CTA `ElevatedButton` "Got it" (lime in `session_control_section`, `0xFF84CC16` in `schedule_section`).

---

## 8. Today's Schedule Section

**File:** `lib/Presentation/Features/Faculty/Components/schedule_section.dart`

### 8.1 Responsibility

A horizontally-paged carousel of today's (or, if none, tomorrow's) scheduled classes, with per-class topic timeline, progress bar, and "See More" deep-link into the full topic list.

### 8.2 Section Header

- Title: "Today's Schedule" or "Tomorrow's Schedule" (when today is empty).
- **"See All"** (teal, 14px) → `onViewAll` → `FacultyTimetableScreen`.

### 8.3 Carousel (`PageView.builder`)

- `PageController(viewportFraction: (390/screenWidth).clamp(0.78, 0.92))`.
- **Auto-focus logic:** on init + every 30 s (`_autoScrollTimer`), computes `_focusIndex`:
  1. Index of the class currently containing `currentMinutes`.
  2. Else index of the first class whose `startMinutes > currentMinutes`.
  3. Else -1.
  Then `animateToPage(focusIdx, 400 ms, easeOutCubic)` **only if focus changed** (`_lastFocusIdx`).
- **Jump-to-focus on first build:** after first frame, `jumpToPage(focusIdx)`.
- **Page-transform effect:** each card is `Transform.translate(slideY = distance*4)` + `Transform.scale(1 - distance*0.05)` + `Opacity(1 - distance*0.2).clamp(0.4, 1.0)`.
- `_containerHeight`: `315 + (textScale-1)*50` clamped 315–420 (accessibility safe).
- **Page indicator:** dots lerp 8→5 px by distance, active teal, inactive secondary@30%. `HapticFeedback.selectionClick()` on page change.

### 8.4 Schedule Card (`_ScheduleCardWidget`)

| Element | Details |
|---|---|
| Border | Highlight lime `0xFFA3E635` (1.5px) when `isHighlighted` (current class) |
| Time badge | `BackdropFilter` (blur 12) pill, JetBrains Mono teal start time |
| Topics area | `_buildTopicsContainer` (max 156px) or `_buildEmptyTopicsArea` ("No topics available") |
| Title | `"${subjectCode} - ${resolveSubjectName()}"` 15px w800 |
| Room chip | lime `0xFF84CC16` chip + `arrow_forward_ios` → `_showRoomInfo` sheet |
| Completion badge | `"$pct%"` + 50×6 `LinearProgressIndicator` (lime), pct = completed/total topics |
| "See More" | shown when topics > 4 → `CourseTopicsScreen(scheduledClass)` |
| `onTap` | `HapticFeedback.heavyImpact()` → `MyClassScreen(initialSubjectCode)` |

### 8.5 Topic Timeline (`_buildTopicsContainer` / `_buildTopicRow`)

- Vertical timeline: left column 28px — 18dp circle per topic + 2px connector line.
- Circle states:
  - **Completed** → filled green `0xFF22C55E`, white check (11px), connector `green@30%`.
  - **Current** (first incomplete) → `_buildGlowingCircle`: `0xFF34D399` with glow shadow (`0x2634D399`, blur 8, spread 1), white dot.
  - **Future** → secondary@15%, dot icon, dimmed text.
- Each row: `FadeTransition` + `SlideTransition` driven by `_topicAnimController` (300 ms) with **staggered `Interval(startInterval, startInterval+0.4)`** where `startInterval = index/total*0.6`.
- Topic meta: `"${completedCount}/${totalCount}"` — green when completed, `0xFF34D399` when current.
- Auto-scroll to first incomplete topic on expand (`_scrollToCurrentTopic`, offset = idx*42 clamped to maxScrollExtent, 350 ms).
- **"Tomorrow" chip:** if all today's topics complete → blue `0xFF3B82F6` chip previewing tomorrow's first topic name.

### 8.6 Loading & Empty States

- Shimmer: 3 horizontal `SkeletonLoader` cards (175px image block + two text bars).
- Empty: "No Active Class" + `event_available_rounded` icon + "No class schedule for today".

---

## 9. Navigation Drawer & Quick Actions

### 9.1 Drawer Structure (`app_drawer.dart`)

Teal profile header (avatar + name + role + "VERIFIED FACULTY" chip) → grouped `ListView` → branding footer → Sign Out.

### 9.2 Drawer Menu Items (sections)

| Section | Item | Icon | Action |
|---|---|---|---|
| ACADEMICS | Student Directory | `people_alt_rounded` | `StudentDirectoryScreen`; subtitle "N Enrolled Students" summed from `FacultyService.courses` enrollment |
| ACADEMICS | Live Attendance / Attendance Manager | `check_circle_rounded` | `RealtimeAttendancePage(courseName, section:"A")`; shows red "LIVE" badge when `AttendanceService().liveCourseName != null` |
| ACADEMICS | Advanced Reports | `analytics_rounded` | `ReportsScreen` |
| CONTENT | Resources | `folder_rounded` | `ResourcesScreen` |
| CONTENT | Create Assignment | `assignment_rounded` | `CreateAssignmentScreen` |
| CONTENT | Submissions | `cloud_upload_rounded` | `SubmissionsScreen` |
| SECURITY & CLOUD | Device Management | `devices_other_rounded` | Dialog: `SecurityService().activeDevices` list; "SECURE" badge; REVOKE per non-current device |
| SECURITY & CLOUD | AI Faculty Assistant | `psychology_rounded` | `LiveSupportChatPage` |
| PREFERENCES | App Settings | `settings_suggest_rounded` | `SettingsScreen` |
| THEME | Switch to Dark/Light | `light_mode_rounded` / `dark_mode_rounded` | `ThemeController.toggle()` |

**Sign Out:** bottom bar, `Icons.logout_rounded`, `errorRed` → `widget.onLogout` → `_handleLogout` in `DashboardScreen`.

### 9.3 The "Quick Actions" of the Home screen

> **Documented reality:** The current Home body renders only the Header, Session Card, and Schedule. The two `dashboard_sections.dart` widgets are **legacy & not wired** into the tree:

| Legacy widget | Intended content | Legacy navigation |
|---|---|---|
| `StatsSection` | "Attendance Record" — Present (lime), Absent (red), Dept Avg (teal) from `FacultyService.stats` | none (read-only) |
| `QuickActionsSection` | Chat / History / Insights / Support tiles | Chat → `ChatListScreen`, History → `HistoryScreen`, Insights → `AnalyticsScreen`, Support → `HelpCenterPage` |

The **live** quick-access entry points are the 4 bottom tabs + the drawer items in §9.2. Mark Attendance / Attendance Records / Students / Messaging / Reports / Settings / Resources all remain reachable through: **My Class tab → Mark Attendance & Records screens** and **Drawer → Reports/Resources/Students/Submissions**.

---

## 10. The Timetable Engine

### 10.1 Files

| File | Contents |
|---|---|
| `lib/engine/engine.dart` | Barrel export re-exporting the shared package + local controller/state-machine |
| `lib/engine/timetable_controller.dart` | `TimetableController extends ChangeNotifier` — 1 s tick, day-boundary callback, snapshot diffing |
| `lib/engine/time_source.dart` | `SystemClockTimeSource` (legacy) |
| `lib/engine/timetable_state_machine.dart` | Legacy `TimetableStateMachine` wrapper around shared `TimetableEvaluator` |
| `lib/engine/timetable_snapshot.dart`, `timetable_phase.dart`, `time_block.dart` | Re-exports of shared types |

**All real evaluation logic lives in the `intelli_attend_shared` git package** (`lib/engine/…`).

### 10.2 Shared types (from `intelli_attend_shared`)

**`TimetablePhase`** enum: `beforeFirstClass`, `activeClass`, `break_`, `afterLastClass`, `weekend`, `noSchedule` (+ boolean getters).

**`TimeBlock`** wraps a `TimetableSlot`; exposes `id`, `isBreak`, `startMinutes`, `endMinutes`, `durationMinutes`, `subjectCode/Name/roomNumber` (null on break), `breakLabel`, `contains(currentMinutes)`, `countdownSecondsAt(currentSeconds)`, `fromSlot`.

**`TimetableSnapshot`** fields:
`phase`, `subjectName`, `subjectCode`, `roomNumber`, `countdown` (Duration), `countdownLabel`, `breakLabel`, `targetTime`, `currentBlock`, `nextBlock`; factories `initial()`, `empty()`, `active()`, `waiting()`, `tomorrow()`, `ended()`, `weekend()`; countdown label format `HH:MM:SS`.

**`TimetableEvaluator.evaluate(timeContext, todayBlocks, tomorrowBlocks)`** decision tree:
1. No blocks at all → `TimetableSnapshot.empty()`.
2. Today empty → tomorrow countdown, else `weekend`/`ended`.
3. `block.contains(now)` → `active` with implicit break between consecutive blocks.
4. `now < first.start` → `waiting(nextBlock=first)`.
5. `now ≥ last.end` → tomorrow countdown.
6. Else → implicit gap break `_buildGapBreak`.
Break labels: 730–750 → "Lunch Break", 670–680 → "Bio Break", else "Break".

**`InstitutionalTime`** = `{dayOfWeek, startMinutes, startSeconds, rawDateTime}`.
**`SyncedClockSource`** converts `nowMsProvider()` to `tz` institutional time via `timezone` package (falls back to local time on failure).

### 10.3 `TimetableController`

```dart
final TimetableController timetableEngine;   // created in DashboardController ctor
```

- `_timer = Timer.periodic(1 s, _evaluateAndNotify)`.
- Day boundary: `if (timeContext.dayOfWeek != _lastEvaluatedDay) onDayChanged?.call()` → `DashboardController` re-runs `_init()`.
- `_snapshotsEqual` compares phase, subject, room, countdownLabel, breakLabel, block boundaries → **only notifies when something actually changed** (prevents needless rebuilds).
- `updateBlocks(today, tomorrow)` → `_evaluateAndNotify()`.
- `forceReevaluate()` on app resume.
- Disposal removes the `WidgetsBindingObserver` and cancels the timer.

---

## 11. DashboardController — Business Logic

**File:** `lib/Presentation/Features/Faculty/dashboard_controller.dart`

### 11.1 Declaration & Dependencies

```dart
class DashboardController with ChangeNotifier, WidgetsBindingObserver {
  static const String _institutionTimezone = 'Asia/Kolkata';
  final CourseRepository _courseRepository;
  final AttendanceRepository _attendanceRepository;
  final OverrideRepository _overrideRepository = OverrideRepository();
  final TimetableController timetableEngine;   // injected _SyncedTimeSource
}
```

Constructor side-effects:
- `FacultyHydrationService.onDataChanged = reloadFromCache` — re-read schedule after hydration writes to Hive.
- `WidgetsBinding.instance.addObserver(this)`.
- `timetableEngine.addListener(_onEngineTick)`; `timetableEngine.onDayChanged = () => _init()`.
- `BoardReadinessNotifier.instance.addListener(_onBoardReadinessChanged)`.
- `_init()` kicks off loading.

### 11.2 State Variables

| Variable | Type | Purpose |
|---|---|---|
| `_schedule` | `List<ScheduledClass>` | Today's classes |
| `_tomorrowSchedule` | `List<ScheduledClass>` | Tomorrow's classes |
| `_subjectsCache` | `Map<String,String>` | code→canonical subject name |
| `_isLoading` / `_displayShimmer` | `bool` | Loading state + shimmer flag (150 ms debounce `_shimmerThresholdTimer`) |
| `_activeSessionMetadata` | `Map<String,dynamic>?` | Live session id, subject, room, counts |
| `_activeOtpResponse` | `SessionStartResponse?` | Latest OTP payload |
| `_sessionState` | `SessionState` | idle/preparing/igniting/active/closed |
| `_sessionStateInfo` | `SessionStateInfo?` | Recovery state (version-guarded) |
| `_presentCount` / `_absentCount` | `int` | Live counters |
| `_isRecovering` / `_recoveryBuffer` | `bool` / `List<WebSocketEvent>` | Buffers WS events during state recovery |
| `_notifyThrottle` / `_pendingNotifyCount` | `Timer` / `int` | 250 ms coalescing for count updates |
| `_wsEventSub` / `_wsConnSub` | `StreamSubscription` | WS subscriptions |

### 11.3 Getters

`scheduledClasses` (= `_withDummyTopics(_schedule)`), `tomorrowSchedule`, `weeklySchedule` (7-day map merging today/tomorrow/cached), `isLoading`, `displayShimmer`, `activeSessionId`, `activeOtpResponse`, `activeSession`, `sessionState`, `sessionStateInfo`, `presentCount`, `absentCount`, `mainCardClass`, `currentSlot`, `isCurrentSlot(c)`, `isTomorrow`, `isBreak`, `breakLabel`, `timeLeft`, `isWithinT3`, `isWithinPreClassWindow`.

### 11.4 Dummy Topic Fallback (`_withDummyTopics`)

When a `ScheduledClass` has **no topics from the backend**, a deterministic pseudo-random bank (`_dummyTopicsBank` of 10 `CourseTopic`s) supplies 5–8 topics: `count = (subjectCode.hashCode % 4 + 5).clamp(5,8)`, `start = hashCode.abs() % (bank.length - count + 1)`.

> ⚠️ **Documented behavior (design debt):** this means "Today's Schedule" topics are **not always real** unless the `/faculty/sync` payload includes `topics`. Flagged for backend owners.

### 11.5 `mainCardClass` resolution

1. `currentBlock` not null and not break → use it; else `nextBlock`.
2. If block null or break: if `afterLastClass || weekend` → `_findNextClassInWeek()` (searches Mon→Sun cached schedules); else null.
3. `_resolveScheduledClass(block)`: find `_schedule`/`_tomorrowSchedule` entry by `block.sourceSlot.id`.

### 11.6 Time-window helpers

| Getter | Definition |
|---|---|
| `isWithinT3` | Not class active, phase ≠ noSchedule, countdown ∈ (0, 180] s |
| `isWithinPreClassWindow` | `preClassWindowSeconds = 1800`; countdown ∈ (0, 1800] s |
| `isBreak` | `ts.isBreak || weekend || beforeFirstClass || !isClassActive` |
| `breakLabel` | `ts.breakLabel` → "Happy Sunday" → "Classes ended for today" → "Classes start at 09:30 AM" |
| `timeLeft` | `ts.countdownLabel` |

### 11.7 Startup & Caching Strategy (`_init` / `_initWithData`)

1. Read `FirebaseAuth.instance.currentUser`; if absent → shimmer, retry after 2 s, give up.
2. `_subjectsCache = PersistenceService.getSubjectsCache()`.
3. `_schedule = getCachedSchedule(today)`, `_tomorrowSchedule = getCachedSchedule(tomorrow)`.
4. **Cache hit** → `_pushBlocksToEngine()`, mark loaded, `_syncOverrides(email, today)` (fire-and-forget), then `recoverState()`.
5. **Cache miss** → shimmer + `_fetchFullScheduleFromFirebase` (awaits `watchTodaySchedule().first` and `watchSchedule(tomorrow).first`, pushes blocks, syncs overrides).
6. Always calls `recoverState()` to restore any active session.

### 11.8 Override Merging (`_syncOverrides` / `_mergeOverrides`)

- Fetches `fetchTodaysOverrides(email)` from the sync payload (`overrides[]`).
- For overrides where `originalFacultyEmail == FacultyService.canonicalId` → remove slot id from `_schedule`.
- Where `substituteFacultyEmail == canonicalId` → insert a new `ScheduledClass` built from the override (legacy time strings formatted `HH:MM` from `startMinutes/endMinutes`), re-sorted by `startMinutes`.
- Re-pushes blocks to the engine.

### 11.9 Session Lifecycle & State Machine

```
        (server session created)
                │
    ┌───────────▼───────────┐   startExistingSession()/startSession()   ┌──────────┐
    │       idle            ├──────────────────────────────────────────►│ preparing │
    └───────────────────────┘                                           └────┬─────┘
                                                                              │ WS: session_igniting
                                                                              ▼
                                                                        ┌──────────┐
                                                                        │ igniting │──► GET /session/current-state
                                                                        └────┬─────┘
                                                                              │ WS: attendance_open / session_activated
                                                                              ▼
                                                                        ┌──────────┐   WS: attendance_closed / session_archived
                                                                        │  active  ├──────────────────────────────► closed → clearActiveSession()
                                                                        └──────────┘
```

**State transitions driven by:**
- `startSession(ScheduledClass)` → `POST /api/v1/faculty/start_session {slot_id}`.
- `startExistingSession(sessionId)` → `POST /api/v1/start-session {session_id}` (guard: only from `preparing`).
- `refreshOtp()` → `POST /api/v1/faculty/refresh_otp {session_id}`.
- `retrySession(c)` → `clearActiveSession()` + `startSession(c)`.

### 11.10 Session Recovery (`recoverState`)

- `GET /api/v1/session/current-state` (3 s timeouts).
- **Version guard:** if `info.sessionId == current.sessionId && info.version <= current.version` → skip (stale).
- **Slot guard:** only restores when `currentSlot != null`; defense-in-depth slot-id check; legacy servers without `slot_id` are trusted.
- `_restoreActiveSession(info)` builds `_activeSessionMetadata` and calls `_connectDashboardWs(sessionId)`.
- During recovery, incoming WS events buffer in `_recoveryBuffer` and flush afterwards (`_flushRecoveryBuffer`).
- Called on startup, WS connect, app resume (`didChangeAppLifecycleState(resumed)` → `forceReevaluate()` + `recoverState()`).

### 11.11 WebSocket Event Handling (`_handleWsEvent`)

**Guards:** session-id mismatch vs `_sessionStateInfo.sessionId` → blocked; `event.version <= _sessionStateInfo.version` → blocked.

| Event | Effect |
|---|---|
| `facultySync` / `fullStateSync` | Set present/absent from `total_present/total_students`; `_scheduleNotify()` |
| `studentVerified` / `attendanceUpdate` / `markAttendanceAck`(success) / `studentMarked` | present+1 |
| `attendanceUpdated` | Absolute present/absent override from `present(_count)` / `absent(_count)` |
| `sessionPreparing` | state→preparing |
| `sessionIgniting` | state→igniting |
| `attendanceOpen` / `sessionActivated` | state→active, version bump |
| `boardConnected` | notify (drawer/board UI) |
| `attendanceClosed` / `sessionArchived` | state→closed, version bump, then `clearActiveSession()` |
| `studentRejected`, `otpFailed`, `otpVerified`, `heartbeat`, chat/presence/call events, `unknown` | no-op on dashboard |

`_scheduleNotify()` coalesces notifies via 250 ms `Timer`.

### 11.12 `clearActiveSession()`

Nulls metadata, resets counters/recovery, cancels WS subs, calls `WebSocketService().disconnect()`, notifies.

### 11.13 Board Readiness Bridge

`isBoardReady(slotId)` / `clearBoardReadiness(slotId)` delegate to the `BoardReadinessNotifier` singleton (set by FCM `SyncFcmHandler` when the SmartBoard signals ready). `clearBoardReadiness` is invoked at `startSession` start.

### 11.14 Disposal

Cancels shimmer/notify timers, cancels WS subs, `WebSocketService().disconnect()`, removes observers/listeners, resets `FacultyHydrationService.onDataChanged` (only if it still points to `reloadFromCache`), disposes engine.

---

## 12. Repositories

### 12.1 `CourseRepository`

**File:** `lib/Data/Repositories/course_repository.dart`

| Method | Contract |
|---|---|
| `watchTodaySchedule(email)` | `watchSchedule(email, today)` |
| `watchSchedule(email, dayName)` | Single-emission `StreamController`; emits cache then server, closes |
| `getCachedSchedule(dayName)` | Reads Hive `academicBox['schedule_<day>']` |
| `_emitScheduleOnce` | 1) emit cache; 2) `GET /api/v1/faculty/sync`, filter `schedule_list` by `day_of_week`, sort by `start_time`, `_cacheSchedule`, emit; on error emit `[]` if cache empty |

- Cache key: `schedule_<day.toLowerCase()>`.
- Day indexing: 1=Monday … 7=Sunday.
- Filters: `.where((c) => c.dayOfWeek == dayIndex)`.

### 12.2 `AttendanceRepository`

**File:** `lib/Data/Repositories/attendance_repository.dart`

| Method | Endpoint | Notes |
|---|---|---|
| `startSession(scheduledClass)` | `POST /api/v1/faculty/start_session` body `{slot_id}` | Throws `"$errorCode: $message"` / `Exception(message)` / `Connection failed: $e` |
| `refreshOtp(sessionId)` | `POST /api/v1/faculty/refresh_otp` `{session_id}` | |
| `generateQr(sessionId, otp)` | `POST /api/v1/faculty/generate_qr` `{session_id, otp}` | Returns bool |
| `markAttendance(request)` | `POST /api/v1/faculty/attendance/manual` | 409 → throws `ALREADY_MARKED:<source>` |
| `markAttendanceCorrection(...)` | `POST /api/v1/faculty/attendance/correction` | 409 → same |
| `getSyncData()` | `GET /api/v1/faculty/sync` | Caches `student_rosters`; fallback to cache on failure |
| `terminateSession(sessionId)` | `POST /api/v1/session/terminate` | |
| `generateRescueSeed(sessionId, seed, deviceInfo)` | `POST /api/v1/session/$sessionId/rescue-seed` | |
| `reconcileSession(sessionId)` | `POST /api/v1/faculty/sessions/$sessionId/reconcile` | |
| `fetchCurrentState()` | `GET /api/v1/session/current-state` (3 s timeouts) | Returns raw map or null |
| `startExistingSession(sessionId)` | `POST /api/v1/start-session` | |
| `fetchSessionStatus(sessionId)` | `GET /api/v1/session/$sessionId` (3 s timeouts) | |

### 12.3 `OverrideRepository`

**File:** `lib/Data/Repositories/override_repository.dart`

| Method | Contract |
|---|---|
| `fetchTodaysOverrides(email)` | Reads `overrides[]` from `GET /api/v1/faculty/sync`; maps to `OverrideSlot`; returns `[]` on error |

### 12.4 `AuthRepository` (used by logout)

`signOut()` — clears Firebase auth + session; `checkAuthStatus()`, `verifySession(deviceInfo)` used by `FacultyService.executeAuthFlow` (login path, not home path).

---

## 13. Services

### 13.1 `FacultyService` (static singleton)

**File:** `lib/Services/faculty_service.dart`

| Static member | Type | Purpose |
|---|---|---|
| `profile` | `ValueNotifier<FacultyProfile?>` | Header/drawer identity |
| `stats` | `ValueNotifier<FacultyStats?>` | Legacy stats card |
| `courses` | `ValueNotifier<List<Map>>` | Drawer enrollment sum |
| `isRegistered` | `ValueNotifier<bool>` | Auth gate |
| `canonicalId` | `String?` | `profile.value?.email` — **the v4.0 identity** used in override matching & WS payloads |

**Key methods:**
- `loadFromCache()` — profile/stats/courses from Hive; sets `is_logged_in` prefs.
- `deriveCoursesFromCohorts()` — builds unique course list from `cohorts` (course_code/subject_code), writes `subjects_cache`.
- `executeAuthFlow(authRepo)` — auth/status → verify-session → load profile or flag registration-required.
- `loadBaseProfile()` / `load()` — cache-first; fallback `GET /api/v1/faculty/sync` → `data['profile']`; persists `profile` + `is_registered`; guarded by `_isLoaded` flag + `_loadCompleter` re-entrancy lock.
- `initializeListeners()` / `onAppResume()` — `FacultyHydrationService.syncIfNeeded()`.
- `applyProfile(data)` — authoritative server profile (email mandatory), persists device_info.
- `updateProfileImage(path)` / `clear()` / `resetToDefaults()`.

### 13.2 `FacultyHydrationService`

**File:** `lib/Services/faculty_hydration_service.dart`

Manifest-based sync:
- `syncIfNeeded()`: if `manifest_hash` + cached profile exist AND `cohorts` non-empty → **skip server** (`unchanged`). Else `GET /api/v1/faculty/sync`.
  - `remoteHash == localHash` → `unchanged`.
  - hash mismatch → `_wipeLocalData()` + `_persistManifest(data)` → `updated`.
  - first sync → `firstSync`.
  - timeout/connection → `noNetwork` (serve cache).
- `_persistManifest(data)`: writes `faculty_profile`, `cohorts`, `schedule_<day>`, `schedule_days`, `roster_<key>`, `roster_keys`, `adhoc_sessions`, `manifest_hash`, `manifest_version`, `last_sync_timestamp`; fires `onDataChanged` (→ `DashboardController.reloadFromCache`).
- `forceWipeAndResync()`, `getCohortsFromCache()`, `getScheduleForDay()`, `getRosterForCohort()`, `getAdhocSessions()`.

### 13.3 `TimeSyncService`

**File:** `lib/Services/time_sync_service.dart`

- **Virtual clock:** `CurrentTime = ServerTime + (CurrentUptime − UptimeAtAnchor)` using the platform monotonic clock (immune to OS wall-clock changes).
- Fallback boot-anchored monotonic clock (`initFallbackClock()`); `syncedNowMs` fast path.
- `bootstrap()` → `GET /api/v1/time`; RTT-corrected `trueTimeAtArrival = server + rtt/2`; `_applyHandshake`; persists `_time_sync_uptime_anchor` + drift `t3_synced_drift_ms`.
- `compensateDrift()` (call on resume) fixes deep-sleep drift via hardware uptime.
- Reboot detection: persisted uptime > current uptime ⇒ reboot.
- Dashboard uses `_SyncedTimeSource` (subclass of shared `SyncedClockSource`) with `nowMsProvider: () => TimeSyncService.syncedNowMs`.

### 13.4 `WebSocketService` (singleton)

**File:** `lib/Services/websocket_service.dart`

- `connectAndJoinRoom(sessionId)` — builds `wss://<api-host>/ws?session_id=...&token=<firebaseJWT>&token_type=firebase`.
- Broadcast `events` stream (`StreamController.broadcast`) + `connectionState` stream.
- Exponential backoff reconnect (1 s → 30 s cap).
- 30 s `ping` heartbeat; ignores `pong`.
- Parses JSON → `WebSocketEvent.fromJson`.
- Outbound helpers: `sendMarkAttendance`, `sendChatMessage`, `sendTyping`, `sendReadReceipt`, `sendPresence`, `sendCallSignal`, `connectMessaging`.
- `disconnect()` on session end/logout.

### 13.5 `BoardReadinessNotifier` (singleton `ChangeNotifier`)

Slot-level readiness set; `isReady/markReady/clearReady/clearAll`; fed by `SyncFcmHandler` (SmartBoard FCM pings) and cleared by `startSession`.

### 13.6 `NotificationService` (singleton)

`history` ValueNotifier + Hive `notifications['history']`; `addNotification` (attendance/system/assignment/security), `markAllAsRead`, `markAsRead`, `showSystemNotification` (channel `intelliattend_channel`); `onPayloadTap` deep-link hook wired to `MessagingRouter.openChatFromPayload`.

### 13.7 `ApiClient` + Interceptors

**File:** `lib/Core/Network/api_client.dart`

- Base URL: `API_BASE_URL` env → `https://api-dev.balaseetharamanjaneyulu.com`.
- Timeouts: connect 15 s, receive 15 s.
- **Interceptor order:** `RetryInterceptor` → `AuthInterceptor` → `SecurityInterceptor` → `LogInterceptor` (debug only).
- `RetryInterceptor`: max 2 retries for connectionTimeout/receiveTimeout/connectionError with backoff `(retries+1)*2 s`.
- TLS cert pinning via SHA-256 `PINNED_CERT_FINGERPRINTS` env list.
- `AuthInterceptor` (`lib/Core/Network/Interceptors/auth_interceptor.dart`): attaches `Authorization: Bearer <Firebase ID token>` (cached, force-refresh on `user-token-expired`/`invalid-credential`); on 401 → security revocation/device mismatch → `ForceLogoutService`, else token-refresh-and-retry, else force logout; on 403 → account blocked / device/proxy mismatch → force logout.
- `SecurityInterceptor` (`lib/Core/Network/Interceptors/security_interceptor.dart`): attaches `X-Device-ID`, `X-Device-Fingerprint`, `X-Device-Model`, `X-App-Version`; on 426 → `appDeprecated` force logout; on 403 device violations → force logout.

### 13.8 `PersistenceService`

**File:** `lib/Services/persistence_service.dart`

- Track A (`initMinimal`): Hive `faculty_profile` + `academic_data` (AES-256 via `HiveAesCipher`, key in secure storage) + SharedPreferences — ~100 ms.
- Track B (`initRemainingBoxes`): `attendance`, `notifications`, `device_data`, `messaging`.
- `saveSubjectsCache`, `saveBackendToken`/`getBackendToken`/`clearBackendToken` (secure storage), `saveDeviceInfo`, generic `cachePut/Get/Remove`, `clearAllData`.

---

## 14. Data Models & DTOs

### 14.1 `ScheduledClass` — `lib/Data/Models/Faculty/scheduled_class.dart`

| Field | Type | Nullable | JSON key(s) |
|---|---|---|---|
| `id` | `String` | No | `id` (passed separately) |
| `subjectName` | `String` | No | `subject_name` / `course_name` / `title` / `name` / `subject_id` |
| `subjectCode` | `String` | No | `subject_code` / `course_code` / `code` / `subject_id` |
| `roomNumber` | `String` | No | `room_number` / `classroom_id` |
| `startTime` / `endTime` | `String` | No | `start_time` / `end_time` (legacy "9:00 AM") |
| `dayOfWeek` | `int` | No | `day_of_week` (int or name) |
| `sectionId` | `String?` | Yes | `section_id` |
| `smartboardId` | `String?` | Yes | `smartboard_id` |
| `startMinutes` / `endMinutes` | `int?` | Yes | `start_minutes` / `end_minutes` |
| `topics` | `List<CourseTopic>` | No | `topics[]` |

Key methods: `toTimetableSlot({institutionTimezone})` → shared `TimetableSlot`; `fromJson`; `toJson` (omits nulls/empty topics); `_parseDay` (int or English name → 1..7); `_parseLegacyTime` (12-hour string → minutes).

### 14.2 `CourseTopic` — `lib/Data/Models/Faculty/course_topic.dart`

`name`, `isCompleted` (`is_completed`/`completed`), `completedCount` (`completed_count`), `totalCount` (`total_count`). Immutable `const` model with `fromJson`/`toJson`.

### 14.3 `OverrideSlot` — `lib/Data/Models/Faculty/override_slot.dart`

`id`, `sectionId`, `slotId`, `originalFacultyEmail`, `substituteFacultyEmail`, `date`, `subjectCode`, `subjectName`, `roomNumber`, `startMinutes`, `endMinutes`, `dayOfWeek`, `classType` (default "Lecture"), `reason?`, `legacyStartTime?`, `legacyEndTime?`, `legacyDayOfWeek?`. `toTimetableSlot(freshId)` builds a `SlotType.substitutionOverride` slot. Parses legacy 12-hour strings to minutes.

### 14.4 `SessionStartResponse` (DTO) — `attendance_repository.dart`

`sessionId`, `otp` (default `'000000'`), `secondsRemaining` (clamped 10–300, default 120), `expiresAt?`, `currentTime?`, `websocketUrl?` (falls back to `ws_token`), `state` (default `'IGNITING'`), `version` (default 1).

### 14.5 `SessionStateInfo` — `lib/Data/Models/Attendance/attendance_models.dart`

`state` (SessionState), `sessionId?`, `presentCount`, `absentCount`, `version`, `stateTimestampMs`, `subjectName?`, `subjectCode?`, `roomNumber?`, `sectionId?`. JSON keys: `state`, `session_id`, `present`/`present_count`, `absent`/`absent_count`, `version`, `state_timestamp_ms`/`last_updated`, `subject_name`, `subject_code`, `room_number`, `section_id`. Has `copyWith`.

**`SessionState` enum:** `idle, preparing, igniting, active, closed`.

### 14.6 `FacultyProfile` — `faculty_service.dart`

`name`, `department`, `designation`, `email`, `facultyId`, `profileImage?`. JSON: `name`, `department`, `designation`, `email`, `facultyId`, `profileImage`.

### 14.7 `FacultyStats` — `faculty_service.dart`

`livePresentCount`, `totalExpectedStrength`, `departmentAverage`, `attendanceHistory` (List<int>). JSON: `live_present_count`, `total_expected_strength`, `department_average`, `attendance_history`.

### 14.8 `WebSocketEvent` + payload DTOs — `lib/Core/Models/websocket_event.dart`

- `WsEventType` enum (29 values; full list in §16).
- `WebSocketEvent { type, data, receivedAt }`, `fromJson` (maps snake_case & legacy aliases), `get<T>(key)`.
- Payload DTOs: `AttendanceUpdateData`, `StudentMarkedData`, `FacultySyncData` (`total_present`, `total_students`, `present_students[]`), `FullStateSyncData` (`total_present`, `total_students`, `roster[]`), `AttendanceMarkAckData` (`success`, `student_id`, `error`, `data`), `BoardConnectedData`, `OtpFailedData` (`attempt_count`, `retries_remaining`).

### 14.9 `AppNotification` — `notification_service.dart`

`id`, `title`, `body`, `timestamp`, `category` (enum `NotificationCategory {attendance, system, assignment, security}`), `isRead`. Hive-serialized JSON.

### 14.10 Legacy models referenced

`StudentAttendance` and `AttendanceMarkRequest` (`student_id` = student email, `session_id`, `notes?`) live in `attendance_models.dart`; used by live monitor, not the Home body directly.

---

## 15. Backend API Reference

> All endpoints are HTTPS against `${API_BASE_URL}` (default `https://api-dev.balaseetharamanjaneyulu.com`). Authorization = `Authorization: Bearer <Firebase ID Token>`. Device headers added by `SecurityInterceptor`.

### 15.1 `GET /api/v1/faculty/sync` — Master Faculty Sync (Home's workhorse)

| Attribute | Value |
|---|---|
| **Name** | Faculty Master Sync / Hydration Manifest |
| **Purpose** | Single-shot load of profile, schedule, overrides, cohorts, rosters, manifest version |
| **Method / URL** | `GET /api/v1/faculty/sync` |
| **Headers** | `Authorization: Bearer <JWT>`, `X-Device-ID`, `X-Device-Fingerprint`, `X-Device-Model`, `X-App-Version`, `Content-Type: application/json` |
| **Request body** | None |
| **Consumers** | `FacultyService.load/loadBaseProfile`, `CourseRepository._emitScheduleOnce`, `OverrideRepository.fetchTodaysOverrides`, `FacultyHydrationService.syncIfNeeded`, `AttendanceRepository.getSyncData` |

**Expected response body (200):**
```json
{
  "profile": {
    "name": "Dr. A. Sharma",
    "department": "CSE",
    "designation": "Professor",
    "email": "a.sharma@university.edu",
    "is_registered": true,
    "profileImage": "https://...|/local/path"
  },
  "faculty_profile": { "...": "same as profile", "is_registered": true },
  "schedule_list": [
    {
      "id": "slot-uuid",
      "subject_code": "CS101",
      "subject_name": "Data Structures",
      "course_name": "Data Structures",
      "room_number": "Room A-204",
      "classroom_id": "A-204",
      "start_time": "09:30 AM",
      "end_time": "10:30 AM",
      "day_of_week": 1,
      "section_id": "sec-uuid",
      "smartboard_id": "sb-01",
      "start_minutes": 570,
      "end_minutes": 630,
      "topics": [
        { "name": "Introduction & Overview", "is_completed": true,
          "completed_count": 62, "total_count": 62 }
      ]
    }
  ],
  "schedule": { "monday": [ "...same slots..." ], "tuesday": [ "..."] },
  "overrides": [
    { "id": "ov-uuid", "slot_id": "slot-uuid",
      "original_faculty_email": "x@university.edu",
      "substitute_faculty_email": "a.sharma@university.edu",
      "date": "2026-08-02", "subject_code": "CS201",
      "subject_name": "Algorithms", "room_number": "B-301",
      "start_minutes": 570, "end_minutes": 630, "day_of_week": 1,
      "class_type": "Lecture", "reason": "Faculty on leave",
      "start_time": "09:30 AM", "end_time": "10:30 AM" }
  ],
  "cohorts": [ { "course_code": "CS101", "course_name": "Data Structures",
                 "short_name": "DS" } ],
  "rosters": { "cohort-key": [ { "student_id": "...", "student_name": "..." } ] },
  "student_rosters": [ "..." ],
  "adhoc_sessions": [ "..." ],
  "manifest_hash": "sha256-hash",
  "manifest_version": 42
}
```

| Attribute | Value |
|---|---|
| **Success** | 200 with payload above |
| **Failures** | 401 (expired/session revoked), 403 (blocked / device mismatch), 426 (app update required), 5xx |
| **Validation / business rules** | Identity resolved from Firebase JWT email claim; schedule filtered server-side by faculty; `manifest_hash` change triggers local wipe+resync |
| **Caching** | Hive `schedule_<day>` per-day caches, `subjects_cache`, `cohorts`, `rosters` |
| **Error handling** | Repos return cached data or `[]`; hydration returns `SyncResult` enum |
| **Retry logic** | `RetryInterceptor` (2 retries on timeout/connection errors) |

### 15.2 `GET /api/v1/time` — Virtual Clock Anchor

| Attribute | Value |
|---|---|
| **Purpose** | Server timestamp for anti-wall-clock-attack time sync |
| **Method / URL** | `GET /api/v1/time` |
| **Response** | `{ "timestamp": 1690000000000, "server_time_ms": 1690000000000 }` |
| **Used by** | `TimeSyncService.bootstrap()` (RTT-corrected anchor) |
| **Note** | Timeouts 5 s; failures degrade to fallback monotonic clock |

### 15.3 `POST /api/v1/faculty/start_session` — Start Session

| Attribute | Value |
|---|---|
| **Purpose** | Create a new attendance session for the current slot |
| **Method / URL** | `POST /api/v1/faculty/start_session` |
| **Request body** | `{ "slot_id": "<scheduledClass.id>" }` |
| **Response (200)** | `{ "session_id": "...", "otp": "123456", "seconds_remaining": 120, "expires_at": "...", "current_time": "...", "websocket_url": "wss://...", "state": "IGNITING", "version": 1 }` |
| **Failures** | 400 `SLOT_NOT_CURRENT`, 409 `ALREADY_ACTIVE`, 401 auth, 404 course not assigned, 5xx |
| **Consumers** | `DashboardController.startSession` |

### 15.4 `POST /api/v1/faculty/refresh_otp` — Rotate OTP

`{ "session_id" }` → `SessionStartResponse`. Used by `AttendanceCodeScreen` every ~30 s.

### 15.5 `POST /api/v1/faculty/generate_qr` — QR Token

`{ "session_id", "otp" }` → 200 bool. Requires valid OTP.

### 15.6 `GET /api/v1/session/current-state` — Recovery

Recovery endpoint returning `SessionStateInfo` JSON (`state`, `session_id`, `present`/`present_count`, `absent`, `version`, `state_timestamp_ms`, `subject_name/code`, `room_number`, `section_id`). 3 s timeouts. `null` on failure.

### 15.7 `POST /api/v1/start-session` — Start Existing (PREPARING→IGNITING)

`{ "session_id" }` → `SessionStartResponse`. Guarded: only valid from `preparing` state.

### 15.8 `GET /api/v1/session/{sessionId}` — Session Status

3 s timeouts; raw map or null. (Used by live monitor/recovery tooling.)

### 15.9 `POST /api/v1/faculty/attendance/manual`

`AttendanceMarkRequest.toJson()` (`student_id`, `session_id`, `notes?`). 409 → `ALREADY_MARKED:<source>`.

### 15.10 `POST /api/v1/faculty/attendance/correction`

`{ session_id, student_id, reason, notes? }`. 409 → `ALREADY_MARKED`.

### 15.11 `POST /api/v1/session/terminate`

`{ "session_id" }` → 200 bool. Session teardown.

### 15.12 `POST /api/v1/faculty/sessions/{sessionId}/reconcile`

Recounts PRESENT records server-side; returns corrected counters.

### 15.13 `POST /api/v1/session/{sessionId}/rescue-seed`

`{ seed, device_info{...}, generated_at }` → 200 bool. Rescue/validation path.

### 15.14 WebSocket `WSS /ws`

Query params: `session_id`, `token` (Firebase JWT), `token_type=firebase`. See §16.

---

## 16. WebSocket Real-Time Protocol

### 16.1 Connection

`wss://<api-host>/ws?session_id=<id>&token=<firebaseJWT>&token_type=firebase`
Reconnect: exponential 1→30 s. Heartbeat: `{"type":"ping"}` every 30 s; ignore `pong`.

### 16.2 Event Table (dashboard-relevant)

| `type` (wire) | `WsEventType` | Dashboard effect |
|---|---|---|
| `faculty_sync` | facultySync | present/absent from `total_present`/`total_students` |
| `full_state_sync` | fullStateSync | same + roster |
| `student_marked` | studentMarked | present+1 |
| `attendance_update` / `ATTENDANCE_MARKED` / `student_verified` | attendanceUpdate / studentVerified | present+1 |
| `mark_attendance_ack` / `attendance_updated` | markAttendanceAck / attendanceUpdated | ack → present+1; else absolute override |
| `session_preparing` | sessionPreparing | → preparing |
| `session_igniting` | sessionIgniting | → igniting |
| `attendance_open` / `session_activated` | attendanceOpen / sessionActivated | → active (version bump) |
| `attendance_closed` / `session_archived` | attendanceClosed / sessionArchived | → closed, then clear session |
| `board_connected` | boardConnected | notify listeners |
| `otp_verified` / `otp_failed` / `student_rejected` / `heartbeat` | — | no-op |
| `message_new`, `typing`, `presence_update`, `call_event`, etc. | chat events | no-op (chat screens consume) |

### 16.3 Version Guard

Both `session_id` equality and `version` monotonicity are enforced before applying events — stale/foreign events are dropped, preventing counter rollback.

---

## 17. Navigation Map

```
UnifiedAuthGate (biometrics) 
      │ (success)
      ▼
DashboardScreen (IndexedStack)
 ├── [Home] MainDashboardView
 │     ├─ Header avatar ─► ProfileModalContent (bottom sheet)
 │     ├─ Header bell ─► NotificationsScreen
 │     ├─ Session card "View Live" ─► LiveMonitorScreen (LiveMonitorController provider)
 │     ├─ Swipe-to-start ─► AttendanceCodeScreen (fade+scale 500ms)
 │     │        └─ QR/OTP ─► session ACTIVE ─► WebSocket live counts
 │     ├─ Schedule "See All" ─► FacultyTimetableScreen
 │     ├─ Schedule card tap ─► MyClassScreen(initialSubjectCode)
 │     │        └─ topics "See More" ─► CourseTopicsScreen(scheduledClass)
 │     └─ Room row ─► Room Info bottom sheet
 ├── [Courses] CoursesScreen
 ├── [My Class] MyClassScreen
 └── [Profile] ProfileScreen

Drawer ─► StudentDirectoryScreen | RealtimeAttendancePage | ReportsScreen |
          ResourcesScreen | CreateAssignmentScreen | SubmissionsScreen |
          LiveSupportChatPage | SettingsScreen | DeviceMgmt dialog | Theme toggle
```

---

## 18. Sequence Diagrams

### 18.1 Cold Start + Schedule Load

```
FacultyService.load()                CourseRepository.watchTodaySchedule(email)
      │                                      │
      │ cache? ──yes──► profile set          │ emit cached schedule (Hive)
      │ no                                   │
      ▼                                     ▼
GET /api/v1/faculty/sync ───────────────────────► (server)
      │ 200                                    │
      ▼                                        │
 profile + is_registered + schedule_list        │
      │                                        ▼
 push blocks → TimetableController (1s tick)   filter by day_of_week, sort
      │                                        │
   OverrideRepository.fetchTodaysOverrides ────► cache schedule_<day>
      │                                        │
      ▼                                        ▼
 _mergeOverrides → push blocks again        emit server list
      │
      ▼
 recoverState() ──► GET /api/v1/session/current-state
      │
      ▼ (if active session) _connectDashboardWs(sessionId)
```

### 18.2 Swipe-to-Start → Active Session

```
UI SwipeToStartSession (95% drag)
 │ HapticFeedback.heavyImpact() → loading
 ▼
DashboardController.startSession(class)
 │  POST /api/v1/faculty/start_session {slot_id}
 ▼  SessionStartResponse(sessionId, otp, ...)
DashboardController.startSession
 │  _connectDashboardWs(sessionId) ──► WSS /ws?session_id=..&token=..
 │  Navigator.push(AttendanceCodeScreen)
 ▼
AttendanceCodeScreen: OTP auto-rotation (refresh_otp every 30s)
 │ student scans QR / enters OTP
 ▼
Server broadcasts WS event(s)
 │  student_marked / faculty_sync / attendance_updated
 ▼
DashboardController._handleWsEvent
 │  version guard → update _presentCount/_absentCount → _scheduleNotify()
 ▼
SessionControlSection rebuilds card with live counts
```

### 18.3 Recovery After Network Drop

```
app resume / WS reconnect
DashboardController.recoverState()
  GET /api/v1/session/current-state
  │ version stale? → skip & flush buffer
  │ active + currentSlot? → _restoreActiveSession → reconnect WS
  ▼
WS events buffered in _recoveryBuffer during recovery
  │ recoverState completes
  ▼
_flushRecoveryBuffer() replays events in order
```

---

## 19. Error Handling & Edge Cases

| Scenario | Detection | Behavior |
|---|---|---|
| No Firebase user at dashboard init | `user == null` | Shimmer 2 s → retry → give up (stays shimmerless, empty) |
| No cache + server down | `sync` throws | `_handleLoadingState(false)`; empty states render |
| Override fetch fails | try/catch | Logged; schedule served without overrides |
| Start session already active | `ALREADY_ACTIVE` / `409` | `_friendlyError` → red SnackBar + handle snap-back |
| Slot not current | `SLOT_NOT_CURRENT` | "This class is not currently in session." |
| Stale WS event | version/session guard | Dropped silently |
| Recovery fetch fails | 3 s timeouts | `recoverState` returns null; counters stay local |
| Network offline (device) | `connectivity_plus` | Header dot amber; cached data still shown |
| Token expiry | `401` | AuthInterceptor refresh+retry → else force logout |
| Device revoked | 401/403 details | `ForceLogoutService` with reason |
| App deprecated | `426` | Force logout `appDeprecated` |
| Timeout/connection errors | Dio types | `RetryInterceptor` 2× with 2/4 s backoff |
| Wall-clock manipulation | `TimeSyncService` | Server-anchored monotonic clock unaffected |
| Deep-sleep drift | resume | `compensateDrift()` + `forceReevaluate()` + `recoverState()` |

---

## 20. Performance Engineering

| Area | Technique |
|---|---|
| Cold start | Two-track bootstrap: ~100 ms Track A (Hive+prefs), Track B deferred after first frame |
| Cache-first | Dashboard serves from `schedule_<day>` cache; manifest-hash skip avoids server call entirely |
| Shimmer debounce | 150 ms threshold before showing skeletons (avoids flash on fast loads) |
| Rebuild control | `_snapshotsEqual` diffing in engine; `Consumer` granularity; `ValueListenableBuilder` scoping |
| Scroll isolation | `PullDownOnlyPhysics` kills bottom overscroll animation; `RepaintBoundary` on pulse dot & profile |
| Coalescing | `_scheduleNotify` 250 ms throttle for high-frequency WS count updates |
| Image optimization | `FileImage`/`NetworkImage` directly; no cache plugin on avatar (single image) |
| Memory | `IndexedStack` keeps tab state alive; subscriptions cancelled on dispose |
| Network | Single `GET /faculty/sync` drives schedule+overrides; WS replaces polling; 3 s timeouts on recovery |

---

## 21. Security

- **Identity:** Firebase Auth JWT; email = canonical faculty ID everywhere.
- **Every request** auto-signed via `AuthInterceptor` (Bearer JWT, refresh+retry) and hardened via `SecurityInterceptor` (X-Device-* fingerprints) and TLS cert pinning.
- **Anti-spoofing:** server-anchored virtual clock; session version monotonicity; slot-current validation; OTP rotation; QR authorized by valid OTP.
- **Role access:** server enforces faculty → course assignment (`404 Course not assigned to you.`); app mirrors with friendly errors.
- **Secure storage:** `flutter_secure_storage` (encrypted prefs / keychain) for Hive AES key + backend JWT; Hive boxes AES-256.
- **Device binding:** 401/403 device/hardware mismatches → hard force-logout with distinct reasons; 426 app-deprecation.
- **UI overlay:** `SecurityOverlay` renders `CompromisedDeviceScreen` or `LockScreen` on top of the navigator; `AbsorbPointer` blocks interaction while locked.

---

## 22. Dependencies Used

| Package | Role in Home Module | Version |
|---|---|---|
| `intelli_attend_shared` (git) | Timetable engine types + evaluator + `SyncedClockSource` | ref `school-main` |
| `provider` | Controller injection & `Consumer/watch/read` | ^6.0.5 |
| `dio` | All REST calls + interceptors | ^5.3.3 |
| `firebase_core` / `firebase_auth` / `firebase_messaging` | Init, identity/JWT, push permission | ^3.1.1 / ^5.1.1 / ^15.0.0 |
| `shared_preferences` | `is_logged_in` flag, time anchor, drift | ^2.2.1 |
| `hive` / `hive_flutter` | AES-encrypted boxes (faculty_profile, academic_data, notifications) | ^2.2.3 / ^1.1.0 |
| `flutter_secure_storage` | Hive key + backend JWT | ^9.2.4 |
| `connectivity_plus` | Header online-status dot | ^6.0.3 |
| `google_fonts` | Inter / JetBrains Mono typography | ^6.1.0 |
| `flutter_local_notifications` | System notifications (channel `intelliattend_channel`) | ^17.1.2 |
| `timezone` | Institutional time conversion (Asia/Kolkata) | ^0.9.4 |
| `flutter_dotenv` | `API_BASE_URL`, `PINNED_CERT_FINGERPRINTS` | ^5.1.0 |
| `crypto` | SHA-256 cert pinning | ^3.0.3 |
| `device_info_plus` / `permission_handler` | Device snapshot + permission flows (via HardwareService) | ^10.1.0 / ^11.3.1 |
| `intl` | Date/time formatting (used across app) | ^0.19.0 |

---

## 23. File Inventory

### 23.1 Home screen & components

| File | Role |
|---|---|
| `lib/Presentation/Features/Faculty/dashboard_screen.dart` | App shell, 4-tab IndexedStack, drawer, nav bar, pull-to-refresh, profile sheet, logout |
| `lib/Presentation/Features/Faculty/dashboard_controller.dart` | The module's brain: schedule, session state machine, recovery, WS handling |
| `lib/Presentation/Features/Faculty/Components/dashboard_header.dart` | Header: avatar+connectivity, greeting, name, notifications |
| `lib/Presentation/Features/Faculty/Components/session_control_section.dart` | Session card matrix, swipe-to-start, countdowns, room sheet |
| `lib/Presentation/Features/Faculty/Components/schedule_section.dart` | Today's schedule carousel, topic timeline, progress |
| `lib/Presentation/Features/Faculty/Components/dashboard_sections.dart` | **Legacy/unused** `StatsSection` + `QuickActionsSection` |

### 23.2 Shared UI

| File | Role |
|---|---|
| `lib/Presentation/Widgets/custom_sliding_nav_bar.dart` | Bottom navigation |
| `lib/Presentation/Widgets/app_drawer.dart` | Global drawer + device dialog |
| `lib/Presentation/Widgets/dynamic_pulse_dot.dart` | Heartbeat pulse dot |
| `lib/Presentation/Widgets/skeleton_loader.dart` | Shimmer placeholders |
| `lib/Presentation/Widgets/premium_clock_badge.dart` | Clock pill badge |
| `lib/Theme/app_theme.dart` | Theme tokens, `PullDownOnlyPhysics` |

### 23.3 Engine

| File | Role |
|---|---|
| `lib/engine/engine.dart` | Barrel |
| `lib/engine/timetable_controller.dart` | 1 s tick, day-boundary, snapshot diffing |
| `lib/engine/time_source.dart` | Legacy system-clock source |
| `lib/engine/timetable_state_machine.dart` | Legacy wrapper |
| `lib/engine/{timetable_snapshot,timetable_phase,time_block}.dart` | Re-exports |
| (shared pkg) `engine/{timetable_evaluator,timetable_snapshot,timetable_phase,time_block,time_source}.dart` | Core engine logic |

### 23.4 Data

| File | Role |
|---|---|
| `lib/Data/Repositories/course_repository.dart` | Schedule fetch/cache |
| `lib/Data/Repositories/attendance_repository.dart` | Session commands + recovery |
| `lib/Data/Repositories/override_repository.dart` | Override fetch |
| `lib/Data/Models/Faculty/scheduled_class.dart` | Timetable model |
| `lib/Data/Models/Faculty/course_topic.dart` | Topic model |
| `lib/Data/Models/Faculty/override_slot.dart` | Override model |
| `lib/Data/Models/Attendance/attendance_models.dart` | SessionState, SessionStateInfo, StudentAttendance |

### 23.5 Services / Core

| File | Role |
|---|---|
| `lib/Services/faculty_service.dart` | Profile/stats/courses notifiers + master load |
| `lib/Services/faculty_hydration_service.dart` | Manifest sync/hydration |
| `lib/Services/time_sync_service.dart` | Virtual secure clock |
| `lib/Services/websocket_service.dart` | WSS transport |
| `lib/Services/board_readiness_notifier.dart` | SmartBoard readiness set |
| `lib/Services/notification_service.dart` | In-app + system notifications |
| `lib/Services/persistence_service.dart` | Hive boxes + secure storage |
| `lib/Core/Network/api_client.dart` | Dio client, pinning, retry |
| `lib/Core/Network/Interceptors/{auth,security}_interceptor.dart` | Auth + device headers, force-logout |
| `lib/Core/Models/websocket_event.dart` | WS event types + payload DTOs |
| `lib/main.dart` | Two-track bootstrap, provider graph, security overlay |

---

## Appendix A — Known Design Notes / Technical Debt

1. **`StatsSection` & `QuickActionsSection` are dead code** on the current Home screen (imported but not rendered). If the product wants on-dashboard Quick Actions (Mark Attendance / Records / Students / Messaging / Reports / Settings / Resources), these tiles must be re-wired; today those features are reached via My Class tab and the drawer.
2. **`_dummyTopicsBank`** fabricates topics when the backend omits `topics` — real data should replace this so faculty see accurate syllabus progress.
3. **Hard-coded profile sheet values** (`"8+ Years"`, `"4.9/5.0"`) should come from the profile API.
4. **Room info sheet logic** (Block/Floor inference from a room string) is duplicated in `session_control_section.dart` and `schedule_section.dart` — extract to a shared helper.
5. **`_scheduleNotify` coalescing** is tuned for UI; the 250 ms window should be re-verified under high student scan rates.
6. **Backend contract drift risk:** `faculty/sync` returns both flat `schedule_list` and nested `schedule` + `faculty_profile` + `profile`; repositories read different shapes. Any backend change to one shape must be mirrored in the repos.

---

*End of Home Module documentation. Next module ready on request (My Class / Courses / Attendance / Messaging / Reports / Profile / Auth / Backend / Database / etc.).*
