import 'i18n.dart';

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

/// "Mon 4 Nov": the words and their order come from the language file (D68).
String shortDate(DateTime d) =>
    t('date.short', {'weekday': t('date.weekday.${d.weekday}'), 'day': d.day, 'month': t('date.month.${d.month}')});

/// 1:05:09, or 12:04 under an hour.
String fmtDuration(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}
