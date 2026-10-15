# 📖 IntelliAttend: Central Documentation Hub

Welcome to the official documentation for **IntelliAttend**, a multi-factor physical presence validation system.

## 🎯 Quick Navigation

| Goal | Reference Document |
| :--- | :--- |
| **Understand the Vision** | [Project Overview](technical/PROJECT_OVERVIEW.md) |
| **Hybrid Authority Workflow** | [Hybrid Workflow Guide](technical/HYBRID_WORKFLOW_GUIDE.md) |
| **Product Specifications** | [Product Requirements (PRD)](product/PRODUCT_REQUIREMENTS_DOC.md) |
| **Development Setup** | [Mobile App Requirements](product/MOBILE_APP_REQUIREMENTS.md) |
| **User Experience Flow** | [System User Journey](product/SYSTEM_USER_JOURNEY.md) |
| **Faculty App Details** | [Faculty App README](../IntelliAttend-Faculty/README.md) |

---

## 🛠️ System Architecture Summary

The IntelliAttend ecosystem is built on a **Hybrid Trust Model**:
-   **Frontend (Flutter):** Collects sensor snapshots (QR, GPS, Wi-Fi, BLE).
-   **Backend (FastAPI):** Acts as the authoritative decision-maker using a weighted **Trust Score**.
-   **Real-time Layer (Firestore):** Powers the live dashboard updates for Faculty and SmartBoards.

### Components
1.  **Faculty Mobile Hub:** Launch sessions and monitor live attendance.
2.  **Student Mobile Hub:** Scans rotating QRs and submits proof of presence.
3.  **SmartBoard Portal:** Displays the dynamic, rotating QR codes (Gateway).
4.  **Admin Portal:** Manage campus infrastructure and user roles.

---

## 📊 Project Status
-   **Refactoring:** Phase 3 (Reports Module) Complete.
-   **Health:** 100% Clean Flutter Analysis.
-   **Infrastructure:** Fully migrated to Firebase Firestore & Auth.

---
*For technical deep dives, refer to the [Technical Docs](technical/) directory.*
