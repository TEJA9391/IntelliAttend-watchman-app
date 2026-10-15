# Quick Start for Collaborators

## Your Role
You are making **cosmetic changes only** - colors, fonts, spacing, layouts, animations. You do NOT touch business logic, APIs, security, or platform configs.

---

## 1-Minute Setup

```bash
# 1. Fork repo on GitHub (click Fork button)

# 2. Clone your fork
git clone git@github.com:YOUR_USERNAME/IntelliAttend-Faculty-Mobile-App.git
cd IntelliAttend-Faculty-Mobile-App

# 3. Add original repo as upstream
git remote add upstream git@github.com:IntelliAttend/IntelliAttend-Faculty-Mobile-App.git

# 4. Create your branch
git checkout -b cosmetic/my-changes

# 5. Run the app
flutter run
```

---

## What You CAN Edit

```
lib/presentation/        # Screens and widgets
lib/presentation/Widgets/    # Reusable UI components
lib/presentation/features/   # Feature screens
lib/Theme/              # Colors, fonts, styles
assets/                 # Images, icons
```

---

## What You CANNOT Edit

```
lib/main.dart           # App entry point
lib/Core/               # Security, networking, encryption
lib/Data/               # Models, API repositories
lib/Services/           # Business logic, auth, sessions
lib/engine/             # Timetable logic
android/ios/web/        # Platform configs
pubspec.yaml            # Dependencies
```

---

## Workflow

```bash
# 1. Create branch
git checkout -b cosmetic/my-feature

# 2. Make changes (ONLY in allowed folders)

# 3. Test
flutter run

# 4. Commit
git add lib/presentation/ lib/Theme/ assets/
git commit -m "cosmetic: describe your change"

# 5. Push to YOUR fork
git push origin cosmetic/my-feature

# 6. Open Pull Request on GitHub
```

---

## PR Checklist

Before submitting PR, confirm:
- [ ] Only modified files in `lib/presentation/`, `lib/Theme/`, or `assets/`
- [ ] Did NOT touch `lib/Core/`, `lib/Data/`, `lib/Services/`, `lib/engine/`
- [ ] Did NOT modify `android/`, `ios/`, `web/`, or `windows/`
- [ ] Did NOT edit `pubspec.yaml`
- [ ] Added before/after screenshots
- [ ] Changes are purely cosmetic

---

## Need Help?

- Read `COLLABORATION_GUIDE.md` for full details
- Look at existing code for patterns
- Check Flutter docs: https://flutter.dev/docs
