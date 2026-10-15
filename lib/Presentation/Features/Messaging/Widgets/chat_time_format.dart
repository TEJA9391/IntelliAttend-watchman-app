import 'package:intl/intl.dart';

/// Centralized time formatting for the chat UI (WhatsApp-style).
class ChatTimeFormat {
  ChatTimeFormat._();

  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _dayFormat = DateFormat('EEEE');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _fullFormat = DateFormat('dd/MM/yyyy, h:mm a');
  static final DateFormat _shortDateFormat = DateFormat('dd MMM');

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Clock time for message bubbles: "2:15 PM".
  static String bubbleTime(DateTime time) => _timeFormat.format(time.toLocal());

  /// Conversation-list timestamp: time if today, "Yesterday", weekday,
  /// otherwise a short date.
  static String listTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    if (isSameDay(local, now)) return _timeFormat.format(local);
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(local, yesterday)) return 'Yesterday';
    if (now.difference(local).inDays < 7) return _dayFormat.format(local);
    if (local.year == now.year) return _shortDateFormat.format(local);
    return _dateFormat.format(local);
  }

  /// Full timestamp used in Message Info.
  static String full(DateTime time) => _fullFormat.format(time.toLocal());

  /// Date-separator label in the message list.
  static String dateSeparator(DateTime time) {
    final local = time.toLocal();
    final now = DateTime.now();
    if (isSameDay(local, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(local, yesterday)) return 'Yesterday';
    if (now.difference(local).inDays < 7) return _dayFormat.format(local);
    return _dateFormat.format(local);
  }

  /// "Last seen today at 2:15 PM" / "Last seen yesterday" / "Last seen at ..."
  static String lastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'last seen recently';
    final local = lastSeen.toLocal();
    final now = DateTime.now();
    if (isSameDay(local, now)) return 'last seen today at ${_timeFormat.format(local)}';
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(local, yesterday)) return 'last seen yesterday at ${_timeFormat.format(local)}';
    return 'last seen ${_dateFormat.format(local)} at ${_timeFormat.format(local)}';
  }

  /// Humanized duration "3m 20s", "1h 05m" used in calls and voice notes.
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  /// Compact file size "2.4 MB", "820 KB".
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Simple date formatting used across chat screens.
String formatShortDate(DateTime time) => DateFormat('EEE, dd MMM').format(time.toLocal());
