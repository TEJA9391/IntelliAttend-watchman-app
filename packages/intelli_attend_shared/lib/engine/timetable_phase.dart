enum TimetablePhase {
  beforeFirstClass,
  activeClass,
  break_,
  afterLastClass,
  weekend,
  noSchedule;

  bool get isActiveClass => this == TimetablePhase.activeClass;
  bool get isBreak => this == TimetablePhase.break_;
  bool get isAfterLastClass => this == TimetablePhase.afterLastClass;
  bool get isBeforeFirstClass => this == TimetablePhase.beforeFirstClass;
  bool get isWeekend => this == TimetablePhase.weekend;
  bool get isNoSchedule => this == TimetablePhase.noSchedule;
}
