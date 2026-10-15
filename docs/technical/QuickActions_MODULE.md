# IntelliAttend Faculty - Quick Actions Module - Enterprise Technical Documentation

Version: 1.0 · Scope: `lib/Presentation/Features/QuickActions/` + supporting Data layer
Companion: `MYCLASS_MODULE.md` (hub & legacy lineage), `HOME_MODULE.md`, `COURSES_MODULE.md`

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [Provider & State Management Wiring](#3-provider--state-management-wiring)
4. [Screen Structure - Widget Tree](#4-screen-structure---widget-tree)
5. [Entry Points & Navigation Map](#5-entry-points--navigation-map)
6. [MarkAttendanceController - the Shared Attendance Engine](#6-markattendancescontroller---the-shared-attendance-engine)
7. [Mark Attendance - Live Hub Path](#7-mark-attendance---live-hub-path)
8. [Mark Attendance - Dashboard Flow (orphaned) & ModeSelectionScreen](#8-mark-attendance---dashboard-flow-orphaned--modeselectionscreen)
9. [Attendance Modes - QR, NFC, Face, Bluetooth](#9-attendance-modes---qr-nfc-face-bluetooth)
10. [Manual & Bluetooth Live Session (AttendanceSessionScreen)](#10-manual--bluetooth-live-session-attendancessessionscreen)
11. [Review & Submission (ReviewScreen)](#11-review--submission-reviewscreen)
12. [Attendance Records Flow](#12-attendance-records-flow)
13. [Class Students Flow](#13-class-students-flow)
14. [Faculty Messaging Flow](#14-faculty-messaging-flow)
15. [Export Reports Flow](#15-export-reports-flow)
16. [Services - Draft Autosave & Offline Sync](#16-services---draft-autosave--offline-sync)
17. [Data Models & DTOs](#17-data-models--dtos)
18. [Repositories - Dummy vs Real](#18-repositories---dummy-vs-real)
19. [Backend API Reference](#19-backend-api-reference)
20. [WebSocket Real-Time Protocol](#20-websocket-real-time-protocol)
21. [Sequence Diagrams](#21-sequence-diagrams)
22. [Error Handling & Edge Cases](#22-error-handling--edge-cases)
23. [Performance & Security](#23-performance--security)
24. [Dependencies Used](#24-dependencies-used)
25. [File Inventory](#25-file-inventory)
26. [Appendix A - Known Design Notes & Technical Debt](#26-appendix-a---known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **Quick Actions Module** is the task-surface engine behind the five most frequent faculty actions, launched from the My Class hub (`my_class_screen.dart:865-909`): **Mark Attendance**, **Attendance Records**, **Students**, **Send Message**, and **Export Reports**. It contains the only working attendance-capture pipeline in the app and the only real backend write in the entire feature surface.

### 1.2 Scope

- **Presentation:** 15 screens + 4 shared widgets under `lib/Presentation/Features/QuickActions/`.
- **Logic:** 5 `ChangeNotifier` controllers.
- **Data:** 5 repositories + 5 models + 2 Hive-backed services + 1 dummy-data generator.
- **Size:** ~22,300 non-blank lines (19,644 in Presentation, 1,309 models, 2,010 repositories, 188 services).

### 1.3 Business Goal

- Collapse the attendance-capture ritual (select → mark → review → submit) into a guided flow with ≤ 2 taps from the class page.
- Support **five capture modes** (Manual, QR, NFC, Face, Bluetooth) behind one shared controller.
- Keep records browsing, roster lookup, messaging, and report generation available as first-class actions alongside marking.
- Survive connectivity loss: autosave drafts + offline-queue submission.

### 1.4 Problem Statement

- Attendance capture in a classroom is time-critical; per-student entry must be instant and undoable.
- QR/NFC/Face/Bluetooth hardware is not yet wired; the product needs a complete, demoable pipeline now and a clean seam for hardware later.
- Records and reports must be browsable without server round-trips (the backend contract is only partially implemented).
- Faculty messaging spans many audiences (whole class, absentees, defaulters, parents); composition must not require the server to exist yet.

### 1.5 Solution

- **One controller to rule them all:** `MarkAttendanceController` owns roster, status map, undo/edit history, selection, bulk ops, quick actions, per-mode simulations, submit, and offline sync.
- **Two mark-attendance pipelines** (critical distinction, see §7/§8):
  1. **Live:** `qa.MarkAttendanceScreen` — the only path reachable from the hub (`my_class_screen.dart:868`).
  2. **Orphaned:** `MarkAttendanceDashboard → ModeSelectionScreen → {5 modes} → ReviewScreen` — fully wired, unreachable dead code (Appendix A-1).
- **Provider-injected controllers** for Records/Students/Messaging; self-instantiated controller for Export Reports.
- **Local-first data:** 4 of 5 repositories are in-memory seeds; exactly one method performs a real HTTP call (`mark_attendance_repository.dart:71`).

### 1.6 Faculty Workflow

```
My Class hub  (_buildQuickActions, my_class_screen.dart:860)
        │
        ├─▶ Mark Attendance ──▶ qa.MarkAttendanceScreen ──► submit / offline queue
        ├─▶ Attendance Records ─▶ AttendanceRecordsScreen ─► record_detail_screen
        ├─▶ Students ──────────▶ ClassStudentsScreen ──────► class_student_profile_screen
        ├─▶ Send Message ──────▶ FacultyMessagingScreen (Inbox | Sent | Compose)
        └─▶ Export Reports ────▶ ExportReportsScreen (generate | history | delete)

[ORPHANED — no navigator entry (A-1)]
   MarkAttendanceDashboard ─▶ ModeSelectionScreen ─▶ {Manual|QR|NFC|Face|BT|Hybrid} ─▶ ReviewScreen
```

---

## 2. Layered Architecture & Data Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ PRESENTATION  lib/Presentation/Features/QuickActions/                 │
│  Screens (15): MarkAttendance×9, AttendanceRecords×2,                 │
│                ClassStudents×2, Messaging×1, ExportReports×1          │
│  Widgets (4): AttendanceSummaryPanel, BulkActionsBar,                 │
│               SearchFilterBar, StudentAttendanceCard                  │
└───────────────┬──────────────────────────────────────────────────────┘
                │ watch() / read()   (Provider)
┌───────────────▼──────────────────────────────────────────────────────┐
│ CONTROLLERS  (ChangeNotifier)                                         │
│  MarkAttendanceController (999)  • AttendanceRecordsController (217)  │
│  ClassStudentsController (174)   • MessagingController (238)          │
│  ExportReportsController (229)                                        │
└──────┬──────────────────────────────┬────────────────────────────────┘
       │ repository calls             │ service calls
┌──────▼─────────────────────┐   ┌────▼───────────────────────────────┐
│ DATA - Repositories        │   │ SERVICES  (Hive)                    │
│  MarkAttendance (112)  ◄─  │   │ DraftAttendanceService ('attendance_│
│  AttendanceRecords (303)  ►│   │   drafts', 500 ms autosave)         │
│  Students (307)            │   │ OfflineSyncService ('offline_       │
│  Messaging (440)           │   │   attendance', simulated replay)    │
│  ExportReports (848)       │   └────────────────────────────────────┘
└──────┬─────────────────────┘
       │ exactly one HTTP call:
       │ POST /api/v1/faculty/session/attendance/bulk  (mark_attendance_repository.dart:71)
┌──────▼───────────────────────────────────────────────────────────────┐
│ CORE NETWORK  ApiClient (dio) — base URL: customBaseUrl ??           │
│   dotenv API_BASE_URL ?? 'https://api-dev.balaseetharamanjaneyulu.com'│
│   (runtime .env → https://api.intelliattend.app)                     │
└──────────────────────────────────────────────────────────────────────┘
```

### 2.1 Data flow on screen launch

```
Hub _buildQuickActions (my_class_screen.dart:860)
   ├─ MarkAttendance:  Navigator.push(qa.MarkAttendanceScreen(courseCode, courseName,
   │                     sessionId: 'session_<millis>'))          // wall-clock id (A-12)
   │                     → screen creates MarkAttendanceController(Repository, courseCode) (mark_attendance_screen.dart:55-59)
   │                     → controller.loadRoster → repository.fetchRoster (simulated 400 ms, cached seed)
   │                     → _sessionId = 'sess_<millis>' (controller:311)
   ├─ Records:  ChangeNotifierProvider(create: AttendanceRecordsController(Repo)) → screen
   ├─ Students: ClassStudentsController(StudentsRepository()) via ChangeNotifierProvider.value
   ├─ Messaging: ChangeNotifierProvider(create: MessagingController(MessagingRepository()))
   └─ Export:    ExportReportsScreen()   // screen builds its own controller (no provider)
```

### 2.2 Draft autosave loop

```
markStudent / markStudentWithNote / quick action / undo
   └─ _scheduleDraftSave()            (controller:338)  500 ms Timer debounce
        └─ _persistDraft()            (controller:344)
             └─ DraftAttendanceService.saveDraft(DraftAttendance(
                    key: '<courseCode>|<section>',      (controller:152)
                    attendanceMap, studentNotes, savedAt))  → Hive box 'attendance_drafts'
```

### 2.3 Submit flow

```
ReviewScreen _showSubmitConfirmation → controller.submitAttendance() (controller:925)
   ├─ guards: empty map / already submitting / already submitted / fingerprint duplicate (:926-947)
   ├─ repository.submitAttendance (simulated 600 ms, 2% random throw) (:954)
   │     ├─ success → status 'submitted', clear draft, reference id (:959-968)
   │     └─ throw   → OfflineSyncService.saveOffline(...) → status 'submitted_offline' (:973-992)
   └─ offline save fails → error message, draft preserved (:993-999)
```

---

## 3. Provider & State Management Wiring

| Entry screen | Controller wiring | Repository | Notes |
|---|---|---|---|
| `MarkAttendanceScreen` (`mark_attendance_screen.dart:20`) | optional `MarkAttendanceController? controller`; else self-constructed `MarkAttendanceController(MarkAttendanceRepository(), courseCode:)` (:55-59) | `MarkAttendanceRepository` | no Provider wrapper; direct field |
| `MarkAttendanceDashboard` (orphaned) | `ChangeNotifierProvider(create: MarkAttendanceController(MarkAttendanceRepository()))` (`mark_attendance_dashboard.dart:248-257`) | same | per-mode fresh controller; not reachable |
| `ModeSelectionScreen` | receives shared controller from dashboard provider | — | child screens push `ReviewScreen` with `ChangeNotifierProvider.value(value: controller)` |
| `AttendanceRecordsScreen` (`attendance_records_screen.dart`) | `ChangeNotifierProvider(create: AttendanceRecordsController(AttendanceRecordsRepository()))` (`my_class_screen.dart:877-879`) | `AttendanceRecordsRepository` | `const` screen, controller injected |
| `ClassStudentsScreen` (`class_students_screen.dart`) | `ChangeNotifierProvider.value(value: controller)` + explicit `controller:` prop (`my_class_screen.dart:886-892`) | `StudentsRepository` | controller created inline in hub builder |
| `FacultyMessagingScreen` (`faculty_messaging_screen.dart`) | `ChangeNotifierProvider(create: MessagingController(MessagingRepository()))` (`my_class_screen.dart:898-900`) | `MessagingRepository` | `const` screen |
| `ExportReportsScreen` (`export_reports_screen.dart`) | **self-created** in `initState`: `ExportReportsController(ExportReportsRepository())` (screen:33) | `ExportReportsRepository` | only screen that manages its own controller lifetime |

- All mode screens and `ReviewScreen` re-supply the live controller down the stack via `ChangeNotifierProvider.value` (e.g. `qr_attendance_screen.dart:143-147`, `review_screen.dart:24` `context.watch`).
- No controller is registered globally; everything is scoped to the pushed route (disposed on pop).

---

## 4. Screen Structure - Widget Tree

### 4.1 `MarkAttendanceScreen` (live hub path)

```
MarkAttendanceScreen (SingleTickerProviderStateMixin)
 ├─ _buildTopBar (course code/name + section chips A|B)
 ├─ SearchFilterBar        (search_query debounce + filter/sort)
 ├─ AttendanceSummaryPanel (total/present/absent/late/leave donut)
 ├─ Quick Action bar       (5 actions via _QuickActionSpec, confirm dialog :1278)
 ├─ roster ListView → StudentAttendanceCard × N
 │    └─ status chips (present/absent/late/leave) → _controller.markStudent (:419)
 ├─ bottomBar BulkActionsBar (selection mode + bulk mark/clear/undo/export)
 └─ FAB.extended (:1827) → submit flow (:372)
```

### 4.2 `ModeSelectionScreen` (orphaned flow)

```
ModeSelectionScreen (SingleTickerProviderStateMixin, 600 ms entrance)
 ├─ loading state (CircularProgressIndicator, "Loading roster...")   (:53-77)
 ├─ error state (retry → loadRoster)                                (:79-105)
 └─ switch (selectedMode)                                            (:115-147)
      ├─ manual/hybrid → AttendanceSessionScreen
      ├─ qr           → QrAttendanceScreen
      ├─ face         → FaceRecognitionScreen
      ├─ nfc          → NfcAttendanceScreen
      └─ bluetooth    → BluetoothAttendanceScreen
```

### 4.3 `AttendanceRecordsScreen`

```
AttendanceRecordsScreen (SingleTickerProviderStateMixin, TabController)
 ├─ Summary tab: stat cards + summary chart (from controller.summary)
 └─ Records tab: date/status filter chips, search (300 ms debounce),
      session list (pagination pageSize 20, near-bottom listener)
      └─ session card → RecordDetailScreen (record_detail_screen.dart)
 Export: _ExportSheet → CSV via share_plus
 Filters: _FilterSheet (date range, status, subject, section, student)
```

### 4.4 `FacultyMessagingScreen`

```
FacultyMessagingScreen (TabController(length: 3))
 ├─ Tab 0 Inbox  (infinite scroll listener, unread badge)
 ├─ Tab 1 Sent   (same list pattern, sentOnly: true)
 └─ Tab 2 Compose (recipient group picker → recipient list w/ per-section
      select-all; type/priority/category chips; subject/body; attachment
      picker via file_picker; template insertion; schedule; send)
 Detail view: type badge (individual→accentTeal, parent→accentPurple) +
      subject + full-date meta + mark-read + delete
```

### 4.5 Shared widgets (4)

| Widget | File (LOC) | Key props | Notes |
|---|---|---|---|
| `AttendanceSummaryPanel` | `attendance_summary_panel.dart` (220) | `totalCount`, `presentCount`, `absentCount`, `lateCount`, `leaveCount`, `attendancePercent`, `showChart` | donut via `dart:math`; computes marked/remaining; dark card `0xFF1E1E1E` |
| `BulkActionsBar` | `bulk_actions_bar.dart` (278) | `selectedCount`, 9 selection callbacks, 3 mark callbacks, `onUndo`/`canUndo`/`onExport`/`onSendParents` | dark card; drives selection & bulk mark flows |
| `SearchFilterBar` | `search_filter_bar.dart` (158) | `searchQuery`/`onSearchChanged`/`onClear`, filter/sort tap + labels, optional gender/section | debounced search inside |
| `StudentAttendanceCard` | `student_attendance_card.dart` (421) | `student`, `status`, `isSelected`, `isSelectionMode`, `onStatusChanged`, `onTap`/`onLongPress`, `onHistoryTap`, `onUndoTap`, `note`/`onNoteChanged`, `canUndo` | per-student mark card |

---

## 5. Entry Points & Navigation Map

```
DashboardScreen (IndexedStack tab 1)
   └─ MyClassScreen ── _buildQuickActions (my_class_screen.dart:860)
        │
        ├─▶ qa.MarkAttendanceScreen(courseCode, courseName, sessionId)      [:868]  [LIVE]
        ├─▶ AttendanceRecordsScreen   (provider)                             [:877]
        │      └─▶ RecordDetailScreen(record)
        ├─▶ ClassStudentsScreen(controller, section, courseCode)            [:888]
        │      └─▶ ClassStudentProfileScreen(student)
        ├─▶ FacultyMessagingScreen    (provider)                             [:900]
        └─▶ ExportReportsScreen                                             [:906]

[ORPHANED — no navigator entry references MarkAttendanceDashboard (A-1)]
   MarkAttendanceDashboard ──▶ ModeSelectionScreen
        ├─▶ QrAttendanceScreen ──▶ ReviewScreen ──▶ submit / offline
        ├─▶ NfcAttendanceScreen ─▶ ReviewScreen
        ├─▶ FaceRecognitionScreen ▶ ReviewScreen
        ├─▶ BluetoothAttendanceScreen ▶ ReviewScreen
        └─▶ AttendanceSessionScreen (manual / hybrid / bluetooth) ──▶ ReviewScreen
```

- The hub fabricates the session id from the wall clock: `'session_${DateTime.now().millisecondsSinceEpoch}'` (`my_class_screen.dart:871`); the controller re-generates its own `'sess_<millis>'` on `loadRoster` (`mark_attendance_controller.dart:311`).
- `ExportReportsScreen` is the only Quick Action pushed without a Provider wrapper.

---

## 6. MarkAttendanceController - the Shared Attendance Engine

**File:** `Controllers/mark_attendance_controller.dart` (999 non-blank / 1,116 total). Single `ChangeNotifier` that drives every attendance screen.

### 6.1 Enums (module-level)

| Enum | Values | Line |
|---|---|---|
| `AttendanceMode` | `manual, qr, face, nfc, bluetooth, hybrid` | :11 |
| `SortMode` | `alphabetical, nameDesc, rollNumber, attendancePercent, recentlyUpdated, newest, oldest` | :12 |
| `FilterMode` | `all, present, absent, late, leave, notMarked, below75, eligible, above90` | :13 |
| `QuickActionResult` | `success, skipped, offline, failed` | :15 |

### 6.2 Core state (:71-113)

- `_roster` (List<ClassStudent>), `_attendanceMap` (studentId → `AttendanceStatus`), `_studentNotes` (studentId → `StudentNote`).
- Session: `_sessionId`, `_sessionMode`, `_sessionStatus` (`not_started|loading|active|cancelled|submitted|submitted_offline`), `_sessionStartTime`, `_hasUnsavedChanges`, `_isEditMode`, `_editedBy='Faculty'`, `_editedAt`, `_lastSubmitTime`.
- Per-mode: `_qrCodeData` + `_qrCountdownSeconds=120` + `_qrTimer` + `_qrScannedStudentIds`; `_recognizedStudentIds` + `_unknownFaceIds` + `_isCameraActive`; `_nfcVerifiedIds` + `_lastNfcTag`; `_bluetoothDetectedIds` + `_bluetoothSignalStrengths`.
- Edit: `_undoStack` (List<_UndoEntry>), `_editHistory` (studentId → `EditEntry`), `_quickActionSnapshot`, `_submittedFingerprint`.
- Constructor: `MarkAttendanceController(MarkAttendanceRepository, {String? courseCode})` (:67-).

### 6.3 Session lifecycle

- `loadRoster(courseCode, {mode, section})` (:288-322): resets everything, calls `fetchRoster` (simulated 400 ms), mints `_sessionId = 'sess_<millis>'`, then seeds `_attendanceHistory` via `DummyDataGeneratorForHistory._generate` (:324-328; generator class defined at :1082 — see A-10).
- `cancelSession()` (:330).

### 6.4 Draft autosave

- `_scheduleDraftSave()` (:338): 500 ms debounce Timer, skipped when `submitted`/`submitted_offline`.
- `_persistDraft()` (:344): no-op when roster/map empty; serializes map + notes into Hive via `DraftAttendanceService`.
- `saveDraftNow()` (:357), `clearDraft()` (:367), `restoreDraft()` (:372), `draftKey = '<courseCode>|<section>'` (:152).

### 6.5 Marking & undo

- `markStudent(studentId, status)` (:419): records undo entry + `EditEntry` on status change, sets `_isEditMode`, schedules draft save.
- `markStudentWithNote(studentId, status, {reason, remark, medical, lateReason, privateNotes})` (:439): status + optional `StudentNote`.
- `undoLast()` (:452): restores previous status + note, prunes edit history.

### 6.6 Selection & bulk

- `toggleSelectionMode()` (:582), `toggleStudentSelection(studentId)` (:588).

### 6.7 Quick actions (network-coupled — see A-6)

- `_runQuickAction({apply, hasTargets})` (:599-641): guards re-entrancy, snapshots `_attendanceMap`, runs `apply()`, then **calls the real bulk endpoint** `_repository.bulkUpdateAttendance(...)` (:614). Outcomes:
  - success → `QuickActionResult.success`
  - `OfflineMarkAttendanceException` → queues `OfflineAttendanceEntry` via `OfflineSyncService.saveOffline` (:621-630) → `.offline`
  - `MarkAttendanceServerException` / any error → rolls `_attendanceMap` back to snapshot (:631-636) → `.failed`
- Exposed actions: `quickMarkAll(status)` (:643), `quickDeselectAll()` (:656), `quickInvert()` (:663, present↔absent, late/leave→absent), `quickMarkStudents(targets, status)` (:682), `quickResetFiltered(targets)` (:698), `quickUndo()` (:709), `quickFilterDefaulters()` (:719, sets `FilterMode.below75`).
- Filters/sorts: `setFilter` (:746), `setSortMode` (:751).

### 6.8 Mode simulations (no hardware — see A-2)

| Mode | Methods | Behavior |
|---|---|---|
| QR | `generateQRCode` (:784), `refreshQR` (:802), `expireQR` (:807), `simulateQRScan` (:813), `approveQRScan` (:822), `rejectQRScan` (:829) | code = `'<sessionId>_<millis>_<rand6>'`; 120 s countdown Timer; scan marks `present` + dedupe via `_qrScannedStudentIds` |
| Face | `startCamera` (:839), `stopCamera` (:846), `simulateFaceDetection` (:851), `confirmFaceRecognition` (:870), `rejectFaceRecognition` (:879) | picks a random unmarked student; `confidence = 75 + rand*25`; marks `present` only when >85, else pushes to `_unknownFaceIds` |
| NFC | `simulateNFCTap` (:889) | dedupe via `_nfcVerifiedIds`; sets `_lastNfcTag = 'NFC_<id>_<millis>'`; marks `present` |
| Bluetooth | `startBluetoothScan` (:901), `simulateBluetoothDetection` (:907), `stopBluetoothScan` (:919) | signal `-30 - rand*60` dBm; dedupe via `_bluetoothDetectedIds`; marks `present` |

### 6.9 Submission

- `submitAttendance({notes})` (:925-1001):
  - Guards: empty map, already submitting, status `submitted`/`submitted_offline`, and **fingerprint duplicate** (`_fingerprintFor` map-hash, :942-947).
  - Calls `_repository.submitAttendance` (600 ms simulated, 2% random throw).
  - Success: `_submittedFingerprint`, `_submitReferenceId`, status `submitted`, clears QR/draft timers + draft (:959-968).
  - Throw: builds `OfflineAttendanceEntry`, `OfflineSyncService.saveOffline`, status `submitted_offline`, reference id kept (:973-992); if the offline save itself fails → user error, draft preserved (:993-999).
- `syncOfflineAttendance()` (:1003) and `offlinePendingCount` (:1011) exist but **no screen calls them** (A-5).

---

## 7. Mark Attendance - Live Hub Path

**File:** `Screens/MarkAttendance/mark_attendance_screen.dart` (2,075 non-blank).

### 7.1 Contract

- Constructor requires `courseCode`, `courseName`, `sessionId`; optional `MarkAttendanceController? controller`, `initialSection='A'`, `sections=['A','B']` (:20-36).
- If no controller is passed, one is constructed with `courseCode` (:55-59).
- Status colors: `_presentGreen 0xFF22C55E`, `_absentRed 0xFFEF4444`, `_lateAmber 0xFFFBBF24`, `_leavePurple 0xFF8B5CF6` (:15-18).

### 7.2 Flow

- Search/filter/sort via `SearchFilterBar`; live summary via `AttendanceSummaryPanel`; per-student `StudentAttendanceCard` with tap-to-cycle status chips (haptics) → `markStudent`.
- **Quick actions** execute through `_executeQuickAction(spec, {confirm})` (:1270): confirm dialog (:1278-1286), then dispatch on `QuickActionResult` — success snackbar with "Undo", skipped warning, offline banner, failure error (:1292-1299+).
- **Submit:** FAB.extended (:1827) → `_controller.submitAttendance()` (:372); success dialog is offline-aware — "Attendance Submitted!" vs "Attendance Saved Offline" + "Queued offline. Will sync when network returns." (:576-631).
- **Back guard:** `PopScope` (:782) intercepts pops while `hasUnsavedChanges`; discard confirmation reuses the quick-action confirm surface.
- Session section chips switch `initialSection` (A/B) and drive the draft key.

---

## 8. Mark Attendance - Dashboard Flow (orphaned) & ModeSelectionScreen

### 8.1 `MarkAttendanceDashboard` (`mark_attendance_dashboard.dart`, 319)

- Stateless; shows a gradient session card (course, date, time, "Room 301" — **hard-coded**, A-13), session details (Faculty "Dr. Rajesh Kumar", Room, Status "Ready to Start"; :198-202), and a 6-cell mode grid (:223-301).
- Mode grid maps list index → `AttendanceMode.values[index]`; each tap pushes a **fresh** `MarkAttendanceController` via `ChangeNotifierProvider(create:)` → `ModeSelectionScreen` (:248-257).
- **Unreachable:** only references are its own declaration (verified by repo-wide grep) — see A-1 and `MYCLASS_MODULE.md` §8.1/A-1.

### 8.2 `ModeSelectionScreen` (`mode_selection_screen.dart`, 138)

- Post-frame `loadRoster(courseCode, mode:)` (:36-38); loading spinner (:53-77); error card with Retry (:79-105); 600 ms entrance animation.
- Routes by `AttendanceMode` (:115-147): manual/hybrid → `AttendanceSessionScreen`; qr/face/nfc/bluetooth → their dedicated screens.

---

## 9. Attendance Modes - QR, NFC, Face, Bluetooth

> All four are **simulated at the controller/screen level** — no camera, NFC, BLE, or real QR content (A-2). Each screen shares the same chrome (custom back affordance, course subtitle, "Review & Submit" bottom bar) and re-supplies the controller to `ReviewScreen` via `ChangeNotifierProvider.value`.

### 9.1 QR (`qr_attendance_screen.dart`, 279)

- Post-frame `controller.generateQRCode()` then a `Timer.periodic(4 s)` simulation marking one student per tick via `simulateQRScan` (:26-45); auto-stops when roster exhausted or QR expired.
- **Note:** the "QR" is rendered as a static Material icon `Icons.qr_code_2_rounded` (:210) — there is **no** `qr_flutter`/`QrImageView` in this module (qr_flutter is only used by the Profile screen). MYCLASS §8.4's "via qr_flutter" is inaccurate for this screen.
- QR card shows Active/Expired badge, 120 s countdown (red <30 s), scanned count (:164-257).
- Bottom bar: "Refresh QR" (regenerates + restarts simulation) and "Review & Submit" which **expires the QR** then pushes `ReviewScreen` (:140-148).

### 9.2 NFC (`nfc_attendance_screen.dart`, 462)

- Pulse animation 1200 ms `repeat(reverse: true)` (:34); tap burst animation 400 ms (:36).
- `Timer.periodic(3 s)` picks a random unverified student → `simulateNFCTap`; "Last tap: <name>" chip; duplicate tap shows an amber "Duplicate tap ignored" warning for 2 s (:54-79).
- Verified list renders a display tag `NFC_<id[:8]uppercase>` (:360); review gate requires ≥1 verified (:460).

### 9.3 Face recognition (`face_recognition_screen.dart`, 497)

- Pulse 1500 ms (:46); progress bar ticks every 50 ms (:68-73); scan `Timer.periodic(3 s)` calls `simulateFaceDetection` (:75-110).
- Camera viewfinder (dark `0xFF0A0A0A`) with animated corner brackets (:264-284); live confidence badge colored >85 green / >70 amber / else red (:289-293).
- Recognized list confidence colors: >90 green, >80 teal, else amber (:406-410). Review gate requires ≥1 recognized face (:500).

### 9.4 Bluetooth (`bluetooth_attendance_screen.dart`, 496)

- Wave animation 2000 ms `repeat` (:44); `Timer.periodic(2.5 s)` → `simulateBluetoothDetection` with signal `-30 - rand*60` dBm (:65-85).
- `_DetectedDevice` (studentId, name, signalStrength, detectedAt) (:12-23); signal bars/labels: ≥-50 strong/green/3 bars, ≥-70 medium/amber/2, else weak/red/1 (:107-123).
- Stats row Detected / Remaining / Total; review gate requires ≥1 detected (:499).

---

## 10. Manual & Bluetooth Live Session (AttendanceSessionScreen)

**File:** `Screens/MarkAttendance/attendance_session_screen.dart` (1,511 non-blank).

- **Live header:** `_sessionTimer` ticks every minute (:30-32, :50-56) computing `_elapsed = now - sessionStartTime`; rendered as `MM:SS` clock (:290-291); live present/absent/late/leave counts.
- **Roster marking:** per-student status chips; summary line shows `${undoStack.length} unsaved change(s)` (:514).
- **Note sheet:** multiple `showModalBottomSheet` surfaces (:647, :700, :746, :796, :844, :1035, :1129, :1164, :1287); the note entry sheet calls `controller.markStudentWithNote(student.id, status, reason:, remark:)` (:1129) with a purple "Save Note" primary.
- **Discard guard:** "This will discard all unsaved attendance marks. This action cannot be undone." confirmation (:1384).
- Success/error animation controllers + session timer wiring for submit transitions.

---

## 11. Review & Submission (ReviewScreen)

**File:** `Screens/MarkAttendance/review_screen.dart` (361 non-blank).

- Stateless; `context.watch<MarkAttendanceController>()` (:24); derives Present/Absent/Late/Leave lists from `attendanceMap` (:26-29).
- Summary card: Total/Present/Absent/Late/Leave stat tiles + stacked proportional color bar + attendance rate % (:135-188).
- Per-status sections render student rows (avatar initials, name, roll, attendance %) only when non-empty (:211-263).
- Bottom bar: "Edit" (pop) and "Submit Attendance" (disabled while submitting, teal, heavy haptic) (:80-131).
- `_showSubmitConfirmation` AlertDialog (:265-306): re-asserts the 5 counts, Cancel/Submit; on Submit → `controller.submitAttendance()` (:296) → `_showSuccessDialog` (:323) which is **offline-aware** (`submitted_offline` → "Saved offline. Will sync when network is available.", :347-349); "Done" pops twice to return to the hub.

---

## 12. Attendance Records Flow

### 12.1 Controller (`Controllers/attendance_records_controller.dart`, 217)

- Enums: `AttendanceFilter {none, date, subject, section, status, student, session}` (:5), `RecordSortField {date, name, rollNumber, attendancePercent, time}` (:6), `SortDirection {ascending, descending}` (:7).
- API: `loadSessions` (:50, paginated), `loadMore` (:82), `loadSessionRecords(sessionId)` (:113), `loadSummary` (:129), `setDateRange` (:152), `setCourseCode` (:160), `setFilter` (:167), `search` (:176), `setSortField` (:181), `toggleSortDirection` (:195), `sortRecords` (:202), `clearFilters` (:225), `refresh` (:241).

### 12.2 Screen (`Screens/AttendanceRecords/attendance_records_screen.dart`, 2,280)

- `TabController` summary/records; private `_DateFilter` + `_SortOption` enums.
- Search debounce 300 ms; infinite scroll at `maxScrollExtent - 200` with `_pageSize = 20`.
- Status colors: present `0xFF22C55E`, absent `0xFFEF4444`, late `0xFFFBBF24`, leave `0xFF6B4EFF`, holiday `0xFF60A5FA`.
- `_ExportSheet` → CSV via `share_plus`; `_FilterSheet` (date range, status, subject, section, student).

### 12.3 Detail (`Screens/AttendanceRecords/record_detail_screen.dart`, 566)

- Single `AttendanceRecord`: check-in/out, location/device verification flags, sync status, remarks, attendance %, per-student note access.

**Data source:** `AttendanceRecordsRepository` (303) — in-memory `AttendanceSession`/`AttendanceRecord` seeds from `dummy_data.dart`; **no network, no persistence** (A-4).

---

## 13. Class Students Flow

### 13.1 Controller (`Controllers/class_students_controller.dart`, 174)

- `StudentsFilter {none, rollNumber, name, department, section, attendance, eligible, defaulter, gender}` (:5-15), `SortOrder {ascending, descending}` (:17).
- API: `loadStudents` (:45), `search` (:70), `setFilter` (:76), `setSortOrder` (:86), `clearFilters` (:92), `refresh` (:102); `_applyFiltersAndSort` (:106).

### 13.2 Screen (`Screens/ClassStudents/class_students_screen.dart`, 1,313)

- Search field, filter chips (department/section/gender/eligibility), sort; 700 ms entry animation; avatar colors via `_getAvatarColor`; `SearchFilterBar` reuse.
- Receives controller both as prop and via `ChangeNotifierProvider.value` (`my_class_screen.dart:886-892`).

### 13.3 Profile (`Screens/ClassStudents/class_student_profile_screen.dart`, 935)

- Rendered from the **typed** `ClassStudent` model (hub's `StudentProfileScreen` takes a raw map). Eligibility badge, guardian/contact block, blood group, address, notes, attendance history rows (`_AttendanceEntry`).

**Data source:** `StudentsRepository` (307) — hard-coded dummy students; no network.

---

## 14. Faculty Messaging Flow

### 14.1 Controller (`Controllers/messaging_controller.dart`, 238)

- Paginated `loadMessages({type, query, filter, sentOnly})` (:48) + `loadMoreMessages` (:81) with `_pageSize = 20`; `loadThreads` (:112), `loadTemplates` (:121), `loadScheduledMessages` (:126).
- `sendMessage(...)` (:135) — 15-param signature (recipient, subject, body, type, priority, category, attachments, scheduledAt, courseCode, section, recipientGroup, recipientIds, notes) → inserts result at list head; `markAsRead` (:182), `deleteMessage` (:199), `cancelScheduledMessage` (:210), `setTypeFilter` (:222), `setFilter` (:233), `search` (:240), `clearFilters` (:247), `refresh` (:261).
- Derived: `unreadMessages`/`unreadCount` (:43-46).

### 14.2 Screen (`Screens/Messaging/faculty_messaging_screen.dart`, 2,919)

- 3 tabs (Inbox/Sent/Compose); post-frame bootstrap of messages/threads/templates; both scroll lists paginate (page size 20); debounced search.
- **Compose:** recipient selection by `RecipientGroup` (entire class, selected/absent/present/late/below-75, parents, individual, multiple classes) with per-section select-all (`_sectionSelectAll`), `_selectAllStudents`, individual toggles (`_selectedRecipientIds`/`_selectedRecipientNames`); `_filteredRecipients`/`_recipientsBySection`.
- `MessageType` chips color-coded (individual → `accentTeal`, parent → `accentPurple`); attachment picker via `file_picker`; template insertion; scheduled-send support.
- Detail view: type badge + subject + formatted full date/time + read status.

### 14.3 Repository (`Repositories/QuickActions/messaging_repository.dart`, 440)

- `fetchMessages(type, query, filter, page, pageSize, sentOnly)`, `fetchThreads`, `fetchScheduledMessages`, `sendMessage`, `markAsRead`, `deleteMessage`, `cancelScheduledMessage`, `getTemplates`.
- Seeded with 200 in-memory `FacultyMessage`s via `Random(42)`; delivery/send simulated; **no network, no persistence, no receipts beyond the status enum** (A-12).

---

## 15. Export Reports Flow

### 15.1 Controller (`Controllers/export_reports_controller.dart`, 229)

- `generateReport({type, format, dateFrom, dateTo, courseCode, section, semester})` (:66-131): staged progress `0.2 "Generating..." → 0.5 "Processing records..." → 0.9 "Finalizing..." → 1.0 "Complete!"`, then refreshes history.
- `downloadReport` (:133, validates `filePath` exists), `openReport` (:159), `shareReport` (:169), `deleteReport` (:179, re-fetches list), `printReport` (:191, **PDF only** — A-11), filter setters (:210-243), `refresh` (:261).
- Owns `_isGenerating`/`_isExporting`/`_exportProgress`/`_exportStatusText`; `hasMore` is always `false` (:36); `loadMore` is a no-op (:64).

### 15.2 Screen (`Screens/ExportReports/export_reports_screen.dart`, 1,686)

- **Self-creates** `ExportReportsController(ExportReportsRepository())` in `initState` (screen:33) — the only Quick Action that does not rely on an injected provider.
- Report type + format selection, date range, courseCode/section/semester; generation sheet with progress bar; preview/format cards.
- History list with download/open/share/print and a **delete confirmation dialog** → `_controller.deleteReport(report.id)` → SnackBar "Report deleted" (errorRed).
- Uses `share_plus` + `open_filex`.

### 15.3 Repository (`Repositories/QuickActions/export_reports_repository.dart`, 848)

- Real **local file generation** (no HTTP): PDF via `pdf` + `printing`, Excel via `excel`, CSV hand-rolled, JSON via `dart:convert`.
- Writes to app documents dir (`path_provider`), storage permission via `permission_handler`, open via `open_filex`, share via `share_plus`.
- `fetchReports` seeds 15 in-memory `ExportReport`s (`dummy_data.dart:415`).

---

## 16. Services - Draft Autosave & Offline Sync

### 16.1 `DraftAttendanceService` (`Data/Services/draft_attendance_service.dart`, 77)

- Hive box `'attendance_drafts'`; singleton.
- `DraftAttendance {key, attendanceMap, studentNotes, savedAt}` with JSON (de)serialization; status strings round-tripped through `AttendanceStatus.values.firstWhere(... orElse: absent)`.
- `saveDraft`/`loadDraft`/`clearDraft`/`isDraftPresent`; key = `'<courseCode>|<section>'` (controller:152) — single draft slot per section (A-8).

### 16.2 `OfflineSyncService` (`Data/Services/offline_sync_service.dart`, 111)

- Hive box `'offline_attendance'`; singleton; `SyncStatus {pending, syncing, synced, failed}` (:6).
- `OfflineAttendanceEntry {sessionId, attendanceMap, timestamp, status, notes}`; entire queue serialized under a single `'entries'` key (:60).
- `saveOffline` (:56), `getPendingSync` (:64), `pendingCount` (:75), `syncAll` (:77), `retryFailed` (:99), `clearSynced` (:120).
- **Critical:** `syncAll`/`retryFailed` only `Future.delayed(800/600 ms)` and flip status to `synced` — they **never POST to the backend**. The "sync" is simulated (A-4/A-5).

---

## 17. Data Models & DTOs

All under `lib/Data/Models/QuickActions/`.

### 17.1 `attendance_record.dart` (187)

- `AttendanceStatus {present, absent, late, leave, holiday}` (:1).
- `AttendanceRecord` (25 fields): id, studentId/Name, rollNumber, sessionId, courseCode/Name, section, date, status, checkIn/checkOutTime, notes, markedBy, sessionType, facultyName, department, location/deviceVerified, syncStatus, attendancePercentage, remarks.
- `AttendanceSession` (15 fields): sessionId, courseCode/Name, section, date, totalStudents, present/absent/late/leaveCount, status, duration, facultyName; `attendanceRate = (present+late)/total*100` (:157).

### 17.2 `class_student.dart` (157)

- `ClassStudent` (23 fields): id, name, rollNumber, email, phone, department, section, courseCode/Name, semester, image, attendancePercentage, totalClasses, attendedClasses, isEligible, isDefaulter, gender, lastSeen, guardianName/Phone, address, bloodGroup, notes.

### 17.3 `faculty_message.dart` (355)

- Enums: `MessageType {announcement, classMessage, individual, parent}` (:1); `MessageStatus {sending, sent, delivered, read, failed}` (:3); `MessagePriority {normal, important, urgent, emergency}` (:5); `MessageCategory` (10: text, importantNotice, assignment, homework, examNotification, holidayNotice, eventNotification, emergencyAlert, reminder, custom) (:7); `RecipientGroup` (10: entireClass, selectedStudents, absentStudents, presentStudents, lateStudents, below75, parents, individual, multipleClasses, allStudents) (:20).
- `FacultyMessage` (22 fields): id, senderId/Name, recipientId/Name, subject, body, type, status, priority, category, createdAt, readAt, scheduledAt, attachments, courseCode, section, recipientCount, readCount, recipientGroup, recipientIds, notes (+ `copyWith`).
- Support types: `MessageThread` (:255), `MessageTemplate` (:297), `MessageFilter` (:315).

### 17.4 `export_report.dart` (161)

- `ExportFormat {pdf, excel, csv, json}` (:1); `ReportType {attendance, studentList, sessionSummary, daily, weekly, monthly, subject, department}` (:3).
- `ExportReport` (17 fields): id, title, type, format, generatedAt, dateFrom/To, courseCode, section, semester, recordCount, filePath, fileName, fileSizeKB, status, exportDurationMs (+ `copyWith`, JSON).

### 17.5 `dummy_data.dart` (449)

- `DummyDataGenerator`: `generateStudents` (:76), `generateAttendanceHistory` (:134), `generateAttendanceRecords` (:166), `generateSessions(count: 20)` (:226), `generateMessages(count: 30)` (:260), `generateThreads` (:386), `generateReports(count: 15)` (:415). `Random(42)` for determinism; name pools at :13/:28, departments :44, sections ['A','B'] :48.

---

## 18. Repositories - Dummy vs Real

| Repository | LOC | Backend? | Detail |
|---|---|---|---|
| `mark_attendance_repository.dart` | 112 | **Partial** | `fetchRoster` (400 ms seed, cached), `submitAttendance` (600 ms, 2% random throw), `fetchHistory` (300 ms); `bulkUpdateAttendance` is the **only real HTTP call** (:71). Exceptions: `OfflineMarkAttendanceException`, `MarkAttendanceServerException` (:10-18). |
| `attendance_records_repository.dart` | 303 | No | in-memory sessions/records seeds |
| `students_repository.dart` | 307 | No | hard-coded dummy roster |
| `messaging_repository.dart` | 440 | No | 200 seeded messages, `Random(42)` |
| `export_reports_repository.dart` | 848 | No (local files) | real PDF/Excel/CSV/JSON generation to disk |

All latency is `Future.delayed`. The 2% failure in `submitAttendance` is deterministic-ish via `Random(42)`.

---

## 19. Backend API Reference

### 19.1 The only endpoint consumed

```
POST https://api.intelliattend.app/api/v1/faculty/session/attendance/bulk
       (base URL resolved in api_client.dart:19/33: customBaseUrl ?? dotenv 'API_BASE_URL'
        ?? 'https://api-dev.balaseetharamanjaneyulu.com'; runtime .env = https://api.intelliattend.app)
```

Request body (`mark_attendance_repository.dart:73-80`):

```json
{
  "session_id": "sess_...",
  "course_code": "CS301",
  "present_students": ["...", "..."],
  "absent_students": ["..."],
  "late_students": ["..."],
  "leave_students": ["..."]
}
```

- Timeouts: 10 s send / 10 s receive (dio `Options`, :81-84).
- Accepted: HTTP 200/201 (:86).
- Error mapping (:91-109):
  - connection/timeout errors → `OfflineMarkAttendanceException` (screen queues offline).
  - response with `data['message']` / `data['error']` → `MarkAttendanceServerException(message)`.
  - anything else → generic `MarkAttendanceServerException('Unable to update attendance.')`.

### 19.2 Missing contract

- No GET endpoints for roster, sessions, records, messages, or reports — all served from in-memory seeds. Any real integration must implement the five repository interfaces against the backend (A-3).

---

## 20. WebSocket Real-Time Protocol

- **None.** Grep across `lib/Presentation/Features/QuickActions/` finds no `WebSocket`, `Socket`, or streaming usage; the only `dart:io` network import is `export_reports_controller.dart` (for local files).
- Consistent with `MYCLASS_MODULE.md` §16: the Home module owns `faculty_sync`/`student_marked`/`attendance_updated` channels; Quick Actions are synchronous with simulated latency. Live telemetry for this module should reuse `WebSocketService`'s existing channels, not introduce new ones.

---

## 21. Sequence Diagrams

### 21.1 Quick action (e.g. "Mark all present") with offline fallback

```
User → MarkAttendanceScreen._executeQuickAction (:1270)
  → _confirmBulkAction  (AlertDialog, only when confirm: true)
  → _QuickActionSpec.action() → controller.quickMarkAll(status)
    → _runQuickAction (:599)
      1. _quickActionSnapshot = Map.of(_attendanceMap)        (:607)
      2. apply()  → every roster id set to status             (:646)
      3. _scheduleDraftSave()                                 (:613)
      4. _repository.bulkUpdateAttendance(...)  [REAL POST]   (:614)
            ├─ 200/201            → QuickActionResult.success  (:620)
            ├─ offline ex         → OfflineSyncService.saveOffline → .offline (:621-630)
            └─ server/any error   → map rolled back → .failed (:631-636)
  → snackbar by result (success/undoable, skipped-warning, offline, failed) (:1292-1299+)
```

### 21.2 Submit (ReviewScreen)

```
ReviewScreen._showSubmitConfirmation (:265)
  → Confirm → controller.submitAttendance() (:296 → controller:925)
     ├─ guards (empty/already-submitting/already-submitted/fingerprint) (:926-947)
     ├─ repository.submitAttendance (600 ms; 2% random throw) (:954)
     │    ├─ ok   → status 'submitted', reference id, clear draft+QR+draft timer (:959-968)
     │    └─ fail → OfflineSyncService.saveOffline → status 'submitted_offline' (:973-992)
     │               (offline save fails → error, draft kept) (:993-999)
  → _showSuccessDialog (offline-aware copy) (:323)
  → Done → pop ×2 back to hub
```

### 21.3 QR mode

```
QrAttendanceScreen.initState
  → post-frame: generateQRCode() + _startSimulation (:26-30)
  → generateQRCode: code = '<sessionId>_<millis>_<rand6>', 120 s countdown Timer (:784-800)
  → Timer.periodic(4 s): simulateQRScan(student[i]) → marks present + dedupes (:37-44, :813)
  → "Review & Submit": expireQR() → ChangeNotifierProvider.value → ReviewScreen (:140-148)
```

---

## 22. Error Handling & Edge Cases

| Area | Handling |
|---|---|
| Roster load | `loadRoster` catch → `_error`, status `error`; ModeSelectionScreen renders error card + Retry (:79-105); MarkAttendanceScreen shows inline error |
| Quick actions | snapshot-and-rollback on server error; `.offline` queues to `OfflineSyncService`; `.skipped` warns; re-entrancy guarded by `_isProcessingQuickAction` |
| Submit | empty map, double-submit, already-submitted, fingerprint-duplicate all blocked with user error text (:926-947); failure always routes to offline queue |
| Offline save failure | user-facing error; draft preserved for later (:995) |
| Duplicate mode scans | QR/NFC/BT dedupe via id sets; face via `recognizedStudentIds`/`unknownFaceIds` |
| Record pagination | `hasMore` from `_pageSize` threshold; `loadMore` guarded by `_isLoadingMore` |
| Messaging | send failure → `_error` surfaced, `_isSending` reset; delete/cancel failures caught |
| Export | generation catch resets progress; delete failure caught; print silently no-ops for non-PDF (A-11) |
| Draft | empty roster/map → no-op; submitted statuses skip autosave; restore is best-effort (`loadDraft` returns null on parse error) |
| Unsaved-changes back-nav | `PopScope` on MarkAttendanceScreen (:782) + discard confirmation on AttendanceSessionScreen (:1384) |

---

## 23. Performance & Security

### 23.1 Performance

- **notifyListeners fan-out:** `markStudent` notifies on every tap; cards re-read `attendanceMap` via `context.watch` — fine for typical 60-120 student rosters but O(roster) per notify in list builds.
- **Timers:** QR 1 s countdown, mode scan timers (4 s / 3 s / 2.5 s), face progress 50 ms; all cancelled in `dispose` and on stop/expire.
- **Debounce:** search 300 ms (records), draft save 500 ms, messaging search debounce.
- **Pagination:** records & messaging use page-size-20 infinite scroll.
- **Animation controllers:** pulse/tap/wave/entrance controllers are disposed; `ShimmerController` repeats while mounted.
- **Dummy history:** `_loadAttendanceHistories` seeds one history per roster student (dummy only).

### 23.2 Security

- No secrets or credentials in Quick Actions; HTTP goes through the shared `ApiClient` dio instance (auth configured centrally).
- Dummy data is **PII-shaped** (realistic names/phones/guardians/blood groups from `dummy_data.dart` pools) and must never ship against real student data (cross-ref MYCLASS A-2).
- Hive boxes `attendance_drafts` / `offline_attendance` are **unencrypted**; drafts/offline maps contain student IDs + statuses.
- Local report files written via `permission_handler` storage permission; files carry attendance data — no purge/retention policy (A-8).

---

## 24. Dependencies Used

Directly exercised by Quick Actions (from `pubspec.yaml`):

| Package | Where used |
|---|---|
| `provider` | controller injection / `ChangeNotifierProvider.value` throughout |
| `hive`, `hive_flutter` | `attendance_drafts`, `offline_attendance` boxes |
| `google_fonts` | `GoogleFonts.inter` / `jetBrainsMono` typography |
| `intl` | `DateFormat` (records, reports, messaging) |
| `dio` | the single bulk attendance POST (`mark_attendance_repository.dart:71`) |
| `pdf`, `printing` | PDF report generation/layout |
| `excel` | XLSX report generation |
| `share_plus` | CSV/PDF/Excel share (records export, reports) |
| `open_filex` | opening generated report files |
| `file_picker` | message attachments |
| `path_provider`, `permission_handler` | report file IO + storage permission |
| `flutter/services` (SDK) | `HapticFeedback` taps, `PopScope` |
| `syncfusion_flutter_charts` | attendance charts (records/profile) — via app-level dependency |

> Not used in this module (despite earlier doc claims): `qr_flutter`, `mobile_scanner`, `csv` (CSV is hand-rolled), `url_launcher`, `connectivity_plus`.

---

## 25. File Inventory

> Line counts = non-blank lines (`Measure-Object -Line`), consistent with `MYCLASS_MODULE.md`. Windows paths shown with forward slashes.

### 25.1 Screens — `lib/Presentation/Features/QuickActions/Screens/`

| File | LOC | Role |
|---|---|---|
| `MarkAttendance/mark_attendance_screen.dart` | 2,075 | **Live** hub-path mark attendance (self-contained) |
| `MarkAttendance/attendance_session_screen.dart` | 1,511 | Manual/hybrid/BT live session + note sheets |
| `MarkAttendance/face_recognition_screen.dart` | 497 | Face mode (simulated) |
| `MarkAttendance/bluetooth_attendance_screen.dart` | 496 | Bluetooth mode (simulated) |
| `MarkAttendance/nfc_attendance_screen.dart` | 462 | NFC mode (simulated) |
| `MarkAttendance/review_screen.dart` | 361 | Review/submit gate |
| `MarkAttendance/mark_attendance_dashboard.dart` | 319 | **Orphaned** 6-mode dashboard (A-1) |
| `MarkAttendance/qr_attendance_screen.dart` | 279 | QR mode (simulated) |
| `MarkAttendance/mode_selection_screen.dart` | 138 | 5-mode routing |
| `AttendanceRecords/attendance_records_screen.dart` | 2,280 | Records tabs/filters/pagination/export |
| `AttendanceRecords/record_detail_screen.dart` | 566 | Single record detail |
| `ClassStudents/class_students_screen.dart` | 1,313 | Roster browser + filters |
| `ClassStudents/class_student_profile_screen.dart` | 935 | Typed-model profile |
| `ExportReports/export_reports_screen.dart` | 1,686 | Report generator + history |
| `Messaging/faculty_messaging_screen.dart` | 2,919 | Inbox/Sent/Compose messaging |

### 25.2 Widgets — `lib/Presentation/Features/QuickActions/Widgets/`

| File | LOC | Role |
|---|---|---|
| `student_attendance_card.dart` | 421 | Per-student mark card |
| `bulk_actions_bar.dart` | 278 | Selection/bulk mark bar |
| `attendance_summary_panel.dart` | 220 | Summary + donut |
| `search_filter_bar.dart` | 158 | Debounced search + filter/sort |

### 25.3 Controllers — `lib/Presentation/Features/QuickActions/Controllers/`

| File | LOC | Role |
|---|---|---|
| `mark_attendance_controller.dart` | 999 | Full attendance engine (modes, quick actions, submit/offline) |
| `attendance_records_controller.dart` | 217 | Records paging/filter/sort |
| `export_reports_controller.dart` | 229 | Report generation/export state |
| `messaging_controller.dart` | 238 | Messaging state + send/mark-read |
| `class_students_controller.dart` | 174 | Roster browser state |

### 25.4 Repositories / Services / Models

| File | LOC | Role |
|---|---|---|
| `Data/Repositories/QuickActions/mark_attendance_repository.dart` | 112 | Roster seed + submit + **real bulk POST** |
| `Data/Repositories/QuickActions/attendance_records_repository.dart` | 303 | In-memory records seeds |
| `Data/Repositories/QuickActions/students_repository.dart` | 307 | Dummy student roster |
| `Data/Repositories/QuickActions/messaging_repository.dart` | 440 | 200 seeded messages |
| `Data/Repositories/QuickActions/export_reports_repository.dart` | 848 | Local PDF/XLSX/CSV/JSON generation |
| `Data/Services/draft_attendance_service.dart` | 77 | 500 ms draft autosave (Hive) |
| `Data/Services/offline_sync_service.dart` | 111 | Offline queue (simulated replay) |
| `Data/Models/QuickActions/dummy_data.dart` | 449 | `DummyDataGenerator` seeds |
| `Data/Models/QuickActions/faculty_message.dart` | 355 | Message model + 5 enums + threads/templates/filter |
| `Data/Models/QuickActions/attendance_record.dart` | 187 | `AttendanceStatus` + record/session DTOs |
| `Data/Models/QuickActions/export_report.dart` | 161 | Report DTO + 2 enums |
| `Data/Models/QuickActions/class_student.dart` | 157 | 23-field student |

**Module totals (non-blank):** 18,771 Presentation (15,837 screens + 1,857 controllers + 1,107 widgets) · 1,309 models · 2,010 repositories · 188 services · **22,278 lines total** (verified with `Measure-Object -Line`; 23,432 lines including blank lines via `Get-Content`).

---

## 26. Appendix A - Known Design Notes & Technical Debt

### A-1. Orphaned MarkAttendance dashboard flow (HIGH)

`MarkAttendanceDashboard → ModeSelectionScreen → {QR/NFC/Face/BT/Manual/Hybrid} → ReviewScreen` is fully implemented with a per-mode fresh controller and shared-`ChangeNotifierProvider` handoff, but **no navigator entry references `MarkAttendanceDashboard`** (repo-wide grep finds only its own declaration, `mark_attendance_dashboard.dart:10`). The hub still launches the legacy `qa.MarkAttendanceScreen`. Decision: wire the dashboard as the hub's Mark Attendance action (replacing the live screen) or delete ~1,200 LOC of dead flow. Cross-ref `MYCLASS_MODULE.md` §8.1/A-1.

### A-2. QR/NFC/Face/Bluetooth are fully simulated (HIGH)

No hardware or platform channels exist. The QR screen renders a static Material icon (`qr_attendance_screen.dart:210`), not a real `qr_flutter` code; NFC/BT/Face are `Timer.periodic` + `Random` simulations in the controller (:851-921). Every "scan" is fabricated. The controller's `simulate*` methods are the intended seam for real integrations (`mobile_scanner`, `nfc_manager`, BLE, ML-Kit).

### A-3. Four of five repositories are dummy (MEDIUM)

Only `mark_attendance_repository.bulkUpdateAttendance` performs HTTP; roster/sessions/messages/reports are in-memory seeds (`Random(42)`, 400-600 ms simulated latency, 2% submit failure). Cross-ref `MYCLASS_MODULE.md` A-4. Real integration requires implementing the interfaces against the backend contract (§19).

### A-4. Offline "sync" never syncs (HIGH)

`OfflineSyncService.syncAll` / `retryFailed` (`offline_sync_service.dart:77-118`) only `Future.delayed` and flip status to `synced`; **no POST is ever issued**. Queued offline entries are never actually delivered to the server, and nothing triggers a replay (A-5).

### A-5. `syncOfflineAttendance` / `offlinePendingCount` are dead API (MEDIUM)

Defined on `MarkAttendanceController` (:1003/:1011) but **no screen calls them**. Attendance submitted offline stays in the `offline_attendance` Hive box forever unless the user re-submits. A sync banner/entry point is missing.

### A-6. Quick actions fire real network calls (MEDIUM)

Every "Mark all present / Deselect all / Invert / Reset filtered" invokes `_repository.bulkUpdateAttendance` (:614) — a real HTTP POST from a demo-style bulk action, with 10 s timeouts. On network failure the local map is rolled back and/or queued offline. For demo/offline contexts this couples UI convenience to live connectivity.

### A-7. Submit always falls back to offline on ANY error (LOW)

`submitAttendance` routes the catch-all branch (including the repository's own 2% random simulated failure) to the offline queue (:973-992) rather than surfacing the error. Non-network failures are indistinguishable from real connectivity loss.

### A-8. Draft key is course+section only (LOW)

`draftKey = '<courseCode>|<section>'` (controller:152) — no date or session component. One draft per section; a new session on the same day overwrites the previous unsaved draft. No draft listing UI.

### A-9. Legacy duplicate screen is dead code (LOW)

`lib/Presentation/Features/my_class/mark_attendance_screen.dart` (596 LOC) defines a second `MarkAttendanceScreen` with zero references (repo-wide grep). Delete or reconcile; the Quick Actions `qa.MarkAttendanceScreen` is the sole live path.

### A-10. `DummyDataGeneratorForHistory` lives inside the controller (LOW)

Defined at `mark_attendance_controller.dart:1082` and used for per-student history seeding (:326) — Data-layer concern living in a Presentation file; should move to `dummy_data.dart`.

### A-11. `printReport` is PDF-only (LOW)

`export_reports_controller.dart:191-208` only calls `Printing.layoutPdf` when `format == ExportFormat.pdf`; Excel/CSV/JSON print buttons silently no-op.

### A-12. Session id from wall clock (LOW)

Hub fabricates `session_<millis>` (`my_class_screen.dart:871`) and the controller mints `sess_<millis>` (controller:311). Per the Home module's `TimeSyncService` posture, session ids should come from the server-anchored clock. Cross-ref `MYCLASS_MODULE.md` A-10.

### A-13. Hard-coded dashboard session details (LOW)

`MarkAttendanceDashboard` hard-codes Faculty "Dr. Rajesh Kumar", "Room 301", "Ready to Start" (:198-202); none derive from the cohort. Only relevant if A-1 is resolved.

### A-14. Repeated haptics on scan timers (LOW)

Mode screens fire `HapticFeedback` on every simulated tick (4 s / 3 s / 2.5 s cadence). On low-end devices this can be intrusive/battery-draining; gate haptics behind a settings flag when hardware modes land.

---

*End of Quick Actions Module technical documentation. Companion: `MYCLASS_MODULE.md` (hub + legacy lineage), `HOME_MODULE.md`, `COURSES_MODULE.md`.*
