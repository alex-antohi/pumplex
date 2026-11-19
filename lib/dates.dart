const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar-safe (DST-safe) day arithmetic.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

String _two(int n) => n.toString().padLeft(2, '0');

/// yyyy-MM-dd; sorts the same as the dates do.
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime parseDateKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

/// "Mon 4 Nov"
String shortDate(DateTime d) =>
    '${_weekdays[d.weekday - 1].substring(0, 3)} ${d.day} ${_months[d.month - 1]}';

/// "Monday, 4 Nov"
String longDate(DateTime d) =>
    '${weekdayName(d)}, ${d.day} ${_months[d.month - 1]}';

/// 1:05:09, or 12:04 under an hour.
String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

String relativeDay(DateTime d, DateTime today) {
  final n = daysBetween(today, d);
  if (n == 0) return 'Today';
  if (n == -1) return 'Yesterday';
  if (n == 1) return 'Tomorrow';
  return n < 0 ? '${-n} days ago' : 'In $n days';
}
