// The CHALK sheet (D72, docs/moodboard/chalk/01-chalk-search.html). At the
// top the chalk line shows the words picked (tap one to wipe it). Right
// under it the results (D79): one row per card; a tap adds it to Today and
// closes the sheet on it. Then one row of word tiles per kind: PATTERN, MOVE, TOOL, BODY, ANGLE, GRIP.
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
import 'filters.dart' show bodyPartLabel;
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
                        // The results, right under the chalk line (D79):
                        // one tap on a row adds that card to Today.
                        if (line.isNotEmpty && total > 0) ...[
                          const SizedBox(height: 12),
                          _Results(store: store, cards: index.search(line), index: index),
                        ],
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

/// The CHALK results (D79): one row per matching card, its exercise's name
/// in the current language, its body part and tool. A card already in Today
/// shows TODAY, the others "+". A tap adds the card to Today (one per tap,
/// no "add all"), closes the sheet and shows the card. The list scrolls on
/// its own, so the word tiles stay close.
class _Results extends StatelessWidget {
  const _Results({required this.store, required this.cards, required this.index});

  final LogStore store;
  final List<ExerciseGroup> cards;
  final ChalkIndex index;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      key: const ValueKey('chalk-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Shout(t('today.results', {'n': cards.length}), size: 13, color: p.ink),
            const Spacer(),
            Flexible(
              child: Text(t('today.tapToAdd'),
                  textAlign: TextAlign.right, style: mono(10, p.ink.withValues(alpha: 0.6))),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 216),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) => _ResultRow(store: store, g: cards[i], index: index),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.store, required this.g, required this.index});

  final LogStore store;
  final ExerciseGroup g;
  final ChalkIndex index;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final v = store.variantFor(g);
    final inToday = store.inToday(g.key);
    final sets = store.groupSetsToday(g.key);
    final part = bodyParts.where((b) => b.muscles.contains(v.muscle)).firstOrNull;
    final tool = (index.words[v.id] ?? const <String>{}).where((k) => k.startsWith('tool.')).map(chalkWordByKey).firstOrNull;
    final info = [
      if (part != null) bodyPartLabel(part.id),
      if (tool != null) chalkLabel(tool),
      if (sets > 0) tn('today.setsToday', sets),
    ].join(' · ');
    return Semantics(
      button: true,
      selected: inToday,
      child: GestureDetector(
        key: ValueKey('chalk-result-${g.key}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          store.addToToday(g.key);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: inToday ? p.panel2 : p.panel,
            border: Border.all(color: p.ink, width: 3),
            boxShadow: [BoxShadow(color: p.ink, offset: const Offset(3, 3))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((v.nick ?? exerciseLabel(v.id, v.name)).toUpperCase(), style: display(15, p.ink)),
                    if (info.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(info.toUpperCase(), style: mono(10, p.ink.withValues(alpha: 0.65))),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (inToday)
                Container(
                  key: ValueKey('chalk-result-today-${g.key}'),
                  padding: const EdgeInsets.fromLTRB(7, 4, 7, 3),
                  color: kNight,
                  child: Text(t('today.title'), style: display(12, p.lime)),
                )
              else
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.lime, border: Border.all(color: p.ink, width: 2)),
                  child: Text('+', style: display(18, p.on)),
                ),
            ],
          ),
        ),
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
