# IntelliAttend Technical Protocol (v3.2)
## Authoritative Communication & Workflow Breakdown

This document provides a step-by-step breakdown of the two most critical "Hybrid" operations: **User Registration** and **Manual Attendance Marking**.

---

## 🏗️ 1. Registration: The 3-Step Identity Handshake
Registration is strictly governed by the **Custom Python Backend** to ensure high-integrity device binding.

### Step 1: Initiation (Verification Request)
1.  **Mobile App:** Faculty enters their official **Email ID**.
2.  **Communication:** `POST /api/v1/auth/register/initiate`
    *   **Payload:** `{ "email": "faculty@university.com" }`
3.  **Server Action:** Validates the email against university records and sends a **6-digit PIN** to that email.

### Step 2: Verification (Self-Correction)
1.  **Mobile App:** Faculty enters the PIN received in their email.
2.  **Communication:** `POST /api/v1/auth/register/verify`
    *   **Payload:** `{ "email": "...", "otp": "123456" }`
3.  **Server Action:** Verifies the OTP and unlocks the final "Completion" phase for this specific email.

### Step 3: Completion & Hardware Binding
1.  **Mobile App:** Faculty sets a password. The app captures a **Hardware Snapshot** via the `HardwareService` (Fingerprint, Device ID, Root Status).
2.  **Communication:** `POST /api/v1/auth/register/complete`
    *   **Payload:** `{ "email": "...", "password": "...", "device_info": { "fingerprint": "...", "id": "...", "is_rooted": false } }`
3.  **Server Action:** 
    *   Binds the hardware fingerprint to the user record (for future 4-factor trust scoring).
    *   Creates a corresponding **Firebase Auth** account.
    *   Pushes the faculty profile to **Firestore**.

---

## 📝 2. Manual Attendance: The Administrative Override
Manual marking is used when students lack devices or face connectivity issues. It is a "Command" operation requiring authoritative evaluation.

### Step 1: Information Gathering
1.  **Mobile App:** Faculty navigates to "Manual Override" in the Live Monitor and selects a student name (linked to their **Email ID**).
2.  **Hardware Action:** The app captures the **Current GPS Coordinates** (Latitude/Longitude) of the faculty's device to ensure they are physically in the classroom.

### Step 2: Policy Evaluation (App -> Python API)
1.  **Mobile App:** Sends the manual marking command.
2.  **Communication:** `POST /api/v1/Attendance/mark`
    *   **Payload:** 
        ```json
        {
          "email": "student@university.com",
          "session_id": "active_session_123",
          "latitude": 12.9716,
          "longitude": 77.5946,
          "device_info": { "faculty_fingerprint": "..." }
        }
        ```
3.  **Server Action:**
    *   Validates the **Faculty Authority** (Are they the owner of this session?).
    *   Verifies **GPS Proximity** (Is the faculty within the room's geofence?).
    *   Marks the student as "Present" in the **Internal SQL Database**.
    *   **Writes the Change to Firestore:** Updates `active_sessions/{session_id}/attendees/{email}` status to `present`.

### Step 3: Real-Time Mirror Update (Firestore -> App UI)
1.  **Mobile App:** Does NOT wait for a refresh. Because the `LiveMonitorScreen` has a **Real-Time Listener** on Firestore, it detects the server's write instantly.
2.  **Result:** The student's tile in the app turns **Green** locally within sub-100ms.

---

## 🚨 Critical Summary of Roles
*   **Transactions (Writes):** Always go through the **Python Server** via `ApiClient`. This is where logic, GPS evaluation, and hardware audits happen.
*   **Visualizations (Reads):** Always come directly from **Google Firestore**. This ensures the UI is "Always Live" without putting load on the Python backend.
