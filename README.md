# IntelliAttend Faculty Mobile App

Flutter/Dart mobile app for faculty to mark attendance, manage timetables, and view reports. Runs on Android and iOS.

## Features

- Mark attendance per period
- View and manage class timetable
- Real-time attendance updates via WebSocket
- Push notifications for schedule changes
- Biometric authentication (fingerprint/face)
- Hardware-backed security (Android KeyStore / iOS Secure Enclave)
- Offline support with local Isar database

## Tech Stack

- **Framework:** Flutter/Dart
- **State:** Controllers (GetX pattern)
- **Database:** Isar (local NoSQL)
- **API:** REST via Dio with interceptors
- **Auth:** Firebase Auth + hardware-backed crypto
- **Real-time:** WebSocket

## Getting Started

### Prerequisites

- Flutter SDK (>=3.41.0)
- Dart SDK
- Android Studio / VS Code
- Xcode (for iOS)

### Installation

```bash
flutter pub get
```

### Environment Setup

```bash
cp .env.example .env
# Edit .env with your API_BASE_URL
```

### Running

```bash
flutter run              # Run on connected device
flutter run -d chrome    # Run on web
```

### Testing

```bash
flutter test             # Run all tests
dart analyze             # Static analysis
dart format .           # Format code
```

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── Core/
│   ├── Models/               # Data models
│   ├── Services/             # API, WebSocket, notifications
│   ├── Repositories/         # Data repositories
│   └── Utils/                # Helpers, constants
├── Screens/                  # UI screens
├── Controllers/              # State controllers
├── widgets/                  # Reusable components
└── packages/
    └── intelli_attend_shared/ # Shared timetable engine
```

## Security

- **Force Logout Chain:** AuthInterceptor → SecurityInterceptor → ForceLogoutService
- **Hardware Crypto:** ECDSA keys in Android KeyStore / iOS Secure Enclave
- **Session Lifecycle:** DashboardController → Repositories → WebSocket Events

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Related Repositories

- [IntelliAttend-Server](../IntelliAttend-Server/) — Backend API
- [IntelliAttend-SmartBoard](../IntelliAttend-SmartBoard/) — Classroom display
- [IntelliAttend-Student-Mobile-App](../IntelliAttend-Student-Mobile-App/) — Student app (shares timetable engine)
