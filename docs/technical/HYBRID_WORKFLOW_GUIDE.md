# 📐 IntelliAttend: Hybrid Architecture & Workflow Guide (v3.2)

This document defines the authoritative boundaries between **Google Firebase** and our **Custom Python Server**. This high-performance "Hybrid" model ensures system integrity, sub-100ms real-time status, and absolute security for academic records.

## 🏛️ System Core Partitioning

| Feature Group | Primary Tech | Primary Responsibility |
| :--- | :--- | :--- |
| **Identity & Auth** | **Firebase SDK** | Persistent Login/Logout via **Full Email ID** only. |
| **Registration** | **Python API** | 3-step authoritative account provisioning & device binding. |
| **Session Control** | **Python API** | OTP Generation & Firestore "Ignition" command. |
| **Attendance Logic** | **Python API** | GPS + Dynamic QR Evaluation (Sensors ignored). |
| **Real-Time Status** | **Firestore** | Direct streaming of "Present/Absent" live status. |
| **Academic Meta** | **Firestore** | Direct reads for Timetables, Profiles, and Percentages. |

---

## 🏗️ Detailed Task Workflows

### 1. Registration (Python Authoritative)
The backend translates the student/faculty **Email ID** into internal system IDs. The mobile app never touches internal IDs.
1.  **Initiate:** User enters Email -> Server sends PIN to email.
2.  **Verify:** User enters PIN -> Server validates verification status.
3.  **Complete:** Server binds Device Fingerprint, creates Firebase User, and enables profile.

### 2. Session Ignition (The OTP Handshake)
1.  **Request:** Faculty app hits `/sessions/start`. Server generates a 6-digit OTP.
2.  **Display:** OTP is shown in the app and entered on the **Native SmartBoard App**.
3.  **Ignite:** SmartBoard verifies OTP with Python Server. Once validated, Server **Ignites** a document in the `active_sessions` collection in Firestore.

### 3. Attendance Evaluation (Transaction Model)
*   **Automatic:** App sends `[GPS Data + Dynamic QR Token + Email]` to Python `/Attendance/mark`.
*   **Manual:** Faculty uses "Manual Override" UI, triggering an administrative API call.
*   **Result:** The Python Server evaluates the "Trust Score" and writes the final "Present" status directly to Firestore.

### 4. Direct Firestore MirrorING
The smartphone apps **bypass the Python server** for all read-only data visualization:
-   **Live Attendance:** Streamed directly from `active_sessions/{id}/attendees`.
-   **Student Profiles:** Fetched directly from `students` collection.
-   **History/Charts:** Calculated from static Firestore snapshots.

---

## 🚨 Critical Constraints
> [!IMPORTANT]
> - **Identity:** The app MUST only use the **Full Email ID** as an identifier.
> - **Sensors:** Wi-Fi BSSID and Bluetooth proximity are **IGNORED** in v3.2.
> - **Authority:** Write operations (Transactions) go to the Python API. Read operations (Visualization) go to Firestore.

---
*Verified for Implementation Alignment (2026).*
