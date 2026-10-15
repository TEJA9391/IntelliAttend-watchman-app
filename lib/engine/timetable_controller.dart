import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intelli_attend_shared/engine/time_source.dart';
import 'package:intelli_attend_shared/engine/time_block.dart';
import 'package:intelli_attend_shared/engine/timetable_phase.dart';
import 'package:intelli_attend_shared/engine/timetable_snapshot.dart';
import 'package:intelli_attend_shared/engine/timetable_evaluator.dart';

class TimetableController extends ChangeNotifier with WidgetsBindingObserver {
  final TimeSource timeSource;
  final String institutionTimezone;
  final TimetableEvaluator _evaluator = const TimetableEvaluator();
  Timer? _timer;

  List<TimeBlock> _todayBlocks = [];
  List<TimeBlock> _tomorrowBlocks = [];
  TimetableSnapshot _snapshot = TimetableSnapshot.initial();
  int? _lastEvaluatedDay;

  VoidCallback? onDayChanged;

  TimetableSnapshot get snapshot => _snapshot;
  List<TimeBlock> get todayBlocks => _todayBlocks;
  List<TimeBlock> get tomorrowBlocks => _tomorrowBlocks;

  TimetableController({
    required this.timeSource,
    this.institutionTimezone = 'Asia/Kolkata',
  }) {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void updateBlocks(List<TimeBlock> today, List<TimeBlock> tomorrow) {
    _todayBlocks = today;
    _tomorrowBlocks = tomorrow;
    _evaluateAndNotify();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _evaluateAndNotify();
    });
  }

  void _evaluateAndNotify() {
    final InstitutionalTime timeContext;
    try {
      timeContext = timeSource.getInstitutionalTime(institutionTimezone);
    } catch (_) {
      return;
    }

    if (_lastEvaluatedDay != null &&
        timeContext.dayOfWeek != _lastEvaluatedDay) {
      _lastEvaluatedDay = timeContext.dayOfWeek;
      onDayChanged?.call();
    }
    _lastEvaluatedDay ??= timeContext.dayOfWeek;

    final newSnapshot = _evaluator.evaluate(
      timeContext: timeContext,
      todayBlocks: _todayBlocks,
      tomorrowBlocks: _tomorrowBlocks,
    );

    if (!_snapshotsEqual(_snapshot, newSnapshot)) {
      _snapshot = newSnapshot;
      notifyListeners();
    }
  }

  bool _snapshotsEqual(TimetableSnapshot a, TimetableSnapshot b) {
    return a.phase == b.phase &&
        a.subjectName == b.subjectName &&
        a.subjectCode == b.subjectCode &&
        a.roomNumber == b.roomNumber &&
        a.countdownLabel == b.countdownLabel &&
        a.breakLabel == b.breakLabel &&
        a.currentBlock?.startMinutes == b.currentBlock?.startMinutes &&
        a.currentBlock?.endMinutes == b.currentBlock?.endMinutes &&
        a.nextBlock?.startMinutes == b.nextBlock?.startMinutes;
  }

  void forceReevaluate() {
    _evaluateAndNotify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      forceReevaluate();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
