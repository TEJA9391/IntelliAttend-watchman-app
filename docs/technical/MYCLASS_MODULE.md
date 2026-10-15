# IntelliAttend Faculty — My Class Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** My Class (Cohort Hub + Quick Actions deep-dive)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/HOME_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`, `docs/technical/PROJECT_STRUCTURE.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [Provider & State Management Wiring](#3-provider--state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [My Class Hub — `MyClassScreen`](#5-my-class-hub--myclassscreen)
6. [Today's Attendance Segment Screens](#6-todays-attendance-segment-screens)
7. [Student Profile, Attendance History & Subject Topics](#7-student-profile-attendance-history--subject-topics)
8. [Quick Actions Engine — Mark Attendance (5 Modes + Review)](#8-quick-actions-engine--mark-attendance-5-modes--review)
9. [Quick Actions Detail Screens](#9-quick-actions-detail-screens)
10. [The Roster & Eligibility Engine](#10-the-roster--eligibility-engine)
11. [Controllers — Business Logic](#11-controllers--business-logic)
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
24. [Appendix A — Known Design Notes & Technical Debt](#appendix-a--known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **My Class Module** is the second tab of the faculty shell (`DashboardScreen` `IndexedStack`, index 1). It is the per-cohort command surface: a faculty member selects a section (cohort) from a swipeable pager header, sees an at-a-glance overview of that class (enrolment, eligibility, at-risk counts), drills into today's attendance segments, and launches the five **Quick Actions** — Mark Attendance, Attendance Records, Students, Send Message, and Export Reports.

This document covers both halves of the module:

- **The hub** (`lib/Presentation/Features/my_class/`) — the cohort carousel, class pages, segment screens, student profile, attendance history, and subject topics.
- **Quick Actions deep-dive** (`lib/Presentation/Features/QuickActions/`) — all 14 screens, 5 controllers, 5 repositories, 4 shared widgets, and the supporting models/services, documented in full per the product decision (no deferral to a future QuickActions document).

### 1.2 Business Goal

- Give a faculty member a **one-swipe class switcher** across all assigned sections.
- Surface **eligibility health** (≥75% threshold) per class before attendance is ever taken.
- Keep the **five most frequent teaching tasks** (marking, reviewing records, roster browsing, messaging, reporting) ≤ 2 taps from the class page.
- Provide a **multi-modal attendance engine** (manual, QR, NFC, Face, Bluetooth) with a simulated-but-complete pipeline (scan → mark → review → submit) for demonstration and later real integration.

### 1.3 Problem Statement

- Classes are heterogeneous (different sections, semesters, departments); navigating between them must be instant.
- Faculty cannot tell, at a glance, which students are at risk of failing attendance norms.
- Attendance capture is a multi-step ritual; the module must collapse it into a guided flow.
- All five Quick Actions were historically separate features; the module consolidates them under a single hub.

### 1.4 Solution

- A **cohort-first hub**: `MyClassScreen` reads the `cohorts` manifest from the Hive `academicBox`, renders one class page per cohort, and pre-warms each page via a per-index widget cache.
- A **deterministic eligibility split**: present/absent/late segments are derived from the same `attended/total` ratio used by `EligibilityService` (threshold 0.75), so every screen agrees on who is "eligible" vs "at risk".
- A **Quick Actions grid** that wires each action to its controller/repository via Provider, with the legacy `qa.MarkAttendanceScreen` as the live mark-attendance path (see Appendix A-1 for the orphaned dashboard flow).
- A **guided attendance engine** (5 modes → `AttendanceSessionScreen` → `ReviewScreen` → submit) whose QR/NFC/Bluetooth/Face steps are currently simulated at the controller level but structurally identical to a real integration.

### 1.5 Target Users

- **Faculty members** (primary). My Class is exclusively a faculty surface; students never see this module.
- Admin/SmartBoard portals share the same backend manifest (`/api/v1/faculty/sync`) but do not consume this module's screens.

### 1.6 Faculty Workflow (My Class-driven)

```
Dashboard (Tab 2: My Class)
        │  CustomAppBar "My Class" (no back button)
        ▼
┌───────────────────────────────┐
│ COHORT PAGER HEADER            │  ← swipe (0.35 viewport) or chevrons
│  "3rd Year" / "CSE-A"          │
└───────────────────────────────┘
        ▼
┌───────────────────────────────┐
│ CLASS PAGE (per cohort)        │
│  • Overview card (enrol/elig)  │
│  • Today's Attendance 4 chips  │──► Present/Absent/Late/Leave segment screens
│  • Quick Actions grid (5)      │──► Mark Attendance / Records / Students / Message / Export
│  • Subject Class Topics        │──► CourseTopicsScreen
│  • Class Statistics            │──► StudentProfileScreen (highest/lowest)
└───────────────────────────────┘
```

---

## 2. Layered Architecture & Data Flow

The My Class module reuses the strict layered architecture of the app:

```
┌─────────────────────────────────────────────────────────────────────┐
│  PRESENTATION (lib/Presentation/Features/my_class + QuickActions)    │
│  MyClassScreen • Present/Absent/Late/LeaveStudentsScreen              │
│  StudentProfileScreen • AttendanceHistoryScreen                      │
│  SubjectClassTopicsSection                                          │
│  QuickActions: 14 Screens (AttendanceRecords, ClassStudents,        │
│  Messaging, MarkAttendance×9, ExportReports)                        │
│  QuickActions: 4 Widgets (SummaryPanel, BulkActions, SearchBar,     │
│  StudentCard)                                                       │
└──────────────┬──────────────────────────────────────────────────────┘
               │ watch() / read() / watch(context)  (Provider)
┌──────────────▼──────────────────────────────────────────────────────┐
│  CONTROLLER (ChangeNotifier)                                        │
│  MarkAttendanceController • AttendanceRecordsController             │
│  ClassStudentsController • MessagingController • ExportReportsController
└──────┬──────────────────────────────┬───────────────────────────────┘
       │ constructs/reads            │ in-memory demos
┌──────▼─────────────────────┐   ┌───▼────────────────────────────────┐
│  DATA (Repositories)       │   │  SERVICES / MODELS                 │
│  MarkAttendanceRepository  │   │  EligibilityService (0.75)         │
│  AttendanceRecordsRepo     │   │  DraftAttendanceService (500ms)    │
│  StudentsRepository        │   │  OfflineSyncService                │
│  MessagingRepository       │   │  PersistenceService (Hive)         │
│  ExportReportsRepository   │   │  ClassStudent / AttendanceRecord / │
│  (all dummy-data seeds)    │   │  FacultyMessage / ExportReport      │
└──────┬─────────────────────┘   └───▲────────────────────────────────┘
       │ real only via FacultyHydrationService manifest
┌──────▼──────────────────────────────────────────────────────────────┐
│  DATABASE  Hive academicBox: cohorts, roster_<sectionId>,           │
│            eligibility cache (eligibility_students_<courseCode>)    │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.1 Data flow on class load (hub)

```
MyClassScreen.initState
   └─ _loadCohorts()
        ├─ PersistenceService.academicBox.get('cohorts')  → _cohorts
        ├─ fallback: _dummyCohorts (CS201/CS301) + _useDummyRoster = true
        ├─ _classPageCache.clear()
        ├─ initialSubjectCode match → _selectedCohortIndex
        └─ _loadRoster(index)
             ├─ dummy path: _dummyRoster1/_dummyRoster2 by index
             └─ real path: academicBox.get('roster_$sectionId')
                  └─ EligibilityService.switchCourse(course_code)
                       └─ compute/cache eligibility at key
                          'eligibility_students_$courseCode'
```

### 2.2 Data flow on cohort swipe

```
User swipes class PageView
   └─ onPageChanged(index)
        ├─ HapticFeedback.lightImpact()
        ├─ _loadRoster(index)   → clears cache, reloads roster + eligibility
        ├─ _tabPageController.animateToPage(index)  (sync header)
        └─ itemBuilder returns _cachedClassPage(index) (cached or built)
```

---

## 3. Provider & State Management Wiring

The hub does **not** own a single controller. It creates short-lived controllers per quick action and injects them via `ChangeNotifierProvider`, so each action screen is isolated and dispose-safe. The only *shared* state primitives used are `FacultyService.courses` (listener → `_onCoursesChanged` → `_loadCohorts`) and the Hive-backed `PersistenceService.academicBox`.

### 3.1 Provider map

| Consumer screen | Provider construction | Scope |
|---|---|---|
| `qa.MarkAttendanceScreen` | none (controller passed as optional constructor arg; else created internally) | routed via `Navigator.push` |
| `AttendanceRecordsScreen` | `ChangeNotifierProvider(create: (_) => AttendanceRecordsController(AttendanceRecordsRepository()))` | pushed route |
| `ClassStudentsScreen` | `ClassStudentsController(StudentsRepository())` created first, then `ChangeNotifierProvider.value(value: controller)` + passed explicitly as `controller:` | pushed route |
| `FacultyMessagingScreen` | `ChangeNotifierProvider(create: (_) => MessagingController(MessagingRepository()))` | pushed route |
| `ExportReportsScreen` | none — creates its own controller internally | pushed route |
| `AttendanceSessionScreen` / QR / NFC / Face / Bluetooth | `ChangeNotifierProvider.value(value: <shared MarkAttendanceController>)` | child of `ModeSelectionScreen` (orphaned flow, A-1) |

### 3.2 Why `ChangeNotifierProvider.value` for the session chain

The MarkAttendance screens share a single `MarkAttendanceController` instance created at `MarkAttendanceDashboard` (orphaned, see A-1) or inside `mark_attendance_screen.dart`. `.value()` reuses that instance without rebuilding, so roster marks, the draft autosave, QR/NFC timers, and the review list all observe the same notifier.

### 3.3 External listeners

- `MyClassScreen` subscribes to `FacultyService.courses` in `initState` and removes the listener in `dispose` (`my_class_screen.dart:56,71`).
- Brightness changes invalidate the class-page cache (`didChangeDependencies`, `my_class_screen.dart:60-67`) so cached widgets re-render with correct dark/light colors.

---

## 4. Screen Structure — Widget Tree

### 4.1 Hub route tree

```
MyClassScreen (StatefulWidget)                                  [1,055 LOC]
 └─ Scaffold
     ├─ CustomAppBar(title: "My Class", showBackButton: false)
     └─ Column
         ├─ Cohort Pager Header (if >1 cohort)  ─ 56px Row
         │    ├─ GestureDetector chevron_left_rounded
         │    ├─ PageView.builder (viewportFraction 0.35, _tabPageController)
         │    │    └─ Column: _yearText + _deptSectionText
         │    └─ GestureDetector chevron_right_rounded
         ├─ SizedBox(8)
         └─ Expanded
              ├─ if empty → Center("No classes assigned")
              └─ AnimatedBuilder(_pageController)
                   └─ PageView.builder
                        └─ itemBuilder → Transform (rotateY/scale/opacity)
                             └─ _cachedClassPage(index) = _buildClassPage
                                  └─ CustomScrollView (BouncingScrollPhysics)
                                       ├─ _buildOverviewCard
                                       ├─ _buildAttendanceSummary
                                       ├─ _buildQuickActions
                                       ├─ SubjectClassTopicsSection
                                       └─ _buildClassStatistics
```

### 4.2 Quick Actions hub wiring (each `_QuickAction`)

| Action | Icon | Accent | Push target |
|---|---|---|---|
| Mark Attendance | `fact_check_rounded` | `0xFF2DD4BF` | `qa.MarkAttendanceScreen(courseCode, courseName, sessionId: 'session_<epochMs>')` |
| Attendance Records | `receipt_long_rounded` | `0xFF60A5FA` | `ChangeNotifierProvider(AttendanceRecordsController(...)) → AttendanceRecordsScreen()` |
| Students | `people_rounded` | `0xFFFF6B6B` | `ClassStudentsController + ChangeNotifierProvider.value → ClassStudentsScreen(controller, section: sectionId, courseCode)` |
| Send Message | `mail_outline_rounded` | `0xFFFBBF24` | `ChangeNotifierProvider(MessagingController(...)) → FacultyMessagingScreen()` |
| Export Reports | `file_download_outlined` | `0xFFA78BFA` | `ExportReportsScreen()` (self-contained) |

All buttons render as 3-column `GridView.count` tiles (`childAspectRatio: 1.1`, tinted `color.withValues(alpha: 0.08)`, 0.15 border, 20px icon on 0.15 tile).

---

## 5. My Class Hub — `MyClassScreen`

**File:** `lib/Presentation/Features/my_class/my_class_screen.dart` (1,055 non-blank LOC)

### 5.1 Public contract

```dart
class MyClassScreen extends StatefulWidget {
  final String? initialSubjectCode;
  const MyClassScreen({Key? key, this.initialSubjectCode});
}
```

`initialSubjectCode` pre-selects the matching cohort (case-insensitive `course_code` match, `my_class_screen.dart:191-199`). It is supplied by `DashboardScreen` when a timetable card is tapped (`dashboard_screen.dart:379`).

### 5.2 State & lifecycle

| Field | Purpose |
|---|---|
| `_cohorts` | `List<Map<String,dynamic>>` loaded from Hive `cohorts` |
| `_selectedCohortIndex` | active class page |
| `_roster` | current cohort's students |
| `_useDummyRoster` | true when cohort manifest missing |
| `_pageController` | main class-page pager |
| `_tabPageController` | header pager (`viewportFraction: 0.35`) |
| `_classPageCache` | `Map<int, Widget>` per-index cache |
| `_lastBrightness` | cache invalidation on theme change |

- `initState`: `_loadCohorts()`; subscribes `FacultyService.courses.addListener(_onCoursesChanged)`.
- `didChangeDependencies`: clears `_classPageCache` when brightness flips.
- `dispose`: removes listener; disposes both `PageController`s.

### 5.3 Dummy fallbacks (design-debt: see A-2)

- `_dummyCohorts`: `CS201 Data Structures & Algorithms / Section A / Sem 3` (`dummy_sec_1`), `CS301 Operating Systems / Section B / Sem 4` (`dummy_sec_2`).
- `_dummyRoster1`: STU001–STU010, `attended`/`total` (total 15) → a mix of eligible and defaulters.
- `_dummyRoster2`: STU011–STU018.
- `_dummyTopicsBank`: 10 `CourseTopic` entries (e.g. `Introduction & Overview` completed 62/62, `Network Security Fundamentals` 0/62).
- `_getTopicsForCohort`: deterministic slice — `count = (courseCode.hashCode % 4 + 5).clamp(5,8)`, `start = hashCode.abs() % (len-count+1)`.
- `_buildScheduledClassFromCohort`: synthesizes a `ScheduledClass` with empty room, `--:--` times, and today's weekday for the topics navigator.

### 5.4 Cohort header pager

- Shown only when `_cohorts.length > 1`.
- 56px row: chevrons + centered `PageView` at 0.35 viewport fraction.
- Each header cell: `_yearText` (14/12px bold) over `_deptSectionText` (teal accent, 12/10px); the selected cell is enlarged.
- Chevron taps call `HapticFeedback.lightImpact()` and `_pageController.animateToPage(±1, 300ms, easeInOut)`; header page changes mirror `_pageController.animateToPage(index)`.
- Display helpers:
  - `_yearText`: regex-extracts a year 1–6 from `year_of_study/year/study_year/sem_year`, then from `section_name` pattern `(\d+)([A-Za-z])$`; ordinalized; else `"Year Not Available"`.
  - `_deptShortCode`: acronym builder skipping `_deptSkipWords` (and/of/the/for/with/in/on/at/department/dept), ≤4 initials.
  - `_sectionLetter`: from explicit `section/section_code`, then `section_name` trailing letter, then `section_id` last token.
  - `_deptSectionText`: `"CSE-A"` style, falling back to `FacultyService.profile.value?.department`.

### 5.5 Class page carousel & 3D transform

- `PageView.builder` inside `AnimatedBuilder(_pageController)`.
- Per item: `offset = (page - index).clamp(-1,1)` → `rotationY = offset * 0.4`, `scale = 1 - absOffset * 0.15`, `opacity = 1 - absOffset * 0.3`, applied via `Matrix4` (`setEntry(3,2,0.001)` for perspective) + `Opacity`.
- `onPageChanged`: haptic, `_loadRoster(index)`, sync header.
- Pages are memoized by `_cachedClassPage(index)` → `_classPageCache.putIfAbsent`.

### 5.6 Class page sections (slivers)

1. **Overview card** (`_buildOverviewCard`) — dark `0xFF1E1E1E` / white, radius 20, `class_rounded` icon on teal 0.15 tile, year + dept-section, `CLASS TEACHER` badge, divider, 4 mini-stats: **Students / Eligible / At Risk / Section** (`_buildMiniStat`).
2. **Today's Attendance** (`_buildAttendanceSummary`) — derived entirely from the roster ratio:
   - Present = `pct >= 0.75` count; Absent = `< 0.75`; **Late = 0; Leave = 0 (hard-coded** — see A-3).
   - Four chips (`_buildSummaryChip`, wrapped in `Semantics`): Present `0xFF2DD4BF`/`check_circle_rounded`, Absent `0xFFEF4444`/`cancel_rounded`, Late `0xFFFBBF24`/`schedule_rounded`, Leave `0xFF60A5FA`/`event_busy_rounded`; each pushes its segment screen with `roster`, `cohort`, and counts.
3. **Quick Actions** — 5-tile grid (see §4.2).
4. **Subject Class Topics** — `SubjectClassTopicsSection` (§7.3).
5. **Class Statistics** (`_buildClassStatistics`) — rows: Highest Attendance (teal, chevron → `StudentProfileScreen`), Lowest Attendance (red, chevron), Average Attendance (blue), Students Needing Attention (amber, = defaulter count). Computed from `_pct` fold/reduce over the roster.

---

## 6. Today's Attendance Segment Screens

Four sibling screens under `lib/Presentation/Features/my_class/`. All are `StatefulWidget`s taking `{required List<Map<String,dynamic>> roster, required Map<String,dynamic> cohort, int <segment>Count, int totalCount}`. All share the same visual DNA: `CustomAppBar` (title + `course_name` subtitle), a `Hero`-tagged gradient stat card, a search field, a chip row, and a `SliverList` of profile-linked rows. Tap haptics (`HapticFeedback.lightImpact`) are used throughout; rows navigate to `StudentProfileScreen`.

### 6.1 PresentStudentsScreen (`present_students_screen.dart`, 422 LOC)

- **Segment predicate:** `pct >= 0.75` (duplicates the eligibility threshold).
- **Search:** query + type chips **Name / Roll No / ID**; `ID` matches `student['id']` only, `Roll No` matches `roll_number` only, default matches name OR roll. Selecting a type clears the query.
- **Sort:** descending `pct`.
- **Hero:** `'attendance_present'`; header shows `"${presentCount} Students"`, `"Present Today"`, `"$percentage%"` (`presentCount/totalCount`, 1 dp), and `DateFormat('dd MMM yyyy')` today.
- **Row:** teal gradient avatar (initial), name, roll · id (JetBrains Mono, 1px divider), right column `check_circle_rounded` + `"attended/total"`.
- **Empty:** `SliverFillRemaining` "No present students".

### 6.2 AbsentStudentsScreen (`absent_students_screen.dart`, 440 LOC)

- **Segment predicate:** `pct < 0.75`.
- **Filter chips:** All / Critical (<50%) / At Risk (50–74%). Critical rows render red (`0xFFEF4444`) with label `Critical`; otherwise amber (`0xFFFBBF24`) with `At Risk`.
- **Sort:** ascending `pct` (most critical first).
- **Hero:** `'attendance_absent'`; header `"${absentCount} Students"` / `"Absent Today"` + `%` + date.
- **Row:** avatar tinted by status; right column shows `"$pct%"` + status pill.

### 6.3 LateStudentsScreen (`late_students_screen.dart`, 436 LOC)

- **Segment predicate:** `pct >= 0.50 && pct < 0.75`.
- **Sort chips:** Highest Risk / Lowest Risk / Name.
- **Hero:** `'attendance_late'`; header uses the **live filtered `students.length`** (not the passed `lateCount`) with label `"At Risk (50–74%)"` and `Avg Attendance` % on the right.
- **Row:** `"$attended/$total classes"` subtitle; right column `%` + `"$missedCount missed"` badge (only when `missedCount > 0`).

### 6.4 LeaveStudentsScreen (`leave_students_screen.dart`, 463 LOC)

- **Data source:** `final List<Map<String,dynamic>> _leaveRecords = [];` — **always empty** (A-3). There is no feed into it.
- **Status filter chips:** All / Approved / Pending / Rejected (`_statusFilter` 0–3).
- **Hero:** `'attendance_leave'`; header `"${_leaveRecords.length} Total"` / `"Leave Requests"` + mini-stats **Approved / Pending / Rejected**.
- **Row builder** `_buildLeaveRow` (never reached today): name, `leave_type`, reason (2-line clamp), `date`, status pill colored Approved `0xFF2DD4BF` / Rejected `0xFFEF4444` / else `0xFFFBBF24`.
- **Empty state:** `"No leave records found"` when list empty (always).

---

## 7. Student Profile, Attendance History & Subject Topics

### 7.1 StudentProfileScreen (`student_profile_screen.dart`, 1,164 LOC)

- **Contract:** `StudentProfileScreen({required Map<String,dynamic> student})` — receives the hub/segment's raw map.
- **Fabricated enrichment (A-2):** profile detail is synthesized deterministically from `_id.hashCode.abs() % 5`:
  - email `${_name.toLowerCase().replaceAll(' ', '.')}@college.edu`;
  - phone/guardian/blood group/address/DOB from static const arrays;
  - `_assignmentPct`, `_internalPct`, `_labPct` from hash-based formulas.
- **Layout:** `CustomScrollView` + pinned `SliverAppBar` (expandedHeight 280, `Hero tag 'student_avatar_$_id'`), 600ms entrance `AnimationController`.
- **Status color rule:** `pct >= 0.75 → 0xFF22C55E` (green); `>= 0.6 → 0xFFF59E0B` (amber); else `0xFFEF4444`.
- **Actions available on profile:** export to PDF (`pdf` + `path_provider` + `share_plus`), launch phone/email via `url_launcher`, and open a chat with the student via `ChatScreen` (built from `ChatConversation`/`StudentContact` + `MessageCacheService`).

### 7.2 AttendanceHistoryScreen (`attendance_history_screen.dart`, 1,656 LOC)

- **Contract:** `AttendanceHistoryScreen({required Map<String,dynamic> student})`.
- **View modes:** private `_ViewMode { calendar = 0; timeline = 1 }` toggle (`_viewMode`).
- **Data:** `_generateRecords()` seeds `_AttendanceRecord{date, subject, faculty, status, time}` using `math.Random(_id.hashCode)` with a weighted status deck (`Present ×5, Absent, Late`); subjects/faculties/time-slots are static const lists. Month paging via `_selectedMonthOffset`; `_selectedSubject` and `_searchQuery` filters; `_analyticsExpanded` collapsible analytics panel; `initializeDateFormatting()` for locale month names.
- **Exports:** PDF (via `pdf`), Excel (via `excel`), share via `share_plus`/`path_provider`.

### 7.3 SubjectClassTopicsSection (`subject_class_topics_section.dart`, 276 LOC)

Stateless widget used on every class page:

- **Props:** `topics: List<CourseTopic>`, `scheduledClass`, `onSeeAll`, `onTopicTap`.
- **Header:** `menu_book_rounded` icon, "Subject Class Topics", `"$completedCount of ${topics.length} completed"`, and a `See All` pill (only if `topics.length > 3`) → `CourseTopicsScreen` via the hub.
- **Progress:** 6px `LinearProgressIndicator` (`completedCount/topics.length`, teal).
- **Card rail:** horizontal `ListView` (height 110, `BouncingScrollPhysics`), 160px-wide cards with status badge + per-topic progress bar:
  - Completed `0xFF22C55E` ("Completed"), In Progress `0xFF3B82F6` ("In Progress", `!isCompleted && completedCount > 0`), else Pending.
- **Empty state:** "No topics added yet" (`menu_book_outlined`).

---

## 8. Quick Actions Engine — Mark Attendance (5 Modes + Review)

### 8.1 Two parallel implementations (critical distinction)

There are **two** mark-attendance pipelines in the codebase:

1. **Legacy (LIVE):** `qa.MarkAttendanceScreen` — the only one reachable from the My Class hub (`my_class_screen.dart:868`). Self-contained; takes `courseCode`, `courseName`, optional `sessionId`; creates/accepts its own `MarkAttendanceController`.
2. **New dashboard flow (ORPHANED, A-1):** `MarkAttendanceDashboard → ModeSelectionScreen → {QR, NFC, Face, Bluetooth, Manual session} → ReviewScreen`. Fully wired internally via `ChangeNotifierProvider.value(value: controller)`, but **no navigator entry point references `MarkAttendanceDashboard`** (verified by repo-wide grep: only its own declaration). It is currently unreachable dead code.

The remainder of this section documents both, since the dashboard flow is the intended future path and contains the complete mode architecture.

### 8.2 The shared controller (see §11.1 for full API)

`MarkAttendanceController` drives everything: roster, per-student status map, selection/bulk ops, quick actions, QR/NFC/Face/Bluetooth simulations, notes, submit/offline-sync, and the `DraftAttendanceService` autosave (500 ms debounce). Mode screens observe it and call synchronous methods; `notifyListeners()` fans rebuilds out to cards/summary/review.

### 8.3 ModeSelectionScreen (`mode_selection_screen.dart`, 138 LOC)

- **Contract:** receives the shared `MarkAttendanceController` (via `.value` provider) plus `courseCode`/`courseName`.
- **5 modes:** Manual, QR, NFC, Face Recognition, Bluetooth. Selection routes (lines 118/143 push `AttendanceSessionScreen` for the manual & Bluetooth paths; the others push their dedicated screens) — all under the same provider.

### 8.4 QR attendance (`qr_attendance_screen.dart`, 279 LOC)

- Renders the session QR via `qr_flutter` (`generateQRCode`/`refreshQR`/`expireQR`).
- **Countdown:** `qrCountdownSeconds = 120`, ticking on a live timer; expired QR is visually invalidated.
- **Simulation:** `simulateQRScan` auto-fires after ~4 s to demo a scan (A-1/A-4), then marks the student through `approveQRScan`; `rejectQRScan` for the reject path.
- "Review" action pushes `ReviewScreen(courseCode, courseName)` (line 146).

### 8.5 NFC attendance (`nfc_attendance_screen.dart`, 462 LOC)

- Big "tap to simulate" surface calling `simulateNFCTap()`; UI mirrors a real NFC-read loop (card present animation, then mark).

### 8.6 Face recognition (`face_recognition_screen.dart`, 497 LOC)

- Simulated camera frame via `startCamera`/`stopCamera`; `simulateFaceDetection` resolves a match and `confirmFaceRecognition`/`rejectFaceRecognition` finalize it. Uses `mobile_scanner`/camera-style framing visuals (simulated).

### 8.7 Bluetooth attendance (`bluetooth_attendance_screen.dart`, 496 LOC)

- `startBluetoothScan` / `simulateBluetoothDetection` / `stopBluetoothScan`; presents discovered "beacon" students; marks them into the shared roster.

### 8.8 AttendanceSessionScreen (`attendance_session_screen.dart`, 1,511 LOC)

- Used for Manual and Bluetooth live sessions; receives controller + course + mode.
- **Live session header:** elapsed-time timer, live present/absent/late counts, close/submit affordances.
- **Roster marking:** per-student status chips; long-press opens the **note sheet** — reason + remark inputs → `markStudentWithNote(student.id, status, reason:, remark:)`; Save Note is a purple primary button with haptics.
- **Bulk controls:** uses `BulkActionsBar` (select all, mark all present, clear, etc.) — see §9.5.
- **Review:** pushes `ReviewScreen(courseCode, courseName)` at line 535.

### 8.9 ReviewScreen (`review_screen.dart`, 361 LOC)

- Final confirmation surface before submit; receives `courseCode`/`courseName`.
- Shows four status lists — **Present / Absent / Late / Leave** — each with counts and the underlying students (taken from the controller's filtered roster).
- Confirms submission; `submitAttendance` (`sessionStatus: submitted`) or `syncOfflineAttendance` (`submitted_offline`) depending on connectivity.

### 8.10 Legacy MarkAttendanceScreen (`mark_attendance_screen.dart`, 2,075 LOC)

- The **live** path from the hub. Optional `MarkAttendanceController` param; otherwise constructs its own from `MarkAttendanceRepository`.
- Full flow in one screen: roster cards (`StudentAttendanceCard`), bulk actions, quick actions (mark all / filter defaulters / filter eligible / clear filters), live summary panel, note entry, and submit with offline fallback.

---

## 9. Quick Actions Detail Screens

### 9.1 Attendance Records — `AttendanceRecordsScreen` (`attendance_records_screen.dart`, 2,280 LOC)

- **Contract:** `const AttendanceRecordsScreen()` — controller injected via provider.
- **Top-level helpers:** `_fmtDate = DateFormat('MMM d, yyyy')`, `_fmtTime = DateFormat('h:mm a')`.
- **Private enums:**
  - `_DateFilter { today, yesterday, last7Days, last30Days, custom }`
  - `_SortOption { date, name, rollNumber, attendancePercent, time, status }`
- **Tabs:** `TabController` (`SingleTickerProviderStateMixin`) — summary vs records views.
- **Search:** 300 ms debounce on query changes.
- **Pagination:** near-bottom listener (`maxScrollExtent - 200`) advances `currentPage` (`_pageSize = 20`, `hasMore`).
- **Export sheet:** private `_ExportSheet(recordCount, onExportCsv, onExportShare)` → CSV via share_plus.
- **Filter sheet:** private `_FilterSheet` (StatefulWidget) — date range, status, subject, section, student filters.
- **Status colors:** present `0xFF22C55E`, absent `0xFFEF4444`, late `0xFFFBBF24`, leave `0xFF6B4EFF`, holiday `0xFF60A5FA`.

### 9.2 Record Detail — `record_detail_screen.dart` (566 LOC)

- Full view of a single `AttendanceRecord`: check-in/out times, location/device verification flags, sync status, remarks, and the attendance percentage.

### 9.3 Class Students — `ClassStudentsScreen` (`class_students_screen.dart`, 1,313 LOC)

- **Contract:** `(controller, section, courseCode)` — receives the `ClassStudentsController` explicitly *and* via `ChangeNotifierProvider.value`.
- **Filters:** department, section, gender, attendance-range values, eligibility; backed by `StudentsFilter` / `SortOrder` (§11.2).
- **Entry animation:** 700 ms fade-in per list; avatar colors via `_getAvatarColor`.
- Helper private widgets `_AttendanceEntry` and search/filter bar (§9.5 `SearchFilterBar`).

### 9.4 Class Student Profile — `class_student_profile_screen.dart` (935 LOC)

- Profile rendered from the typed `ClassStudent` model (unlike the hub's `StudentProfileScreen` which takes a raw map). Shows eligibility badge, guardian/contact block, blood group, address, notes.

### 9.5 QuickActions shared widgets (4)

| Widget | File (LOC) | Props (key) | Notes |
|---|---|---|---|
| `AttendanceSummaryPanel` | `attendance_summary_panel.dart` (220) | `totalCount`, `presentCount`, `absentCount`, `lateCount`, `leaveCount`, `attendancePercent`, `showChart` | `math` import for the donut; computes `marked`/`remaining`; dark card `0xFF1E1E1E` |
| `BulkActionsBar` | `bulk_actions_bar.dart` (278) | `selectedCount` + 9 selection callbacks + 3 mark callbacks + `onUndo`/`canUndo`/`onExport`/`onSendParents` | dark `0xFF1E1E1E` card; drives selection & bulk mark flows |
| `SearchFilterBar` | `search_filter_bar.dart` (158) | `searchQuery`/`onSearchChanged`/`onClear`/`activeFilterLabel`/`onFilterTap`/`activeSortLabel`/`onSortTap` + optional gender/section filters, `hasActiveFilters`/`onClearAllFilters` | debounced search hook inside |
| `StudentAttendanceCard` | `student_attendance_card.dart` (421) | `student` (ClassStudent), `status`, `isSelected`, `isSelectionMode`, `onStatusChanged`, `onTap`/`onLongPress`, `onHistoryTap`, `onUndoTap`, `note`/`onNoteChanged`, `showLastAttendance`/`lastAttendanceDate`, `canUndo` | imports `ClassStudent` + `AttendanceStatus`; per-student mark card |

### 9.6 Messaging — `FacultyMessagingScreen` (`faculty_messaging_screen.dart`, 2,919 LOC)

- **Contract:** `const FacultyMessagingScreen()` — `MessagingController` injected via provider.
- **3 tabs:** Inbox / Sent / Compose.
- **Post-frame bootstrap:** `loadMessages`, `loadThreads`, `loadTemplates` are invoked post-frame; both scroll controllers paginate (page size 20).
- **Compose:** recipient selection by `RecipientGroup` (entire class, absent/present/late/below-75, parents, individual, multiple classes), `MessageType` chips with color coding (individual → `accentTeal`, parent → `accentPurple`), attachment picker via `file_picker`, template insertion.
- **Text scaling:** `_fontSize` helper scales all typography.

### 9.7 Export Reports — `ExportReportsScreen` (`export_reports_screen.dart`, 1,686 LOC)

- **Contract:** `const ExportReportsScreen()` — creates its own `ExportReportsController` (no provider needed).
- **Form:** `ReportType` + `ExportFormat` selection, date range (`dateFrom`/`dateTo`), `courseCode`, `section`, `semester`.
- **Progress:** generation sheet advances `0.4 → 0.8 → 1.0` via `exportProgress`/`exportStatusText`.
- **Output:** PDF (`printing`), Excel (`excel`), CSV (`csv`), JSON; open via `open_filex`, share via `share_plus`.
- **History:** saved report list with a delete confirmation dialog (line 1,467).

---

## 10. The Roster & Eligibility Engine

### 10.1 Single source of truth

Every screen's "eligible vs at risk" decision derives from the same ratio:

```
pct(student) = attended / total     (total > 0; else 0)
Eligible   : pct >= 0.75
Defaulter  : pct <  0.75
Critical   : pct <  0.50
At risk    : 0.50 <= pct < 0.75
```

The hub duplicates this predicate locally (`_pct`, `my_class_screen.dart:248-252`; `_buildClassPage` §5.6) rather than consuming `EligibilityService` — see A-5 for the drift risk.

### 10.2 EligibilityService (`lib/Services/eligibility_service.dart`, 61 LOC)

- `static double threshold = 0.75` — the single tunable constant for all eligibility gates.
- `switchCourse(String courseCode)` recomputes/caches eligibility under Hive key `eligibility_students_$courseCode`.
- The hub calls `EligibilityService.switchCourse(course['course_code'])` in `_loadRoster` (`my_class_screen.dart:244`).

### 10.3 Hive keys consumed

| Key | Producer | Consumer |
|---|---|---|
| `cohorts` | `FacultyHydrationService` (manifest `/api/v1/faculty/sync`) | `MyClassScreen._loadCohorts` |
| `roster_<sectionId>` | manifest hydration | `MyClassScreen._loadRoster`, `PersistenceService.academicBox` |
| `eligibility_students_<courseCode>` | `EligibilityService.switchCourse` | eligibility gates |

---

## 11. Controllers — Business Logic

### 11.1 `MarkAttendanceController` (`mark_attendance_controller.dart`, 999 LOC)

The largest controller in the module. Full surface:

- **Enums:** `AttendanceMode { manual, qr, face, nfc, bluetooth, hybrid }`, `SortMode`, `FilterMode { all, present, absent, late, leave, notMarked, below75, eligible, above90 }`, `QuickActionResult { success, skipped, offline, failed }`, `StudentNote { reason, remark, medical, lateReason, privateNotes, timestamp }`.
- **Roster:** `loadRoster({section, courseCode})` (400 ms simulated fetch), `filteredRoster`, `availableSections`.
- **Marking (60+ public methods):** `markStudent`, `markStudentWithNote`, `undoLast`; bulk `markAllPresent`, `select*`/`invert`/`clear`/toggle modes; quick actions `quickMarkAll`/`quickFilterDefaulters`/`quickFilterEligible`/`quickClearFilters`; notes.
- **Getters:** `totalCount`, `presentCount`, `absentCount`, `lateCount`, `leaveCount`, `attendancePercent`, `allMarked`, `canSubmit`.
- **QR:** `generateQRCode`, `refreshQR`, `expireQR`, `simulateQRScan`, `approveQRScan`, `rejectQRScan`; `qrCountdownSeconds = 120`.
- **Face:** `startCamera`, `stopCamera`, `simulateFaceDetection`, `confirmFaceRecognition`, `rejectFaceRecognition`.
- **NFC/BT:** `simulateNFCTap`; `startBluetoothScan`, `simulateBluetoothDetection`, `stopBluetoothScan`.
- **Submit:** `submitAttendance`, `syncOfflineAttendance`; `sessionStatus ∈ {submitted, submitted_offline}`; `submitReferenceId`.
- **Autosave:** `DraftAttendanceService` (500 ms debounce) persists the working session so an app kill mid-session is recoverable.

### 11.2 `ClassStudentsController` (`class_students_controller.dart`, 174 LOC)

- **Enums:** `StudentsFilter { none, rollNumber, name, department, section, attendance, eligible, defaulter, gender }`, `SortOrder`.
- **API:** `loadStudents({section, courseCode})`, `isEmpty` getter, filter/sort state.
- Pairs with `StudentsRepository` (dummy data via `DummyDataGenerator.generateStudents`).

### 11.3 `AttendanceRecordsController` (`attendance_records_controller.dart`, 217 LOC)

- **Enums:** `AttendanceFilter { date, subject, section, status, student, session }`, `RecordSortField { date, name, rollNumber, attendancePercent, time }`, `SortDirection`.
- **Paging:** `_pageSize = 20`, `currentPage`, `hasMore`; `summary` map; `currentSessionRecords`.
- Feeds `AttendanceRecordsScreen` tabs, filters, and export.

### 11.4 `MessagingController` (`messaging_controller.dart`, 238 LOC)

- State: `messages`, `threads`, `templates`, `scheduledMessages`; `unreadCount` getter; `MessageFilter`.
- **Paging:** `_pageSize = 20`; flags `isSending`, `isExporting`.
- `loadMessages`, `loadThreads`, `loadTemplates` called post-frame from the screen; send/export flows.

### 11.5 `ExportReportsController` (`export_reports_controller.dart`, 229 LOC)

- `ReportType` / `ExportFormat` selection; `dateFrom`/`dateTo`/`courseCode`/`section`/`semester`.
- Generation state: `exportProgress`, `exportStatusText`; print (PDF) + file output.

---

## 12. Repositories

All five QuickActions repositories live under `lib/Data/Repositories/QuickActions/` and are **in-memory dummy seeds** (A-4) — no real HTTP. Shared conventions: seeded via `DummyDataGenerator`, deterministic `Random(42)`, simulated network latencies (400 ms fetch, 600 ms submit), and a `2%` random `Network error` throw on submit to exercise the failure path.

| Repository | Seeds | Notes |
|---|---|---|
| `mark_attendance_repository` | `_cachedStudents` via `DummyDataGenerator.generateStudents` | 400 ms fetch delay, 600 ms submit delay, 2% submit failure; throws `OfflineMarkAttendanceException` / `MarkAttendanceServerException` |
| `attendance_records_repository` | RPT001 / RPT002 record groups | paged `records` stream; `summary`; `export` |
| `students_repository` | `generateStudents` | `loadStudents`; `isEmpty` |
| `messaging_repository` | ~200 seeded messages, threads, templates | `loadMessages/threads/templates`, send, markRead |
| `export_reports_repository` | generated reports | `generate`, `listReports`, `deleteReport` |

`DummyDataGenerator` (shared generator) produces the `ClassStudent`-shaped students with the 30-field model (see §14.1).

---

## 13. Services

### 13.1 `EligibilityService` — see §10.2

### 13.2 `DraftAttendanceService` (`lib/Data/Services/draft_attendance_service.dart`, 77 LOC)

- Autosaves the in-progress attendance session with a **500 ms debounce**, keyed per session, so a faculty kill/background of the app doesn't lose marks. Writes into Hive (via `PersistenceService`); restores on `loadRoster`/session resume.

### 13.3 `OfflineSyncService` (`lib/Data/Services/offline_sync_service.dart`, 111 LOC)

- Queues submitted sessions when offline (`sessionStatus: submitted_offline`, `submitReferenceId`) and replays them once connectivity returns (`connectivity_plus`), mirroring the Home module's offline posture.

### 13.4 `PersistenceService` (`lib/Services/persistence_service.dart`, 122 LOC)

- Owns the Hive `academicBox` used by `cohorts`, `roster_<sectionId>`, and the eligibility cache. Also exposes the other app boxes (auth/device/etc.).

---

## 14. Data Models & DTOs

All models under `lib/Data/Models/QuickActions/`.

### 14.1 `ClassStudent` (`class_student.dart`)

- **30 fields** including `id`, `name`, `rollNumber`, `courseCode`, `section`, `department`, `gender`, `attended`, `total`, `attendancePercentage`, `isEligible`, `isDefaulter`, `guardianName`, `guardianPhone`, `address`, `bloodGroup`, `notes`.
- `fromJson` uses snake_case keys: `roll_number`, `course_code`, `attendance_percentage`.
- Power source for `StudentAttendanceCard`, `ClassStudentsScreen`, and `DummyDataGenerator`.

### 14.2 `AttendanceRecord` (`attendance_record.dart`)

- **`AttendanceStatus { present, absent, late, leave, holiday }`** — the canonical status enum used across the engine (segment colors in §9.1 derive from it).
- **25 fields** including `checkInTime`, `checkOutTime`, `locationVerified`, `deviceVerified`, `syncStatus`, `attendancePercentage`, `remarks`.

### 14.3 `FacultyMessage` (`faculty_message.dart`)

- **Enums:** `MessageType { announcement, classMessage, individual, parent }`, `MessageStatus`, `MessagePriority`, `MessageCategory`, `RecipientGroup { entireClass, selectedStudents, absentStudents, presentStudents, lateStudents, below75, parents, individual, multipleClasses, allStudents }`.
- **26 fields** including `readCount`, `recipientIds`, `attachments`; companion `MessageThread` / `MessageTemplate` models feed the Messaging tabs.

### 14.4 `ExportReport` (`export_report.dart`)

- **Enums:** `ExportFormat { pdf, excel, csv, json }`, `ReportType { attendance, studentList, sessionSummary, daily, weekly, monthly, subject, department }`.
- `copyWith` for the generation form; feeds `ExportReportsScreen`/`ExportReportsController`.

---

## 15. Backend API Reference

### 15.1 Base URL & manifest

- Base: `https://api-dev.balaseetharamanjaneyula.com`
- Master manifest: `GET /api/v1/faculty/sync` → consumed by `FacultyHydrationService` → written to Hive `academicBox` (this is how `cohorts`, rosters, and schedules reach `MyClassScreen`).
- The **five QuickActions repositories issue no HTTP calls today** (dummy data, A-4). They are shaped to swap onto real endpoints later.

### 15.2 Known contract drift (A-6)

- `course_repository.dart` reads `data['schedule_list']`.
- `faculty_hydration_service.dart` reads `data['schedule']`.
- Same manifest, two key spellings → hydration may silently drop schedules for one consumer.

---

## 16. WebSocket Real-Time Protocol

- The **Home module** subscribes to `faculty_sync`, `student_marked`, and `attendance_updated` events to stream live present/absent counts (see `HOME_MODULE.md`).
- **My Class/Quick Actions do not currently open or listen to WebSocket channels** — the review/submit flow is synchronous with simulated latency. Live telemetry, when enabled for this module, should reuse the existing `WebSocketService` channels (`faculty_sync`, `attendance_updated`) rather than introduce new ones.

---

## 17. Navigation Map

```
DashboardScreen (IndexedStack tab index 1)
   └─ MyClassScreen(initialSubjectCode?)  ── from dashboard_screen.dart:379 (timetable card tap)
        │
        ├─▶ PresentStudentsScreen / AbsentStudentsScreen / LateStudentsScreen / LeaveStudentsScreen
        │        └─▶ StudentProfileScreen(student)
        │              └─▶ AttendanceHistoryScreen(student)      (via profile)
        │              └─▶ ChatScreen                            (via profile "chat")
        ├─▶ SubjectClassTopicsSection ──▶ CourseTopicsScreen(scheduledClass[, initialTopicIndex])
        ├─▶ (stat rows) StudentProfileScreen(highest/lowest)
        │
        ├─▶ qa.MarkAttendanceScreen(courseCode, courseName, sessionId)          [LIVE path]
        ├─▶ AttendanceRecordsScreen (provider) ──▶ record_detail_screen
        ├─▶ ClassStudentsScreen(controller, section, courseCode) ──▶ class_student_profile_screen
        ├─▶ FacultyMessagingScreen (provider)            (Inbox | Sent | Compose)
        └─▶ ExportReportsScreen

[ORPHANED — not reachable from any navigator entry (A-1)]
   MarkAttendanceDashboard
        └─▶ ModeSelectionScreen
              ├─▶ QRAttendanceScreen ──▶ ReviewScreen ──▶ submit/offline
              ├─▶ NFCAttendanceScreen ──▶ ReviewScreen
              ├─▶ FaceRecognitionScreen ──▶ ReviewScreen
              ├─▶ AttendanceSessionScreen(bluetooth) ──▶ ReviewScreen
              └─▶ AttendanceSessionScreen(manual) ──▶ ReviewScreen
```

Legend: `──▶` = `Navigator.push(MaterialPageRoute)`. All routes are unnamed `MaterialPageRoute`s (no named-route table for this module).

---

## 18. Sequence Diagrams

### 18.1 MyClass cold start (cache-first)

```
FacultyService.courses (hydrated)
   │ notifies
MyClassScreen._onCoursesChanged ─▶ _loadCohorts
   │  academicBox.get('cohorts')  ──(null)──▶ _dummyCohorts + _useDummyRoster=true
   ▼
_loadRoster(0)
   ├─ dummy? _dummyRoster1  ── setState
   └─ real?  academicBox.get('roster_dummy_sec_1')
                 └─ EligibilityService.switchCourse('CS201')
   ▼
setState → header pager + class page (cached) render
```

### 18.2 Legacy mark-attendance flow (live)

```
Class page "Mark Attendance" tap
   └─ qa.MarkAttendanceScreen(courseCode, courseName, sessionId: session_<ms>)
         └─ (creates) MarkAttendanceController(MarkAttendanceRepository)
               ├─ loadRoster  → Random(42) seeded students (~400ms)
               ├─ markStudent(id, status)          [per-tap, draft autosave 500ms]
               ├─ markStudentWithNote(id, status, reason, remark) [note sheet]
               ├─ quickMarkAll / quickFilterDefaulters / quickFilterEligible
               └─ submitAttendance
                     ├─ success            → sessionStatus: submitted
                     └─ 2% Network error   → OfflineMarkAttendanceException
                         └─ syncOfflineAttendance → submitted_offline (OfflineSyncService)
```

### 18.3 Orphaned 5-mode flow (future wiring)

```
MarkAttendanceDashboard(controller)
   └─ ModeSelectionScreen
        ├─ QR    : generateQRCode → [120s countdown] → simulateQRScan(~4s)
        │           → approveQRScan → markStudent → ReviewScreen
        ├─ NFC   : simulateNFCTap → markStudent → ReviewScreen
        ├─ Face  : simulateFaceDetection → confirmFaceRecognition → ReviewScreen
        ├─ BT    : startBluetoothScan → simulateBluetoothDetection → markStudent
        │           → ReviewScreen
        └─ Manual: AttendanceSessionScreen → status chips / note sheet → ReviewScreen
              └─ ReviewScreen → submitAttendance | syncOfflineAttendance
```

---

## 19. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| No cohorts manifest | `_dummyCohorts` fallback; `_useDummyRoster=true`; header pager hidden (`length>1` guard); empty state "No classes assigned" if still empty |
| Corrupt/missing Hive cohorts/roster | `try/catch` around `academicBox.get`, `debugPrint`, empty `_roster` → statistics compute to 0/N/A; segment screens show empty states |
| `initialSubjectCode` with no match | ignored; stays on cohort index 0 |
| `total = 0` | `_pct` guards division → `0`; all students render as defaulters |
| Empty segments | `SliverFillRemaining` empty states per screen ("No present students", etc.) |
| Leave module | always empty (`_leaveRecords = []`) — non-functional (A-3) |
| Simulated submit failure (2%) | `MarkAttendanceServerException`; offline fallback path `syncOfflineAttendance`; `sessionStatus: submitted_offline` |
| Mid-session app kill | `DraftAttendanceService` 500 ms debounce restores marks |
| Duplicate subject code (case) | cohort match is case-insensitive (`toLowerCase`) |
| QR expiry | `expireQR` invalidates; 120 s countdown; regenerate allowed |
| Selection on empty roster | `bulkMarkAll`/`quickMarkAll` no-op via `allMarked`/`canSubmit` guards |
| Offline export/report delete | delete confirm dialog; generation progress gate 0.4/0.8/1.0 |

---

## 20. Performance Engineering

- **Per-index class-page cache** (`_classPageCache`): pages are built once per cohort and reused across swipes; invalidated on brightness change and cohort reload.
- **Slivers/lazy lists** everywhere (`SliverList`, `SliverChildBuilderDelegate`) — segment rows, records, students, messages render on demand.
- **3D pager** applies `Opacity` + `Transform` per page — visual cost is bounded because content is cached and pages are small; see A-7 for jank risk on low-end devices.
- **Debounced search:** `AttendanceRecordsScreen` 300 ms; `SearchFilterBar` internal debounce; segment screens use immediate `setState` (small lists).
- **Pagination:** records/students/messaging page at `_pageSize = 20`, near-bottom trigger (`maxScrollExtent - 200`), `hasMore` gating.
- **Autosave batching:** `DraftAttendanceService` 500 ms debounce prevents per-tap disk writes.
- **Fabricated profile data** is computed lazily via getters (`_id.hashCode` derived) — no I/O in the profile screen.
- **Simulated latencies** (400/600 ms) in repositories intentionally mimic network so the UI pipeline (loading states, spinners) is exercised.

---

## 21. Security

- **Identity/transport** is inherited from the app shell: Firebase JWT, Dio interceptors, TLS pinning (`ApiClient`), biometric unlock (`local_auth`) — see `HOME_MODULE.md` §21.
- **Eligibility cache keying** uses the `courseCode`; gate decisions (`EligibilityService.threshold`) are client-side and must be treated as advisory until server-authoritative eligibility exists (A-8).
- **Offline persistence** of rosters/eligibility in Hive is app-sandboxed (no export by default).
- **Fabricated PII** (emails, phones, guardians, addresses) — placeholder data only; real integration must scrub these (A-2).
- **QR attendance** uses a session-scoped QR with 120 s expiry and approve/reject confirmation to prevent replay; NFC/Face/BT remain simulated.
- No secrets/logging of credentials in this module; `debugPrint` used only for Hive load errors.

---

## 22. Dependencies Used

Directly exercised by the My Class module & Quick Actions (from `pubspec.yaml`):

| Package | Where used |
|---|---|
| `provider` | controller injection throughout |
| `hive`, `hive_flutter` | `academicBox` (cohorts/roster/eligibility), draft sessions |
| `google_fonts` | `GoogleFonts.inter` / `jetBrainsMono` typography |
| `intl` | `DateFormat` (`MMM d, yyyy`, `h:mm a`, `dd MMM yyyy`), locale init |
| `qr_flutter` | QR generation in `QRAttendanceScreen` |
| `mobile_scanner` | camera/scanner surface (face screen, simulated) |
| `file_picker` | message attachments |
| `share_plus`, `path_provider` | CSV/PDF/Excel share & export |
| `pdf`, `excel`, `csv`, `printing`, `open_filex` | report generation/printing |
| `url_launcher` | profile call/email actions |
| `connectivity_plus` | offline-sync gating |
| `syncfusion_flutter_charts` | analytics/attendance charts (records/profile) |
| `vibration` | haptic feedback primitives (`HapticFeedback` used for taps) |
| `crypto` | hash-derived deterministic IDs/colours |
| `intelli_attend_shared` | shared models/constants (git dependency, `school-main`) |

---

## 23. File Inventory

> Line counts = non-blank lines (`Measure-Object -Line`), Windows paths shown with forward slashes.

### 23.1 Hub & class pages — `lib/Presentation/Features/my_class/`

| File | LOC | Role |
|---|---|---|
| `my_class_screen.dart` | 1,055 | Hub: cohort pager, class pages, quick actions, statistics |
| `present_students_screen.dart` | 422 | Present segment (≥75%) |
| `absent_students_screen.dart` | 440 | Absent segment (<75%), Critical/At-Risk chips |
| `late_students_screen.dart` | 436 | At-risk segment (50–74%) |
| `leave_students_screen.dart` | 463 | Leave screen (always empty) |
| `student_profile_screen.dart` | 1,164 | Student profile (fabricated enrichment, PDF/chat) |
| `attendance_history_screen.dart` | 1,656 | Calendar/timeline history + exports |
| `subject_class_topics_section.dart` | 276 | Topics rail widget |
| `mark_attendance_screen.dart` | 563 | Legacy per-subject mark attendance (from Courses lineage) |
| `export_attendance_screen.dart` | 488 | Export attendance (CSV default; share/path_provider/intl) |
| `send_notice_screen.dart` | 499 | Notice composer (general/attendance/assignment/exam/meeting) |
| `send_message_screen.dart` | 1,038 | Single-student chat (Hive-backed `_ChatMessage`) |

### 23.2 QuickActions screens — `lib/Presentation/Features/QuickActions/Screens/`

| File | LOC | Role |
|---|---|---|
| `AttendanceRecords/attendance_records_screen.dart` | 2,280 | Records list, tabs, filters, export sheet |
| `AttendanceRecords/record_detail_screen.dart` | 566 | Record detail |
| `ClassStudents/class_students_screen.dart` | 1,313 | Roster browser with filters |
| `ClassStudents/class_student_profile_screen.dart` | 935 | Typed-model profile |
| `ExportReports/export_reports_screen.dart` | 1,686 | Report generator + history |
| `Messaging/faculty_messaging_screen.dart` | 2,919 | Inbox/Sent/Compose messaging |
| `MarkAttendance/mark_attendance_dashboard.dart` | 319 | **Orphaned** dashboard (A-1) |
| `MarkAttendance/mode_selection_screen.dart` | 138 | 5-mode picker |
| `MarkAttendance/attendance_session_screen.dart` | 1,511 | Live session (manual/BT) + note sheet |
| `MarkAttendance/mark_attendance_screen.dart` | 2,075 | **Live** mark-attendance (hub path) |
| `MarkAttendance/qr_attendance_screen.dart` | 279 | QR mode |
| `MarkAttendance/face_recognition_screen.dart` | 497 | Face mode (simulated) |
| `MarkAttendance/nfc_attendance_screen.dart` | 462 | NFC mode (simulated) |
| `MarkAttendance/bluetooth_attendance_screen.dart` | 496 | Bluetooth mode (simulated) |
| `MarkAttendance/review_screen.dart` | 361 | Review/submit |

### 23.3 QuickActions widgets — `lib/Presentation/Features/QuickActions/Widgets/`

| File | LOC | Role |
|---|---|---|
| `attendance_summary_panel.dart` | 220 | Summary/donut panel |
| `bulk_actions_bar.dart` | 278 | Bulk selection/mark bar |
| `search_filter_bar.dart` | 158 | Debounced search + filter/sort chips |
| `student_attendance_card.dart` | 421 | Per-student mark card |

### 23.4 Controllers / Repositories / Services / Models

| File | LOC | Role |
|---|---|---|
| `Controllers/mark_attendance_controller.dart` | 999 | Full attendance engine |
| `Controllers/attendance_records_controller.dart` | 217 | Records paging/filter/sort |
| `Controllers/class_students_controller.dart` | 174 | Roster browser state |
| `Controllers/messaging_controller.dart` | 238 | Messaging state |
| `Controllers/export_reports_controller.dart` | 229 | Report generation state |
| `Repositories/QuickActions/*` (5) | — | Dummy-data seeds (Random 42, 2% failure) |
| `Services/eligibility_service.dart` | 61 | 0.75 threshold + cache |
| `Data/Services/draft_attendance_service.dart` | 77 | 500 ms autosave |
| `Data/Services/offline_sync_service.dart` | 111 | Offline queue/replay |
| `Services/persistence_service.dart` | 122 | Hive `academicBox` |
| `Models/QuickActions/class_student.dart` | — | 30-field student |
| `Models/QuickActions/attendance_record.dart` | — | 5-state record |
| `Models/QuickActions/faculty_message.dart` | — | 26-field message + enums |
| `Models/QuickActions/export_report.dart` | — | Report DTO + copyWith |

---

## 24. Appendix A — Known Design Notes & Technical Debt

### A-1. Orphaned MarkAttendance dashboard flow (HIGH)

`MarkAttendanceDashboard → ModeSelectionScreen → {QR/NFC/Face/BT/Manual} → ReviewScreen` is fully implemented (5 modes, shared controller via `ChangeNotifierProvider.value`, Review submit) but **no navigation entry references `MarkAttendanceDashboard`** — repo-wide grep finds only its own declaration. The hub still launches the legacy `qa.MarkAttendanceScreen`. Decision needed: wire the dashboard as the hub's "Mark Attendance" action (replacing the legacy screen) or delete the dead flow.

### A-2. Fabricated demo data (MEDIUM)

- Hub fallback: `_dummyCohorts`, `_dummyRoster1/2`, `_dummyTopicsBank`.
- `StudentProfileScreen` synthesizes emails (`<first.last>@college.edu`), phones, guardians, blood groups, addresses, DOB, and exam percentages from `id.hashCode`. These are PII-shaped placeholders that must never ship against real student data.

### A-3. Hard-coded Late/Leave (MEDIUM)

`_buildAttendanceSummary` fixes `late = 0` and `leave = 0`, and `LeaveStudentsScreen._leaveRecords` is a hard-coded empty list. The Leave screen renders a functional UI but can never show data; Late segments only exist as the 50–74% at-risk view. There is no live per-session late/leave feed.

### A-4. QuickActions repositories are dummy (MEDIUM)

All five repositories return in-memory seeds (`Random(42)`, 400/600 ms simulated latency, 2% random submit failure). No HTTP. Any real integration requires implementing the repository interfaces against the backend contract (`/api/v1/faculty/sync` manifest + session endpoints).

### A-5. Duplicated eligibility predicate (MEDIUM)

The hub and segment screens re-implement `pct >= 0.75` locally instead of consuming `EligibilityService.threshold`. If the threshold changes in one place only, hub and engine will disagree. Recommend a shared helper (e.g. `EligibilityService.isEligible(student)`).

### A-6. Manifest contract drift (MEDIUM)

`course_repository.dart` reads `data['schedule_list']` while `faculty_hydration_service.dart` reads `data['schedule']` from the same `/api/v1/faculty/sync` payload — one consumer silently loses schedule data.

### A-7. 3D pager cost (LOW)

`Opacity` + `Transform` on every class page during swipe is GPU-cheap for 2–3 pages but should be monitored on low-end Android; the per-index cache mitigates rebuilds.

### A-8. Client-side eligibility authority (MEDIUM)

Eligibility (0.75) is computed client-side from `attended/total`. Advisory only; server-authoritative eligibility is required before student-facing consequences attach.

### A-9. Import casing inconsistency (LOW)

`send_message_screen.dart` imports `Theme/app_theme.dart` (capital `T`) while every other file uses `theme/app_theme.dart`. Functionally equivalent on case-insensitive filesystems; on case-sensitive builds (Linux CI) this will fail.

### A-10. `sessionId` generated from wall clock (LOW)

The hub fabricates `sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}'`. Per the Home module's `TimeSyncService` posture, session IDs should come from the server-anchored clock, not the device wall clock.

---

*End of My Class Module technical documentation. Companion: `HOME_MODULE.md`, `COURSES_MODULE.md`.*
