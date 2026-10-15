import 'package:intelli_attend_shared/engine/time_source.dart';
import 'package:intelli_attend_shared/models/timetable_slot.dart';
import 'package:intelli_attend_shared/models/slot_type.dart';

/// A scriptable, deterministic [TimeSource] for chaos-engineering tests.
///
/// Separates the time base into two independent axes:
/// - [simulatedNetworkEpochMs] — the server-anchored monotonic epoch (source of truth).
/// - [simulatedDeviceDriftMs] — synthetic clock skew injected by the test to
///   simulate device timezone spoofing or hardware drift.
///
/// Together these produce [nowMs] and [nowUtc], but the critical override
/// [getInstitutionalTime] folds drift into the raw [DateTime] used downstream,
/// allowing tests to verify that the engine ignores client-side manipulation
/// and relies solely on the server epoch.
class ChaosTimeHarness implements TimeSource {
  /// Baseline epoch in ms, defaulting to a known Monday 2026-06-15 09:00 IST.
  int simulatedNetworkEpochMs = 1774861200000;

  /// Deliberate offset (ms) added to simulate device clock tampering.
  int simulatedDeviceDriftMs = 0;

  /// IANA timezone label used for display; does NOT affect epoch math.
  String simulatedDeviceTimezone = 'Asia/Kolkata';

  /// Advances the network epoch by [seconds] (forward or backward).
  void stepSeconds(int seconds) {
    simulatedNetworkEpochMs += (seconds * 1000);
  }

  /// Injects a static offset to simulate device-level clock drift.
  void injectDeviceDrift(int driftMs) {
    simulatedDeviceDriftMs = driftMs;
  }

  /// Overwrites the network epoch to an absolute millisecond value.
  void setEpochMs(int ms) {
    simulatedNetworkEpochMs = ms;
  }

  /// Composite wall-clock value (network + drift).
  int get nowMs => simulatedNetworkEpochMs + simulatedDeviceDriftMs;

  /// UTC [DateTime] representation of [nowMs].
  DateTime get nowUtc => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true);

  @override
  InstitutionalTime getInstitutionalTime(String locationName) {
    final effectiveMs = simulatedNetworkEpochMs + simulatedDeviceDriftMs;
    final dt = DateTime.fromMillisecondsSinceEpoch(effectiveMs);
    return InstitutionalTime(
      dayOfWeek: dt.weekday,
      startMinutes: dt.hour * 60 + dt.minute,
      startSeconds: dt.hour * 3600 + dt.minute * 60 + dt.second,
      rawDateTime: dt,
    );
  }
}

/// Shorthand factory for a fresh [ChaosTimeHarness] instance.
ChaosTimeHarness chaos() => ChaosTimeHarness();

/// Creates a [TimetableSlot] with sensible defaults for testing.
///
/// Only [id], [startMinutes] and [endMinutes] are required; all other
/// parameters default to values that keep boilerplate to a minimum while
/// remaining architecturally valid.
TimetableSlot slot({
  required String id,
  required int startMinutes,
  required int endMinutes,
  SlotType slotType = SlotType.regularClass,
  String subjectCode = 'CS101',
  String subjectName = 'Class',
  String roomNumber = 'R1',
  List<String> facultyEmails = const [],
  int dayOfWeek = 1,
  String? overrideFacultyEmail,
}) {
  return TimetableSlot(
    id: id,
    sectionId: '',
    dayOfWeek: dayOfWeek,
    slotType: slotType,
    classType: ClassType.lecture,
    subjectCode: subjectCode,
    subjectName: subjectName,
    roomNumber: roomNumber,
    facultyEmails: facultyEmails,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    institutionTimezone: 'Asia/Kolkata',
    overrideFacultyEmail: overrideFacultyEmail,
  );
}
