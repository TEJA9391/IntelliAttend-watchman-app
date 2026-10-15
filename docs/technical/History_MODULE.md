# IntelliAttend Faculty — History Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** History (Session History / "Attendance History")
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/ANALYTICS_MODULE.md`, `docs/technical/HOME_MODULE.md`, `docs/technical/PROFILE_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`HistoryScreen` — the Session List Hub](#5-historyscreen--the-session-list-hub)
6. [Session Card Rendering (`_buildHistoryItem`)](#6-session-card-rendering-_buildhistoryitem)
7. [Search & Filter Surface](#7-search--filter-surface)
8. [Pagination & Cursor State Machine](#8-pagination--cursor-state-machine)
9. [Session-Detail Navigation](#9-session-detail-navigation)
10. [Data Models & DTOs](#10-data-models--dtos)
11. [Backend API Reference](#11-backend-api-reference)
12. [Shared Contract with the Analytics Module](#12-shared-contract-with-the-analytics-module)
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

The **History Module** is a single push screen that renders the logged-in faculty member's past attendance **sessions** as a paginated, card-based list. Each card shows the course name, session date/time, room, and present count. It is a **read-only, pull-based surface**: no writes, no filters (today), no detail drill-down, no export.

### 1.2 Business Goal

- Give faculty a **scrollable record of past attendance sessions** (course, date, room, present count).
- Support **pagination** so the full session log can be walked incrementally without downloading everything at once.
- Surface the data **server-authoritatively** — every entry re-fetches from the summary endpoint; there is no local persistence.

### 1.3 Problem Statement

- Session history lives server-side; the client needs a paginated view without a dedicated history endpoint.
- The app already consumes a faculty-wide **summary** endpoint for Analytics; History reuses that single contract, reading the session slice it contains, and driving server-side cursor pagination via `limit` / `last_id`.

### 1.4 Solution

- One `StatefulWidget` (`HistoryScreen`) that:
  1. Fetches the first page on `initState` via `context.read<ApiClient>().dio` with 5 s send/receive timeouts.
  2. Accumulates pages into an in-memory `_allSessionData` list using an **`_lastSessionId` cursor** (`session_id` / `id` of the last row) + fixed `_pageSize = 20`.
  3. Renders a `RefreshIndicator` + `ListView.builder`; a trailing "Load more" control when `_hasMore`.
  4. Renders each session as a decorative card (no tap action — see §9 and A-4).
- The screen is intentionally **simple**: one endpoint, one list, cursor pagination. It shares its data source with the Analytics module (see §12) but parses a disjoint slice of the payload.

### 1.5 Target Users

- **Faculty members** — intended entry point is the "History" quick action on the dashboard home grid. Note: that quick-action grid is **legacy/unwired** in the current Home tree (see §14 and A-1), so the screen is effectively unreachable in the running app today.

### 1.6 Faculty Workflow (History-driven)

```
Dashboard Home → Quick Actions → "History"     (legacy/unwired entry — A-1)
   ├─ Search field (decorative, non-functional — A-3)
   ├─ Session cards: course · date · time · room · present count
   ├─ "Load more" → next cursor page
   ├─ pull-to-refresh → reset from page 1
   └─ back → Dashboard
```

---

## 2. Layered Architecture & Data Flow

```
┌───────────────────────────────────────────────────────────────────────┐
│  PRESENTATION                                                          │
│  HistoryScreen (StatefulWidget, single push screen)                    │
│   ├─ TextField (search — no controller, no onChanged — A-3)            │
│   ├─ RefreshIndicator + ListView.builder                                │
│   │    └─ _buildHistoryItem(...)   (session cards, not tappable — A-4) │
│   └─ _buildLoadMoreButton()  (cursor pagination footer)                 │
└──────────────┬─────────────────────────────────────────────────────────┘
               │ context.read<ApiClient>()  ·  FacultyService.canonicalId
               │ FirebaseAuth.instance.getIdToken()
┌──────────────▼────────────────────────┐
│  INFRA / NETWORK                       │
│  ApiClient (Provider singleton, Dio,   │
│    AuthInterceptor, RetryInterceptor,  │
│    SecurityInterceptor, cert pinning)  │
│  FirebaseAuth (identity + idToken)     │
└──────────────┬────────────────────────┘
               │ HTTPS
   GET /api/v1/analytics/faculty/{facultyEmail}/summary
       ?limit=20[&last_id=<cursor>]
```

### 2.1 Data flow on screen load

```
HistoryScreen.initState
   └─ _fetchPage()
        ├─ setState(_isLoading = true; clear _allSessionData; _lastSessionId = null)
        ├─ facultyEmail = FacultyService.canonicalId      (profile.value?.email)
        ├─ idToken = FirebaseAuth.instance.currentUser?.getIdToken()
        │    └─ null → silent return (spinner stuck — A-2)
        ├─ dio.get('/api/v1/analytics/faculty/$facultyEmail/summary',
        │      queryParameters: {limit: "20", last_id?: cursor},
        │      Options: Authorization: Bearer <idToken>,
        │               5 s send/receive timeouts)
        ├─ 200 && data != null
        │    └─ data['sessions'] ?? data['history'] ?? []
        │         ├─ append cast to _allSessionData
        │         ├─ _hasMore = (rows.length >= 20)
        │         └─ _lastSessionId = rows.last['session_id'] ?? rows.last['id']
        └─ catch → debugPrint (console only) → flags cleared → empty state
```

---

## 3. State Management Wiring

| Concern | Mechanism |
|---|---|
| Session rows | Local `List<Map<String, dynamic>> _allSessionData` + `setState` |
| First-load flag | `bool _isLoading` + `setState` |
| Load-more flag | `bool _isLoadingMore` + `setState` |
| Cursor | `String? _lastSessionId` (last row's `session_id`/`id`) |
| Page ceiling | `bool _hasMore` (recomputed every page) |
| HTTP client | `Provider<ApiClient>` (registered `main.dart:160`), read via `context.read<ApiClient>()` |
| Auth identity | `FacultyService.canonicalId` (`faculty_service.dart:90` = `profile.value?.email`) |
| Token | `FirebaseAuth.instance.currentUser?.getIdToken()`, sent explicitly |

The module uses **no `ChangeNotifier`, no repository, no DI** for the fetch. All state is local `setState`; the only external dependencies are the Provider-registered `ApiClient` singleton and the `FacultyService`/`FirebaseAuth` identity sources. The email is interpolated straight into the URL with **no null guard** (A-5).

---

## 4. Screen Structure — Widget Tree

```
Scaffold (bg: AppTheme.bg)
└─ AppBar
   ├─ title "Attendance History" (bold, AppTheme.text)
   ├─ transparent bg, elevation 0
   └─ leading back (arrow_back_ios_new_rounded) → Navigator.pop
└─ body: Column(mainAxisSize: min)
     ├─ Padding(24h, 16v)
     │    └─ TextField  (hint "Search past sessions...", prefix search icon,
     │                   filled AppTheme.surface, radius 16, no border)
     │                   — NO controller / onChanged (A-3)
     └─ Expanded
          ├─ _isLoading        → Center(CircularProgressIndicator)
          ├─ _allSessionData.empty
          │    └─ Center(Icons.history_rounded @64 alpha 0.3,
          │              "No session history found.")
          └─ RefreshIndicator(onRefresh: _fetchPage)
               └─ ListView.builder(padding 24h)
                    ├─ itemCount = rows.length + (_hasMore ? 1 : 0)
                    ├─ index == rows.length → _buildLoadMoreButton()
                    └─ else                  → _buildHistoryItem(data)
```

### 4.1 `_buildLoadMoreButton` (history_screen.dart:152–167)

- Padding 16v, centered.
- `_isLoadingMore` → 24×24 `CircularProgressIndicator(strokeWidth: 2)`.
- Else `TextButton.icon(Icons.expand_more_rounded, "Load more")` → `_fetchPage(loadMore: true)`.

### 4.2 `_buildHistoryItem` (history_screen.dart:169–242)

See §6.

---

## 5. `HistoryScreen` — the Session List Hub

**File:** `lib/Presentation/Features/History/history_screen.dart` (229 non-blank LOC, 243 raw)

- `HistoryScreen extends StatefulWidget` with a no-arg const constructor — a pure navigation target.
- State fields (history_screen.dart:18–23):
  - `_pageSize = 20` (static const).
  - `_allSessionData` (list buffer), `_lastSessionId` (cursor), `_isLoading`, `_isLoadingMore`, `_hasMore`.
- `_fetchPage({bool loadMore = false})` (history_screen.dart:31–80):
  - Load-more path guards on `_isLoadingMore || !_hasMore` (single-flight).
  - Full-reload path clears the buffer and cursor.
  - Guards: `idToken == null` → **silent early return** (leaves `_isLoading` true — A-2); non-200 or null body → **silent early return** (A-2).
  - Parses `data['sessions'] as List? ?? data['history'] as List? ?? []` (defensive dual key).
  - Appends `Map<String, dynamic>.from(row as Map)` per row; updates `_hasMore` and the cursor from the last row's `session_id`/`id`.
  - `catch (e)` → `debugPrint("❌ HistoryScreen error: $e")` (console only) + clears both loading flags → UI falls to the empty state. No user-facing error (A-10).
- `build` (history_screen.dart:82–150): AppBar + search field + tri-state body (loading / empty / list).

> The **shared payload** with the Analytics screen is documented in `ANALYTICS_MODULE.md` §8/§11; the two consumers read disjoint slices of the same response (`AnalyticsScreen` reads `attendance_trend`/`section_performance`; `HistoryScreen` reads `sessions`/`history`). See §12.

---

## 6. Session Card Rendering (`_buildHistoryItem`)

Each card (history_screen.dart:179–241) is a `Container`:

- Margin bottom 16, padding 20, `borderRadius: 24`, `AppTheme.surface` fill, soft shadow (black @ 0.02, blur 10, offset y4).
- **Left icon chip:** 12 padding, `primary @ 0.1` tint, radius 16, `Icons.check_circle_outline` @ 28 in primary.
- **Middle (Expanded Column):**
  - Course name: `data['subject_name'] ?? 'Unknown Course'`, maxLines 1, ellipsis, bold 16.
  - Subtitle: `"$dateStr • $timeStr • Room $room"` (12 px, `textSecondary`), maxLines 1, ellipsis.
- **Right (Column, end-aligned):**
  - `data['present_count'] ?? 0` interpolated, bold 18 primary.
  - Label `"students"` (10 px `textSecondary`).

### 6.1 Date/time coercion (history_screen.dart:170–173)

```
dateRaw = data['date'] ?? data['timestamp']
  ├─ DateTime        → used directly
  ├─ String          → DateTime.tryParse
  └─ null / invalid  → dt = null
dateStr = DateFormat('dd MMM yyyy').format(dt)   (fallback 'Unknown Date')
timeStr = DateFormat('hh:mm a').format(dt)        (fallback 'Unknown Time')
```

Hard-coded display fallbacks: `'Unknown Course'`, `'TBD'` (room), `'Unknown Date'`, `'Unknown Time'`, `0` (present count). No key normalization beyond the `date`/`timestamp` pair (A-6).

---

## 7. Search & Filter Surface

A `TextField` with hint **"Search past sessions..."** renders above the list (history_screen.dart:102–116), but:

- **No `TextEditingController`**, **no `onChanged`/`onSubmitted`**, no listener.
- `_allSessionData` is **never filtered**; the field has zero functional effect (A-3).
- It is purely decorative: filled `AppTheme.surface`, search prefix icon, radius 16, borderless.

There is no other filter (no course/section/date-range pickers) anywhere in the module.

---

## 8. Pagination & Cursor State Machine

### 8.1 State fields

| Field | Initial | Meaning |
|---|---|---|
| `_pageSize` | `20` (const) | Rows requested per page (`limit` param) |
| `_lastSessionId` | `null` | Opaque cursor = last row's `session_id` (fallback `id`), stringified |
| `_isLoading` | `true` | First-page spinner |
| `_isLoadingMore` | `false` | Footer spinner |
| `_hasMore` | `true` | Footer visibility / next-request gating |

### 8.2 Transitions

```
Full reload (_fetchPage()):
   _isLoading = true; _allSessionData.clear(); _lastSessionId = null
      └─ request(limit=20)
           └─ append rows; _hasMore = rows.length >= 20
                └─ if rows non-empty: _lastSessionId = rows.last.id

Load more (_fetchPage(loadMore: true)):
   guard: if (_isLoadingMore || !_hasMore) return     (single-flight)
   _isLoadingMore = true
      └─ request(limit=20, last_id=_lastSessionId)
           └─ append rows; _hasMore = rows.length >= 20
                └─ _lastSessionId = rows.last.id   (advances cursor)
```

- **Cursor semantics:** the server returns rows **after** the given `last_id` (offsets-style cursor, not page numbers). `_hasMore` is inferred client-side as `rows.length >= _pageSize` — a page **exactly** `_pageSize` long can mis-declare a final page (one wasted request, self-corrects; A-7).
- **Empty final page:** rows empty → `_hasMore = false`, cursor unchanged → footer disappears.
- **Re-entrancy:** pull-to-refresh (`RefreshIndicator.onRefresh → _fetchPage()`) resets cursor and can race a footer load-more; the `_isLoadingMore` guard only serializes load-more calls, not refresh-vs-load-more overlap.

---

## 9. Session-Detail Navigation

**There is none in the module.** The session cards are plain `Container`s — no `InkWell`, `GestureDetector`, or `onTap` — and `history_screen.dart` contains **no `Navigator.push`** (the only `Navigator` use is the AppBar back `Navigator.pop` at history_screen.dart:95). A repo-wide search for other navigations from the History feature directory finds nothing.

Consequences:

- A tapped session card does nothing; there is no per-session detail screen, no per-session student list, no export/report action.
- The module is a pure list-viewing surface. Compare the My Class module's **`AttendanceHistoryScreen`** (`lib/Presentation/Features/my_class/attendance_history_screen.dart`, per-student, 1,656 LOC), which is a **different, unrelated screen** — it is student-scoped and reached from `StudentProfileScreen`, not from `HistoryScreen` (A-4).

---

## 10. Data Models & DTOs

The History module defines **no DTOs**. Session rows stay raw `Map<String, dynamic>` (A-6), parsed inline in `_fetchPage` and read with stringly-typed lookups in `_buildHistoryItem`.

| Key(s) read | Type expected | Used for |
|---|---|---|
| `date` / `timestamp` | `String`/`DateTime` | card date+time (via `intl` `DateFormat`) |
| `subject_name` | `String` | card title |
| `present_count` | `num` | trailing present-count stat |
| `room_number` | `String` | "Room X" subtitle segment |
| `session_id` / `id` | scalar | cursor (`_lastSessionId`) |
| `sessions` / `history` (top-level) | `List` | page source |
| `attendance_trend`, `section_performance` (top-level) | `List` | **not read by History** (Analytics only) |

No key normalization (beyond `date`/`timestamp` and `session_id`/`id` fallbacks), no type coercion, no validation. Shared models from `attendance_models.dart` (`StudentAttendance`, `SessionState`, etc.) are **not used** by this module.

---

## 11. Backend API Reference

| Endpoint | Verb | Used by | Notes |
|---|---|---|---|
| `/api/v1/analytics/faculty/{facultyEmail}/summary` | GET | `HistoryScreen._fetchPage` (history_screen.dart:47–58) | `limit` (always `"20"`) + optional `last_id`; reads `sessions`/`history`; explicit `Authorization: Bearer <idToken>`; **5 s** send/receive timeouts |
| `/api/v1/analytics/faculty/{facultyEmail}/summary` | GET | `AnalyticsScreen._fetchHistoricalStats` (analytics_screen.dart:36) | Same endpoint, **no query params**, **10 s** timeouts, no manual auth header (interceptor only); reads `attendance_trend` + `section_performance` |

All requests go through `ApiClient().dio` (JWT bearer via `AuthInterceptor`, `RetryInterceptor`, `SecurityInterceptor` device headers, TLS + cert pinning). Base URL resolves as `dotenv.env['API_BASE_URL'] ?? _defaultBaseUrl` (`api_client.dart:33`); task/documented base is `https://api-dev.balaseetharamanjaneya.com` (spelling drift between code default and docs — A-11).

**Timeout posture:** the screen overrides the Dio defaults (15 s connect / 15 s receive, `api_client.dart:38–39`) with 5 s send/receive on the request itself — inconsistent with `AnalyticsScreen`'s 10 s on the same endpoint (A-8, mirrors `ANALYTICS_MODULE.md` A-9).

---

## 12. Shared Contract with the Analytics Module

Cross-referenced from `ANALYTICS_MODULE.md` §8 and §11 — **verified consistent with `history_screen.dart`:**

- Both `HistoryScreen` and `AnalyticsScreen` call **`GET /api/v1/analytics/faculty/{facultyEmail}/summary`** — the single shared "faculty summary" contract. The payload is a **superset**: `attendance_trend`, `section_performance`, and `sessions`/`history`.
- **Analytics** passes no query parameters and parses only the trend/performance lists.
- **History** passes `limit`/`last_id` for cursor pagination and parses only the `sessions`/`history` list.
- The two consumers therefore read **disjoint slices** of one response and can evolve independently as long as the top-level keys remain stable.
- Auth source differs: History uses `FacultyService.canonicalId` (the app-standard v4.0 identity, `faculty_service.dart:90`); Analytics reads `FirebaseAuth.currentUser.email` directly. Equivalent today; see `ANALYTICS_MODULE.md` A-11.

---

## 13. WebSocket Real-Time Protocol

The History module opens **no WebSocket channels**; it is strictly pull-based REST. Sessions refresh only by re-entering the screen, pull-to-refresh, or tapping "Load more". There is no live-session subscription feeding this list (the app's real-time surface is `RealtimeAttendancePage` via the My Class tab; `AttendanceService`'s "WebSocket" doc-comment is unrelated to this module — see `ANALYTICS_MODULE.md` §12/A-1).

---

## 14. Navigation Map

```
DashboardScreen Home tab
   └─ QuickActionsSection "History" tile (dashboard_sections.dart:141–143)
        └─ Navigator.push(HistoryScreen)           ← ONLY entry point
             └─ AppBar back ──► Navigator.pop

⚠ Dead entry: per HOME_MODULE.md §9.3 (lines 171, 539–540, 1356),
  QuickActionsSection is imported but NOT rendered in the current Home
  widget tree (legacy/dead UI). Hence HistoryScreen has no live
  navigation path in the running app (A-1).
```

Related, **not** this module:
- `AnalyticsScreen` ("Insights" tile, `dashboard_sections.dart:145–147`) — same endpoint, sibling screen.
- `AttendanceHistoryScreen` (`my_class/attendance_history_screen.dart`) — student-scoped per-student history, reached via `StudentProfileScreen` (my_class/student_profile_screen.dart:411).

Route is an anonymous `MaterialPageRoute`. No deep link, no route name, no tab.

---

## 15. Sequence Diagrams

### 15.1 Initial load

```
Navigator.push(HistoryScreen)
   └─ initState → _fetchPage()
        ├─ setState: _isLoading=true; _allSessionData.clear(); _lastSessionId=null
        ├─ facultyEmail = FacultyService.canonicalId      (no null guard — A-5)
        ├─ idToken = FirebaseAuth.currentUser?.getIdToken()
        │    └─ null → silent return → spinner stuck (A-2)
        ├─ dio.get(...summary?limit=20, Bearer idToken, 5 s timeouts)
        │    ├─ 200 && data != null → sessionsRaw = data['sessions'] ?? data['history'] ?? []
        │    │    └─ append; _hasMore = len >= 20; _lastSessionId = last['session_id'] ?? last['id']
        │    └─ non-200 / null → silent return → spinner stuck (A-2)
        └─ catch(e) → debugPrint; _isLoading=false; _isLoadingMore=false → empty state
   └─ build: body = _isLoading ? spinner
              : rows.empty ? "No session history found."
              : RefreshIndicator(ListView.builder(rows + footer))
```

### 15.2 Load more (pagination)

```
List bottom → _buildLoadMoreButton "Load more" tap
   └─ _fetchPage(loadMore: true)
        ├─ guard: _isLoadingMore || !_hasMore → return
        ├─ _isLoadingMore = true  → footer spinner
        ├─ dio.get(...summary?limit=20&last_id=$_lastSessionId)
        ├─ append next 20 rows; _hasMore = len >= 20
        │    └─ _lastSessionId = last row cursor  (advances)
        └─ _isLoadingMore = false
   └─ footer: _hasMore ? ("Load more" | spinner) : removed
```

### 15.3 Search (as designed vs. current behavior)

```
User types in search field
   └─ Field has NO controller / onChanged (history_screen.dart:104–114)
        └─ nothing fires; _allSessionData never filtered (A-3)

Design intent (not implemented):
   onChanged → local filter of _allSessionData → setState → list re-renders
```

---

## 16. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| `idToken == null` (no Firebase user) | Silent `return` in `_fetchPage` — **`_isLoading` stays true, spinner forever** (A-2) |
| Non-200 status / null body | Silent `return` — same infinite-spinner defect (A-2) |
| `response.data` not a `Map` (e.g. String) | Cast throws inside `try` → `catch` → `debugPrint` → flags cleared → empty state |
| Network error / timeout | `catch` → `debugPrint("❌ HistoryScreen error: ...")` (console only) → flags cleared → **empty state with no message**; `RetryInterceptor` (max 2 retries, backoff) already retried before this catch (A-10) |
| `sessions` and `history` both absent | `?? []` → empty state "No session history found." |
| `canonicalId == null` (profile not hydrated) | `"$facultyEmail"` interpolates the literal `null` → `.../faculty/null/summary` → 4xx → catch → empty state (A-5) |
| Page exactly `_pageSize` long | `_hasMore = true` even on a true final page → one wasted follow-up request that returns fewer rows and self-corrects (A-7) |
| Malformed row / wrong key types | Stringly-typed lookups default to `'Unknown Course'`/`'TBD'`/`'Unknown Date'`/`0`; a non-parseable date yields the fallbacks (A-6) |
| Re-entrancy | Load-more is single-flight via `_isLoadingMore`; refresh (`_fetchPage()`) vs load-more are **not** serialized against each other |
| 401 / 403 | `AuthInterceptor.onError` (auth_interceptor.dart:76–151) translates to token refresh + retry, or `ForceLogoutService` (session revoked / device mismatch / account blocked) — applies to this endpoint too |

---

## 17. Performance Engineering

- **Single shared endpoint**: exactly one REST call per page; no dedicated history API, no redundant analytics download (only the session slice is parsed).
- **Fixed page size** (20 rows) bounds each payload and keeps list build cost low; `ListView.builder` is lazy.
- **Incremental append**: `_allSessionData.addAll(...)` + one `setState` per page — no list rebuild of the full log.
- **No persistence**: nothing cached in Hive/`SharedPreferences`; every screen entry is a cold first-page fetch. No offline story (acceptable for a list; noted in A-2/A-10).
- **Retry cost**: `RetryInterceptor` may add ~2 s + 4 s of backoff before a failing request surfaces to the screen's `catch`.
- **Scope**: the module is a single short-lived screen; no timers, streams, or background work. The decorative search field adds negligible cost (it renders once, no controller).

---

## 18. Security

- **Identity**: `facultyEmail` comes from `FacultyService.canonicalId` (the verified auth profile email, `faculty_service.dart:90`), **not** user input — safe for URL interpolation. However it is **not null-guarded** (A-5).
- **Transport**: requests ride `ApiClient().dio` — TLS, SHA-256 cert pinning (`api_client.dart:57–93`), `AuthInterceptor` Bearer injection, `SecurityInterceptor` device headers, debug-only `LogInterceptor`.
- **Redundant auth header**: the screen sends `'Authorization': 'Bearer $idToken'` explicitly even though `AuthInterceptor` already injects it (auth_interceptor.dart:32–33). Harmless but duplicative; a force-refreshed token by the interceptor would override the explicit header, so the explicit one is at risk of staleness (A-9).
- **Session handling**: a 401/403 from this endpoint is treated as a security signal — `AuthInterceptor` triggers token refresh + retry or a `ForceLogoutService` hard logout (session revoked / device mismatch / account blocked).
- **PII posture**: the session list exposes subject names, rooms, times, and present counts — aggregate session metadata, no student-level PII on this screen.

---

## 19. Dependencies Used

| Package | Where used |
|---|---|
| `provider` | `context.read<ApiClient>()` (provider-registered at `main.dart:160`) |
| `dio` | summary request via `ApiClient` (5 s overrides) |
| `firebase_auth` | `FirebaseAuth.instance.currentUser` + `getIdToken()` |
| `intl` | `DateFormat('dd MMM yyyy')` / `DateFormat('hh:mm a')` for session cards |
| `flutter/material` | layout, `RefreshIndicator`, `ListView.builder`, `TextField` |

No `hive`, no image packages, no charts — the module is intentionally minimal (the chart machinery lives in the Analytics sibling).

---

## 20. File Inventory

> Line counts = non-blank lines (`Measure-Object -Line`), per repo convention.

### 20.1 History feature — `lib/Presentation/Features/History/`

| File | LOC | Role |
|---|---|---|
| `history_screen.dart` | 229 | The entire module: search field + paginated session list + footer |

### 20.2 Supporting surfaces & data layer

| File | LOC | Role |
|---|---|---|
| `lib/Presentation/Features/Faculty/Components/dashboard_sections.dart` | 186 | `QuickActionsSection` "History" tile — **the only push site** (lines 141–143), currently legacy/unwired (A-1) |
| `lib/Presentation/Features/Analytics/analytics_screen.dart` | 219 | Co-consumer of the shared summary endpoint (trend/perf slice) |
| `lib/Services/faculty_service.dart` | 480 | `canonicalId` source (`profile.value?.email`, line 90) |
| `lib/Core/Network/api_client.dart` | 110 | Dio client, interceptors, cert pinning, base-URL resolution |
| `lib/Core/Network/Interceptors/auth_interceptor.dart` | 175 | Bearer injection + 401/403 force-logout translation |

---

## 21. Appendix A — Known Design Notes & Technical Debt

### A-1. No live navigation entry point — the only push is from dead UI (HIGH)

The sole `Navigator.push(HistoryScreen)` is inside `QuickActionsSection` (`dashboard_sections.dart:141–143`), which is **imported but never rendered** in the current Home tree (`HOME_MODULE.md` §9.3, lines 171 / 539–540 / 1356). The History screen is therefore unreachable in the running app. Either re-wire the quick-action grid or add a reachable entry (drawer item, Home header, or a route).

### A-2. Silent early-returns leave an infinite spinner (HIGH)

`_fetchPage` returns **without clearing `_isLoading`** when `idToken == null` (history_screen.dart:45) or when the response is non-200/null (history_screen.dart:60). In both cases the body stays on the full-screen `CircularProgressIndicator` forever. Every failure path must clear `_isLoading` before returning.

### A-3. Search field is non-functional (MEDIUM)

The `TextField` (history_screen.dart:102–116) has **no `TextEditingController`, no `onChanged`/`onSubmitted`, and no filtering** of `_allSessionData`. It is decorative; users can type but nothing happens. Either implement client-side filtering over the loaded pages, wire a server-side search param, or remove the field.

### A-4. Session cards are not tappable — no detail navigation (MEDIUM, product)

`_buildHistoryItem` renders plain `Container`s with no `onTap`; `history_screen.dart` has zero `Navigator.push`. There is no per-session detail (student roster, marked-by, verification data) or export/report action. The related per-student `AttendanceHistoryScreen` (My Class) is a separate, student-scoped screen and does not compensate.

### A-5. No null guard on `canonicalId` (MEDIUM)

`facultyEmail = FacultyService.canonicalId` (history_screen.dart:42) is interpolated into the URL unguarded. If the profile isn't hydrated yet, the request targets `.../analytics/faculty/null/summary`, guaranteeing a 4xx that degrades to the (silent) empty state. Guard against null alongside the `idToken` check.

### A-6. Stringly-typed session parsing (LOW)

Session rows are raw `Map<String, dynamic>` read via `data['date'] ?? data['timestamp']`, `data['present_count'] ?? 0`, `data['session_id'] ?? data['id']`, etc. No DTO, no key normalization, no type coercion; `present_count` as a non-numeric value would interpolate oddly, and a wrong `id` type would flow straight into the cursor. `ANALYTICS_MODULE.md` A-4 flags the same anti-pattern on the sibling screen.

### A-7. Final-page heuristic can waste one request (LOW)

`_hasMore = sessionsRaw.length >= _pageSize` (history_screen.dart:68). If the true last page happens to contain exactly 20 rows, the footer appears once more, issuing a follow-up request that returns fewer rows and self-corrects. Harmless but avoidable (e.g., server `has_more` flag, or checking the returned count strictly).

### A-8. Inconsistent timeout posture (LOW)

History overrides the client's 15 s defaults with **5 s** send/receive (history_screen.dart:55–56) while `AnalyticsScreen` uses **10 s on the same endpoint**. Mirrors `ANALYTICS_MODULE.md` A-9 — unify the client-level timeout strategy.

### A-9. Manual `Authorization` header duplicates the interceptor (LOW)

`Options(headers: {'Authorization': 'Bearer $idToken'})` (history_screen.dart:53–57) is redundant — `AuthInterceptor.onRequest` already injects a (possibly fresher) Bearer token. The explicit header can also carry a stale token if auth state changed between `getIdToken()` and interceptor execution. `AnalyticsScreen` relies on the interceptor alone; History should do the same.

### A-10. Minimal error/empty experience (LOW)

Every failure path (except the A-2 early returns) collapses to the "No session history found." empty state — there is no error message, no differentiation between "no data" and "request failed", and no explicit retry button (pull-to-refresh is the only recovery). Consider an error state with a Retry action.

### A-11. Base-URL / doc spelling drift (LOW)

Docs and the task reference `https://api-dev.balaseetharamanjaneya.com`, while the code default is `https://api-dev.balaseetharamanjaneyulu.com` (`api_client.dart:19`, `.env.example`) and `PROFILE_MODULE.md` uses `https://api-dev.balaseetharamanjaneyula.com`. The committed `.env` additionally points `API_BASE_URL` at the production host `https://api.intelliattend.app`. Standardize the documented base URL and verify what CI/dev actually resolves.

---

*End of History Module technical documentation. Companion: `ANALYTICS_MODULE.md`, `HOME_MODULE.md`, `PROFILE_MODULE.md`.*
