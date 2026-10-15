# Mobile App Requirements & Professional Standards

This document defines the requirements for the **IntelliAttend** mobile applications (Faculty and Student) in their modern Flutter-based implementation.

## 📱 Platform Overview
-   **Framework:** Flutter (Stable)
-   **Architecture:** Modular Controller Pattern
-   **State Management:** Provider / ValueNotifiers
-   **Design Language:** Premium Material 3 / Glassmorphism

---

## 🛠️ Development Requirements
To build and deploy the IntelliAttend ecosystem:

1.  **Flutter SDK:** Version 3.19+ (Stable Channel).
2.  **Android Studio:** Version 2023.3+ (Iguana/Jellyfish).
3.  **Xcode:** Required for iOS target builds (macOS only).
4.  **Hardware:** 
    *   **Android:** Minimum SDK 26 (Android 8.0), Target SDK 34 (Android 14).
    *   **iOS:** Minimum iOS 13.0.

---

## 🔐 Hardware & Sensor Requirements (Critical)
The application **MUST** have access to these sensors to perform physical presence validation. Emulators are **NOT** suitable for testing these features.

| Sensor / API | Purpose |
| :--- | :--- |
| **Camera** | High-speed QR scanning via ML Kit. |
| **GPS (Fine Location)** | Geofence validation (Classroom accuracy). |
| **Wi-Fi / Network** | BSSID identification (Infrastructure proximity). |
| **Bluetooth LE** | Faculty-to-Student handshake (Local auditing). |
| **Biometrics** | Fingerprint/FaceID for secure scanner activation. |

---

## 📦 Key Packages & Dependencies

### Core UI & UX
*   **Syncfusion Charts:** For Faculty analytics and attendance trends.
*   **Google Fonts:** Inter / Roboto for a premium look.
*   **Custom Animations:** Lottie and standard Flutter Tween animations.

### Data & Connectivity
*   **Firebase Core/Auth/Firestore:** Real-time data backbone.
*   **Provider:** For reactive state management.
*   **Shared Preferences:** For secure JSON-based session persistence.

---

## 🚀 Setup & Build Checklist

### 1. Firebase Secret Provisioning
The project requires a `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) placed in their respective platform directories. Without these, Cloud sync will fail.

### 2. API Context
All networking is routed through the `ApiClient`:
-   **Dev:** `https://api-dev.balaseetharamanjaneyulu.com`
-   **Production:** `https://api.intelliattend.app`

### 3. Device Attestation
To prevent fake attendance from rooted phones:
*   **Play Integrity (Android):** Verifies device health.
*   **App Attest (iOS):** Ensures genuine binary execution.

---
*Failure to grant location or network permissions will result in a Trust Score below the acceptance threshold.*
