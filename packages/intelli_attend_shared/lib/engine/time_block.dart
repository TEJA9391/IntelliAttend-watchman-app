import '../models/timetable_slot.dart';

class TimeBlock {
  final TimetableSlot sourceSlot;

  const TimeBlock({required this.sourceSlot});

  String get id => sourceSlot.id;
  bool get isBreak => sourceSlot.isBreak;
  int get startMinutes => sourceSlot.startMinutes;
  int get endMinutes => sourceSlot.endMinutes;
  int get durationMinutes => sourceSlot.computedDuration;
  String? get subjectCode => sourceSlot.isBreak ? null : sourceSlot.subjectCode;
  String? get subjectName => sourceSlot.isBreak ? null : sourceSlot.subjectName;
  String? get roomNumber => sourceSlot.isBreak ? null : sourceSlot.roomNumber;
  String? get breakLabel => sourceSlot.isBreak ? (sourceSlot.breakLabel ?? 'Break') : null;

  bool contains(int currentMinutes) =>
      currentMinutes >= startMinutes && currentMinutes < endMinutes;

  int countdownSecondsAt(int currentSeconds) =>
      (endMinutes * 60) - currentSeconds;

  factory TimeBlock.fromSlot(TimetableSlot slot) => TimeBlock(sourceSlot: slot);
}
