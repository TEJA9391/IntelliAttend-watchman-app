# IntelliAttend Faculty — Students Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Students (Student Directory)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/HOME_MODULE.md`, `docs/technical/MYCLASS_MODULE.md`, `docs/technical/QUICKACTIONS_MODULE.md`, `docs/technical/ANALYTICS_MODULE.md`, `docs/technical/PROFILE_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Entry Point — AppDrawer "Student Directory" Tile](#4-entry-point--appdrawer-student-directory-tile)
5. [`StudentDirectoryScreen` — Screen Structure & Widget Tree](#5-studentdirectoryscreen--screen-structure--widget-tree)
6. [Search, Filter & List-Rendering Behavior](#6-search-filter--list-rendering-behavior)
7. [Tap-to-Detail Navigation — Where the Tap Goes](#7-tap-to-detail-navigation--where-the-tap-goes)
8. [Cross-Module Edges](#8-cross-module-edges)
9. [Data Models & DTOs](#9-data-models--dtos)
10. [Backend API Reference](#10-backend-api-reference)
11. [WebSocket Real-Time Protocol](#11-websocket-real-time-protocol)
12. [Navigation Map](#12-navigation-map)
13. [Sequence Diagrams](#13-sequence-diagrams)
14. [Error Handling & Edge Cases](#14-error-handling--edge-cases)
15. [Performance Engineering](#15-performance-engineering)
16. [Security](#16-security)
17. [Dependencies Used](#17-dependencies-used)
18. [File Inventory](#18-file-inventory)
19. [Appendix A — Known Design Notes & Technical Debt](#19-appendix-a--known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **Students Module** is a single push screen (`StudentDirectoryScreen`) intended to be a "Student Directory". It is a **static, read-only list view**: a hard-coded array of five fictional students rendered as cards inside a `ListView.builder`, with a decorative search box in the app bar area. The module has **no data layer of its own** — no repository, no service, no controller, no model, no network call, and no state.

> **Plain statement (per documentation rule):** this module is a **thin, non-functional stub**. The feature folder is one 147-line file whose entire "business logic" is a fixture list. Every interactive affordance it advertises (search, directory depth) is unimplemented or decorative. This is documented here rather than assumed to be real.

### 1.2 Business Goal (as intended)

- Provide faculty a browsable, searchable roster of enrolled students with per-student attendance percentage and present/absent status.
- Serve as the drawer-level entry point for the "Student Directory" concept (subtitle reads "N Enrolled Students", where N is summed from the cached course manifest).

### 1.3 Problem Statement

- The app's real, typed student surfaces live in the **QuickActions** module (`ClassStudentsScreen` → `ClassStudentProfileScreen`, typed by `ClassStudent`). The drawer additionally surfaces a "Student Directory" that was scaffolded as a separate screen.
- That screen was built from sample fixtures and never connected to the shared data layer, so it duplicates the *concept* (roster browsing) with **none** of the real behavior (search, filters, tap-to-profile).

### 1.4 Solution (current implementation)

- One `StatelessWidget` that:
  1. Declares `List<Map<String, dynamic>> students` with **5 inline fixture records** (`build()`, student_directory_screen.dart:9–45).
  2. Renders a non-wired `TextField` ("Search student name or ID...").
  3. Renders the fixture list via `ListView.builder` with avatar/name/id/attendance/status cards.
  4. Provides **no** row tap handler — nothing happens when a student is tapped.

### 1.5 Target Users

- **Faculty members** — reached only through the navigation drawer ("Student Directory", ACADEMICS section). Never reachable as a standalone route, tab, or deep link.

### 1.6 Faculty Workflow (as intended)

```
Drawer → ACADEMICS → "Student Directory"
   ├─ search box (expects name/ID filtering — NOT wired)
   ├─ 5 static student cards (avatar · name · id · attendance % · status)
   └─ tap a student → (expects profile view — NOT wired)
   └─ back → Drawer
```

---

## 2. Layered Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION                                               │
│  StudentDirectoryScreen (StatelessWidget, single file)      │
│   ├─ fixture list (hard-coded in build)                     │
│   ├─ decorative TextField (no controller / no onChanged)    │
│   └─ ListView.builder (read-only cards)                     │
└──────────────┬──────────────────────────────────────────────┘
               │ Navigator.push (from AppDrawer only)
┌──────────────▼──────────────────────────────────────────────┐
│  APP SHELL                                                  │
│  AppDrawer (lib/Presentation/Widgets/app_drawer.dart)       │
│   └─ ValueListenableBuilder(FacultyService.courses)         │
│        └─ subtitle "$enrollmentSum Enrolled Students"       │
└──────────────┬──────────────────────────────────────────────┘
               │ ValueListenableBuilder read (drawer subtitle)
┌──────────────▼──────────────────────────────────────────────┐
│  SERVICES (singleton, read-only for this module)            │
│  FacultyService.courses  → List<Map> (Hive-cached manifest) │
└─────────────────────────────────────────────────────────────┘
   NO ApiClient · NO FirebaseAuth · NO repository · NO WebSocket
   NO HTTP of any kind — the module makes ZERO network calls
```

### 2.1 Data flow on screen open

```
AppDrawer "Student Directory" tap
   └─ Navigator.pop(context)                       (close drawer)
   └─ Navigator.push(StudentDirectoryScreen)       (anonymous MaterialPageRoute)
        └─ build()  →  synchronously renders the inline fixture list
             (no initState, no fetch, no loading flag, no error path)
```

The only dynamic value in the flow is the drawer **subtitle**, which is computed live from `FacultyService.courses` (see §4). The screen itself never reads that notifier.

---

## 3. State Management Wiring

| Concern | Mechanism |
|---|---|
| Roster data | **None** — inline fixture `List<Map<String, dynamic>>` built inside `build()` (student_directory_screen.dart:9–45) |
| Search state | **None** — the `TextField` has no `TextEditingController` and no `onChanged` |
| Selected student | **None** — rows have no tap handler |
| Loading / error | **None** — the screen is a single synchronous build; no flags exist |
| App state consumed | `FacultyService.courses` via `ValueListenableBuilder` — but only in `AppDrawer`, **not** in this screen |
| HTTP / DI | No `Provider`, no `context.read`, no `ApiClient` usage anywhere in the file |

The module uses **no** state-management mechanism whatsoever. It is a `StatelessWidget` whose subtree never changes. This is the simplest possible implementation and also the most disconnected: nothing in the module reacts to data changes, auth state, or user input.

---

## 4. Entry Point — AppDrawer "Student Directory" Tile

**File:** `lib/Presentation/Widgets/app_drawer.dart` (375 LOC), ACADEMICS section (lines 58–76).

```dart
ValueListenableBuilder<List<Map<String, dynamic>>>(
    valueListenable: FacultyService.courses,              // app_drawer.dart:59–60
    builder: (context, courses, child) {
      int totalEnrollment = 0;
      for (var c in courses) {
        totalEnrollment += (c['enrollment'] as int? ?? 0);   // app_drawer.dart:63–65
      }
      return _buildMenuItem(
        context,
        Icons.people_alt_rounded,
        "Student Directory",
        () {
          Navigator.pop(context);
          Navigator.push(context,                                    // app_drawer.dart:72
            MaterialPageRoute(builder: (_) => const StudentDirectoryScreen()));
        },
        subtitle: "$totalEnrollment Enrolled Students",             // app_drawer.dart:74
      );
    }),
```

Key facts:

- **Sole launcher.** A repo-wide search for `StudentDirectoryScreen` finds exactly one push site: `app_drawer.dart:72`. There is no route table, no tab, no deep link, and no other screen navigating to it.
- **Subtitle vs. screen mismatch.** The drawer computes "N Enrolled Students" by summing `c['enrollment']` across `FacultyService.courses` (Hive-cached manifest data). The screen itself renders 5 hard-coded fixtures — the drawer count and the on-screen roster are unrelated numbers (A-5).
- The tap closes the drawer first (`Navigator.pop`), then pushes the screen — standard drawer-navigation hygiene (no drawer overlapping the pushed route).

---

## 5. `StudentDirectoryScreen` — Screen Structure & Widget Tree

**File:** `lib/Presentation/Features/Students/student_directory_screen.dart` (147 non-blank LOC).

```dart
class StudentDirectoryScreen extends StatelessWidget {   // no args, const constructor
  ...
  build(context) {
    final List<Map<String, dynamic>> students = [ ... 5 fixtures ... ];  // lines 9–45
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: "Student Directory" (bold, AppTheme.text),    // lines 50–52
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(arrow_back_ios) → Navigator.pop,  // lines 55–57
      ),
      body: Column(mainAxisSize: MainAxisSize.min)            // line 59
        ├─ Padding(24) → TextField                            // lines 62–75
        │    hintText: "Search student name or ID..."
        │    prefixIcon: Icons.search (AppTheme.slate500)
        │    fill: AppTheme.surface, radius 20, no border
        └─ Expanded → ListView.builder(padding h24)           // lines 77–145
             itemCount: students.length
             itemBuilder → Container card (lines 83–142)
                ├─ CircleAvatar(NetworkImage(student['img']), radius 26)  // line 96
                ├─ Column → name (16 bold, ellipsis) + id (12 secondary)  // lines 100–120
                └─ Column (end-aligned)
                     ├─ attendance ('98%' etc., primary bold)             // lines 125–130
                     └─ status ('Present'→green / else→red, 10 bold)      // lines 131–137
    );
  }
}
```

### 5.1 The fixture dataset (student_directory_screen.dart:9–45)

| # | name | id | attendance | status | img |
|---|---|---|---|---|---|
| 1 | Aditya Kumar | 2024CS001 | 98% | Present | `https://i.pravatar.cc/150?u=1` |
| 2 | Sneha Sharma | 2024CS002 | 92% | Present | `https://i.pravatar.cc/150?u=2` |
| 3 | Rohan Das | 2024CS003 | 85% | Absent | `https://i.pravatar.cc/150?u=3` |
| 4 | Priya Singh | 2024CS004 | 75% | Present | `https://i.pravatar.cc/150?u=4` |
| 5 | Vikram Mehra | 2024CS005 | 88% | Present | `https://i.pravatar.cc/150?u=5` |

- All values are **display strings** (`'98%'`, `'Present'`) stored as `String` in a `Map<String, dynamic>` — not typed numbers/enums (A-7).
- Avatars are remote images from `i.pravatar.cc` — an external, non-IntelliAttend service with no `errorBuilder` (A-4).
- The fixture is re-allocated on **every** `build()` of the widget (A-8).

---

## 6. Search, Filter & List-Rendering Behavior

### 6.1 Search — present but non-functional

The `TextField` (student_directory_screen.dart:64–75) is the module's only interactive-looking control, yet it is **fully decorative**:

- No `TextEditingController` — the typed text is not held anywhere in the widget.
- No `onChanged` / `onSubmitted` callback — no filtering is triggered.
- No `_query` state — the screen is stateless by design.

**Consequence:** typing in the search box does nothing. The five fixtures are always rendered in declaration order. There is no filtering, no highlighting, no empty-search-result state, and no clear button.

### 6.2 Filters

**None.** There is no section/course/department/eligibility filter — compare with the sibling `ClassStudentsScreen`, which exposes a `StudentsFilter` enum, sort orders, and section/course selection through `ClassStudentsController` (see §8).

### 6.3 List rendering

- `ListView.builder` with `itemCount: students.length` (fixed at 5), horizontal padding 24.
- Each row is a rounded `Container` (surface fill, radius 20, near-invisible shadow `black @ 0.01 / blur 10`).
- Row content: 26px `CircleAvatar` (network), name (`maxLines: 1`, ellipsis, 16 bold), ID (`maxLines: 1`, ellipsis, 12 secondary), right-aligned attendance (`AppTheme.primary` bold) and status text.
- Status color: `student['status'] == 'Present' ? Colors.green : Colors.red` (line 133–135) — **any** value other than the exact string `'Present'` renders red (A-10).
- No separators, no headers, no index/section headers, no pagination, no pull-to-refresh, no empty state (A-6).

---

## 7. Tap-to-Detail Navigation — Where the Tap Goes

**Answer: nowhere.** Rows have no `GestureDetector`, no `InkWell`, no `onTap`. Tapping a student card produces **zero** effect.

- It does **not** push `ClassStudentProfileScreen` (the QuickActions sibling, `class_student_profile_screen.dart`). That screen requires a typed `ClassStudent` (`ClassStudentProfileScreen({super.key, required this.student})`, class_student_profile_screen.dart:24) — a type the Students module does not produce; its fixtures are untyped `Map`s.
- It does **not** open a profile modal, bottom sheet, or dialog.
- The `class_student_profile_screen.dart` import is **absent** from `student_directory_screen.dart` (only `flutter/material.dart` and `app_theme.dart` are imported).
- The only navigation on the screen is the AppBar back arrow → `Navigator.pop` (line 57).

**Gap:** the drawer advertises a "directory" and the sibling QuickActions flow demonstrates the intended UX (tap roster row → `ClassStudentProfileScreen` at class_students_screen.dart:484). This screen stops at the list with no detail surface (A-3).

---

## 8. Cross-Module Edges

### 8.1 Shared student data — where the real roster lives

The app has **two** "students" concepts that do not share a single source:

| Surface | Module | Data source | Row → detail |
|---|---|---|---|
| `StudentDirectoryScreen` | **Students** (this doc) | inline fixture (5 untyped maps) | none |
| `ClassStudentsScreen` → `ClassStudentProfileScreen` | **QuickActions** (sibling) | `ClassStudentsController(StudentsRepository())` — 12 static typed fixtures | `ClassStudentProfileScreen(student: student)` (class_students_screen.dart:484) |

The QuickActions surface is created at `my_class_screen.dart:884–888`:

```dart
final controller = ClassStudentsController(StudentsRepository());
...
child: ClassStudentsScreen(controller: controller, section: sectionId, courseCode: courseCode)
```

`ClassStudentsController` (`class_students_controller.dart`, 174 LOC) is a `ChangeNotifier` with working search (`search(String)`), filter (`setFilter(StudentsFilter)`), sort (`setSortOrder`), and clear (`clearFilters`). `StudentsRepository` (`students_repository.dart`, 307 LOC) is **also** fixture-based — 12 hard-coded `ClassStudent`s with a simulated 300 ms latency; **no HTTP, no `/api/v1/` call** exists in either the Students feature folder or the whole `QuickActions` subtree (verified by grep).

**Conclusion:** neither students surface talks to the backend today; both render mock data, but the QuickActions one at least has working client-side search/filter/sort/detail. The Students module is the least-evolved of the two (A-1, A-8).

### 8.2 FacultyService.courses (drawer subtitle only)

`AppDrawer` sums `c['enrollment']` from `FacultyService.courses` (Hive-cached manifest list) for the "N Enrolled Students" subtitle. This is the module's only live app-state dependency, and it is consumed by the **drawer**, not by the screen. There is no `FacultyService.profile`, `AttendanceService.students`, or `EligibilityService` dependency in the module.

### 8.3 Share options

**None exist.** A grep for `share`/`Share` inside the QuickActions `ClassStudents` folder returns nothing, and the Students module has no share affordance. "Share a student profile" is not implemented anywhere in this module's reach.

### 8.4 Documentation references

- `COLLABORATION_GUIDE.md:117` — lists `Students/student_directory_screen.dart` as "Student directory".
- `INSTRUCTIONS_FOR_TEJA.md:207` — references the file path.
- `HOME_MODULE.md:520, 1141` — document the drawer tile and its navigation line.
- `OVERFLOW_AUDIT.md:227` — flags long-name overflow risk in this screen (already mitigated by `maxLines: 1` + ellipsis).

---

## 9. Data Models & DTOs

### 9.1 This module

**No model, no DTO.** The module works exclusively with `Map<String, dynamic>` fixture entries keyed by ad-hoc display strings: `name`, `id`, `attendance`, `status`, `img`. There is no `StudentProfile`, no `StudentDirectoryEntry`, no `fromJson`/`toJson` in the feature folder.

### 9.2 Sibling typed model — `ClassStudent` (`lib/Data/Models/QuickActions/class_student.dart`, 157 LOC)

The QuickActions surface owns the app's only typed student model (not part of this module, cross-referenced for clarity):

| Field | Type | JSON key |
|---|---|---|
| `id` | String | `id` |
| `name` | String | `name` |
| `rollNumber` | String | `roll_number` |
| `email` | String | `email` |
| `phone`, `department`, `section`, `courseCode`, `courseName`, `semester`, `image` | String? | same (snake_case) |
| `attendancePercentage` | double | `attendance_percentage` |
| `totalClasses`, `attendedClasses` | int | `total_classes`, `attended_classes` |
| `isEligible`, `isDefaulter` | bool | `is_eligible`, `is_defaulter` |
| `gender`, `lastSeen`, `guardianName`, `guardianPhone`, `address`, `bloodGroup`, `notes` | String?/DateTime? | snake_case |

`ClassStudent.fromJson` is tolerant (`.toString()`, `num?`/`int?` casts, `??` fallbacks). Notably, the Students module's fixtures store `attendance` as the **string** `'98%'` while the typed model uses the **double** `attendancePercentage` — a type-shape divergence that would need reconciling if the directory were ever wired to real data (A-7).

---

## 10. Backend API Reference

The Students module consumes **no endpoints**.

A grep for `/api/v1/` across the Students feature folder and the whole `QuickActions` subtree returns **zero matches**. `ApiClient` and `ApiClient().dio` are not referenced by this module or by the sibling `ClassStudents`/`ClassStudentProfile`/`StudentsRepository`/`ClassStudentsController` files. The module performs no HTTP traffic of any kind.

| Endpoint | Verb | Used by (this module) |
|---|---|---|
| — | — | None. Zero network calls; zero API surface |

For completeness, the app-wide HTTP base (relevant if this screen is ever connected) is defined in `lib/Core/Network/api_client.dart:19`:

```dart
static const _defaultBaseUrl = 'https://api-dev.balaseetharamanjaneyulu.com';
```

- Overridable via `API_BASE_URL` env var (flutter_dotenv) or `ApiClient(customBaseUrl: ...)`.
- All real API calls in the app flow through `ApiClient().dio` (Dio + JWT `AuthInterceptor` + `SecurityInterceptor` + `RetryInterceptor`, 15 s connect/receive timeouts, cert pinning via `PINNED_CERT_FINGERPRINTS`).

---

## 11. WebSocket Real-Time Protocol

**None.** The module opens no WebSocket channels, holds no streams, and subscribes to no live telemetry. `websocket_service.dart` exists app-wide (used by session-monitoring surfaces), but neither the Students module nor its sibling `ClassStudents` surface touches it. The roster, when it exists, is entirely static in-memory mock data.

---

## 12. Navigation Map

```
AppDrawer (lib/Presentation/Widgets/app_drawer.dart)
   └─ ACADEMICS section → "Student Directory" (app_drawer.dart:66–75)
        ├─ Navigator.pop(context)                      (close drawer)
        └─ Navigator.push(MaterialPageRoute)
             └─► StudentDirectoryScreen (Students module)
                  └─ AppBar leading (arrow_back_ios) ──► Navigator.pop
   (rows are not tappable — no student-detail route from this module)

Sibling roster surface (NOT this module):
   MyClassScreen (my_class_screen.dart:888)
      └─► ClassStudentsScreen(controller, section, courseCode)
             └─ row tap (class_students_screen.dart:484)
                  └─► ClassStudentProfileScreen(student: ClassStudent)
```

All routes are anonymous `MaterialPageRoute`s. There is **no deep link, no route name, no tab, and no dashboard quick-action** for `StudentDirectoryScreen`.

---

## 13. Sequence Diagrams

### 13.1 Load directory (from drawer)

```
AppDrawer "Student Directory" tap
   ├─ compute subtitle: sum(c['enrollment'] as int? ?? 0 for c in FacultyService.courses)
   │        (rendered live in drawer via ValueListenableBuilder)
   ├─ Navigator.pop(context)
   ├─ Navigator.push(MaterialPageRoute → StudentDirectoryScreen)
   └─ build()
        ├─ allocate fixture List (5 maps)              // synchronous, lines 9–45
        └─ Scaffold → AppBar → Column
             ├─ TextField (decorative)
             └─ ListView.builder → 5 cards
   (no async, no initState, no network, no loading spinner)
```

### 13.2 Search (as user expects vs. as implemented)

```
User types "Rohan" into search field
   AS DESIGNED:                       AS IMPLEMENTED:
   onChanged → filter fixtures        TextField has no controller/onChanged
     └─ list rebuilds with 1 match      └─ widget tree unchanged
        (empty result → empty state)       list still shows all 5 fixtures
```

### 13.3 Open student profile (as user expects vs. as implemented)

```
User taps "Aditya Kumar" card
   AS DESIGNED (cf. QuickActions):   AS IMPLEMENTED:
   row.onTap → push                  card has no GestureDetector / InkWell / onTap
     └─► ClassStudentProfileScreen     └─ nothing happens; no modal, no detail,
          (student: ClassStudent)         no navigation (A-3)
```

---

## 14. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| Search with no matches | Not applicable — search is not wired; the list never changes |
| Network failure (avatars) | `NetworkImage(student['img'])` has **no `errorBuilder`** — i.pravatar.cc unreachable renders a broken/blank avatar circle (A-4) |
| Null/missing fixture keys | All fixture entries are complete literals; untyped access (`student['name']`) would crash on a malformed map, but none is possible today |
| Offline mode | Screen renders fine (static); only remote avatars fail |
| Empty roster | Impossible — `itemCount` is fixed at 5; there is no empty-state widget (A-6) |
| Double-entry / re-entrancy | N/A — no async work to re-enter |
| `c['enrollment']` non-int (drawer) | `as int? ?? 0` guards the sum — no crash (drawer, not module) |
| Long student names | `maxLines: 1` + `TextOverflow.ellipsis` on name/id/attendance (matches OVERFLOW_AUDIT note) |

The module has **no error surface at all**: no SnackBar, no error banner, no retry, no debugPrint. Errors cannot occur from its own code because it performs no I/O — the only failure domain is the external avatar host.

---

## 15. Performance Engineering

- **Zero network, zero disk I/O** — the cheapest possible screen; no request, cache, or persistence work exists to tune.
- **Tiny dataset** — 5 rows in a `ListView.builder`; nothing scroll-heavy.
- **Remote avatars**: each card requests `https://i.pravatar.cc/150?u=N` on first build; Flutter's in-memory image cache dedupes repeat visits, but there is no `cached_network_image` or persistent disk cache (A-4).
- **Fixture allocation per build**: the list is re-created on every `build()` (A-8). The `itemBuilder` is not `const`-optimized and each card re-decorates its `Container`/`BoxShadow` per build — negligible at this size, but the pattern would not scale.
- **Layout note**: `Column(mainAxisSize: MainAxisSize.min)` containing a flex `Expanded` is contradictory styling (flex forces the column to fill available space anyway); harmless here, worth cleaning when the screen is rewritten.
- No `RepaintBoundary`, no lazy loading, no skeleton loader (compare the QuickActions surface's `skeleton_loader.dart`).

---

## 16. Security

- **No PII transmitted**: the module makes zero network calls; the five fixtures are fictional names/roll numbers/avatars.
- **No secrets**: no tokens, keys, or credentials in the file.
- **External image host**: `i.pravatar.cc` receives requests from the device for avatar bytes — an out-of-domain, non-IntelliAttend service baked into the UI. Any future conversion to real student photos would instead source images from the IntelliAttend CDN/backend (A-4).
- **Displayed data hygiene**: if this screen is ever wired to real student data (names, emails, roll numbers), it will render **PII** — the current stub poses no risk, but the future feature must treat student names/IDs as sensitive in logs and analytics (see `ANALYTICS_MODULE.md` for the app-wide posture).
- **Transport**: N/A for this module; app-wide HTTP is pinned/authenticated via `ApiClient` when used elsewhere.

---

## 17. Dependencies Used

| Package / import | Where used |
|---|---|
| `flutter/material.dart` | `Scaffold`, `AppBar`, `TextField`, `ListView.builder`, `CircleAvatar` |
| `package:intelli_attend_faculty/theme/app_theme.dart` | `AppTheme.bg`, `AppTheme.text`, `AppTheme.slate500`, `AppTheme.surface`, `AppTheme.textSecondary`, `AppTheme.primary` |

The module imports **exactly two libraries**. No `provider`, no `dio`, no `firebase_auth`, no `google_fonts`, no image cache package, no `hive` — the lightest possible dependency footprint, which is also the direct cause of its lack of real behavior.

---

## 18. File Inventory

> Line counts = `Measure-Object -Line` (non-blank, per repo convention).

### 18.1 Students feature — `lib/Presentation/Features/Students/`

| File | LOC | Role |
|---|---|---|
| `student_directory_screen.dart` | 147 | The entire module: fixture data + decorative search + read-only card list |

### 18.2 Launcher

| File | LOC | Role |
|---|---|---|
| `lib/Presentation/Widgets/app_drawer.dart` | 375 | "Student Directory" tile (lines 59–76); computes enrollment subtitle from `FacultyService.courses` |

### 18.3 Sibling surface — QuickActions / ClassStudents (cross-reference, NOT this module)

| File | LOC | Role |
|---|---|---|
| `lib/Presentation/Features/QuickActions/Screens/ClassStudents/class_students_screen.dart` | 1,313 | Typed roster browser (search/filter/sort) — the feature the Students module duplicates in stub form |
| `lib/Presentation/Features/QuickActions/Screens/ClassStudents/class_student_profile_screen.dart` | 935 | Typed student profile (row-tap target in QuickActions) |
| `lib/Presentation/Features/QuickActions/Controllers/class_students_controller.dart` | 174 | `ChangeNotifier` with working search/filter/sort |
| `lib/Data/Repositories/QuickActions/students_repository.dart` | 307 | 12 static `ClassStudent` fixtures; simulated 300 ms latency; no HTTP |
| `lib/Data/Models/QuickActions/class_student.dart` | 157 | Typed `ClassStudent` DTO (`fromJson`/`toJson`/`copyWith`) |

---

## 19. Appendix A — Known Design Notes & Technical Debt

### A-1. The module is a hard-coded mock — no data layer at all (HIGH)

`StudentDirectoryScreen` renders five inline fixture maps declared inside `build()`. There is no repository, service, controller, model, API call, cache, or DI registration anywhere in the Students feature. It is the only "feature" in the app with zero wiring to the data layer. Every other roster surface (My Class, QuickActions, Realtime) goes through repositories/notifiers. Either implement a real data path or remove the screen in favor of routing the drawer tile to the QuickActions surface.

### A-2. Search box is a no-op (HIGH)

The "Search student name or ID..." `TextField` has no controller, no `onChanged`, and no filtering. Users can type and observe nothing happen — an active UX lie. The sibling `ClassStudentsController.search()` already implements the exact desired behavior (name/rollNumber/email substring match) and could be shared or ported.

### A-3. Rows are not tappable — no student detail (HIGH)

No `GestureDetector`/`InkWell`/`onTap` on any card; tapping a student does nothing. The screen does **not** reuse `ClassStudentProfileScreen` (which requires a typed `ClassStudent`) and opens no profile modal. A "directory" that cannot open an entry is a dead end. Wire rows to a detail surface (reuse QuickActions' profile or add a dedicated one) or demote the screen.

### A-4. External avatar dependency with no fallback (MEDIUM)

Avatars come from `https://i.pravatar.cc/150?u=N` — an out-of-domain service with no `errorBuilder` and no disk cache. Offline or blocked networks render broken avatar circles. Replace with bundled assets or the app's own image pipeline (`cached_network_image` + error widget, as `ProfileScreen` does).

### A-5. Drawer subtitle and screen roster disagree (MEDIUM)

The drawer subtitle "N Enrolled Students" is summed from `FacultyService.courses` enrollment (app_drawer.dart:63–65), while the screen always shows exactly 5 fixtures. The two numbers are unrelated, so the directory "count" is informational only and the roster it leads to never matches it.

### A-6. No loading / empty / error states (LOW)

The screen is a single synchronous build with no empty-state widget, no skeleton, no error banner. Fine while static, but any future data wiring will need these states from day one.

### A-7. Stringly-typed display data (LOW)

Attendance is stored as the string `'98%'` and status as `'Present'`/`'Absent'` in untyped maps — unusable for sorting/filtering and incompatible with the typed `ClassStudent.attendancePercentage` (double). Status coloring (`== 'Present' ? green : red`) means any unexpected status value renders red (A-10).

### A-8. Duplicated mock datasets (LOW)

Two independent fixture sets describe the same concept: 5 maps here vs. 12 typed `ClassStudent`s in `students_repository.dart`. Divergent data (different names, different counts) increases confusion and drift risk. If fixtures must persist, centralise them.

### A-9. Stale analyzer output in repo docs (LOW)

`current_analysis.txt:184–185` reports `AppTheme.slate500` / `AppTheme.primary` as undefined for this file — **outdated**. `AppTheme.slate500` is defined (`app_theme.dart:195`) and `AppTheme.primary` is used app-wide; the file compiles against the current theme. The analyzer snapshot should be regenerated or deleted to avoid misleading audits.

### A-10. Status color logic treats all non-"Present" as red (LOW)

`student['status'] == 'Present' ? Colors.green : Colors.red` — a typo like `'present'` or a future status (`'Late'`, `'Flagged'`) silently renders red. Compare the typed `StudentStatus` enum used by `attendance_models.dart`, which defaults unknown → `absent`.

### A-11. `MainAxisSize.min` + flex `Expanded` layout contradiction (LOW)

The body `Column` uses `mainAxisSize: MainAxisSize.min` while containing a flex `Expanded` child — contradictory sizing that happens to fill the viewport. Harmless at this scale; should be simplified when the screen is rewritten.

---

*End of Students Module technical documentation. Companion: `HOME_MODULE.md`, `MYCLASS_MODULE.md`, `QUICKACTIONS_MODULE.md`, `ANALYTICS_MODULE.md`, `PROFILE_MODULE.md`.*
