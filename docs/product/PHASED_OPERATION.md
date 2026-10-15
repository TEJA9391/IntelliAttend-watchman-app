# 🧩 IntelliAttend — Role Relationships & Phase-wise Operation

> **Think in PHASES, not roles.**
> Each role wakes up only in certain phases.

---

## 🔷 PHASE 0: PLATFORM FOUNDATION (One-time / Rare)

### 🎯 Goal
Create and protect the IntelliAttend platform itself.

### 👤 Active Role
**Super Admin (Platform Mode)**

### 🛠️ What happens
* Defines global architecture
* Creates role definitions
* Sets QR rules, security thresholds
* Builds tenant isolation model
* Enables Infrastructure Mode internally

### 🔁 Role Relationships
* No colleges yet
* No faculty
* No students
* Pure system-level work

📌 **This phase happens before any college joins.**

---

## 🔷 PHASE 1: COLLEGE ONBOARDING

### 🎯 Goal
Bring a new college into IntelliAttend safely.

### 👤 Active Roles
* **Super Admin (Platform Mode)**
* **College Admin** (introduced here)

### 🛠️ What happens

#### Super Admin
* Registers the college
* Creates tenant
* Assigns College Admin
* Enables features based on plan

#### College Admin
* Accepts onboarding
* Verifies institutional data
* Prepares academic structure

### 🔁 Role Relationships
* Super Admin → *authorizes* College Admin
* College Admin → *depends on* Super Admin

📌 **No physical rooms yet. No attendance yet.**

---

## 🔷 PHASE 2: PHYSICAL INFRASTRUCTURE MAPPING
*(MOST CRITICAL PHASE)*

### 🎯 Goal
Convert classrooms into trusted digital rooms.

### 👤 Active Roles
* **Super Admin (Infrastructure Mode)**
* (College Admin is NOT involved)

### 🛠️ What happens

#### Super Admin (Infrastructure Mode)
* Physically visits / provisions rooms
* Captures:
  * Wi-Fi BSSID
  * BLE UUID
  * GPS cluster
  * SmartBoard binding
* Locks room trust config

#### College Admin
* Only sees “Room Ready” status
* Cannot edit anything

### 🔁 Role Relationships
* Infrastructure Mode → feeds trusted data
* Platform Mode → validates & locks it

📌 **This phase creates the trust backbone.**

---

## 🔷 PHASE 3: ACADEMIC CONFIGURATION

### 🎯 Goal
Map academic reality onto trusted infrastructure.

### 👤 Active Roles
* **College Admin**
* **Faculty** (introduced here)

### 🛠️ What happens

#### College Admin
* Creates departments
* Defines courses
* Assigns faculty to subjects
* Maps subjects → rooms

#### Faculty
* Gets assigned classes
* Reviews room allocation
* No attendance yet

### 🔁 Role Relationships
* College Admin → controls Faculty
* Faculty → depends on room trust created earlier

📌 **Still no students scanning anything.**

---

## 🔷 PHASE 4: STUDENT ENROLLMENT

### 🎯 Goal
Bring students into the system.

### 👤 Active Roles
* **College Admin**
* **Student**

### 🛠️ What happens

#### College Admin
* Imports student list
* Assigns sections
* Activates student accounts

#### Student
* Installs app
* Verifies identity
* Prepares device (permissions)

### 🔁 Role Relationships
* College Admin → authorizes Student
* Student → has no control over system

📌 **Students cannot act without faculty sessions.**

---

## 🔷 PHASE 5: LIVE ATTENDANCE SESSION (DAILY OPERATION)

### 🎯 Goal
Secure, real-time attendance.

### 👤 Active Roles
* **Faculty**
* **Student**
* **Super Admin (Passive Monitoring)**

### 🛠️ What happens

#### Faculty
* Starts session
* Links SmartBoard via OTP
* Observes live attendance grid

#### Student
* Scans rotating QR
* Passes:
  * Identity check
  * Proximity check
  * Device integrity check
* Gets marked present

#### Super Admin
* Monitors health
* Detects anomalies
* Does NOT interfere unless needed

### 🔁 Role Relationships
* Faculty ↔ Student (via system)
* SmartBoard ↔ Backend
* Super Admin → watches silently

📌 **This is the most frequent phase.**

---

## 🔷 PHASE 6: EXCEPTIONS & INCIDENTS (Occasional)

### 🎯 Goal
Handle failures, disputes, fraud.

### 👤 Active Roles
* **College Admin**
* **Super Admin**

### 🛠️ What happens

#### College Admin
* Reviews attendance requests
* Flags issues
* Requests override (with reason)

#### Super Admin
* Investigates logs
* Approves or rejects actions
* Freezes or restores data
* Forces re-provision if needed

### 🔁 Role Relationships
* College Admin → escalates
* Super Admin → final authority

📌 **No silent changes allowed. Everything logged.**

---

## 🔷 PHASE 7: AUDIT & REPORTING (Periodic)

### 🎯 Goal
Transparency, compliance, trust.

### 👤 Active Roles
* **College Admin**
* **Super Admin**
* *(Optional Auditor)*

### 🛠️ What happens
* Attendance reports generated
* Logs exported
* Patterns reviewed
* Compliance verified

📌 **No system changes here. Only observation.**

---

# 🧠 ROLE INTERACTION SUMMARY (VERY IMPORTANT)

| Role                | Talks To          | When       |
| ------------------- | ----------------- | ---------- |
| Super Admin         | Everyone          | All phases |
| Infrastructure Mode | Physical world    | Phase 2    |
| College Admin       | Faculty, Students | Phases 3–7 |
| Faculty             | Students          | Phase 5    |
| Student             | System only       | Phase 5    |

---

# 🔑 ONE GOLDEN RULE

> **No role ever skips a phase. Trust is built layer by layer.**

If you skip:
* Infrastructure → fraud happens
* Governance → chaos happens
* Separation → abuse happens
