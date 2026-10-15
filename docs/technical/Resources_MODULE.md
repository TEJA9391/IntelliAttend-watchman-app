# IntelliAttend Faculty — Resources Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Resources (Faculty File Library: "My Private" / "College Shared")
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/HOME_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/ASSIGNMENTS_MODULE.md`, `docs/technical/PROFILE_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`ResourcesScreen` — the List Hub](#5-resourcesscreen--the-list-hub)
6. [Upload Flow — `_showUploadSheet`](#6-upload-flow--showuploadsheet)
7. [File Pickers & the File-Type Whitelist](#7-file-pickers--the-file-type-whitelist)
8. [Open / Download / Share — Presigned-URL Flow](#8-open--download--share--presigned-url-flow)
9. [Push to SmartBoard & Share-to-Class](#9-push-to-smartboard--share-to-class)
10. [`ResourcesController` — State & Repo Calls](#10-resourcescontroller--state--repo-calls)
11. [Upload Payload Construction — Multipart](#11-upload-payload-construction--multipart)
12. [Data Models & DTOs](#12-data-models--dtos)
13. [Backend API Reference](#13-backend-api-reference)
14. [WebSocket Real-Time Protocol](#14-websocket-real-time-protocol)
15. [Navigation Map](#15-navigation-map)
16. [Sequence Diagrams](#16-sequence-diagrams)
17. [Error Handling & Edge Cases](#17-error-handling--edge-cases)
18. [Performance Engineering](#18-performance-engineering)
19. [Security](#19-security)
20. [Dependencies Used](#20-dependencies-used)
21. [File Inventory](#21-file-inventory)
22. [Appendix A — Known Design Notes & Technical Debt](#22-appendix-a--known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **Resources Module** is a file library for faculty. It lists two independent scopes — **My Private** (`faculty_private`) and **College Shared** (`college_shared`) — behind a segmented toggle, and supports the full lifecycle of a resource: **upload** (multipart), **list**, **open/preview** (download via presigned URL), **system share**, **delete**, **push to a section** (SmartBoard), and **share to a class**. It is reached either from the app drawer (global "Resources") or from a course card (`ResourcesScreen(courseCode, courseName)`).

### 1.2 Business Goal

- Give faculty a **single place to manage teaching materials** (lecture notes, assignments, lab manuals, question banks) on the "Faculty Cloud".
- Keep a **personal scope** (My Private) separate from an **institutional scope** (College Shared) with distinct permissions — college-shared cards are read-only (no swipe-to-delete).
- Let faculty **share materials with sections** (SmartBoard push) and **with classes** without leaving the library.
- Reuse the module as the **only real network path** for the app's assignment-related artifacts: the `'Assignment'` category exists in the upload sheet, and the Assignments module itself never calls the upload API (see `ASSIGNMENTS_MODULE.md`).

### 1.3 Problem Statement

- Teaching materials live server-side as opaque blobs; the app needs a **metadata-first** list so browsing never downloads files.
- Opening or sharing a file must work through the app's authenticated backend (a presigned URL is issued per request).
- Uploads are large (up to 50 MB) and need **progress feedback** plus strict type/size validation before leaving the device.

### 1.4 Solution

- A `ChangeNotifier` controller (`ResourcesController`) holds two in-memory lists, loading flags, upload progress, and a shared error string.
- A single `StatefulWidget` (`ResourcesScreen`) renders the toggle, the swipeable list, the upload bottom sheet, and the share/push sheets.
- A `ResourceRepository` wraps `ApiClient().dio` for all REST and performs **client-side validation** (extension whitelist, existence, 50 MB cap) before constructing a multipart `FormData` upload.
- Opening/sharing is **never streamed in-app**: a presigned URL is fetched, the file is downloaded to the app temp dir with a plain `Dio()`, then handed to `open_filex` or the system share sheet.

### 1.5 Target Users

- **Faculty members** — reachable from the app drawer ("CONTENT → Resources") and from every course card in the Courses tab.

### 1.6 Faculty Workflow (Resources-driven)

```
AppDrawer → CONTENT → "Resources"
   └─ My Private | College Shared toggle
        ├─ tap card ──► preview (presigned URL → temp file → open_filex)
        ├─ more ⋮ ──► Share (system sheet) | Push to SmartBoard | Delete (private only)
        ├─ long-press 3s ──► Share to Class (course picker)
        ├─ swipe left/right ──► Delete (private only)
        └─ FAB Upload ──► pick file → category chip → description → upload (progress %)
```

---

## 2. Layered Architecture & Data Flow

```
┌───────────────────────────────────────────────────────────────────────────┐
│  PRESENTATION                                                             │
│  ResourcesScreen (StatefulWidget, own Scaffold, [1019 LOC])               │
│   ├─ _buildToggleBar        (My Private | College Shared)                 │
│   ├─ _buildResourceList     (Consumer<ResourcesController>)               │
│   ├─ _showUploadSheet       (file pick + category + progress)             │
│   ├─ _openResource/_shareFile (presigned URL + temp download)             │
│   ├─ _showPushToClassPicker / _showShareToClassSheet                      │
│   └─ reads FacultyService.profile / FacultyService.courses (static)       │
└──────────────┬────────────────────────────────────────────────────────────┘
               │ context.read<ResourcesController>()  ·  Consumer<ResourcesController>
┌──────────────▼────────────────────────────────────────────────────────────┐
│  CONTROLLER (ChangeNotifier, provider-lazy singleton)                     │
│  ResourcesController [107 LOC]                                            │
│   myResources · collegeResources · isLoading · isUploading               │
│   uploadProgress · error                                                  │
│   loadResources · uploadResource · deleteResource · getPresignedUrl       │
│   pushToSection · pushToSession (dead) · clearError (dead)                │
└──────────────┬────────────────────────────────────────────────────────────┘
               │ direct method calls
┌──────────────▼────────────────────────────────────────────────────────────┐
│  REPOSITORY                                                               │
│  ResourceRepository [271 LOC]                                             │
│   getMyResources · getCollegeResources · uploadResource · deleteResource  │
│   getPresignedUrl · pushToSession · pushToSection                         │
│   _detectMimeType · isSupportedFile                                       │
└──────────────┬────────────────────────────────────────────────────────────┘
               │ ApiClient().dio (JWT bearer, interceptors, TLS)
┌──────────────▼────────────────────────────────────────────────────────────┐
│  INFRA / NETWORK                                                          │
│  ApiClient (Provider, Dio)  ·  baseUrl from _defaultBaseUrl / .env        │
└──────────────┬────────────────────────────────────────────────────────────┘
               │ HTTPS
      /api/v1/faculty/resources[/{id}[/presigned-url|push-to-*]]
      /api/v1/faculty/college-resources
      /api/v1/faculty/resources/upload        (multipart POST)
```

### 2.1 Data flow on screen load

```
ResourcesScreen.initState
   └─ postFrameCallback ──► context.read<ResourcesController>().loadResources()
        ├─ isLoading = true → notifyListeners
        ├─ Future.wait([ repo.getMyResources(),        GET /faculty/resources?scope=faculty_private
        │                 repo.getCollegeResources() ]) GET /faculty/college-resources
        ├─ _myResources / _collegeResources = results
        └─ isLoading = false → notifyListeners
Body renders inside Consumer<ResourcesController>:
   ├─ isLoading → Center(CircularProgressIndicator)   (both tabs share one flag)
   ├─ list empty → "No resources yet" empty state
   └─ else → RefreshIndicator + ListView.builder of swipeable cards
```

---

## 3. State Management Wiring

The module uses **Provider for DI + a `ChangeNotifier` controller** — the classic app pattern (unlike Profile, which is `ValueNotifier`-based).

| Concern | Mechanism |
|---|---|
| Controller registration | `ChangeNotifierProxyProvider<ResourceRepository, ResourcesController>` (lazy) at `main.dart:184–188`; `create/update` both build `ResourcesController(repo)` |
| Repository registration | `ProxyProvider<ApiClient, ResourceRepository>` at `main.dart:181–183` (lazy, reused) |
| State | `ResourcesController` (extends `ChangeNotifier`): `_myResources`, `_collegeResources`, `_isLoading`, `_isUploading`, `_uploadProgress`, `_error` |
| Screen reads | `context.read<ResourcesController>()` for actions (initState load, upload, delete, presigned URL, push) |
| Screen renders | `Consumer<ResourcesController>` around the list |
| Faculty identity | `FacultyService.profile.value` (static `ValueNotifier<FacultyProfile?>`) — read imperatively inside the upload sheet for `facultyId` |
| Class pickers | `FacultyService.courses.value` (static `ValueNotifier<List<Map<String, dynamic>>>`) — read for Share-to-Class and SmartBoard push |

**Key wiring fact:** a single lazy `ResourcesController` instance is shared by **every** `ResourcesScreen` pushed onto the stack (drawer entry + every per-course entry). State persists between pushes until `loadResources()` overwrites it (A-1).

---

## 4. Screen Structure — Widget Tree

```
Scaffold (bg: AppTheme.bg)
├─ AppBar (transparent, elevation 0, leading back → Navigator.pop)
│    └─ title Column: courseName ?? "Resources" (20 w900) + courseCode subtitle (12 teal)
├─ FloatingActionButton.extended (teal) "Upload" (cloud_upload_outlined)
│    └─ onPressed → _showUploadSheet(context)
└─ body: Column(mainAxisSize: min)
     ├─ _buildToggleBar()          segmented "My Private" | "College Shared"
     └─ Expanded(_buildResourceList())
          └─ Consumer<ResourcesController>
               ├─ controller.isLoading → Center(CircularProgressIndicator)
               ├─ resources.isEmpty → empty state (folder_open_rounded 64 + "No resources yet"
               │                      + "Tap Upload to add your first resource")
               └─ RefreshIndicator(onRefresh: loadResources)
                    └─ ListView.builder(padding bottom 100, BouncingScrollPhysics)
                         └─ _buildSwipeableCard(resource, controller)
                              ├─ scope == 'college_shared' → _buildResourceCard (no swipe)
                              └─ else → Dismissible(direction: horizontal,
                                       background/secondaryBackground: red "Delete",
                                       confirmDismiss: _confirmDelete)
```

---

## 5. `ResourcesScreen` — the List Hub

**File:** `lib/Presentation/Features/Resources/resources_screen.dart` (1019 LOC)

### 5.1 Public contract & lifecycle

```dart
class ResourcesScreen extends StatefulWidget {
  final String? courseCode;
  final String? courseName;
  const ResourcesScreen({Key? key, this.courseCode, this.courseName});
}
```

- Both parameters are optional: the drawer entry uses `const ResourcesScreen()` (no course context); `CoursesScreen` pushes `ResourcesScreen(courseCode: code, courseName: subject)` (`courses_screen.dart:120`).
- `initState` kicks `loadResources()` via `WidgetsBinding.addPostFrameCallback` (post-frame so the `Provider` lookup is safe).
- `dispose` cancels the long-press `Timer`.

### 5.2 Toggle bar (`_buildToggleBar`, lines 97–154)

- A segmented pill (16-radius container, surface fill, border). `_showCollegeShared` (local `setState`) selects **"My Private"** or **"College Shared"**.
- The active segment gets a teal fill; the inactive one is transparent with secondary text. No animation — a plain conditional recolor.

### 5.3 Resource list (`_buildResourceList`, lines 156–193)

- Reads `_showCollegeShared ? controller.collegeResources : controller.myResources`.
- **Loading**: a single `controller.isLoading` gates the whole body — both tabs blank while `Future.wait` runs (A-2).
- **Empty**: per-tab empty state (folder icon + "No resources yet" + "Tap Upload to add your first resource").
- **Data**: `RefreshIndicator` (pull-to-refresh → `loadResources`) wrapping a `ListView.builder` with bottom padding 100 (clears the FAB). Cards keyed by `ValueKey(resource.id)`.

### 5.4 Swipeable card wrapper (`_buildSwipeableCard`, lines 197–243)

- `scope == 'college_shared'` → plain card (**no delete affordance** anywhere: no swipe, and the ⋮ menu hides Delete).
- Private resources → `Dismissible` horizontal with red "Delete" backgrounds on both sides; `confirmDismiss` → `_confirmDelete` (A-3: the dialog always pops `false`, so the Dismissible never animates a dismissal; the item disappears only because the controller mutates its list and rebuilds).

### 5.5 Resource card (`_buildResourceCard`, lines 245–325)

- **Icon + color by type** (from the model's `isPdf` / `isPowerpoint` / `isWord` / `isImage`): PDF red, PPT orange, Word blue, image green, else neutral drive-file icon, all on a 10% tinted square.
- **Metadata row**: `fileSizeFormatted` • dot • `createdAtFormatted` (both ellipsized).
- **Interactions**:
  - Tap → `_openResource(resource)`.
  - Long-press 3 s (`Timer`) → `HapticFeedback.heavyImpact()` + `_showShareToClassSheet` (no visible hint that this affordance exists — A-4).
  - ⋮ `more_vert` → `_showResourceMenu`.

### 5.6 Three-dot menu (`_showResourceMenu`, lines 387–437)

Bottom sheet with file name + size/date header and:
- **Share** → `_shareFile` (system share sheet).
- **Push to SmartBoard** → `_showPushToClassPicker`.
- **Delete** → only when `resource.scope != 'college_shared'`; routes to the same `_confirmDelete` as swipe.

---

## 6. Upload Flow — `_showUploadSheet`

**Lines 753–1035.** A `showModalBottomSheet` (isScrollControlled, `StatefulBuilder`) that owns its own picker state — separate from the controller:

| Local sheet state | Meaning |
|---|---|
| `pickedFilePath / pickedFileName / pickedExtension / pickedFileSize` | result of `FilePicker` (single file) |
| `description` | optional text field value |
| `category` | default `'Lecture Notes'`, one of the chip list |
| `isUploading / uploadProgress / uploadError` | in-sheet progress + error (mirrors the controller) |

### 6.1 Steps (validated in order)

1. **Pick file** — `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: [...])` (full list in §7).
2. **Category** — `ChoiceChip` `Wrap` of `['Lecture Notes', 'Assignment', 'Lab Manual', 'Question Bank', 'Other']`; default `'Lecture Notes'`.
3. **Description** — optional 2-line `TextField`.
4. **Upload button** — disabled until a file is picked. Guards in order:
   - no file → `'No file selected'`
   - `FacultyService.profile.value == null || facultyId.isEmpty` → `'Missing authentication. Please login again.'`
   - `category.isEmpty` → `'Missing category'`
5. **Execute** → `rc.uploadResource(filePath, fileName, facultyId: profile.facultyId, courseId: widget.courseCode, category, description: non-empty ? description : null)`.
6. **Feedback** — success → pop sheet + teal SnackBar "Uploaded successfully"; failure → in-sheet red error banner from `rc.error`.

### 6.2 Progress UI (lines 988–1027)

While `isUploading`, the form is replaced by a 64 px circular ring with a `"${(progress*100).toInt()}%"` center label plus a `LinearProgressIndicator`. Both use `value: progress > 0 ? progress : null` — i.e. **indeterminate until the first send chunk arrives** (A-5).

---

## 7. File Pickers & the File-Type Whitelist

The whitelist is declared **twice** — once in the UI picker, once in the repository:

| Allowed extension | Picker (`resources_screen.dart:801`) | Repository `isSupportedFile` (`resource_repository.dart:82`) |
|---|---|---|
| `pdf, doc, docx, ppt, pptx, xls, xlsx, txt, csv, jpg, jpeg, png, zip` | `FileType.custom` filter | extension whitelist (upload guard) |

- The picker restrict list is **identical** to the repository whitelist today; they are independent constants, so a future drift would let the picker offer a file the backend rejects (A-6).
- MIME types are derived **from the extension** by `_detectMimeType` (`resource_repository.dart:60–78`) — a `.docx` is declared `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, etc.; anything else falls back to `application/octet-stream`. There is **no content sniffing** (A-6).

---

## 8. Open / Download / Share — Presigned-URL Flow

### 8.1 `_openResource` (lines 329–353)

```
tap card ──► _showLoadingDialog("Opening...")
   ├─ controller.getPresignedUrl(resource.id)      GET /faculty/resources/{id}/presigned-url
   │    └─ success==false || url==null → pop dialog + error SnackBar ("Unable to open file.")
   ├─ dir = await getTemporaryDirectory()
   ├─ tempPath = "{dir}/preview_{resource.id}_{resource.fileName}"
   ├─ plainDio = Dio()                             // NOT ApiClient().dio
   ├─ await plainDio.download(url, tempPath)       // presigned URL is the auth
   └─ await OpenFilex.open(tempPath)               // OS handler (PDF viewer, etc.)
catch → debugPrint("Preview error") + pop dialog + "Unable to preview this file."
```

### 8.2 `_shareFile` (lines 441–462)

Same shape: presigned URL → `share_{resource.id}_{resource.fileName}` in the temp dir → `Share.shareXFiles([XFile(tempPath)], text: resource.fileName)`.

### 8.3 Shared characteristics

- Both use a **fresh plain `Dio()`** (no `ApiClient` interceptors — by design the presigned URL is the credential; the app-wide JWT/logging interceptors are skipped for the blob download).
- Full-file download into the temp dir with **no progress UI and no cancel**; large files block the "Opening…"/"Preparing file…" dialog for the whole transfer (A-7).
- Temp files are **never cleaned up** after open/share (A-8).
- `Navigator.of(context, rootNavigator: true).pop()` pops the loading dialog; `mounted` is re-checked before the error SnackBar.

---

## 9. Push to SmartBoard & Share-to-Class

Two overlapping sheets, both driven by `FacultyService.courses.value` (maps with `course`/`name`, `code`/`id`, `section` keys):

### 9.1 Share-to-Class (long-press 3 s, `_showShareToClassSheet`, lines 466–570)

- Empty classes → orange SnackBar "No classes assigned".
- Non-scrollable bottom sheet listing classes (subject, `code • Sec section`), tap → `_pushToClass(resource, controller, code, subject)`.
- `_pushToClass` (lines 572–597): optimistic purple SnackBar "Pushing to …", then `controller.pushToSection(resource.id, classCode)`; result SnackBar teal "Shared to …" / red `controller.error`.

### 9.2 Push to SmartBoard (⋮ menu, `_showPushToClassPicker`, lines 626–749)

- `DraggableScrollableSheet` (0.4–0.9, initial 0.75) over a 75% sheet height; same course rows with `cast_connected_rounded`; tap → same `_pushToClass` (i.e. both features call `pushToSection`).

### 9.3 Controller-level push

- `pushToSection` → `POST /faculty/resources/{id}/push-to-section` body `{section_id}`.
- **`pushToSession` exists end-to-end** (`resources_controller.dart:98`, `resource_repository.dart:256`, `POST /faculty/resources/{id}/push-to-session`) but **is never called from any UI** — dead API surface (A-9).

---

## 10. `ResourcesController` — State & Repo Calls

**File:** `lib/Presentation/Features/Resources/resources_controller.dart` (107 LOC)

| Member | Behavior |
|---|---|
| `myResources` / `collegeResources` | `List<ResourceItem>` getters over private fields |
| `isLoading` | set true + `notifyListeners` before `Future.wait`; false after |
| `loadResources()` | **Parallel** fetch of both lists; `_error = null` first; repository swallows its own exceptions → returns `[]` (A-2) |
| `isUploading` / `uploadProgress` | set by `uploadResource`; progress pushed via `onProgress` callback |
| `uploadResource(...)` | delegates to repo; on success sets `uploadProgress = 1.0`, `notifyListeners`, then **re-runs `loadResources()`**; returns `bool` |
| `deleteResource(id)` | on success `removeWhere` from **both** lists + `notifyListeners` |
| `getPresignedUrl(id)` | thin passthrough returning `Map<String, dynamic>` |
| `pushToSession(id, sessionId)` | **never called from UI** (A-9) |
| `pushToSection(id, sectionId)` | called from `_pushToClass` only |
| `clearError()` | **never called from UI** (A-10) |
| `error` | shared `String?`; overwritten by upload/delete/push failures; never auto-cleared between operations except by `loadResources` |

**Note on `loadResources` and errors:** the repository catches every failure and returns `[]`, so `Future.wait` never throws; a failed fetch renders the **empty state** ("No resources yet") rather than an error state — the failure is invisible to the user (A-2).

---

## 11. Upload Payload Construction — Multipart

`ResourceRepository.uploadResource` (`resource_repository.dart:85–216`) is a **multipart** upload (not base64).

### 11.1 Pre-flight validation (client-side, in order)

| Guard | Result on failure |
|---|---|
| `!isSupportedFile(fileName)` | `{'success': false, 'error': 'Unsupported file type'}` |
| `!File(filePath).existsSync()` | `'File not found'` |
| `fileSize > 50 * 1024 * 1024` | `'File too large. Maximum size is 50 MB.'` |
| `facultyId.isEmpty` | `'Missing authentication'` |
| `category.isEmpty` | `'Missing category'` |

### 11.2 FormData fields

```dart
FormData.fromMap({
  'faculty_id':  facultyId,
  'course_id':   courseId,          // optional (only if non-empty)
  'subject_id':  subjectId,         // optional (only if non-empty) — ALWAYS null from the UI
  'category':    category,
  'description': description,       // optional (only if non-empty)
  'filename':    fileName,
  'mime_type':   mimeType,          // _detectMimeType(fileName) — extension-derived
  'file':        await MultipartFile.fromFile(filePath, filename: fileName),
});
```

- Sent via `ApiClient().dio.post('/api/v1/faculty/resources/upload', data: formData, options: Options(contentType: 'multipart/form-data', sendTimeout: 120s, receiveTimeout: 120s), onSendProgress: ...)`.
- `onSendProgress` reports `sent / total` → controller `uploadProgress`.
- Success = HTTP `200` **or** `201`; the response body is merged into the result map (`{'success': true, ...body}`).
- Error paths: HTTP 400 → per-field validation error extraction (`data.forEach`), timeouts → "Server unavailable. Please try again.", connection errors → "Server unavailable. Check your internet connection.", otherwise `message/detail/error` from the body.

### 11.3 Notable payload facts

- **`course_id` is actually the course *code***: the screen passes `courseId: widget.courseCode` (e.g. `'CS201'`), not a numeric course ID (A-11).
- **`subject_id` is never populated** — `uploadResource` is called with `subjectId` omitted everywhere, so that branch of the payload is dead (A-11).
- **`faculty_id` = the faculty email**: `FacultyService.profile.value.facultyId`, which the Profile docs establish equals the canonical email (`FacultyService.canonicalId => profile.value?.email`, `faculty_service.dart:90`).

---

## 12. Data Models & DTOs

| Model | File (LOC) | Fields / Notes |
|---|---|---|
| `ResourceItem` | `lib/Data/Models/Faculty/resource_model.dart` (63) | `id`, `facultyId`, `fileName`, `fileSize` (int), `mimeType`, `scope`, `securityStatus`, `createdAt?`, `institutionId?`, `allowedSections` (List<String>), `subjectCode?` |

### 12.1 `ResourceItem.fromJson`

Tolerant snake_case parsing: `id` (toString fallback `''`), `faculty_id`, `file_name` (fallback `'Unknown'`), `file_size` (`as int? ?? 0`), `mime_type` (fallback `'application/octet-stream'`), `scope` (fallback `'faculty_private'`), `security_status` (fallback `'UNKNOWN'`), `created_at`, `institution_id`, `allowed_sections`, `subject_code`.

### 12.2 Computed getters (used by the UI)

| Getter | Purpose |
|---|---|
| `fileSizeFormatted` | B / KB (1 decimal) / MB (1 decimal) |
| `fileExtension` | last dot segment uppercased; `'FILE'` if none |
| `createdAtFormatted` | `d/M/y` via `DateTime.parse`; raw string or `'-'` on failure |
| `isPdf` / `isPowerpoint` / `isWord` | `mimeType.contains(...)` **OR** filename-extension fallback |
| `isImage` | `mimeType.startsWith('image/')` |

No `toJson` (uploads are built from raw fields, never from the model), no equality override, no caching layer.

---

## 13. Backend API Reference

| # | Endpoint | Verb | Used by | Notes |
|---|---|---|---|---|
| 1 | `/api/v1/faculty/resources?scope=faculty_private[&subject_code=...]` | GET | `ResourceRepository.getMyResources` | optional `subject_code` param exists but is **never passed** by the controller (A-12); expects a JSON array of `ResourceItem` |
| 2 | `/api/v1/faculty/college-resources[?subject_code=...]` | GET | `ResourceRepository.getCollegeResources` | same; `subject_code` never passed (A-12) |
| 3 | `/api/v1/faculty/resources/upload` | POST | `ResourceRepository.uploadResource` | multipart form (fields §11.2); ≤ 50 MB; 120 s send/receive; accepts 200/201 |
| 4 | `/api/v1/faculty/resources/{resourceId}` | DELETE | `deleteResource` | success judged by HTTP 200 + Map body |
| 5 | `/api/v1/faculty/resources/{resourceId}/presigned-url` | GET | `getPresignedUrl` | returns `{'success': true, ...body}` where body holds the download `url` |
| 6 | `/api/v1/faculty/resources/{resourceId}/push-to-section` | POST | `pushToSection` (via `_pushToClass`) | body `{section_id}` |
| 7 | `/api/v1/faculty/resources/{resourceId}/push-to-session` | POST | `pushToSession` | body `{session_id}`; **dead at UI level** (A-9) |

All requests go through `ApiClient().dio` (JWT bearer, interceptors, TLS) **except** the two blob downloads in `_openResource`/`_shareFile`, which use a fresh `Dio()`.

**Base URL (verified):** `api_client.dart:19` → `static const _defaultBaseUrl = 'https://api-dev.balaseetharamanjaneyulu.com';` (overridable via `dotenv.env['API_BASE_URL']`, `api_client.dart:33`). Note: some companion docs (`ANALYTICS_MODULE.md`, `PROFILE_MODULE.md`) print `...janeya.com` — a domain spelling drift (A-13).

---

## 14. WebSocket Real-Time Protocol

The Resources module opens **no WebSocket channels** and has no real-time dependency. The list is strictly pull-based (`loadResources` on entry + `RefreshIndicator`). The only shared real-time-adjacent state is `FacultyService.courses` / `profile`, which are populated by the manifest sync (Profile module) and read imperatively by the pickers — no subscription.

---

## 15. Navigation Map

```
AppDrawer ("CONTENT" section, app_drawer.dart:101–105)
   └─ "Resources" (folder_rounded, subtitle "Upload & manage materials")
        └─ Navigator.push ──► ResourcesScreen()                     (no course context)

CoursesScreen (courses_screen.dart:115–122)
   └─ course card tap (HapticFeedback.mediumImpact)
        └─ Navigator.push ──► ResourcesScreen(courseCode: code, courseName: subject)
             ├─ AppBar back ──► Navigator.pop
             └─ FAB Upload ──► _showUploadSheet (bottom sheet)

Within ResourcesScreen (no separate routes — all modal):
   ├─ card tap          ──► _openResource            (loading dialog → temp file → open_filex)
   ├─ ⋮ menu            ──► bottom sheet: Share / Push to SmartBoard / Delete
   ├─ long-press 3 s    ──► _showShareToClassSheet   (bottom sheet, course rows)
   └─ swipe             ──► _confirmDelete (AlertDialog)
```

All routes are anonymous `MaterialPageRoute`s; every auxiliary surface is a bottom sheet or dialog. There is **no deep link and no route name** for Resources.

---

## 16. Sequence Diagrams

### 16.1 Upload a resource

```
FAB "Upload" ──► _showUploadSheet
   ├─ FilePicker.pickFiles(type: custom, [13 extensions])
   │    └─ picked file (path/name/ext/size) → sheet state
   ├─ category chip (default 'Lecture Notes') · optional description
   └─ Upload pressed (guards: file → auth → category)
        └─ rc.uploadResource(filePath, fileName, facultyId=email,
               courseId=widget.courseCode, category, description?)
             └─ repo.uploadResource
                  ├─ pre-flight: whitelist → exists → ≤50MB → auth → category
                  ├─ FormData.fromMap{...} + MultipartFile.fromFile
                  ├─ dio.post(/faculty/resources/upload, 120s timeouts,
                  │      onSendProgress: sent/total → controller.uploadProgress → sheet ring %)
                  ├─ 200/201 → {'success': true} → controller.uploadProgress=1.0
                  │      → await loadResources() (parallel re-fetch)
                  │      → sheet pops + SnackBar "Uploaded successfully"
                  └─ error → {'success': false, 'error'} → in-sheet red banner (rc.error)
```

### 16.2 List refresh (entry / pull-to-refresh)

```
ResourcesScreen.initState ──► postFrame ──► rc.loadResources()
   └─ Future.wait([
        repo.getMyResources():    GET /faculty/resources?scope=faculty_private → List<ResourceItem> ([] on any error)
        repo.getCollegeResources(): GET /faculty/college-resources            → List<ResourceItem> ([] on any error)
      ])
   └─ _myResources / _collegeResources updated → notifyListeners
        └─ Consumer rebuild → toggle tab renders its list (loading spinner → data/empty)
```

### 16.3 Open / download a resource

```
card tap ──► _showLoadingDialog("Opening...")
   ├─ controller.getPresignedUrl(id)  → GET /faculty/resources/{id}/presigned-url
   │    ├─ success==false || url==null → pop dialog + error SnackBar
   │    └─ url ok → getTemporaryDirectory() → tempPath = preview_{id}_{fileName}
   ├─ plainDio = Dio()  (no ApiClient interceptors)
   ├─ await plainDio.download(url, tempPath)      (no progress, no cancel)
   └─ await OpenFilex.open(tempPath)              → OS handler / viewer
catch → debugPrint("Preview error") + pop dialog + "Unable to preview this file."
```

---

## 17. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| List fetch failure | Repository swallows all exceptions → returns `[]`; screen shows **"No resources yet"** empty state, no error surface (A-2) |
| `Future.wait` mid-failure | Both repo methods are exception-proof, so `loadResources` can't throw |
| Unsupported file type | Upload rejected client-side `'Unsupported file type'` |
| File deleted on device | `'File not found'` |
| File > 50 MB | `'File too large. Maximum size is 50 MB.'` |
| No faculty profile / empty facultyId | Upload sheet: `'Missing authentication. Please login again.'` |
| Missing category | `'Missing category'` (unreachable — category is a chip with a default) |
| HTTP 400 on upload | Per-field validation errors extracted (`key: value` joined); `message/detail/error` preferred |
| Timeout / connection error | `'Server unavailable…'` / `'Server unavailable. Check your internet connection.'` |
| Presigned URL failure / null url | Error SnackBar (`result['error']` or `'Unable to open file.'` / `'Unable to share file.'`) |
| Blob download throws | `debugPrint` + `'Unable to preview this file.'` / `'Unable to share this file.'` |
| No classes for push/share | Orange SnackBar `'No classes assigned'` |
| Delete failure | `controller.error` SnackBar (default `'Delete failed'`) |
| Cancel delete | AlertDialog "Cancel" → `false` (item stays) |
| Confirmed delete | Dialog always pops `false` to the Dismissible (A-3); item removed via controller `removeWhere` + rebuild |
| Re-entrancy / double taps | No single-flight on `loadResources`; a pull-to-refresh during an upload re-fetch is unguarded |
| `mounted` after async | All async continuations guard with `mounted` before `ScaffoldMessenger`/navigation |

---

## 18. Performance Engineering

- **Metadata-only lists**: list GETs return `ResourceItem` JSON; file blobs are never downloaded until an explicit open/share — the list is light.
- **Parallel list fetch**: `Future.wait` over private + college GETs collapses two round-trips into one wait.
- **`ListView.builder`** with `ValueKey(resource.id)` keys — items are built lazily; `Dismissible` backgrounds are cheap containers.
- **No caching / no persistence**: every entry and every pull-to-refresh re-fetches cold from the network (A-12).
- **Shared loading flag**: one `isLoading` blanks both tabs (A-2); acceptable for a two-list fetch but suboptimal when only one scope is slow.
- **Blob I/O on open/share**: full-file synchronous download to temp with a plain `Dio()` and no progress — a 50 MB file holds the "Opening…" dialog open for the entire transfer (A-7).
- **`RefreshIndicator`** is the only refresh affordance; long-press timer is cancelled on `dispose` and on `onLongPressEnd`/`onLongPressCancel`.

---

## 19. Security

- **Transport**: all CRUD via `ApiClient().dio` (JWT bearer interceptor, TLS per app standard). Blob downloads use a **plain `Dio()`** — deliberately credential-free because the presigned URL itself is the authorization (still: app-wide interceptors/error handling are bypassed).
- **Auth identity**: `faculty_id` = canonical email (`FacultyService.profile.value.facultyId`), never user-typed input; the upload sheet refuses to run without a profile.
- **Client-side file validation**: extension whitelist + existence + 50 MB cap before any bytes leave the device.
- **MIME trust boundary**: `mime_type` is derived from the **filename extension**, not content sniffing — a renamed `.exe` could be declared `application/pdf` (A-6). The backend is assumed to re-validate.
- **Path hygiene**: uploads use `File(filePath)` from the OS file picker; temp download paths embed `resource.id` + `fileName` (server-controlled values) into a path — a hostile `fileName` could inject path separators into the temp path (A-14).
- **Scope enforcement (client-side only)**: college-shared cards hide Delete/swipe in the UI; nothing stops a crafted API call — server-side ownership checks are assumed.
- **Data exposure**: list shows file name/size/date only; no content is rendered in-app (open delegates to `open_filex`).

---

## 20. Dependencies Used

| Package (pubspec) | Where used |
|---|---|
| `provider` ^6.0.5 | `ChangeNotifierProxyProvider`, `Consumer`, `context.read` |
| `dio` ^5.3.3 | repo REST via `ApiClient`; plain `Dio()` blob downloads |
| `file_picker` ^10.3.10 | upload picker (`FileType.custom` + whitelist) |
| `share_plus` ^12.0.2 | `Share.shareXFiles` system sheet |
| `open_filex` ^4.7.0 | `OpenFilex.open` on the downloaded temp file |
| `path_provider` ^2.1.3 | `getTemporaryDirectory()` for open/share staging |
| `google_fonts` ^6.1.0 | Inter typography across the screen |
| `url_launcher` ^6.3.0 | **imported but unused** in `resources_screen.dart:7` (dead import — A-15) |

Not used by this module despite being in pubspec: `pdf`, `excel`, `csv`, `printing` (report generation lives elsewhere).

---

## 21. File Inventory

> Line counts = `Measure-Object -Line` (non-blank, per repo convention).

### 21.1 Resources feature — `lib/Presentation/Features/Resources/`

| File | LOC | Role |
|---|---|---|
| `resources_screen.dart` | 1019 | Toggle list + upload sheet + open/share/push/delete flows |
| `resources_controller.dart` | 107 | `ChangeNotifier`: lists, loading, upload progress, repo delegation |

### 21.2 Data layer

| File | LOC | Role |
|---|---|---|
| `lib/Data/Repositories/resource_repository.dart` | 271 | All REST, multipart upload, MIME/whitelist validation |
| `lib/Data/Models/Faculty/resource_model.dart` | 63 | `ResourceItem` DTO + formatted getters |

### 21.3 Supporting surfaces

| File | LOC | Role |
|---|---|---|
| `lib/main.dart` | 278 | Provider graph: `ResourceRepository` (181–183), `ResourcesController` (184–188) |
| `lib/Presentation/Widgets/app_drawer.dart` | 375 | Drawer "CONTENT → Resources" entry (lines 101–105) |
| `lib/Presentation/Features/Courses/courses_screen.dart` | 222 | Per-course entry `ResourcesScreen(courseCode, courseName)` (lines 115–122) |
| `lib/Services/faculty_service.dart` | 480 | `profile`/`courses` notifiers consumed by the upload sheet and class pickers |

---

## 22. Appendix A — Known Design Notes & Technical Debt

### A-1. Single shared `ResourcesController` across all resource screens (MEDIUM)

A lazy provider serves the drawer entry and every per-course `ResourcesScreen`. Navigating course A → Resources → back → course B reuses the same instance, so course A's lists persist in memory until `loadResources()` overwrites them (a possible flash of the previous course's data). `courseCode` also only affects uploads — the lists themselves are never filtered by course.

### A-2. List failures are invisible (MEDIUM)

`getMyResources`/`getCollegeResources` catch all exceptions and return `[]`, so a network failure renders the friendly **"No resources yet"** empty state. There is no error banner, no retry button, and no distinction between "empty" and "failed". The single `isLoading` flag also blanks both tabs during one slow fetch.

### A-3. `Dismissible` never actually dismisses (LOW)

`_confirmDelete` always pops `false` (the delete runs afterward and the controller `removeWhere`s the item). The swipe animation is never completed by Dismissible; removal is purely a list-rebuild side effect. Confusing interaction semantics if the rebuild is delayed.

### A-4. Long-press 3 s share-to-class is a hidden affordance (LOW)

No UI hint (icon, label, tooltip) tells the user that holding a card for 3 seconds shares it to a class. The only discoverability path is the ⋮ menu's "Push to SmartBoard".

### A-5. Upload progress is indeterminate until first chunk (LOW)

`CircularProgressIndicator.value` and `LinearProgressIndicator.value` are null (indeterminate) while `uploadProgress == 0`, which persists until the first `onSendProgress` fires — for small files this may be the whole upload.

### A-6. Extension-derived MIME types (MEDIUM)

`_detectMimeType` trusts the filename extension; no content sniffing. A renamed malicious file is labeled `application/pdf` etc. The backend is assumed to re-validate the byte stream. Additionally, the picker whitelist and the repository whitelist are duplicated constants that can drift.

### A-7. Open/share download whole file with no progress/cancel (MEDIUM)

`_openResource` and `_shareFile` `await plainDio.download` the complete blob (up to 50 MB) behind a modal dialog with no progress bar and no cancel. Large files can hang the "Opening…"/"Preparing file…" dialog for a long time.

### A-8. Temp files are never cleaned up (LOW)

`preview_{id}_{fileName}` and `share_{id}_{fileName}` accumulate in `getTemporaryDirectory()` on every open/share; no deletion after `OpenFilex.open`/`Share.shareXFiles`.

### A-9. `pushToSession` is dead code (LOW)

`ResourcesController.pushToSession` (`resources_controller.dart:98`) and `ResourceRepository.pushToSession` (`resource_repository.dart:256`, `POST .../push-to-session`) are implemented end-to-end but **never invoked** by any UI. Either wire a live-session picker or remove the surface.

### A-10. `clearError()` is dead code (LOW)

`ResourcesController.clearError` (`resources_controller.dart:118`) is never called; the screen only reads `controller.error` in failure SnackBars/banners. A stale `_error` from a prior operation can surface in a later unrelated operation.

### A-11. Payload field semantics: `course_id` is a code, `subject_id` never sent (MEDIUM)

The screen passes `courseId: widget.courseCode` (e.g. `'CS201'`), so the multipart `course_id` field carries a course code, not a numeric course id. The `subject_id` branch of the payload is unreachable (no caller supplies it). Backend contracts for these fields should be confirmed.

### A-12. `subject_code` filter never used; no caching (LOW)

`getMyResources({subjectCode})` and `getCollegeResources({subjectCode})` accept `subject_code`, but the controller always calls them without arguments, so every screen shows the full faculty/college lists regardless of course. Combined with no Hive/SharedPreferences caching, every entry is a cold double GET.

### A-13. Base-URL spelling drift across docs (LOW)

Verified `_defaultBaseUrl` is `https://api-dev.balaseetharamanjaneyulu.com` (`api_client.dart:19`), but `ANALYTICS_MODULE.md` and `PROFILE_MODULE.md` document `...janeya.com`. One of the two spellings is wrong; worth reconciling in docs.

### A-14. Temp-path injection surface (LOW)

Download paths interpolate `resource.id` and `resource.fileName` (server-controlled) into the temp path without sanitization. A hostile file name containing path separators could escape the intended temp directory.

### A-15. Dead import: `url_launcher` (LOW)

`resources_screen.dart:7` imports `package:url_launcher/url_launcher.dart`; no `launchUrl`/`canLaunchUrl` call exists in the file. Remove or wire (e.g. open the presigned URL in an external browser as an alternative to in-app download).

---

*End of Resources Module technical documentation. Companion: `HOME_MODULE.md`, `COURSES_MODULE.md`, `ASSIGNMENTS_MODULE.md`, `PROFILE_MODULE.md`.*
