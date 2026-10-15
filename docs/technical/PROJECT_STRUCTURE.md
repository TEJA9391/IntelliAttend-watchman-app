# PROJECT STRUCTURE: IntelliAttend Faculty Mobile App

This document outlines the architectural organization of the standalone Faculty application.

## 📁 Package Hierarchy (`com.intelliattend.app`)

### 📦 `auth`
- `AuthRepository`: Faculty identity management (Firebase + Backend).
- `AuthInterceptor`: Secure JWT token attachment to API calls.

### 📦 `network`
- `ApiService`: Faculty-specific API definitions (`createSession`, `getFacultyProfile`).
- `NetworkModule`: Hilt provider for Retrofit/OkHttp.

### 📦 `ui.auth`
- `LoginScreen`: Official faculty login interface.
- `AuthViewModel`: Manages faculty session lifecycle and role verification.

### 📦 `ui.faculty`
- `LiveMonitorScreen`: Real-time dashboard for active attendance sessions.
- `SmartBoardLinkScreen`: QR projection and board synchronization logic.

### 📦 `ui.profile`
- `ProfileScreen`: Displays faculty-specific professional data.
- `DeveloperInfoScreen`: Diagnostic tools for faculty/developers.
- `QrDebugScannerScreen`: Utility for testing QR token validity.

### 📦 `data`
- `local`: Room DB for caching faculty metadata.
- `model`: Faculty-only data models (`FacultyProfile`, `SecurityPackage`, `SessionResponse`).

### 📦 `security`
- `SecurityService`: Biometric auth and device integrity checks.

---

## 🛠 Navigation Graph
- `splash` → `login` (if not authenticated)
- `splash` → `faculty_dashboard/active` (if authenticated)
- `faculty_dashboard` → `settings`, `profile`, `attendance_history`
- `profile` → `developer_info` → `qr_debug_scanner`

---

## 🗑 Removed Components (Standalone Refactoring)
The following student-specific packages have been **surgically removed** for codebase health:
- `com.intelliattend.app.student` (Repository & ViewModels)
- `com.intelliattend.app.ui.student` (Dashboard & UI)
- `com.intelliattend.app.ui.scanner.AttendanceSuccessScreen`
- `com.intelliattend.app.ui.auth.StudentRegistration`

---

**Last Updated:** March 2026  
**Status:** Standalone Faculty Edition (100% Dedicated)
