import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dates.dart';
import 'program.dart';
import 'pumplex.dart';
import 'store.dart';

// Android's own "Save as" / "Open" screens (Storage Access Framework),
// reached through MainActivity.kt, so no plugin is needed.
const _files = MethodChannel('pumplex/files');

/// Lets the user pick where to save. False if they backed out.
Future<bool> saveTextFile({
  required String name,
  required String mime,
  required String content,
}) async =>
    await _files.invokeMethod<bool>('saveText', {
      'name': name,
      'mime': mime,
      'content': content,
    }) ??
    false;

/// Lets the user pick a file and returns its text. Null if they backed out.
Future<String?> openTextFile() => _files.invokeMethod<String>('openText');

/// Unicode byte-order mark (U+FEFF).
final bom = String.fromCharCode(0xFEFF);

String _csvField(String v) =>
    RegExp(r'[",\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

/// One row per logged set, for sessions dated [from]..[to].
/// Returns the CSV and how many sets it holds.
({String csv, int sets}) buildCsv(LogStore store, DateTime from, DateTime to) {
  final entries = store.betweenDates(dateKey(from), dateKey(to));
  // Session order, then program order within a session.
  entries.sort((a, b) {
    final bySession = a.n.compareTo(b.n);
    if (bySession != 0) return bySession;
    return (findExercise(a.id)?.index ?? 99).compareTo(findExercise(b.id)?.index ?? 99);
  });

  final rows = <List<String>>[
    ['date', 'session', 'program_day', 'workout', 'exercise', 'slot', 'scheme', 'set', 'kg', 'reps'],
  ];
  for (final e in entries) {
    final where = findExercise(e.id);
    final day = store.dayOf(e.n);
    final sets = e.log.filledSets;
    for (var i = 0; i < sets.length; i++) {
      final s = sets[i];
      if (s.isEmpty) continue;
      rows.add([
        e.date,
        '${e.n}',
        '$day',
        program[day]?.title ?? where?.workout.title ?? '',
        e.log.name,
        where?.exercise.hint ?? '',
        where?.exercise.scheme ?? '',
        '${i + 1}',
        s.kg == null ? '' : fmtKg(s.kg!),
        s.reps?.toString() ?? '',
      ]);
    }
  }
  // Byte-order mark so Excel reads it as UTF-8; Google Sheets ignores it.
  final csv = '$bom${rows.map((r) => r.map(_csvField).join(',')).join('\r\n')}\r\n';
  return (csv: csv, sets: rows.length - 1);
}

/// Pick a period, build the CSV, save it where the user chooses.
Future<void> exportCsvFlow(BuildContext context, LogStore store) async {
  final today = dateOnly(DateTime.now());
  final first = store.firstDate == null ? today : parseDateKey(store.firstDate!);

  final range = await showDialog<DateTimeRange>(
    context: context,
    builder: (context) {
      final p = Pal.of(context);
      Widget option(String label, Color color, DateTimeRange r) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SizedBox(
              width: double.infinity,
              child: BrutalButton(
                color: color,
                onTap: () => Navigator.pop(context, r),
                child: Text(label),
              ),
            ),
          );
      DateTimeRange last(int days) =>
          DateTimeRange(start: addDays(today, -(days - 1)), end: today);
      return AlertDialog(
        title: const Text('EXPORT CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pick a period. One row per set.', style: mono(13, p.ink)),
            const SizedBox(height: 16),
            option('LAST 7 DAYS', p.lime, last(7)),
            option('LAST 30 DAYS', p.sky, last(30)),
            option('LAST 90 DAYS', p.orange, last(90)),
            option('ALL TIME', p.violet, DateTimeRange(start: first, end: today)),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                width: double.infinity,
                child: BrutalButton(
                  color: p.pink,
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: addDays(today, 365),
                      initialDateRange: last(30),
                      helpText: 'EXPORT WHICH DAYS?',
                    );
                    if (picked != null && context.mounted) Navigator.pop(context, picked);
                  },
                  child: const Text('PICK DATES…'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: display(16, p.ink)),
          ),
        ],
      );
    },
  );
  if (range == null || !context.mounted) return;

  final from = dateOnly(range.start), to = dateOnly(range.end);
  final out = buildCsv(store, from, to);
  final messenger = ScaffoldMessenger.of(context);
  if (out.sets == 0) {
    messenger.showSnackBar(const SnackBar(content: Text('NOTHING LOGGED IN THAT PERIOD. SUSPICIOUS.')));
    return;
  }
  try {
    final saved = await saveTextFile(
      name: 'pumplex_${dateKey(from)}_to_${dateKey(to)}.csv',
      mime: 'text/csv',
      content: out.csv,
    );
    if (saved) {
      messenger.showSnackBar(SnackBar(content: Text('EXPORTED ${out.sets} SETS. SPREADSHEET: SCARED.')));
    }
  } on PlatformException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('COULD NOT SAVE: ${e.message}')));
  }
}
