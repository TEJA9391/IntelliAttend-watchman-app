# IntelliAttend Faculty — Reports Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Reports ("Advanced Reports" — Analytics, Eligibility & Insights)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/ANALYTICS_MODULE.md`, `docs/technical/MYCLASS_MODULE.md`, `docs/technical/PROFILE_MODULE.md`, `docs/technical/HOME_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`ReportsScreen` — the Section Hub](#5-reportsscreen--the-section-hub)
6. [`ReportsController` — State, Caching & Derived Data](#6-reportscontroller--state-caching--derived-data)
7. [Overview / KPI Cards](#7-overview--kpi-cards)
8. [Chart Components](#8-chart-components)
9. [Department Performance, Recent Reports & Export Stats](#9-department-performance-recent-reports--export-stats)
10. [The Orphaned "Tab" Components](#10-the-orphaned-tab-components)
11. [`report_helper_widgets` — Orphaned Helpers & Retrospective Correction](#11-report_helper_widgets--orphaned-helpers--retrospective-correction)
12. [Export Pipeline (CSV / PDF / Excel)](#12-export-pipeline-csv--pdf--excel)
13. [Data Models & DTOs](#13-data-models--dtos)
14. [Backend API Reference](#14-backend-api-reference)
15. [WebSocket Real-Time Protocol](#15-websocket-real-time-protocol)
16. [Navigation Map](#16-navigation-map)
17. [Sequence Diagrams](#17-sequence-diagrams)
18. [Error Handling & Edge Cases](#18-error-handling--edge-cases)
19. [Performance Engineering](#19-performance-engineering)
20. [Security](#20-security)
21. [Dependencies Used](#21-dependencies-used)
22. [File Inventory](#22-file-inventory)
23. [Appendix A — Known Design Notes & Technical Debt](#23-appendix-a--known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **Reports Module** is the "Advanced Reports" surface of the faculty app: a single push screen (`ReportsScreen`) that renders course-scoped attendance analytics, eligibility health, defaulters, session history, and a multi-format export pipeline (CSV/PDF/Excel). It is reached **only** from the navigation drawer (`AppDrawer` → ACADEMICS → "Advanced Reports").

Despite its label and a folder full of `*Tab` components, the live screen is **not a tabbed UI**: it is one vertically-scrolling `CustomScrollView` composed of stacked section widgets (KPI cards, charts, department performance, recent reports, export statistics). The seven tab components and the helper-widget file that implement a tabbed iteration are **orphaned dead code** (see Appendix A-1/A-2).

### 1.2 Business Goal

- Give faculty a **course-switchable analytics hub**: pick a course, see average attendance, eligible/defaulter counts, a weekly trend, and a day-of-week breakdown.
- Make **eligibility** (<75 % threshold) legible: defaulters and at-risk students are derivable from the same roster that powers My Class, because the module shares the `EligibilityService.students` notifier and the `eligibility_students_<courseId>` Hive cache.
- Provide a **one-tap export** of the current filtered view in three formats (CSV, PDF, Excel) with a faculty/course/semester/period header block.
- Work **offline-first**: every successful fetch is cached in Hive; failures degrade to cached data (or to fabricated demo data, see A-3).

### 1.3 Problem Statement

- Attendance data lives in the `/api/v1/faculty/sync` manifest (rosters + adhoc sessions), not in a dedicated reports endpoint; the module must extract and reshape that payload for one course.
- Faculty need a **per-course, per-period** view (semester + month/week/day filters) without re-downloading all session logs.
- Report files must be generated entirely on-device in multiple formats with consistent headers.

### 1.4 Solution

- One `ReportsController` (`ChangeNotifier`, created per screen instance) owns all state: course selection, semester/month filters (persisted in `SharedPreferences`), raw `students`/`sessions`/`stats`, and a battery of **memoized derived getters** invalidated by a `_filtersDirty` flag.
- `ReportsService.fetchReports(courseId)` performs one `GET /api/v1/faculty/sync` per course (15 s timeouts), extracts the roster for the requested course (by `course_id` or cohort code), persists it to `eligibility_students_<courseId>`, caches the whole result under `reports_cache_<courseId>`, and falls back to cache on any failure.
- `ReportsScreen` renders via a single `ListenableBuilder`; each major section is wrapped in `RepaintBoundary`; charts are keyed by filter state so they rebuild only when filters change.
- Exports are generated entirely client-side (`pdf`, `excel`, raw CSV) into `getApplicationDocumentsDirectory()` and opened via `open_filex`.

### 1.5 Target Users

- **Faculty members** — the only audience. Reached exclusively via the app drawer; never a tab, never a named route.

### 1.6 Faculty Workflow (Reports-driven)

```
AppDrawer → ACADEMICS → "Advanced Reports"
   ├─ AppBar course picker (filter_list)  → bottom sheet: Select Course
   ├─ Date-range header → Semester sheet | Month sheet (Today/Week/Month/LastMonth)
   ├─ Overview KPI cards (Avg Attendance / Eligible / Defaulters)
   ├─ Attendance Analytics chart (Daily | Weekly | Monthly segmented)
   ├─ Report Distribution doughnut
   ├─ Department Performance bars
   ├─ Recent Reports (session list)
   ├─ Export Statistics grid
   └─ AppBar download icon → PDF | Excel | CSV → documents dir → "Open"
```

---

## 2. Layered Architecture & Data Flow

```
┌────────────────────────────────────────────────────────────────────────────┐
│  PRESENTATION  lib/Presentation/Features/Reports/                          │
│  ReportsScreen (StatefulWidget, push route)                                │
│   └─ CustomScrollView (ListenableBuilder on controller)                    │
│        ├─ _buildDateRangeHeader    (semester + month filter chips)         │
│        ├─ _buildKPICards           (ReportKpiCard ×3 + sparkline)          │
│        ├─ _buildChartsRow          (AttendanceChart + ReportDistribution)  │
│        ├─ _buildDepartmentPerformance (DepartmentPerformance)              │
│        ├─ _buildBottomRow          (RecentReportsList)                     │
│        └─ _buildExportStats        (ExportStatsCard)                       │
└──────────────┬─────────────────────────────────────────────────────────────┘
               │ notifyListeners() / getters (memoized)                      │
┌──────────────▼─────────────────────────────────────────────────────────────┐
│  CONTROLLER  ReportsController (ChangeNotifier, 1-per-screen)              │
│   fields: _students/_sessions/_stats, _selectedCourseId,                   │
│           _selectedSemester, _monthFilter, _isOffline, _lastSyncTime       │
│   caches: _cachedFilteredSessions, _cachedSparklineData, _cachedWeeklyTrend│
│           _cachedOverview, _cachedWeeklyChartData, _cachedRecentReports,   │
│           _cachedReportDistribution, _cachedDepartmentPerformance,         │
│           _cachedAtRiskStudents, _cachedTopPerformers, _cachedAbsentStreaks│
└──────┬──────────────────────────────────────────────────┬──────────────────┘
       │                                                  │ writes/reads
┌──────▼───────────────┐                     ┌────────────▼──────────────────┐
│  SERVICES            │                     │  PERSISTENCE (Hive/SHPrefs)    │
│  ReportsService()    │                     │  academicBox:                  │
│   └─ ApiClient().dio │                     │   'reports_cache_<courseId>'  │
│      GET /faculty/sync│                    │   'reports_last_sync'          │
│  EligibilityService  │                     │   'eligibility_students_<cId>' │
│   └─ students ValueNotifier                │  prefs: 'reports_selected_     │
│      threshold = 0.75                      │    semester', 'reports_month_  │
│                                            │    filter'                     │
└──────────────────────┘                     └────────────────────────────────┘
                 │ HTTPS (JWT, cert pinning, retry ×2, 15s timeouts)
                 │  GET /api/v1/faculty/sync   (the manifest: rosters,
                 │                              adhoc_sessions, cohorts)
```

### 2.1 Data flow on screen load

```
ReportsScreen.initState
   └─ ReportsController()                       [created; disposed in dispose]
        ├─ _loadPersistedFilters()  → prefs: semester id + month filter index
        ├─ _loadLastSyncTime()      → academicBox 'reports_last_sync'
        └─ _init()
             ├─ FacultyService.courses.addListener(_onCoursesLoaded)
             └─ courses already non-empty?
                  └─ _onCoursesLoaded → setSelectedCourse(first course 'id')
                       → fetchReports(courseId)
                            ├─ _status=loading → notifyListeners (skeleton)
                            ├─ ReportsService.fetchReports(courseId)
                            │    └─ GET /faculty/sync (15s timeouts)
                            │         ├─ extract roster for courseId
                            │         ├─ put eligibility_students_<courseId>
                            │         ├─ computeStats() locally
                            │         └─ save cache reports_cache_<courseId>
                            ├─ students/sessions/stats assigned
                            ├─ EligibilityService.students.value = _students
                            └─ _status=success → notifyListeners
```

### 2.2 Data flow on filter change

```
User taps month filter → setMonthFilter(type)
   ├─ _monthFilter = type
   ├─ _invalidateFilters() → _filtersDirty=true; all 11 caches = null
   ├─ _persistFilters()    → prefs.setInt('reports_month_filter', index)
   └─ notifyListeners()
        └─ getters lazily recompute: filteredSessions → sparkline/overview/
             weeklyTrend/weeklyChartData/recentReports/reportDistribution
        └─ KeyedSubtree(ValueKey('${monthFilter.index}_${semester.id}'))
             forces AttendanceChart subtree to rebuild with fresh data
```

---

## 3. State Management Wiring

The module uses a single **`ChangeNotifier` controller** (`ReportsController`) consumed through **`ListenableBuilder`** — no `Provider`, no `ValueNotifier` for its own state. The one shared notifier it *writes* is `EligibilityService.students` (singleton `ValueNotifier`), the same store My Class and the eligibility gates read.

| Concern | Mechanism |
|---|---|
| All Reports state | `ReportsController extends ChangeNotifier`; screen listens via `ListenableBuilder(listenable: _controller)` |
| Course list | `FacultyService.courses.value` (static `ValueNotifier<List<Map<String,dynamic>>>`) read at picker time and observed via `addListener` in the controller (`_onCoursesLoaded`) |
| Eligibility roster | `EligibilityService.students.value = _students` (controller `reports_controller.dart:544`) |
| Course → eligibility cache | `ReportsService` writes `eligibility_students_<courseId>` to `PersistenceService.academicBox`; `EligibilityService.switchCourse` reads it (`my_class_screen.dart:244` is the other producer-side consumer) |
| Filter persistence | `SharedPreferences` keys `reports_selected_semester`, `reports_month_filter` |
| Report data cache | Hive `academicBox` keys `reports_cache_<courseId>`, `reports_last_sync` |
| HTTP | `ReportsService()` → `ApiClient().dio` (JWT bearer, cert pinning, retry interceptor) |

**Lifecycle:** the controller is created in `ReportsScreen.initState` and disposed in `dispose` (`reports_screen.dart:54–63`); the controller removes its `FacultyService.courses` listener in its own `dispose`. No leak, but every push of `ReportsScreen` re-fetches the full manifest.

---

## 4. Screen Structure — Widget Tree

```
Scaffold (bg: AppTheme.bg)
└─ CustomAppBar(title: "Reports", subtitle: "Analytics, Eligibility & Insights",
   showBackButton: false)
   ├─ action: download_rounded (teal 0.15 tile)  → _showDownloadSheet (PDF/Excel/CSV)
   └─ action: filter_list_rounded                → _showCoursePicker
└─ RefreshIndicator(onRefresh: _controller.refresh)
   └─ ListenableBuilder(_controller)
        └─ CustomScrollView(PageStorageKey 'reports_scroll')
             ├─ SliverFillRemaining skeleton        (isLoading && !hasData)
             ├─ SliverFillRemaining error state     (error != null && !hasData)
             ├─ SliverFillRemaining empty state     (!hasData && status==success)
             └─ else (always in practice — see A-4)
                  ├─ SliverToBoxAdapter offline banner   (isOffline)
                  └─ SliverPadding(SliverList, 11 children, bottom padding 120)
                       0  RepaintBoundary(_buildDateRangeHeader)  → _showMonthFilterSheet
                       2  RepaintBoundary(_buildKPICards)
                       4  RepaintBoundary(KeyedSubtree(ValueKey monthFilter+semester)
                            → _buildChartsRow)
                       6  RepaintBoundary(_buildDepartmentPerformance)
                       8  RepaintBoundary(_buildBottomRow)   → RecentReportsList
                      10  RepaintBoundary(_buildExportStats)
```

### 4.1 Bottom sheets (private widgets in `reports_screen.dart`)

| Sheet | Trigger | Contents |
|---|---|---|
| `_showDownloadSheet` | AppBar download icon | Radio rows PDF (0xFFEF4444) / Excel (0xFF22C55E) / CSV (0xFF60A5FA) → `controller.exportAsFormat(context, format)` |
| `_showSemesterSheet` → `_SemesterPickerSheet` | Date-range header left text | 60 %-height grouped list: academic years 2023–27 × semesters, Clear + Apply; calls `controller.setSemester` |
| `_showMonthFilterSheet` → `_MonthFilterSheet` | Date-range header right chip | Today / This Week / This Month / Last Month radios; calls `controller.setMonthFilter` |
| `_showCoursePicker` → `_CoursePickerSheet` | AppBar filter icon | 50 %-height course list from `FacultyService.courses`; `onSelected` → `controller.setSelectedCourse(id)` |

---

## 5. `ReportsScreen` — the Section Hub

**File:** `lib/Presentation/Features/Reports/reports_screen.dart` (1,213 non-blank LOC)

- `const ReportsScreen({Key? key})` — pure navigation target, no constructor args.
- **`initState`** creates the controller (which immediately kicks off a fetch via `_init`), **`dispose`** destroys it.
- **`_onRefresh`** → `controller.refresh()` (a thin wrapper over `fetchReports`), used by both the `RefreshIndicator` and the Retry/Refresh buttons.
- **Screen state machine** (the `if/else` chain in `build`):
  1. `isLoading && !hasData` → full-screen skeleton (`_buildSkeletonLoader` — static gray placeholder blocks, not an animated shimmer).
  2. `error != null && !hasData` → `_buildNoDataErrorState` (cloud-off icon, "Unable to load reports", Retry).
  3. `!hasData && status == success` → `_buildEmptyState` (chart emoji glyph, "No attendance reports available", Refresh).
  4. else → the live scroll (offline banner + 11 sliver children).

> Because every fetch path (dummy, cache, or success) leaves `_students`/`_sessions` non-empty and `_error` null, **branch 2 and 3 are unreachable dead code** (A-4).

- `_buildDateRangeHeader`: tappable card; left = `semesterDisplayLabel` (opens semester sheet), right = `monthFilterLabel` pill (opens month sheet).

---

## 6. `ReportsController` — State, Caching & Derived Data

**File:** `lib/Presentation/Features/Reports/reports_controller.dart` (959 non-blank LOC)

### 6.1 Enums & model

```dart
enum ReportsStatus { initial, loading, success, error }     // 'error' never set (A-4)
enum MonthFilterType { today, thisWeek, thisMonth, lastMonth }

class SemesterInfo {
  final int academicYear; final int semesterNumber; final String label;
  final DateTime startDate; final DateTime endDate;
  String get id => '$academicYear|$semesterNumber';   // '2024|2'
}
```

- `_semesterGroups` is a **static** list of 8 semesters across academic years 2023→2027: Sem 1–2 (Jul–Dec / Jan–Jun) per year, hard-coded horizon 2023–2027 (A-17).
- `_dummyStudents` (10 entries, STU001–STU010, attended/15) and `_dummySessions` (5 ISO-dated sessions, 70–92 %).

### 6.2 Raw state

| Field | Notes |
|---|---|
| `_status` | `initial` → `loading` → `success` (never `error`) |
| `_error` | never assigned a non-null value (A-4) |
| `_isOffline` | `true` only when `fetchReports` throws and dummy fallback is used |
| `_selectedCourseId` | set from `FacultyService.courses.value.first['id']` once courses load |
| `_selectedSemester` / `_monthFilter` | persisted; `_monthFilter` defaults to `thisMonth` |
| `_students`, `_sessions`, `_stats` | raw payload slices (`stats` shape in §13) |
| `_lastSyncTime` | from Hive `reports_last_sync` → `lastSyncDisplay` getter ("Just now / Nm ago / Nh ago / date") |

### 6.3 Memoized derived data (the `_filtersDirty` cache)

Eleven lazy getters compute once per filter generation and are invalidated together by `_invalidateFilters()`:

| Getter | Computation |
|---|---|
| `filteredSessions` | `_sessions` filtered by semester window then by `MonthFilterType` date range (see 6.4) |
| `kpiSparklineData` | 7 points sampled evenly across time-sorted filtered sessions (`attendance_percentage/100`); `List.filled(7, 0.5)` if <2 sessions |
| `overview` | `overall_average` = mean of filtered sessions' `attendance_percentage`; `total_students`/`eligible_count`/`defaulter_count`/`at_risk_count` from `_stats`; `total_sessions` = filtered length. Returns `{}` if `_stats` empty |
| `weeklyTrend` | buckets filtered sessions by `(now - date).inDays ~/ 7` (weeks 0–11), label `W{index+1}`, mean `value` |
| `weeklyChartData` | aggregates filtered sessions **by weekday name** (Mon–Sun): `present`/`absent`/`percentage` per day |
| `atRiskStudents` | `_students` where `attended/total < 0.75`; adds `is_critical = pct < 0.50` |
| `topPerformers` | `_students` sorted by `attended/total` desc, `take(10)` |
| `absentStreaks` | `_students` where `max_absent_streak >= 3`, sorted desc |
| `reportDistribution` | doughnut slices `[Eligible, At Risk, Defaulters, Sessions]` with fixed colors `0xFF22C55E/0xFFFBBF24/0xFFEF4444/0xFF60A5FA` |
| `departmentPerformance` | maps `FacultyService.courses.value` → `{name, percentage: c['avg_attendance'] ?? 0, sessions: c['session_count'] ?? 0}` — see A-7 |
| `recentReports` | `filteredSessions` sorted by date desc, `take(10)` |

**Cache discipline:** the first getter access after a filter change recomputes and stashes; subsequent reads hit the cache until `_invalidateFilters()` (called by `setSelectedCourse`, `setSemester`, `setMonthFilter`, `fetchReports`). `overview`/`reportDistribution`/`departmentPerformance`/`recentReports`/`weeklyChartData` additionally short-circuit when `_filtersDirty == false` and their cache is non-null.

### 6.4 Time-period filter logic (`_computeFilteredSessions`)

- **Semester filter first:** keeps sessions whose parsed `date` falls in `[startDate, endDate]`.
- **Then month filter** (`rangeStart`/`rangeEnd` as `DateTime`):
  - `today` → today 00:00–23:59:59
  - `thisWeek` → Monday-of-this-week 00:00 → now (end of today)
  - `thisMonth` → 1st-of-month → now
  - `lastMonth` → 1st of previous month → last day of previous month 23:59:59
- Sessions without a parseable `date` are silently dropped from all filtered views.

### 6.5 Fetch (`fetchReports`, `reports_controller.dart:515–565`)

1. `_selectedCourseId == null` → **dummy data** path: `_dummyStudents` + `_dummySessions` + `_service.computeStats`, `_status = success`, `_isOffline` untouched (A-3/A-4).
2. else → `_status = loading`, call `ReportsService.fetchReports(courseId)`.
3. On success: assign `result['students']/'sessions'/'stats']`; if both empty, **substitute dummy data**; set `EligibilityService.students.value = _students`; `_isOffline = false`; reload `_lastSyncTime`.
4. On error: **dummy data + `_isOffline = true` + `_status = success`** (the exception is swallowed into a `debugPrint`) — the user sees fabricated data with only an amber offline banner (A-3).

`setSelectedCourse` guards against redundant refetch (`if (_selectedCourseId == courseId && _status == success) return`).

### 6.6 Export header & rows

- `_getExportHeader`: text block with faculty name/department (from `FacultyService.profile`), course, `semesterDisplayLabel`, `monthFilterLabel`, and generation timestamp.
- `_getStudentCsvRows`: `Student ID,Name,Roll Number,Attended,Total,Percentage,Status` — status `Eligible` iff `attended/total >= 0.75` (raw, unescaped CSV — A-11).
- `_getSessionCsvRows` / `_getSummaryCsvRows`: filtered-session rows + a `Summary` block mirroring `overview`.
- `exportAllReports` is misnamed — it forwards to `exportAsFormat(context, 'csv')`.

---

## 7. Overview / KPI Cards

**File:** `report_kpi_card.dart` (207 LOC) + `_buildKPICards` (`reports_screen.dart:443–510`)

- 2-column `GridView` with three `ReportKpiCard`s (childAspectRatio tuned by card height 140/160 px):
  1. **Avg Attendance** — teal, `analytics_rounded`, value = `overview['overall_average']`.
  2. **Eligible Students** — `0xFF22C55E`, `check_circle_rounded`, value = `_stats['eligible_count']`.
  3. **Defaulters** — `errorRed`, `warning_rounded`, value = `_stats['defaulter_count']`.
- Each card carries a **hard-coded `change` delta** ("vs last month"): `+2.3`, `+4.1`, `-1.8` — no comparison logic exists (A-5).
- Entry animation: 500 ms `FadeTransition` + `SlideTransition`, staggered via `animationDelayMs` (100/200/300) with a `Future.delayed` kick.
- Sparkline: `_SparklinePainter` `CustomPaint` (50×24 px) drawn over the 7-point `kpiSparklineData`, normalized by min/max/range; falls back to flat `[0.5×7]`.

---

## 8. Chart Components

All charts use `syncfusion_flutter_charts ^26.1.35`.

### 8.1 `AttendanceChart` (`attendance_chart.dart`, 381 LOC) — "Attendance Analytics"

Stateful, with a **Daily / Weekly / Monthly** segmented control (`_selectedFilter`). Data is cached in state and invalidated via `didUpdateWidget` when the source list identity changes (`identical(...)`).

| Filter | Series | Data source |
|---|---|---|
| Daily | two `ColumnSeries` (Present teal / Absent `0xFFEF4444` 0.7α), legend, tooltip `point.x\nPresent: point.y` | `weeklyChartData` (per-weekday present/absent counts) |
| Weekly | `SplineAreaSeries` (teal 0.15 fill, border 2.5), markers, tooltip `point.x : point.y%` | `weeklyTrend` (W1…W12 mean %) |
| Monthly | `LineSeries` (teal, markers) | **reuses `weeklyTrend`** — identical to Weekly (A-9) |

- Header shows a teal "LIVE" pill — decorative; no live data is streamed (see §15).
- Empty data → `_buildEmptyState` ("No attendance data yet").
- Chart height fixed at 200 px inside a `RepaintBoundary`; card is wrapped in another `RepaintBoundary`.

### 8.2 `ReportDistributionChart` (`report_distribution_chart.dart`, 130 LOC)

- `DoughnutSeries` (inner radius 68 %, `cornerStyle` bothCurve, 800 ms animation, 200 ms delay) over `reportDistribution`; `pointColorMapper` reads the `Color` stored in each slice map.
- Center overlay shows the summed slice total; `Wrap` legend below (name + value).
- Empty distribution → "No data available" placeholder inside the 180 px box.

### 8.3 `DepartmentPerformance` (`department_performance.dart`, 170 LOC)

- 1,200 ms entrance `AnimationController`; each row's progress bar is an `AnimatedBuilder` windowed across `[delay, delay+0.7]` with `Curves.easeOutCubic`.
- Row: name, `"$sessions sessions"`, `%`; bar color `>=75` teal / `>=60` amber / else red.
- Empty list → "No department data". Given the data source (§6.3, A-7) the bars are effectively always 0 %.

---

## 9. Department Performance, Recent Reports & Export Stats

### 9.1 `RecentReportsList` (`recent_reports_list.dart`, 202 LOC)

- "Recent Reports" header + chevron; subtitle "Latest session attendance records".
- Rows from `recentReports` (top-10 filtered sessions): `course_code`, formatted date, `present/total`, `%` (colored `>=75` teal / `>=60` amber / red), status pill via `_getStatusColor`/`_getStatusLabel` (`completed`→Done green, `cancelled`→red, `ongoing`→amber, default Active teal).
- **The rows are adhoc sessions, not generated reports** — there is no export-history record (A-8).
- Empty → "No reports yet".

### 9.2 `ExportStatsCard` (`export_stats_card.dart`, 138 LOC)

- 2×2 grid: Total Students (blue), Sessions Held (teal), Eligible (green), At Risk (amber) — all from `overview`.
- Pure display; the "Export" name refers to the surrounding context, the card itself has no actions.

---

## 10. The Orphaned "Tab" Components

The folder `Components/` contains **seven `*Tab` widgets that no other file imports** (verified repo-wide: each class appears only inside its own file). Together they implement a tabbed iteration of the reports screen that was superseded by the single-scroll layout. They are dead code (~1,611 non-blank LOC).

| File | LOC | Contents |
|---|---|---|
| `overview_tab.dart` | 281 | `OverviewTab` — doughnut gauge (`SfCircularChart` DoughnutSeries avg/100-avg, innerRadius 72 %), quick stats grid, course-wise cards, day-of-week columns. Reads `overview['courses']` (never produced by the controller — always falls back to `FacultyService.courses`) |
| `analytics_tab.dart` | 429 | `AnalyticsTab` — attendance overview card, per-student `LineSeries` (top-15 performers), `SplineAreaSeries` weekly trend, summary row, "Quick Actions" export buttons |
| `defaulter_tab.dart` | 281 | `DefaulterTab` — alert header, chips All/Critical(<60 %)/At-Risk(60–75 %), defaulter cards with **fake action buttons** (Warn / Call Parent / Meeting — only SnackBars) |
| `eligibility_tab.dart` | 216 | `EligibilityTab` — circular-progress header, chips All/Above-90 %/75–90 %, eligible student cards |
| `students_tab.dart` | 199 | `StudentsTab` — chips All At Risk / Critical / Top Performers / Streak |
| `sessions_tab.dart` | 113 | `SessionsTab` — `sessionHistory` card list |
| `actions_tab.dart` | 92 | `ActionsTab` — Send Warnings (SnackBar only), Export CSV, Export PDF (`exportAllReports` → CSV), Share Report (`share_plus` text) |

These tabs are the likely origin of the "tabs (Overview/Analytics/Defaulters/Eligibility/Students/Sessions/Actions)" description. **They are not wired to any `TabController` or route** — see A-1.

---

## 11. `report_helper_widgets` — Orphaned Helpers & Retrospective Correction

**File:** `report_helper_widgets.dart` (507 LOC) — **entirely orphaned** (no other file imports it; repo-wide grep finds only its own declarations, A-2).

- Pure helper builders (never referenced): `buildLiveBadge`, `buildPercentageBadge`, `buildProgressBar`, `buildBatchHeader`, `buildStudentTile` (eligibility-colored tiles with "Need N cls" chips).
- `showRetrospectiveCorrectionDialog` + `_RetrospectiveDialogContent` — a **fully functional but unreachable** feature:
  1. On open, `_fetchSessions()` calls `GET /api/v1/analytics/subject/{courseId}/attendance` (5 s timeouts, explicit `Authorization: Bearer <idToken>` from `FirebaseAuth`), parses `data['sessions']` into `{id, label}` dropdown items.
  2. Dialog offers session dropdown, reason dropdown (`late_arrival`/`missed_scan`/`system_error`/`other`), and free-text notes.
  3. "MARK PRESENT" posts to `AttendanceRepository.markAttendanceCorrection` → `POST /api/v1/faculty/attendance/correction` (`attendance_repository.dart:165–194`); 409 → `ALREADY_MARKED:<source>` surfaced as "Already marked present by …".
- This is the module's **only** consumer of the subject-analytics endpoint and the only path that writes a retrospective correction — both live-but-unreachable. The empty-sessions copy says "…in Firestore", implying stale copy from an earlier backend design.

---

## 12. Export Pipeline (CSV / PDF / Excel)

**Entry:** AppBar download icon → `_showDownloadSheet` → `controller.exportAsFormat(context, 'pdf'|'excel'|'csv')` (`reports_controller.dart:637–732`).

### 12.1 Shared flow

```
exportAsFormat(format)
   ├─ _isExporting = true; notifyListeners
   ├─ showDialog "Generating Report…" (non-dismissible, CircularProgressIndicator)
   ├─ if Android: Permission.manageExternalStorage → request if not granted   (A-10)
   ├─ dir = getApplicationDocumentsDirectory()
   ├─ filename = 'attendance_<courseName sanitized>_<yyyyMMdd_HHmmss>.<ext>'
   ├─ switch format → _exportCSV | _exportPDF | _exportExcel
   ├─ pop dialog; SnackBar "Report downloaded successfully" + action "Open"
   │    → OpenFilex.open(file.path)
   └─ catch → pop dialog; SnackBar "Export failed: $e" (AppTheme.errorRed)
   finally → _isExporting = false; notifyListeners
```

All three formats are written to **application documents** and opened locally; no upload, no share_plus in the live path (share exists only in the orphaned `ActionsTab`).

### 12.2 CSV (`_exportCSV`)

Header block + Summary rows + student rows + filtered-session rows, concatenated as a single `StringBuffer` written with `writeAsString`. **Values are not CSV-escaped** (A-11).

### 12.3 PDF (`_exportPDF`)

`pw.MultiPage` A4, 32 pt margins, header (title + generated timestamp + teal divider) and footer ("IntelliAttend • Confidential") on every page. Body: info rows (Faculty/Department/Course/Semester/Period), a grey `Summary` container with 5 stat boxes, then `TableHelper.fromTextArray` for **all students** (ID/Name/Roll/Att/Total/%/Status) and filtered sessions (Date/%/Students). Cell font 8–9 pt; status recomputed at render.

### 12.4 Excel (`_exportExcel`)

Three sheets via `excel` package:
- **Summary** — header rows, report details (Faculty/Dept/Course/Semester/Period/Generated), and a summary block (Total Students/Avg Attendance/Eligible/Defaulters/At Risk). `_excelStyleHeader` only writes text into a cell — no real cell styling despite the name.
- **Students** — header row + one row per student.
- **Sessions** — header row + filtered sessions.
`excel.save()` bytes → `writeAsBytes` to `attendance_<course>_<ts>.xlsx`.

---

## 13. Data Models & DTOs

The module defines **no typed DTOs**; everything is `Map<String, dynamic>` with stringly-typed keys (same posture as `AnalyticsScreen`, A-12).

### 13.1 Student record shape (`_students` items)

| Key | Type | Source |
|---|---|---|
| `id` | String | manifest roster entry (also `roll_number`, `name`, `attended`, `total`) |
| `name` | String | roster |
| `roll_number` | String | roster |
| `attended` / `total` | num | roster — the only inputs to every percentage/eligibility calculation |
| `max_absent_streak` | int? | optional; drives `absentStreaks` (≥3) |

### 13.2 Session record shape (`_sessions` items)

`date` (ISO string), `attendance_percentage` (num), `total_students` (num), optional `course_code`/`section_id`/`status`/`present`. Filtering is exclusively by the parsed `date`.

### 13.3 Stats shape (`_stats` — computed locally by `ReportsService.computeStats`)

```
{ total_students, overall_average (mean of per-student %), eligible_count,
  defaulter_count, at_risk_count, total_sessions, weekly_trend }
```

**Band logic (locally computed, server not involved):** `pct >= 0.75` eligible; `0.60 <= pct < 0.75` at-risk; `pct < 0.60` defaulter. Note this differs from the eligibility-gate split elsewhere (`EligibilityService` uses a strict 0.75; `atRiskStudents` uses `<0.75` + `is_critical < 0.50`) — A-6.

### 13.4 `SemesterInfo`

`{academicYear, semesterNumber, label, startDate, endDate}` + derived `id = '$year|$sem', shortYear, displayLabel ('Sem 2 • 2024-25')`.

### 13.5 Controller `_students` vs `EligibilityService.students`

`ReportsController._students` is the module's private copy; on every successful/dummy fetch the controller also publishes it to `EligibilityService.students.value` (`reports_controller.dart:544`), so My Class eligibility screens that read the notifier see the last-fetched Reports roster. `EligibilityService.getEligibleStudents()` / `getDefaulters()` / `calculate()` are **never called anywhere** (dead API, A-12).

---

## 14. Backend API Reference

All HTTP goes through `ApiClient().dio` (JWT auth interceptor, `RetryInterceptor` ×2 on timeouts/connection errors, TLS cert pinning, LogInterceptor in debug).

**Base URL — verify before relying on either host:** `ApiClient._defaultBaseUrl = 'https://api-dev.balaseetharamanjaneyulu.com'` (`api_client.dart:19`), overridden by `.env` → `API_BASE_URL=https://api.intelliattend.app`, and further overridable via the `ApiClient(customBaseUrl:)` factory. `ANALYTICS_MODULE.md` documents yet another spelling — see A-14.

| Endpoint | Verb | Used by | Notes |
|---|---|---|---|
| `/api/v1/faculty/sync` | GET | `ReportsService.fetchReports` (reports_service.dart:21) | The **only** live endpoint of this module. 15 s send/receive timeouts. Reads `data['rosters']` (map keyed by course id / cohort id), `data['adhoc_sessions']` (list), `data['cohorts']` (to resolve `course_code` → cohort-id rosters). Same manifest that feeds `FacultyHydrationService` and `MyClassScreen` |
| `/api/v1/analytics/subject/{courseId}/attendance` | GET | `report_helper_widgets.dart:300` (**orphaned**, A-2) | Subject-analytics contract shared with `AnalyticsModule` docs §11; fetches past sessions for the retrospective-correction dialog (5 s timeouts, explicit Bearer token). Reads `data['sessions']` |
| `/api/v1/faculty/attendance/correction` | POST | `AttendanceRepository.markAttendanceCorrection` (`attendance_repository.dart:165`) | Body `{session_id, student_id, reason, notes?}`; 200/201 success; 409 → `ALREADY_MARKED:<source>`. Called from the orphaned dialog (and the live `LiveMonitorController`) |
| `/api/v1/faculty/sync` | GET | `AttendanceRepository.getSyncData` (attendance_repository.dart:198) | Sibling consumer reading `data['student_rosters']` (different key spelling than the Reports module) |

> **There is no dedicated reports/analytics/export endpoint.** The module synthesizes all statistics client-side from the sync manifest and writes files locally. Any "server-side eligibility" would require a new contract; today eligibility is purely a local computation over fetched `attended`/`total` (A-6, and cross-ref `MYCLASS_MODULE.md` A-8).

---

## 15. WebSocket Real-Time Protocol

The Reports module opens **no WebSocket channels** and subscribes to none. The teal/red "LIVE" pills on the KPI header, `AttendanceChart`, `OverviewTab`, and `AnalyticsTab` are decorative; no live count is streamed into the screen. Data is pull-based (one `GET /faculty/sync` per course selection, plus `RefreshIndicator`). The only "real-time-ish" coupling is the in-memory `EligibilityService.students` notifier, which the controller writes and My Class reads.

---

## 16. Navigation Map

```
AppDrawer (ACADEMICS → "Advanced Reports", subtitle "Analytics & Defaulters")
   └─ Navigator.push(MaterialPageRoute) ──► ReportsScreen     (app_drawer.dart:93–97)
        └─ internal bottom sheets (no routes):
             ├─ _showDownloadSheet   (PDF | Excel | CSV)
             ├─ _SemesterPickerSheet
             ├─ _MonthFilterSheet
             └─ _CoursePickerSheet
        └─ AppBar back ──► Navigator.pop

Related surfaces sharing data/contracts (NOT this module):
   AppDrawer "Attendance Manager"          ──► RealtimeAttendancePage
   MyClass hub "Export Reports"            ──► ExportReportsScreen   (QuickActions module)
   MyClass hub eligibility gates           ──► EligibilityService.switchCourse
        (reads eligibility_students_<courseId> written by ReportsService)
```

`ReportsScreen` is reachable **only** from the drawer — no named route, no deep link, no Home quick action.

---

## 17. Sequence Diagrams

### 17.1 Course load + eligibility publication

```
Drawer "Advanced Reports" tap → ReportsScreen.initState → ReportsController()
   ├─ _loadPersistedFilters()  (prefs → semester + month filter)
   └─ _init() → courses loaded? yes
        └─ setSelectedCourse(first course 'id')
             └─ fetchReports(courseId)
                  ├─ _status = loading → skeleton
                  ├─ ReportsService.fetchReports(courseId)
                  │    ├─ GET /api/v1/faculty/sync (15s timeouts)
                  │    ├─ roster = rosters[courseId] ?? rosters[cohortId(course_code)]
                  │    ├─ if roster found → academicBox.put('eligibility_students_$courseId')
                  │    ├─ sessions = adhoc_sessions
                  │    ├─ stats  = computeStats(students, sessions)   [local, 0.75/0.60 bands]
                  │    └─ academicBox.put('reports_cache_$courseId', {students,sessions,stats})
                  │          + academicBox.put('reports_last_sync', now)
                  ├─ _students/_sessions/_stats assigned
                  ├─ EligibilityService.students.value = _students     [shared notifier]
                  ├─ _status = success
                  └─ notifyListeners → section widgets render (cached getters)
```

### 17.2 Filter change (month filter)

```
Tap "This Month" chip → _MonthFilterSheet → Apply
   └─ setMonthFilter(thisMonth)
        ├─ _invalidateFilters()   (11 caches → null; _filtersDirty = true)
        ├─ prefs.setInt('reports_month_filter', index)
        └─ notifyListeners
             └─ build: KeyedSubtree(ValueKey('2_all')) changes
                  └─ filteredSessions re-filtered → overview average,
                       sparkline, weeklyTrend, weeklyChartData, recentReports
                       recompute lazily per getter; charts repaint
```

### 17.3 CSV / PDF / Excel export

```
AppBar download icon → sheet → "Download"
   └─ exportAsFormat(context, 'pdf'|'excel'|'csv')
        ├─ _isExporting = true; show "Generating Report…" dialog
        ├─ Permission.manageExternalStorage (Android) if needed        [A-10]
        ├─ dir = getApplicationDocumentsDirectory()
        ├─ prefix = 'attendance_<course>_<ts>'
        ├─ csv   → header + summary + students + sessions (raw text)
        ├─ pdf   → pw.MultiPage(A4): info rows, stat boxes, 2 tables
        └─ excel → 3 sheets (Summary / Students / Sessions)
        ├─ pop dialog; SnackBar "Report downloaded successfully"
        │    └─ "Open" → OpenFilex.open(path)
        └─ catch → "Export failed: $e" SnackBar
```

### 17.4 Defaulter drill-down (as designed in the dead tab; live screen has no drill-down)

```
DefaulterTab (orphaned) tap "Warn"/"Call Parent"/"Meeting"
   └─ HapticFeedback.lightImpact()
   └─ SnackBar "Warning sent to $name" / "Calling parent…" / "Meeting scheduled…"
        └─ NO repository call, NO navigation — cosmetic only
```

The live `ReportsScreen` has **no defaulter list at all**: defaulters appear only as a KPI count and a doughnut slice. The full defaulter drill-down lives in the orphaned tabs (A-1).

---

## 18. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| Manifest fetch fails (timeout/network/5xx) | `ReportsService` falls back to `reports_cache_<courseId>`; if no cache, rethrows → controller substitutes `_dummyStudents`/`_dummySessions`, `_isOffline=true`, `_status=success`, amber offline banner shows "Last Synced" from `reports_last_sync` (**dummy data rendered as real — A-3**) |
| No cache and network down on first launch | Dummy data + offline banner (no error state) |
| `_selectedCourseId == null` (no courses loaded) | Dummy data path with `_status=success`, `_isOffline` stays false — full UI renders fabricated data with **no banner** (A-3) |
| Both students and sessions empty from server | Dummy data substituted silently |
| Roster missing for courseId in manifest | `ReportsService` tries cohorts (`course_code`/`subject_code` → cohort `id`), else empty roster → dummy substitution downstream |
| Session `date` unparseable | dropped from all filtered views (`tryParse` guard) |
| `total == 0` for a student | treated as 0 % (defaulter), guarded division everywhere |
| `overview` when `_stats` empty | returns `{}` → KPI cards render `0.0%` / `0` |
| Filter with zero matching sessions | `overview.overall_average = 0`, sparkline falls back to flat 0.5, charts show empty states |
| Export while exporting | no explicit re-entrancy guard beyond the modal dialog; `_isExporting` flag exists but the sheet can be reopened |
| File write / permission failure | caught → "Export failed: $e" SnackBar |
| `FacultyService.courses` empty at picker | "No courses available" SnackBar (picker not opened) |
| Semester id persisted but no longer in the generated horizon | `_loadPersistedFilters` simply finds nothing → `_selectedSemester` stays null ("Current Semester") |
| Duplicate course id / same course re-selected | `setSelectedCourse` short-circuits when same id and `success` (no redundant refetch) |
| Course id case mismatch | controller compares `c['id'] == _selectedCourseId` (case-sensitive; course ids are codes, so usually consistent) |

---

## 19. Performance Engineering

- **Single-flight fetch:** one `GET /faculty/sync` per course selection (short-circuited for a re-selected course). Full manifest re-download per new course is the price of using the shared manifest instead of a dedicated reports endpoint.
- **Memoized derived getters:** the `_filtersDirty` + 11-cache design means every filter change recomputes each derivation at most once per build pass; repeated `ListenableBuilder` rebuilds hit caches.
- **`RepaintBoundary` scoping:** KPI cards, charts row, department performance, bottom row, and export stats each sit behind a `RepaintBoundary`; `AttendanceChart` is double-wrapped and internally caches its point lists with `identical()` invalidation.
- **`KeyedSubtree(ValueKey(monthFilter + semester))`:** forces chart-subtree rebuild only when a filter actually changes (avoids redundant repaint on unrelated notifies).
- **Lazy lists:** only the skeleton uses a grid; the live layout is a bounded `SliverList` of 11 children — cheap.
- **Client-side aggregation:** weekly/day-of-week bucketing is O(sessions) and computed lazily; sparklines are fixed 7 points; charts cap displayed series to small datasets.
- **Static `_semesterGroups` / style constants:** no per-build allocations for picker data or `GoogleFonts.inter` styles.
- **Export cost:** PDF/Excel generation is synchronous on the UI isolate inside a modal progress dialog (single-threaded; large rosters could jank, but datasets are class-sized).

---

## 20. Security

- **Transport:** all requests via `ApiClient().dio` — JWT bearer via `AuthInterceptor`, `RetryInterceptor` (2 retries, backoff 2/4 s), TLS certificate pinning (`sha256` fingerprints from `PINNED_CERT_FINGRINTS`), body logging only in debug. Timeouts 15 s (sync) / 5 s (subject-analytics in the orphaned dialog).
- **Identity for export headers:** faculty name/department from `FacultyService.profile` (server manifest, `canonicalId` = email); the course name is sanitized with `RegExp(r'[^\w]')` before use in a filename, preventing path injection through course names.
- **Permissions:** the module requests `MANAGE_EXTERNAL_STORAGE` on Android before writing to application documents — a broader permission than needed for the app-scoped directory (A-10).
- **Files:** reports are written to the sandboxed application-documents directory; no upload endpoint; no PII beyond attendance figures in the headers (name/department from the logged-in user's own profile).
- **Retrospective correction** (orphaned but live-wired): explicit `Authorization: Bearer <idToken>` from `FirebaseAuth` on the subject-analytics GET; the POST body is whitelisted (session/student/reason/notes). Server 409 messages are surfaced to the user (`ALREADY_MARKED:<source>`) — acceptable, though the raw exception text leaks the `source` value.
- **Dummy-data risk:** on network failure the module renders fabricated students/sessions (A-3) — a data-accuracy and misreporting risk if faculty export or screenshot that view.
- No secrets or credentials logged; `debugPrint` used for cache/load diagnostics only.

---

## 21. Dependencies Used

| Package | Version | Where used |
|---|---|---|
| `provider` | ^6.0.5 | `context.read<ApiClient>()` and `context.read<AttendanceRepository>()` (orphaned dialog only) |
| `dio` | ^5.3.3 | `ReportsService` (sync manifest) |
| `firebase_auth` | ^5.1.1 | idToken for orphaned subject-analytics call |
| `syncfusion_flutter_charts` | ^26.1.35 | `AttendanceChart`, `ReportDistributionChart`, orphaned `OverviewTab`/`AnalyticsTab` |
| `google_fonts` | ^6.1.0 | all typography |
| `intl` | ^0.19.0 | `DateFormat` (last-sync, filename timestamps, export headers) |
| `hive` / `hive_flutter` | ^2.2.3 | `academicBox` caches + eligibility cache |
| `shared_preferences` | (via PersistenceService) | filter persistence (`reports_selected_semester`, `reports_month_filter`) |
| `pdf` | ^3.12.0 | `_exportPDF` |
| `excel` | ^4.0.6 | `_exportExcel` |
| `open_filex` | ^4.7.0 | "Open" action after export |
| `path_provider` | ^2.1.3 | `getApplicationDocumentsDirectory()` |
| `permission_handler` | ^11.3.1 | `manageExternalStorage` request (A-10) |
| `share_plus` | ^12.0.2 | orphaned `ActionsTab._shareReport` only |
| `dart:io`, `dart:async`, `dart:math` | SDK | file I/O, futures, sparkline min/max |

---

## 22. File Inventory

> Line counts = non-blank lines (`Measure-Object -Line`), Windows paths shown with forward slashes.

### 22.1 Reports feature — `lib/Presentation/Features/Reports/`

| File | LOC | Role | Wired? |
|---|---|---|---|
| `reports_screen.dart` | 1,213 | Section hub: skeleton/empty/error states, 11-sliver layout, 4 bottom sheets | Live |
| `reports_controller.dart` | 959 | All state, filters, memoized derivations, CSV/PDF/Excel export | Live |
| `Components/attendance_chart.dart` | 381 | Daily/Weekly/Monthly chart | Live |
| `Components/report_distribution_chart.dart` | 130 | Eligibility/donut chart | Live |
| `Components/department_performance.dart` | 170 | Course performance bars | Live |
| `Components/recent_reports_list.dart` | 202 | Session list ("Recent Reports") | Live |
| `Components/export_stats_card.dart` | 138 | 2×2 stat grid | Live |
| `Components/report_kpi_card.dart` | 207 | KPI card + sparkline painter | Live |
| `Components/overview_tab.dart` | 281 | `OverviewTab` (gauge, course cards) | **Orphaned (A-1)** |
| `Components/analytics_tab.dart` | 429 | `AnalyticsTab` (student line + trend spline) | **Orphaned (A-1)** |
| `Components/defaulter_tab.dart` | 281 | `DefaulterTab` (alert + fake actions) | **Orphaned (A-1)** |
| `Components/eligibility_tab.dart` | 216 | `EligibilityTab` | **Orphaned (A-1)** |
| `Components/students_tab.dart` | 199 | `StudentsTab` | **Orphaned (A-1)** |
| `Components/sessions_tab.dart` | 113 | `SessionsTab` | **Orphaned (A-1)** |
| `Components/actions_tab.dart` | 92 | `ActionsTab` (exports + share) | **Orphaned (A-1)** |
| `Components/report_helper_widgets.dart` | 507 | Badges, student tile, retrospective-correction dialog | **Orphaned (A-2)** |
| **Module subtotal** | **5,518** | | |

### 22.2 Services / supporting surfaces

| File | LOC | Role |
|---|---|---|
| `lib/Services/reports_service.dart` | 196 | `/faculty/sync` fetch, roster extraction, `computeStats`, Hive cache (`reports_cache_*`, `reports_last_sync`, `eligibility_students_*`) |
| `lib/Services/eligibility_service.dart` | 61 | `threshold = 0.75`, `students` notifier, `switchCourse` cache loader; `getEligibleStudents`/`getDefaulters`/`calculate` unused (A-12) |
| `lib/Presentation/Widgets/app_drawer.dart` | 385 | Drawer "Advanced Reports" entry (`app_drawer.dart:93–97`) — sole entry point |
| `lib/Services/persistence_service.dart` | 147 | `academicBox` (caches), `prefs` (filters) |
| `lib/core/network/api_client.dart` | 131 | Dio + interceptors + cert pinning; base URL precedence (§14) |
| `lib/Data/Repositories/attendance_repository.dart` | 346 | `markAttendanceCorrection` (POST) — called only by orphaned dialog + LiveMonitor |

---

## 23. Appendix A — Known Design Notes & Technical Debt

### A-1. Seven tab components are orphaned dead code (HIGH)

`OverviewTab`, `AnalyticsTab`, `DefaulterTab`, `EligibilityTab`, `StudentsTab`, `SessionsTab`, `ActionsTab` in `Components/` are **never imported** (repo-wide grep: each class appears only in its own file). `ReportsScreen` renders a single-scroll layout instead of tabs. ~1,611 non-blank LOC of tabbed UI, including the only defaulter drill-down (Warn/Call Parent/Meeting) and the only `share_plus` path, is unreachable. Decision needed: restore a `TabController`-based layout or delete the files. The drawer's "Advanced Reports" subtitle ("Analytics & Defaulters") advertises surfaces that only exist in this dead code.

### A-2. `report_helper_widgets.dart` is entirely orphaned — including a live-wired feature (HIGH)

`buildLiveBadge`, `buildPercentageBadge`, `buildProgressBar`, `buildBatchHeader`, `buildStudentTile`, `showRetrospectiveCorrectionDialog` (507 LOC) are referenced by no other file. The retrospective-correction dialog performs **real network I/O** (`GET /api/v1/analytics/subject/{courseId}/attendance`, then `POST /api/v1/faculty/attendance/correction`) but is unreachable from the UI — a shipped-but-unwired feature. Either wire it to a student row or delete it. Its "…in Firestore" empty-state copy suggests drift from the server-backed design.

### A-3. Dummy data masks real failures (HIGH)

`fetchReports` substitutes hard-coded `_dummyStudents` (STU001–STU010) and `_dummySessions` on **any** error, and even when no course is selected, with `_status = success` and `_error = null`. A faculty member offline (or with no courses synced) sees fabricated students and 5 fake sessions rendered identically to real data — distinguishable only by the amber offline banner (which itself is absent in the no-course path). Exports of this view would contain demo data. This is a data-accuracy defect.

### A-4. Error and empty states are unreachable (MEDIUM)

`_error` is never assigned a non-null value and `_status` is never set to `ReportsStatus.error`; dummy substitution guarantees `hasData == true` after any fetch. Therefore `_buildNoDataErrorState`, `_buildEmptyState`, the `error` enum member, and the empty/error branches in `build` are dead UI. The initial (pre-fetch, no-courses) state renders the full section list with all-zero numbers instead of a meaningful message.

### A-5. Hard-coded KPI "change vs last month" deltas (MEDIUM)

`_buildKPICards` passes `change: 2.3 / 4.1 / -1.8` to `ReportKpiCard`, which labels them "vs last month". No period-over-period computation exists; the deltas are static literals that contradict the displayed values once filters change.

### A-6. Eligibility threshold bands are inconsistent across the codebase (MEDIUM)

- `ReportsService.computeStats`: eligible `>= 0.75`, at-risk `0.60–0.75`, defaulter `< 0.60`.
- `ReportsController.atRiskStudents`: defaulter-ish `< 0.75`, critical `< 0.50`.
- `DefaulterTab`: critical `< 0.60`, at-risk `0.60–0.75`.
- `EligibilityService`: gate `>= 0.75`, `calculate()` percentages; `getEligibleStudents`/`getDefaulters` use `>=`/`< 0.75`.
The "critical" boundary alone is **0.50 vs 0.60** depending on surface, and the stats bands (0.60 at-risk) disagree with the controller's 0.75 split. All eligibility is client-side advisory (cross-ref `MYCLASS_MODULE.md` A-8); a server-authoritative eligibility endpoint would remove the ambiguity.

### A-7. "Department Performance" always renders 0 % (MEDIUM)

`departmentPerformance` maps `FacultyService.courses.value` reading `c['avg_attendance']` and `c['session_count']`. The derived course shape (`deriveCoursesFromCohorts`, `faculty_service.dart:144–150`) contains only `id/code/course/name/short_name` — no `avg_attendance`/`session_count`. Unless the manifest adds those keys, every bar renders `0.0 %` and the card is decorative. The orphaned `OverviewTab` has the same dependency.

### A-8. "Recent Reports" / "Export Statistics" are session-derived, not export history (MEDIUM)

`recentReports` = top-10 `filteredSessions` and `totalReportsGenerated` = `filteredSessions.length`. The module records **no history of generated exports**, so the "Reports" naming overstates what the UI shows (it's a session list). The `totalReportsGenerated` getter is itself never consumed.

### A-9. Weekly and Monthly chart tabs render identical data (LOW)

`AttendanceChart._buildMonthlyChart` reuses `_getWeeklyData()` (the W1…W12 weekly trend), so the "Monthly" segment shows exactly the same series as "Weekly". A real monthly aggregation (`_computeWeeklyChartData`-style bucketing by month) is missing.

### A-10. Unnecessary `MANAGE_EXTERNAL_STORAGE` request (MEDIUM)

`exportAsFormat` requests `Permission.manageExternalStorage` on Android, then writes to `getApplicationDocumentsDirectory()` — an app-scoped path that does **not** require that permission. This prompts users for a broad, high-risk permission (which may also be denied by policy on recent Android) for no functional benefit.

### A-11. CSV values are not escaped (LOW)

`_getStudentCsvRows`/`_getSessionCsvRows` join raw values with commas. A student name containing a comma, quote, or newline corrupts the CSV row/column layout. Export should use a quoting strategy or the `csv` package already present in the dependency tree.

### A-12. EligibilityService helper API is dead and logic is duplicated (MEDIUM)

`getEligibleStudents()`, `getDefaulters()`, and `calculate()` are never called; the controller re-implements the same `attended/total` predicates inline (`atRiskStudents`, `topPerformers`, CSV status column). Consolidating on `EligibilityService` would keep the 0.75 gate single-sourced (and would also eliminate the A-6 band drift). Additionally, `EligibilityService.switchCourse` sets `isLoading` `true` then immediately `false` in every branch — the flag is a no-op.

### A-13. Static semester horizon and no default semester (LOW)

`_buildSemesterGroups` hard-codes 8 semesters across 2023–2027; a persisted semester id outside that horizon silently resolves to null ("Current Semester"). There is no "auto-detect current semester" logic, so the default filter is effectively "all time" plus the month range until the user picks a semester.

### A-14. Base URL drift across docs, code, and env (LOW)

`ApiClient._defaultBaseUrl` = `https://api-dev.balaseetharamanjaneyulu.com` (note `janeyulu`); `.env` overrides with `API_BASE_URL=https://api.intelliattend.app`; `ANALYTICS_MODULE.md` documents `https://api-dev.balaseetharamanjaneya.com`. The Reports module runs against whatever the interceptor's base resolves to (the `.env` host today). The three spellings should be reconciled.

### A-15. Import casing drift (LOW)

`reports_screen.dart` imports `components/report_kpi_card.dart` (lowercase) while the physical folder is `Components/`. Functionally fine on Windows/macOS; breaks on case-sensitive builds (Linux CI), mirroring `MYCLASS_MODULE.md` A-9.

### A-16. Dead members (LOW)

`_chartKey` (`GlobalKey`) is declared and attached to the charts row but never read; `totalReportsGenerated` getter is unused; `ReportsStatus.error` is never set; `EligibilityService.isLoading` toggling is a no-op (see A-12).

### A-17. Fake action affordances (LOW)

The orphaned `DefaulterTab` buttons ("Warn" / "Call Parent" / "Meeting") and `ActionsTab._sendWarnings` only show SnackBars — no push notifications, calls, or scheduling. If the defaulter drill-down is ever wired back (A-1), these must connect to real services or be removed.

---

*End of Reports Module technical documentation. Companion: `ANALYTICS_MODULE.md`, `MYCLASS_MODULE.md`, `PROFILE_MODULE.md`, `HOME_MODULE.md`, `COURSES_MODULE.md`.*
