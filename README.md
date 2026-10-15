# IntelliAttend Watchman App

Flutter/Dart mobile application for campus security personnel and watchmen to scan student/faculty ID cards, track entry/exit activity, verify visitor passes, and monitor real-time gate statistics. Runs on Android and iOS.

## Features

- **High-Speed QR & Barcode Scanner**: Scan 1D barcodes and 2D QR codes on physical or digital student/faculty ID cards with camera torch support and instant verification.
- **Gate Entry / Exit Logging**: Track student, faculty, and visitor check-ins and check-outs with automated timestamping and gate access approval.
- **Recently Scanned ID Card**: Live display of the most recently verified individual (ID number, name, department, batch, institution, and verification status).
- **Gate KPIs & Analytics**: Real-time checkpoint counters for Students Inside Campus, Active Visitor Passes, Late Entries, and Exits Logged.
- **Watchman Profile & Station Info**: Quick-access profile modal showing watchman designation, employee code, gate station, and security ratings.
- **Hardware-Backed Security**: Cryptographic ECDSA signing and integrity token validation using Android KeyStore and iOS Secure Enclave.
- **Offline Reliability**: Fast local caching with Hive/Isar for instant startup and seamless gate operations even during network interruptions.
- **Refined Dark Mode UI**: Clean, high-contrast dark theme optimized for day and night security shifts, with pinned headers and a tactile navigation dock.

## Tech Stack

- **Framework:** Flutter / Dart (>=3.41.0)
- **State Management:** Provider / Controllers
- **Scanner Engine:** `mobile_scanner` (QR, Code128, Code39, EAN13, DataMatrix)
- **Local Database:** Hive & SharedPreferences (ultra-fast offline caching)
- **Networking:** Dio REST client with authentication and security interceptors
- **Authentication & Security:** Firebase Auth + Android KeyStore / iOS Secure Enclave ECDSA hardware cryptography
- **Typography & Icons:** Google Fonts (Inter, JetBrains Mono) & Material Symbols

## Getting Started

### Prerequisites

- Flutter SDK (>=3.41.0)
- Dart SDK
- Android Studio / VS Code
- Xcode (for iOS)
- Physical Android/iOS device with camera support

### Installation

```bash
flutter pub get
```

### Environment Setup

```bash
cp .env.example .env
# Configure API_BASE_URL in .env
```

### Running

```bash
flutter run              # Run on connected device
flutter run -d chrome    # Run on web
```

### Building Release APK

```bash
flutter build apk --release
flutter install -d <device_id>
```

### Testing & Code Quality

```bash
flutter test             # Run unit and widget tests
flutter analyze          # Static code analysis
dart format .            # Format Dart code
```

## Project Structure

```
lib/
├── main.dart                                   # Application bootstrap & startup
├── Core/
│   ├── Network/                                # API clients and interceptors
│   ├── Security/                               # Hardware key management & tokens
│   └── Utils/                                  # Common helpers and constants
├── Data/
│   └── Repositories/                           # Gate records & authentication repositories
├── Presentation/
│   ├── Features/
│   │   ├── Auth/                               # Login & authentication gate
│   │   ├── Watchman/                           # Watchman dashboard & gate record details
│   │   ├── Profile/                            # QR Scanner screen & watchman profile
│   │   ├── Faculty/                            # Dashboard shell & controller
│   │   └── notifications/                      # Gate alerts & notifications
│   ├── Widgets/                                # Custom sliding nav bar, pulse dots, badges
│   └── Theme/                                  # AppTheme dark/light design tokens
└── Services/
    ├── id_card_service.dart                    # Barcode & QR verification logic
    ├── faculty_service.dart                    # Watchman profile persistence
    ├── haptic_service.dart                     # Tactile haptic feedback
    └── notification_service.dart               # Gate alerts & push messages
```

## Security & Verification

- **ID Verification Pipeline:** Barcode/QR Raw Payload → Checksum Validation → Server Cryptographic Attestation → Gate Log Registration
- **Hardware Cryptography:** ECDSA keys securely generated within Android KeyStore (`intelli_attend_key`) and iOS Secure Enclave
- **Tamper Protection:** Device fingerprinting and integrity token checks to prevent unauthorized scanners on campus gates

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Related Repositories

- [IntelliAttend-Server](https://github.com/TEJA9391/IntelliAttend-Server) — Central Backend API & Verification Engine
- [IntelliAttend-Student-Mobile-App](https://github.com/TEJA9391/IntelliAttend-Student-Mobile-App) — Student ID & Attendance Mobile App
- [IntelliAttend-Faculty-Mobile-App](https://github.com/TEJA9391/IntelliAttend-Faculty-Mobile-App) — Faculty Attendance & Timetable Management App
- [IntelliAttend-SmartBoard](https://github.com/TEJA9391/IntelliAttend-SmartBoard) — Classroom Attendance Display
