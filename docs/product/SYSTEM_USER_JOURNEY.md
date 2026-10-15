# 📖 The IntelliAttend Journey: From Classroom to Cloud

The story of how **IntelliAttend** transforms a standard lecture into a high-security, verified ecosystem.

## 🎭 The Cast
1.  **The Faculty:** Uses the Faculty App to orchestrate the session.
2.  **The SmartBoard:** The visual gateway displaying dynamic security tokens.
3.  **The Student:** Uses the Student App to prove they are physically present.
4.  **The Custom Server:** The authoritative decision-maker for sensitive actions.

---

## 🛠️ The Process

### ⚡ Phase 1: The Spark (Session Start)
The Instructor opens the **Faculty App**, selects their subject, and places their **Fingerprint**.
-   **The Authority Call:** The app sends a request to the **Custom Python Server** to initiate the session.
-   **The Secret Key:** The server generates a unique **OTP (One-Time Password)**.

### 🤝 Phase 2: The Handshake (SmartBoard Link)
The server pushes the OTP to the classroom **SmartBoard**. 
-   The Instructor confirms the link by verifying the OTP on the SmartBoard interface.
-   **Validation:** The room is now officially "live" and bound to the session.

### 🌀 Phase 3: The Pulsing Gateway (Dynamic QR)
A custom-branded QR code appears on the SmartBoard.
-   Every **5 seconds**, the token rotates.
-   **Real-time Power:** This stream is managed via direct integration with **Firebase**, ensuring zero lag.

### 🔍 Phase 4: The Proof (Student Scan)
Students scan the QR. Their app collects:
-   📍 GPS / 📶 Wi-Fi / 🔵 Bluetooth
-   This "Proof of Presence" packet is sent to the **Custom Server** for a trust decision.

### 🏆 Phase 5: The Seal (Authoritative Decision)
The **Custom Server** calculates the trust score.
-   If valid, it writes the "Present" status directly into **Google Firebase**.
-   **Observation:** The Faculty Dashboard and SmartBoard update **instantly** because they are listening directly to the database.

---
*IntelliAttend: Authoritative control meeting real-time speed.*
