# IntelliAttend Faculty — Assignments Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Assignments (Create Assignment / Submissions)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/HOME_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/MYCLASS_MODULE.md`, `docs/technical/PROFILE_MODULE.md`, `docs/technical/ANALYTICS_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`CreateAssignmentScreen` — the Publish Form](#5-createassignmentscreen--the-publish-form)
6. [`SubmissionsScreen` — the Completion List](#6-submissionsscreen--the-completion-list)
7. [Submission Detail Bottom Sheet](#7-submission-detail-bottom-sheet)
8. [Drawer Wiring — `AppDrawer` & `DashboardScreen`](#8-drawer-wiring--appdrawer--dashboardscreen)
9. [Cross-Module References](#9-cross-module-references)
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

The **Assignments Module** is a pair of independent push screens exposed only from the `AppDrawer` "CONTENT" section:

- **`CreateAssignmentScreen`** (`create_assignment_screen.dart`, 203 LOC) — a publish form for a new assignment.
- **`SubmissionsScreen`** (`submissions_screen.dart`, 262 LOC) — a list of assignments with submission-completion progress.

Critically, **both screens are entirely client-side shells**: they contain **zero network I/O**, zero repositories, zero services, and zero persistence. Every value rendered — courses, due dates, submission counts, student names — is a hard-coded literal or a hard-coded `Map` literal in the widget's state. The module is **simulated/static UI** (A-1).

### 1.2 Business Goal

- Give faculty a place to **declare an assignment** (title, course, description, due date, max marks) and **observe submission-completion rates** per assignment.
- The intent mirrors a typical LMS "assign → track submissions" loop, delivered as two drawer entries with no server contract today.

### 1.3 Problem Statement

- The app has real modules (My Class, Analytics, Resources, Messaging) but **no assignment backend contract exists in this codebase**.
- The drawer already lists "Create Assignment" and "Submissions" (`app_drawer.dart:106,111`), so the screens exist to satisfy the IA with **placeholder functionality**.
- Faculty expectations (persist an assignment, view real per-student submissions) are not met by the current implementation.

### 1.4 Solution

- `CreateAssignmentScreen`: a `Form` with `GlobalKey<FormState>`, three `TextEditingController`s (`_titleController`, `_descController`, `_marksController` default `"100"`), a `DropdownButton` over a hard-coded 5-item `_courses` list, and a themed `showDatePicker`. `_submit()` validates, shows a green SnackBar `"Assignment Published Successfully!"`, and pops. **Nothing is sent anywhere.**
- `SubmissionsScreen`: a `ListView.builder` over a hard-coded 3-entry `_assignments` list; each card shows title/course/due date, a status badge, a `LinearProgressIndicator` completion bar, and a "View Breakdown" button that opens a bottom sheet with **4 hard-coded student rows**.
- Both screens use **no state-management primitive beyond `setState`** for the picker/selector fields.

### 1.5 Target Users

- **Faculty members** — reached only through the `AppDrawer` "CONTENT" section (`app_drawer.dart:100–114`). There is **no quick action, no tab, and no other entry point** for either screen.

### 1.6 Faculty Workflow (Assignments-driven)

```
Dashboard (any tab) → AppDrawer → CONTENT
   ├─ "Create Assignment" (Icons.assignment_rounded)
   │     └─ fill General Information (Title/Course/Description)
   │        └─ set Deadlines & Grading (Due Date picker / Max Marks)
   │           └─ "Publish Assignment" → green SnackBar → Navigator.pop   (no persistence)
   └─ "Submissions" (Icons.cloud_upload_rounded)
         └─ 3 hard-coded assignment cards (completion %)
            └─ "View Breakdown" → bottom sheet of 4 hard-coded students
```

---

## 2. Layered Architecture & Data Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│  PRESENTATION (only layer present)                                    │
│  CreateAssignmentScreen (StatefulWidget)  •  SubmissionsScreen        │
│   ├─ Form + TextEditingControllers + DropdownButton + DatePicker      │
│   └─ ListView.builder of hard-coded _assignments Maps                 │
└──────────────────────────────────────────────────────────────────────┘
        │  NO repositories, NO services, NO ApiClient, NO dio
        ▼
   (module performs zero network I/O — all data is widget-local)
```

### 2.1 Data flow on screen load

```
CreateAssignmentScreen (no initState logic at all):
   ├─ _dueDate = DateTime.now().add(Duration(days: 7))        [line 18]
   ├─ _selectedCourse = "Neural Networks (CSE-402)"           [line 19]
   └─ _courses = [5 hard-coded course strings]                [lines 21–27]

SubmissionsScreen (no initState logic at all):
   └─ _assignments = [3 hard-coded Map literals]              [lines 12–37]
        └─ itemBuilder → progress = submitted/total           [line 55]
```

There is **no fetch, no cache, no lifecycle hook** — `initState`/`dispose` are not overridden in either screen.

---

## 3. State Management Wiring

| Concern | Mechanism |
|---|---|
| Form fields | Uncontrolled `TextEditingController`s (`_titleController` line 14, `_descController` line 15, `_marksController` line 16 default `"100"`) |
| Due date | `DateTime _dueDate` (line 18) + `setState` after `showDatePicker` |
| Selected course | `String _selectedCourse` (line 19) + `setState` from `DropdownButton.onChanged` (line 108) |
| Submissions list | `List<Map<String, dynamic>> _assignments` — a **final hard-coded field** (lines 12–37); never mutated |
| Form validity | `GlobalKey<FormState>` (line 13), evaluated once in `_submit` (line 54) |
| Provider / ChangeNotifier / ValueNotifier | **None used** in this module |

The module is deliberately state-management-free: no `Provider`, no `ChangeNotifier`, no `ValueNotifier`, no repository. `setState` is invoked only for the date and course selector (`create_assignment_screen.dart:49,108`). The `SubmissionsScreen` never calls `setState` at all.

---

## 4. Screen Structure — Widget Tree

```
Scaffold (bg: AppTheme.bg)
└─ AppBar (bold title, elevation 0, transparent, foreground AppTheme.text)
└─ body
   ├─ CreateAssignmentScreen → SingleChildScrollView(padding 24)
   │    └─ Form(key: _formKey)
   │         └─ Column (mainAxisSize.min, crossAxisStart)
   │              ├─ _buildSectionTitle("General Information")
   │              ├─ _buildLabel("Assignment Title")
   │              │    └─ TextFormField(hint "e.g. Backpropagation Lab")
   │              ├─ _buildLabel("Course")
   │              │    └─ Container > DropdownButtonHideUnderline
   │              │         └─ DropdownButton<String>(value: _selectedCourse, isExpanded)
   │              ├─ _buildLabel("Description")
   │              │    └─ TextFormField(maxLines: 4, hint "Detailed instructions…")
   │              ├─ _buildSectionTitle("Deadlines & Grading")
   │              ├─ Row [ Expanded(Due Date InkWell → calendar_today icon
   │              │          + DateFormat('dd MMM yyyy').format(_dueDate)),
   │              │        Expanded(Max Marks TextFormField, number keyboard) ]
   │              └─ SizedBox(w:∞, h:56) > ElevatedButton("Publish Assignment")
   │
   └─ SubmissionsScreen → ListView.builder(padding 20)
        └─ _assignments.length cards (margin bottom 20, radius 20, surface fill)
             ├─ Row [ title + "course • Due: dueDate" | _buildStatusBadge ]
             ├─ Row [ "Completion Rate" | "submitted/total Students" ]
             ├─ ClipRRect > LinearProgressIndicator(value: progress, minHeight 8)
             └─ OutlinedButton("View Breakdown") → _showSubmissionDetails
```

### 4.1 Shared styling conventions

- Cards: `AppTheme.surface(context)` fill, `borderRadius` 20 (list cards) / 12 (inputs), border `AppTheme.border(context).withValues(alpha: 0.1)`.
- Primary action: full-width `ElevatedButton`, `AppTheme.primary(context)` background, `borderRadius: 16`, height 56, white bold 16 px label.
- Section titles: `w900`, 12 px, `letterSpacing 1.2`, primary color. Labels: 13 px `w600`, `textSecondary`.
- Text overflow defended with `maxLines: 1` + `TextOverflow.ellipsis` throughout.

---

## 5. `CreateAssignmentScreen` — the Publish Form

**File:** `lib/Presentation/Features/Assignments/create_assignment_screen.dart` (203 LOC)

- `CreateAssignmentScreen extends StatefulWidget` with a no-arg `const` constructor — a pure navigation target (no parameters, no callbacks).
- **Imports:** `flutter/material.dart`, `theme/app_theme.dart`, `package:intl/intl.dart` (for `DateFormat`). The `intl` import is the module's only third-party dependency.
- **No `initState`, no `dispose`** — controllers are never disposed (A-6).
- `_submit()` (create_assignment_screen.dart:53–65):
  - `if (_formKey.currentState!.validate())` → `showSnackBar(SnackBar(content: Text("Assignment Published Successfully!"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))` → `Navigator.pop(context)`.
  - There is **no HTTP call, no repository, no storage** — the form data is discarded on pop (A-1/A-2).

### 5.1 Hard-coded constants

| Constant | Value | Line |
|---|---|---|
| `_marksController` initial text | `"100"` | 16 |
| `_dueDate` default | `DateTime.now().add(const Duration(days: 7))` | 18 |
| `_selectedCourse` default | `"Neural Networks (CSE-402)"` | 19 |
| `_courses` | `["Neural Networks (CSE-402)", "Digital Ethics (HUM-101)", "Machine Learning (AI-301)", "Cloud Computing (IT-405)", "Cyber Security (SEC-501)"]` | 21–27 |
| `showDatePicker.firstDate` | `DateTime.now()` | 33 |
| `showDatePicker.lastDate` | `DateTime(2030)` | 34 |

> The course list is **not derived from `FacultyService.courses`** (the app's canonical course notifier) — it is a static 5-item fixture (A-3). Any new course enrolled in the backend will not appear here.

### 5.2 Validation

- **Assignment Title:** `validator: (v) => v!.isEmpty ? "Required" : null` (line 91) — the only validation rule in the form.
- **Description:** no validator (optional).
- **Max Marks:** `keyboardType: TextInputType.number` only — no numeric parser, no `min > 0` check, and an **empty value is accepted** (A-4).
- `_formKey.currentState!` is force-unwrapped; the form is always present so this is safe in practice.

### 5.3 Date picker

- `_selectDate()` (lines 29–51): `showDatePicker(initialDate: _dueDate, firstDate: DateTime.now(), lastDate: DateTime(2030))`, wrapped in a `Theme` that forces `ColorScheme.light(primary: AppTheme.primary(context), onPrimary: Colors.white, onSurface: AppTheme.text(context))` — i.e. the picker is always light-themed even in dark mode.
- Result applied only `if (picked != null && picked != _dueDate)` then `setState`.
- Display format: `DateFormat('dd MMM yyyy')` (line 144) → e.g. `09 Aug 2026`.

### 5.4 Submission affordance

- "Publish Assignment" button (lines 173–184): `SizedBox(width: double.infinity, height: 56)` + `ElevatedButton` with `borderRadius: 16`.
- **No loading state** exists — `_submit` is synchronous (A-5). Double-tapping publishes twice (two SnackBars, two pops).

---

## 6. `SubmissionsScreen` — the Completion List

**File:** `lib/Presentation/Features/Assignments/submissions_screen.dart` (262 LOC)

- `SubmissionsScreen extends StatefulWidget` — no-arg `const` constructor, no parameters.
- **Imports:** `flutter/material.dart`, `theme/app_theme.dart`. No `intl`, no network packages.
- **No `initState`, no `dispose`, no `setState` anywhere in the file** — the widget is effectively immutable after construction.

### 6.1 The hard-coded `_assignments` dataset (lines 12–37)

| `title` | `course` | `submitted` | `total` | `dueDate` | `status` |
|---|---|---|---|---|---|
| `Backpropagation Lab` | `CSE-402` | `42` | `55` | `28 Mar 2024` | `Active` |
| `Ethics Case Study` | `HUM-101` | `55` | `55` | `22 Mar 2024` | `Completed` |
| `ML Model Optimization` | `AI-301` | `12` | `55` | `02 Apr 2024` | `Active` |

- All `dueDate` values are **hard-coded to March/April 2024** — stale relative to the current product date (A-7).
- `progress = a['submitted'] / a['total']` (line 55) is integer-to-integer **double division** (Dart `/`), safe for `LinearProgressIndicator`.
- `isCompleted = a['submitted'] == a['total']` (line 56) drives the green progress bar and green badge.

### 6.2 Card rendering (lines 58–151)

- Card header: bold 16 px title + `${a['course']} • Due: ${a['dueDate']}` (line 85) + `_buildStatusBadge(a['status'])` (line 94).
- Completion row: `"Completion Rate"` label and `${a['submitted']}/${a['total']} Students` (lines 98–120).
- `LinearProgressIndicator` (lines 122–131): `minHeight: 8`, `borderRadius: 10` via `ClipRRect`, track `AppTheme.primary.withValues(alpha: 0.1)`, value color `Colors.green` when `isCompleted` else `AppTheme.primary`.
- "View Breakdown" `OutlinedButton` (lines 133–148) → `_showSubmissionDetails(a)`; border `AppTheme.primary.withValues(alpha: 0.3)`, radius 12.
- `_buildStatusBadge` (lines 252–269): `"Completed"` → green tint / else primary tint; label is `status.toUpperCase()` (e.g. `ACTIVE`), 10 px w900, `letterSpacing 0.5`.

> There is **no pull-to-refresh, no empty state, no error state, no pagination** — the list is static (A-8). Because `total` is a literal `55` in all entries, the `submitted/total` division cannot hit zero today (A-9).

---

## 7. Submission Detail Bottom Sheet

**File:** `submissions_screen.dart` `_showSubmissionDetails` (lines 157–204)

- `showModalBottomSheet(context, backgroundColor: AppTheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))))`.
- Content: header `${a['title']} - Submissions` (bold 18 px, ellipsized), then **4 hard-coded `_buildSubmissionTile` rows** (lines 178–183):

| Name | status | time |
|---|---|---|
| `John Doe` | `submitted` | `10:30 AM Today` |
| `Jane Smith` | `submitted` | `09:15 AM Yesterday` |
| `Mark Wilson` | `absent` | `Not Submitted` |
| `Emma Brown` | `submitted` | `02:45 PM Yesterday` |

- These rows are **unrelated to the tapped assignment's data** — every assignment opens the identical 4-person fixture (A-10).
- `_buildSubmissionTile(name, status, time)` (lines 206–250):
  - `CircleAvatar` 18 px — green 0.1 tint + `Icons.check` when `status == "submitted"`, else red 0.1 tint + `Icons.close`.
  - Name (14 px bold) + time (11 px `textSecondary`).
  - When submitted, a `"VIEW"` text label is appended (lines 241–246) — **purely decorative, not tappable** (A-10).
- Footer: full-width `ElevatedButton("Close")` → `Navigator.pop`.
- Sheet uses `mainAxisSize: MainAxisSize.min` with a fixed 4 rows; there is no scrollable student list (A-10).

---

## 8. Drawer Wiring — `AppDrawer` & `DashboardScreen`

### 8.1 `AppDrawer` callback contract (`lib/Presentation/Widgets/app_drawer.dart`, 375 LOC)

| Member | Line | Purpose |
|---|---|---|
| `final VoidCallback? onCreateAssignment` | 22 | Drawer "Create Assignment" tap handler |
| `final VoidCallback? onSubmissions` | 23 | Drawer "Submissions" tap handler |
| `"CONTENT"` section label | 100 | Groups Resources / Create Assignment / Submissions |
| `_buildMenuItem(Icons.assignment_rounded, "Create Assignment", …)` | 106–110 | Calls `widget.onCreateAssignment!()` after `Navigator.pop` (line 109) |
| `_buildMenuItem(Icons.cloud_upload_rounded, "Submissions", …)` | 111–114 | Calls `widget.onSubmissions!()` after `Navigator.pop` (line 113) |

Both callbacks are nullable and guarded (`if (widget.onCreateAssignment != null)`).

### 8.2 `DashboardScreen` wiring (`lib/Presentation/Features/Faculty/dashboard_screen.dart`, 364 LOC)

```dart
void _showCreateAssignment() {                                  // lines 67–69
  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAssignmentScreen()));
}
void _showSubmissions() {                                       // lines 71–73
  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmissionsScreen()));
}
```

- The drawer is built inside `Consumer<DashboardController>` + `ValueListenableBuilder<FacultyProfile?>` (dashboard_screen.dart:102–118); the assignment callbacks are wired at **lines 114–115** (`onCreateAssignment: _showCreateAssignment, onSubmissions: _showSubmissions`).
- Imports for the two screens: `dashboard_screen.dart:20–21`.
- Note the drawer **pops itself before invoking the callback** (`app_drawer.dart:108`), so the push happens on the shell's context after the drawer closes.

---

## 9. Cross-Module References

The Assignments screens are standalone, but "assignment" as a domain concept appears across several real (and simulated) surfaces:

| Surface | File:line | Relationship |
|---|---|---|
| My Class — student profile | `lib/Presentation/Features/my_class/student_profile_screen.dart:54` | `double get _assignmentPct => 0.60 + (_id.hashCode.abs() % 30) / 100.0` — a **deterministic pseudo-random "Assignment Completion" percentage** (simulated; rendered at lines 343, 733, 793, 944, 1037, 1129). |
| Messaging — templates | `lib/Data/Repositories/QuickActions/messaging_repository.dart:210–213` | `MessageCategory.assignment` template `'Assignment Submission'` / subject `'Assignment Submission Reminder'` |
| Messaging — enum | `lib/Data/Models/QuickActions/faculty_message.dart:10` | `enum MessageCategory { …, assignment, … }` |
| Notifications | `lib/Presentation/Features/Notifications/notifications_screen.dart:204–205` | assignment-category notifications render `Icons.assignment_turned_in_rounded` |
| Resources | `lib/Presentation/Features/Resources/resources_screen.dart:764` | `'Assignment'` is one of the **real upload categories** (`['Lecture Notes', 'Assignment', 'Lab Manual', 'Question Bank', 'Other']`); uploads hit `POST /api/v1/faculty/resources/upload` (`resource_repository.dart:148`) |
| QuickActions announcements | `lib/Data/Models/QuickActions/dummy_data.dart:263–264` | `'Assignment Deadline Extended'` announcement template (simulated feed) |
| My Class — simulated chat | `lib/Presentation/Features/my_class/send_message_screen.dart:112–116` | Chat fixture text references "all 4 assignments" / "Assignment 4 is due tomorrow" |
| Dashboard quick actions | `lib/Presentation/Features/Faculty/Components/dashboard_sections.dart:135–152` | Quick Actions grid is **Chat / History / Insights / Support** — assignments are **absent** from the grid; the drawer is the only entry (A-11) |

**Takeaway:** the only *real* network path related to assignments anywhere in the app is the **Resources upload** (`POST /api/v1/faculty/resources/upload`); the Assignments module itself never touches it, and all other assignment data (My Class completion %, messaging templates, notifications) is fixture/simulated.

---

## 10. Data Models & DTOs

| Model | File | Notes |
|---|---|---|
| *(none)* | — | The module defines **no classes, enums, or DTOs**. |

- `CreateAssignmentScreen` models its input purely via widget state (`TextEditingController`s + two `setState` fields); there is no `AssignmentDraft`/`AssignmentPayload` class.
- `SubmissionsScreen` models its data as raw `Map<String, dynamic>` literals with ad-hoc keys: `title`, `course`, `submitted`, `total`, `dueDate`, `status` (`submissions_screen.dart:13–20`). Stringly-typed access (`a['title']`, `a['submitted'] / a['total']`) with **no type guards** (A-12).
- By contrast, every other assignment-adjacent surface in the app has models: `MessageCategory` (`faculty_message.dart:10`), `NotificationCategory.assignment` (`notification_service.dart:5`), and the Resources category list (`resources_screen.dart:764`).

---

## 11. Backend API Reference

| Endpoint | Verb | Used by | Notes |
|---|---|---|---|
| *(none — this module performs zero HTTP)* | — | — | Neither screen imports `ApiClient`, `dio`, or any repository |

Verified by grep: `api/v1|dio|http|service|repository` matches **zero** across `lib/Presentation/Features/Assignments/`.

All other calls in the app still go through `ApiClient().dio` (JWT bearer, interceptors, TLS) against `https://api-dev.balaseetharamanjaneya.com` — see `PROFILE_MODULE.md` / `ANALYTICS_MODULE.md` for the client contract. The only assignment-adjacent real endpoint elsewhere is `POST /api/v1/faculty/resources/upload` (Resources module, `resource_repository.dart:148`), which this module does not call.

---

## 12. WebSocket Real-Time Protocol

The Assignments module opens **no WebSocket channels** and subscribes to nothing. The real-time WebSocket stack used elsewhere (`websocket_service.dart`, `chat_realtime_service.dart` — both keyed off `FacultyService.canonicalId`) is entirely unrelated to these screens. Assignment data would, in a production design, likely arrive over REST or the existing WebSocket; today there is no transport at all (A-1).

---

## 13. Navigation Map

```
DashboardScreen (any tab) ──► AppDrawer (CONTENT section, app_drawer.dart:100)
   ├─ "Create Assignment" (Icons.assignment_rounded)  ──► CreateAssignmentScreen   (app_drawer.dart:106–110 → dashboard_screen.dart:67–69)
   │        └─ "Publish Assignment" → SnackBar → Navigator.pop
   └─ "Submissions" (Icons.cloud_upload_rounded)      ──► SubmissionsScreen        (app_drawer.dart:111–114 → dashboard_screen.dart:71–73)
            └─ "View Breakdown" → showModalBottomSheet (submissions_screen.dart:157)

Not reachable from:
   Quick Actions grid (dashboard_sections.dart:135–152 — Chat/History/Insights/Support only)
   Tab bar / IndexedStack (Home, Courses, My Class, Profile)
   Any deep link or named route
```

Both routes are anonymous `MaterialPageRoute`s. There is **no deep link, no route name, no tab** for either screen — drawer-only navigation (A-11).

---

## 14. Sequence Diagrams

### 14.1 Create Assignment (entire flow is local)

```
Drawer "Create Assignment"
   └─ Navigator.push(CreateAssignmentScreen)
        └─ user fills title/course/description, picks due date, sets marks
             ├─ _selectDate(): showDatePicker(now → 2030) → setState(_dueDate)
             └─ _submit()
                  ├─ _formKey.currentState!.validate()
                  │    └─ title empty → "Required" (inline FormField error)
                  ├─ showSnackBar("Assignment Published Successfully!" ← green)
                  └─ Navigator.pop(context)   [data discarded — no server, no cache]
```

### 14.2 View Submissions

```
Drawer "Submissions"
   └─ Navigator.push(SubmissionsScreen)
        └─ build → ListView.builder over _assignments (3 literals)
             └─ "View Breakdown" tap → showModalBottomSheet
                  └─ renders 4 hard-coded student tiles (John Doe / Jane Smith /
                     Mark Wilson / Emma Brown) — same fixture for every assignment
```

No external actors participate in either diagram.

---

## 15. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| Empty assignment title | `validator` returns `"Required"`; form blocks submit (create_assignment_screen.dart:91) |
| Empty description | Accepted (no validator) |
| Empty / non-numeric Max Marks | Accepted silently — no numeric validation (A-4) |
| Empty Max Marks + submit | Form still validates → success SnackBar with empty marks (A-4) |
| Date picker cancelled | `picked == null` → `_dueDate` unchanged (line 48) |
| Network failure | **Not applicable** — no network calls exist |
| `submitted == total` (division) | Static dataset guarantees `total = 55`; if a future list entry had `total = 0` the unguarded `a['submitted'] / a['total']` would throw at render (A-9) |
| Missing/wrong `Map` keys | `a['submitted'] / a['total']` on a non-numeric value would throw; stringly-typed access with no guard (A-12) |
| Rapid double-tap "Publish" | No debounce/single-flight — two SnackBars and two pops possible (A-5) |
| Long strings | Defended with `maxLines: 1` + `TextOverflow.ellipsis` on every text node |
| Dark mode | Date picker forcibly themed `ColorScheme.light` (lines 36–43) — consistent but ignores app theme |

---

## 16. Performance Engineering

- **Zero network cost**: the module performs no I/O of any kind — nothing to fetch, cache, or paginate.
- **Static construction**: `_assignments` is a `final` field; `ListView.builder` (submissions_screen.dart:50) lazily builds only visible cards — appropriate for the 3-item fixture.
- **No repaint/rebuild hazards**: `SubmissionsScreen` never calls `setState`; `CreateAssignmentScreen` rebuilds only on date/course change (both `setState` calls are cheap).
- **No persistence, no timers, no streams** — trivially low footprint; the trade-off is the total absence of functionality (A-1).
- **Controllers not disposed** (`_titleController`/`_descController`/`_marksController`) — a minor leak per screen visit, invisible in practice (A-6).

---

## 17. Security

- **No data leaves the device**: both screens transmit zero bytes, so there is no exfiltration surface in this module.
- **No PII**: all rendered names (`John Doe`, etc.) and values are hard-coded fixture strings, not real student records.
- **No input handling risk**: the date picker coerces its selection; the title validator prevents null/empty; no raw HTML/markdown rendering is performed.
- **Honest-by-default concern**: because `_submit` shows a **green success SnackBar** for a publish that never reaches a server (`create_assignment_screen.dart:57`), the UI asserts a false state of success — a data-integrity/UX risk for faculty who believe the assignment was persisted (A-2).

---

## 18. Dependencies Used

| Package | Where used |
|---|---|
| `intl` (`^0.19.0`, pubspec.yaml:25) | `DateFormat('dd MMM yyyy')` in `create_assignment_screen.dart:144` |
| `flutter/material` | All layout, form, snackbar, bottom-sheet widgets |
| `theme/app_theme.dart` | `AppTheme.bg/surface/primary/text/textSecondary/border` |

The module does **not** use `provider`, `dio`, `firebase_auth`, `hive`, or `shared_preferences`. Its only non-SDK import is `intl`. For contrast, the sibling `Resources` module (real uploads) uses `provider`, `dio`, and `file_picker`.

---

## 19. File Inventory

> Line counts = `Measure-Object -Line` (non-blank, per repo convention).

### 19.1 Assignments feature — `lib/Presentation/Features/Assignments/`

| File | LOC | Role |
|---|---|---|
| `create_assignment_screen.dart` | 203 | Publish form (entirely local/simulated) |
| `submissions_screen.dart` | 262 | Static completion list + detail bottom sheet |

### 19.2 Supporting surfaces (wiring & cross-references)

| File | LOC | Role |
|---|---|---|
| `lib/Presentation/Widgets/app_drawer.dart` | 375 | "Create Assignment" / "Submissions" drawer items (lines 106–114) |
| `lib/Presentation/Features/Faculty/dashboard_screen.dart` | 364 | Pushes both screens (lines 67–73); wires drawer callbacks (lines 114–115) |
| `lib/Presentation/Features/my_class/student_profile_screen.dart` | 1290* | Simulated "Assignment Completion" % (`_assignmentPct`, line 54) |
| `lib/Data/Repositories/QuickActions/messaging_repository.dart` | ~215* | `MessageCategory.assignment` template (lines 210–213) |

\* Reference sizes for cross-module surfaces; full inventories live in the respective module docs (`MYCLASS_MODULE.md`, `HOME_MODULE.md`).

---

## 20. Appendix A — Known Design Notes & Technical Debt

### A-1. The module is 100% simulated — no backend, no persistence (HIGH)

Both screens are static UI shells. `CreateAssignmentScreen._submit` (create_assignment_screen.dart:53–65) shows a success SnackBar and pops without any API call, repository, or storage; `SubmissionsScreen` renders 3 hard-coded `Map` literals (submissions_screen.dart:12–37). A repo-wide search for `api/v1|dio|http|service|repository` inside `lib/Presentation/Features/Assignments/` returns zero matches. The "CONTENT" drawer section therefore promises an LMS capability the app does not implement.

### A-2. False-success UX (HIGH, product-integrity)

"Assignment Published Successfully!" (create_assignment_screen.dart:57) is a green confirmation for an action that persists nothing. Faculty believe the assignment was created server-side. Either implement a real create endpoint (and surface real errors/loading) or relabel the screen as a draft/local-only form.

### A-3. Hard-coded course list diverges from `FacultyService.courses` (HIGH)

`_courses` (create_assignment_screen.dart:21–27) is a 5-item fixture that is never synchronized with the app's canonical `FacultyService.courses` notifier. New enrolled courses will never appear in the dropdown; retired ones linger forever.

### A-4. Max Marks has no numeric validation (MEDIUM)

The field sets `keyboardType: TextInputType.number` (create_assignment_screen.dart:164) but has no validator, no parser, and no `min > 0` rule. Empty or alphabetic input is accepted and "published".

### A-5. No async/submission guard on Publish (LOW)

`_submit` is synchronous — no loading state, no disabled-while-publishing flag. Rapid double-taps produce duplicate SnackBars and double pops. If a real API is ever wired, this becomes a duplicate-submission risk.

### A-6. TextEditingControllers are never disposed (LOW)

`_titleController`, `_descController`, `_marksController` (create_assignment_screen.dart:14–16) are created in the state but no `dispose()` exists. Minor leak per push/pop cycle; surfaces a missing-lifecycle pattern when real input handling arrives.

### A-7. Stale hard-coded due dates (MEDIUM)

All `dueDate` strings in `_assignments` (`28 Mar 2024`, `22 Mar 2024`, `02 Apr 2024` — submissions_screen.dart:17,26,35) are frozen in 2024, and `showDatePicker.lastDate` is hard-coded to `DateTime(2030)` (create_assignment_screen.dart:34). Nothing derives from the clock except the default `_dueDate` (`DateTime.now().add(7 days)`).

### A-8. No refresh / empty / error states on Submissions (LOW)

The list is static: no `RefreshIndicator`, no empty-state widget, no pagination. When real data lands, the screen needs all three.

### A-9. Unguarded division in progress computation (LOW)

`progress = a['submitted'] / a['total']` (submissions_screen.dart:55) will throw on a `total == 0` entry. Safe today only because all three literals use `total: 55`.

### A-10. Detail sheet shows the same hard-coded 4-student fixture for every assignment (MEDIUM)

`_showSubmissionDetails` (submissions_screen.dart:157–204) renders `John Doe / Jane Smith / Mark Wilson / Emma Brown` regardless of the tapped assignment's data. The `"VIEW"` label on submitted rows (lines 241–246) is decorative — not tappable. No per-student drilldown exists.

### A-11. Drawer-only entry points, no quick action (LOW, IA)

Assignments are reachable only via `AppDrawer` CONTENT (app_drawer.dart:106–114). The Quick Actions grid (dashboard_sections.dart:135–152) offers Chat/History/Insights/Support — no assignment entry — and there is no named route or deep link. If assignments become real, discoverability and route definitions must be added.

### A-12. Stringly-typed, unguarded map access (LOW)

`SubmissionsScreen` reads `Map<String, dynamic>` keys with no DTO and no type coercion (`a['submitted'] / a['total']`). The Analytics module has the same pattern; a shared parsing helper would harden both.

---

*End of Assignments Module technical documentation. Companion: `HOME_MODULE.md`, `COURSES_MODULE.md`, `MYCLASS_MODULE.md`, `PROFILE_MODULE.md`, `ANALYTICS_MODULE.md`.*
