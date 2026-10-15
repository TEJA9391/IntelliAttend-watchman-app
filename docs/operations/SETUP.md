# IntelliAttend - Complete Setup Guide

This guide walks you through setting up the IntelliAttend development environment.

---

## Prerequisites

### Required Software

- **Python:** 3.11 or higher
- **Node.js:** 18.x or higher (for SmartBoard portal)
- **Git:** Latest version
- **Android Studio:** Latest (for mobile apps)
- **Firebase Account:** Google Cloud project with Firestore enabled

### Operating Systems

- macOS 10.15+ (Catalina or later)
- Ubuntu 20.04+ / Debian 11+
- Windows 10/11 with WSL2 (recommended)

---

## Technology Stack

### Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| **FastAPI** | 0.104+ | Web framework |
| **Python** | 3.11+ | Programming language |
| **Firestore** | Latest | NoSQL database (Google Cloud) |
| **Firebase Admin SDK** | Latest | Firebase integration |
| **Uvicorn** | Latest | ASGI server |
| **Pydantic** | 2.x | Data validation |
| **JWT** | Latest | Authentication tokens |

**Architecture:**
- Repository Pattern (Data Access Layer)
- Service Layer (Business Logic)
- RBAC (Role-Based Access Control)
- Async/Await (Non-blocking I/O)

### Mobile Apps

| Technology | Version | Purpose |
|------------|---------|---------|
| **Kotlin** | 1.9+ | Programming language |
| **Android SDK** | API 24+ (Android 7.0+) | Platform |
| **Jetpack Compose** | Latest | UI framework |
| **ML Kit** | Latest | QR code scanning |
| **Retrofit** | 2.9+ | HTTP client |
| **OkHttp** | 4.x | WebSocket support |

### SmartBoard Portal

| Technology | Version | Purpose |
|------------|---------|---------|
| **Vanilla JavaScript** | ES6+ | Programming |
| **HTML5 Canvas** | - | QR rendering |
| **WebSocket API** | - | Real-time updates |
| **CSS3** | - | Styling |

---

## Part 1: Firebase & Firestore Setup

### 1.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Enter project name: `intelliattend-dev` (or your choice)
4. Disable Google Analytics (optional for development)
5. Click "Create Project"

### 1.2 Enable Firestore

1. In Firebase Console → Build → Firestore Database
2. Click "Create Database"
3. Start in **Production Mode**
4. Choose region closest to you (e.g., `us-central1`)
5. Click "Enable"

### 1.3 Download Service Account Key

1. Project Settings (gear icon) → Service Accounts
2. Click "Generate New Private Key"
3. Save file as `serviceAccountKey.json`
4. **IMPORTANT:** Keep this file secure, never commit to Git

### 1.4 Create Firestore Indexes

Run this script after backend setup:

```bash
cd backend
python scripts/create_firestore_indexes.py
```

**Or create manually in Firebase Console → Firestore → Indexes:**

Required composite indexes:
- `users`: `email` (ASC) + `role` (ASC)
- `student_attendance`: `student_id` (ASC) + `session_id` (ASC)
- `student_attendance`: `session_id` (ASC) + `marked_at` (DESC)
- `sessions`: `faculty_id` (ASC) + `status` (ASC)

---

## Part 2: Backend Setup

### 2.1 Clone Repository

```bash
git clone <repository-url>
cd IntelliAttend/backend
```

### 2.2 Create Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
```

### 2.3 Install Dependencies

```bash
pip install -r requirements.txt
```

### 2.4 Configure Environment

```bash
# Copy environment template
cp .env.example .env
```

Edit `.env` file:

```bash
# Firebase Configuration
FIREBASE_PROJECT_ID=intelliattend-dev
GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json

# JWT Configuration
JWT_SECRET=your-secret-key-min-32-characters-long
JWT_ALGORITHM=HS256
JWT_EXPIRES_IN=3600
JWT_REFRESH_EXPIRES_IN=604800

# Server Configuration
DEBUG=true
HOST=0.0.0.0
PORT=8000

# Trust Score Thresholds
TRUST_SCORE_ACCEPT=70
TRUST_SCORE_FLAG=50

# GPS Configuration
GPS_GEOFENCE_RADIUS_METERS=50
GPS_MAX_ACCURACY_METERS=20

# WiFi Configuration
WIFI_RSSI_MIN_DBM=-75

# Bluetooth Configuration
BLE_RSSI_THRESHOLD=-70
```

### 2.5 Place Service Account Key

Copy `serviceAccountKey.json` to `/backend` directory:

```bash
# Structure should be:
backend/
├── serviceAccountKey.json  ← HERE
├── main.py
├── requirements.txt
└── .env
```

### 2.6 Run Backend Server

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Verify:**
- Server: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Health Check: http://localhost:8000/healthz

---

## Part 3: SmartBoard Portal Setup

### 3.1 Navigate to Portal

```bash
cd ../smartboard-portal
```

### 3.2 Install Dependencies

```bash
npm install
```

### 3.3 Configure Backend URL

Edit `js/config.js`:

```javascript
const API_BASE_URL = "http://localhost:8000";
const WS_URL = "ws://localhost:8000/ws";
```

### 3.4 Run Development Server

```bash
npm run dev
```

Portal runs at: http://localhost:5173

---

## Part 4: Mobile Apps Setup

### 4.1 Install Android Studio

1. Download from [developer.android.com](https://developer.android.com/studio)
2. Install with default settings
3. Open Android Studio → SDK Manager
4. Install Android SDK API 24-34

### 4.2 Student App

```bash
cd ../mobile-student
```

**Configure API endpoint:**

Edit `app/src/main/java/com/intelliattend/student/data/api/ApiConfig.kt`:

```kotlin
object ApiConfig {
    const val BASE_URL = "http://10.0.2.2:8000/"  // Android emulator
    // const val BASE_URL = "http://YOUR_IP:8000/"  // Physical device
}
```

**Run:**

```bash
# Open in Android Studio
# OR via command line:
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 4.3 Faculty App

```bash
cd ../mobile-faculty
```

Same configuration process as student app.

---

## Part 5: Database Seeding (Optional)

### 5.1 Seed Demo Data

```bash
cd backend
python scripts/seed_firestore.py
```

This creates:
- Demo users (faculty, students, admin)
- Sample sections and courses
- Test classrooms with infrastructure

### 5.2 Demo Accounts

**Faculty:**
- Email: `faculty@mrcet.ac.in`
- Password: `demo123`

**Student:**
- Roll: `23N31A6645`
- Password: `demo123`

**Admin:**
- Email: `admin@mrcet.ac.in`
- Password: `admin123`

---

## Part 6: Verification

### 6.1 Backend Health Check

```bash
curl http://localhost:8000/healthz
```

Expected response: `{"status": "healthy"}`

### 6.2 Test Authentication

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "faculty@mrcet.ac.in", "password": "demo123"}'
```

Should return JWT token.

### 6.3 Check Firestore Connection

```bash
cd backend
python -c "from app.core.firebase import db; print('✅ Firestore Connected' if db else '❌ Failed')"
```

---

## Troubleshooting

### Backend Issues

**Problem:** `ModuleNotFoundError: No module named 'app'`

**Solution:**
```bash
# Ensure you're in /backend directory
cd backend
# Activate virtual environment
source venv/bin/activate
```

---

**Problem:** `Failed to initialize Firebase`

**Solution:**
1. Check `serviceAccountKey.json` exists in `/backend`
2. Verify `FIREBASE_PROJECT_ID` matches your Firebase project
3. Ensure service account has Firestore permissions

---

**Problem:** "Missing index" error in logs

**Solution:**
```bash
python scripts/create_firestore_indexes.py
# OR create manually via Firebase Console
```

---

**Problem:** `JWT_SECRET` error

**Solution:**
Generate a secure secret:
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```
Add to `.env` file.

---

### Mobile App Issues

**Problem:** Network error / Cannot connect to backend

**Solution:**
- **Emulator:** Use `http://10.0.2.2:8000`
- **Physical Device:** Use your computer's IP (e.g., `http://192.168.1.100:8000`)
- Ensure backend is running
- Check firewall settings

---

**Problem:** Build failed - KAPT errors

**Solution:**
```bash
# In Android Studio → File → Invalidate Caches
# OR
./gradlew clean build
```

---

### SmartBoard Issues

**Problem:** WebSocket connection failed

**Solution:**
- Check backend WebSocket endpoint: `ws://localhost:8000/ws/smartboard/{session_id}`
- Verify CORS settings in backend
- Check browser console for errors

---

## Development Workflow

### 1. Start Backend

```bash
cd backend
source venv/bin/activate
uvicorn main:app --reload
```

### 2. Start SmartBoard (if needed)

```bash
cd smartboard-portal
npm run dev
```

### 3. Run Mobile App

Open Android Studio → Run → Select device/emulator

---

## Production Deployment

See separate deployment guide: `/docs/DEPLOYMENT.md`

Key considerations:
- Use production Firebase project
- Set `DEBUG=false`
- Enable HTTPS/TLS
- Configure proper CORS
- Set up monitoring & logging

---

## Additional Resources

- **Database Schemas:** [DATABASE.md](DATABASE.md)
- **API Documentation:** http://localhost:8000/docs (when running)
- **Architecture Review:** [CODE_ARCHITECTURE_REVIEW.md](CODE_ARCHITECTURE_REVIEW.md)
- **Backend README:** [../backend/README.md](../backend/README.md)

---

## Getting Help

1. Check [DATABASE.md](DATABASE.md) for Firestore questions
2. Review [CODE_ARCHITECTURE_REVIEW.md](CODE_ARCHITECTURE_REVIEW.md) for architecture
3. See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines
4. Open GitHub issue for bugs

---

**Last Updated:** January 2026  
**Version:** 2.0 (Production Hardened)
