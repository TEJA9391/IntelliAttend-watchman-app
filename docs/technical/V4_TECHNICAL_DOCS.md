# 📘 IntelliAttend Faculty v4.0: Technical Documentation

## 1. Executive Summary
IntelliAttend Faculty is a professional mobile solution designed for high-integrity attendance management. It operates on a **"Hybrid v4.0 Architecture"**, leveraging Google Firebase for real-time data persistence and a custom Python Backend for authoritative transaction security (OTP, Binding, Marking).

## 2. Core Identity Standard: "Email-is-ID"
The system is entirely **ID-Agnostic**. To ensure O(1) lookup performance and simplified security rules:
- **Canonical ID:** The full, lowercase official Email ID (e.g., `fac03@mrcet.ac.in`).
- **Primary Key:** The Email address serves as the **Document ID** for `users`, `faculties`, and `attendance_summaries`.
- **Legacy IDs:** Faculty IDs (FAC03) and Student Roll Numbers are strictly relegated to metadata fields.

## 3. Hybrid Architecture Overview

### A. Authentication & Identification (Native SDK)
The app uses the **Firebase Auth SDK** for primary sign-on.
1. User enters Email/Password.
2. SDK returns an Auth Token.
3. App extracts the Email to initialize all downstream data streams.

### B. "Static" Data Layer (Direct Firestore)
Static profile data is fetched directly via DocID:
- **Path:** `faculties/{email}`
- **Contents:** Name, Designation, Branch, and Dept.
- **Benefit:** Sub-100ms retrieval without requiring backend API overhead.

### C. "Dynamic" Data Layer (Reactive Listeners)
Real-time UI updates are driven by Firestore Snapshots:
- **Timetables:** Filtered via `arrayContains` on `faculty_emails`.
- **Live Status:** Monitored via the `sessions` collection where `faculty_email == user_email`.
- **Analytics:** Attendance percentages streamed from `attendance_summaries/{email}`.

### D. "Trigger" Layer (Python API)
Critical transactions requiring state-mutations or external hardware access use the Python Backend:
- **Registration:** 3-Step OTP verification and hardware fingerprint binding.
- **Session Start:** Secure request for the 6-digit OTP displayed on Smart Boards.
- **Attendance Marking:** API calls requiring GPS metadata and hardware signature verification.

## 4. Key Workflows

### 🛡️ Registration & Hardware Binding
1. **Initiate:** App sends Email to Server ➔ Server sends 6-digit PIN to registered Email.
2. **Verify:** User enters PIN ➔ Server validates.
3. **Bind:** App compiles Hardware Snapshot (Brand, Model, Fingerprint, Root-status) ➔ Server binds identity and updates `is_registered: true`.

### ⏱️ Session Initiation
1. Faculty selects a class from their Timetable.
2. App requests an OTP from the Python Server.
3. OTP is displayed on-screen; Faculty enters it on the Smart Board to "Unlock" the class.

### 📍 Manual Attendance Marking
1. Faculty selects a student from the Live List.
2. App captures current **GPS Coordinates** and the **Hardware Signature**.
3. App sends a signed request to the Python API to update the record.

## 5. Clean Code & Engineering Standards
- **Single Source of Truth:** No redundant local flags; the database `is_registered` state is authoritative.
- **Separation of Concerns:** Data fetching is handled by `FacultyService`; Logic/Navigation by `Controllers`.
- **O(1) Retrieval:** No collection-wide scans; direct DocID fetches for primary profiles.
- **Type Safety:** All API and Firestore payloads use strictly-typed `Data Models`.

---
**Version:** 4.1.0-Release 
**Documentation Date:** 2026-03-29
**Primary Maintainer:** IntelliAttend Engineering Group
