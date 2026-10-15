# IntelliAttend Faculty App - Collaboration Guide

## About the Project

**IntelliAttend Faculty** is a Flutter mobile app for faculty members to manage classroom attendance. It's part of the IntelliAttend ecosystem (Faculty App + Student App + SmartBoard App + Server).

### Key Features
- **Session Management** - Launch attendance sessions via 6-digit OTP handshake with SmartBoards
- **Live Monitor** - Real-time pulse dashboard showing students as they verify attendance
- **Reports** - Analytics, eligibility tracking, defaulter reports
- **Notifications** - Push notifications with FCM integration
- **Resources** - Upload/download course materials
- **Security** - Root/jailbreak detection, hardware key enrollment, time-sync anti-fraud

### Tech Stack
- **Framework:** Flutter (Dart)
- **State Management:** Provider + ChangeNotifier
- **Local Storage:** Hive + SharedPreferences
- **Networking:** Dio (HTTP) + WebSocket (real-time)
- **Backend:** Firebase (Auth, FCM) + Custom REST API

---

## Repository Structure

```
IntelliAttend-Faculty-Mobile-App/
|
|-- lib/
|   |-- main.dart                    # App entry point
|   |-- Core/                        # Foundation layer (networking, security)
|   |-- Data/                        # Models and repositories
|   |-- Services/                    # Business logic services
|   |-- Theme/                       # Visual theming (colors, fonts)
|   |-- engine/                      # Timetable/scheduling logic
|   |-- presentation/                # UI layer (screens, widgets)
|       |-- Widgets/                 # Reusable UI components
|       |-- features/                # Feature-specific screens
|
|-- assets/                          # Images, icons, fonts
|-- android/                         # Android platform config
|-- ios/                             # iOS platform config
|-- web/                             # Web platform config
|-- windows/                         # Windows platform config
|-- test/                            # Unit and widget tests
|-- docs/                            # Documentation
```

---

## What You CAN Edit (Cosmetic Changes Only)

### 1. `lib/presentation/Widgets/` - Shared UI Components
These are reusable widgets used across the app:

| File | Description |
|------|-------------|
| `app_drawer.dart` | Navigation drawer (hamburger menu) |
| `custom_sliding_nav_bar.dart` | Bottom navigation bar |
| `dynamic_pulse_dot.dart` | Animated pulse indicator |
| `fingerprint_scan_overlay.dart` | Biometric scan overlay |
| `onboarding_tooltip.dart` | First-use tooltips |
| `premium_clock_badge.dart` | Clock display badge |
| `rolling_digit.dart` | Animated digit counter |
| `skeleton_loader.dart` | Loading skeleton/shimmer |
| `slider_button.dart` | Slide-to-confirm button |

### 2. `lib/presentation/features/` - Feature Screens

#### Auth Screens (Login/Registration)
- `Auth/login_screen.dart` - Login page
- `Auth/lock_screen.dart` - Biometric lock screen
- `Auth/compromised_device_screen.dart` - Security warning
- `Auth/Registration/otp_screen.dart` - OTP verification
- `Auth/Registration/registration_screen.dart` - Registration form
- `Auth/Registration/set_password_screen.dart` - Password setup

#### Faculty Dashboard
- `Faculty/dashboard_screen.dart` - Main dashboard
- `Faculty/Components/dashboard_header.dart` - Dashboard header
- `Faculty/Components/schedule_section.dart` - Schedule display
- `Faculty/Components/session_control_section.dart` - Session controls
- `Faculty/Components/custom_app_bar.dart` - Custom app bar
- `Faculty/attendance_code_screen.dart` - OTP display
- `Faculty/faculty_timetable_screen.dart` - Timetable view
- `Faculty/login_devices_screen.dart` - Device management
- `Faculty/change_password_screen.dart` - Password change
- `Faculty/Settings/settings_screen.dart` - Settings page

#### Live Monitor
- `Faculty/live_monitor/live_monitor_screen.dart` - Live attendance view
- `Faculty/live_monitor/manual_attendance_screen.dart` - Manual attendance
- `Faculty/live_monitor/seating_arrangement_widget.dart` - Seating layout

#### Reports
- `Reports/reports_screen.dart` - Reports main page
- `Reports/Components/overview_tab.dart` - Overview tab
- `Reports/Components/analytics_tab.dart` - Analytics tab
- `Reports/Components/eligibility_tab.dart` - Eligibility tab
- `Reports/Components/students_tab.dart` - Students tab
- `Reports/Components/sessions_tab.dart` - Sessions tab
- `Reports/Components/defaulter_tab.dart` - Defaulter tab
- `Reports/Components/actions_tab.dart` - Actions tab
- `Reports/Components/report_helper_widgets.dart` - Helper widgets

#### Other Features
- `Notifications/notifications_screen.dart` - Notification inbox
- `Notifications/notification_detail_screen.dart` - Notification detail
- `Notifications/notification_preferences_screen.dart` - Notification settings
- `Profile/profile_screen.dart` - Faculty profile
- `Courses/courses_screen.dart` - Course listing
- `Resources/resources_screen.dart` - Resource management
- `Analytics/analytics_screen.dart` - Analytics view
- `History/history_screen.dart` - Attendance history
- `my_class/my_class_screen.dart` - Class management
- `my_class/syllabus_view.dart` - Syllabus viewer
- `Students/student_directory_screen.dart` - Student directory
- `Support/about_app_page.dart` - About page
- `Support/help_center_page.dart` - Help center
- `Support/report_issue_page.dart` - Bug report
- `Support/live_support_chat_page.dart` - Live support

### 3. `lib/Theme/` - Visual Theming

| File | Description |
|------|-------------|
| `app_theme.dart` | Colors, typography, component styles (light & dark) |
| `theme_controller.dart` | Theme mode switching logic |

### 4. `assets/` - Static Resources
- Images (PNG, JPG)
- Icons
- Fonts
- Lottie animations

---

## What You CANNOT Touch (DO NOT EDIT)

### Critical Files - Breaking Changes Risk

| File/Directory | Why It's Critical |
|----------------|-------------------|
| `lib/main.dart` | App entry point, dependency injection, startup sequence |
| `lib/Core/` | Network layer, security, encryption, error handling |
| `lib/Data/` | Data models, API repositories, database schemas |
| `lib/Services/` | Business logic, authentication, session management |
| `lib/engine/` | Timetable state machine, scheduling logic |

### Specific Critical Files

#### `lib/Core/` - DO NOT EDIT
- `Core/Network/api_client.dart` - HTTP client for all API calls
- `Core/Network/Interceptors/auth_interceptor.dart` - Auth token handling
- `Core/Network/Interceptors/security_interceptor.dart` - Security validation
- `Core/Models/crypto_envelope.dart` - Encryption payloads
- `Core/Models/websocket_event.dart` - Real-time events
- `Core/Models/device_data.dart` - Device fingerprinting
- `Core/Services/security_controller.dart` - Root security brain
- `Core/Services/force_logout_service.dart` - Remote logout
- `Core/Services/hardware_service.dart` - Hardware ID
- `Core/Services/key_enrollment_service.dart` - Security key setup
- `Core/Services/qr_validation_service.dart` - QR/OTP validation
- `Core/error/error_handler.dart` - Error handling

#### `lib/Data/` - DO NOT EDIT
- `Data/Models/Attendance/attendance_models.dart` - Attendance data
- `Data/Models/Auth/auth_session_model.dart` - Auth session
- `Data/Models/Auth/registration_models.dart` - Registration flow
- `Data/Models/Faculty/scheduled_class.dart` - Schedule data
- `Data/Models/Faculty/override_slot.dart` - Override slots
- `Data/Repositories/auth_repository.dart` - Auth API
- `Data/Repositories/attendance_repository.dart` - Attendance API
- `Data/Repositories/course_repository.dart` - Course API
- `Data/Repositories/notification_repository.dart` - Notification API
- `Data/Repositories/override_repository.dart` - Override API
- `Data/Repositories/resource_repository.dart` - Resource API

#### `lib/Services/` - DO NOT EDIT
- `Services/persistence_service.dart` - Local storage (Hive/SharedPrefs)
- `Services/faculty_service.dart` - Faculty state management
- `Services/notification_service.dart` - Push notifications
- `Services/sync_fcm_handler.dart` - FCM message handlers
- `Services/time_sync_service.dart` - Server time sync
- `Services/session_management_service.dart` - Session lifecycle
- `Services/websocket_service.dart` - WebSocket client
- `Services/eligibility_service.dart` - Eligibility calculations
- `Services/security_service.dart` - Security checks

#### `lib/engine/` - DO NOT EDIT
- `engine/engine.dart` - Core engine
- `engine/timetable_controller.dart` - Timetable driver
- `engine/timetable_state_machine.dart` - State transitions
- `engine/timetable_phase.dart` - Phase definitions
- `engine/timetable_snapshot.dart` - State snapshots
- `engine/time_block.dart` - Time block data
- `engine/time_source.dart` - Time abstraction

#### Platform Configs - DO NOT EDIT
- `android/` - Android build config, manifests, Gradle
- `ios/` - iOS build config, Info.plist, Xcode
- `web/` - Web config
- `windows/` - Windows build config
- `pubspec.yaml` - Dependencies (DO NOT add packages)

---

## How to Work (Step-by-Step)

### 1. Fork the Repository
1. Go to: `https://github.com/IntelliAttend/IntelliAttend-Faculty-Mobile-App`
2. Click **"Fork"** button (top right)
3. Select your GitHub account
4. Wait for fork to complete

### 2. Clone Your Fork
```bash
# Clone YOUR fork (not the original)
git clone git@github.com:YOUR_USERNAME/IntelliAttend-Faculty-Mobile-App.git

# Navigate to project
cd IntelliAttend-Faculty-Mobile-App

# Add original repo as upstream
git remote add upstream git@github.com:IntelliAttend/IntelliAttend-Faculty-Mobile-App.git

# Verify remotes
git remote -v
# origin    -> YOUR fork
# upstream  -> Original repo
```

### 3. Create a Feature Branch
```bash
# Make sure you're on main
git checkout main

# Pull latest from original
git pull upstream main

# Create your branch
git checkout -b cosmetic/your-feature-name

# Examples:
git checkout -b cosmetic/update-login-colors
git checkout -b cosmetic/improve-dashboard-layout
git checkout -b cosmetic/add-loading-animation
```

### 4. Make Your Changes
- **ONLY edit files in:**
  - `lib/presentation/` (screens and widgets)
  - `lib/Theme/` (colors, fonts, styles)
  - `assets/` (images, icons)

- **Test your changes:**
  ```bash
  flutter run
  ```

### 5. Commit Your Changes
```bash
# Stage changes
git add lib/presentation/ lib/Theme/ assets/

# Check what you're committing
git status

# Commit with descriptive message
git commit -m "cosmetic: update login screen button colors"

# Commit message examples:
# "cosmetic: improve dashboard header spacing"
# "cosmetic: add loading skeleton to reports"
# "cosmetic: update theme colors for dark mode"
# "cosmetic: fix button alignment on profile screen"
```

### 6. Push to YOUR Fork
```bash
git push origin cosmetic/your-feature-name
```

### 7. Create Pull Request
1. Go to YOUR fork on GitHub
2. Click **"Compare & pull request"**
3. Ensure:
   - **Base:** `IntelliAttend/IntelliAttend-Faculty-Mobile-App` → `main`
   - **Compare:** `YOUR_USERNAME` → `cosmetic/your-feature-name`
4. Fill out the PR template:
   - Check "Cosmetic (UI only)"
   - Describe your changes
   - Add before/after screenshots
   - Confirm checklist items
5. Click **"Create pull request"**

### 8. Wait for Review
- Owner will review your changes
- May request changes or approve
- Once approved, your changes will be merged

---

## Pull Request Rules

### PR Title Format
```
cosmetic: <short description>
```

Examples:
- `cosmetic: update login button colors`
- `cosmetic: improve dashboard spacing`
- `cosmetic: add shimmer loading to reports`

### PR Description Must Include
1. **Type of Change** - Check "Cosmetic (UI only)"
2. **Description** - What you changed and why
3. **Screenshots** - Before/after images (required for UI changes)
4. **Checklist** - Confirm you only touched allowed files

### What Gets Your PR Rejected
- Editing files in `lib/Core/`, `lib/Data/`, `lib/Services/`, `lib/engine/`
- Editing `lib/main.dart`
- Editing `android/`, `ios/`, `web/`, `windows/`
- Editing `pubspec.yaml` (adding dependencies)
- Non-cosmetic changes (logic, API, security)
- No screenshots for UI changes
- Vague description

---

## File Naming Conventions

### Screens
```dart
// Feature screen naming
lib/presentation/features/{Feature}/{feature}_screen.dart
lib/presentation/features/{Feature}/{feature}_controller.dart

// Examples:
lib/presentation/features/Profile/profile_screen.dart
lib/presentation/features/Reports/reports_screen.dart
lib/presentation/features/Reports/reports_controller.dart
```

### Widgets
```dart
// Reusable widget naming
lib/presentation/Widgets/{widget_name}.dart

// Examples:
lib/presentation/Widgets/skeleton_loader.dart
lib/presentation/Widgets/slider_button.dart
```

### Components
```dart
// Feature-specific components
lib/presentation/features/{Feature}/Components/{component_name}.dart

// Examples:
lib/presentation/features/Faculty/Components/dashboard_header.dart
lib/presentation/features/Reports/Components/overview_tab.dart
```

---

## Code Style Guidelines

### Dart/Flutter Conventions
```dart
// Use camelCase for variables and functions
String facultyName = 'John';
void loadDashboard() { }

// Use PascalCase for classes
class DashboardScreen extends StatelessWidget { }

// Use snake_case for file names
// dashboard_screen.dart

// Use const constructors when possible
const Text('Hello')

// Use meaningful variable names
// BAD:  var x = 10;
// GOOD: var attendanceCount = 10;
```

### Widget Structure
```dart
class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Screen')),
      body: const Center(
        child: Text('Hello World'),
      ),
    );
  }
}
```

### Theme Usage
```dart
// Use theme colors, don't hardcode
// BAD:  color: Colors.blue
// GOOD: color: Theme.of(context).colorScheme.primary

// Access theme
Theme.of(context).colorScheme
Theme.of(context).textTheme
Theme.of(context).brightness
```

---

## Common Tasks

### Change Colors
1. Edit `lib/Theme/app_theme.dart`
2. Modify color definitions
3. Test in both light and dark mode

### Modify a Screen
1. Find the screen in `lib/presentation/features/{Feature}/`
2. Edit the widget tree
3. Use `flutter run` to test
4. Take before/after screenshots

### Add a New Widget
1. Create file in `lib/presentation/Widgets/`
2. Follow existing widget patterns
3. Make it reusable (pass parameters)

### Update Assets
1. Add files to `assets/` folder
2. Reference in code: `Image.asset('assets/image.png')`
3. Ensure proper format (PNG for images, SVG for icons)

---

## Getting Help

### If You're Stuck
1. Read the code comments in existing files
2. Look at similar features for patterns
3. Check Flutter documentation: https://flutter.dev/docs
4. Ask in the PR comments

### Useful Commands
```bash
# Run the app
flutter run

# Hot reload (while app is running)
# Press 'r' in terminal

# Clean build
flutter clean && flutter pub get

# Run analyzer
flutter analyze

# Run tests
flutter test
```

---

## Summary

| Action | Allowed? |
|--------|----------|
| Edit `lib/presentation/` | Yes |
| Edit `lib/Theme/` | Yes |
| Edit `assets/` | Yes |
| Edit `lib/Core/` | NO |
| Edit `lib/Data/` | NO |
| Edit `lib/Services/` | NO |
| Edit `lib/engine/` | NO |
| Edit `lib/main.dart` | NO |
| Edit `android/ios/web/` | NO |
| Edit `pubspec.yaml` | NO |
| Add dependencies | NO |
| Push to main branch | NO |
| Create PR | Yes (requires review) |

**Remember:** You are making COSMETIC changes only (colors, fonts, spacing, layouts). Any logic changes will be rejected.
