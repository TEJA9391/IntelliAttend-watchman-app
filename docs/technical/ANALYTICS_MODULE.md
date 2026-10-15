# IntelliAttend Faculty — Analytics Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Analytics (Attendance Analytics / "Insights")
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/HOME_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/MYCLASS_MODULE.md`, `docs/technical/PROFILE_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`AnalyticsScreen` — the Chart Hub](#5-analyticsscreen--the-chart-hub)
6. [Live Stats Cards & the `AttendanceService` Dependency](#6-live-stats-cards--the-attendanceservice-dependency)
7. [Chart Components (`SfCartesianChart`)](#7-chart-components-sfcartesianchart)
8. [Backend Contract — `attendance_trend` & `section_performance`](#8-backend-contract--attendance_trend--section_performance)
9. [State Management Wiring — Loading & Data Flow](#9-state-management-wiring--loading--data-flow)
10. [Data Models & DTOs](#10-data-models--dtos)
11. [Backend API Reference](#11-backend-api-reference)
12. [WebSocket Real-Time Protocol](#12-websocket-real-time-protocol)
13. [Navigation Map](#13-navigation-map)
14. [Sequence Diagrams](#14-sequence-diagrams)
15. [Error Handling & Edge Cases](#15-error-handling--edge-cases)
16. [Performance Engineering](#16-performance-engineering)
17. [Security](#17-security)
18. [Dependencies Used](#18-dependencies-used)
19. [File Inventory](#19-file-inventory)
20. [Appendix A — Known Design Notes & Technical Debt](#20-appendix-a--known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **Analytics Module** is a single push screen that renders faculty-wide attendance analytics for the logged-in faculty member: two headline stat cards and two `Syncfusion` charts (a 14-day trend spline area and a per-section performance column chart). It is a **read-only, chart-first surface** with no filters, no interactivity, and no persistence of its own.

### 1.2 Business Goal

- Give faculty a **one-glance numeric summary** of their live roster and a **visual trend** of attendance over the last 14 days.
- Provide a **section-level performance comparison** so faculty can spot weak sections.
- All values derive from a single backend summary endpoint (`GET /api/v1/analytics/faculty/{email}/summary`).

### 1.3 Problem Statement

- Attendance history lives server-side; the app needs a lightweight, fast-drawing summary view without re-downloading full session logs.
- Faculty want both a **current snapshot** (live roster) and a **historical curve** on one screen.
- The app already ships `syncfusion_flutter_charts`; the module is the primary consumer.

### 1.4 Solution

- One `StatefulWidget` (`AnalyticsScreen`) that:
  1. Fetches `_historicalStats` once on `initState` via `ApiClient().dio` with 10 s timeouts.
  2. Subscribes (via `ValueListenableBuilder`) to the `AttendanceService` singleton for the live roster.
  3. Computes the two live stat cards client-side from that roster.
  4. Maps the API's `attendance_trend` → `SplineAreaSeries` and `section_performance` → `ColumnSeries`.
- The screen is intentionally **stateless after load**: no filters, no refresh affordance, no caching.

### 1.5 Target Users

- **Faculty members** — the "Insights" quick action on the dashboard home grid. Reached only through the Home tab, never as a standalone route.

### 1.6 Faculty Workflow (Analytics-driven)

```
Dashboard Home → Quick Actions → "Insights"
   ├─ Stat cards: Live Average % · Total Enrolled
   ├─ Weekly Attendance Trend (14-day spline area)
   └─ Section Performance (column chart)
   └─ back → Dashboard
```

---

## 2. Layered Architecture & Data Flow

```
┌───────────────────────────────────────────────────────────────────────┐
│  PRESENTATION                                                          │
│  AnalyticsScreen (StatefulWidget, single push screen)                  │
│   ├─ ValueListenableBuilder<List<StudentAttendance>>                   │
│   │    └─ AttendanceService().students   (live roster)                 │
│   └─ _historicalStats (local state, setState)                          │
└──────────────┬─────────────────────────────────────────────────────────┘
               │ context.read<ApiClient>()   ·   AttendanceService()
┌──────────────▼──────────────────────┐   ┌──────────────────────────────┐
│  INFRA / NETWORK                     │   │  SERVICES (singletons)       │
│  ApiClient (Provider, Dio, JWT)      │   │  AttendanceService            │
│  FirebaseAuth (idToken, email)       │   │   └─ students ValueNotifier   │
└──────────────┬──────────────────────┘   └──────────────────────────────┘
               │ HTTPS
   GET /api/v1/analytics/faculty/{email}/summary
```

### 2.1 Data flow on screen load

```
AnalyticsScreen.initState
   └─ _fetchHistoricalStats()
        ├─ FirebaseAuth.currentUser → email.toLowerCase()
        ├─ user.getIdToken() → idToken
        ├─ context.read<ApiClient>().dio.get(
        │      '/api/v1/analytics/faculty/$facultyEmail/summary',
        │      send/receiveTimeout: 10 s)
        ├─ 200 && data is Map → setState(_historicalStats = data)
        └─ error → debugPrint("Analytics Error: $e") → _isStatsLoading = false

Body renders inside ValueListenableBuilder(AttendanceService().students):
   ├─ _isStatsLoading true  → full-screen CircularProgressIndicator
   └─ else → stat cards from students list + charts from _historicalStats
```

---

## 3. State Management Wiring

| Concern | Mechanism |
|---|---|
| Live roster | `AttendanceService().students` — singleton `ValueNotifier<List<StudentAttendance>>`, consumed via `ValueListenableBuilder` |
| Historical payload | Local `Map<String, dynamic>? _historicalStats` + `setState` |
| Loading flag | `bool _isStatsLoading` + `setState` |
| HTTP client | `Provider<ApiClient>` (registered `main.dart:160`), read via `context.read<ApiClient>()` |
| Auth identity | `FirebaseAuth.instance.currentUser` read directly (no repository) |

The module uses **Provider only for the Dio client**; all other state is a mix of a singleton `ValueNotifier` (`AttendanceService`) and local `setState`. There is no `ChangeNotifier` controller, no repository, and no DI for the analytics call itself.

---

## 4. Screen Structure — Widget Tree

```
Scaffold (bg: AppTheme.bg)
└─ AppBar
   ├─ title "Attendance Analytics" (bold, AppTheme.text)
   ├─ transparent bg, elevation 0
   └─ leading back (arrow_back_ios_new_rounded) → Navigator.pop
└─ body: ValueListenableBuilder<List<StudentAttendance>>
     └─ _isStatsLoading ? Center(CircularProgressIndicator)
        : SingleChildScrollView(padding 24)
           ├─ Row [_buildSummaryCard("Live Average", liveRate%, shutter_speed_outlined, blue)
           │         , _buildSummaryCard("Total Enrolled", totalCount, people_outline, teal)]
           ├─ _buildChartCard("Weekly Attendance Trend",
           │        "14-day historical tracking", _buildLineChart)
           └─ _buildChartCard("Section Performance",
                    "Comparison across sections", _buildBarChart)
```

### 4.1 `_buildSummaryCard`

- 20 px padding, `borderRadius: 24`, translucent tint of the accent (`color.withValues(alpha: 0.1)`), 0.2-alpha border.
- Icon (28 px) → value (24 px bold) → label (12 px, 0.7-alpha).
- Value and label use `TextOverflow.ellipsis` + `maxLines: 1` (defensive against very long values).

### 4.2 `_buildChartCard`

- Full-width `Container`, 24 px padding, `borderRadius: 32`, `AppTheme.surface` fill, soft shadow (black @ 0.03, blur 20, offset y10).
- Title (18 px bold) + subtitle (13 px, `textSecondary`).
- Chart wrapped in `SizedBox(height: MediaQuery.sizeOf(context).height * 0.28)`.

---

## 5. `AnalyticsScreen` — the Chart Hub

**File:** `lib/Presentation/Features/Analytics/analytics_screen.dart` (219 LOC)

- `AnalyticsScreen extends StatefulWidget` with a no-arg const constructor — a pure navigation target.
- `_fetchHistoricalStats()` (analytics_screen.dart:28–53):
  - Guard: `user == null || user.email == null` → return (page shows only live cards… but see A-2/A-5).
  - `facultyEmail = user.email!.toLowerCase()`.
  - `context.read<ApiClient>().dio.get(...)` with 10 s send/receive timeouts (no auth header — relies on ApiClient interceptor).
  - Accepts only `200` AND `data is Map`; anything else silently leaves `_historicalStats` null.
- `build` (analytics_screen.dart:56–109): wraps the entire body in `ValueListenableBuilder<List<StudentAttendance>>` over `AttendanceService().students`; recomputes the two live stats on every roster change.
- Live math (analytics_screen.dart:73–75):
  - `livePresentCount = students.where(status == present).length`
  - `liveTotalCount = students.length`
  - `liveRate = total > 0 ? present/total*100 : 0`

> ⚠️ The live cards are computed from `AttendanceService().students`, which is **never populated anywhere in the codebase** (see §6 and Appendix A-1).

---

## 6. Live Stats Cards & the `AttendanceService` Dependency

**File:** `lib/Services/attendance_service.dart` (25 LOC)

```dart
class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;   // singleton
  final ValueNotifier<int> attendanceCount = ValueNotifier(0);
  final ValueNotifier<bool> isSessionLive = ValueNotifier(false);
  final ValueNotifier<String?> liveCourseName = ValueNotifier(null);
  final ValueNotifier<List<StudentAttendance>> students = ValueNotifier([]);

  void startSessionMonitoring(String sessionId, {String? courseName}) {
    liveCourseName.value = courseName;   // NOTE: students is NOT updated here
  }
  void stopMonitoring() {
    isSessionLive.value = false; liveCourseName.value = null;
    students.value = []; attendanceCount.value = 0;
  }
}
```

Key facts:

- The class comment states it is "responsible for managing the real-time attendance state via WebSocket" — **no WebSocket wiring exists in the file**.
- `students` is only ever assigned `[]` (in `stopMonitoring`). A repo-wide search for `students.value =` finds no other writer; `EligibilityService.students` is a **separate** `ValueNotifier<List<Map<String, dynamic>>>` (`eligibility_service.dart:9`).
- Consumers of `AttendanceService().students`: `AnalyticsScreen` (`analytics_screen.dart:71`) and `RealtimeAttendancePage` (`realtime_attendance_page.dart:89`). Both therefore read a permanently empty list under the current code.

Consequence for Analytics: **"Live Average" always renders `0.0%` and "Total Enrolled" always `0`**, unless a future feature starts populating the notifier. The two stat cards are effectively dead UI (A-1).

---

## 7. Chart Components (`SfCartesianChart`)

Package: `syncfusion_flutter_charts` `^26.1.35` (`pubspec.yaml:30`).

### 7.1 Weekly Attendance Trend — `SplineAreaSeries` (analytics_screen.dart:194–214)

```dart
SfCartesianChart(
  margin: EdgeInsets.zero,
  plotAreaBorderWidth: 0,
  primaryXAxis: CategoryAxis(isVisible: true),
  primaryYAxis: NumericAxis(isVisible: false),
  series: [
    SplineAreaSeries<Map<String, dynamic>, String>(
      dataSource: trendData,                     // _historicalStats?['attendance_trend'] ?? []
      xValueMapper: (d, _) => d['day'],
      yValueMapper: (d, _) => d['count'],
      color: AppTheme.primary(context).withValues(alpha: 0.2),  // translucent fill
      borderColor: AppTheme.primary(context),
      borderWidth: 3,
    )
  ],
)
```

- Expects items of shape `{"day": <String>, "count": <num>}`.
- Filled-area rendering; value axis hidden (A-8).

### 7.2 Section Performance — `ColumnSeries` (analytics_screen.dart:216–235)

```dart
ColumnSeries<Map<String, dynamic>, String>(
  dataSource: sectionData,                       // _historicalStats?['section_performance'] ?? []
  xValueMapper: (d, _) => d['section'],
  yValueMapper: (d, _) => d['percentage'],
  borderRadius: BorderRadius.circular(8),
  color: AppTheme.primary(context),
)
```

- Expects items of shape `{"section": <String>, "percentage": <num>}`.
- Rounded-top bars, primary accent color.

### 7.3 Shared chart styling

- `margin: EdgeInsets.zero`, `plotAreaBorderWidth: 0`.
- X axis visible, Y axis hidden.
- Height fixed at **28 % of the viewport height** (`SizedBox(height: MediaQuery.sizeOf(context).height * 0.28)`), inside the chart card.
- Empty arrays render an empty chart area (no "no data" placeholder, A-3).

---

## 8. Backend Contract — `attendance_trend` & `section_performance`

The module consumes only two top-level keys of the summary response:

| Key | Type | Item shape | Rendered by |
|---|---|---|---|
| `attendance_trend` | `List` | `{ "day": String, "count": num }` | `SplineAreaSeries` (14-day trend) |
| `section_performance` | `List` | `{ "section": String, "percentage": num }` | `ColumnSeries` |

Parsing (analytics_screen.dart:195–196, 217–218):

```dart
List<Map<String, dynamic>>.from(_historicalStats?['attendance_trend'] ?? []);
List<Map<String, dynamic>>.from(_historicalStats?['section_performance'] ?? []);
```

No DTO/model, no key normalization, no type coercion of values — strictly stringly-typed lookups (A-4). Unknown keys, wrong types, or a non-Map payload are tolerated only because the `?? []` fallback yields an empty (blank) chart.

> The **same summary endpoint** also feeds `HistoryScreen`, which additionally reads a top-level `sessions`/`history` list and supports cursor pagination via `limit` / `last_id` query parameters (`history_screen.dart:47–58`). `AnalyticsScreen` passes **no query parameters** and does not read the session list. The endpoint is therefore a shared "faculty summary" contract with superset payload; the two consumers parse disjoint slices of it.

---

## 9. State Management Wiring — Loading & Data Flow

_(Alias section header kept for parity with the template; content in §3.)_

- Initial paint: `_isStatsLoading = true` → full-screen spinner **replaces the entire body** (including live cards).
- On success: `_historicalStats` set, spinner removed, charts render.
- On failure/timeout/parse-guard: `_isStatsLoading = false` with `_historicalStats` null → page renders **only** the (empty) live cards and two blank chart cards. No error banner, no retry (A-2).
- Re-entrancy: `initState` runs the fetch exactly once per screen instance; popping and re-pushing re-fetches. There is no pull-to-refresh (A-5).

---

## 10. Data Models & DTOs

| Model | File | Fields / Notes |
|---|---|---|
| `StudentAttendance` | `lib/Data/Models/Attendance/attendance_models.dart` (168) | id, name, email?, image?, status, checkInTime?, deviceFingerprint?, isVerified, markedBy?; `fromJson` tolerant of `student_id`/`id`, `student_name`/`name`, `student_email`/`email`, `recorded_at`/`timestamp`, `is_verified`/`isVerified`, `marked_by`/`markedBy` |
| `StudentStatus` | `attendance_models.dart` (168) | `present`, `absent`, `issue`, `flagged`; `_parseStatus` defaults unknown → `absent` |
| `SessionState` / `SessionStateInfo` / `SessionInfo` / `AttendanceMarkRequest` | `attendance_models.dart` | Shared session/state DTOs (not used by Analytics directly) |

Analytics does **not** define module-specific DTOs; the historical payload stays a raw `Map<String, dynamic>` (A-4).

---

## 11. Backend API Reference

| Endpoint | Verb | Used by | Notes |
|---|---|---|---|
| `/api/v1/analytics/faculty/{facultyEmail}/summary` | GET | `AnalyticsScreen._fetchHistoricalStats` | 10 s send/receive timeouts; no query params; reads `attendance_trend` + `section_performance` |
| `/api/v1/analytics/faculty/{facultyEmail}/summary` | GET | `HistoryScreen._fetchPage` | Same endpoint; adds `limit` / `last_id`; reads `sessions`/`history` |
| `/api/v1/analytics/subject/{courseId}/attendance` | GET | `Reports/Components/report_helper_widgets.dart` (300) | Subject-level analytics used by the Reports module (separate contract) |

All requests go through `ApiClient().dio` (JWT bearer, interceptors, TLS). Base: `https://api-dev.balaseetharamanjaneya.com` — see `PROFILE_MODULE.md` for the client contract. Note: `AnalyticsScreen` reads the faculty email from `FirebaseAuth` directly rather than from `FacultyService.canonicalId` (equivalent value today; A-11).

---

## 12. WebSocket Real-Time Protocol

The Analytics module opens **no WebSocket channels**. Despite `AttendanceService`'s class comment ("via WebSocket"), the singleton is a plain in-memory notifier store; the only real-time-ish behavior is the `ValueListenableBuilder` reacting to future writes that never occur under current code (A-1). Pull-based REST is the only transport for the analytics data.

---

## 13. Navigation Map

```
DashboardScreen Home tab
   └─ Quick Actions row (dashboard_sections.dart:135–152)
        └─ "Insights" (Icons.insights_rounded)  ──► AnalyticsScreen  (dashboard_sections.dart:145–147)
             └─ AppBar back ──► Navigator.pop

Related (same endpoint / sibling analytics surfaces, NOT this module):
   Dashboard Home "History" quick action        ──► HistoryScreen   (dashboard_sections.dart:141–143)
   AppDrawer "Advanced Reports"                 ──► ReportsScreen   (app_drawer.dart:93–97)
   Reports UI label "Attendance Analytics"      ──► Reports/Components/attendance_chart.dart
```

Route is an anonymous `MaterialPageRoute`. There is **no deep link, no route name, no tab** for Analytics — reachable only via the dashboard quick-action grid.

---

## 14. Sequence Diagrams

### 14.1 Screen load

```
Quick Action "Insights" tap
   └─ Navigator.push(AnalyticsScreen)
        └─ initState → _fetchHistoricalStats()
             ├─ user = FirebaseAuth.currentUser
             │    └─ (null guard → silent return; page shows empty cards, A-2)
             ├─ facultyEmail = user.email.toLowerCase()
             ├─ idToken = await user.getIdToken()
             ├─ dio.get(/api/v1/analytics/faculty/$facultyEmail/summary, 10s timeouts)
             │    ├─ 200 && Map → _historicalStats = payload; _isStatsLoading=false
             │    └─ else/error → debugPrint; _isStatsLoading=false; _historicalStats stays null
             └─ build:
                  ValueListenableBuilder(AttendanceService().students)
                     ├─ livePresent/liveTotal/liveRate  (always 0/[] today — A-1)
                     ├─ _isStatsLoading ? spinner
                     └─ else stat cards + trend chart + section chart
```

### 14.2 Live roster update (as designed)

```
WebSocket/DB push (future) → AttendanceService().students.value = newList
   └─ ValueListenableBuilder fires
        └─ recompute liveRate → both stat cards re-render in place (no network)
```

(Not reachable today — no producer writes to the notifier, A-1.)

---

## 15. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| No Firebase user / null email | `_fetchHistoricalStats` returns early; page renders (empty) cards with no notice (A-2/A-5) |
| Non-200 or non-Map payload | `_historicalStats` stays null; charts render blank (A-3) |
| Network error / timeout | `debugPrint("Analytics Error: $e")`; loading flag cleared; **no user-facing error** (A-2) |
| `attendance_trend` / `section_performance` absent | `?? []` → empty chart (A-3) |
| Malformed item / wrong value types | `_buildLineChart`/`_buildBarChart` access `d['count']`/`d['percentage']` untyped; a non-numeric value can throw a cast error at chart render (A-4) |
| Empty live roster | `liveTotalCount == 0` guards division → `0.0%`, `0` (but roster is always empty today, A-1) |
| Re-entrancy / double fetch | Fetch runs once in `initState`; no manual refresh path |

---

## 16. Performance Engineering

- **Single request**: exactly one REST call per screen instance; the payload is a compact summary (no session log download).
- **No persistence**: nothing cached in Hive/`SharedPreferences`; cold data every entry (acceptable for a chart view; no offline story — A-3/A-5).
- **Scoped rebuilds**: only the two stat cards recompute on roster changes via `ValueListenableBuilder`; the charts rebuild from `_historicalStats` (stable after load) and would rebuild alongside on `setState` — minor, since the page is short-lived.
- **Fixed chart height** (28 % viewport) avoids layout thrash during first paint.
- **Lightweight**: two chart series with small datasets (14-day + per-section rows); no animations configured (defaults apply).

---

## 17. Security

- **Identity**: faculty email taken from `FirebaseAuth.currentUser` and lowercased before path interpolation — prevents case-mismatch 404s on the backend route.
- **Path injection**: `facultyEmail` is derived from the verified auth user, not user input — safe for URL interpolation.
- **Transport**: Dio via `ApiClient` (JWT bearer interceptor, TLS per app standard). `getIdToken()` is awaited but the header injection is handled by the interceptor (no manual `Authorization` header in this call — unlike `HistoryScreen`, which sends `'Authorization': 'Bearer $idToken'` explicitly).
- **Data exposure**: charts show aggregate percentages/counts; no PII in the two rendered series.

---

## 18. Dependencies Used

| Package | Where used |
|---|---|
| `provider` | `context.read<ApiClient>()` |
| `dio` | summary request via `ApiClient` (10 s timeouts) |
| `firebase_auth` | current user + idToken |
| `syncfusion_flutter_charts` | `SfCartesianChart` / `SplineAreaSeries` / `ColumnSeries` |
| `flutter/material` | layout, cards, `ValueListenableBuilder` |

No `google_fonts`, no `hive`, no image packages — the module is intentionally dependency-light.

---

## 19. File Inventory

> Line counts = `Measure-Object -Line` (non-blank, per repo convention).

### 19.1 Analytics feature — `lib/Presentation/Features/Analytics/`

| File | LOC | Role |
|---|---|---|
| `analytics_screen.dart` | 219 | The entire module: stat cards + trend + section charts |

### 19.2 Supporting surfaces & data layer

| File | LOC | Role |
|---|---|---|
| `lib/Services/attendance_service.dart` | 25 | Singleton `ValueNotifier` store (`students` consumed here) |
| `lib/Data/Models/Attendance/attendance_models.dart` | 168 | `StudentAttendance` / `StudentStatus` (shared with My Class, Realtime) |
| `lib/Presentation/Features/Faculty/Components/dashboard_sections.dart` | 186 | Home "Quick Actions" grid incl. "Insights" entry (lines 135–152) |
| `lib/Presentation/Features/Faculty/realtime_attendance_page.dart` | 382 | Co-consumer of `AttendanceService().students` (not part of this module) |

---

## 20. Appendix A — Known Design Notes & Technical Debt

### A-1. Live stat cards are dead UI — `AttendanceService().students` is never populated (HIGH)

`AnalyticsScreen` computes "Live Average" and "Total Enrolled" from `AttendanceService().students`, a singleton `ValueNotifier` that no code path ever writes to. A repo-wide search for `students.value =` finds only `[]` assignments (`attendance_service.dart:26`, in `stopMonitoring`); `EligibilityService.students` is a different notifier. Result: both stat cards permanently render `0.0%` and `0`. Either wire a producer (WebSocket/repository) or remove the cards. The class doc-comment claims WebSocket state management that no longer exists in the file.

### A-2. No error or empty state (MEDIUM)

Every failure path (network, timeout, non-200, null user) silently degrades to `_isStatsLoading = false` with null `_historicalStats`, painting empty cards and blank charts with no message and no retry. A faculty member sees a broken-looking page with zero feedback.

### A-3. "Loading" hides the whole body (LOW)

While `_isStatsLoading`, the spinner replaces the entire body — including the live cards, which don't depend on the network fetch. Live cards could render immediately and the spinner scoped to the charts.

### A-4. Stringly-typed payload parsing (LOW)

`attendance_trend` / `section_performance` are read as raw `Map` items with untyped `d['count']` / `d['percentage']` access. No DTO, no key normalization, no validation; a non-numeric value throws at chart render. `HistoryScreen` demonstrates a defensive parsing style that could be shared.

### A-5. No refresh affordance (LOW)

No pull-to-refresh, retry button, or `RefreshIndicator`. The only way to refresh is to pop and re-enter the screen (which re-runs the fetch). Stale/cached-worthy data is re-fetched cold every visit.

### A-6. "Total Enrolled" is mislabeled (MEDIUM)

The card labeled "Total Enrolled" actually shows `students.length` — the *live roster size*, not the course's enrolled/expected strength. `FacultyService` exposes `totalExpectedStrength` (unused here). Product-wise the label should either be changed or the value sourced from the roster/expected figures.

### A-7. No course/section filter (MEDIUM, product)

The summary endpoint is faculty-wide; the module has no course picker, section picker, or date range. "Section Performance" is a fixed breakdown the backend chooses. Compare: `Reports` module exposes course-scoped analytics (`/api/v1/analytics/subject/{courseId}/attendance`) — the two analytics surfaces don't share scope or UI.

### A-8. Hidden Y axis (LOW)

`NumericAxis(isVisible: false)` hides values on both charts; faculty can read shapes but not magnitudes. For an analytics product this reduces the feature's utility.

### A-9. Inconsistent timeout posture (LOW)

`AnalyticsScreen` uses 10 s send/receive timeouts; `HistoryScreen` uses 5 s on the same endpoint. Unify the client-level timeout strategy.

### A-10. Naming/entry-point confusion (LOW)

Home grid label is "Insights"; the AppBar title is "Attendance Analytics"; the drawer's "Advanced Reports" (subtitle "Analytics & Defaulters") routes to the separate `ReportsScreen`. Three names, two surfaces, one analytics concept — worth aligning labels in the IA.

### A-11. Auth source divergence (LOW)

`AnalyticsScreen` reads the email from `FirebaseAuth` while most other modules use `FacultyService.canonicalId` (also the email). If the account is ever unlinked/migrated (`ACCOUNT_UNLINKED` state handled in `FacultyService`), this screen would keep querying with the old email and silently render blank.

### A-12. Charts render blank with no placeholder (LOW)

Empty/absent series yield an empty plot area inside a large decorative card — no "no data yet" text. Cheap win for perceived quality.

---

*End of Analytics Module technical documentation. Companion: `HOME_MODULE.md`, `COURSES_MODULE.md`, `MYCLASS_MODULE.md`, `PROFILE_MODULE.md`.*
