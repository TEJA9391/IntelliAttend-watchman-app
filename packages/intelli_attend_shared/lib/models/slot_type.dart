enum SlotType {
  regularClass,
  institutionalBreak,
  substitutionOverride;

  String get wire => name;
  static SlotType fromWire(String value) =>
      SlotType.values.firstWhere((e) => e.name == value, orElse: () => SlotType.regularClass);
}

enum ClassType {
  lecture,
  lab,
  tutorial,
  administrative;

  String get wire => name;
  static ClassType fromWire(String value) =>
      ClassType.values.firstWhere((e) => e.name == value, orElse: () => ClassType.lecture);
}
