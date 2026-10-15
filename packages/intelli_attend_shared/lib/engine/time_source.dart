import 'package:timezone/timezone.dart' as tz;

class InstitutionalTime {
  final int dayOfWeek;
  final int startMinutes;
  final int startSeconds;
  final DateTime rawDateTime;

  const InstitutionalTime({
    required this.dayOfWeek,
    required this.startMinutes,
    required this.startSeconds,
    required this.rawDateTime,
  });
}

abstract class TimeSource {
  InstitutionalTime getInstitutionalTime(String locationName);
}

class SyncedClockSource implements TimeSource {
  final int Function() nowMsProvider;

  const SyncedClockSource({required this.nowMsProvider});

  @override
  InstitutionalTime getInstitutionalTime(String locationName) {
    final networkEpochMs = nowMsProvider();
    try {
      final location = tz.getLocation(locationName);
      final tzDateTime = tz.TZDateTime.fromMillisecondsSinceEpoch(location, networkEpochMs);

      return InstitutionalTime(
        dayOfWeek: tzDateTime.weekday,
        startMinutes: (tzDateTime.hour * 60) + tzDateTime.minute,
        startSeconds: (tzDateTime.hour * 3600) + (tzDateTime.minute * 60) + tzDateTime.second,
        rawDateTime: tzDateTime,
      );
    } catch (_) {
      final dt = DateTime.fromMillisecondsSinceEpoch(networkEpochMs, isUtc: true).toLocal();
      return InstitutionalTime(
        dayOfWeek: dt.weekday,
        startMinutes: (dt.hour * 60) + dt.minute,
        startSeconds: (dt.hour * 3600) + (dt.minute * 60) + dt.second,
        rawDateTime: dt,
      );
    }
  }
}
