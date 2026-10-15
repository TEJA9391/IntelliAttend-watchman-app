# Instructions for TEJA9391 - Faculty Mobile App

## Your Assignment

You are assigned to work on **IntelliAttend Faculty Mobile App** only.
**NO OTHER REPOSITORY.** Do not touch any other repo.

---

## Your Access

| Repository | Your Access | What It Means |
|------------|-------------|---------------|
| IntelliAttend-Faculty-Mobile-App | write | You can push branches, but ALWAYS use Pull Requests |

---

## Before You Start - Setup (One Time Only)

### Step 1: Clone the Repository
```bash
git clone git@github.com:IntelliAttend/IntelliAttend-Faculty-Mobile-App.git
cd IntelliAttend-Faculty-Mobile-App
```

### Step 2: Install Flutter
- Download Flutter from: https://docs.flutter.dev/get-started/install
- Run: `flutter doctor` to verify installation
- You need Flutter SDK, Android Studio/Xcode, and a device/emulator

### Step 3: Install Dependencies
```bash
flutter pub get
```

### Step 4: Verify It Works
```bash
flutter run
```
App should launch on your device/emulator.

---

## Daily Workflow (Follow This Every Time)

### Step 1: Start Your Day
```bash
# Go to your project folder
cd IntelliAttend-Faculty-Mobile-App

# Switch to school-main branch (OUR WORKING BRANCH)
git checkout school-main

# Pull latest changes from owner
git pull origin school-main

# Create your working branch from school-main
git checkout -b cosmetic/your-feature-name
```

**Branch naming rules:**
- Must start with `cosmetic/`
- Use lowercase, no spaces
- Be descriptive

**Good examples:**
```
cosmetic/update-login-colors
cosmetic/improve-dashboard-spacing
cosmetic/add-loading-animation
cosmetic/fix-button-alignment
```

**Bad examples:**
```
my-changes          (missing cosmetic/ prefix)
Cosmetic/Update     (capital letters)
feature/new-api     (not cosmetic)
fix-bug             (not cosmetic)
```

### Step 2: Make Your Changes
- Edit ONLY the files listed in "Allowed Files" section below
- Test your changes: `flutter run`
- Take screenshots of before/after

### Step 3: Save Your Work
```bash
# See what files you changed
git status

# Add ONLY the files you changed
git add lib/Presentation/ lib/Theme/ assets/

# NEVER add these:
# git add lib/Core/
# git add lib/Data/
# git add lib/Services/
# git add lib/engine/
# git add lib/main.dart
# git add android/ ios/ web/ windows/
# git add pubspec.yaml

# Commit with clear message
git commit -m "cosmetic: describe what you changed"
```

**Commit message examples:**
```
cosmetic: update login button colors to teal
cosmetic: improve dashboard header spacing
cosmetic: add shimmer loading to reports screen
cosmetic: fix button alignment on profile page
cosmetic: update theme colors for dark mode
```

### Step 4: Push Your Work
```bash
# Push your branch to GitHub
git push origin cosmetic/your-feature-name
```

### Step 5: Create Pull Request
1. Go to: https://github.com/IntelliAttend/IntelliAttend-Faculty-Mobile-App
2. You'll see a yellow banner: "cosmetic/your-feature-name had recent pushes"
3. Click **"Compare & pull request"**
4. Fill out the form:
   - **Title:** `cosmetic: your change description`
   - **Description:** Explain what you changed and why
   - **Checklist:** Check all boxes confirming you only touched allowed files
5. Attach screenshots (before/after)
6. Click **"Create pull request"**

### Step 6: Wait for Review
- Owner will review your code
- You may get comments asking for changes
- If changes requested:
  1. Make the changes locally
  2. Commit: `git commit -m "cosmetic: address review feedback"`
  3. Push: `git push origin cosmetic/your-feature-name`
  4. PR auto-updates with new changes
- Once approved, owner will merge your PR

### Step 7: Clean Up
```bash
# Switch back to school-main
git checkout school-main

# Delete your local branch
git branch -d cosmetic/your-feature-name

# Pull latest (now includes your merged work)
git pull origin school-main
```

---

## What You CAN Edit (Safe Zone)

### `lib/Presentation/` - All UI Files

#### Screens (Feature Pages)
```
lib/Presentation/Features/Analytics/analytics_screen.dart
lib/Presentation/Features/Auth/Registration/otp_screen.dart
lib/Presentation/Features/Auth/Registration/registration_screen.dart
lib/Presentation/Features/Auth/Registration/set_password_screen.dart
lib/Presentation/Features/Auth/lock_screen.dart
lib/Presentation/Features/Auth/unified_auth_gate.dart
lib/Presentation/Features/Auth/compromised_device_screen.dart
lib/Presentation/Features/Courses/courses_screen.dart
lib/Presentation/Features/Faculty/attendance_code_screen.dart
lib/Presentation/Features/Faculty/change_password_screen.dart
lib/Presentation/Features/Faculty/dashboard_controller.dart
lib/Presentation/Features/Faculty/dashboard_screen.dart
lib/Presentation/Features/Faculty/faculty_timetable_screen.dart
lib/Presentation/Features/Faculty/login_devices_screen.dart
lib/Presentation/Features/Faculty/Components/custom_app_bar.dart
lib/Presentation/Features/Faculty/Components/dashboard_header.dart
lib/Presentation/Features/Faculty/Components/dashboard_sections.dart
lib/Presentation/Features/Faculty/Components/schedule_section.dart
lib/Presentation/Features/Faculty/Components/session_control_section.dart
lib/Presentation/Features/Faculty/live_monitor/live_monitor_controller.dart
lib/Presentation/Features/Faculty/live_monitor/live_monitor_screen.dart
lib/Presentation/Features/Faculty/live_monitor/manual_attendance_screen.dart
lib/Presentation/Features/Faculty/live_monitor/seating_arrangement_widget.dart
lib/Presentation/Features/Faculty/Settings/settings_screen.dart
lib/Presentation/Features/History/history_screen.dart
lib/Presentation/Features/Notifications/notification_detail_screen.dart
lib/Presentation/Features/Notifications/notification_preferences_screen.dart
lib/Presentation/Features/Notifications/notifications_screen.dart
lib/Presentation/Features/Profile/profile_screen.dart
lib/Presentation/Features/Reports/reports_controller.dart
lib/Presentation/Features/Reports/reports_screen.dart
lib/Presentation/Features/Reports/Components/actions_tab.dart
lib/Presentation/Features/Reports/Components/analytics_tab.dart
lib/Presentation/Features/Reports/Components/defaulter_tab.dart
lib/Presentation/Features/Reports/Components/eligibility_tab.dart
lib/Presentation/Features/Reports/Components/overview_tab.dart
lib/Presentation/Features/Reports/Components/report_helper_widgets.dart
lib/Presentation/Features/Reports/Components/sessions_tab.dart
lib/Presentation/Features/Reports/Components/students_tab.dart
lib/Presentation/Features/Resources/resources_controller.dart
lib/Presentation/Features/Resources/resources_screen.dart
lib/Presentation/Features/my_class/my_class_screen.dart
lib/Presentation/Features/my_class/syllabus_view.dart
lib/Presentation/Features/Students/student_directory_screen.dart
lib/Presentation/Features/Support/about_app_page.dart
lib/Presentation/Features/Support/help_center_page.dart
lib/Presentation/Features/Support/live_support_chat_page.dart
lib/Presentation/Features/Support/report_issue_page.dart
```

#### Widgets (Shared UI Components)
```
lib/Presentation/Widgets/app_drawer.dart
lib/Presentation/Widgets/custom_sliding_nav_bar.dart
lib/Presentation/Widgets/dynamic_pulse_dot.dart
lib/Presentation/Widgets/fingerprint_scan_overlay.dart
lib/Presentation/Widgets/onboarding_tooltip.dart
lib/Presentation/Widgets/premium_clock_badge.dart
lib/Presentation/Widgets/rolling_digit.dart
lib/Presentation/Widgets/skeleton_loader.dart
lib/Presentation/Widgets/slider_button.dart
```

### `lib/Theme/` - Visual Theming
```
lib/Theme/app_theme.dart
lib/Theme/theme_controller.dart
```

### `assets/` - Images, Icons, Fonts
```
assets/images/
assets/icons/
assets/fonts/
```

---

## What You CANNOT Touch (DO NOT EDIT)

### `lib/Core/` - Security & Networking (CRITICAL)
```
lib/Core/error/error_handler.dart
lib/Core/Models/crypto_envelope.dart
lib/Core/Models/device_data.dart
lib/Core/Models/websocket_event.dart
lib/Core/Network/api_client.dart
lib/Core/Network/Interceptors/auth_interceptor.dart
lib/Core/Network/Interceptors/security_interceptor.dart
lib/Core/Services/force_logout_service.dart
lib/Core/Services/hardware_service.dart
lib/Core/Services/key_enrollment_service.dart
lib/Core/Services/qr_validation_service.dart
lib/Core/Services/security_controller.dart
```

### `lib/Data/` - Models & API (CRITICAL)
```
lib/Data/Models/Attendance/attendance_models.dart
lib/Data/Models/Auth/auth_session_model.dart
lib/Data/Models/Auth/registration_models.dart
lib/Data/Models/Faculty/override_slot.dart
lib/Data/Models/Faculty/resource_model.dart
lib/Data/Models/Faculty/scheduled_class.dart
lib/Data/Models/Faculty/server_notification.dart
lib/Data/Models/Faculty/syllabus_topic.dart
lib/Data/Repositories/attendance_repository.dart
lib/Data/Repositories/auth_repository.dart
lib/Data/Repositories/course_repository.dart
lib/Data/Repositories/notification_repository.dart
lib/Data/Repositories/override_repository.dart
lib/Data/Repositories/resource_repository.dart
```

### `lib/Services/` - Business Logic (CRITICAL)
```
lib/Services/allocation_service.dart
lib/Services/board_readiness_notifier.dart
lib/Services/eligibility_service.dart
lib/Services/faculty_hydration_service.dart
lib/Services/faculty_service.dart
lib/Services/haptic_service.dart
lib/Services/notification_service.dart
lib/Services/permission_service.dart
lib/Services/persistence_service.dart
lib/Services/security_service.dart
lib/Services/session_management_service.dart
lib/Services/syllabus_service.dart
lib/Services/sync_fcm_handler.dart
lib/Services/time_sync_service.dart
lib/Services/websocket_service.dart
```

### `lib/engine/` - Timetable Logic (CRITICAL)
```
lib/engine/engine.dart
lib/engine/time_block.dart
lib/engine/time_source.dart
lib/engine/timetable_controller.dart
lib/engine/timetable_phase.dart
lib/engine/timetable_snapshot.dart
lib/engine/timetable_state_machine.dart
```

### `lib/main.dart` - App Entry Point (CRITICAL)
```
lib/main.dart
```

### Platform Configs (CRITICAL)
```
android/
ios/
web/
windows/
```

### Config Files (CRITICAL)
```
pubspec.yaml
pubspec.lock
analysis_options.yaml
.env
.env.example
```

---

## Code Style Rules

### Dart/Flutter
```dart
// Use const when possible
const Text('Hello')

// Use meaningful names
// BAD:  var x = 10;
// GOOD: var attendanceCount = 10;

// Use theme colors, not hardcoded
// BAD:  color: Colors.blue
// GOOD: color: Theme.of(context).colorScheme.primary

// Widget naming: PascalCase
class DashboardScreen extends StatelessWidget { }

// File naming: snake_case
dashboard_screen.dart
```

### Commit Messages
```
cosmetic: <action> <what>

Examples:
cosmetic: update login button colors
cosmetic: improve dashboard spacing
cosmetic: add loading skeleton to reports
cosmetic: fix button alignment on profile
cosmetic: update theme for dark mode
```

---

## What Gets Your Work REJECTED

| Reason | Example |
|--------|---------|
| Editing wrong files | Changed `lib/Core/Network/api_client.dart` |
| Non-cosmetic changes | Modified business logic in `lib/Services/` |
| No screenshots | Submitted PR without before/after images |
| Vague description | "Fixed stuff" or "Updated things" |
| Bad commit message | "update" or "fix" |
| Missing checklist | Didn't confirm only cosmetic changes |
| Multiple unrelated changes | Changed login + dashboard + reports in one PR |

---

## GitHub Rules

### DO
- Always create a new branch for each feature
- Always use Pull Requests
- Write clear commit messages
- Add screenshots to PRs
- Respond to review feedback promptly
- Keep your fork updated

### DON'T
- Push directly to `school-main` branch
- Edit files outside your allowed zone
- Commit `pubspec.yaml` changes
- Add new dependencies
- Delete files you didn't create
- Merge your own PRs
- Force push (`git push --force`)
- Touch `main`, `dev`, or `master` branches

---

## Getting Help

### If Something Breaks
```bash
# Discard all local changes
git checkout .
git clean -fd

# Start fresh
git checkout school-main
git pull origin school-main
```

### If You're Confused
1. Read the code comments in existing files
2. Look at similar features for patterns
3. Ask in the Pull Request comments
4. Do NOT guess - ask before coding

### Useful Commands
```bash
# Check status
git status

# See what changed
git diff

# See commit history
git log --oneline -10

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Discard all changes
git checkout .
```

---

## Summary

| Rule | Details |
|------|---------|
| **Repo** | IntelliAttend-Faculty-Mobile-App ONLY |
| **Working Branch** | `school-main` (start from here) |
| **Branch prefix** | `cosmetic/` |
| **Allowed files** | `lib/Presentation/`, `lib/Theme/`, `assets/` |
| **Forbidden files** | `lib/Core/`, `lib/Data/`, `lib/Services/`, `lib/engine/`, `lib/main.dart`, `android/`, `ios/`, `pubspec.yaml` |
| **Forbidden branches** | `main`, `dev`, `master` (DO NOT TOUCH) |
| **Workflow** | Branch from school-main → Edit → Commit → Push → PR → Wait for review |
| **PR requirement** | Screenshots + description + checklist |
| **Review** | Owner reviews, may ask for changes |
| **Merge** | Only owner merges |

**Follow these instructions exactly. No exceptions.**
