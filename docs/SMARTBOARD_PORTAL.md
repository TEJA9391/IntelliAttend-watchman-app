# 🖥️ SmartBoard Portal Documentation

The SmartBoard Portal is a web-based interface designed to be displayed on classroom "smart boards". It provides a real-time visualization of attendance sessions, displaying dynamic QR codes for students to scan and a live seating grid showing attendance status.

## 🏗️ Technical Architecture

### Tech Stack
- **Core**: Vanilla JavaScript (ES6+)
- **Styling**: Vanilla CSS3
- **QR Generation**: HTML5 Canvas (via `qr_handler.js`)
- **Real-time Communication**: WebSockets (`websocket-client.js`)
- **State Management**: Simple global `window.appState`

### Key Components

- **Main Dashboard (`index.html`)**: The primary interface containing the connectivity indicators, faculty banner, seating grid, and QR display section.
- **QR Handler (`js/modules/qr_handler.js`)**: Manages the rendering of dynamic QR codes on the HTML5 canvas. It supports branding overlays (the central logo) and handled rotation cycles.
- **WebSocket Client (`js/modules/websocket-client.js`)**: Maintains a persistent connection with the FastAPI backend to receive real-time QR token updates and attendance status changes.
- **Seating Grid (`js/dashboard.js`)**: A "BookMyShow" style visual representation of the classroom. It dynamically renders seats and updates their color/status based on live data.
- **OTP Entry (`js/main.js` & `otp-screen`)**: A security layer requiring a session code (OTP) to link the SmartBoard to a specific faculty session.

## 🚀 Setup & Installation

### Prerequisites
- Node.js installed (for serving the files)
- A running IntelliAttend Backend

### Running Locally
1. Navigate to the portal directory:
   ```bash
   cd smartboard-portal
   ```
2. Start a local server:
   ```bash
   npx http-server -p 3000 -c-1
   ```
   *Alternatively, use the built-in Vite-like setup if available:*
   ```bash
   npm run dev
   ```
3. Open `http://localhost:3000` in a web browser (Chrome recommended for Fullscreen support).

## 🔄 Core Workflows

### 1. Linking a Session
- The SmartBoard starts on the **OTP Screen**.
- The faculty provides the **Session Code** from their app.
- Upon successful verification via `/api/v1/sessions/verify-otp`, the portal switches to the **Dashboard Screen**.

### 2. Live QR Rotation
- Once the session starts, the backend pushes a new QR token via WebSocket every 5 seconds.
- `websocket-client.js` receives the token and calls `renderQRCode()` in `qr_handler.js`.
- The QR code is rendered on `<canvas id="qr-canvas">`.

### 3. Real-time Attendance
- As students scan the QR code and pass multi-factor validation, the backend pushes attendance updates.
- The `updateDashboard()` function in `dashboard.js` updates the seating grid:
    - 🔴 **Absent**: Initial state.
    - 🟡 **Pending**: Validation in progress.
    - 🟢 **Present**: Successfully verified.
    - ⚫ **Failed**: Validation failed.

## 📡 API & WebSocket Integration

### REST Endpoints Used
- `POST /api/v1/sessions/verify-otp`: Validates the session code and returns a `session_id`.

### WebSocket Events
- **QR Update**: `{ "type": "qr_update", "token": "..." }`
- **Attendance Update**: `{ "type": "attendance_update", "students": [...] }`

## 🎨 UI/UX Features
- **Connectivity Indicators**: Real-time status icons for Wi-Fi, BLE, and Server connection.
- **Fullscreen Mode**: Prompted automatically if the viewport size is too small for optimal QR scanning.
- **Rotation Info**: A countdown timer showing when the next QR rotation will occur.
- **Visual Feedback**: Micro-animations and color-coded statuses for intuitive monitoring.
