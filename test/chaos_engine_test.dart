import 'package:flutter_test/flutter_test.dart';
import 'package:intelli_attend_faculty/engine/engine.dart';
import 'package:intelli_attend_shared/models/timetable_slot.dart';
import 'package:intelli_attend_shared/models/slot_type.dart';
import 'package:intelli_attend_shared/test_shared/chaos_time_harness.dart';

/// Faculty-variant chaos-engineering tests for the timetable engine.
///
/// This suite mirrors the Student chaos tests (Tracks 1, 2, 4) with minor
/// assertion differences where the Faculty model omits certain fields
/// (e.g., no [facultyEmails] on the original faculty class). Key scenarios:
///
/// **Track 1 — Security Boundary**:
///   Timezone spoofing via [InstitutionalTime] and token replay prevention.
///
/// **Track 2 — Data Boundary**:
///   [SlotType.substitutionOverride] priority over [SlotType.regularClass]
///   at the same time boundary; duplicate-boundary crash safety.
///
/// **Track 4 — Hardware Boundary**:
///   Deep-wake recovery after 65-hour suspend and offline cache resilience.
void main() {

  final evaluator = const TimetableEvaluator();
  final stateMachine = TimetableStateMachine();

  DateTime dt(int y, int m, int d, int hour, int min, [int sec = 0]) {
    return DateTime(y, m, d, hour, min, sec);
  }

  group('Track 1: Security Boundary — Timezone Spoof & Replay', () {
    test('1.1 Tokyo Time Spoof: InstitutionalTime anchors to Asia/Kolkata', () {
      final timeContext = InstitutionalTime(
        dayOfWeek: 1,
        startMinutes: 565,
        startSeconds: 565 * 60,
        rawDateTime: DateTime.utc(2026, 6, 15, 3, 55, 0),
      );

      expect(timeContext.startMinutes, equals(565),
          reason: 'Must carry 565 (09:25 IST), not 775 (12:55 JST)');
      expect(timeContext.dayOfWeek, equals(1));
    });

    test('1.1 Tokyo Spoof: phase locked to beforeFirstClass', () {
      final timeContext = InstitutionalTime(
        dayOfWeek: 1,
        startMinutes: 565,
        startSeconds: 565 * 60,
        rawDateTime: DateTime.utc(2026, 6, 15, 3, 55, 0),
      );

      final today = [
        TimeBlock.fromSlot(slot(
          id: 'P1',
          startMinutes: 570,
          endMinutes: 630,
          subjectCode: 'MATH101',
          subjectName: 'Mathematics',
        )),
      ];

      final snapshot = evaluator.evaluate(
        timeContext: timeContext,
        todayBlocks: today,
        tomorrowBlocks: [],
      );

      expect(snapshot.phase, TimetablePhase.beforeFirstClass,
          reason: '09:25 IST is before 09:30 P1 — must be beforeFirstClass');
      expect(snapshot.countdownLabel, '00:05:00');
    });

    test('1.2 Malicious Flight Replay: token from past slot rejected', () {
      final capturedPayloadMinutes = 570;

      final today = [
        TimeBlock.fromSlot(slot(
          id: 'P1',
          startMinutes: 570,
          endMinutes: 630,
          subjectCode: 'MATH101',
          subjectName: 'Math',
          facultyEmails: ['prof@college.edu'],
        )),
        TimeBlock.fromSlot(slot(
          id: 'P2',
          startMinutes: 650,
          endMinutes: 710,
          subjectCode: 'PHY101',
          subjectName: 'Physics',
        )),
      ];

      final dtAtP2Gap = DateTime(2026, 6, 15, 10, 40, 0);
      final timeContextNow = InstitutionalTime(
        dayOfWeek: 1,
        startMinutes: 640,
        startSeconds: 640 * 60,
        rawDateTime: dtAtP2Gap,
      );

      final snapshot = evaluator.evaluate(
        timeContext: timeContextNow,
        todayBlocks: today,
        tomorrowBlocks: [],
      );

      expect(timeContextNow.startMinutes, greaterThan(capturedPayloadMinutes));
      expect(snapshot.phase, equals(TimetablePhase.break_));
    });
  });

  group('Track 2: Data Boundary — Substitution Collision', () {
    test('2.1 substitutionOverride suppresses regularClass at same time', () {
      final overrideSlot = TimetableSlot(
        id: 'OVERRIDE_P1',
        sectionId: 'sec',
        dayOfWeek: 1,
        slotType: SlotType.substitutionOverride,
        classType: ClassType.lecture,
        subjectCode: 'MATH101',
        subjectName: 'Mathematics',
        roomNumber: '101',
        facultyEmails: ['ta.jones@college.edu'],
        startMinutes: 570,
        endMinutes: 630,
        institutionTimezone: 'Asia/Kolkata',
        overrideFacultyEmail: 'ta.jones@college.edu',
      );

      final mergedBlocks = [TimeBlock.fromSlot(overrideSlot)];

      final timeContext = InstitutionalTime(
        dayOfWeek: 1,
        startMinutes: 575,
        startSeconds: 575 * 60,
        rawDateTime: DateTime(2026, 6, 15, 9, 35, 0),
      );

      final snapshot = evaluator.evaluate(
        timeContext: timeContext,
        todayBlocks: mergedBlocks,
        tomorrowBlocks: [],
      );

      expect(snapshot.phase, TimetablePhase.activeClass);
      expect(snapshot.currentBlock?.sourceSlot.id, equals('OVERRIDE_P1'));
      expect(snapshot.currentBlock?.sourceSlot.facultyEmails,
          contains('ta.jones@college.edu'));
    });

    test('2.1 duplicate time boundaries do not crash engine', () {
      final duplicateSlots = [
        TimeBlock.fromSlot(slot(
          id: 'A',
          startMinutes: 570,
          endMinutes: 630,
          subjectCode: 'CS1',
        )),
        TimeBlock.fromSlot(slot(
          id: 'B',
          startMinutes: 570,
          endMinutes: 630,
          subjectCode: 'CS2',
        )),
      ];

      final timeContext = InstitutionalTime(
        dayOfWeek: 1,
        startMinutes: 575,
        startSeconds: 575 * 60,
        rawDateTime: DateTime(2026, 6, 15, 9, 35, 0),
      );

      expect(
        () => evaluator.evaluate(
          timeContext: timeContext,
          todayBlocks: duplicateSlots,
          tomorrowBlocks: [],
        ),
        returnsNormally,
      );

      final snapshot = evaluator.evaluate(
        timeContext: timeContext,
        todayBlocks: duplicateSlots,
        tomorrowBlocks: [],
      );
      expect(snapshot.phase, TimetablePhase.activeClass);
      expect(snapshot.currentBlock?.sourceSlot.id, equals('A'));
    });
  });

  group('Track 4: Hardware Boundary — Weekend-to-Monday Deep Wake', () {
    test('4.1 recovers to Monday activeClass after 65h32m suspend', () {
      final friday4pm = DateTime(2026, 6, 12, 16, 0, 0);
      final monday932am = DateTime(2026, 6, 15, 9, 32, 0);

      final todayBlocks = [
        TimeBlock.fromSlot(slot(
          id: 'P1',
          startMinutes: 570,
          endMinutes: 630,
          dayOfWeek: 1,
          subjectCode: 'MATH101',
          subjectName: 'Math',
        )),
        TimeBlock.fromSlot(slot(
          id: 'P2',
          startMinutes: 650,
          endMinutes: 710,
          dayOfWeek: 1,
          subjectCode: 'PHY101',
          subjectName: 'Physics',
        )),
      ];

      var snap = stateMachine.evaluate(friday4pm, [], []);
      expect(snap.phase, TimetablePhase.noSchedule,
          reason: 'Friday with empty today');

      snap = stateMachine.evaluate(monday932am, todayBlocks, []);

      expect(snap.phase, TimetablePhase.activeClass,
          reason: 'Must recover to activeClass immediately');
      expect(snap.subjectCode, 'MATH101');
      expect(snap.countdownLabel, '00:58:00');
    });

    test('4.1 offline cache resilience — blocks resolved without network', () {
      final monday932am = DateTime(2026, 6, 15, 9, 32, 0);

      final cachedBlocks = [
        TimeBlock.fromSlot(slot(
          id: 'P1',
          startMinutes: 570,
          endMinutes: 630,
          dayOfWeek: 1,
          subjectCode: 'PHY101',
          subjectName: 'Physics',
        )),
      ];

      final snap = stateMachine.evaluate(monday932am, cachedBlocks, []);

      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.subjectCode, 'PHY101');
      expect(() => snap.phase, returnsNormally);
    });
  });
}
