import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'package:intelli_attend_faculty/Theme/theme_controller.dart';
import 'package:intelli_attend_faculty/Core/Network/api_client.dart';
import 'package:intelli_attend_faculty/Data/Repositories/auth_repository.dart';

import 'package:intelli_attend_faculty/Core/Services/security_controller.dart';
import 'package:intelli_attend_faculty/Core/Services/force_logout_service.dart';
import 'package:intelli_attend_faculty/Core/Services/key_enrollment_service.dart';
import 'package:intelli_attend_faculty/Data/Repositories/attendance_repository.dart';
import 'package:intelli_attend_faculty/Data/Repositories/course_repository.dart';
import 'package:intelli_attend_faculty/Data/Repositories/resource_repository.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_controller.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Faculty/dashboard_screen.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Resources/resources_controller.dart';
import 'package:intelli_attend_faculty/Services/persistence_service.dart';
import 'package:intelli_attend_faculty/Services/faculty_service.dart';
import 'package:intelli_attend_faculty/Services/time_sync_service.dart';
import 'package:intelli_attend_faculty/Services/notification_service.dart';
import 'package:intelli_attend_faculty/Services/chat_notification_service.dart';
import 'package:intelli_attend_faculty/Services/chat_outbox_service.dart';
import 'package:intelli_attend_faculty/Services/sync_fcm_handler.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Auth/unified_auth_gate.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/messaging_router.dart';
import 'package:intelli_attend_faculty/Presentation/Features/Messaging/incoming_call_overlay.dart';

bool isFirebaseInitialized = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final appClock = Stopwatch()..start();
  debugPrint('[IntelliAttend-Faculty-Startup] ▶ main() — app clock started');

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFF16161A),
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ── Track A: Ultra-fast persistence path (~100ms) ─────────────────────
  // ONLY local I/O: Hive boxes + dotenv + prefs. NO Firebase.
  // Dashboard renders from cache the instant this resolves.
  final persistenceFuture = _bootstrapPersistence(appClock);

  // Firebase init continues in background — not blocking the UI gate.
  final firebaseReady = _initFirebase();

  // Track B runs after first frame for heavy background work.
  final backgroundCompleter = Completer<void>();

  runApp(IntelliAttendApp(
    persistenceFuture: persistenceFuture,
    backgroundFuture: backgroundCompleter.future,
    firebaseReady: firebaseReady,
  ));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Flush any deep-link that arrived before the navigator was ready.
    MessagingRouter.flushPending();
    _bootstrapBackground(persistenceFuture, firebaseReady, appClock).then((_) {
      backgroundCompleter.complete();
    }).catchError((e, stackTrace) {
      backgroundCompleter.completeError(e, stackTrace);
    });
  });
}

/// Track A — Ultra-fast persistence. Hive + dotenv + prefs ONLY.
/// Firebase is NOT awaited here — it continues in the background.
/// This completes in ~100ms, allowing the dashboard to render from cache instantly.
Future<void> _bootstrapPersistence(Stopwatch clock) async {
  debugPrint('[IntelliAttend-Faculty-Startup] ⚡ Track A started  (+${clock.elapsedMilliseconds}ms)');
  final sw = Stopwatch()..start();
  await Future.wait([
    dotenv.load(fileName: '.env'),
    ThemeController.init(),
    PersistenceService().initMinimal(),
  ]);
  
  // Hydrate faculty profile from cache instantly after Hive is ready.
  FacultyService.loadFromCache();

  debugPrint('[IntelliAttend-Faculty-Startup] ✅ Track A complete — Hive+prefs ready in ${sw.elapsedMilliseconds}ms (+${clock.elapsedMilliseconds}ms total)');
}

/// Track B — Heavy background infrastructure.
/// Runs deferred operations after the first frame has rendered.
Future<void> _bootstrapBackground(Future<void> persistenceFuture, Future<void> firebaseReady, Stopwatch clock) async {
  debugPrint('[IntelliAttend-Faculty-Startup] 🔥 Track B started  (+${clock.elapsedMilliseconds}ms)');
  final sw = Stopwatch()..start();

  // Wait for Firebase to be ready before opening remaining boxes.
  await firebaseReady;

  // Open remaining Hive boxes (attendance, notifications, device_data)
  // the instant Track A completes.
  await persistenceFuture.then((_) async {
    final boxSw = Stopwatch()..start();
    debugPrint('[IntelliAttend-Faculty-Startup] 📦 Track B — opening remaining Hive boxes...');
    await PersistenceService().initRemainingBoxes();
    debugPrint('[IntelliAttend-Faculty-Startup] 📦 Track B — attendance+notifications+device open in ${boxSw.elapsedMilliseconds}ms (+${clock.elapsedMilliseconds}ms total)');
  });
  debugPrint('[IntelliAttend-Faculty-Startup] 🔥 Track B — boxes wave done in ${sw.elapsedMilliseconds}ms (+${clock.elapsedMilliseconds}ms total)');

  // Initialize time sync and notification services
  TimeSyncService.initFallbackClock();
  tz_data.initializeTimeZones();

  final sw2 = Stopwatch()..start();
  await Future.wait([
    NotificationService().init(),
  ]);
  // Route notification taps (e.g. `chat:<conversationId>`) to the chat UI.
  NotificationService.onPayloadTap = MessagingRouter.openChatFromPayload;
  debugPrint('[IntelliAttend-Faculty-Startup] 🔥 Track B — Notification wave done in ${sw2.elapsedMilliseconds}ms (+${clock.elapsedMilliseconds}ms total)');

  // Initialize FCM handlers for board readiness, sync pings, late-start reminders
  unawaited(SyncFcmHandler.init());

  // App-wide chat alerts + offline outbox drain (fire when the socket connects).
  ChatNotificationService.instance.start();
  ChatOutboxService.instance.start();

  // Fire-and-forget: time sync handshake + hardware key enrollment
  unawaited(TimeSyncService.bootstrap());
  unawaited(KeyEnrollmentService.enroll());
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint("Firebase initialization skipped: $e");
  }
}

class IntelliAttendApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final Future<void> persistenceFuture;
  final Future<void> backgroundFuture;
  final Future<void> firebaseReady;

  const IntelliAttendApp({
    super.key,
    required this.persistenceFuture,
    required this.backgroundFuture,
    required this.firebaseReady,
  });

  @override
  Widget build(BuildContext context) {
    // 🛡️ ROOT PROVIDER: The SecurityController is the source of truth
    return ChangeNotifierProvider<SecurityController>(
      create: (_) => SecurityController(),
      child: MultiProvider(
        providers: [
          Provider<ApiClient>(create: (_) => ApiClient()),
          ProxyProvider<ApiClient, CourseRepository>(
            update: (_, apiClient, previous) => previous ?? CourseRepository(),
          ),
          ProxyProvider<ApiClient, AttendanceRepository>(
            update: (_, apiClient, previous) => previous ?? AttendanceRepository(apiClient),
          ),
          ProxyProvider<ApiClient, AuthRepository>(
            update: (_, apiClient, previous) => previous ?? AuthRepository(apiClient),
          ),
          // v12.5 FIX: DashboardController is now LAZY. 
          // It will NOT initialize until the UnifiedAuthGate finishes biometrics.
          ChangeNotifierProxyProvider2<CourseRepository, AttendanceRepository, DashboardController>(
            lazy: true,
            create: (context) => DashboardController(
              context.read<CourseRepository>(),
              context.read<AttendanceRepository>(),
            ),
            update: (_, courseRepo, attendanceRepo, controller) =>
                controller ?? DashboardController(courseRepo, attendanceRepo),
          ),
          ProxyProvider<ApiClient, ResourceRepository>(
            update: (_, apiClient, previous) => previous ?? ResourceRepository(apiClient),
          ),
          ChangeNotifierProxyProvider<ResourceRepository, ResourcesController>(
            lazy: true,
            create: (context) => ResourcesController(context.read<ResourceRepository>()),
            update: (_, repo, previous) => previous ?? ResourcesController(repo),
          ),
        ],
        child: IntelliAttendMaterialApp(persistenceFuture: persistenceFuture, firebaseReady: firebaseReady),
      ),
    );
  }
}

class IntelliAttendMaterialApp extends StatelessWidget {
  final Future<void> persistenceFuture;
  final Future<void> firebaseReady;
  const IntelliAttendMaterialApp({super.key, required this.persistenceFuture, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'IntelliAttend Watchman',
          navigatorKey: IntelliAttendApp.navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: AppTheme.getTheme(Brightness.light),
          darkTheme: AppTheme.getTheme(Brightness.dark),
          routes: {
            '/login': (context) => const DashboardScreen(),
          },
          home: UnifiedAuthGate(persistenceFuture: persistenceFuture, firebaseReady: firebaseReady),
          builder: (context, child) {
            // Wire the navigator context for outside-of-tree navigation
            ForceLogoutService.setNavigatorContext(context);
            
            return SecurityOverlay(child: child);
          },
        );
      },
    );
  }
}

class SecurityOverlay extends StatelessWidget {
  final Widget? child;
  const SecurityOverlay({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
          const IncomingCallOverlay(),
        ],
      ),
    );
  }
}
