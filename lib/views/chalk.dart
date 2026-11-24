// The CHALK sheet (D72, D79, D81; docs/moodboard/chalk/01-chalk-search.html).
// At the top: the title and BACK TO TODAY (it wipes the words, closes the
// sheet and goes back to the first Today card). Then one row of word tiles
// per kind: PATTERN, MOVE, TOOL, BODY (ANGLE and GRIP are chips on the
// exercise card, D55/D57). A tile picked is filled; a second tap takes it
// out. A tile that gives 0 exercises is greyed (no counts, D81). At the
// bottom, in a fixed height: the results, one row per matching exercise (a
// card can give several); a tap picks that exercise and selects its card
// (the carousel goes there and the sheet closes on it); the "+" at the
// right adds that exercise to Today (only an exercise in Today shows TODAY,
// not the other variations of its move, D82). The list ends
// with FORGE IT. The sheet has a fixed height, so nothing moves with the
// count. With 0 matches: NO SUCH MOVE. FORGE IT? Both open the FORGE card
// with the picked words (lib/views/forge.dart).
// CHALK searches ALL exercises and ignores the class and the filters.

import 'package:flutter/material.dart';

import '../game/chalk.dart';
import '../game/exercises.dart';
import '../i18n.dart';
import '../labels.dart' show bodyPartLabel;
import '../pumplex.dart';
import '../store.dart';
import 'forge.dart';

/// Chalk white, for the words on the dark floor (an alias of [Pal.chalk];
/// workout.dart uses it).
const kChalk = Pal.chalkWhite;

/// A word's label in the current language: `chalk.<row>.<id>`.
String chalkLabel(ChalkWord w) => tOr('chalk.${w.key}', w.label);

/// A row's title: `chalk.row.<row>`.
String chalkRowLabel(String row) => tOr('chalk.row.$row', row);

Future<void> showChalkSheet(BuildContext context, LogStore store) =>
    showBrutalSheet(context, (_) => ChalkSheet(store: store));

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
          showForge(nav, store, line, onBackToChalk: () => showChalkSheet(nav.context, store));
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
                            ChipSection(
                              key: ValueKey('chalk-row-$row'),
                              title: chalkRowLabel(row),
                              bottom: 10,
                              children: [
                                // A word tile: its label only (no count,
                                // D81); filled lime when picked (like the
                                // selected result row), greyed when it gives
                                // no exercise.
                                for (final w in chalkWords.where((w) => w.row == row))
                                  PickChip(
                                    id: 'chalk-${w.key}',
                                    label: chalkLabel(w),
                                    off: !line.contains(w.key) && index.count(chalkToggle(line, w)) == 0,
                                    selected: line.contains(w.key),
                                    color: p.lime,
                                    selectedBorder: p.on,
                                    onTap: () => store.setChalk(chalkToggle(line, w)),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // At the bottom, in a fixed height: the results, or FORGE
                // at 0 (D81), or a hint before the first word.
                SizedBox(
                  key: const ValueKey('chalk-results-area'),
                  height: kChalkResultsHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
                    child: line.isEmpty
                        // Before the first word: a short hint, not a blank.
                        ? Align(
                            alignment: Alignment.topLeft,
                            child: Text(t('chalk.pickHint'),
                                key: const ValueKey('chalk-pick-hint'), style: mono(12, p.inkQuiet)),
                          )
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
                trackBorderColor: WidgetStatePropertyAll(p.inkFaint),
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
/// right adds that exercise (variation) to Today; an exercise in Today
/// shows TODAY there (D82: per exercise, not per card). The list scrolls inside its fixed area and always ends with
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

/// The "+" glyph of a result row: two thick bars, most of the box (the
/// Anton "+" is tiny), square ends like the pixel art.
class _Plus extends StatelessWidget {
  const _Plus({required this.color});

  final Color color;

  /// The bars' length and thickness.
  static const size = 28.0, bar = 7.0;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        key: const ValueKey('chalk-plus'),
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: size, height: bar, color: color),
            Container(width: bar, height: size, color: color),
          ],
        ),
      );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.store, required this.r, required this.index});

  final LogStore store;
  final ChalkResult r;
  final ChalkIndex index;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final v = r.exercise;
    // Per exercise (D82): only this variation's own TODAY mark and sets.
    final inToday = store.inToday(v.id);
    final on = store.pickedCard == v.id;
    final sets = store.setsToday(v.id);
    final (:part, :tool) = index.tagsOf(v);
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
          store.selectExercise(v.id);
          Navigator.of(context).pop();
        },
        child: Brutal(
          key: on ? ValueKey('chalk-result-on-${v.id}') : null,
          padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
          color: on ? p.lime : p.panel,
          borderColor: on ? p.on : p.ink,
          border: 3,
          shadow: p.ink,
          offset: 3,
          duration: Duration.zero,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName(v).toUpperCase(), style: display(15, fg)),
                    if (info.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(info.toUpperCase(), style: mono(10, on ? p.onSoft : p.inkSoft)),
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
                IconTapButton(
                  key: ValueKey('chalk-result-add-${v.id}'),
                  label: '+ ${t('today.title')}',
                  size: kChalkAddSize,
                  borderColor: on ? p.on : p.ink,
                  // Adds this exercise (variation) to Today; the sheet
                  // stays open.
                  onTap: () => store.addToToday(v.id),
                  icon: _Plus(color: p.lime),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
