// The CHALK sheet (D72, D79, D81; docs/moodboard/chalk/01-chalk-search.html).
// At the top: the title and BACK TO TODAY (it wipes the words, closes the
// sheet and goes back to the first Today card). Then one row of word tiles
// per kind: PATTERN, MOVE, TOOL, BODY (ANGLE and GRIP are chips on the
// exercise card, D55/D57). A tile picked is filled; a second tap takes it
// out. A tile that gives 0 exercises is greyed (no counts, D81). At the
// bottom, in a fixed height: the results, one row per matching exercise (a
// card can give several); a tap picks that exercise and selects its card
// (the carousel goes there and the sheet closes on it); the "+" at the
// right adds the card to Today (a card in Today shows TODAY). The list ends
// with FORGE IT. The sheet has a fixed height, so nothing moves with the
// count. With 0 matches: NO SUCH MOVE. FORGE IT? Both open the FORGE card
// with the picked words (lib/views/forge.dart).
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

/// The CHALK sheet's height, a fixed part of the screen: the same with 0,
/// 3 or 30 results, so the sheet never jumps (D81 follow-up).
const kChalkSheetFraction = 0.82;

/// The results area's fixed height at the bottom of the sheet: few results
/// leave empty space, many scroll inside it.
const kChalkResultsHeight = 270.0;

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
        // The FORGE card, from the picked words (CHALK closes first).
        void forge() {
          final nav = Navigator.of(context)..pop();
          showForge(nav, store, line);
        }

        return SizedBox(
          key: const ValueKey('chalk-sheet'),
          height: MediaQuery.sizeOf(context).height * kChalkSheetFraction,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The title and BACK TO TODAY (D81).
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 24, 4),
                  child: Row(
                    children: [
                      Shout(t('chalk.title'), size: 15, color: p.ink),
                      const Spacer(),
                      BrutalButton(
                        key: const ValueKey('chalk-back-today'),
                        small: true,
                        color: p.sky,
                        onTap: () {
                          store.backToToday();
                          Navigator.of(context).pop();
                        },
                        child: Text(t('chalk.backToToday')),
                      ),
                    ],
                  ),
                ),
                // The word tiles: all the space between the top and the
                // results; they scroll in it.
                Expanded(
                  child: ChalkScroll(
                    key: const ValueKey('chalk-tiles'),
                    builder: (controller) => SingleChildScrollView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 8, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final row in chalkRows)
                            Padding(
                              key: ValueKey('chalk-row-$row'),
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
                                          // Greyed when it gives nothing.
                                          off: !line.contains(w.key) && index.count(chalkToggle(line, w)) == 0,
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
                ),
                // At the bottom, in a fixed height: the results, or FORGE
                // at 0 (D81), or empty space before the first word.
                SizedBox(
                  key: const ValueKey('chalk-results-area'),
                  height: kChalkResultsHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
                    child: line.isEmpty
                        ? const SizedBox.shrink()
                        : total > 0
                            ? _Results(store: store, rows: index.results(line), index: index, onForge: forge)
                            : Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: BrutalButton(
                                    key: const ValueKey('chalk-forge'),
                                    color: p.pink,
                                    onTap: forge,
                                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(t('chalk.forge'))),
                                  ),
                                ),
                              ),
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

/// A scroll area that shows it scrolls: an always-visible ink scrollbar on
/// a lime track, and a fade at the bottom edge while more content is below.
class ChalkScroll extends StatefulWidget {
  const ChalkScroll({super.key, required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<ChalkScroll> createState() => _ChalkScrollState();
}

class _ChalkScrollState extends State<ChalkScroll> {
  final _controller = ScrollController();
  bool _more = false, _scrolls = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetrics m) {
    final more = m.extentAfter > 0.5, scrolls = m.maxScrollExtent > 0.5;
    if (more != _more || scrolls != _scrolls) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _more = more;
            _scrolls = scrolls;
          });
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics),
        child: Stack(
          children: [
            ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbColor: WidgetStatePropertyAll(p.ink),
                trackColor: WidgetStatePropertyAll(p.lime.withValues(alpha: 0.45)),
                trackBorderColor: WidgetStatePropertyAll(p.ink.withValues(alpha: 0.4)),
                thickness: const WidgetStatePropertyAll(6),
                radius: Radius.zero,
                crossAxisMargin: 1,
              ),
              child: Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                trackVisibility: _scrolls,
                child: widget.builder(_controller),
              ),
            ),
            if (_more)
              Positioned(
                key: const ValueKey('chalk-fade'),
                left: 0,
                right: 10,
                bottom: 0,
                height: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [p.bg.withValues(alpha: 0), p.bg],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The CHALK results (D79, D81): one row per matching exercise
/// (ChalkIndex.results), so a card with several matches gives several rows;
/// the name in the current language, its body part and tool. The exercise
/// on the carousel is filled lime (the app's yellow). A tap on the row picks
/// that exercise and selects its card: the sheet closes on it. A "+" at the
/// right adds the card to Today with that exercise; a card in Today shows
/// TODAY there. The list scrolls inside its fixed area and always ends with
/// FORGE IT (a move that is not in the list yet).
class _Results extends StatelessWidget {
  const _Results({required this.store, required this.rows, required this.index, required this.onForge});

  final LogStore store;
  final List<ChalkResult> rows;
  final ChalkIndex index;
  final VoidCallback onForge;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      key: const ValueKey('chalk-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Shout(t('today.results', {'n': rows.length}), size: 13, color: p.ink),
        const SizedBox(height: 6),
        Expanded(
          child: ChalkScroll(
            key: const ValueKey('chalk-results-scroll'),
            builder: (controller) => ListView.separated(
              controller: controller,
              padding: const EdgeInsets.only(right: 12, bottom: 4),
              itemCount: rows.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) => i < rows.length
                  ? _ResultRow(store: store, r: rows[i], index: index)
                  : BrutalButton(
                      key: const ValueKey('chalk-forge-it'),
                      small: true,
                      color: p.pink,
                      onTap: onForge,
                      child: Text(t('forge.go')),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The "+" (and TODAY) spot at the right of a result row: 44 px high.
const kChalkAddSize = 44.0;

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.store, required this.r, required this.index});

  final LogStore store;
  final ChalkResult r;
  final ChalkIndex index;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final g = r.card, v = r.exercise;
    final inToday = store.inToday(g.key);
    final on = store.pickedCard == g.key && store.variantFor(g).id == v.id;
    final sets = store.groupSetsToday(g.key);
    final part = bodyParts.where((b) => b.muscles.contains(v.muscle)).firstOrNull;
    final tool = (index.words[v.id] ?? const <String>{}).where((k) => k.startsWith('tool.')).map(chalkWordByKey).firstOrNull;
    final info = [
      if (part != null) bodyPartLabel(part.id),
      if (tool != null) chalkLabel(tool),
      if (sets > 0) tn('today.setsToday', sets),
    ].join(' · ');
    final fg = on ? p.on : p.ink;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        key: ValueKey('chalk-result-${v.id}'),
        behavior: HitTestBehavior.opaque,
        // Picks this exercise on its card and selects the card.
        onTap: () {
          store.pickVariant(v.id);
          store.selectCard(g.key);
          Navigator.of(context).pop();
        },
        child: Container(
          key: on ? ValueKey('chalk-result-on-${v.id}') : null,
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          decoration: BoxDecoration(
            color: on ? p.lime : p.panel,
            border: Border.all(color: on ? p.on : p.ink, width: 3),
            boxShadow: [BoxShadow(color: p.ink, offset: const Offset(3, 3))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((v.nick ?? exerciseLabel(v.id, v.name)).toUpperCase(), style: display(15, fg)),
                    if (info.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(info.toUpperCase(), style: mono(10, fg.withValues(alpha: 0.7))),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (inToday)
                Container(
                  key: ValueKey('chalk-result-today-${v.id}'),
                  constraints: const BoxConstraints(minHeight: kChalkAddSize),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  color: kNight,
                  child: Text(t('today.title'), style: display(12, p.lime)),
                )
              else
                Semantics(
                  button: true,
                  label: '+ ${t('today.title')}',
                  child: GestureDetector(
                    key: ValueKey('chalk-result-add-${v.id}'),
                    behavior: HitTestBehavior.opaque,
                    // Adds the card to Today, on this exercise; the sheet
                    // stays open.
                    onTap: () {
                      store.pickVariant(v.id);
                      store.addToToday(g.key);
                    },
                    child: Container(
                      width: kChalkAddSize,
                      height: kChalkAddSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: kNight,
                        border: Border.all(color: on ? p.on : p.ink, width: 2),
                      ),
                      child: Text('+', style: display(24, p.lime)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A word tile: its label only (no count, D81); filled lime when picked
/// (like the selected result row), greyed
/// when it gives no exercise.
class _Tile extends StatelessWidget {
  const _Tile({required this.word, required this.off, required this.selected, required this.onTap});

  final ChalkWord word;
  final bool off, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
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
              color: selected ? p.lime : p.panel,
              border: Border.all(color: selected ? p.on : p.ink, width: 3),
              boxShadow: selected ? [BoxShadow(color: p.ink, offset: const Offset(3, 3))] : null,
            ),
            child: Text(chalkLabel(word).toUpperCase(), style: display(13, selected ? p.on : p.ink)),
          ),
        ),
      ),
    );
  }
}
