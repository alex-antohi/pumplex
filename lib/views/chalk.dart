// The CHALK sheet (D72, docs/moodboard/chalk/01-chalk-search.html). At the
// top the chalk line shows the words picked (tap one to wipe it). Under it
// one row of word tiles per kind: PATTERN, MOVE, TOOL, BODY, ANGLE, GRIP.
// Each tile shows how many exercises the chalk line gives with it (its own
// row's word swapped for it); 0 is greyed. WIPE clears the line; SHOW n
// EXERCISES closes the sheet. With 0 matches the main button reads NO SUCH
// MOVE. FORGE IT?, which opens the FORGE card (lib/views/forge.dart).
// CHALK searches ALL exercises and ignores the class and the filters.

import 'package:flutter/material.dart';

import '../game/chalk.dart';
import '../game/exercises.dart';
import '../i18n.dart';
import '../pumplex.dart';
import '../store.dart';
import 'forge.dart';

/// Chalk white, for the words on the dark floor.
const kChalk = Color(0xFFF4F1FF);

/// A word's label in the current language: `chalk.<row>.<id>`.
String chalkLabel(ChalkWord w) => tOr('chalk.${w.key}', w.label);

/// A row's title: `chalk.row.<row>`.
String chalkRowLabel(String row) => tOr('chalk.row.$row', row);

Future<void> showChalkSheet(BuildContext context, LogStore store) {
  final p = Pal.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.bg,
    shape: Border(top: BorderSide(color: p.ink, width: 4)),
    builder: (_) => ChalkSheet(store: store),
  );
}

class ChalkSheet extends StatelessWidget {
  const ChalkSheet({super.key, required this.store});

  final LogStore store;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final index = ChalkIndex.of(exerciseCatalog);
        final line = store.chalk;
        final total = index.count(line);
        final picked = [for (final k in line) ?chalkWordByKey(k)]
          ..sort((a, b) => chalkRows.indexOf(a.row) - chalkRows.indexOf(b.row));
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ChalkLine(
                          words: picked,
                          empty: line.isNotEmpty && total == 0,
                          onWipe: (w) => store.setChalk(chalkToggle(line, w)),
                        ),
                        const SizedBox(height: 12),
                        for (final row in chalkRows)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Shout(chalkRowLabel(row), size: 13, color: p.ink),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final w in chalkWords.where((w) => w.row == row))
                                      _Tile(
                                        word: w,
                                        count: index.count(chalkToggle(line, w).union(line.contains(w.key) ? {w.key} : {})),
                                        selected: line.contains(w.key),
                                        onTap: () => store.setChalk(chalkToggle(line, w)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 24, 16),
                  child: Row(
                    children: [
                      BrutalButton(
                        key: const ValueKey('chalk-wipe'),
                        small: true,
                        color: p.sky,
                        onTap: () => store.setChalk(const {}),
                        child: Text(t('chalk.wipe')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: line.isNotEmpty && total == 0
                            ? BrutalButton(
                                key: const ValueKey('chalk-forge'),
                                color: p.pink,
                                // The FORGE card, from these words.
                                onTap: () {
                                  final nav = Navigator.of(context)..pop();
                                  showForge(nav, store, line);
                                },
                                child: FittedBox(fit: BoxFit.scaleDown, child: Text(t('chalk.forge'))),
                              )
                            : BrutalButton(
                                key: const ValueKey('chalk-show'),
                                color: p.lime,
                                onTap: () => Navigator.of(context).pop(),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(t('filter.show', {'exercises': tn('exercises', total)})),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The chalk line: chalk words on a dark floor, each with a × to wipe it.
class _ChalkLine extends StatelessWidget {
  const _ChalkLine({required this.words, required this.empty, required this.onWipe});

  final List<ChalkWord> words;
  final bool empty;
  final ValueChanged<ChalkWord> onWipe;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      key: const ValueKey('chalk-line'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: kNight,
        border: Border.all(color: p.ink, width: 3),
        boxShadow: [BoxShadow(color: p.ink, offset: const Offset(3, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('chalk.lineLabel'), style: mono(10, kChalk.withValues(alpha: 0.55))),
          const SizedBox(height: 4),
          if (words.isEmpty)
            Text(t('chalk.pick'), style: display(18, kChalk.withValues(alpha: 0.3)))
          else
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                for (final (i, w) in words.indexed)
                  GestureDetector(
                    key: ValueKey('chalk-word-${w.key}'),
                    onTap: () => onWipe(w),
                    child: Transform.rotate(
                      angle: (i.isEven ? -1.5 : 1) * 3.14159 / 180,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
                        decoration: BoxDecoration(border: Border.all(color: kChalk.withValues(alpha: 0.75), width: 2)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(chalkLabel(w).toUpperCase(), style: display(19, kChalk)),
                            const SizedBox(width: 5),
                            Text('×', style: mono(11, kChalk.withValues(alpha: 0.55))),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 6),
          Text(empty ? t('chalk.none') : t('chalk.tip'),
              key: const ValueKey('chalk-tip'), style: mono(10, empty ? p.pink : kChalk.withValues(alpha: 0.5))),
        ],
      ),
    );
  }
}

/// A word tile: its label and how many exercises it gives; filled when it
/// is in the chalk line, greyed at 0.
class _Tile extends StatelessWidget {
  const _Tile({required this.word, required this.count, required this.selected, required this.onTap});

  final ChalkWord word;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final off = count == 0 && !selected;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: ValueKey('chalk-${word.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: off ? 0.35 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? kNight : p.panel,
              border: Border.all(color: p.ink, width: 3),
              boxShadow: selected ? [BoxShadow(color: p.ink, offset: const Offset(3, 3))] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(chalkLabel(word).toUpperCase(), style: display(13, selected ? kChalk : p.ink)),
                const SizedBox(width: 5),
                Text('$count', style: mono(11, selected ? kChalk : p.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
