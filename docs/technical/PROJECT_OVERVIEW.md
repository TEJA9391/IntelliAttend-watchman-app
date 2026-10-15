# IntelliAttend: Project Overview 🚀

**IntelliAttend** is a production-grade, multi-factor attendance management system. Its mission is to eliminate proxy attendance and automate classroom tracking through verifiable physical presence.

## 🧐 The Core Problem
Traditional attendance systems are easily bypassed:
*   **Proxy Attendance:** Friends marking for each other.
*   **Remote Scans:** Students scanning QR codes from photos or group chats.
*   **Administrative Drain:** Faculty losing 10-15 minutes per lecture on manual roll calls.

## 💡 The Solution: Multi-Factor Trust Engine
IntelliAttend does not rely on a single signal. It calculates a **Trust Score** based on four layers of physical evidence:

1.  **Dynamic Tokens (Time-Sensitive):**
    *   The SmartBoard displays a QR code that rotates every **5 seconds**.
    *   Photos/screenshots are rendered useless almost instantly.
2.  **Geofencing (Location-Based):**
    *   GPS validation ensures the student device is within the physical boundaries of the classroom.
3.  **Proximity Auditing (Infrastructure-Based):**
    *   Checks for the presence of specific classroom Wi-Fi APs (BSSID) and Bluetooth (BLE) beacons.
4.  **Hardware Binding (Identity-Based):**
    *   Accounts are locked to a single device (Hardware Fingerprint) to prevent login sharing.

---

## 🏗️ System Architecture

The ecosystem consists of four integrated components:

### 1. Faculty Mobile Hub (Flutter)
The command center for the class. Faculty use this to launch sessions, link SmartBoards, and monitor student entries live on their dashboard.

### 2. Student Mobile Hub (Flutter)
The verification tool. It scans the rotating QR and securely submits location and sensor snapshots for authoritative validation.

### 3. SmartBoard Portal (Web)
A lightweight frontend displayed on the projector that serves as the visual gateway for the rotating verification stream.

### 4. Backend Trust Authority (FastAPI & Firestore)
The central "brain" that receives raw sensor data, calculates the trust score, and officially seals the attendance record.

---

## 🛠️ Technology Stack Summary

| Layer | Technology |
| :--- | :--- |
| **Mobile** | Flutter (Dart), BouncingScroll UI, Modern Auth |
| **Backend** | Python (FastAPI), Pydantic, Uvicorn |
| **Database** | Google Cloud Firestore (Real-Time NoSQL) |
| **Dashboard** | Vanilla JS / WebSockets |
| **Identity** | Firebase Auth + Device Attestation |

---
*IntelliAttend verifies the human, not just the device.*
