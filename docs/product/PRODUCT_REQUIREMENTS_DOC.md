# IntelliAttend: Product Requirements Specification (Professional Edition)

## 1. Vision & Purpose
IntelliAttend is an authoritative **Physical Presence Validation System**. Its goal is to provide undeniable proof of a student's attendance in a classroom by correlating multiple independent sensors and time-sensitive tokens.

---

## 2. Core Principles
1.  **Authority Separation:** The mobile device is a sensor collector; only the Backend Server has the authority to grant attendance.
2.  **Defense-in-Depth:** No single signal (GPS, QR, Wi-Fi) is trusted in isolation. Validation relies on a weighted **Trust Score**.
3.  **No Hardcoding:** All thresholds (geofence radius, RSSI levels) are remotely configurable.

---

## 3. High-Level Workflow
1.  **Launch:** Faculty starts a session on the Faculty App.
2.  **Handshake:** Faculty links the SmartBoard via a 6-digit OTP.
3.  **Gateway:** SmartBoard displays a **Rotating QR Code (Every 5s)**.
4.  **Proof:** Student scans the QR and submits a sensor snapshot (GPS, BSSID, BLE).
5.  **Seal:** Backend validates the proof and calculates the **Trust Score**.
6.  **Update:** SmartBoard Live Dashboard updates in real-time as student attendance is "Sealed".

---

## 4. Functional Requirements

### 4.1 Verification Layers (Multi-Factor Enforcement)
*   **Layer 1 (Time):** QR tokens must include encrypted `issued_at` timestamps. Scan time must be within a 7-second window.
*   **Layer 2 (Location):** GPS coordinates must be within the classroom's geofence (default 30m radius).
*   **Layer 3 (Infrastructure):** Discovered Wi-Fi BSSID must match the classroom's registered Access Point.
*   **Layer 4 (Identity):** Device Hardware Fingerprinting ensures one account per physical device.

### 4.2 The Trust Scoring Model
The backend evaluates the submission and assigns points based on signal strength and accuracy.
*   **Accepted (Green):** Score ≥ 70
*   **Flagged (Amber):** Score 40–69 (Weak signal, Requires manual review)
*   **Rejected (Red):** Score < 40 (Proxy or Location Fraud Detected)

---

## 5. Security & Stability
-   **Play Integrity API:** Prevents execution on rooted or tampered devices.
-   **Real-Time Sync:** WebSockets (Socket.io) provide 100ms latency updates to the Faculty and SmartBoard dashboards.
-   **Audit Immutable Logs:** Every attendance decision is stored with full sensor snapshots for academic auditing.

---
*The IntelliAttend standard: Secure, Scalable, and Unfair to Proxy Users.*