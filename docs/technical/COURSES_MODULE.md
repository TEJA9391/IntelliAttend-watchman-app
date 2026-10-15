# IntelliAttend Faculty — Courses Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Courses (Course Catalog + Syllabus/Topics + Course Resources)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`, `docs/technical/PROJECT_STRUCTURE.md`, `docs/technical/HOME_MODULE.md`, `docs/PROJECT_DOCUMENTATION.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [Provider & State Management Wiring](#3-provider--state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`CoursesScreen` — Course Catalog Tab](#5-coursescreen--course-catalog-tab)
6. [Course Card Component](#6-course-card-component)
7. [`CourseTopicsScreen` — Syllabus & Topics](#7-coursetopicsscreen--syllabus--topics)
8. [`ResourcesScreen` — Course Resources](#8-resourcesscreen--course-resources)
9. [`ResourcesController` — Business Logic](#9-resourcescontroller--business-logic)
10. [Repositories](#10-repositories)
11. [Services](#11-services)
12. [Data Models & DTOs](#12-data-models--dtos)
13. [Backend API Reference](#13-backend-api-reference)
14. [Navigation Map](#14-navigation-map)
15. [Sequence Diagrams](#15-sequence-diagrams)
16. [Error Handling & Edge Cases](#16-error-handling--edge-cases)
17. [Performance Engineering](#17-performance-engineering)
18. [Security](#18-security)
19. [Dependencies Used](#19-dependencies-used)
20. [File Inventory](#20-file-inventory)

---

## 1. Module Overview

### 1.1 Purpose

The **Courses Module** is the faculty member's course catalog and per-course knowledge surface. It occupies the **Courses tab** (index `1`) of the main `DashboardScreen` and provides:

- A **read-only list of assigned courses** (subject name, code, section) rendered from the hydration cache.
- A per-course **Syllabus/Topics browser** (`CourseTopicsScreen`) with unit grouping, completion filters, search, and a timeline of topic progress.
- A per-course **Resources library** (`ResourcesScreen`) with two scopes — **My Private** (`faculty_private`) and **College Shared** (`college_shared`) — supporting upload, preview, system share, class share, and SmartBoard push.

### 1.2 Business Goal

- Give faculty an instant, offline-first catalog of every course they teach, derived from their cohort/schedule data.
- Let faculty track **syllabus completion** per topic (completed / in-progress / pending, with student counts) at a glance.
- Provide a **private and shared document store per course** so lecture notes, lab manuals, question banks, and assignments are accessible on-device and pushable to a class session or SmartBoard.

### 1.3 Problem Statement

- Faculty historically track multiple sections across semesters with no single mobile view of "what I teach."
- Syllabus progress is tracked on paper/Excel; no live visibility into how many topics are complete or how many students covered each topic.
- Course materials are scattered (email, drives, USB); no sanctioned per-course library with private vs. institutional scoping.

### 1.4 Solution

- A **cache-first course catalog** (`FacultyService.courses`) populated from the manifest hydration (`FacultyHydrationService`) or derived from cached cohorts — no dedicated API call on tab open.
- A **syllabus unit model** that groups raw topics into 4 logical units with per-unit and per-topic progress derived from `completed_count`/`total_count`.
- A **scoped resource library** with a `scope` field distinguishing private faculty files from college-shared files, backed by presigned URLs for streaming/preview and push endpoints for distribution to sessions/sections.

### 1.5 Target Users

- **Faculty members** (primary). Courses and topics are assigned by admin/backend per faculty email.
- The same backend serves admin and SmartBoard portals; this module only surfaces the faculty-visible slice.

### 1.6 Faculty Workflow (Courses-driven)

```
Dashboard → [Courses tab]
        │
        ▼
┌───────────────────────────────────────────────┐
│ Course Catalog (CoursesScreen)                 │
│  • course card (initials avatar + code chip)   │
└──────────────┬────────────────────────────────┘
               │ tap card
        ┌──────▼──────────────────┐
        │ ResourcesScreen          │──► My Private / College Shared toggle
        │  • Upload (multipart)    │──► Preview (presigned URL + OpenFilex)
        │  • Delete (swipe/menu)   │──► Share (system sheet / to class)
        │  • Push to SmartBoard    │──► Push to section/session
        └─────────────────────────┘
(separate entry) My Class / Home schedule → CourseTopicsScreen
```

---

## 2. Layered Architecture & Data Flow

```
┌────────────────────────────────────────────────────────────────────┐
│  PRESENTATION (lib/Presentation/Features/Courses + Faculty +        │
│                Resources)                                          │
│  CoursesScreen • CourseTopicsScreen • ResourcesScreen              │
│  CustomAppBar • ResourcesController (ChangeNotifier)               │
└──────────────┬─────────────────────────────────────────────────────┘
               │ read() / watch() (Provider)   │ FacultyService.courses (ValueNotifier)
┌──────────────▼─────────────┐   ┌─────────────▼─────────────────────┐
│  CONTROLLER                │   │  STATE (static singletons)        │
│  ResourcesController       │   │  FacultyService.profile/courses   │
│  (ChangeNotifier)          │   │  FacultyService.deriveCourses...  │
└──────┬─────────────────────┘   └───────────────────────────────────┘
       │ calls                     │ feeds from
┌──────▼─────────────────────┐   ┌───────────────────────────────────┐
│  DATA (Repositories)       │   │  HYDRATION                        │
│  ResourceRepository        │   │  FacultyHydrationService          │
│  CourseRepository (home)   │   │  (manifest → cohorts → derive)    │
└──────┬─────────────────────┘   └───────────────────────────────────┘
       │ Dio (interceptors)        │ Hive academicBox
┌──────▼─────────────────────────────────────────────────────────────┐
│  NETWORK + STORAGE                                                 │
│  ApiClient (Dio, auth/security interceptors, cert pinning)         │
│  PersistenceService (academicBox: cohorts, schedule_*, subjects)   │
└────────────────────────────────────────────────────────────────────┘
```

Key data-flow rule: **the Courses tab never blocks on the network.** It renders whatever is in `FacultyService.courses` (populated from Hive cache or derived from cohorts). The authoritative refresh path is the manifest hydration triggered during app bootstrap (see HOME_MODULE §13 for the hydration timeline).

---

## 3. Provider & State Management Wiring

Wiring in `lib/main.dart` (lines 156–192):

```
ChangeNotifierProvider<SecurityController>
└── MultiProvider
    ├── Provider<ApiClient>                                create: ApiClient()
    ├── ProxyProvider<ApiClient, CourseRepository>         (also used by Home)
    ├── ProxyProvider<ApiClient, AttendanceRepository>
    ├── ProxyProvider<ApiClient, AuthRepository>
    ├── ChangeNotifierProxyProvider2<Course, Attendance, DashboardController> (lazy)
    ├── ProxyProvider<ApiClient, ResourceRepository>       create: ResourceRepository(apiClient)
    └── ChangeNotifierProxyProvider<ResourceRepository, ResourcesController>
            create/update: ResourcesController(repo)  (lazy)
```

Observations specific to this module:

- `CoursesScreen` is **not** provider-driven. It binds directly to the static `FacultyService.courses` `ValueNotifier<List<Map<String, dynamic>>>` via `ValueListenableBuilder`. There is no `CoursesController`.
- `ResourcesScreen` is provider-driven. It reads the globally provided `ResourcesController` (lazy) via `context.read()` (load) and `Consumer<ResourcesController>` (render). The same provider instance is shared by every `ResourcesScreen` pushed onto the stack — meaning state persists between different course resource screens (resources from a previous course remain in memory until `loadResources()` overwrites them).
- `CourseTopicsScreen` is a pure `StatefulWidget` receiving a `ScheduledClass` (immutable data object) — no provider, no controller. All derivation (`_units`, filters, progress) is computed in the widget.

---

## 4. Screen Structure — Widget Tree

```
DashboardScreen (IndexedStack)
└── [1] CoursesScreen  (CustomAppBar + body)
     ├── CustomAppBar (title "Courses", subtitle = department, no back button)
     └── ValueListenableBuilder<FacultyService.courses>
          ├── Empty state (icon + "No courses assigned")
          └── ListView.builder → _buildCourseCard(course)
               └── GestureDetector ──tap──► ResourcesScreen(courseCode, courseName)

ResourcesScreen  (navigated, own Scaffold)
├── AppBar (back + course name + code)
├── FloatingActionButton.extended "Upload"
└── Column
    ├── _buildToggleBar (My Private / College Shared)
    └── Consumer<ResourcesController>
         ├── loading spinner
         ├── empty state
         └── RefreshIndicator → ListView.builder
              ├── _buildSwipeableCard (Dismissible for private scope)
              └── _buildResourceCard (icon by type, tap→open, 3s long-press→share-to-class, ⋮ menu)

CourseTopicsScreen  (navigated, own Scaffold)
├── custom PreferredSize app bar (back, subjectCode, "Today's Topics", search toggle)
└── Column
    ├── [if search open] _buildSearchBar (200 ms debounce)
    ├── _buildProgressOverview (AnimatedBuilder + LinearProgressIndicator)
    ├── _buildFilterChips (All / Completed / In Progress / Pending)
    └── Expanded
         ├── filtered mode → _buildFilteredTopicList
         └── unit mode → _buildUnitList → ExpansionTile(_SyllabusUnit)
              └── _buildTopicItem (timeline connector, status badges, student progress)
```

---

## 5. `CoursesScreen` — Course Catalog Tab

**File:** `lib/Presentation/Features/Courses/courses_screen.dart` (230 lines)

`CoursesScreen` is a `StatefulWidget` (stateless in practice — no state fields) mounted at tab index `1` of the `DashboardScreen` `IndexedStack`.

### 5.1 AppBar

- Uses `CustomAppBar` (`lib/Presentation/Features/Faculty/Components/custom_app_bar.dart`).
- `title: "Courses"`, `subtitle: profile?.department ?? "Computer Science & Engineering"`.
- `showBackButton: false` (it is a root tab, not a pushed route).

### 5.2 Body / data binding

```dart
ValueListenableBuilder<List<Map<String, dynamic>>>(
  valueListenable: FacultyService.courses,
  builder: (context, courseList, _) {
    if (courseList.isEmpty) → empty state (icon + "No courses assigned")
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 100),   // 100 = room for bottom nav
      physics: BouncingScrollPhysics,
      itemCount: courseList.length,
      itemBuilder: (context, index) => _buildCourseCard(courseList[index]),
    );
  },
)
```

### 5.3 Course source-of-truth chain

`FacultyService.courses` is populated by two paths (see §11):

1. **Cache path** — `FacultyService.loadFromCache()` reads `academicBox.get('courses')`; if empty, calls `deriveCoursesFromCohorts()`.
2. **Derived path** — `deriveCoursesFromCohorts()` reads cached `cohorts`, de-duplicates by `course_code`/`subject_code`, and emits `{id, code, course, name, short_name}` entries.

### 5.4 Course card field access

Each card reads raw map keys with fallbacks (important for contract resilience):

| Display | Primary key | Fallback |
|---|---|---|
| subject | `course` | `name` → `'Unknown'` |
| code | `code` | `id` → `''` |
| section (Resources share sheets) | `section` | — |

---

## 6. Course Card Component

Internal to `courses_screen.dart` (`_buildCourseCard`, `_getInitials`, `_getCourseColor`).

### 6.1 Initials derivation (`_getInitials`)

Deterministic, three-tier heuristic:

1. If `code.length <= 4` **and** `code` has no digit → return `code.toUpperCase()` (e.g. `MATH`).
2. If subject has **≥ 3 words** → first letter of first 3 words, excluding `and`/`&` (e.g. "Data Structures and Algorithms" → `DSA`).
3. If subject has **2 words** → first letter of both (e.g. "Operating Systems" → `OS`).
4. Otherwise → first `min(code.length, 3)` chars of `code` uppercased.

### 6.2 Accent color (`_getCourseColor`)

- Fixed 8-color palette (teal, pink, blue, amber, violet, green, red, orange).
- Index = `(initials.hashCode + initials.length) % palette.length`.
- Used for the 56×56 avatar container background (`color.withValues(alpha: 0.15)`) and initial text.

### 6.3 Card layout

- 20px radius container; dark-mode aware (`Color(0xFF1E1E1E)` vs white; border `Color(0xFFE2E8F0)`).
- Row: initials avatar → column(subject, code chip + "Resources" meta) → chevron.
- Code chip: `AppTheme.jetBrainsMono`, teal accent on `accentTeal.withValues(alpha: 0.1)`.
- Tap → `HapticFeedback.mediumImpact()` + `Navigator.push(MaterialPageRoute(ResourcesScreen(courseCode: code, courseName: subject)))`.

---

## 7. `CourseTopicsScreen` — Syllabus & Topics

**File:** `lib/Presentation/Features/Faculty/course_topics_screen.dart` (946 lines)

### 7.1 Input contract

```dart
CourseTopicsScreen({required ScheduledClass scheduledClass, int initialTopicIndex = -1})
```

- `scheduledClass.topics` — `List<CourseTopic>` (see §12). If empty → unit list empty state ("Topics have not been added yet").
- `initialTopicIndex` — when ≥ 0, auto-expands the owning unit, highlights the topic, scrolls it into view, and clears the highlight after 2 s (`_highlightTimer`).

### 7.2 Syllabus unit derivation (`_units`)

- `unitSize = (topics.length / 4).ceil().clamp(2, 4)` — topics are split into **≈4 units** of 2–4 topics each, labelled `Unit 1..N`.
- `_SyllabusUnit` is a private immutable holder (`title`, `topics`).

### 7.3 State & filtering

- `_searchQuery` (search toggle + TextField; 200 ms debounce timer — note the debounce callback body is a no-op; the `setState` fires on every `onChanged`).
- `_selectedFilter` chips:
  - `0 = All`
  - `1 = Completed` → `t.isCompleted`
  - `2 = In Progress` → `!isCompleted && completedCount > 0`
  - `3 = Pending` → `!isCompleted && completedCount == 0`
- When search or filter is active, the unit list is replaced by a flat filtered list.

### 7.4 Progress overview card

- `_progressPct = completedTopics / totalTopics`.
- Animated via `_animController` (600 ms) — the progress bar value is `_progressPct * _animController.value`.
- Footer text: `"$completedCount / $totalCount Topics Completed"`.

### 7.5 Unit tiles

- `ExpansionTile` with expand/collapse animation, haptic on toggle.
- Leading badge: green check when all topics in the unit complete, else unit number.
- Subtitle: `"X / Y Topics"`, 60×4 px progress bar, `pct%`.
- `_expandedUnits` is a growable `List<bool>` indexed by unit; unit 0 auto-expands by default.

### 7.6 Topic item

Per-topic row with:

- **Timeline connector** (`_buildTimelineConnector`): 22 px circle — current = glowing teal dot (`0x2634D399` shadow, `Color(0xFF34D399)`), completed = green check, else muted dot; vertical connector line between rows.
- **Status badges**: `Completed` (green), `Current` (green outline, first incomplete topic), `In Progress` (amber).
- **Student progress** row (when `topic.totalCount > 0`): `"${completedCount} / ${totalCount} Students"` + 50×3 px progress bar color-keyed by state.
- **Completed meta**: `"Completed Today"` caption with check icon.
- Completed topics render with `TextDecoration.lineThrough`; future topics are dimmed.

### 7.7 Current-topic determination

`_getFirstIncompleteIndex()` returns the index of the first non-completed topic (or 0 when all complete) — drives the `Current` badge.

### 7.8 Scroll-to-topic

`_scrollToTopicIndex` computes an approximate offset using fixed row heights (72 px unit header, 56 px per topic) and animates via `_scrollController`. Height assumptions can drift if item layout changes.

### 7.9 Entry points

- Home `schedule_section.dart:749` — schedule carousel → `CourseTopicsScreen(scheduledClass: c, initialTopicIndex: i)` (topic timeline tap).
- `my_class_screen.dart:160/168` — My Class subject card → `CourseTopicsScreen(scheduledClass: ...)` with its own `_dummyTopicsBank`.

> ⚠️ Note the topics payload is **not** fetched from a dedicated topics API. It arrives embedded in the schedule/manifest (`topics` list on each slot). When absent, callers inject dummy topics (see §11.3 / Appendix).

---

## 8. `ResourcesScreen` — Course Resources

**File:** `lib/Presentation/Features/Resources/resources_screen.dart` (1080 lines)

### 8.1 Input contract & initialization

```dart
ResourcesScreen({String? courseCode, String? courseName})
```

On `initState`, a post-frame callback invokes `context.read<ResourcesController>().loadResources()` (parallel fetch of private + college lists).

### 8.2 AppBar & FAB

- Transparent `AppBar`, back button, title = `courseName ?? "Resources"`, subtitle = `courseCode` (teal, mono not used).
- `FloatingActionButton.extended` **Upload** → `_showUploadSheet`.

### 8.3 Scope toggle bar

- Segmented pill (`_showCollegeShared`): **My Private** | **College Shared`.
- Rendering selects `controller.collegeResources` vs `controller.myResources`.

### 8.4 Resource list

- `Consumer<ResourcesController>`:
  - `isLoading` → centered spinner.
  - empty → folder icon + "No resources yet" + "Tap Upload to add your first resource".
  - else → `RefreshIndicator(onRefresh: loadResources)` + `ListView.builder`.
- Private resources are wrapped in `Dismissible` (horizontal, red "Delete" background on both sides, `confirmDismiss` → dialog). College-shared resources are **not** dismissible (read-only).

### 8.5 Resource card

- File-type icon mapping (`_buildResourceCard`): PDF → red `picture_as_pdf`; PPT → orange `slideshow`; DOC → blue `description`; image → green `image`; else `insert_drive_file`.
- Meta row: `fileSizeFormatted • createdAtFormatted`.
- Interactions:
  - **Tap** → `_openResource` (preview).
  - **Long-press 3 s** (`_longPressTimer`) → `_showShareToClassSheet` (haptic heavy impact).
  - **⋮ menu** → `_showResourceMenu` (Share / Push to SmartBoard / Delete — delete only when scope ≠ college_shared).

### 8.6 Preview flow (`_openResource`)

1. `_showLoadingDialog('Opening...')`.
2. `controller.getPresignedUrl(resource.id)` via authenticated `ApiClient`.
3. On success, download to `<tempDir>/preview_<id>_<fileName>` using a **plain `Dio()`** (unauthenticated — presigned URL is bearer of the permission).
4. `OpenFilex.open(tempPath)`.
5. Errors → dismiss dialog + red snackbar ("Unable to preview this file.").

### 8.7 Share flow (`_shareFile`)

1. Same presigned-URL path.
2. Download to `<tempDir>/share_<id>_<fileName>`.
3. `Share.shareXFiles([XFile(tempPath)], text: fileName)`.

### 8.8 Share-to-class (3 s long-press) & Push to SmartBoard

- Both open a class picker sheet listing `FacultyService.courses.value`.
- Each row shows subject, `code • Sec <section>`, and a send/cast icon.
- **Both paths** ultimately call `controller.pushToSection(resource.id, classCode)` — i.e. the course **code** string is sent as `section_id` to the push endpoint. (See Appendix — potential contract mismatch.)
- "Push to SmartBoard" sheet is scroll-controlled (`DraggableScrollableSheet`, 75% initial, up to 90%).
- Feedback: transient snackbar ("Pushing to X (CODE)…"), then success ("Shared to X") or failure (`controller.error`).

### 8.9 Upload sheet (`_showUploadSheet`)

State kept in local closures with `StatefulBuilder(setSheetState)`:

- **File picker**: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: [pdf, doc, docx, ppt, pptx, xls, xlsx, txt, csv, jpg, jpeg, png, zip])`.
- **Category chips**: Lecture Notes / Assignment / Lab Manual / Question Bank / Other.
- **Description**: optional 2-line TextField.
- **Validation** before upload: file selected; `FacultyService.profile.value` non-null & `facultyId` non-empty ("Missing authentication"); category non-empty.
- **Upload**: `ResourcesController.uploadResource(filePath, fileName, facultyId, courseId: widget.courseCode, category, description)` with live progress ring + linear bar.
- Success → pop sheet + green snackbar; failure → inline red error banner with `rc.error`.

---

## 9. `ResourcesController` — Business Logic

**File:** `lib/Presentation/Features/Resources/resources_controller.dart` (122 lines)

`ChangeNotifier` wrapping `ResourceRepository`.

| Field | Type | Meaning |
|---|---|---|
| `myResources` | `List<ResourceItem>` | Private scope list |
| `collegeResources` | `List<ResourceItem>` | College-shared list |
| `isLoading` | `bool` | True during `loadResources()` |
| `isUploading` / `uploadProgress` | `bool` / `double` | Upload state & 0→1 progress |
| `error` | `String?` | Last operation error message |

### Methods

| Method | Behavior |
|---|---|
| `loadResources()` | `Future.wait([getMyResources(), getCollegeResources()])`; sets both lists; toggles `isLoading`. |
| `uploadResource(...)` | Forwards to repo with `onProgress` callback updating `uploadProgress`; on success reloads lists (`await loadResources()`) and returns `true`. |
| `deleteResource(id)` | On success removes id from **both** lists (defensive) and returns `true`; else sets `error`. |
| `getPresignedUrl(id)` | Passthrough to repo (returns `Map`). |
| `pushToSession(id, sessionId)` | Passthrough; sets `error` on failure. |
| `pushToSection(id, sectionId)` | Passthrough; sets `error` on failure. |
| `clearError()` | Clears `error`. |

Note: `pushToSession` is defined but **not called from `ResourcesScreen`** in the current code — only `pushToSection` is used (dead API surface at UI level).

---

## 10. Repositories

### 10.1 `CourseRepository` — `lib/Data/Repositories/course_repository.dart`

Owned by the Home module (see HOME_MODULE §12) but relevant here because the same `/api/v1/faculty/sync` payload drives `ScheduledClass.topics` consumed by `CourseTopicsScreen`.

Key mechanics:
- `watchSchedule(email, dayName)` / `watchTodaySchedule(email)` — single-emission `StreamController`; emits cached schedule first, then refreshes from `GET /api/v1/faculty/sync`, filters by `day_of_week`, sorts by start time, re-caches.
- Day keys: `schedule_<daylowercase>` in `academicBox`.
- Reads `data['schedule_list']` from the sync response (see Appendix — contract drift with hydration's `data['schedule']`).

### 10.2 `ResourceRepository` — `lib/Data/Repositories/resource_repository.dart`

Wraps `ApiClient`. All methods return either a `List<ResourceItem>` or a result map `{success, error, ...}`.

| Method | Endpoint | Notes |
|---|---|---|
| `getMyResources({scope, subjectCode})` | `GET /api/v1/faculty/resources` | query `scope=faculty_private`, optional `subject_code` |
| `getCollegeResources({subjectCode})` | `GET /api/v1/faculty/college-resources` | optional `subject_code` |
| `uploadResource(...)` | `POST /api/v1/faculty/resources/upload` | multipart; see §10.3 |
| `deleteResource(id)` | `DELETE /api/v1/faculty/resources/{id}` | |
| `getPresignedUrl(id)` | `GET /api/v1/faculty/resources/{id}/presigned-url` | |
| `pushToSession(id, sessionId)` | `POST /api/v1/faculty/resources/{id}/push-to-session` | body `{session_id}` |
| `pushToSection(id, sectionId)` | `POST /api/v1/faculty/resources/{id}/push-to-section` | body `{section_id}` |

### 10.3 Upload guard rails (`uploadResource`)

- `isSupportedFile` extension allow-list (mirrors the FilePicker list).
- File must exist on disk.
- **50 MB hard cap** → `"File too large. Maximum size is 50 MB."`
- `facultyId` and `category` required.
- `_detectMimeType` maps extension → MIME (docx/pptx/xlsx explicit OOXML types).
- `MultipartFile.fromFile`; form fields: `faculty_id`, optional `course_id`/`subject_id`, `category`, optional `description`, `filename`, `mime_type`, `file`.
- Dio `sendTimeout`/`receiveTimeout` = **120 s** (large-file friendly); `onSendProgress` drives the UI progress.
- HTTP 400 → aggregates all validation keys into `validation_errors` + first `message/detail/error`.
- Timeout → "Server unavailable. Please try again."; connection error → "Server unavailable. Check your internet connection."

---

## 11. Services

### 11.1 `FacultyService` — `lib/Services/faculty_service.dart`

Static `ValueNotifier` singleton the Courses catalog depends on:

```dart
static final ValueNotifier<FacultyProfile?> profile;
static final ValueNotifier<List<Map<String, dynamic>>> courses;   // ← catalog source
```

**Catalog population paths:**

1. `loadFromCache()` → reads `academicBox.get('courses')`; if the persisted list is empty, falls back to `deriveCoursesFromCohorts()`.
2. `deriveCoursesFromCohorts()` → reads `academicBox.get('cohorts')`; for each cohort map, extracts `course_code`/`subject_code`, `course_name`/`subject_name`, `short_name`; de-duplicates by code; writes `courses.value`; persists a `subjects_cache` map via `PersistenceService.saveSubjectsCache()`.
3. Network refresh of the catalog happens **indirectly**: `initializeListeners()` → `FacultyHydrationService.syncIfNeeded()` → `_persistManifest()` persists `cohorts` → `deriveCoursesFromCohorts()` runs again → `courses.value` updates → the Courses tab rebuilds via `ValueListenableBuilder`.

`clear()`/`resetToDefaults()` reset `courses.value = []` on logout.

### 11.2 `FacultyHydrationService` — `lib/Services/faculty_hydration_service.dart`

- `syncIfNeeded()` short-circuits to `SyncResult.unchanged` when a manifest hash + profile + non-empty cohorts already exist locally.
- `_persistManifest()` writes `cohorts`, per-day `schedule_<day>`, `rosters`, `adhoc_sessions`, `manifest_hash`, `manifest_version`, then invokes `deriveCoursesFromCohorts()` and the `onDataChanged` hook.
- `_wipeLocalData()` deletes `cohorts`, `schedule_*`, `roster_*`, `adhoc_sessions`, `courses`, `subjects_cache`, `student_rosters`.

### 11.3 Dummy topic injection (shared with Home)

`DashboardController._withDummyTopics` (`dashboard_controller.dart:88–122`):
- If a `ScheduledClass` already has topics → returned as-is.
- Else a deterministic slice of `_dummyTopicsBank` (length `(subjectCode.hashCode % 4 + 5).clamp(5, 8)`) is injected.

Because `CourseTopicsScreen` renders `scheduledClass.topics`, these synthetic topics can appear in the syllabus view whenever the backend omits the `topics` array. `my_class_screen.dart:122` keeps its own parallel `_dummyTopicsBank`.

---

## 12. Data Models & DTOs

### 12.1 Raw course map (no model class)

`FacultyService.courses` is `List<Map<String, dynamic>>`. Canonical keys:

| Key | Meaning |
|---|---|
| `id` | Course identifier (cohort code) |
| `code` | Subject/course code |
| `course` / `name` | Subject display name |
| `short_name` | Short name (from cohort) |
| `section` | Section label (used in share pickers) |

Because there is **no `Course` model class**, type safety and JSON schema validation are delegated to the UI's fallback chains.

### 12.2 `CourseTopic` — `lib/Data/Models/Faculty/course_topic.dart`

| Field | Type | JSON keys |
|---|---|---|
| `name` | `String` | `name` / `topic_name` |
| `isCompleted` | `bool` | `is_completed` / `completed` |
| `completedCount` | `int` | `completed_count` |
| `totalCount` | `int` | `total_count` |

Derived UI states: `isCompleted`, `isInProgress` (`!completed && count>0`), `isFuture`.

### 12.3 `ScheduledClass` — `lib/Data/Models/Faculty/scheduled_class.dart`

Legacy timetable model (migration-compatible; new code prefers `TimetableSlot` from the shared package). Carries `topics: List<CourseTopic>` embedded per class. Also provides `toTimetableSlot()` (engine bridge) and legacy `startTime`/`endTime` string + `startMinutes`/`endMinutes`.

`fromJson` resolves `subject_name`/`course_name`/`title`/`name`/`subject_id`; `subject_code`/`course_code`/`code`/`subject_id`; `room_number`/`classroom_id`; day via `_parseDay`.

### 12.4 `ResourceItem` — `lib/Data/Models/Faculty/resource_model.dart`

| Field | Type | JSON key |
|---|---|---|
| `id` | `String` | `id` |
| `facultyId` | `String` | `faculty_id` |
| `fileName` | `String` | `file_name` |
| `fileSize` | `int` | `file_size` |
| `mimeType` | `String` | `mime_type` |
| `scope` | `String` | `scope` (`faculty_private` / `college_shared`) |
| `securityStatus` | `String` | `security_status` (e.g. `UNKNOWN`) |
| `createdAt` | `String?` | `created_at` |
| `institutionId` | `String?` | `institution_id` |
| `allowedSections` | `List<String>` | `allowed_sections` |
| `subjectCode` | `String?` | `subject_code` |

Derived getters: `fileSizeFormatted`, `fileExtension`, `createdAtFormatted`, and type predicates `isPdf/isPowerpoint/isWord/isImage` (mime OR extension based).

---

## 13. Backend API Reference

Base URL (default): `https://api-dev.balaseetharamanjaneyulu.com` (env `API_BASE_URL`).

All endpoints ride the authenticated `ApiClient` (JWT bearer via Firebase `getIdToken`, `X-Device-*` headers, cert pinning, retry, force-logout on 401).

| # | Method | Path | Purpose | Auth |
|---|---|---|---|---|
| 1 | GET | `/api/v1/faculty/sync` | Full faculty manifest: `profile`, `cohorts`, `schedule`, `rosters`, `adhoc_sessions`, `manifest_hash` (source of course catalog + topics) | Firebase JWT |
| 2 | GET | `/api/v1/faculty/resources` | Private resources; query `scope`, optional `subject_code` | JWT |
| 3 | GET | `/api/v1/faculty/college-resources` | College-shared resources; optional `subject_code` | JWT |
| 4 | POST | `/api/v1/faculty/resources/upload` | Multipart upload (≤ 50 MB, 120 s timeout) | JWT |
| 5 | DELETE | `/api/v1/faculty/resources/{id}` | Delete a resource | JWT |
| 6 | GET | `/api/v1/faculty/resources/{id}/presigned-url` | Presigned URL for streaming preview/share | JWT |
| 7 | POST | `/api/v1/faculty/resources/{id}/push-to-session` | Push resource to an active session (`session_id`) | JWT |
| 8 | POST | `/api/v1/faculty/resources/{id}/push-to-section` | Push resource to a section (`section_id`) | JWT |

### Contract notes

- **List endpoints return a JSON array**; `ResourceItem.fromJson` tolerates missing fields.
- **Upload** returns a JSON map; success keys include `id`/file metadata; failures surface `message`/`detail`/`error`.
- **Presigned URL** response: map containing a `url` (the UI expects `result['url']`).
- `push-to-section` is invoked from the UI with the **course code** in `section_id` (see Appendix).

---

## 14. Navigation Map

```
DashboardScreen (IndexedStack, _currentIndex)
   │  index 1
   ▼
CoursesScreen ──tap course──► ResourcesScreen(courseCode, courseName)
                                    ├── (no further pushes; sheets/dialogs only)
                                    └── Upload / Share / Push sheets (modal)

ScheduleSection (Home) ──tap topic──► CourseTopicsScreen(scheduledClass, initialTopicIndex)
MyClassScreen ──tap subject──► CourseTopicsScreen(scheduledClass)
```

All navigations use imperative `Navigator.push(MaterialPageRoute(...))` (no named routes). `CustomAppBar`/AppBar back buttons use `Navigator.maybePop(context)`.

---

## 15. Sequence Diagrams

### 15.1 Catalog rendering (cold start)

```
App bootstrap
  │
  ├─► FacultyService.loadBaseProfile() ──► loadFromCache()
  │      ├─ profile? ← academicBox 'profile'
  │      └─ courses? ← academicBox 'courses'  ──(empty)──► deriveCoursesFromCohorts()
  │             cohorts ← academicBox 'cohorts'
  │             de-dupe by course_code → courses.value = [...]
  │
  ├─► DashboardScreen builds IndexedStack (tab 1 = CoursesScreen)
  │      CoursesScreen: ValueListenableBuilder on FacultyService.courses
  │      ◄── renders cached/derived list instantly (no network on tab open)
  │
  └─► FacultyService.initializeListeners() (background)
         └─► FacultyHydrationService.syncIfNeeded()
                └─► GET /faculty/sync
                       └─► _persistManifest(): cohorts → deriveCoursesFromCohorts()
                              ◄── courses.value updated → Courses tab re-renders
```

### 15.2 Resources load & upload

```
ResourcesScreen.initState
  └─► postFrame → ResourcesController.loadResources()
         └─► Future.wait( getMyResources(), getCollegeResources() )
                GET /faculty/resources?scope=faculty_private
                GET /faculty/college-resources
         └─► notifyListeners() → Consumer re-renders both tabs

Upload
  └─► FAB → _showUploadSheet (FilePicker → category → description)
         └─► ResourcesController.uploadResource(...)
                └─► ResourceRepository.uploadResource
                       multipart POST /faculty/resources/upload (progress cb)
                       ├─ 200/201 → reload lists → "Uploaded successfully"
                       └─ error  → inline error banner (rc.error)
```

### 15.3 Preview & push

```
Tap card → _openResource
  └─► getPresignedUrl(id)  ──GET /resources/{id}/presigned-url──► {url}
         └─► plain Dio download(url → temp/preview_<id>_<name>)
                └─► OpenFilex.open(tempPath)

Long-press 3 s / menu → class picker
  └─► pushToSection(id, courseCode)
         └─► POST /resources/{id}/push-to-section {section_id: courseCode}
                ├─ success → "Shared to <class>"
                └─ failure → controller.error snackbar
```

---

## 16. Error Handling & Edge Cases

| Scenario | Handling |
|---|---|
| Empty catalog | `CoursesScreen` empty state: "No courses assigned" / "Courses will appear here once assigned". |
| Corrupt/empty cohorts cache | `deriveCoursesFromCohorts` try/catch → leaves `courses.value` empty; hydration `_wipeLocalData` + forced resync on `SyncResult` mismatch. |
| Missing `topics` in schedule | Callers inject deterministic dummy topics (see §11.3). |
| Empty topics list in `CourseTopicsScreen` | "Topics have not been added yet" empty state. |
| No search/filter matches | "No topics match your search". |
| Resource list fetch failure | Repos catch `DioException`/generic and return `[]` — UI shows "No resources yet" (silent degradation, no error banner). |
| Upload: no file / no auth / no category | Client-side validation → inline banner. |
| Upload: unsupported type / missing file / >50 MB | Repo-level guard → `{success:false, error:...}`. |
| Upload: HTTP 400 validation | All keys collected into `validation_errors`; first `message/detail/error` surfaced. |
| Upload: timeout / connection error | Repo maps to friendly messages. |
| Preview/share failure | Red snackbar "Unable to preview/share this file."; loading dialog always popped. |
| Delete confirmation | Swipe and menu both route through `AlertDialog`; cancel returns `false`. |
| `mounted` after async | `_openResource`/`_shareFile` guard with `mounted` before using `context`. |
| SmartBoard/no classes | Picker guarded: "No classes assigned" snackbar. |

---

## 17. Performance Engineering

- **Zero-network catalog**: tab open is a Hive read + `ValueListenableBuilder` — no spinner, no API call.
- **Derived, not stored**: catalog is recomputed from cohorts at hydration time and cached once; `courses` cache is deliberately deleted during `_wipeLocalData` to avoid stale courses.
- **Parallel list fetch**: `loadResources()` uses `Future.wait` for private + college lists.
- **List recycling**: `ListView.builder` in both `CoursesScreen` and `ResourcesScreen` (no eager list materialization).
- **Animated progress**: `_animController` drives progress-bar fill once (600 ms) rather than per-frame layout work.
- **Debounce**: search input uses a 200 ms debounce timer (currently a no-op body — see Appendix).
- **Scroll-control math**: `_scrollToTopicIndex` uses fixed row heights (72/56 px) for O(1) offset computation — cheap but fragile to layout changes.
- **Images/avatars**: course avatars are text initials on colored containers — zero image decoding cost.

---

## 18. Security

- **Authenticated fetch**: every resource API call goes through `ApiClient` interceptors (JWT bearer, device headers, cert pinning; force-logout on 401).
- **Presigned URLs**: downloads use a *plain* `Dio()` with no auth headers — the short-lived signed URL is the credential; it is never cached or logged.
- **Upload validation** server-side + client-side (extension allow-list, 50 MB cap) reduces abuse surface.
- **Scope enforcement**: `college_shared` resources are read-only on the client (`Dismissible` + delete option suppressed); delete UI is never offered for shared files.
- **Temp-file hygiene**: preview/share files go to the OS temp directory with the resource id in the name; not persisted in app storage.
- **Secret handling**: no credentials in code; `API_BASE_URL`/`PINNED_CERT_FINGERPRINTS` come from environment/dart-define.
- **Facility**: no user-generated content is interpolated into HTML/WebView — all rendering is native Flutter widgets.

---

## 19. Dependencies Used

| Package | Role in this module |
|---|---|
| `provider` | `ResourcesController` exposure (`Consumer`, `read`) |
| `google_fonts` | Inter/JetBrains Mono typography |
| `file_picker` | Upload file selection |
| `dio` | API calls, multipart upload with progress, presigned downloads |
| `path_provider` | Temp directory for preview/share staging |
| `open_filex` | Open downloaded files in native viewers |
| `share_plus` | System share sheet (`shareXFiles`) |
| `url_launcher` | Deep-link/URL launching (imported in resources screen) |
| `firebase_auth` | JWT identity for authenticated resource calls |
| `hive` (via `persistence_service`) | `academicBox` (cohorts/courses/subjects cache) |
| `intelli_attend_shared` | `TimetableSlot` bridge used by `ScheduledClass` |

---

## 20. File Inventory

### 20.1 Courses feature

| File | Role |
|---|---|
| `lib/Presentation/Features/Courses/courses_screen.dart` | Course catalog tab: list, card, initials/color derivation, empty state |
| `lib/Presentation/Features/Faculty/course_topics_screen.dart` | Syllabus browser: units, filters, search, timeline, progress |
| `lib/Presentation/Features/Faculty/Components/custom_app_bar.dart` | Reusable app bar used by the catalog |

### 20.2 Resources feature

| File | Role |
|---|---|
| `lib/Presentation/Features/Resources/resources_screen.dart` | Resource library: toggle, list, upload, preview, share, push |
| `lib/Presentation/Features/Resources/resources_controller.dart` | `ChangeNotifier` state for resources/upload/errors |

### 20.3 Data layer

| File | Role |
|---|---|
| `lib/Data/Repositories/course_repository.dart` | Schedule/sync fetch + cache (topics source) |
| `lib/Data/Repositories/resource_repository.dart` | Resource CRUD, upload, presigned URL, push |
| `lib/Data/Models/Faculty/course_topic.dart` | `CourseTopic` model |
| `lib/Data/Models/Faculty/scheduled_class.dart` | `ScheduledClass` + embedded topics |
| `lib/Data/Models/Faculty/resource_model.dart` | `ResourceItem` model + derived getters |

### 20.4 Services / state

| File | Role |
|---|---|
| `lib/Services/faculty_service.dart` | `courses`/`profile` notifiers, cache load, cohort derivation |
| `lib/Services/faculty_hydration_service.dart` | Manifest sync that refreshes cohorts/courses |
| `lib/main.dart` | Provider graph (`ResourcesController`, `ResourceRepository`) |

---

## Appendix — Known Design Notes / Technical Debt

1. **No `Course` model class.** `FacultyService.courses` is `List<Map<String, dynamic>>`; all field access is string-keyed with fallbacks (`course`/`name`, `code`/`id`). A typed `Course` DTO with `fromJson` would centralize schema handling and catch backend drift at one point.
2. **`section` is read in the resource share pickers but not in the catalog card.** The catalog card shows only subject + code; if sections matter per course, the card should display `section` too.
3. **Push-to-section uses course code as `section_id`.** Both "Share to Class" and "Push to SmartBoard" call `pushToSection(id, courseCode)`. If the backend expects a real section id, this is a contract mismatch; if it accepts course codes, the parameter naming is misleading. `pushToSession` is defined but never invoked from the UI.
4. **Dummy topics injection.** Both `dashboard_controller.dart` and `my_class_screen.dart` fabricate topics when the backend omits `topics`, which then render in `CourseTopicsScreen`. Real syllabus data (or an explicit "syllabus not published" empty state) should replace this so progress is truthful.
5. **Silent list-fetch degradation.** `ResourceRepository.getMyResources/getCollegeResources` swallow `DioException` and return `[]`, rendering "No resources yet" even on network failure — indistinguishable from a genuinely empty library. An error/retry state is missing.
6. **Debounce no-op.** The 200 ms `_searchDebounce` timer's callback body is empty; filtering runs on every keystroke via the `onChanged` `setState`. For long topic lists the debounce should actually gate filtering.
7. **Hard-coded scroll offsets.** `_scrollToTopicIndex` assumes 72 px unit headers and 56 px topic rows; any layout change silently breaks auto-scroll accuracy.
8. **`security_status` defaults to `UNKNOWN`** in `ResourceItem.fromJson` and is never surfaced in the UI — dead data unless the product plans to show file security states.
9. **ResourcesController shared across courses.** A single lazy `ResourcesController` serves all `ResourcesScreen` instances; navigating from course A → resources → back → course B reuses the instance until `loadResources()` overwrites it (a flash of course A's data is possible).
10. **Shared-pkg contract drift.** `course_repository.dart` reads `data['schedule_list']` while `faculty_hydration_service.dart` reads `data['schedule']` from the same `/faculty/sync` endpoint; `ScheduledClass.topics` therefore depends on whichever shape the backend currently emits (same risk flagged in HOME_MODULE Appendix).

---
