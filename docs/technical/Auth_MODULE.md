# IntelliAttend Faculty — Auth Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Auth (Boot Gate, Login, Registration, OTP, Device Binding & Security Overlay)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/HOME_MODULE.md`, `docs/technical/COURSES_MODULE.md`, `docs/technical/MYCLASS_MODULE.md`, `docs/technical/PROFILE_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Tree](#4-screen-structure--widget-tree)
5. [`UnifiedAuthGate` — the Boot State Machine](#5-unifiedauthgate--the-boot-state-machine)
6. [`SecurityOverlay` & `LockScreen` — App-Level Gate](#6-securityoverlay--lockscreen--app-level-gate)
7. [`LoginScreen` — Credentials & the Auth Decision Tree](#7-loginscreen--credentials--the-auth-decision-tree)
8. [Registration Flow — `RegistrationScreen` → `OtpScreen` → `SetPasswordScreen`](#8-registration-flow--registrationscreen--otpscreen--setpasswordscreen)
9. [`CompromisedDeviceScreen` — Scorched-Earth Lock](#9-compromiseddevicescreen--scorched-earth-lock)
10. [`FacultyService` — Auth Orchestration & Profile Gate](#10-facultyservice--auth-orchestration--profile-gate)
11. [`AuthRepository` — Firebase + Device-Binding Repository](#11-authrepository--firebase--device-binding-repository)
12. [`SecurityController` & the Hardware Trust Layer](#12-securitycontroller--the-hardware-trust-layer)
13. [Server-Driven Logout — `ForceLogoutService` & Interceptors](#13-server-driven-logout--forcelogoutservice--interceptors)
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

The **Auth Module** is the identity and boot surface of the app. It owns the cold-start **auth gate** (cache-first routing), the **login / registration / OTP / set-password** screens, the app-wide **security overlay** (biometric lock + compromised-device lock), and the **device-binding** handshake that ties every faculty account to a registered hardware fingerprint. Everything is orchestrated around one invariant: **Firebase Auth is the identity provider, and the faculty email is the canonical ID** (`FacultyService.canonicalId`).

### 1.2 Business Goal

- **Instant cold start**: render the dashboard from Hive cache (~100 ms) without blocking on Firebase, then validate the session in the background.
- **Secure login**: email/password against Firebase plus a backend **device-binding** check (`/api/v1/auth/verify-session`) before any screen is reachable.
- **Guided self-registration**: `send-otp` → OTP entry → set password + hardware binding (`/api/v1/auth/register/complete`).
- **Tamper response**: a rooted/compromised device is locked out with a **scorched-earth** teardown (hardware keypair deleted, session revoked server-side).
- **Server-driven logout**: session revocation, device mismatch and forced upgrades (`401`/`403`/`426`) route through `ForceLogoutService` back to `LoginScreen`.

### 1.3 Problem Statement

- The old pattern (block on Firebase, then load) made cold starts slow; the app needs the dashboard visible before Firebase resolves.
- A stolen credential alone should not grant access — the app must bind each account to a device fingerprint.
- OTP/password flows are security-critical but were historically ad-hoc; they needed a single repository contract (`IAuthRepository`).
- The app must react to server-initiated session death (Redis kill switch, blocked status, device mismatch) with a complete local wipe.

### 1.4 Solution

- `UnifiedAuthGate` (`unified_auth_gate.dart`) is the `MaterialApp` `home`. It awaits **only** Hive persistence (`persistenceFuture`), routes to `DashboardScreen` on cache hit, and validates Firebase/network in the background (`_backgroundValidate` / `_loadFromNetwork`).
- `SecurityOverlay` (in `main.dart`) wraps the entire navigator in a `Consumer<SecurityController>`: compromised → `CompromisedDeviceScreen`; locked (biometric) → `LockScreen` with `AbsorbPointer`.
- `LoginScreen` signs into Firebase, runs `FacultyService.executeAuthFlow` (status + device binding), then routes by `FacultyService.isRegistered.value`.
- Registration is a 3-step push chain: `RegistrationScreen` (request OTP) → `OtpScreen` (enter code) → `SetPasswordScreen` (set password, complete registration, bind device, verify session).
- `AuthRepository` is the single contract for all auth REST + Firebase operations (`auth_repository.dart:8`).

### 1.5 Target Users

- **Faculty members** — every session enters through this module. It is the only route to the dashboard and the only exit (logout / force logout).

### 1.6 Faculty Workflow (Auth-driven) — the Auth Gate Flow

```
App launch (main.dart)
   ├─ Track A: dotenv + Hive + prefs + FacultyService.loadFromCache()  (~100 ms)
   ├─ Track B: Firebase.initializeApp() + heavy services (background)
   └─ home = UnifiedAuthGate(persistenceFuture, firebaseReady)
        │
        ├─ await persistenceFuture
        │    ├─ cache hit (profile != null && isRegistered) ──► DashboardScreen  (instant)
        │    │     └─ _backgroundValidate(): firebase → loadBaseProfile → confirm / redirect
        │    └─ miss ──► loading splash ──► _loadFromNetwork()
        │          ├─ base profile ok + registered ──► DashboardScreen + background validate
        │          ├─ base profile ok + NOT registered ──► RegistrationScreen (OTP → password)
        │          └─ error / no profile / no Firebase ──► LoginScreen
        │
        └─ SecurityOverlay wraps every phase:
             ├─ device compromised (root detected) ──► CompromisedDeviceScreen (scorched earth)
             └─ biometric lock enabled + backgrounded ──► LockScreen overlay (tap to unlock)
```

---

## 2. Layered Architecture & Data Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│  PRESENTATION (Auth feature)                                             │
│  UnifiedAuthGate (boot gate)  •  LoginScreen  •  RegistrationScreen      │
│  OtpScreen  •  SetPasswordScreen  •  LockScreen  •  CompromisedDeviceScreen│
│  + SecurityOverlay (main.dart) wrapping the whole Navigator              │
└──────────────┬───────────────────────────────────────────────────────────┘
               │ context.read<AuthRepository>()   ·   FacultyService statics
┌──────────────▼──────────────────────┐   ┌────────────────────────────────┐
│  REPOSITORY                          │   │  SERVICES (singletons)         │
│  AuthRepository (IAuthRepository)    │   │  FacultyService (ValueNotifiers)│
│   FirebaseAuth + ApiClient().dio     │   │  SecurityController (ChangeNotifier)
│   checkAuthStatus/sendOtp/...        │   │  ForceLogoutService            │
└──────────────┬──────────────────────┘   │  KeyEnrollmentService          │
               │                          └──────────────┬─────────────────┘
┌──────────────▼──────────────────────────────────────────▼─────────────────┐
│  INFRA / NETWORK / HARDWARE                                                │
│  ApiClient (Dio, cert pinning, AuthInterceptor, SecurityInterceptor,       │
│             RetryInterceptor)   •   FirebaseAuth  •   LocalAuthentication  │
│  SharedPreferences (is_logged_in, last_login_email, biometric_lock_enabled)│
│  Hive via PersistenceService (profile, is_registered)  •   MethodChannel   │
│  HardwareService (fingerprint, root check, monotonic clock, keypair)       │
└──────────────┬─────────────────────────────────────────────────────────────┘
               │ HTTPS (Authorization: Bearer + X-Device-* headers)
   /api/v1/auth/status  •  /auth/register/send-otp  •  /auth/register/complete
   /api/v1/auth/verify-session  •  /api/v1/faculty/device/compromised  •  /sync
```

### 2.1 Data flow on cold start (cache-first)

```
main() 
   └─ _bootstrapPersistence (Track A): dotenv + ThemeController + PersistenceService.initMinimal
        └─ FacultyService.loadFromCache() → profile.value / isRegistered.value from Hive
   └─ _initFirebase (Track B, background): Firebase.initializeApp()
   └─ runApp → SecurityController() created (root provider) → _performInitialSecurityCheck()
   └─ home: UnifiedAuthGate._startBootSequence()
        ├─ await persistenceFuture
        ├─ profile cached && isRegistered ──► _phase = cacheHit → DashboardScreen (instant)
        └─ else _phase = loading → _loadFromNetwork() (awaits firebaseReady)
             └─ loadBaseProfile() → GET /api/v1/faculty/sync (10 s timeouts)
                  ├─ 200 → profile block → isRegistered / profile → dashboard|registration
                  └─ error → loadFromCache() fallback → dashboard (stale) or login
```

---

## 3. State Management Wiring

The Auth module uses **three coexisting mechanisms** (documented as intentional-but-mixed, A-6/A-14):

| Concern | Mechanism | Location |
|---|---|---|
| Boot phase | `_BootPhase` enum + `setState` (local) | `unified_auth_gate.dart:13–20`, `:43` |
| Auth controller (lock / compromised / biometrics) | `SecurityController` **`ChangeNotifier`** registered at root | `main.dart:156–157`; consumed via `Consumer`/`context.watch` |
| Profile / registration state | `FacultyService.profile` / `FacultyService.isRegistered` **static `ValueNotifier`s** | `faculty_service.dart:79,82` |
| Auth REST + Firebase | `Provider<AuthRepository>` | `main.dart:167–169`; read via `context.read<AuthRepository>()` |
| Persistence flags | `SharedPreferences` `is_logged_in`, `last_login_email`, `biometric_lock_enabled`, `fcm_token` | `login_screen.dart:58,118`; `security_controller.dart:95,105`; `sync_fcm_handler.dart:141` |
| HTTP client | `Provider<ApiClient>` (singleton) | `main.dart:160`; also `ApiClient()` direct |
| Lock overlay trigger | `ValueListenableBuilder(FacultyService.profile)` + `Consumer<SecurityController>` | `main.dart:227–277` |

**Key access pattern:** the SecurityOverlay recomputes `isUserLoggedIn` from three independent sources (Firebase user, `is_logged_in` pref, non-null `profile`) and only then applies `security.isLocked` — so the lock overlay never appears before any identity exists (`main.dart:247–253`).

---

## 4. Screen Structure — Widget Tree

### 4.1 Boot gate route tree

```
MaterialApp (home: UnifiedAuthGate, no routes table)               [main.dart:206–221]
└─ SecurityOverlay (builder)                                       [main.dart:227–277]
   ├─ security.isCompromised ──► CompromisedDeviceScreen(reason)   [main.dart:243]
   └─ Stack
      ├─ RepaintBoundary → AbsorbPointer(absorbing: isLocked) → navigatorChild
      └─ if isLocked ──► LockScreen                                [main.dart:269]
UnifiedAuthGate._phase switch                                       [unified_auth_gate.dart:125–142]
   ├─ initial | loading ──► _buildSplash (logo + LinearProgressIndicator)
   ├─ cacheHit | dashboard ──► DashboardScreen
   ├─ login ──► LoginScreen
   └─ registration ──► RegistrationScreen(preloadedEmail: user?.email, fromLogin: true)
```

### 4.2 LoginScreen widget tree (`login_screen.dart:163–308`)

```
Theme(AppTheme.getAuthTheme) → Scaffold → SafeArea → Center → SingleChildScrollView
└─ Column
   ├─ Image.asset('assets/images/logo.png', 240x200)
   ├─ "IntelliAttend" (GoogleFonts.inter 32 w900)
   ├─ "Smart. Secure. Seamless Faculty Portal."
   ├─ if (_authError != null) error Card (errorContainer tint, icon + message)
   ├─ TextField email (label "Faculty ID / Email", hint user@mrcet.ac.in)
   ├─ TextField password (obscureText toggle suffix icon)
   ├─ TextButton "Forgot Password?" → _handleForgotPassword
   ├─ FilledButton "SIGN IN" (accentTeal, minHeight 64, spinner while _isLoading)
   └─ "v$_appVersion • SECURE FACULTY SYSTEM"
```

### 4.3 Registration chain widget trees

- `RegistrationScreen` (`registration_screen.dart:64–158`): AppBar "Faculty Registration" → `Hero('app_logo')` → "Identify Yourself" → email `TextField` (readOnly when `fromLogin`) → FilledButton "Send Verification Code".
- `OtpScreen` (`otp_screen.dart:103–194`): AppBar "Verify Email" → mail icon → 6-box `Row` of `_buildOtpBox` → FilledButton "Verify & Continue" → resend `TextButton` with 60 s countdown.
- `SetPasswordScreen` (`set_password_screen.dart:114–194`): AppBar "Secure Faculty Account" → lock icon → two obscured password fields → `_buildSecurityBadge` ("Hardware Binding", TRUSTED pill) → FilledButton "Complete Registration".

### 4.4 Lock / Compromised widgets

- `LockScreen` (`lock_screen.dart:18–64`): transparent `Scaffold` → `GestureDetector(onTap: _handleTap)` → 60 % black `Container` → fingerprint icon + status text (`Authenticating...` / `Timed out. Tap to retry.` / `_errorMessage` / `Tap to unlock`).
- `CompromisedDeviceScreen` (`compromised_device_screen.dart:9–128`): `PopScope(canPop: false)` → dark `0xFF0F172A` scaffold → red alert icon → "Security Policy Violation" → reason card (`Reason: $reason`) → "Please use a standard, non-rooted device…" → full-width red "Exit Application" button (`SystemNavigator.pop()`).

---

## 5. `UnifiedAuthGate` — the Boot State Machine

**File:** `lib/Presentation/Features/Auth/unified_auth_gate.dart` (175 LOC)

- Constructor takes `persistenceFuture` and `firebaseReady` — the two boot tracks from `main.dart:49–52`.
- `_BootPhase` enum (unified_auth_gate.dart:13–20): `initial, cacheHit, loading, dashboard, login, registration`.

### 5.1 `_startBootSequence()` (unified_auth_gate.dart:51–67)

- `await widget.persistenceFuture` — the **only** blocking wait ("Lightning-fast auth gate").
- If `FacultyService.profile.value != null && FacultyService.isRegistered.value` → `_phase = cacheHit` → `DashboardScreen` renders instantly, then `_backgroundValidate()` fires without blocking UI.
- Otherwise → `_phase = loading` → `_loadFromNetwork()`.

### 5.2 `_backgroundValidate()` (unified_auth_gate.dart:69–96)

- `await widget.firebaseReady`; `FirebaseAuth.instance.currentUser == null` → `_phase = login`.
- `FacultyService.loadBaseProfile()` → on error: **stays on current phase, no redirect** (A-14).
- `!isRegistered` → `_phase = registration`.
- else → `_phase = dashboard` + `await FacultyService.initializeListeners()` + `await TimeSyncService.bootstrap()`.

### 5.3 `_loadFromNetwork()` (unified_auth_gate.dart:98–122)

- `await widget.firebaseReady` → `loadBaseProfile()`.
- On error: `FacultyService.loadFromCache()` fallback — if a stale `profile` exists → dashboard + `_backgroundValidate()`; else → login.
- Not registered → registration; otherwise dashboard + `_backgroundValidate()`.

### 5.4 `build` / `_buildSplash` (unified_auth_gate.dart:124–198)

- Switch on `_phase` (see 4.1). Splash renders the logo, optional `"Loading..."` text, and a lime `LinearProgressIndicator`.

---

## 6. `SecurityOverlay` & `LockScreen` — App-Level Gate

**File:** `lib/main.dart` (`SecurityOverlay` at 227–277) and `lib/Presentation/Features/Auth/lock_screen.dart` (82 LOC)

- Wired via `MaterialApp.builder` (`main.dart:214–220`); also calls `ForceLogoutService.setNavigatorContext(context)` for interceptor-driven navigation.
- `ValueListenableBuilder(FacultyService.profile)` → `Consumer<SecurityController>` (main.dart:235–240):
  1. `isCompromised` → `Material(child: CompromisedDeviceScreen(reason: security.violationReason))` (main.dart:242–244).
  2. `isUserLoggedIn` = (Firebase initialized && user != null) **or** (`is_logged_in` pref == true) **or** (profile != null) (main.dart:247–251).
  3. `isLocked = security.isLocked && isUserLoggedIn` → wraps navigator in `RepaintBoundary` + `AbsorbPointer(absorbing: isLocked)` and stacks `LockScreen` on top (main.dart:253–271).
- `LockScreen._handleTap` (lock_screen.dart:66–89): guards `isCompromised`/`isAuthenticating`/`!isLocked`; calls `security.authenticate()`; on `false` shows "Timed out. Tap to retry."; on exception shows "Authentication failed. Tap to retry."

> Design note (security_controller.dart:24–25): "App starts UNLOCKED. Never blocks the UI after login." Lock only activates when the user enables biometric lock in Settings or the device is compromised.

---

## 7. `LoginScreen` — Credentials & the Auth Decision Tree

**File:** `lib/Presentation/Features/Auth/login_screen.dart` (313 LOC)

### 7.1 State & lifecycle

- Controllers `_emailController` / `_passwordController`; `_isLoading`, `_authError`, `_appVersion` (login_screen.dart:22–27).
- `initState` (login_screen.dart:29–35): seeds `_authError` from `widget.initialError` (used by `ForceLogoutService`), loads `_appVersion` via `PackageInfo.fromPlatform()` (login_screen.dart:45–48), and pre-fills the email from `last_login_email` (login_screen.dart:37–43).
- Email validation requires the `@mrcet.ac.in` suffix (login_screen.dart:98) — hard-coded institution policy (A-5).

### 7.2 `_handleLogin()` (login_screen.dart:89–160)

```
validate (empty / domain)
   └─ context.read<AuthRepository>().signIn(email, password)     FirebaseAuth
   └─ prefs.setString('last_login_email', email)
   └─ FacultyService.executeAuthFlow(authRepo)                    POST /auth/status + /auth/verify-session
        ├─ flowError != null ──► authRepo.signOut() + set _authError (banner)
        └─ null (success)
             ├─ isRegistered.value ──► _navigateToDashboard()
             └─ else ──► Navigator.push(RegistrationScreen(preloadedEmail: email, fromLogin: true))
   └─ on FirebaseAuthException / generic ──► ErrorHandler.showVisualError (bottom sheet)
```

### 7.3 `_navigateToDashboard()` (login_screen.dart:50–65)

- Force-refreshes the ID token (`currentUser?.getIdToken(true)`, failure non-critical).
- Sets `prefs['is_logged_in'] = true` **before** navigation.
- `pushAndRemoveUntil(MaterialPageRoute(_DashboardGate))`.

### 7.4 `_DashboardGate` (login_screen.dart:311–349)

- Post-frame callback: `isRegistered` → `pushNamedAndRemoveUntil('/', ...)` else `pushNamedAndRemoveUntil('/login', ...)`.
- ⚠️ No `routes:`/`onGenerateRoute` exists on `MaterialApp` (main.dart:206–221 uses only `home:`), so both named-route calls would throw `FlutterError` at runtime — the class is effectively **broken/dead navigation** (A-1).

### 7.5 `_handleForgotPassword()` (login_screen.dart:67–87)

- Requires non-empty, `@mrcet.ac.in` email; `FirebaseAuth.sendPasswordResetEmail`; success SnackBar; `FirebaseAuthException` → inline banner.

---

## 8. Registration Flow — `RegistrationScreen` → `OtpScreen` → `SetPasswordScreen`

### 8.1 `RegistrationScreen` (`registration_screen.dart`, 147 LOC)

- `_handleInitiate()` (registration_screen.dart:30–62): domain-validates the email, then `authRepo.sendOtp()` → push `OtpScreen(email: email)`.
- ⚠️ `sendOtp()` posts **no body** (see §11) — the email field here is essentially cosmetic (A-3). When `fromLogin` is true the field is `readOnly` and pre-filled.

### 8.2 `OtpScreen` (`otp_screen.dart`, 258 LOC)

- 6 single-digit boxes with auto-advance focus; digits-only input (otp_screen.dart:196–253); 6th digit triggers `_handleVerify` immediately (otp_screen.dart:243).
- `_startResendCooldown([seconds = 60])` (otp_screen.dart:44–55): `Timer.periodic(1s)` countdown; `_handleResend()` (otp_screen.dart:57–76) re-calls `authRepo.sendOtp()` and restarts the cooldown with a success SnackBar.
- ⚠️ `_handleVerify()` (otp_screen.dart:80–101) does **not** contact any backend — it only checks `_otp.length == 6`, then immediately pushes `SetPasswordScreen(email, otp)`. The `_isLoading = true` at otp_screen.dart:87–93 is immediately reset to `false` and is dead code (A-2). The 6-digit code is only validated later, server-side, at `/register/complete`.

### 8.3 `SetPasswordScreen` (`set_password_screen.dart`, 230 LOC)

- `_handleComplete()` (set_password_screen.dart:28–112) runs the full registration commit:
  1. Validate: password ≥ 6 chars, matches confirm (client-side only; no strength meter).
  2. `HardwareService.getDeviceSnapshot()` → builds `DeviceInfoPayload` (note `biometricsEnabled: true` hard-coded, A-4).
  3. `authRepo.checkAuthStatus()` → `AuthStatusResponse.userId` — aborts if null.
  4. `RegistrationCompleteRequest(userId, otp, password, deviceInfo.toJson())` → `authRepo.completeRegistration(request)` → `POST /api/v1/auth/register/complete`.
  5. On `status == 'success'`: `authRepo.verifySession(deviceInfoPayload)` (errors non-blocking), `PermissionService().requestAll()`, `FacultyService.loadBaseProfile()`, `prefs['is_logged_in'] = true`.
  6. `Navigator.of(context).pushNamedAndRemoveUntil('/', ...)` — same broken named-route issue as `_DashboardGate` (A-1).
- Non-success → inline error from `response.error`.

---

## 9. `CompromisedDeviceScreen` — Scorched-Earth Lock

**File:** `lib/Presentation/Features/Auth/compromised_device_screen.dart` (127 LOC)

- A `StatelessWidget` taking a single `reason` string. `PopScope(canPop: false)` blocks back navigation; the only action is "Exit Application" → `SystemNavigator.pop()` (compromised_device_screen.dart:109).
- Displayed exclusively from `SecurityOverlay` when `SecurityController.isCompromised` (main.dart:243).
- The **actual teardown** happens before this screen is shown: `SecurityController.executeScorchedEarth(reason)` (see §12.4) — POSTs a signed payload to `/api/v1/faculty/device/compromised`, signs out Firebase, deletes the hardware keypair, and revokes key enrollment.
- Reasons observed: `SEC_ROOT_DETECTED` (boot/audit/scan) and `SEC_ROOT_DETECTED_SCAN` (QR scan integrity).

---

## 10. `FacultyService` — Auth Orchestration & Profile Gate

**File:** `lib/Services/faculty_service.dart` (480 LOC)

### 10.1 `executeAuthFlow(IAuthRepository authRepo)` (faculty_service.dart:169–216)

The login "auth decision tree" (mirrors the Student app):

```
FirebaseAuth.currentUser == null ──► "No active session found."
   └─ authRepo.checkAuthStatus()                    POST /api/v1/auth/status  {token}
        ├─ authStatus.isActive ──► verifySession(deviceInfo)   POST /auth/verify-session
        │     ├─ isAuthenticated ──► _loadFromAuthStatus() → null (registered)
        │     ├─ isDeviceMismatch | isDeviceMissing ──► "Device not recognized. Contact your administrator."
        │     ├─ isRegistrationRequired ──► isRegistered=false → null
        │     └─ else ──► sessionResult.message
        ├─ isPending | isNotFound ──► isRegistered=false; best-effort profile cache → null
        └─ else ──► "Unknown account status."
```

- `_buildDeviceInfoPayload()` (faculty_service.dart:218–241): `HardwareService.getDeviceSnapshot()` → `DeviceInfoPayload`; on failure falls back to all-`'unknown'` + `biometricsEnabled: false`.
- `_loadFromAuthStatus()` (faculty_service.dart:243–259): sets `isRegistered=true`, builds `FacultyProfile`, persists `profile` + `is_registered` to Hive.

### 10.2 `loadBaseProfile()` (faculty_service.dart:263–334)

- Cache-first: `loadFromCache()` runs first; a cached profile short-circuits to `null` ("UI Unblocked via CACHE").
- Else `GET /api/v1/faculty/sync` (10 s timeouts) → `data['profile']`; sets `isRegistered` from `profile['is_registered']`; `facultyId = email`.
- No profile block → `isRegistered=false`, `profile=null`, returns **`"ACCOUNT_UNLINKED: Profile not found for ..."`** (faculty_service.dart:326).
- `load()` (faculty_service.dart:376–459) is the master variant with a `_loadCompleter` single-flight guard and a once-only `_isLoaded` short-circuit.

### 10.3 `initializeListeners()` / `onAppResume()` (faculty_service.dart:337–372)

- Phase 2 background hydration via `FacultyHydrationService().syncIfNeeded()`; no persistent listeners remain (comment at faculty_service.dart:87).

### 10.4 `loadFromCache()` (faculty_service.dart:93–127)

- Restores `profile`, `stats`, `courses` from Hive; re-derives courses from cohorts if empty; **sets `is_logged_in = true`** whenever a cached profile exists (faculty_service.dart:101–103) — a gate flag written without any server check (A-9).

---

## 11. `AuthRepository` — Firebase + Device-Binding Repository

**File:** `lib/Data/Repositories/auth_repository.dart` (139 LOC)

- Implements `IAuthRepository` (auth_repository.dart:8–17); constructed with `ApiClient` (`main.dart:167–169`).
- `_getIdToken()` (auth_repository.dart:25–31): throws `Exception('No authenticated user')` if no Firebase user, else returns the cached ID token.

| Member | Endpoint / mechanism | Notes |
|---|---|---|
| `checkAuthStatus()` (34–46) | `POST /api/v1/auth/status` `{token}` | returns `AuthStatusResponse`; Dio errors logged + rethrown |
| `sendOtp()` (49–54) | `POST /api/v1/auth/register/send-otp` | **no body**; throws if `statusCode != 200` |
| `completeRegistration()` (57–85) | `POST /api/v1/auth/register/complete` | body = `RegistrationCompleteRequest.toJson()` (incl. plaintext password over TLS); maps Dio error bodies to `RegistrationCompleteResponse` |
| `verifySession()` (88–113) | `POST /api/v1/auth/verify-session` | body = `{token, role: 'faculty', device_info, fcm_token?}` from prefs; returns parsed response or `status: 'error'` fallback |
| `signIn()` (116–129) | `FirebaseAuth.signInWithEmailAndPassword` | rethrows |
| `signOut()` (132–134) | `FirebaseAuth.signOut` | |
| `changePassword()` (137–150) | Firebase re-auth + update | `EmailAuthProvider.credential` → `reauthenticateWithCredential` → `updatePassword` |
| `getCurrentUser()` (153–155) | `FirebaseAuth.currentUser` | |

- The Firebase ID token is attached automatically to every request by `AuthInterceptor` (Bearer) and also **passed in the body** of `/auth/status` and `/auth/verify-session` — a dual transmission (A-11).

---

## 12. `SecurityController` & the Hardware Trust Layer

**File:** `lib/Core/Services/security_controller.dart` (325 LOC)

- `SecurityState` enum (security_controller.dart:18): `checking, permissionsMissing, authenticating, ready, compromised`.
- Root `ChangeNotifier`, registered at `main.dart:156–157`; `WidgetsBindingObserver` (security_controller.dart:20).
- Constructor (security_controller.dart:79–84): stores singleton, `_loadBiometricPreference()`, `_performInitialSecurityCheck()`, registers lifecycle observer.

### 12.1 State getter (security_controller.dart:52–58)

```
compromised  →  if _isCompromised
checking     →  if !_initialCheckComplete
authenticating → if _isAuthenticating
permissionsMissing → if _isLocked        (name is misleading — see A-6)
ready        →  otherwise
```

### 12.2 Root / scan checks

- `_performInitialSecurityCheck()` (259–281): `HardwareService.getDeviceSnapshot()` → if `isRooted` → `_isCompromised=true`, `_violationReason='SEC_ROOT_DETECTED'`, `executeScorchedEarth('SEC_ROOT_DETECTED')`.
- `performSecurityAudit()` (283–296): same root re-check on app resume, then `_checkPermissionsSilently()`.
- `verifyIntegrityOnScan()` (300–314): force-refreshes the snapshot; root → `SEC_ROOT_DETECTED_SCAN` + scorched earth; used by QR-scan paths.
- `_checkPermissionsSilently()` (323–330): notification / auto-time / auto-timezone / India-timezone pillars; **only `notificationsOk` feeds `arePermissionsOk`** (A-6).

### 12.3 Biometric lock & lifecycle

- `setBiometricLockEnabled()` (101–111) persists `biometric_lock_enabled`; disabling while locked unlocks.
- `didChangeAppLifecycleState()` (116–139): locks on `paused`/`hidden`/`inactive` **only if `_biometricLockEnabled`**; on `resumed` → `HardwareService.clearCache()` + security re-check + `TimeSyncService.compensateDrift()` + `performSecurityAudit()`.
- `authenticate()` (174–244): single-flight; checks `canCheckBiometrics`/`isDeviceSupported` (auto-unlock if unavailable); `_auth.authenticate` with `stickyAuth`, **15 s timeout**; rejects as **bypass** if auth resolves in **< 350 ms** (security_controller.dart:221–224); success calls `FacultyService.onAppResume()`.

### 12.4 `executeScorchedEarth(reason)` (security_controller.dart:337–377)

1. `HardwareService.getMonotonicTime()` + device fingerprint.
2. If a hardware keypair exists: `signPayload('$reason:$monotonic')` → signature.
3. `POST /api/v1/faculty/device/compromised` with `X-Device-ID` header and body `{email, device_id, reason, monotonic_timestamp_ms, nonce_or_pill_id, signature}` (empty string if no keypair).
4. `FirebaseAuth.signOut()`.
5. `HardwareService.deleteKeyPair()` + `KeyEnrollmentService.revoke()`.

- ⚠️ Every step is wrapped in `catch (_) {}` — the teardown is **best-effort and silently swallowable** (A-7).

### 12.5 Hardware trust primitives (`hardware_service.dart`, 153 LOC)

- `getDeviceSnapshot()` via `MethodChannel('com.intelliattend.faculty/hardware')`; 30 s cache; `forceRefresh` bypass (hardware_service.dart:23–98). ⚠️ On native-bridge failure it returns a `DeviceData` with **`isRooted: true`** (hardware_service.dart:94) — a failure would false-positive the compromised lock (A-8).
- Monotonic clock, hardware keypair generate/sign/public-key/delete (hardware_service.dart:110–148).
- `KeyEnrollmentService` (73 LOC): Phase 1 generates the keypair at boot; **Phase 2 (`synchronizeWithServer`) is a documented no-op** — backend enrollment endpoints are not deployed (A-13).

---

## 13. Server-Driven Logout — `ForceLogoutService` & Interceptors

### 13.1 `ForceLogoutService` (`force_logout_service.dart`, 106 LOC)

- `ForceLogoutReason` enum (force_logout_service.dart:10–18): `sessionRevoked, deviceMismatch, accountBlocked, securityViolation, adminForceLogout, multipleDevicesDetected, appDeprecated`.
- `execute()` (43–88): single-flight guard → `PersistenceService().clearAllData()` → `FirebaseAuth.signOut()` → `FacultyService.clear()` → `SecurityController.resetAll()` → `_navigateToLogin(message)` (109–122) = `pushAndRemoveUntil(LoginScreen(initialError: message))`.
- Navigator context injected from `MaterialApp.builder` (`main.dart:216`, `force_logout_service.dart:39`).

### 13.2 `AuthInterceptor` (`auth_interceptor.dart`, 155 LOC)

- `onRequest` (15–69): attaches `Authorization: Bearer <idToken>` (cached token; force-refresh on null/`user-token-expired`/`invalid-credential`).
- `onError` (76–151):
  - **401** → `revoked`/`terminated` detail → `sessionRevoked`; `hardware`/`device` detail → `deviceMismatch`; otherwise **refresh token + retry once**; retry failure → `sessionRevoked`.
  - **403** → `ACCOUNT_SUSPENDED`/`BLOCKED`/`suspend` → `accountBlocked`; `DEVICE_MISMATCH`/`PROXY`/`hardware` → `deviceMismatch`.

### 13.3 `SecurityInterceptor` (`security_interceptor.dart`, 71 LOC)

- `onRequest` (11–27): attaches `X-Device-ID`, `X-Device-Fingerprint`, `X-Device-Model`, `X-App-Version` to **every** request from `HardwareService.getDeviceSnapshot()`.
- `onError` (35–66): **426** → `appDeprecated`; **403** with `SHARED_DEVICE`/`HARDWARE_VIOLATION`/`DEVICE_MISMATCH`/`PROXY`/`hardware`/`device fingerprint` → `deviceMismatch`.

### 13.4 `ApiClient` (`api_client.dart`, 110 LOC)

- Default base `https://api-dev.balaseetharamanjaneyulu.com` (api_client.dart:19); overridden by `.env` `API_BASE_URL` = **`https://api.intelliattend.app`**.
- Cert pinning via `PINNED_CERT_FINGERPRINTS`; empty list → debug mode accepts any cert (api_client.dart:72–74).
- Interceptor order: `RetryInterceptor` (2 retries, backoff) → `AuthInterceptor` → `SecurityInterceptor` (api_client.dart:46–48).
- ⚠️ Debug builds add a `LogInterceptor` that logs **request headers, request bodies, response bodies** — including the plaintext password in `/register/complete` (A-11).

---

## 14. Data Models & DTOs

| Model | File | Fields / Notes |
|---|---|---|
| `AuthStatusResponse` | `registration_models.dart` (125) | `authStatus` (`active`/`pending`/`not_found`), `name`, `role`, `userId`; `isActive/isPending/isNotFound` getters |
| `VerifySessionResponse` | `registration_models.dart` | `status` (`authenticated`/`device_mismatch`/`device_missing`/`registration_required`/`error`), `authStatus`, `errorCode`, `message` |
| `RegistrationCompleteRequest` | `registration_models.dart` | `userId`, `otp`, `password`, `deviceInfo`; toJson snake_case (`user_id`, `device_info`) |
| `RegistrationCompleteResponse` | `registration_models.dart` | `status` (`success`/`error`), `profile`, `error`, `errorCode`; tolerant of FastAPI `detail` envelopes |
| `DeviceInfoPayload` | `registration_models.dart` | `deviceId`, `deviceFingerprint`, `brand`, `model`, `manufacturer`, `osVersion`, `biometricsEnabled`, `isRooted` (default false) |
| `AuthSession` | `auth_session_model.dart` (95) | server session DTO for `/api/v1/auth/sessions` (`sessionId`, `deviceModel`, `isCurrentDevice`, `ipAddress`, …) |
| `FacultyProfile` | `faculty_service.dart:12–46` | `name`, `department`, `designation`, `email`, `facultyId`, `profileImage` |
| `DeviceData` | `core/models/device_data.dart` | hardware snapshot from `HardwareService` |

---

## 15. Backend API Reference

| Endpoint | Verb | Used by | Body / Notes |
|---|---|---|---|
| `/api/v1/auth/status` | POST | `AuthRepository.checkAuthStatus` (auth_repository.dart:38); also `SetPasswordScreen` step 1 | `{token}`; returns `auth_status` + optional `name`/`user_id` |
| `/api/v1/auth/register/send-otp` | POST | `AuthRepository.sendOtp` (auth_repository.dart:50) — `RegistrationScreen._handleInitiate`, `OtpScreen._handleResend` | **empty body** (A-3) |
| `/api/v1/auth/register/complete` | POST | `AuthRepository.completeRegistration` (auth_repository.dart:62) | `{user_id, otp, password, device_info}` |
| `/api/v1/auth/verify-session` | POST | `AuthRepository.verifySession` (auth_repository.dart:95) — `executeAuthFlow`, `SetPasswordScreen` | `{token, role: 'faculty', device_info, fcm_token?}` |
| `/api/v1/auth/sessions` | GET | `SessionManagementService.getActiveSessions` (session_management_service.dart:14) | returns `data['sessions']` |
| `/api/v1/auth/sessions/:id` | DELETE | `SessionManagementService.revokeSession` (:25) | `data['success']` |
| `/api/v1/faculty/sync` | GET | `FacultyService.loadBaseProfile`/`load` (faculty_service.dart:291,418) | 10 s timeouts; `data['profile']` block |
| `/api/v1/faculty/device/compromised` | POST | `SecurityController.executeScorchedEarth` (security_controller.dart:353) | `X-Device-ID` header + `{email, device_id, reason, monotonic_timestamp_ms, nonce_or_pill_id, signature}` |
| `/api/v1/time` | GET | `TimeSyncService.bootstrap` (time_sync_service.dart:143) | 5 s timeouts; `{timestamp \| server_time_ms}` |

All requests go through `ApiClient().dio` (JWT bearer, device headers, cert pinning, retries). Base from `.env`: `https://api.intelliattend.app` (code default `https://api-dev.balaseetharamanjaneyulu.com`, `api_client.dart:19`).

---

## 16. WebSocket Real-Time Protocol

The Auth module opens **no WebSocket channels**. Session state is validated synchronously via REST (`/auth/status`, `/auth/verify-session`) at login, and **server-initiated revocation arrives over HTTP** (401/403/426) rather than a push channel — `AuthInterceptor`/`SecurityInterceptor` translate those into `ForceLogoutService`. The only live-update behavior is the client-side lifecycle/security audit (`SecurityController.didChangeAppLifecycleState`) and the FCM push channel (token registered via `SyncFcmHandler`), neither of which is a WebSocket.

---

## 17. Navigation Map

```
MaterialApp home: UnifiedAuthGate                                [main.dart:213]
   └─ _phase switch                                               [unified_auth_gate.dart:125–142]
        ├─ cacheHit/dashboard ──► DashboardScreen
        ├─ loading/initial ──► _buildSplash
        ├─ login ──► LoginScreen
        └─ registration ──► RegistrationScreen(preloadedEmail, fromLogin: true)

LoginScreen._handleLogin
   ├─ not registered ──► push RegistrationScreen (anonymous MaterialPageRoute)   [login_screen.dart:141–149]
   └─ registered ──► push _DashboardGate → pushNamedAndRemoveUntil('/')  ⚠️ unregistered route (A-1)
        └─ back: ForceLogoutService._navigateToLogin ──► LoginScreen(initialError)  [force_logout_service.dart:115–121]
   └─ Forgot Password ──► FirebaseAuth.sendPasswordResetEmail

RegistrationScreen._handleInitiate ──► push OtpScreen(email)                     [registration_screen.dart:50–55]
OtpScreen._handleVerify ──► push SetPasswordScreen(email, otp)                   [otp_screen.dart:95–100]
SetPasswordScreen._handleComplete ──► pushNamedAndRemoveUntil('/')  ⚠️ unregistered route (A-1)

SecurityOverlay
   ├─ isCompromised ──► CompromisedDeviceScreen(reason)  (no back, exit-app only)
   └─ isLocked ──► LockScreen (tap → SecurityController.authenticate)
```

All module routes are anonymous `MaterialPageRoute`s except the two named-route calls that target `/` and `/login` — which are **not registered** anywhere (A-1). Route name `'LoginScreen'` is set only for the force-logout push (`force_logout_service.dart:118`).

---

## 18. Sequence Diagrams

### 18.1 Cold-start auth gate

```
main()
   ├─ Track A: dotenv + Hive + ThemeController + loadFromCache()   (~100 ms)
   ├─ Track B: Firebase.initializeApp()                            (background)
   └─ runApp → SecurityController() → _performInitialSecurityCheck()
        └─ HardwareService.getDeviceSnapshot()
             ├─ isRooted ──► compromised → executeScorchedEarth → CompromisedDeviceScreen
             └─ else ──► _checkPermissionsSilently()

UnifiedAuthGate._startBootSequence()
   ├─ await persistenceFuture
   ├─ profile != null && isRegistered ──► cacheHit ──► DashboardScreen (instant)
   │     └─ _backgroundValidate():
   │          await firebaseReady → currentUser == null ──► login
   │          loadBaseProfile() ──► error ──► stay (silent)
   │          !isRegistered ──► registration   |   else ──► dashboard + initializeListeners() + TimeSyncService.bootstrap()
   └─ miss ──► loading ──► _loadFromNetwork():
        await firebaseReady → loadBaseProfile()
           ├─ error ──► loadFromCache() ──► profile? dashboard : login
           ├─ !isRegistered ──► registration
           └─ ok ──► dashboard + _backgroundValidate()
```

### 18.2 Login (Firebase + auth flow)

```
LoginScreen._handleLogin(email, password)
   ├─ authRepo.signIn() → FirebaseAuth.signInWithEmailAndPassword
   ├─ prefs['last_login_email'] = email
   ├─ FacultyService.executeAuthFlow(authRepo)
   │    ├─ POST /auth/status {token}
   │    │    ├─ active ──► POST /auth/verify-session {token, role, device_info, fcm_token}
   │    │    │     ├─ authenticated ──► isRegistered = true → return null
   │    │    │     ├─ device_mismatch/missing ──► error string
   │    │    │     └─ registration_required ──► isRegistered = false → null
   │    │    ├─ pending/not_found ──► isRegistered = false → null
   │    │    └─ else ──► "Unknown account status."
   │    └─ flowError ──► authRepo.signOut() + banner
   ├─ isRegistered ──► _navigateToDashboard()  [→ _DashboardGate → pushNamedAndRemoveUntil('/') ⚠️ A-1]
   └─ else ──► push RegistrationScreen(email, fromLogin: true)
   └─ FirebaseAuthException ──► ErrorHandler.showVisualError (bottom sheet)
```

### 18.3 Registration — OTP request

```
RegistrationScreen._handleInitiate(email)
   ├─ validate @mrcet.ac.in
   └─ authRepo.sendOtp()  POST /auth/register/send-otp   (no body — A-3)
        └─ push OtpScreen(email)
OtpScreen
   ├─ 6th digit / Verify button ──► _handleVerify: len==6 ? push SetPasswordScreen(email, otp)
   │        (no server call — A-2)
   └─ Resend ──► sendOtp() again + 60 s cooldown timer
```

### 18.4 Registration — password set + device binding

```
SetPasswordScreen._handleComplete(password, confirm)
   ├─ validate length/equality
   ├─ HardwareService.getDeviceSnapshot() → DeviceInfoPayload (biometricsEnabled: true hard-coded)
   ├─ authRepo.checkAuthStatus() → userId (abort if null)
   ├─ RegistrationCompleteRequest(userId, otp, password, device_info)
   ├─ authRepo.completeRegistration() → POST /auth/register/complete
   │    ├─ status == 'success':
   │    │    ├─ authRepo.verifySession(deviceInfo)  (non-blocking errors)
   │    │    ├─ PermissionService().requestAll()      (notification only)
   │    │    ├─ FacultyService.loadBaseProfile()      (GET /faculty/sync)
   │    │    ├─ prefs['is_logged_in'] = true
   │    │    └─ pushNamedAndRemoveUntil('/') ⚠️ unregistered route (A-1)
   │    └─ else ──► inline error banner
   └─ catch ──► "An error occurred during completion."
```

### 18.5 Session verification on subsequent login

```
User taps SIGN IN
   ├─ Firebase signIn succeeds (credential valid)
   ├─ POST /auth/status ──► active
   ├─ POST /auth/verify-session with device_info (X-Device headers also attached by SecurityInterceptor)
   │    ├─ fingerprint matches bound device ──► authenticated ──► dashboard
   │    └─ fingerprint differs / unbound ──► "Device not recognized." → signOut → banner
   └─ any 401/403 during session ──► interceptors → ForceLogoutService → wipe → LoginScreen(message)
```

### 18.6 Compromised-device lock (scorched earth)

```
SecurityController._performInitialSecurityCheck / performSecurityAudit / verifyIntegrityOnScan
   └─ HardwareService.getDeviceSnapshot().isRooted
        └─ _isCompromised = true; _violationReason = 'SEC_ROOT_DETECTED'
             └─ executeScorchedEarth('SEC_ROOT_DETECTED')
                  ├─ signPayload('$reason:$monotonic')  (hardware keypair)
                  ├─ POST /faculty/device/compromised {email, device_id, reason,
                  │       monotonic_timestamp_ms, nonce_or_pill_id, signature}
                  ├─ FirebaseAuth.signOut()
                  ├─ HardwareService.deleteKeyPair()
                  └─ KeyEnrollmentService.revoke()
   └─ SecurityOverlay rebuild → CompromisedDeviceScreen(reason)
        └─ "Exit Application" → SystemNavigator.pop()
```

---

## 19. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| No Firebase user at login | `executeAuthFlow` returns `"No active session found."` → banner |
| Wrong password / unknown user | `FirebaseAuthException` → `ErrorHandler.sanitize` → bottom-sheet (title "Invalid Credentials") |
| Too many attempts / account disabled | `user-disabled` / `too-many-requests` mapped to restricted / lockdown sheets |
| Network failure at login | `DioException`/generic → sanitized bottom sheet |
| Device mismatch / missing at verify-session | error string from `sessionResult.message` → `authRepo.signOut()` + banner |
| `ACCOUNT_UNLINKED` | `loadBaseProfile` sets `profile=null`, `isRegistered=false`, returns error; gate falls back to cache or login (`faculty_service.dart:326,451`) |
| Background validation fails in gate | phase stays; **no redirect, no message** (A-14) |
| `sendOtp` non-200 | `Exception('Failed to send OTP')` → generic banner |
| OTP wrong / incomplete | length < 6 → "Please enter the full 6-digit code."; content never checked client-side (A-2) |
| Resend during cooldown | button disabled while `_resendCooldown > 0` |
| Registration complete error | `response.error` inline banner; Dio timeout → "Network error: …" |
| `userId == null` at set-password | "Could not verify your identity. Please restart registration." |
| Biometric unsupported | `authenticate()` auto-unlocks (documented in code) |
| Biometric timeout (>15 s) | `authenticate()` returns false → LockScreen "Timed out. Tap to retry." |
| Bypass attempt (<350 ms auth) | `_bypassDetected = true`, stays locked |
| Rooted device | compromised state → scorched earth → CompromisedDeviceScreen |
| 401 (revoked/terminated) | `ForceLogoutService(sessionRevoked)` → wipe → LoginScreen message |
| 401 (hardware/device detail) | `ForceLogoutService(deviceMismatch)` |
| 403 (BLOCKED/suspend) | `ForceLogoutService(accountBlocked)` |
| 403 (device/hardware) | `ForceLogoutService(deviceMismatch)` (both interceptors) |
| 426 Upgrade Required | `ForceLogoutService(appDeprecated)` |
| Named route `/` or `/login` | would throw `FlutterError` — no route generator (A-1) |
| Native bridge failure in snapshot | returns `isRooted: true` fallback → false-positive compromise (A-8) |

---

## 20. Performance Engineering

- **Two-phase boot** (`main.dart:46–71`): Track A (Hive/dotenv/prefs, ~100 ms) unblocks the UI; Track B (Firebase + heavy services) runs after first frame. The gate awaits only `persistenceFuture`.
- **Cache-first profile**: `loadBaseProfile` short-circuits on a cached `profile` (`faculty_service.dart:276–279`), and `load()` completes `_loadCompleter` immediately on cache hit — no duplicate `/sync`.
- **Single-flight guards**: `FacultyService._loadCompleter` (dedupes concurrent `load()`), `ForceLogoutService._isExecuting`, `SecurityController._isAuthenticating`, `PermissionService._isRequesting`, `HardwareService` 30 s snapshot cache.
- **Overlay optimization**: `RepaintBoundary` + `AbsorbPointer` around the navigator so the lock overlay adds no per-frame cost (`main.dart:261–265`); `SecurityController._safeNotify` defers notifications to post-frame.
- **Retry interceptor**: connection/timeout errors retried up to 2× with exponential backoff at the Dio layer (`api_client.dart:108–130`).
- **No module-local timers** except the OTP resend countdown (a 1 s periodic `Timer`, cancelled on `dispose`).
- **Low risk**: no heavy lists or images beyond the boot logo asset; the only spinner replaces the whole splash while `loading`.

---

## 21. Security

- **Identity provider**: Firebase Auth only; the app never stores the password (it lives in `TextEditingController` memory for the screen lifetime). The faculty email is persisted as `last_login_email` (plaintext SharedPreferences — A-10) purely for pre-fill.
- **Token handling**: ID token attached as `Authorization: Bearer` by `AuthInterceptor` on every request; also mirrored in the body of `/auth/status` and `/auth/verify-session`. Tokens are never stored by the app; Firebase refreshes them.
- **Device binding**: `X-Device-ID` / `X-Device-Fingerprint` / `X-Device-Model` / `X-App-Version` on every request (`SecurityInterceptor`); `/auth/verify-session` enforces the registered device at login; `device_mismatch` → login rejected.
- **Scorched-earth teardown**: on root detection the app reports the violation with a **hardware-keypair-signed** payload (`signature = signPayload('$reason:$monotonic')`), then deletes the keypair and revokes enrollment. Empty signature when no keypair exists (A-7).
- **Anti-bypass**: biometric auth is rejected if it resolves in < 350 ms; 15 s timeout; never auto-runs on startup/resume (only explicit user action).
- **Transport**: TLS + cert pinning (`PINNED_CERT_FINGERPRINTS`; debug falls back to accept-any when the list is empty). ⚠️ Debug `LogInterceptor` prints request bodies — including the plaintext password on `/register/complete` (A-11).
- **Lock semantics**: app starts unlocked; lock applies only when `biometric_lock_enabled` and only while `isUserLoggedIn` is provable (Firebase user / `is_logged_in` / cached profile) — avoids trapping the user pre-login.
- **Server-driven revocation**: 401/403/426 translate to a full local wipe (`clearAllData`) before routing to login, preventing stale-session reuse.
- **Verdict flags**: `biometricsEnabled: true` and `isRooted` (default `false`) are **hard-coded**, not read from the device snapshot, in both `_buildDeviceInfoPayload` and `SetPasswordScreen` (A-4).

---

## 22. Dependencies Used

| Package | Where used |
|---|---|
| `provider` | `context.read<AuthRepository>()`, `ChangeNotifierProvider<SecurityController>` |
| `firebase_auth` / `firebase_core` | sign-in/out, ID token, `sendPasswordResetEmail`, current user |
| `dio` | all auth REST via `ApiClient` |
| `shared_preferences` | `is_logged_in`, `last_login_email`, `biometric_lock_enabled`, `fcm_token` |
| `hive` / `hive_flutter` | `PersistenceService` profile / `is_registered` cache |
| `local_auth` | biometric unlock (`SecurityController.authenticate`) |
| `permission_handler` | notification pillar (`PermissionService`) |
| `flutter_dotenv` | `API_BASE_URL`, `PINNED_CERT_FINGERPRINTS` |
| `crypto` | cert-fingerprint hashing in `ApiClient` |
| `google_fonts` | auth-screen typography (`Inter`, `JetBrainsMono`) |
| `package_info_plus` | login footer version string |
| `flutter_timezone` | (imported by `SecurityController`) |
| `firebase_messaging` | FCM token persisted for `verify-session` body (`sync_fcm_handler.dart:141`) |

---

## 23. File Inventory

> Line counts = `Measure-Object -Line` (non-blank, per repo convention).

### 23.1 Auth feature — `lib/Presentation/Features/Auth/`

| File | LOC | Role |
|---|---|---|
| `unified_auth_gate.dart` | 175 | Boot state machine (gate → dashboard/login/registration) |
| `login_screen.dart` | 313 | Firebase login + auth decision tree + `_DashboardGate` |
| `lock_screen.dart` | 82 | Biometric unlock overlay |
| `compromised_device_screen.dart` | 127 | Scorched-earth lock UI (exit-app only) |
| `Registration/registration_screen.dart` | 147 | Request OTP (send-otp) |
| `Registration/otp_screen.dart` | 258 | 6-digit OTP entry + resend countdown |
| `Registration/set_password_screen.dart` | 230 | Set password + complete registration + device bind |

### 23.2 Supporting repositories / services / models

| File | LOC | Role |
|---|---|---|
| `lib/Data/Repositories/auth_repository.dart` | 139 | Firebase + REST auth contract (`IAuthRepository`) |
| `lib/Core/Services/security_controller.dart` | 325 | Device fingerprint, root checks, biometric lock, scorched earth |
| `lib/Services/faculty_service.dart` | 480 | `executeAuthFlow`, `loadBaseProfile`, profile/`isRegistered` notifiers |
| `lib/Core/Services/force_logout_service.dart` | 106 | Server-driven logout pipeline |
| `lib/Core/Services/hardware_service.dart` | 153 | Device snapshot, root check, keypair, monotonic clock |
| `lib/Core/Services/key_enrollment_service.dart` | 73 | Hardware keypair enrollment (Phase 2 = no-op) |
| `lib/Core/Network/api_client.dart` | 110 | Dio + cert pinning + interceptor stack |
| `lib/Core/Network/Interceptors/auth_interceptor.dart` | 155 | Bearer token + 401/403 → force logout |
| `lib/Core/Network/Interceptors/security_interceptor.dart` | 71 | Device headers + 403/426 → force logout |
| `lib/Core/Error/error_handler.dart` | 227 | `ErrorHandler.sanitize` / `showVisualError` |
| `lib/Data/Models/Auth/registration_models.dart` | 125 | `AuthStatusResponse`, `VerifySessionResponse`, registration DTOs, `DeviceInfoPayload` |
| `lib/Data/Models/Auth/auth_session_model.dart` | 95 | `AuthSession` DTO |
| `lib/Services/session_management_service.dart` | 43 | `/auth/sessions` list/revoke |
| `lib/Services/permission_service.dart` | 22 | Notification-only permission pillar |
| `lib/Services/time_sync_service.dart` | 287 | Server-anchored virtual clock (bootstrapped by the gate) |
| `lib/main.dart` | 247 | Boot tracks, root providers, `SecurityOverlay` wiring |

---

## 24. Appendix A — Known Design Notes & Technical Debt

### A-1. Named routes `/` and `/login` are not registered — gate navigation would crash (HIGH)

`MaterialApp` (`main.dart:206–221`) defines only `home: UnifiedAuthGate`; there is **no `routes:` map and no `onGenerateRoute`** anywhere in `lib`. Yet three call sites navigate by name: `_DashboardGate._goToDashboard` (`login_screen.dart:333`), `_DashboardGate._goToLogin` (`login_screen.dart:338`), and `SetPasswordScreen._handleComplete` (`set_password_screen.dart:98`). Each `pushNamedAndRemoveUntil` would throw `FlutterError` ("Could not find a generator for route") at runtime — so a **successful registered login via `LoginScreen` and a completed registration both terminate in a crash** instead of reaching the dashboard. Either register the routes, or replace the calls with the anonymous-route pattern used everywhere else (e.g. `dashboard_screen.dart:90`).

### A-2. OTP is never verified client-side; the OTP screen is cosmetic (HIGH)

`OtpScreen._handleVerify` (`otp_screen.dart:80–101`) only checks `otp.length == 6` and then pushes `SetPasswordScreen`. Any six digits pass; the code is validated only server-side at `/register/complete`. The `_isLoading` toggle is dead (set `true` then immediately `false` at otp_screen.dart:87–93), so the "Verify & Continue" button never shows its spinner. There is no `verify-otp` endpoint call, no attempt limit, and no error for a wrong code until the final submit.

### A-3. `sendOtp()` posts an empty body — identity derived only from the JWT (HIGH)

`AuthRepository.sendOtp` (`auth_repository.dart:49–54`) POSTs `/api/v1/auth/register/send-otp` with no body. The server must identify the faculty from the `Authorization: Bearer` token alone; the `RegistrationScreen` email field is effectively decorative. If the backend expects an `email`/`user_id` in the body (as `register/complete` does), OTP delivery silently breaks.

### A-4. Device-trust flags are hard-coded (MEDIUM)

`biometricsEnabled: true` is a literal in both `_buildDeviceInfoPayload` (`faculty_service.dart:228`) and `SetPasswordScreen` (`set_password_screen.dart:66`), and `isRooted` defaults to `false` in `DeviceInfoPayload` (`registration_models.dart:129`) — the actual snapshot's `isRooted` is never propagated into the payloads sent to `/verify-session`/`/register/complete`. The backend is told the device has biometrics and is not rooted regardless of reality.

### A-5. Institutional email domain hard-coded (MEDIUM)

`@mrcet.ac.in` is validated in `LoginScreen` (`login_screen.dart:73,98`) and `RegistrationScreen` (`registration_screen.dart:33`). Any second university domain requires a code change; a typo'd or generic email is rejected with a fixed string.

### A-6. `SecurityState.permissionsMissing` is a misnomer for "locked" (MEDIUM)

The state getter (`security_controller.dart:52–58`) maps `_isLocked` to `SecurityState.permissionsMissing`. Separately, `arePermissionsOk => notificationsOk` (`security_controller.dart:77`) while `autoTime`, `autoTimeZone` and `timezoneIndia` are tracked but never gate anything. The naming and the permissions model should be reconciled with what actually drives the lock overlay.

### A-7. Scorched-earth teardown swallows all errors (MEDIUM)

Every step of `executeScorchedEarth` (`security_controller.dart:337–377`) is inside `catch (_) {}` — the compromised-device report POST, the Firebase sign-out, `deleteKeyPair`, and `revoke` can all fail silently. If the `/faculty/device/compromised` call fails (network, revoked key), the server never learns of the violation and `signature` is `''` when no keypair exists.

### A-8. Native-bridge failure yields a false-positive "rooted" device (MEDIUM)

`HardwareService.getDeviceSnapshot` returns a fallback `DeviceData` with **`isRooted: true`** on any native-call error (`hardware_service.dart:86–97`). Because `SecurityController` treats `isRooted` as a compromise trigger, a MethodChannel failure would lock the app into the compromised screen (scorched earth) for a healthy device.

### A-9. `is_logged_in` flag semantics are inconsistent (MEDIUM)

The boolean is written in three places with different meaning: before the auth flow completes (`login_screen.dart:58`), unconditionally on any cached profile (`faculty_service.dart:102`), and at registration completion (`set_password_screen.dart:95`). It has no expiry and is the single gate input (with Firebase user + profile) for the lock overlay. A stale `true` keeps the overlay logic armed even after a failed re-login.

### A-10. `last_login_email` persisted in plaintext (MEDIUM)

`login_screen.dart:118` stores the email in `SharedPreferences` as `last_login_email` (restored at `login_screen.dart:39`). It is an identifier, not a secret, but it is unencrypted device-resident PII and survives until wiped.

### A-11. Debug `LogInterceptor` logs request bodies, including the plaintext password (MEDIUM)

`api_client.dart:50–53` enables `LogInterceptor(requestHeader: true, requestBody: true, responseBody: true)` in non-release builds. The `/register/complete` body contains `password` in cleartext, so **debug builds write the plaintext password to the device log**. The ID token is likewise double-transmitted (header + body of `/auth/status` and `/auth/verify-session`), enlarging the token's exposure surface.

### A-12. OTP auto-verify double-trigger (LOW)

Typing the 6th digit auto-invokes `_handleVerify` (`otp_screen.dart:243`), but the "Verify & Continue" button remains enabled — tapping it again re-pushes `SetPasswordScreen`, leaving duplicate routes in the stack. A guard or disabling the button during submission is missing.

### A-13. `KeyEnrollmentService` Phase 2 is a documented no-op (LOW)

`synchronizeWithServer` (`key_enrollment_service.dart:57–71`) is unimplemented pending backend enrollment endpoints, and `SecurityInterceptor`'s header list (`security_interceptor.dart:15–18`) does not actually include the public key despite its class comment claiming it is "sent with every API request". Enrollment today is local-only.

### A-14. Cache-hit gate can silently strand a user on the dashboard (LOW)

On the `cacheHit` path, `DashboardScreen` renders before Firebase is ready; if `_backgroundValidate` subsequently fails (`loadBaseProfile` error), the phase is left unchanged (`unified_auth_gate.dart:82–85`) — no redirect to login and no user message, so a revoked/blocked user can keep browsing stale cached data.

---

*End of Auth Module technical documentation. Companion: `HOME_MODULE.md`, `COURSES_MODULE.md`, `MYCLASS_MODULE.md`, `PROFILE_MODULE.md`.*
