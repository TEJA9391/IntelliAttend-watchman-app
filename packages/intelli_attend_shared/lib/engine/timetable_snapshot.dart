import 'time_block.dart';
import 'timetable_phase.dart';

class TimetableSnapshot {
  final TimetablePhase phase;
  final String? subjectName;
  final String? subjectCode;
  final String? roomNumber;
  final Duration countdown;
  final String countdownLabel;
  final String? breakLabel;
  final DateTime targetTime;
  final TimeBlock? currentBlock;
  final TimeBlock? nextBlock;

  const TimetableSnapshot({
    required this.phase,
    this.subjectName,
    this.subjectCode,
    this.roomNumber,
    this.countdown = Duration.zero,
    this.countdownLabel = '--:--',
    this.breakLabel,
    required this.targetTime,
    this.currentBlock,
    this.nextBlock,
  });

  bool get isClassActive => phase.isActiveClass;
  bool get isBreak => phase.isBreak;
  bool get isAfterLastClass => phase.isAfterLastClass;
  bool get isBeforeFirstClass => phase.isBeforeFirstClass;
  bool get isWeekend => phase.isWeekend;
  bool get isNoSchedule => phase.isNoSchedule;

  factory TimetableSnapshot.initial() => TimetableSnapshot(
        phase: TimetablePhase.noSchedule,
        targetTime: DateTime.now(),
        countdownLabel: '--:--',
      );

  factory TimetableSnapshot.empty() => TimetableSnapshot(
        phase: TimetablePhase.noSchedule,
        targetTime: DateTime.now(),
        countdownLabel: 'NO CLASSES',
      );

  factory TimetableSnapshot.active({
    required TimeBlock currentBlock,
    TimeBlock? nextBlock,
    required Duration remainingDuration,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final isClass = !currentBlock.isBreak;
    return TimetableSnapshot(
      phase: isClass ? TimetablePhase.activeClass : TimetablePhase.break_,
      subjectName: currentBlock.subjectName ?? currentBlock.breakLabel,
      subjectCode: currentBlock.subjectCode,
      roomNumber: currentBlock.roomNumber,
      countdown: remainingDuration,
      countdownLabel: _formatCountdown(remainingDuration.inSeconds),
      breakLabel: isClass ? null : currentBlock.breakLabel,
      targetTime: now.add(remainingDuration),
      currentBlock: currentBlock,
      nextBlock: nextBlock,
    );
  }

  factory TimetableSnapshot.waiting({
    required TimeBlock nextBlock,
    required Duration remainingDuration,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    return TimetableSnapshot(
      phase: TimetablePhase.beforeFirstClass,
      subjectName: nextBlock.subjectName,
      subjectCode: nextBlock.subjectCode,
      roomNumber: nextBlock.roomNumber,
      countdown: remainingDuration,
      countdownLabel: _formatCountdown(remainingDuration.inSeconds),
      breakLabel: 'Classes start at',
      targetTime: now.add(remainingDuration),
      nextBlock: nextBlock,
    );
  }

  factory TimetableSnapshot.tomorrow({
    required TimeBlock nextBlock,
    required Duration remainingDuration,
    String? breakLabel,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    return TimetableSnapshot(
      phase: TimetablePhase.afterLastClass,
      subjectName: nextBlock.subjectName,
      subjectCode: nextBlock.subjectCode,
      countdown: remainingDuration,
      countdownLabel: _formatCountdown(remainingDuration.inSeconds),
      breakLabel: breakLabel ?? 'Tomorrow',
      targetTime: now.add(remainingDuration),
      nextBlock: nextBlock,
    );
  }

  factory TimetableSnapshot.ended({DateTime? asOf}) => TimetableSnapshot(
        phase: TimetablePhase.afterLastClass,
        countdownLabel: 'CLASSES ENDED',
        targetTime: asOf ?? DateTime.now(),
        breakLabel: 'Classes ended for today',
      );

  factory TimetableSnapshot.weekend({DateTime? asOf}) => TimetableSnapshot(
        phase: TimetablePhase.weekend,
        countdownLabel: 'HAPPY SUNDAY',
        targetTime: asOf ?? DateTime.now(),
        breakLabel: 'Happy Sunday',
      );

  static String _formatCountdown(int totalSeconds) {
    if (totalSeconds < 0) return '00:00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}'
        ':${minutes.toString().padLeft(2, '0')}'
        ':${seconds.toString().padLeft(2, '0')}';
  }
}
