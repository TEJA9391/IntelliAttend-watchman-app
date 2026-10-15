# 🛡️ Admin Portal Documentation

The Admin Portal is the central management hub for the IntelliAttend system. It allows university administrators to configure the physical infrastructure, manage academic structures, onboard users, and monitor real-time attendance intelligence.

## 🏗️ Technical Architecture

### Tech Stack
- **Core**: Vanilla JavaScript (ES6+)
- **Styling**: Vanilla CSS3 with **Glassmorphism** design language.
- **Icons**: FontAwesome 6.4.0
- **Fonts**: Outfit (Google Fonts)
- **Data Visualization**: Chart.js for intelligence reports.
- **Authentication**: JWT-based session management.

### Key Modules

- **Authentication (`login.html`, `js/auth.js`)**:
    - Secure login for Admin and Super Admin roles.
    - Identity recovery flows (Forgot Admin ID, Reset Password).
    - Auth Guards to prevent unauthorized access to protected pages.

- **Campus Vault (`js/app.js` -> `vault`)**:
    - A comprehensive "Snapshot" of the entire database.
    - Displays real-time counts and hierarchical tables for campuses, departments, blocks, rooms, and sections.

- **Intelligence & Analytics (`js/analytics.js`)**:
    - Advanced data visualization using Chart.js.
    - Provides insights into attendance trends and system usage.

- **Infrastructure Management**:
    - **Institution**: Define the top-level university identity.
    - **Campuses**: Map physical geofences with geographic coordinates and radii.
    - **Blocks & Rooms**: Configure buildings and specific classrooms, including Wi-Fi BSSID and BLE Beacon mapping.

- **Academic Management**:
    - **Departments & Subjects**: Define the educational organizational structure and curriculum.
    - **Sections & Timetable**: Group students and schedule class pairings.

- **Identity Management**:
    - **User Onboarding**: Register faculty and students with role-specific metadata.

- **Attendance Operations**:
    - **Active Sessions**: Monitor live classes in real-time, showing faculty, room, and current student count.

## 🚀 Setup & Installation

### Running Locally
1. Navigate to the admin portal directory:
   ```bash
   cd admin-portal
   ```
2. Start a local server:
   ```bash
   npx http-server -p 4000 -c-1
   ```
3. Open `http://localhost:4000` in your browser.

### Authentication Config
- The portal communicates with the backend at `http://localhost:8000/api/v1`.
- Ensure the backend is running and you have valid admin credentials.

## 📡 API Integration

### Central API Helpers
- **`getAuthHeaders()`**: Injects the Bearer JWT token into every request.
- **`processForm()`**: A unified handler for all infrastructure and academic data submissions via POST requests.

### Data Snapshots
- **`loadVaultData()`**: Fetches a complete system snapshot from `/api/v1/admin/snapshot`.
- **`loadSessionData()`**: Retrieves active session status from `/api/v1/sessions/active`.

## 🎨 Design Philosophy
- **Glassmorphism**: Uses semi-transparent glass backgrounds with backdrop filters for a premium, modern feel.
- **Micro-interactions**: Toast notifications, loading spinners, and hover transitions for enhanced user feedback.
- **Responsive Layout**: Designed to work effectively on desktop and tablet displays.
