import 'package:intl/intl.dart';

/// Small formatting helpers shared across screens.
abstract class Formatters {
  static final _time = DateFormat('h:mm a');
  static final _date = DateFormat('EEE, d MMM');
  static final _dateTime = DateFormat('d MMM, h:mm a');

  static String time(DateTime dt) => _time.format(dt);
  static String date(DateTime dt) => _date.format(dt);
  static String dateTime(DateTime dt) => _dateTime.format(dt);

  /// Time only if [dt] is today, otherwise date + time (`5 Dec, 3:00 PM`).
  /// Use for end times, which can be days away on long bookings.
  static String smartTime(DateTime dt) {
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    return sameDay ? time(dt) : dateTime(dt);
  }

  /// Formats a duration as `3d 04h`, `1h 05m` or `05m 12s` when under an hour.
  static String remaining(Duration d) {
    if (d.isNegative) d = Duration.zero;
    if (d.inDays > 0) {
      final h = d.inHours.remainder(24);
      return '${d.inDays}d ${h.toString().padLeft(2, '0')}h';
    }
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

  /// Compact label like `7 days`, `2h` or `45m` for durations.
  static String durationLabel(Duration d) {
    if (d.inDays > 0) {
      final days = d.inDays;
      final h = d.inHours.remainder(24);
      final dayText = days == 1 ? '1 day' : '$days days';
      return h > 0 ? '$dayText ${h}h' : dayText;
    }
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}
