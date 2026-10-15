import 'package:intelli_attend_shared/engine/time_source.dart';
export 'package:intelli_attend_shared/engine/time_source.dart';

/// Legacy [SystemClockTimeSource] using device wall clock.
/// Prefer [SyncedClockSource] for production use.
class SystemClockTimeSource implements TimeSource {
  @override
  InstitutionalTime getInstitutionalTime(String locationName) {
    return const SyncedClockSource(
      nowMsProvider: _deviceNowMs,
    ).getInstitutionalTime(locationName);
  }
}

int _deviceNowMs() => DateTime.now().millisecondsSinceEpoch;
