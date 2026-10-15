import '../models/slot_type.dart';
import '../models/timetable_slot.dart';
import 'time_source.dart';
import 'time_block.dart';
import 'timetable_snapshot.dart';

class TimetableEvaluator {
  const TimetableEvaluator();

  TimetableSnapshot evaluate({
    required InstitutionalTime timeContext,
    required List<TimeBlock> todayBlocks,
    required List<TimeBlock> tomorrowBlocks,
  }) {
    if (todayBlocks.isEmpty && tomorrowBlocks.isEmpty) {
      return TimetableSnapshot.empty();
    }

    final currentMins = timeContext.startMinutes;
    final currentSecs = timeContext.startSeconds;

    if (todayBlocks.isEmpty) {
      return _buildOfflineSnapshot(timeContext, tomorrowBlocks);
    }

    for (int i = 0; i < todayBlocks.length; i++) {
      final block = todayBlocks[i];
      if (block.contains(currentMins)) {
        final remaining = Duration(
          seconds: block.countdownSecondsAt(currentSecs),
        );
        TimeBlock? next = i + 1 < todayBlocks.length ? todayBlocks[i + 1] : null;
        if (next != null && block.endMinutes < next.startMinutes) {
          next = _buildImplicitBreak(
            block.endMinutes,
            next.startMinutes,
            block.id,
            next.id,
            timeContext.dayOfWeek,
          );
        }
        return TimetableSnapshot.active(
          currentBlock: block,
          nextBlock: next,
          remainingDuration: remaining,
          asOf: timeContext.rawDateTime,
        );
      }
    }

    final firstBlock = todayBlocks.first;
    final lastBlock = todayBlocks.last;

    if (currentMins < firstBlock.startMinutes) {
      final remaining = Duration(
        seconds: (firstBlock.startMinutes * 60) - currentSecs,
      );
      return TimetableSnapshot.waiting(
        nextBlock: firstBlock,
        remainingDuration: remaining,
        asOf: timeContext.rawDateTime,
      );
    }

    if (currentMins >= lastBlock.endMinutes) {
      return _buildTomorrowCountdown(timeContext, tomorrowBlocks);
    }

    return _buildGapBreak(timeContext, todayBlocks, currentMins, currentSecs);
  }

  TimeBlock _buildImplicitBreak(
    int gapStart,
    int gapEnd,
    String prevId,
    String nextId,
    int dayOfWeek,
  ) {
    return TimeBlock.fromSlot(TimetableSlot(
      id: 'implicit_gap_${prevId}_$nextId',
      sectionId: '',
      dayOfWeek: dayOfWeek,
      slotType: SlotType.institutionalBreak,
      classType: ClassType.administrative,
      subjectCode: '',
      subjectName: '',
      roomNumber: '',
      facultyEmails: [],
      startMinutes: gapStart,
      endMinutes: gapEnd,
      durationMinutes: gapEnd - gapStart,
      institutionTimezone: 'Asia/Kolkata',
      breakLabel: _detectBreakLabel(gapStart, gapEnd),
    ));
  }

  TimetableSnapshot _buildGapBreak(
    InstitutionalTime timeContext,
    List<TimeBlock> todayBlocks,
    int currentMins,
    int currentSecs,
  ) {
    TimeBlock? prevBlock;
    TimeBlock? nextBlock;

    for (int i = 0; i < todayBlocks.length; i++) {
      final b = todayBlocks[i];
      if (currentMins < b.startMinutes) {
        prevBlock = i > 0 ? todayBlocks[i - 1] : null;
        nextBlock = b;
        break;
      }
    }

    if (prevBlock == null || nextBlock == null) {
      return _buildTomorrowCountdown(timeContext, []);
    }

    final gapStart = prevBlock.endMinutes;
    final gapEnd = nextBlock.startMinutes;
    final gapBlock = _buildImplicitBreak(
      gapStart,
      gapEnd,
      prevBlock.id,
      nextBlock.id,
      timeContext.dayOfWeek,
    );

    final remaining = Duration(
      seconds: (gapEnd * 60) - currentSecs,
    );

    return TimetableSnapshot.active(
      currentBlock: gapBlock,
      nextBlock: nextBlock,
      remainingDuration: remaining,
      asOf: timeContext.rawDateTime,
    );
  }

  String _detectBreakLabel(int gapStartMinutes, int gapEndMinutes) {
    if (gapStartMinutes >= 730 && gapEndMinutes <= 750) {
      return 'Lunch Break';
    }
    if (gapStartMinutes >= 670 && gapEndMinutes <= 680) {
      return 'Bio Break';
    }
    return 'Break';
  }

  TimetableSnapshot _buildOfflineSnapshot(
    InstitutionalTime timeContext,
    List<TimeBlock> tomorrowBlocks,
  ) {
    if (tomorrowBlocks.isNotEmpty) {
      return _buildTomorrowCountdown(timeContext, tomorrowBlocks);
    }
    if (timeContext.dayOfWeek == 7) {
      return TimetableSnapshot.weekend(asOf: timeContext.rawDateTime);
    }
    return TimetableSnapshot.ended(asOf: timeContext.rawDateTime);
  }

  TimetableSnapshot _buildTomorrowCountdown(
    InstitutionalTime timeContext,
    List<TimeBlock> tomorrowBlocks,
  ) {
    if (tomorrowBlocks.isEmpty) {
      return TimetableSnapshot.ended(asOf: timeContext.rawDateTime);
    }

    final firstTomorrow = tomorrowBlocks.first;
    final currentSecs = timeContext.startSeconds;
    final tomorrowStartSecs = firstTomorrow.startMinutes * 60;

    final nextDayOfWeek = firstTomorrow.sourceSlot.dayOfWeek;
    final todayDayOfWeek = timeContext.dayOfWeek;
    int daysAhead = nextDayOfWeek - todayDayOfWeek;
    if (daysAhead <= 0) daysAhead += 7;

    final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    final remainingSeconds = (daysAhead - 1) * 86400 +
        ((86400 - currentSecs) + tomorrowStartSecs);

    final label = daysAhead == 1 ? 'Tomorrow' : dayNames[nextDayOfWeek];

    return TimetableSnapshot.tomorrow(
      nextBlock: firstTomorrow,
      remainingDuration: Duration(
        seconds: remainingSeconds.clamp(0, 7 * 86400),
      ),
      breakLabel: label,
      asOf: timeContext.rawDateTime,
    );
  }
}
