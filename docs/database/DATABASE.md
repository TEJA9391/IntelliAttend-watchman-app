# Database Documentation - Firestore

## Overview

IntelliAttend uses **Google Cloud Firestore** (NoSQL) as its primary database. This document covers all collections, schemas, indexes, and data access patterns.

---

## Technology Stack

- **Database:** Google Cloud Firestore (NoSQL Document Database)
- **SDK:** `firebase-admin` (Python)
- **Client:** `google.cloud.firestore.AsyncClient` (async/await)
- **Data Access:** Repository Pattern (see `/backend/app/repositories/`)

---

## Collections

### 1. `users`

**Purpose:** Stores all user accounts (students, faculty, admins)

**Document ID:** Email address or auto-generated ID

**Schema:**
```json
{
  "id": "string (document ID)",
  "email": "string (unique)",
  "name": "string",
  "role": "student | faculty | admin",
  "password_hash": "string (pbkdf2_sha256)",
  "phone_number": "string (optional)",
  "created_at": "timestamp",
  "updated_at": "timestamp"
}
```

**Indexes:**
- Single field: `email` (ASC)
- Single field: `role` (ASC)
- Composite: `email` (ASC) + `role` (ASC)

**Access Patterns:**
- Get user by email and role
- Get user by ID
- Authentication queries

---

### 2. `students`

**Purpose:** Extended student information

**Document ID:** Student roll number (e.g., "23N31A6645")

**Schema:**
```json
{
  "roll_number": "string (document ID)",
  "email": "string",
  "name": "string",
  "section_id": "string (reference to sections)",
  "class_id": "string",
  "department": "string",
  "year": "number",
  "phone_number": "string",
  "emergency_contact": {
    "name": "string",
    "phone": "string",
    "relationship": "string"
  },
  "created_at": "timestamp",
  "status": "active | suspended | graduated"
}
```

**Indexes:**
- Single field: `email` (ASC)
- Single field: `section_id` (ASC)
- Composite: `section_id` (ASC) + `status` (ASC)

**Access Patterns:**
- Get student by roll number
- Get students by section
- Resolve roll number to email

---

### 3. `sessions`

**Purpose:** Attendance session records

**Document ID:** Auto-generated

**Schema:**
```json
{
  "id": "string (auto-generated)",
  "faculty_id": "string",
  "faculty_name": "string",
  "course_id": "string",
  "course_name": "string",
  "section_id": "string",
  "class_id": "string",
  "room_id": "string (reference to rooms)",
  "slot_id": "string (optional)",
  "status": "active | ended | cancelled",
  "created_at": "timestamp",
  "started_at": "timestamp",
  "ended_at": "timestamp (nullable)",
  "expected_location": {
    "latitude": "number",
    "longitude": "number",
    "radius_meters": "number"
  },
  "calibration_mode": "boolean",
  "total_students_present": "number",
  "total_students_enrolled": "number"
}
```

**Indexes:**
- Single field: `faculty_id` (ASC) + `created_at` (DESC)
- Single field: `section_id` (ASC) + `created_at` (DESC)
- Single field: `status` (ASC) + `created_at` (DESC)
- Composite: `faculty_id` (ASC) + `status` (ASC)

**Access Patterns:**
- Get active sessions by faculty
- Get sessions by section
- Historical session queries

---

### 4. `ActiveSessions`

**Purpose:** Real-time active sessions with QR tokens

**Document ID:** Session ID (matches `sessions` collection)

**Schema:**
```json
{
  "session_id": "string (document ID)",
  "faculty_id": "string",
  "room_id": "string",
  "current_token": {
    "token": "string (IATT::base64::signature)",
    "generated_at": "timestamp",
    "expires_at": "timestamp",
    "sequence": "number"
  },
  "status": "active | expired",
  "created_at": "timestamp",
  "last_rotation_at": "timestamp",
  "rotation_count": "number"
}
```

**Indexes:**
- Single field: `faculty_id` (ASC)
- Single field: `status` (ASC)

**Access Patterns:**
- Get active session by ID
- Get all active sessions (for scheduler)
- Token rotation queries

---

### 5. `student_attendance`

**Purpose:** Individual attendance records

**Document ID:** Auto-generated

**Schema:**
```json
{
  "id": "string (auto-generated)",
  "student_id": "string",
  "session_id": "string (reference to sessions)",
  "status": "present | suspicious | rejected",
  "trust_score": "number (0-100)",
  "trust_breakdown": {
    "qr": "number",
    "gps": "number",
    "wifi": "number",
    "ble": "number",
    "gps_distance": "number (meters)"
  },
  "trust_flags": ["string array (e.g., LOW_GPS_ACCURACY)"],
  "marked_at": "timestamp",
  "location_metadata": {
    "gps": {
      "latitude": "number",
      "longitude": "number",
      "accuracy": "number"
    },
    "wifi_bssid": "string",
    "bluetooth_beacons": ["array of beacon UUIDs"]
  }
}
```

**Indexes:**
- Composite: `student_id` (ASC) + `session_id` (ASC) [UNIQUE]
- Composite: `session_id` (ASC) + `marked_at` (DESC)
- Composite: `student_id` (ASC) + `marked_at` (DESC)
- Single field: `status` (ASC)

**Access Patterns:**
- Check duplicate attendance
- Get session attendance list
- Get student attendance history

---

### 6. `device_bindings`

**Purpose:** Student device registration (BYOD security)

**Document ID:** Student ID

**Schema:**
```json
{
  "student_id": "string (document ID)",
  "device_fingerprint_hash": "string (SHA-256)",
  "device_info": {
    "manufacturer": "string",
    "model": "string",
    "os_version": "string",
    "app_version": "string"
  },
  "registered_at": "timestamp",
  "status": "active | pending_approval | suspended",
  "pending_device_hash": "string (nullable)",
  "change_requested_at": "timestamp (nullable)"
}
```

**Indexes:**
- Single field: `status` (ASC)

**Access Patterns:**
- Get device binding by student ID
- Verify device fingerprint
- List pending device changes

---

### 7. `rooms`

**Purpose:** Classroom/location information

**Document ID:** Room identifier (e.g., "CI-BLOCK-301")

**Schema:**
```json
{
  "room_id": "string (document ID)",
  "name": "string",
  "building": "string",
  "floor": "number",
  "capacity": "number",
  "location": {
    "latitude": "number",
    "longitude": "number",
    "campus_id": "string"
  },
  "infrastructure": {
    "wifi_bssids": ["array of registered BSSIDs"],
    "bluetooth_beacons": ["array of beacon UUIDs"]
  },
  "status": "active | maintenance | disabled"
}
```

**Indexes:**
- Single field: `building` (ASC)
- Single field: `status` (ASC)

---

### 8. `security_audit_log`

**Purpose:** Security events and audit trail

**Document ID:** Auto-generated

**Schema:**
```json
{
  "event_type": "string (e.g., DEVICE_MISMATCH, SUSPICIOUS_ATTENDANCE)",
  "student_id": "string",
  "session_id": "string (optional)",
  "severity": "INFO | WARNING | CRITICAL",
  "metadata": {
    "any": "additional context"
  },
  "timestamp": "timestamp",
  "ip_address": "string (optional)"
}
```

**Indexes:**
- Composite: `student_id` (ASC) + `timestamp` (DESC)
- Composite: `severity` (ASC) + `timestamp` (DESC)
- Single field: `event_type` (ASC) + `timestamp` (DESC)

---

## Required Composite Indexes

### Critical Indexes (Manual Creation Required)

Firebase automatically creates single-field indexes, but composite indexes must be created manually:

```bash
# 1. users: email + role
gcloud firestore indexes composite create \
  --collection-group=users \
  --field-config field-path=email,order=ascending \
  --field-config field-path=role,order=ascending

# 2. student_attendance: student_id + session_id (UNIQUE)
gcloud firestore indexes composite create \
  --collection-group=student_attendance \
  --field-config field-path=student_id,order=ascending \
  --field-config field-path=session_id,order=ascending

# 3. student_attendance: session_id + marked_at
gcloud firestore indexes composite create \
  --collection-group=student_attendance \
  --field-config field-path=session_id,order=ascending \
  --field-config field-path=marked_at,order=descending

# 4. sessions: faculty_id + status
gcloud firestore indexes composite create \
  --collection-group=sessions \
  --field-config field-path=faculty_id,order=ascending \
  --field-config field-path=status,order=ascending
```

**Alternative:** Create via Firebase Console → Firestore → Indexes tab

---

## Data Access Pattern

### Repository Layer

All database access goes through repository classes (never direct Firestore calls in services):

```python
# ❌ BAD: Direct Firestore in services
db = firestore.client()
doc = db.collection('users').document(user_id).get()

# ✅ GOOD: Repository pattern
user_repo = UserRepository()
user = await user_repo.get_by_id(user_id)
```

**Repository Classes:**
- `BaseRepository` - Generic CRUD operations
- `UserRepository` - User queries
- `StudentRepository` - Student queries
- `SessionRepository` - Session management
- `AttendanceRepository` - Attendance records
- `DeviceRepository` - Device bindings

See `/backend/app/repositories/` for implementations.

---

## Data Retention Policies

| Collection | Retention | Notes |
|------------|-----------|-------|
| `users` | Indefinite | Archived on graduation |
| `students` | Indefinite | Marked as graduated |
| `sessions` | 2 years | Historical analysis |
| `student_attendance` | 2 years | Compliance requirement |
| `security_audit_log` | 1 year | Security compliance |
| `ActiveSessions` | Auto-cleanup | Expired after 24 hours |

---

## Migration from PostgreSQL

**Previous:** PostgreSQL with SQLAlchemy + Alembic  
**Current:** Firestore with AsyncClient + Repository Pattern

**Breaking Changes:**
- No SQL queries - use Firestore queries
- No joins - denormalize data
- No transactions across collections (limited to 500 documents)
- Async/await required for all operations

---

## Performance Optimization

### Best Practices

1. **Batch Reads:** Use `get_all()` for multiple documents
2. **Query Optimization:** Create composite indexes for common queries
3. **Denormalization:** Store frequently accessed data redundantly
4. **Pagination:** Use `.limit()` and `.offset()` for large result sets
5. **Avoid `.stream()`:** Use `.get()` when possible (fewer round trips)

### Monitoring

```python
# Log slow queries
import time
start = time.time()
result = await repo.find_many(filters)
duration = time.time() - start
if duration > 1.0:
    logger.warning(f"Slow query: {duration:.2f}s")
```

---

## Backup & Recovery

**Automated Backups:** Enabled via Firebase Console  
**Frequency:** Daily  
**Retention:** 30 days  
**Location:** Same region as Firestore database

**Manual Export:**
```bash
gcloud firestore export gs://[BUCKET_NAME] \
  --collection-ids=users,students,student_attendance
```

---

## Security Rules

Firestore security rules are defined in `firestore.rules`:

```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read their own data
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
    }
    
    // Students can only read their own attendance
    match /student_attendance/{docId} {
      allow read: if request.auth.uid == resource.data.student_id;
      allow create: if request.auth.uid == request.resource.data.student_id;
    }
    
    // Faculty can manage sessions
    match /sessions/{sessionId} {
      allow read: if true; // Public read
      allow create, update: if request.auth.token.role == 'faculty';
    }
  }
}
```

**Note:** Backend uses Admin SDK which bypasses security rules.

---

## Troubleshooting

### Common Issues

**Issue:** "Missing index" error  
**Solution:** Create composite index as shown above

**Issue:** "Deadline exceeded" on queries  
**Solution:** Add indexes, reduce query complexity, or paginate

**Issue:** "Permission denied"  
**Solution:** Check security rules or Admin SDK initialization

---

## Contact

For database questions: See `/docs/CONTRIBUTING.md`
