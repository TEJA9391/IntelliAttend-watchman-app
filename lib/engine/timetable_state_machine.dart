import 'package:intelli_attend_shared/engine/time_source.dart';
import 'package:intelli_attend_shared/engine/time_block.dart';
import 'package:intelli_attend_shared/engine/timetable_phase.dart';
import 'package:intelli_attend_shared/engine/timetable_snapshot.dart';
import 'package:intelli_attend_shared/engine/timetable_evaluator.dart';

/// Legacy wrapper. New code should use [TimetableEvaluator] directly.
class TimetableStateMachine {
  final TimetableEvaluator _evaluator = const TimetableEvaluator();

  TimetableSnapshot evaluate(
    DateTime now,
    List<TimeBlock> todayBlocks,
    List<TimeBlock> tomorrowBlocks,
  ) {
    final timeContext = InstitutionalTime(
      dayOfWeek: now.weekday,
      startMinutes: now.hour * 60 + now.minute,
      startSeconds: now.hour * 3600 + now.minute * 60 + now.second,
      rawDateTime: now,
    );
    return _evaluator.evaluate(
      timeContext: timeContext,
      todayBlocks: todayBlocks,
      tomorrowBlocks: tomorrowBlocks,
    );
  }

  @Deprecated('Use TimetableSlot.startMinutes / endMinutes instead')
  static int toMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      if (parts.length > 1) {
        final meridian = parts[1].toUpperCase();
        if (meridian == 'PM' && hour < 12) hour += 12;
        if (meridian == 'AM' && hour == 12) hour = 0;
      }
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }
}
