import 'package:flutter_test/flutter_test.dart';

import 'package:intelli_attend_faculty/main.dart';

/// Baseline smoke test that verifies the Faculty [IntelliAttendApp] widget
/// tree can mount without throwing.
///
/// Supplies [persistenceFuture] and [backgroundFuture] as required named
/// parameters — both resolve immediately — so the test focuses purely on
/// widget-tree construction rather than async boot sequencing.
void main() {
  testWidgets('Faculty Application Baseline Boot Test',
      (WidgetTester tester) async {
    final mockPersistenceFuture = Future<void>.value();

    await tester.pumpWidget(
      IntelliAttendApp(
        persistenceFuture: mockPersistenceFuture,
        backgroundFuture: Future<void>.value(),
        firebaseReady: Future<void>.value(),
      ),
    );

    expect(find.byType(IntelliAttendApp), findsOneWidget);
  });
}
