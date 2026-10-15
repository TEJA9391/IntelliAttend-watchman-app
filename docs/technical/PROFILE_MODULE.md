# IntelliAttend Faculty — Profile Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Profile (Identity, Appearance, Security & Support)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/HOME_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/MYCLASS_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`ProfileScreen` — the Hub Tab](#5-profilescreen--the-hub-tab)
6. [`ProfileModalContent` & `AppDrawer`](#6-profilemodalcontent--appdrawer)
7. [`QRScannerScreen`](#7-qrscannerscreen)
8. [Identity Features (QR ID & Digital ID Card)](#8-identity-features-qr-id--digital-id-card)
9. [Security & Access (Change Password / Login Devices)](#9-security--access-change-password--login-devices)
10. [Help & Support Pages](#10-help--support-pages)
11. [`FacultyService` & `FacultyProfile` — Data Layer](#11-facultyservice--facultyprofile--data-layer)
12. [`ThemeController`](#12-themecontroller)
13. [`AuthRepository` & `SessionManagementService`](#13-authrepository--sessionmanagementservice)
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
24. [Appendix A — Known Design Notes & Technical Debt](#24-appendix-a--known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **Profile Module** is the fourth tab of the faculty shell (`DashboardScreen` `IndexedStack`, index 3) and the identity/account surface of the app. It is a **view-and-settings hub**: it displays the faculty member's canonical identity (from the server manifest), lets them change the in-app avatar, toggle the app theme, manage credentials and login devices, and reach the identity artifacts (QR Code ID, Digital ID Card) plus the help/support surface.

### 1.2 Business Goal

- Give faculty a **single, authoritative profile view** fed by the `/api/v1/faculty/sync` manifest and the Hive cache — instant on cold start, refreshed in the background.
- Provide **self-service security controls**: password change (Firebase re-auth) and per-device session revocation.
- Surface **identity proofs** (QR verification ID, virtual faculty ID card) without opening a separate portal.
- Route **support** (About / Help Center / Report Issue / Live Chat) from one place.

### 1.3 Problem Statement

- Faculty identity lives on the backend; the app must render it cache-first so the profile tab is usable offline.
- Account security (password, sessions) is usually buried in settings menus; the module centralises it under "Security & Access".
- Support needs are ad-hoc; the module funnels them to help/chat/reporting in one vertical scroll.

### 1.4 Solution

- `FacultyService` acts as the **singleton profile store** (`ValueNotifier<FacultyProfile?>`), written by the manifest sync and read by every profile surface (tab, modal sheet, drawer header).
- A single `ListView` page with **six labelled sections** — Profile Header, Registration Identity, Appearance Settings, Security & Access, Identification, Help & Support.
- Identity widgets rendered entirely client-side: `QrImageView` over the faculty email (QR ID) and a gradient `Dialog` (Digital ID Card).
- Real API only where security demands it: `changePassword` (Firebase re-auth + update), `/api/v1/auth/sessions` (list/revoke). All support/help content is static or simulated (A-7/A-8).

### 1.5 Target Users

- **Faculty members** — the only audience. The profile tab is rendered at `DashboardScreen` tab index 3 for every logged-in faculty session.

### 1.6 Faculty Workflow (Profile-driven)

```
Dashboard → Tab 4: Profile
   ├─ Header (avatar + name/dept/designation)
   │    ├─ tap avatar → full-image dialog
   │    └─ camera badge → Change Photo (camera/gallery → local persist)
   ├─ Registration Identity (Faculty Name/Designation/Department/Official Email)
   ├─ Appearance Settings (theme toggle → ThemeController)
   ├─ Security & Access → ChangePasswordScreen | LoginDevicesScreen
   ├─ Identification → Digital ID Card dialog | QR Code ID dialog
   └─ Help & Support → AboutAppPage | HelpCenterPage | ReportIssuePage
```

---

## 2. Layered Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│  PRESENTATION                                                       │
│  ProfileScreen (tab) • ProfileModalContent (sheet) • AppDrawer       │
│  QRScannerScreen • ChangePasswordScreen • LoginDevicesScreen        │
│  DeviceDetailScreen • About/Help/ReportIssue/LiveSupportChat        │
└──────────────┬──────────────────────────────────────────────────────┘
               │ ValueListenableBuilder / read()
┌──────────────▼──────────────────────────────────────────────────────┐
│  SERVICES (singleton, stateless facades)                            │
│  FacultyService      → profile/stats/courses ValueNotifiers         │
│  ThemeController     → themeMode ValueNotifier + SharedPreferences  │
│  SessionManagementService → GET/DELETE /api/v1/auth/sessions        │
└──────┬──────────────────────────────┬───────────────────────────────┘
       │                              │
┌──────▼──────────────────┐   ┌───────▼───────────────────────────────┐
│  REPOSITORY             │   │  INFRA / NETWORK / DB                  │
│  AuthRepository (Firebase)│  │  ApiClient (Dio, JWT, interceptors)  │
│  changePassword, signOut│   │  FirebaseAuth (reauth, updatePassword)│
└──────┬──────────────────┘   │  Hive facultyBox (profile/stats),      │
       │                      │  SharedPreferences (is_logged_in,     │
       │                      │  is_dark_mode)                         │
       │                      │  HardwareService (device snapshot)     │
       └──────────────────────┴────────────────────────────────────────┘
                │ HTTPS / Firebase
        /api/v1/faculty/sync  •  /api/v1/auth/sessions[/:id]
```

### 2.1 Data flow on Profile tab load

```
ProfileScreen.initState → FacultyService.load()
   ├─ _loadCompleter guard (dedupe concurrent loads)
   ├─ loadFromCache() → facultyBox['profile'], ['stats'], academicBox['courses']
   │     └─ if courses empty → deriveCoursesFromCohorts() (academicBox['cohorts'])
   ├─ if profile cached → resolve immediately (UI unblocked)
   └─ else GET /api/v1/faculty/sync → profile block → persist to facultyBox
         └─ initializeListeners() (background): FacultyHydrationService.syncIfNeeded()
              ├─ updated/firstSync → loadFromCache()
              ├─ unchanged → serve cache
              └─ noNetwork → serve cache
```

---

## 3. State Management Wiring

The Profile module does **not** use `ChangeNotifier`/`Provider` for profile state. It is built on **`ValueNotifier` + `ValueListenableBuilder`** (plain Flutter), plus one `context.read<AuthRepository>()` access for password/session operations.

| Notifier (singleton static) | Type | Consumers |
|---|---|---|
| `FacultyService.profile` | `ValueNotifier<FacultyProfile?>` | `ProfileScreen` (header, rows), `ProfileModalContent`, `AppDrawer` header, `DashboardScreen` drawer builder |
| `FacultyService.stats` | `ValueNotifier<FacultyStats?>` | (reserved; used by dashboards) |
| `FacultyService.courses` | `ValueNotifier<List<Map<String,dynamic>>>` | `AppDrawer` "Student Directory" enrollment count, My Class, Courses |
| `FacultyService.isRegistered` | `ValueNotifier<bool>` | registration gate |
| `ThemeController.themeMode` | `ValueNotifier<ThemeMode>` | `ProfileScreen._buildThemeToggle`, `AppDrawer` theme item, `IntelliAttendApp` |

**Access pattern:** screens wrap profile-bound widgets in `ValueListenableBuilder<FacultyProfile?>(valueListenable: FacultyService.profile, ...)`, so edits like `FacultyService.updateProfileImage(...)` propagate live without a controller or rebuild of the whole tab.

**Reasoning (design note):** the app mixes `ChangeNotifier`/`Provider` (Dashboard, My Class) with `ValueNotifier` (Profile, Theme). This split is historical; both are valid but the coexistence should be acknowledged (A-11).

---

## 4. Screen Structure — Widget Tree

### 4.1 Profile tab route tree

```
DashboardScreen (IndexedStack index 3)
   └─ ProfileScreen (StatefulWidget)                              [968 LOC]
        ├─ CustomAppBar(title: "Profile", showBackButton: false,
        │     actions: [qr_code_scanner IconButton])
        └─ ListView (BouncingScrollPhysics)
             ├─ Profile Header (Row)
             │    ├─ avatar Stack (GestureDetector → _showFullImage)
             │    │    └─ ValueListenableBuilder → CircleAvatar
             │    │         (CachedNetworkImageProvider | FileImage | ui-avatars fallback)
             │    │         └─ camera badge → _showProfileHeaderOptions
             │    └─ Expanded (ValueListenableBuilder)
             │         ├─ name (22 w900)
             │         ├─ department (14 w500)
             │         └─ designation chip (10 w800, primary 0.1 tint)
             ├─ "REGISTRATION IDENTITY" section
             │    └─ _buildPlainRow ×4 (Faculty Name/Designation/Department/Official Email)
             ├─ "APPEARANCE SETTINGS" section → _buildThemeToggle (ListTile + Switch.adaptive)
             ├─ "SECURITY & ACCESS" section → _buildInteractiveTile ×2
             │    ├─ Change Password → ChangePasswordScreen
             │    └─ Login Devices → LoginDevicesScreen
             ├─ "IDENTIFICATION" section → _buildInteractiveTile ×2
             │    ├─ Digital ID Card → _showDigitalIdCard dialog
             │    └─ QR Code ID → _showQRCodeID dialog
             ├─ "HELP & SUPPORT" section → _buildInteractiveTile ×3
             │    ├─ About IntelliAttend → AboutAppPage
             │    ├─ Help Center → HelpCenterPage
             │    └─ Report an Issue → ReportIssuePage
             └─ Footer: "INTELLIATTEND FACULTY" + "© 2026 IntelliAttend Technologies."
```

### 4.2 Off-tab entry points into profile data

| Surface | Location | Purpose |
|---|---|---|
| `ProfileModalContent` | `dashboard_screen.dart:152` | Bottom sheet (85% height) on dashboard header avatar tap |
| `AppDrawer` profile header | `app_drawer.dart:207` | Teal header with avatar, name, role, "VERIFIED FACULTY" pill; Sign Out at bottom |

---

## 5. `ProfileScreen` — the Hub Tab

**File:** `lib/Presentation/Features/Profile/profile_screen.dart` (968 non-blank LOC)

### 5.1 Public contract & lifecycle

```dart
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
}
```

- `initState` → `_loadProfileData()` → `FacultyService.load()` (guard: the service short-circuits if `_isLoaded`).
- `_defaultAvatar` = `https://ui-avatars.com/api/?name=Faculty+User&background=2DD4BF&color=000` (network placeholder, A-2).

### 5.2 Header

- Avatar resolved through a `ValueListenableBuilder`: `profileImage` starting with `http` → `CachedNetworkImageProvider`; otherwise a local `FileImage`; null → the ui-avatars fallback.
- Avatar tap → `_showFullImage(context, p.profileImage)` (dialog with `CachedNetworkImage` placeholder/error widgets or `Image.file`).
- Camera badge (bottom-right, primary circle) → `_showProfileHeaderOptions` bottom sheet:
  - "Change Photo" → `_showImagePicker` → Camera / From Device → `_pickImage(source)` with `imageQuality: 85` → `FacultyService.updateProfileImage(path)` + success SnackBar.
  - A disclaimer explicitly states the photo is for **in-app display only** and does not update institutional records (A-3).

### 5.3 Sections

1. **Registration Identity** — plain rows via `_buildPlainRow` (label column 120px, `:` separator, bold value): Faculty Name, Designation, Department, Official Email. All sourced from `FacultyProfile`.
2. **Appearance Settings** — `_buildThemeToggle`: `ValueListenableBuilder<ThemeMode>` on `ThemeController.themeMode`; icon (dark→`dark_mode`, light→`light_mode`/amber), `Switch.adaptive` wired to `ThemeController.toggle()`.
3. **Security & Access** — `_buildInteractiveTile(lock_reset, "Change Password", "Update credentials")` and `(devices_other_rounded, "Login Devices", "Manage sessions")`.
4. **Identification** — `_buildInteractiveTile(badge_outlined, "Digital ID Card", "View Virtual Faculty ID")` and `(qr_code_2_rounded, "QR Code ID", "Personal verification code")`.
5. **Help & Support** — About IntelliAttend, Help Center, Report an Issue.
6. **Footer** — branding + copyright line.

### 5.4 Private builders

| Builder | Purpose |
|---|---|
| `_buildPlainRow(label, value)` | label/value key–value row |
| `_buildIdentityCard` / `_buildIdentityCompact` / `_buildSettingsTile` | identity/settings card variants (presently not all wired to live data — A-1) |
| `_buildInteractiveTile(icon, title, subtitle, onTap)` | primary nav tile with chevron |
| `_buildThemeToggle()` | theme switch (see §12) |

---

## 6. `ProfileModalContent` & `AppDrawer`

### 6.1 `ProfileModalContent` (`dashboard_screen.dart:152-274`)

- Opened via `DashboardScreen._showProfileModalStatic` (a `static` so the dashboard header and other screens can reuse it without a state instance).
- Bottom sheet at **85% screen height**, radius 32 top corners, teal-tinted avatar circle, name + email.
- Info rows (`_buildProfileInfoRow`): Employee Code (derived as email-local-part uppercased), Primary Dept, Designation, **Experience ("8+ Years")**, **Rating ("4.9/5.0")** — the latter two are **hard-coded** (A-1).

### 6.2 `AppDrawer` (`lib/Presentation/Widgets/app_drawer.dart`, 375 LOC)

- Fed by `ValueListenableBuilder<FacultyProfile?>` in `DashboardScreen.build` (`dashboard_screen.dart:107`): `facultyName = profile?.name`, `facultyRole = profile?.designation`, `profileImage`.
- Header: teal block, avatar (NetworkImage/FileImage/person icon), name, role, "VERIFIED FACULTY" pill.
- Theme toggle item (mirrors `ProfileScreen` via `ThemeController`).
- Sections: ACADEMICS (Student Directory with live enrollment sum, Attendance Manager/RealtimeAttendancePage, Advanced Reports), CONTENT (Resources, Create Assignment, Submissions), SECURITY & CLOUD (Device Management dialog via `SecurityService().activeDevices`, AI Faculty Assistant → `LiveSupportChatPage`), PREFERENCES (App Settings), THEME.
- Device Management dialog: lists `SecurityService().activeDevices` with CURRENT badge and REVOKE buttons.
- Sign Out → `widget.onLogout` (dashboard handler → `_handleLogout`).

---

## 7. `QRScannerScreen`

**File:** `lib/Presentation/Features/Profile/qr_scanner_screen.dart` (295 LOC)

- **Contract:** `QRScannerScreen({super.key})`; returns `Navigator.pop(context, {'value': String, 'format': String})`.
- **Controller:** `MobileScannerController(detectionSpeed: normal, facing: back, torchEnabled: false)` created in `initState`, disposed in `dispose`.
- **Detection:** `_onDetect(BarcodeCapture)` — single-flight `_isProcessing` guard; takes `barcodes.first.rawValue`; `HapticFeedback.mediumImpact()`; stops camera; pops with the value+format map.
- **UI:** full-black `Scaffold`, `MobileScanner` with an `errorBuilder` ("Camera access required"), custom `CustomPainter` overlay `_ScannerOverlayPainter` (even-odd cutout, 0.55 black), teal corner-frame `_CornerPainter` (quadratic corners), top bar with back + live torch toggle (`ValueListenableBuilder` on `torchState`), bottom "Processing..." pill.
- **Consumption (`ProfileScreen._openQRScanner`):** the scanned result is shown in a SnackBar with a COPY action (`Clipboard.setData`) — no semantic action beyond display (A-10).

---

## 8. Identity Features (QR ID & Digital ID Card)

### 8.1 QR Code ID (`_showQRCodeID`)

- `Dialog` (radius 32, transparent bg): icon, "Verification ID", then a white card hosting `QrImageView(data: p.email, version: auto, size: 200, QrEyeStyle/QrDataModuleStyle square, 0xFF131B2E)`.
- Below: email local-part uppercased in `AppTheme.jetBrainsMono` (20px, letter-spacing 2), then a DISMISS `TextButton`.
- **Key property:** the QR encodes the **canonical email** — matching the v4.0 "Email is the canonical ID" design (`FacultyService.canonicalId`).

### 8.2 Digital ID Card (`_showDigitalIdCard`)

- `Dialog` 88% width × 32% height, `LinearGradient(primary → 0xFF004D40)`.
- Repeating watermark via `AssetImage('assets/images/logo_square.png')` at 5% opacity, scale 8.
- Content: "INTELLIATTEND / FACULTY PORTAL" + OFFICIAL pill (`verified_rounded`); avatar ring with profile image; name uppercased; email-local-part in teal mono; `"designation • department"`; bottom row STATUS "ACTIVE" + logo.

---

## 9. Security & Access (Change Password / Login Devices)

### 9.1 `ChangePasswordScreen` (`change_password_screen.dart`, 224 LOC)

- **Form:** 3 fields — Current, New (≥6 chars), Confirm (match validator). Per-field visibility toggles.
- **Error banner:** `AppTheme.errorRed` container mapping `FirebaseAuthException` codes:
  - `wrong-password` → "Current password is incorrect."
  - `weak-password` → "The new password is too weak."
  - else → `e.message` / generic.
- **Flow:** validate → `context.read<AuthRepository>().changePassword(old, new)` → success SnackBar (teal) + pop; button shows inline `CircularProgressIndicator` while `_isLoading`.
- **Repository:** `AuthRepository.changePassword` (`auth_repository.dart:137`) = `EmailAuthProvider.credential(email, old)` → `user.reauthenticateWithCredential` → `user.updatePassword(new)`. Throws `FirebaseAuthException('no-user')` if no current user/email.

### 9.2 `LoginDevicesScreen` (`login_devices_screen.dart`, 290 LOC)

- **Load:** `_loadAll()` → `HardwareService.getDeviceSnapshot(forceRefresh: true)` (local device) + `SessionManagementService().getActiveSessions()` (server sessions).
- **Layout:** `RefreshIndicator` list; current device card (teal border, "CURRENT DEVICE" pill, Android icon) then "OTHER DEVICES" cards; each navigates to `DeviceDetailScreen`.
- **Revoke:** `_revokeSession(session)` → confirm `AlertDialog` ("Log Out Device?") → `SessionManagementService().revokeSession(session.sessionId)` → SnackBar + reload.
- **Log Out This Device:** confirm dialog → `authRepo.signOut()` → `FacultyService.clear()` → `prefs['is_logged_in'] = false` → `pushAndRemoveUntil(LoginScreen)`.

### 9.3 `DeviceDetailScreen` (`device_detail_screen.dart`, 101 LOC)

- Detail view of a single device (name, IP, current flag); reached from session cards.

---

## 10. Help & Support Pages

| Page | File (LOC) | Content |
|---|---|---|
| `AboutAppPage` | `about_app_page.dart` (188) | Logo block, "IntelliAttend Faculty", **"Version 2.4.0 (Build 108)" (hard-coded — A-7)**, Mission, info card (Website / Privacy Policy / Terms of Service — rows are display-only), © line |
| `HelpCenterPage` | `help_center_page.dart` (286) | Searchable FAQ (5 static entries, `_filteredFaqs`), categories grid (Account/Attendance/Analytics/Security — tapping fills the search box), `ExpansionTile` FAQ cards, gradient "Still need help?" CTA → `LiveSupportChatPage` |
| `ReportIssuePage` | `report_issue_page.dart` (230) | Form (category dropdown: Technical Bug / Attendance Sync Issue / UI Glitch / Feature Request / Other, subject, 6-line description), **simulated 2 s submit** → success dialog (A-8) |
| `LiveSupportChatPage` | `live_support_chat_page.dart` (248) | AI-faculty-assistant style chat surface (also used from the drawer) |

---

## 11. `FacultyService` & `FacultyProfile` — Data Layer

**File:** `lib/Services/faculty_service.dart` (480 LOC)

### 11.1 `FacultyProfile` model (in-file)

```dart
{ String name, String department, String designation,
  String email, String? profileImage, String facultyId }
```

- `toJson`/`fromJson`; defaults `name: 'Faculty User'`, `department/designation: 'N/A'`.
- **`canonicalId` = profile.value?.email** — the v4.0 single identifier for all API calls.

### 11.2 `FacultyStats` model (in-file)

- `livePresentCount`, `totalExpectedStrength`, `departmentAverage`, `attendanceHistory` (List<int>); snake_case JSON (`live_present_count`, etc.).

### 11.3 `FacultyService` API surface

| Member | Purpose |
|---|---|
| `profile` / `stats` / `courses` / `isRegistered` | static `ValueNotifier`s |
| `isLoaded`, `_loadCompleter` | concurrency guards |
| `loadFromCache()` | Hive `facultyBox['profile'/'stats']`, `academicBox['courses']`; sets `is_logged_in`; falls back to `deriveCoursesFromCohorts()` |
| `deriveCoursesFromCohorts()` | builds course list from `cohorts` manifest; persists subject cache |
| `executeAuthFlow(authRepo)` | `/auth/status` → `verifySession` (device binding) → profile/registration decision |
| `loadBaseProfile()` | cache-first Phase 1 (10 s timeouts); error string or null |
| `initializeListeners()` | Phase 2: `FacultyHydrationService().syncIfNeeded()`; `SyncResult` switch |
| `onAppResume()` | re-run manifest sync if `_isLoaded` |
| `load()` | master rebuild; single-flight via `_loadCompleter`; cache-first then `/api/v1/faculty/sync`; `facultyId = email` |
| `applyProfile(data)` | authoritative server response → notifier + Hive (+ device_info persistence) |
| `updateProfileImage(path)` | rebuild `FacultyProfile` with local path; persists (A-3) |
| `clear()` / `resetToDefaults()` / `dispose()` | teardown |

---

## 12. `ThemeController`

**File:** `lib/Theme/theme_controller.dart` (23 LOC)

- `static ValueNotifier<ThemeMode> themeMode` (default light).
- `init()`: reads `prefs['is_dark_mode']`.
- `toggle()`: flips notifier + persists asynchronously (`_prefs?.setBool`).
- `resetToDefaults()`: removes the pref, forces light.
- Consumed by `ProfileScreen` switch, `AppDrawer` item, and the root `IntelliAttendApp` (via `ValueListenableBuilder<ThemeMode>`), so toggling from either surface updates the whole app instantly.

---

## 13. `AuthRepository` & `SessionManagementService`

### 13.1 `AuthRepository` (`auth_repository.dart`, 139 LOC)

- Firebase-backed (`FirebaseAuth`); `signInWithEmailAndPassword`, `signOut`, `changePassword` (§9.1), `getCurrentUser`, plus `checkAuthStatus`/`verifySession` device-binding helpers.
- `changePassword` requires **re-authentication** with the old credential before `updatePassword` — a deliberate security posture (recent login required by Firebase).

### 13.2 `SessionManagementService` (`session_management_service.dart`, 43 LOC)

- Wraps `ApiClient().dio`:
  - `getActiveSessions()` → `GET /api/v1/auth/sessions` → `List<AuthSession>` ([] on failure).
  - `revokeSession(sessionId)` → `DELETE /api/v1/auth/sessions/$sessionId` → `bool` (true if `data['success']`).
  - `revokeAllOtherSessions({currentSessionId})` → loops revokes; returns count.

---

## 14. Data Models & DTOs

| Model | File | Fields / Notes |
|---|---|---|
| `FacultyProfile` | `faculty_service.dart` (inline) | name, department, designation, email, facultyId, profileImage |
| `FacultyStats` | `faculty_service.dart` (inline) | livePresentCount, totalExpectedStrength, departmentAverage, attendanceHistory |
| `AuthSession` | `lib/Data/Models/Auth/auth_session_model.dart` (95) | server session DTO (`isCurrentDevice`, `displayName`, `osDisplay`, `ipAddress`, `sessionId`), parsed from `/api/v1/auth/sessions` |
| `DeviceData` | `lib/core/models/device_data.dart` | local device snapshot from `HardwareService` (`deviceId`, `fingerprint`, `manufacturer`, `model`, `osVersion`, `displayName`, `osDisplay`, `localIpAddress`) |
| `DeviceInfo` | `SecurityService` | drawer "Active Sessions" device rows |

---

## 15. Backend API Reference

| Endpoint | Verb | Used by | Notes |
|---|---|---|---|
| `/api/v1/faculty/sync` | GET | `FacultyService.load/loadBaseProfile` | master manifest; reads `data['profile']`; 10 s send/receive timeouts |
| `/api/v1/auth/status` | POST | `FacultyService.executeAuthFlow` | account status + `is_registered` |
| `/api/v1/auth/verify-session` | POST | `executeAuthFlow` | device-binding check |
| `/api/v1/auth/sessions` | GET | `SessionManagementService` | `data['sessions']` list |
| `/api/v1/auth/sessions/:id` | DELETE | `revokeSession` | `data['success']` |

All requests go through `ApiClient().dio` (JWT bearer, interceptors, TLS). Base: `https://api-dev.balaseetharamanjaneyula.com`.

---

## 16. WebSocket Real-Time Protocol

The Profile module opens **no WebSocket channels**; it is pull-based (manifest sync + session REST calls). Live-telemetry subscriptions used by Home/My Class do not feed any profile surface. `FacultyService` explicitly removed its real-time listeners ("All real-time subscriptions removed — data synced via FacultyHydrationService", `faculty_service.dart:87`).

---

## 17. Navigation Map

```
DashboardScreen (IndexedStack index 3) ──► ProfileScreen
   ├─ CustomAppBar QR button ──► QRScannerScreen ──► (pop: {'value','format'}) → SnackBar+COPY
   ├─ camera badge ──► bottom sheets (Change Photo → Camera/From Device → ImagePicker)
   ├─ avatar tap ──► full-image Dialog
   ├─ Change Password ──► ChangePasswordScreen  (authRepo.changePassword → pop)
   ├─ Login Devices ──► LoginDevicesScreen
   │     ├─ session card tap ──► DeviceDetailScreen
   │     ├─ revoke ──► confirm Dialog → DELETE session
   │     └─ Log Out This Device ──► confirm → signOut → LoginScreen (pushAndRemoveUntil)
   ├─ Digital ID Card ──► Dialog (gradient ID card)
   ├─ QR Code ID ──► Dialog (QrImageView of email)
   ├─ About IntelliAttend ──► AboutAppPage
   ├─ Help Center ──► HelpCenterPage ──► LiveSupportChatPage
   └─ Report an Issue ──► ReportIssuePage

Other profile-data surfaces (off-tab):
   DashboardHeader avatar ──► ProfileModalContent (bottom sheet)
   AppDrawer ──► header (profile data) / Sign Out / Device Management dialog
   LoginDevicesScreen "Log Out This Device" ──► LoginScreen (root reset)
```

All routes are anonymous `MaterialPageRoute`s.

---

## 18. Sequence Diagrams

### 18.1 Profile tab cold start (cache-first)

```
ProfileScreen.initState
   └─ FacultyService.load()
        ├─ _loadCompleter single-flight
        ├─ loadFromCache()
        │    ├─ facultyBox['profile'] ──► profile.value (immediate UI)
        │    └─ academicBox['courses'] / deriveCoursesFromCohorts
        ├─ profile.value != null → complete + return (UI unblocked)
        └─ else GET /api/v1/faculty/sync
             └─ profile block → profile.value + facultyBox.put('profile')
   └─ (background) initializeListeners()
        └─ FacultyHydrationService.syncIfNeeded()
             ├─ updated/firstSync → loadFromCache()
             ├─ unchanged → cache
             └─ noNetwork → cache
```

### 18.2 Change password

```
Profile "Change Password" tap
   └─ ChangePasswordScreen validate
        └─ authRepo.changePassword(old, new)
             ├─ EmailAuthProvider.credential(email, old)
             ├─ user.reauthenticateWithCredential(credential)
             ├─ user.updatePassword(new)  → success SnackBar → pop
             └─ FirebaseAuthException
                  ├─ wrong-password → error banner
                  ├─ weak-password → error banner
                  └─ other → e.message banner
```

### 18.3 Profile photo update (local-only)

```
camera badge → Change Photo sheet → Camera/Gallery
   └─ ImagePicker.pickImage(imageQuality: 85)
        └─ FacultyService.updateProfileImage(path)
             ├─ profile.value = copyWith(profileImage: path)
             └─ facultyBox.put('profile', json)  (no server upload — A-3)
   └─ SnackBar "Profile photo updated"
```

---

## 19. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| No cached profile, no network | `FacultyService.load` falls through to `/sync`; on failure returns error string; UI keeps ui-avatars fallback + 'Faculty User' placeholders |
| `ACCOUNT_UNLINKED` | profile.value = null; `isRegistered = false`; error string returned to gate |
| Firebase re-auth failure | `wrong-password`/`weak-password`/generic mapped to banner text |
| No current Firebase user | `FirebaseAuthException('no-user')` thrown and shown generically |
| `getActiveSessions()` failure | returns `[]` (silent) — no error surface |
| `revokeSession` failure | `false` → "Failed to log out device" SnackBar |
| Camera permission denied | `MobileScanner.errorBuilder` → "Camera access required" prompt |
| Scanner re-entrancy | `_isProcessing` single-flight; stops camera before pop |
| Null `profileImage` | ui-avatars fallback in tab/modal; person icon in drawer |
| Local image deleted from disk | `FileImage` throws on build (no catch) — A-6 |
| Concurrent `load()` calls | `_loadCompleter` waits and returns (single-flight) |
| Theme prefs write failure | `toggle()` ignores SharedPreferences errors (fire-and-forget) |
| Empty courses after hydration | `deriveCoursesFromCohorts()` synthesizes from cohorts |

---

## 20. Performance Engineering

- **Cache-first profile**: `loadFromCache()` runs before any network I/O, so the tab paints in ~100 ms; the network refresh is background (`initializeListeners`).
- **`_loadCompleter` single-flight**: repeated tab init / app-resume calls don't stack duplicate `/sync` requests.
- **`ValueListenableBuilder` scoping**: only widgets that read `FacultyService.profile` rebuild when it changes; the tab body is otherwise static.
- **Image quality cap**: `imageQuality: 85` on picker; `CachedNetworkImageProvider` reuses the app's image cache for the remote avatar.
- **Lightweight surfaces**: About/Help/Report are static `StatelessWidget`/simple forms; Help Center uses `RepaintBoundary` around the search bar and list to limit repaints.
- **Low-risk**: no timers, streams, or heavy lists in this module; the QR screen stops the camera immediately after a scan and disposes the controller.

---

## 21. Security

- **Re-authentication required** before password change (Firebase `reauthenticateWithCredential`) — prevents session-hijacked password updates.
- **Session revocation** against `/api/v1/auth/sessions/:id` with a confirm dialog; "Log Out This Device" clears `is_logged_in` and routes to `LoginScreen`.
- **Canonical identity**: email only (`canonicalId`); `facultyId` is the email — no PII beyond the manifest.
- **Transport**: all calls via `ApiClient().dio` (JWT, interceptors, TLS pinning per app standard).
- **QR ID encodes the email** — treated as a public verification token; note there is no expiry or server-side validation on it (A-9).
- **Local avatar** stored as a filesystem path in Hive — a device compromise can read it; it is display-only data (A-3).
- **Privacy posture**: disclaimer in the photo sheet explicitly says the photo is in-app only and not written to institutional records.
- **Support pages leak nothing**: Report Issue is a simulated client-side form (A-8); no PII transmitted.

---

## 22. Dependencies Used

| Package | Where used |
|---|---|
| `provider` | `context.read<AuthRepository>()` in ChangePassword/LoginDevices |
| `firebase_auth` | re-auth + updatePassword; current user email |
| `shared_preferences` | `is_dark_mode` (ThemeController), `is_logged_in` |
| `hive`, `hive_flutter` | `facultyBox` (profile/stats), `academicBox` (courses/cohorts) |
| `dio` | `/api/v1/faculty/sync`, `/api/v1/auth/sessions` via `ApiClient` |
| `image_picker` | Change Photo (camera/gallery, quality 85) |
| `cached_network_image` | remote avatar (tab, full-image dialog, ID card) |
| `qr_flutter` | `QrImageView` (QR Code ID) |
| `mobile_scanner` | `QRScannerScreen` (barcode detection, torch) |
| `google_fonts` | section labels / theme row typography |
| `url_launcher` | (imported in profile_screen; used by student profile flows) |
| `package_info_plus` | imported in `profile_screen.dart` but **unused** (dead import — A-7) |

---

## 23. File Inventory

> Line counts = non-blank lines (`Measure-Object -Line`).

### 23.1 Profile feature — `lib/Presentation/Features/Profile/`

| File | LOC | Role |
|---|---|---|
| `profile_screen.dart` | 968 | Hub tab: identity, theme, security, identification, support |
| `qr_scanner_screen.dart` | 295 | Camera QR scanner (returns value+format map) |

### 23.2 Profile-supporting surfaces

| File | LOC | Role |
|---|---|---|
| `lib/Presentation/Features/Faculty/dashboard_screen.dart` | 364 | `IndexedStack` host; `ProfileModalContent` sheet (lines 152–274) |
| `lib/Presentation/Widgets/app_drawer.dart` | 375 | Drawer header (profile data), theme, device dialog, sign out |
| `lib/Presentation/Features/Faculty/change_password_screen.dart` | 224 | Re-auth password change |
| `lib/Presentation/Features/Faculty/login_devices_screen.dart` | 290 | Session list + revoke + local sign-out |
| `lib/Presentation/Features/Faculty/device_detail_screen.dart` | 101 | Device detail |
| `lib/Presentation/Features/Support/about_app_page.dart` | 188 | About (hard-coded version) |
| `lib/Presentation/Features/Support/help_center_page.dart` | 286 | Searchable FAQ + live-chat CTA |
| `lib/Presentation/Features/Support/report_issue_page.dart` | 230 | Issue form (simulated submit) |
| `lib/Presentation/Features/Support/live_support_chat_page.dart` | 248 | AI/live support chat surface |

### 23.3 Services / Repos / Models

| File | LOC | Role |
|---|---|---|
| `lib/Services/faculty_service.dart` | 480 | `FacultyProfile`/`FacultyStats` + profile store + manifest sync |
| `lib/Theme/theme_controller.dart` | 23 | ThemeMode notifier + persistence |
| `lib/Services/session_management_service.dart` | 43 | Active-session list/revoke REST |
| `lib/Data/Repositories/auth_repository.dart` | 139 | Firebase auth incl. `changePassword` |
| `lib/Data/Models/Auth/auth_session_model.dart` | 95 | `AuthSession` DTO |

---

## 24. Appendix A — Known Design Notes & Technical Debt

### A-1. Hard-coded profile embellishments (MEDIUM)

`ProfileModalContent` renders **"Experience: 8+ Years"** and **"Rating: 4.9/5.0"** as literals — not backed by any model field or API. `_buildIdentityCard`, `_buildIdentityCompact`, and `_buildSettingsTile` in `ProfileScreen` exist but are **not wired to live data** in the current layout.

### A-2. Network-dependent avatar fallback (MEDIUM)

The default avatar `https://ui-avatars.com/api/?name=Faculty+User&background=2DD4BF&color=000` requires network access and an external service (ui-avatars.com). Offline cold start shows a blank/placeholder. Consider bundling a local asset fallback.

### A-3. Profile photo is local-only (HIGH for data-accuracy)

`FacultyService.updateProfileImage(path)` stores a **local filesystem path** into Hive. There is **no upload endpoint**; the photo is never synced and disappears on reinstall/app-data clear. The UI disclaimer is honest about this, but the mismatch between "change photo" affordance and reality should be product-acknowledged.

### A-4. `facultyId` = email (LOW)

`load()` and `applyProfile()` set `facultyId = email` even though the manifest carries `userId`. If the backend ever exposes a separate employee ID, this silently loses it.

### A-5. `load()` is effectively once-only (MEDIUM)

`_isLoaded` short-circuits every subsequent `load()`; the Profile tab's `initState → load()` therefore rarely re-fetches. Fresh data arrives only via `onAppResume()`/`initializeListeners()` manifest sync. This is intentional for performance but surprising for a "refresh my profile" expectation.

### A-6. Local image lifecycle (LOW)

A stored local `profileImage` path pointing at a deleted file will throw inside `FileImage` during build — no guard exists (the tab, modal, drawer, and ID card all assume the file exists).

### A-7. Version + dead import drift (LOW)

`AboutAppPage` hard-codes **"Version 2.4.0 (Build 108)"** while `pubspec.yaml` declares **1.0.0+1**. `package_info_plus` is imported in `profile_screen.dart` but never used — it should either back the About page or be removed.

### A-8. Report Issue is simulated (MEDIUM)

`ReportIssuePage._submitIssue` awaits `Future.delayed(2s)` then shows a success dialog. No repository/API, no server persistence, no ticket ID. "By submitting, you agree to our Support Terms" implies a real contract.

### A-9. QR ID has no expiry/validation (MEDIUM)

The QR Code ID encodes the email with no payload signature, expiry, or server-side verification flow. A captured QR is a permanent reusable identifier.

### A-10. QR scanner result is display-only (LOW)

`_openQRScanner` shows the decoded value in a SnackBar with a COPY action but takes no further action (no student lookup, no session join). The feature is a generic scanner bolted onto the profile tab.

### A-11. Dual state-management styles (LOW)

The app uses `ChangeNotifier`+`Provider` (Home, My Class, QuickActions) and `ValueNotifier`+`ValueListenableBuilder` (Profile, Theme) side by side. Both are sound; the split should be documented or unified to reduce onboarding confusion.

### A-12. Session revoke semantics (LOW)

`SessionManagementService.revokeSession` trusts `data['success']`. `AuthSession.isCurrentDevice` drives the "current" pill, but `LoginDevicesScreen._handleLogoutThisDevice` signs out the whole Firebase user rather than revoking just the current session server-side — a product/security decision worth confirming.

---

*End of Profile Module technical documentation. Companion: `HOME_MODULE.md`, `COURSES_MODULE.md`, `MYCLASS_MODULE.md`.*
