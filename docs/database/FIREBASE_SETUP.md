# Firebase Firestore Setup Guide

## 🔥 Quick Setup

IntelliAttend uses **Firebase Firestore** as its sole database. No traditional SQL database setup required!

---

## 📋 Prerequisites

- Google/Gmail account
- Firebase project (free tier is sufficient for development)

---

## 🚀 Step-by-Step Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Add project"**
3. Enter project name: `intelliattend` (or your preferred name)
4. Accept terms and click **"Continue"**
5. Disable Google Analytics (optional for development)
6. Click **"Create project"**

### 2. Enable Firestore Database

1. In Firebase Console, navigate to **"Firestore Database"** (left sidebar)
2. Click **"Create database"**
3. Select **"Start in production mode"** (we'll configure rules later)
4. Choose your database location (closest to your region)
5. Click **"Enable"**

### 3. Generate Service Account Key

1. Go to **Project Settings** ⚙️ (top left, next to "Project Overview")
2. Navigate to **"Service accounts"** tab
3. Click **"Generate new private key"**
4. Click **"Generate key"** (JSON file will download)
5. **Important**: Keep this file secure! It provides admin access.

### 4. Configure Backend

1. **Rename** the downloaded key to `serviceAccountKey.json`
2. **Move** it to your backend directory:
   ```bash
   mv ~/Downloads/intelliattend-*.json /path/to/IntelliAttend/backend/serviceAccountKey.json
   ```

3. **Set environment variable** in `backend/.env`:
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json
   FIREBASE_PROJECT_ID=your-project-id  # From Firebase Console
   ```

### 5. Verify Setup

```bash
cd backend
python -c "from app.core.firebase import initialize_firebase; initialize_firebase()"
```

Expected output:
```
Firebase Admin SDK initialized successfully
```

---

## 📊 Seed Database with Sample Data

```bash
cd backend

# Seed complete database (users, timetables, etc.)
python scripts/seed_complete_database.py

# Or seed specific data:
python scripts/seed_user_data.py          # Users only
python scripts/seed_timetable_data.py     # Timetables only
python scripts/seed_mrcet_data.py         # MRCET-specific data
```

---

## 🔐 Configure Firestore Security Rules

1. In Firebase Console, go to **Firestore Database**
2. Click **"Rules"** tab
3. Replace with production-ready rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - authenticated users can read their own data
    match /Users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Active Sessions - students can read during active sessions
    match /ActiveSessions/{sessionId} {
      allow read: if request.auth != null;
      allow write: if false; // Only backend can write
    }
    
    // Attendance - students can create, backend validates
    match /Attendance/{recordId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if false;
    }
    
    // Other collections - backend only
    match /{document=**} {
      allow read, write: if false; // Deny all, backend uses Admin SDK
    }
  }
}
```

4. Click **"Publish"**

---

## 📱 Mobile App Configuration

### Android (Firebase Config)

1. In Firebase Console, click **"Add app"** → **Android**
2. Enter package name: `com.intelliattend.app`
3. Download `google-services.json`
4. Place in: `mobile-app/app/google-services.json`
5. The build system will handle the rest!

---

## ✅ Verification Checklist

- [ ] Firebase project created
- [ ] Firestore database enabled
- [ ] Service account key downloaded and placed
- [ ] Environment variables configured
- [ ] Backend can connect to Firestore
- [ ] Database seeded with sample data
- [ ] Security rules configured
- [ ] Mobile app `google-services.json` added

---

## 🔍 Testing Connection

### Backend Test
```bash
cd backend
python -m pytest tests/unit/test_firebase_auth.py -v
```

### Check Firestore Console
1. Go to Firestore Database in Firebase Console
2. You should see collections: `Users`, `ActiveSessions`, `Attendance`, etc.
3. Browse documents to verify seeded data

---

## 🆘 Troubleshooting

### "Firebase not initialized"
**Solution**: Verify `GOOGLE_APPLICATION_CREDENTIALS` path is correct

### "Permission denied"
**Solution**: Regenerate service account key with proper permissions

### "Collection not found"
**Solution**: Run seed scripts to populate database

### Mobile app connection issues
**Solution**: Verify `google-services.json` package name matches your app

---

## 📚 Resources

- [Firebase Documentation](https://firebase.google.com/docs/firestore)
- [Python Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Android SDK Setup](https://firebase.google.com/docs/android/setup)
- [Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)

---

## 💡 Tips

- Free tier includes 50K reads + 20K writes per day
- Firestore has built-in offline support
- Use indexes for complex queries (auto-created on first query)
- Monitor usage in Firebase Console → Usage tab

---

**Setup Time**: ~10 minutes  
**Cost**: $0 (free tier for development)  
**Scalability**: Auto-scaling to millions of operations
