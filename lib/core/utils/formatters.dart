import 'package:intl/intl.dart';

/// Small formatting helpers shared across screens.
abstract class Formatters {
  static final _time = DateFormat('h:mm a');
  static final _date = DateFormat('EEE, d MMM');
  static final _dateTime = DateFormat('d MMM, h:mm a');

  static String time(DateTime dt) => _time.format(dt);
  static String date(DateTime dt) => _date.format(dt);
  static String dateTime(DateTime dt) => _dateTime.format(dt);

  /// Formats a duration as `1h 05m` or `05m 12s` when under an hour.
  static String remaining(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s';
  }

  /// Compact label like `2h` or `45m` for durations.
  static String durationLabel(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}
