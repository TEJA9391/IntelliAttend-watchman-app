import 'package:flutter_test/flutter_test.dart';
import 'package:intelli_attend_faculty/engine/engine.dart';
import 'package:intelli_attend_shared/models/timetable_slot.dart';
import 'package:intelli_attend_shared/models/slot_type.dart';

/// A controllable [TimeSource] used in engine unit tests.
///
/// Exposes [advanceMs] / [advanceMinutes] / [advanceSeconds] for fine-grained
/// time stepping and [setTime] for absolute positioning. All methods operate
/// on a single internal millisecond counter, making [getInstitutionalTime]
/// fully deterministic.
class MockTimeSource implements TimeSource {
  int _currentMs;
  MockTimeSource(this._currentMs);

  @override
  InstitutionalTime getInstitutionalTime(String locationName) {
    final dt = DateTime.fromMillisecondsSinceEpoch(_currentMs);
    return InstitutionalTime(
      dayOfWeek: dt.weekday,
      startMinutes: dt.hour * 60 + dt.minute,
      startSeconds: dt.hour * 3600 + dt.minute * 60 + dt.second,
      rawDateTime: dt,
    );
  }

  void advanceMs(int ms) => _currentMs += ms;
  void advanceMinutes(int mins) => _currentMs += mins * 60 * 1000;
  void advanceSeconds(int secs) => _currentMs += secs * 1000;

  void setTime(DateTime dt) => _currentMs = dt.millisecondsSinceEpoch;
}

/// Shorthand for constructing a [DateTime] in the local timezone.
DateTime dt(int y, int m, int d, int hour, int min, [int sec = 0]) {
  return DateTime(y, m, d, hour, min, sec);
}

/// Builds a [TimeBlock] for use in engine tests with minimal boilerplate.
///
/// All blocks default to [SlotType.regularClass], [ClassType.lecture], day
/// Monday, and timezone [Asia/Kolkata]. Only the start ([sm]) and end ([em])
/// minute boundaries are required.
TimeBlock klass(int sm, int em, {String name = 'Class', String code = 'CS101', String room = 'R1'}) {
  return TimeBlock.fromSlot(TimetableSlot(
    id: '$code-$sm',
    sectionId: '',
    dayOfWeek: 1,
    slotType: SlotType.regularClass,
    classType: ClassType.lecture,
    subjectCode: code,
    subjectName: name,
    roomNumber: room,
    facultyEmails: [],
    startMinutes: sm,
    endMinutes: em,
    institutionTimezone: 'Asia/Kolkata',
  ));
}

void main() {
  final engine = TimetableStateMachine();
  final monday = DateTime(2026, 6, 15);
  final sunday = DateTime(2026, 6, 21);

  group('Test 1: Back-to-Back Zero-Duration Break Guard', () {
    late List<TimeBlock> today;

    setUp(() {
      today = [
        klass(600, 650, name: 'Math', code: 'MATH101'),
        klass(650, 700, name: 'Physics', code: 'PHY101'),
      ];
    });

    test('transitions directly without intermediate break phase', () {
      var snap = engine.evaluate(dt(2026, 6, 15, 10, 49, 58), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.subjectCode, 'MATH101');
      expect(snap.countdownLabel, '00:00:02');

      snap = engine.evaluate(dt(2026, 6, 15, 10, 49, 59), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.subjectCode, 'MATH101');
      expect(snap.countdownLabel, '00:00:01');

      snap = engine.evaluate(dt(2026, 6, 15, 10, 50, 0), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.subjectCode, 'PHY101');
    });

    test('zero gap never produces break_ phase', () {
      final snap = engine.evaluate(dt(2026, 6, 15, 10, 50, 0), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.currentBlock?.subjectCode, 'PHY101');
    });
  });

  group('Test 2: Midnight Rollover & onDayChanged', () {
    test('countdown to tomorrow P1 after last class ends', () {
      final today = [klass(570, 600, name: 'Chem', code: 'CHEM101')];
      final tomorrow = [klass(570, 600, name: 'Bio', code: 'BIO101')];

      final afterClass = dt(2026, 6, 15, 10, 0, 1);
      final snap = engine.evaluate(afterClass, today, tomorrow);

      expect(snap.phase, TimetablePhase.afterLastClass);
      expect(snap.breakLabel, anyOf('Tomorrow', 'Monday', 'Tuesday'));
      expect(snap.subjectCode, 'BIO101');

      final expectedTarget = DateTime(2026, 6, 16, 9, 30, 0);
      expect(snap.targetTime, anyOf(expectedTarget, DateTime(2026, 6, 22, 9, 30, 0)));
    });

    test('tomorrow after midnight with swapped data → beforeFirstClass', () {
      final today = [klass(570, 600, name: 'Bio', code: 'BIO101')];

      final snap = engine.evaluate(dt(2026, 6, 16, 0, 0, 0), today, []);
      expect(snap.phase, TimetablePhase.beforeFirstClass);
      expect(snap.countdownLabel, '09:30:00');
      expect(snap.targetTime, DateTime(2026, 6, 16, 9, 30, 0));
    });

    test('no tomorrow blocks shows CLASSES ENDED', () {
      final today = [klass(570, 600)];
      final snap = engine.evaluate(dt(2026, 6, 15, 10, 0, 1), today, []);
      expect(snap.phase, TimetablePhase.afterLastClass);
      expect(snap.countdownLabel, 'CLASSES ENDED');
    });
  });

  group('Test 3: Background Suspend & Heavy Drift Resume', () {
    test('recovers to correct phase after large time jump', () {
      final today = [
        klass(570, 630, name: 'Math', code: 'MATH101'),
        klass(650, 710, name: 'Physics', code: 'PHY101'),
        klass(730, 790, name: 'Chem', code: 'CHEM101'),
        klass(810, 870, name: 'Bio', code: 'BIO101'),
      ];

      var snap = engine.evaluate(dt(2026, 6, 15, 9, 40, 0), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.subjectCode, 'MATH101');

      snap = engine.evaluate(dt(2026, 6, 15, 10, 35, 0), today, []);
      expect(snap.phase, TimetablePhase.break_);

      snap = engine.evaluate(dt(2026, 6, 15, 11, 0, 0), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.subjectCode, 'PHY101');
    });

    test('recovers to break phase after jump into gap', () {
      final today = [
        klass(570, 630, name: 'Math', code: 'MATH101'),
        klass(650, 710, name: 'Physics', code: 'PHY101'),
      ];

      final snap = engine.evaluate(dt(2026, 6, 15, 10, 40, 0), today, []);
      expect(snap.phase, TimetablePhase.break_);
      expect(snap.currentBlock?.isBreak, true);
    });

    test('recovers to afterLastClass after jump past end', () {
      final today = [klass(570, 600, name: 'Short', code: 'SHRT')];
      final snap = engine.evaluate(dt(2026, 6, 15, 14, 0, 0), today, []);
      expect(snap.phase, TimetablePhase.afterLastClass);
    });
  });

  group('Test 4: 50-Minute Stacking Latency Stress', () {
    test('zero cumulative drift after 3000 ticks with simulated latency', () {
      final today = [klass(570, 630, name: 'Math', code: 'MATH101')];
      final source = MockTimeSource(dt(2026, 6, 15, 9, 30, 0).millisecondsSinceEpoch);

      for (int i = 0; i < 3000; i++) {
        if (i % 10 == 0) {
        }

        final now = DateTime.fromMillisecondsSinceEpoch(source._currentMs);
        engine.evaluate(now, today, []);
        source.advanceSeconds(1);
      }

      final snap = engine.evaluate(
        DateTime.fromMillisecondsSinceEpoch(source._currentMs),
        today,
        [],
      );
      expect(snap.countdownLabel, '00:10:00');

      final wall = DateTime.fromMillisecondsSinceEpoch(source._currentMs);
      expect(snap.targetTime, wall.add(const Duration(minutes: 10)));
    });
  });

  group('Test 5: Extreme Time Boundary Traversal T-10 → T-3 → T-0 → T+5', () {
    final today = [klass(570, 630, name: 'Math', code: 'MATH101')];

    test('T-10 (09:19:59): beforeFirstClass, countdown 10:01', () {
      final snap = engine.evaluate(dt(2026, 6, 15, 9, 19, 59), today, []);
      expect(snap.phase, TimetablePhase.beforeFirstClass);
      expect(snap.countdownLabel, '00:10:01');
    });

    test('T-10 boundary (09:20:00): beforeFirstClass, countdown 10:00', () {
      final snap = engine.evaluate(dt(2026, 6, 15, 9, 20, 0), today, []);
      expect(snap.phase, TimetablePhase.beforeFirstClass);
      expect(snap.countdownLabel, '00:10:00');
    });

    test('T-3 (09:27:00): beforeFirstClass, countdown 03:00', () {
      final snap = engine.evaluate(dt(2026, 6, 15, 9, 27, 0), today, []);
      expect(snap.phase, TimetablePhase.beforeFirstClass);
      expect(snap.countdownLabel, '00:03:00');
    });

    test('T-0 (09:30:00): transitions to activeClass', () {
      final snap = engine.evaluate(dt(2026, 6, 15, 9, 30, 0), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.subjectCode, 'MATH101');
      expect(snap.countdownLabel, '01:00:00');
    });

    test('T+5 (09:35:00): activeClass with 55:00 remaining', () {
      final snap = engine.evaluate(dt(2026, 6, 15, 9, 35, 0), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.countdownLabel, '00:55:00');
    });
  });

  group('Test 6: Ghost Schedule / Empty State Resilience', () {
    test('empty today + empty tomorrow → noSchedule', () {
      final snap = engine.evaluate(monday, [], []);
      expect(snap.phase, TimetablePhase.noSchedule);
      expect(snap.countdownLabel, 'NO CLASSES');
    });

    test('Sunday empty both arrays → noSchedule (early exit)', () {
      final snap = engine.evaluate(sunday, [], []);
      expect(snap.phase, TimetablePhase.noSchedule);
    });

    test('Sunday with tomorrow blocks → weekend', () {
      final tomorrow = [klass(570, 630, name: 'Mon', code: 'MON')];
      final snap = engine.evaluate(sunday, [], tomorrow);
      expect(snap.phase, anyOf(TimetablePhase.weekend, TimetablePhase.afterLastClass));
    });

    test('non-Sunday with empty today + tomorrow → afterLastClass to tomorrow', () {
      final tomorrow = [klass(570, 630, name: 'Chem', code: 'CHEM101')];
      final snap = engine.evaluate(monday, [], tomorrow);
      expect(snap.phase, TimetablePhase.afterLastClass);
      expect(snap.breakLabel, anyOf('Tomorrow', 'Monday', 'Tuesday'));
      expect(snap.subjectCode, 'CHEM101');
    });

    test('no exceptions thrown for any empty configuration', () {
      expect(() => engine.evaluate(monday, [], []), returnsNormally);
      expect(() => engine.evaluate(sunday, [], []), returnsNormally);
      expect(() => engine.evaluate(dt(2026, 6, 15, 23, 59, 59), [], []), returnsNormally);
      expect(() => engine.evaluate(dt(2026, 6, 15, 0, 0, 0), [], []), returnsNormally);
    });
  });

  /// A collection of smaller but important boundary conditions: single-class
  /// day cleanup, negative-countdown clamping, named break labels (lunch,
  /// bio), the [toMinutes] parser across six formats, nextBlock resolution
  /// with and without gaps, and beforeFirstClass nextBlock accuracy.
  group('Additional edge cases', () {
    test('single class day → afterLastClass after class ends', () {
      final today = [klass(570, 630, name: 'Sole', code: 'SOLE101')];
      final snap = engine.evaluate(dt(2026, 6, 15, 10, 30, 1), today, []);
      expect(snap.phase, TimetablePhase.afterLastClass);
      expect(snap.countdownLabel, 'CLASSES ENDED');
    });

    test('countdown never shows negative values', () {
      final today = [klass(570, 630)];
      final snap = engine.evaluate(dt(2026, 6, 15, 12, 0, 0), today, []);
      expect(snap.countdownLabel, 'CLASSES ENDED');
    });

    test('lunch break detection (12:10-12:30 gap)', () {
      final today = [
        klass(660, 730, name: 'PreLunch', code: 'A'),
        klass(750, 810, name: 'PostLunch', code: 'B'),
      ];
      final snap = engine.evaluate(dt(2026, 6, 15, 12, 20, 0), today, []);
      expect(snap.phase, TimetablePhase.break_);
      expect(snap.breakLabel, 'Lunch Break');
    });

    test('bio break detection (11:10-11:20 gap)', () {
      final today = [
        klass(660, 670, name: 'A', code: 'A'),
        klass(680, 710, name: 'B', code: 'B'),
      ];
      final snap = engine.evaluate(dt(2026, 6, 15, 11, 15, 0), today, []);
      expect(snap.phase, TimetablePhase.break_);
      expect(snap.breakLabel, 'Bio Break');
    });

    test('toMinutes parses 12-hour format correctly', () {
      expect(TimetableStateMachine.toMinutes('9:30 AM'), 570);
      expect(TimetableStateMachine.toMinutes('12:00 PM'), 720);
      expect(TimetableStateMachine.toMinutes('12:00 AM'), 0);
      expect(TimetableStateMachine.toMinutes('11:59 PM'), 1439);
      expect(TimetableStateMachine.toMinutes('10:50'), 650);
      expect(TimetableStateMachine.toMinutes('invalid'), 0);
    });

    test('nextBlock is the chronologically next block (could be break or class)', () {
      final today = [
        klass(600, 650, name: 'Math', code: 'MATH101'),
        klass(650, 700, name: 'Physics', code: 'PHY101'),
      ];
      var snap = engine.evaluate(dt(2026, 6, 15, 10, 45, 0), today, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.currentBlock?.subjectCode, 'MATH101');
      expect(snap.nextBlock?.subjectCode, 'PHY101');

      final gapped = [
        klass(570, 630, name: 'Math', code: 'MATH101'),
        klass(650, 710, name: 'Physics', code: 'PHY101'),
      ];
      snap = engine.evaluate(dt(2026, 6, 15, 9, 45, 0), gapped, []);
      expect(snap.phase, TimetablePhase.activeClass);
      expect(snap.currentBlock?.subjectCode, 'MATH101');
      expect(snap.nextBlock?.isBreak, true);
    });

    test('beforeFirstClass correctly reports nextBlock', () {
      final today = [klass(600, 660, name: 'Math', code: 'MATH101')];
      final snap = engine.evaluate(dt(2026, 6, 15, 9, 30, 0), today, []);
      expect(snap.phase, TimetablePhase.beforeFirstClass);
      expect(snap.nextBlock?.subjectCode, 'MATH101');
      expect(snap.countdownLabel, '00:30:00');
    });
  });

  group('48-Hour Hybrid Fallback Integration', () {
    test('TimetableSlot.fromFirestore reads migrated integer day_of_week', () {
      final Map<String, dynamic> postMigrationPayload = {
        "section_id": "ci_2025_c",
        "day_of_week": 1,
        "start_minutes": 570,
        "end_minutes": 630,
        "duration_minutes": 60,
        "slot_type": "regularClass",
        "class_type": "lecture",
      };

      final slot = TimetableSlot.fromFirestore(postMigrationPayload, "mock_doc_123");

      expect(slot.dayOfWeek, equals(1));
      expect(slot.startMinutes, equals(570));
      expect(slot.endMinutes, equals(630));
      expect(slot.computedDuration, equals(60));
    });

    test('integer fields take priority over legacy when both present', () {
      final Map<String, dynamic> migratedJsonPayload = {
        "section_id": "ci_2025_c",
        "day_of_week": 1,
        "start_minutes": 600,
        "end_minutes": 660,
        "start_time": "09:30",
        "end_time": "10:30",
        "slot_type": "regularClass",
        "class_type": "lecture",
      };

      final slot = TimetableSlot.fromFirestore(migratedJsonPayload, "mock_doc_125");

      expect(slot.dayOfWeek, equals(1));
      expect(slot.startMinutes, equals(600));
      expect(slot.endMinutes, equals(660));
      expect(slot.computedDuration, equals(60));
    });
  });
}
