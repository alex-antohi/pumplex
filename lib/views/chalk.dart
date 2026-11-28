// The CHALK sheet, the VISUAL MAP layout (D87; docs/moodboard/chalk/
// debate-02/visual-map.html; before it D72, D79, D81, D86).
//
// Opened: a character screen. The lifter stands in the middle with six body
// tags beside it (SHOULDERS, ARMS, LEGS / CHEST, CORE, BACK), the WHOLE BODY
// words under it (JUMP, CARRY, CARDIO), then the GEAR RACK (one pixel icon
// slot per tool, assets/icons/tools/; the lit tools first, D89) and OR SAY
// THE MOVE (the 5 moves of the class, D89; "+n" shows the rest). A picked
// piece is lime; one that gives no
// exercise is greyed.
//
// A tool or a move folds the picture into the LOADOUT bar: the picked words,
// always in sight, each with ✕ to drop it (a drop unfolds the picture so the
// lifter can pick again). Under it NARROW (only the move words that still
// match) and the results as loot cards, one per move: DO IT ▸ selects the
// move and closes CHALK; each variation is a pip: its name selects it, "+"
// adds it to Today (✓ TODAY when it is there, D82: per exercise). The list
// ends with FORGE IT.
//
// 0 matches: the loadout pieces are outlined pink, an empty loot slot says
// NO SUCH MOVE. with FORGE IT, and OR DROP ONE says what each drop brings back.
// BACK TO TODAY sits at the bottom, in thumb reach (it wipes the words).
// CHALK searches ALL exercises: the class is a hint, never a filter (D89).
// The lit gear (class gear and my gear) comes first in the rack and the
// results; a long-press on a rack tool adds it to my gear or removes it.

import 'package:flutter/material.dart';

import '../game/chalk.dart';
import '../game/exercises.dart';
import '../i18n.dart';
import '../labels.dart' show bodyPartLabel;
import '../pumplex.dart';
import '../store.dart';
import 'forge.dart';
import 'sprite.dart' show CharacterSprite;

/// Chalk white, for the words on the dark floor (an alias of [Pal.chalk];
/// workout.dart uses it).
const kChalk = Pal.chalkWhite;

/// A word's label in the current language: `chalk.<row>.<id>`.
String chalkLabel(ChalkWord w) => tOr('chalk.${w.key}', w.label);

/// A row's title: `chalk.row.<row>`.
String chalkRowLabel(String row) => tOr('chalk.row.$row', row);

Future<void> showChalkSheet(BuildContext context, LogStore store) => showBrutalSheet(context, (_) => _ChalkScope(store: store, child: ChalkSheet(store: store)));

/// The CHALK sheet's height, a fixed part of the screen (D81 follow-up).
const kChalkSheetFraction = 0.82;

/// The body tags beside the lifter: left, then right (D87).
const _bodyLeft = ['shoulders', 'arms', 'legs'], _bodyRight = ['chest', 'core', 'back'];

/// The WHOLE BODY words on the ground under the lifter (D87); the other
/// patterns are covered by the body tags, the tools and the moves.
const _wholeBody = ['jump', 'carry', 'cardio'];

/// The gear-rack icon of a tool word id (tools/tool_icons.mjs).
String chalkToolIcon(String id) => 'assets/icons/tools/$id.png';

/// The light slot behind a tool icon, the same in both themes.
const _slotBg = Color(0xFFFFFFFF);

class ChalkSheet extends StatefulWidget {
  const ChalkSheet({super.key, required this.store});

  final LogStore store;

  @override
  State<ChalkSheet> createState() => _ChalkSheetState();
}

class _ChalkSheetState extends State<ChalkSheet> {
  /// The picture (lifter, gear rack, moves) is open; a tool or a move folds
  /// it into the LOADOUT bar.
  bool _open = true;

  /// OR SAY THE MOVE shows every move, not only the most common.
  bool _allMoves = false;

  LogStore get store => widget.store;

  void _pick(ChalkWord w) {
    final line = chalkToggle(store.chalk, w);
    setState(() {
      if (line.isEmpty) {
        _open = true;
      } else if (!store.chalk.contains(w.key) && (w.row == 'tool' || w.row == 'move')) {
        _open = false;
      }
    });
    store.setChalk(line);
  }

  /// ✕ on a loadout piece: it drops and the picture opens again.
  void _drop(ChalkWord w) {
    setState(() => _open = true);
    store.setChalk(chalkToggle(store.chalk, w));
  }

  @override
  void initState() {
    super.initState();
    // Words from before (the FORGE card's BACK): show their results.
    _open = store.chalk.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final index = ChalkIndex.of(exerciseCatalog);
        final line = store.chalk;
        final cards = store.chalkCards(line); // my gear first (D89)
        final total = index.count(line);
        final open = _open || line.isEmpty;
        // The FORGE card, from the picked words (CHALK closes first).
        void forge() {
          final nav = Navigator.of(context)..pop();
          showForge(nav, store, line, onBackToChalk: () => showChalkSheet(nav.context, store));
        }

        bool off(ChalkWord w) => !line.contains(w.key) && index.count(chalkToggle(line, w)) == 0;

        return SizedBox(
          key: const ValueKey('chalk-sheet'),
          height: MediaQuery.sizeOf(context).height * kChalkSheetFraction,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 20, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Shout(t('chalk.title'), size: 22, color: p.ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          open
                              ? t('chalk.whereWith')
                              : total == 0
                              ? t('chalk.zero')
                              : t('chalk.moves', {'n': cards.length}),
                          key: const ValueKey('chalk-subtitle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mono(10, p.inkQuiet),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ChalkScroll(
                    // The picture scrolls as 'chalk-tiles', the results as 'chalk-results-scroll'.
                    key: ValueKey(open ? 'chalk-tiles' : 'chalk-results-scroll'),
                    builder: (controller) => SingleChildScrollView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 4, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: open
                            ? [
                                _LifterPanel(store: store, line: line, off: off, onPick: _pick),
                                const SizedBox(height: 14),
                                _GearRack(store: store, line: line, off: off, onPick: _pick),
                                const SizedBox(height: 14),
                                _SayMove(
                                  top: store.topMoves,
                                  line: line,
                                  off: off,
                                  all: _allMoves,
                                  onMore: () => setState(() => _allMoves = !_allMoves),
                                  onPick: _pick,
                                ),
                                if (line.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  BrutalButton(
                                    key: const ValueKey('chalk-show'),
                                    color: p.lime,
                                    onTap: () => setState(() => _open = false),
                                    child: Text(total == 0 ? t('chalk.zero') : t('chalk.showMoves', {'n': cards.length})),
                                  ),
                                ],
                              ]
                            : [
                                _Loadout(line: line, bad: total == 0, onDrop: _drop, onAdd: () => setState(() => _open = true)),
                                const SizedBox(height: 10),
                                if (total > 0) ...[
                                  _Narrow(line: line, off: off, onPick: _pick),
                                  const SizedBox(height: 12),
                                  _LootCards(store: store, cards: cards, index: index, onForge: forge),
                                ] else
                                  _EmptySlot(line: line, index: index, onForge: forge, onDrop: _drop),
                              ],
                      ),
                    ),
                  ),
                ),
                // BACK TO TODAY in thumb reach (D87).
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 22, 12),
                  child: BrutalButton(
                    key: const ValueKey('chalk-back-today'),
                    color: p.sky,
                    onTap: () {
                      store.backToToday();
                      Navigator.of(context).pop();
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      PxIcon('back', size: 16, color: p.on),
                      const SizedBox(width: 8),
                      Text(t('chalk.backToToday')),
                    ]),
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

/// A body tag or a WHOLE BODY word: 40 dp, a small square marker, lime when
/// picked, greyed when it gives no exercise.
class _BodyTag extends StatelessWidget {
  const _BodyTag({required this.word, required this.selected, required this.off, required this.onTap, this.trailing});

  final ChalkWord word;
  final bool selected, off;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = selected ? p.on : p.ink;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !off,
      child: GestureDetector(
        key: ValueKey('chalk-${word.key}'),
        behavior: HitTestBehavior.opaque,
        // Dimmed, still tappable: a clash leads to 0 matches (FORGE, drop one).
        onTap: onTap,
        child: Opacity(
          opacity: off ? 0.35 : 1,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? p.lime : p.panel,
              border: Border.all(color: selected ? p.on : p.ink, width: 3),
              boxShadow: selected ? [BoxShadow(color: p.ink, offset: const Offset(3, 3))] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, color: selected ? p.on : p.pink),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(chalkLabel(word).toUpperCase(), style: display(14, fg)),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The character screen: the lifter, the body tags beside it and the WHOLE
/// BODY words on the ground.
class _LifterPanel extends StatelessWidget {
  const _LifterPanel({required this.store, required this.line, required this.off, required this.onPick});

  final LogStore store;
  final Set<String> line;
  final bool Function(ChalkWord) off;
  final ValueChanged<ChalkWord> onPick;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final profile = store.profile;
    Widget tag(String row, String id, {Widget? trailing}) {
      final w = chalkWordByKey('$row.$id')!;
      return _BodyTag(word: w, selected: line.contains(w.key), off: off(w), onTap: () => onPick(w), trailing: trailing);
    }

    Widget column(List<String> ids, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [for (final id in ids) tag('body', id, trailing: id == 'back' ? PxIcon('restore', size: 14, color: line.contains('body.back') ? p.on : p.ink) : null)],
    );

    return Container(
      key: const ValueKey('chalk-lifter-panel'),
      decoration: BoxDecoration(
        color: p.panel,
        border: Border.all(color: p.ink, width: 3),
        boxShadow: [BoxShadow(color: p.ink, offset: const Offset(4, 4))],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 176,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(padding: const EdgeInsets.only(left: 8), child: column(_bodyLeft, CrossAxisAlignment.start)),
                ),
                // Your own lifter (body + class outfit), D87.
                SizedBox(
                  key: const ValueKey('chalk-lifter'),
                  width: 104,
                  child: profile == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: CharacterSprite(character: profile.character, classId: store.gameClass.id, pedestal: false),
                        ),
                ),
                Expanded(
                  child: Padding(padding: const EdgeInsets.only(right: 8), child: column(_bodyRight, CrossAxisAlignment.end)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              color: p.panel2,
              border: Border(top: BorderSide(color: p.ink, width: 3)),
            ),
            child: Row(
              children: [
                Text(t('chalk.wholeBody'), style: mono(10, p.inkSoft)),
                const SizedBox(width: 6),
                for (final id in _wholeBody) ...[Expanded(child: tag('pattern', id)), if (id != _wholeBody.last) const SizedBox(width: 5)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The gear rack: one pixel-icon slot per tool, six to a row, on a dark
/// pegboard (D87). The lit tools (D89: class gear and my gear) come first;
/// a long-press on a tool adds it to my gear or removes it.
class _GearRack extends StatelessWidget {
  const _GearRack({required this.store, required this.line, required this.off, required this.onPick});

  final LogStore store;
  final Set<String> line;
  final bool Function(ChalkWord) off;
  final ValueChanged<ChalkWord> onPick;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final lit = store.litTools;
    final tools = rackOrder(lit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Shout(t('chalk.gearRack'), size: 13, color: p.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t('chalk.tapTool'),
                  textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(9.5, p.inkQuiet)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          key: const ValueKey('chalk-gear-rack'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kNight,
            border: Border.all(color: p.ink, width: 3),
            boxShadow: [BoxShadow(color: p.ink, offset: const Offset(4, 4))],
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              const per = 6, gap = 6.0;
              final w = (box.maxWidth - gap * (per - 1)) / per;
              return Wrap(
                spacing: gap,
                runSpacing: 8,
                children: [
                  for (final tool in tools)
                    _ToolSlot(
                      word: tool,
                      width: w,
                      selected: line.contains(tool.key),
                      off: off(tool),
                      lit: lit.contains(tool.id),
                      onTap: () => onPick(tool),
                      onLongPress: () => store.toggleGear(tool.id),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToolSlot extends StatelessWidget {
  const _ToolSlot({
    required this.word,
    required this.width,
    required this.selected,
    required this.off,
    required this.lit,
    required this.onTap,
    required this.onLongPress,
  });

  final ChalkWord word;
  final double width;

  /// [lit]: my gear (D89). A dim tool still works with one tap.
  final bool selected, off, lit;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !off,
      label: chalkLabel(word),
      // Placeholder state until the design team's lit / dim look (D89).
      value: lit ? 'lit' : 'dim',
      child: GestureDetector(
        key: ValueKey('chalk-${word.key}'),
        behavior: HitTestBehavior.opaque,
        // Dimmed, still tappable: a clash leads to 0 matches (FORGE, drop one).
        onTap: onTap,
        onLongPress: onLongPress,
        child: Opacity(
          // Placeholder: a dim tool is a little faded; a clash more.
          opacity: off ? 0.3 : lit ? 1 : 0.6,
          child: SizedBox(
            width: width,
            child: Column(
              children: [
                Container(
                  height: width,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? p.lime : _slotBg,
                    border: Border.all(color: selected ? p.pink : kNight, width: selected ? 3 : 2),
                  ),
                  child: Image.asset(
                    chalkToolIcon(word.id),
                    width: width * 0.72,
                    height: width * 0.72,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(chalkLabel(word).toUpperCase(), maxLines: 1, style: mono(9, selected ? p.lime : kChalk)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// OR SAY THE MOVE: the class's 5 moves ([top], D89), "+n" shows the rest.
class _SayMove extends StatelessWidget {
  const _SayMove({required this.top, required this.line, required this.off, required this.all, required this.onMore, required this.onPick});

  final List<String> top;
  final Set<String> line;
  final bool Function(ChalkWord) off;
  final bool all;
  final VoidCallback onMore;
  final ValueChanged<ChalkWord> onPick;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final moves = chalkWords.where((w) => w.row == 'move').toList();
    final shown = all
        ? moves
        : [
            for (final id in top) ...moves.where((w) => w.id == id),
            for (final w in moves)
              if (!top.contains(w.id) && line.contains(w.key)) w,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shout(t('chalk.sayMove'), size: 13, color: p.ink),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final w in shown)
              PickChip(
                id: 'chalk-${w.key}',
                label: chalkLabel(w),
                off: off(w),
                selected: line.contains(w.key),
                color: p.lime,
                selectedBorder: p.on,
                onTap: () => onPick(w),
              ),
            PickChip(
              id: 'chalk-more-moves',
              label: all ? '−' : '+${moves.length - shown.length}',
              selected: false,
              color: p.lime,
              onTap: onMore,
            ),
          ],
        ),
      ],
    );
  }
}

/// The store for the small pictures in the sheet (the lifter thumbnails).
class _ChalkScope extends InheritedWidget {
  const _ChalkScope({required this.store, required super.child});

  final LogStore store;

  static LogStore? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ChalkScope>()?.store;

  @override
  bool updateShouldNotify(_ChalkScope old) => old.store != store;
}

/// The small picture of a picked word: the tool's icon, else your lifter
/// (a body part or a whole-body word), else nothing (a move).
class _Thumb extends StatelessWidget {
  const _Thumb({required this.word, this.size = 30});

  final ChalkWord word;
  final double size;

  @override
  Widget build(BuildContext context) {
    final store = _ChalkScope.of(context);
    final profile = store?.profile;
    final Widget? art = word.row == 'tool'
        ? Image.asset(chalkToolIcon(word.id), fit: BoxFit.contain, filterQuality: FilterQuality.none)
        : profile != null && word.row != 'move'
            ? FittedBox(
                child: SizedBox(
                  width: 48,
                  height: 80,
                  child: CharacterSprite(character: profile.character, classId: store!.gameClass.id, pedestal: false),
                ),
              )
            : null;
    if (art == null) return const SizedBox.shrink();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: _slotBg, border: Border.all(color: kNight, width: 2)),
      child: ClipRect(child: art),
    );
  }
}

/// The picked pieces (D87), right under the title: each with its picture
/// and ×, lime; outlined pink when together they give nothing. A tap drops
/// the piece and opens the picture again.
class _Loadout extends StatelessWidget {
  const _Loadout({required this.line, required this.bad, required this.onDrop, required this.onAdd});

  final Set<String> line;
  final bool bad;
  final ValueChanged<ChalkWord> onDrop;

  /// Opens the picture to pick one more piece.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const order = ['body', 'pattern', 'tool', 'move'];
    final words = [for (final k in line) ?chalkWordByKey(k)]..sort((a, b) => order.indexOf(a.row) - order.indexOf(b.row));
    return Wrap(
      key: const ValueKey('chalk-loadout'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in words)
          GestureDetector(
            key: ValueKey('chalk-word-${w.key}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onDrop(w),
            child: Container(
              height: 46,
              padding: const EdgeInsets.fromLTRB(5, 4, 8, 4),
              decoration: BoxDecoration(
                color: bad ? _slotBg : p.lime,
                border: Border.all(color: bad ? p.pink : kNight, width: 3),
                boxShadow: [BoxShadow(color: kNight, offset: const Offset(3, 3))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Thumb(word: w, size: 34),
                  if (w.row == 'tool' || w.row != 'move') const SizedBox(width: 6),
                  Text(chalkLabel(w).toUpperCase(), style: display(14, kNight)),
                  const SizedBox(width: 8),
                  PxIcon('close', size: 14, color: kNight),
                ],
              ),
            ),
          ),
        GestureDetector(
          key: const ValueKey('chalk-unfold'),
          behavior: HitTestBehavior.opaque,
          onTap: onAdd,
          child: Container(
            height: 46,
            width: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: p.inkFaint, width: 2)),
            child: PxIcon('plus', size: 18, color: p.inkSoft),
          ),
        ),
      ],
    );
  }
}

/// NARROW: only the move words that still give something, on one line with
/// its label.
class _Narrow extends StatelessWidget {
  const _Narrow({required this.line, required this.off, required this.onPick});

  final Set<String> line;
  final bool Function(ChalkWord) off;
  final ValueChanged<ChalkWord> onPick;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final moves = [for (final w in chalkWords) if (w.row == 'move' && !off(w)) w];
    if (moves.length < 2 && !moves.any((w) => line.contains(w.key))) return const SizedBox.shrink();
    return Wrap(
      key: const ValueKey('chalk-narrow'),
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Shout(t('chalk.narrow'), size: 12, color: p.ink),
        ),
        for (final w in moves)
          PickChip(
            id: 'chalk-${w.key}',
            label: chalkLabel(w),
            selected: line.contains(w.key),
            color: p.lime,
            selectedBorder: p.on,
            onTap: () => onPick(w),
          ),
      ],
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

/// What tells a variation apart on its loot card: the words of its name that
/// are not in the move's name or the tools (INCLINE, ONE ARM...); the base
/// variation is STANDARD; a move with one exercise shows its whole name.
String chalkPipLabel(CatalogExercise v, ExerciseGroup card) {
  String clean(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-ZĂÂÎȘȚŞŢ0-9 ]'), ' ');
  final full = clean(displayName(v)).split(' ').where((w) => w.isNotEmpty).toList();
  final skip = {
    ...clean(groupLabel(card.key, card.name)).split(' '),
    for (final w in chalkWords.where((w) => w.row == 'tool')) ...clean(chalkLabel(w)).split(' '),
    ...clean(card.name).split(' '),
  };
  final rest = [for (final w in full) if (!skip.contains(w)) w];
  if (rest.isNotEmpty) return rest.join(' ');
  return card.variants.length > 1 ? t('chalk.standard') : displayName(v).toUpperCase();
}

/// The results as loot cards (D87): one card per move, most common first.
/// The list ends with FORGE IT.
class _LootCards extends StatelessWidget {
  const _LootCards({required this.store, required this.cards, required this.index, required this.onForge});

  final LogStore store;
  final List<ExerciseGroup> cards;
  final ChalkIndex index;
  final VoidCallback onForge;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      key: const ValueKey('chalk-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in cards) ...[
          _LootCard(store: store, card: g, index: index),
          const SizedBox(height: 12),
        ],
        BrutalButton(
          key: const ValueKey('chalk-forge-it'),
          small: true,
          color: p.pink,
          onTap: onForge,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset(chalkToolIcon('hammer'), width: 18, height: 18, fit: BoxFit.contain, filterQuality: FilterQuality.none),
            const SizedBox(width: 6),
            Text(t('forge.go')),
          ]),
        ),
      ],
    );
  }
}

/// One loot card: on the left your lifter and the move's tool; on the right
/// the move's name, body part · tool · how many, DO IT (selects the move and
/// closes CHALK), and one pip per variation.
class _LootCard extends StatelessWidget {
  const _LootCard({required this.store, required this.card, required this.index});

  final LogStore store;
  final ExerciseGroup card;
  final ChalkIndex index;

  void _select(BuildContext context, String id) {
    store.selectExercise(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final first = card.variants.first;
    final (:part, :tool) = index.tagsOf(first);
    final info = [
      if (part != null) bodyPartLabel(part.id),
      if (tool != null) chalkLabel(tool),
      '${card.variants.length}',
    ].join(' · ');
    final picked = card.variants.any((v) => store.pickedCard == v.id);
    final profile = store.profile;
    return Container(
      key: ValueKey('chalk-card-${card.key}'),
      decoration: BoxDecoration(
        color: p.panel,
        border: Border.all(color: picked ? p.pink : p.ink, width: 3),
        boxShadow: [BoxShadow(color: p.ink, offset: const Offset(4, 4))],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The loot's picture: your lifter, and the tool under it.
            Container(
              width: 62,
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              decoration: BoxDecoration(color: p.panel2, border: Border(right: BorderSide(color: p.ink, width: 3))),
              child: Column(
                children: [
                  if (profile != null)
                    SizedBox(
                      height: 58,
                      child: CharacterSprite(character: profile.character, classId: store.gameClass.id, pedestal: false),
                    ),
                  const Spacer(),
                  if (tool != null)
                    Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: _slotBg, border: Border.all(color: kNight, width: 2)),
                      child: Image.asset(chalkToolIcon(tool.id), fit: BoxFit.contain, filterQuality: FilterQuality.none),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(groupLabel(card.key, card.name).toUpperCase(), style: display(20, p.ink))),
                        const SizedBox(width: 6),
                        GestureDetector(
                          key: ValueKey('chalk-do-${card.key}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _select(context, first.id),
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: p.sky,
                              border: Border.all(color: p.ink, width: 2),
                              boxShadow: [BoxShadow(color: p.ink, offset: const Offset(2, 2))],
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(t('chalk.doIt'), style: mono(10, p.on)),
                              const SizedBox(width: 4),
                              PxIcon('next', size: 10, color: p.on),
                            ]),
                          ),
                        ),
                      ],
                    ),
                    Text(info.toUpperCase(), style: mono(9.5, p.inkSoft)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final v in card.variants)
                          _Pip(store: store, v: v, label: chalkPipLabel(v, card), onSelect: () => _select(context, v.id)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "+" (and TODAY) spot of a pip: 44 px, a big enough target.
const kChalkAddSize = 44.0;

/// One variation on a loot card: its name (a tap selects it) and an orange
/// "+" (adds it to Today). Once in Today the pip is lime with a ✓.
class _Pip extends StatelessWidget {
  const _Pip({required this.store, required this.v, required this.label, required this.onSelect});

  final LogStore store;
  final CatalogExercise v;
  final String label;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final on = store.pickedCard == v.id;
    final inToday = store.inToday(v.id);
    final sets = store.setsToday(v.id);
    final fill = inToday || on ? p.lime : p.panel;
    // The class mark (D89) is the design team's; until then only a hint
    // for screen readers. No XP effect.
    return Semantics(
      value: store.fitsMyGear(v) ? 'my gear' : null,
      child: Container(
      key: on ? ValueKey('chalk-result-on-${v.id}') : null,
      height: kChalkAddSize + 4, // the 2 px borders around the 44 px "+"
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: p.ink, width: 2),
        boxShadow: on ? [BoxShadow(color: p.ink, offset: const Offset(2, 2))] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: GestureDetector(
              key: ValueKey('chalk-result-${v.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  sets > 0 ? '$label · ${tn('today.setsToday', sets)}'.toUpperCase() : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(13, inToday || on ? p.on : p.ink),
                ),
              ),
            ),
          ),
          if (inToday)
            Container(
              key: ValueKey('chalk-result-today-${v.id}'),
              width: kChalkAddSize,
              height: double.infinity,
              alignment: Alignment.center,
              color: kNight,
              child: Semantics(label: t('today.title'), child: PxIcon('check', size: 20, color: p.lime)),
            )
          else
            Semantics(
              button: true,
              label: '+ ${t('today.title')}',
              child: GestureDetector(
                key: ValueKey('chalk-result-add-${v.id}'),
                behavior: HitTestBehavior.opaque,
                // Adds this exercise (variation) to Today; CHALK stays open.
                onTap: () => store.addToToday(v.id),
                child: Container(
                  width: kChalkAddSize,
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.orange, border: Border(left: BorderSide(color: p.ink, width: 2))),
                  child: const _Plus(color: kNight),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// The "+" glyph of a pip: two thick bars, square ends like the pixel art.
class _Plus extends StatelessWidget {
  const _Plus({required this.color});

  final Color color;

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

/// 0 matches: the empty loot slot (dashed pink) that says why, FORGE IT, and
/// OR DROP ONE: what each dropped piece brings back.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.line, required this.index, required this.onForge, required this.onDrop});

  final Set<String> line;
  final ChalkIndex index;
  final VoidCallback onForge;
  final ValueChanged<ChalkWord> onDrop;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    const order = ['body', 'pattern', 'tool', 'move'];
    final words = [for (final k in line) ?chalkWordByKey(k)]..sort((a, b) => order.indexOf(b.row) - order.indexOf(a.row));
    final names = [for (final w in words.reversed) chalkLabel(w).toUpperCase()].join(' + ');
    return Column(
      key: const ValueKey('chalk-empty-slot'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomPaint(
          foregroundPainter: _DashedBorder(color: p.pink),
          child: Container(
            color: p.panel,
            padding: const EdgeInsets.fromLTRB(16, 18, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.panel2,
                        border: Border.all(color: p.ink, width: 3),
                        boxShadow: [BoxShadow(color: p.ink, offset: const Offset(3, 3))],
                      ),
                      child: Text('?', style: display(40, p.pink)),
                    ),
                    Positioned(
                      left: -8,
                      top: -12,
                      child: Transform.rotate(
                        angle: -0.06,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          color: kNight,
                          child: Text(t('chalk.emptySlot'), style: display(9, p.lime)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('chalk.noSuch'), style: display(20, p.ink)),
                      const SizedBox(height: 4),
                      Text(t('chalk.noSuchWhy', {'words': names}), style: mono(10.5, p.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        BrutalButton(
          key: const ValueKey('chalk-forge'),
          color: p.pink,
          onTap: onForge,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Image.asset(chalkToolIcon('hammer'), width: 22, height: 22, fit: BoxFit.contain, filterQuality: FilterQuality.none),
            const SizedBox(width: 8),
            Text(t('forge.go')),
          ]),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Shout(t('chalk.dropOne'), size: 12, color: p.ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t('chalk.whatBack'),
                  textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(9.5, p.inkQuiet)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final w in words)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              key: ValueKey('chalk-drop-${w.key}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onDrop(w),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: p.panel, border: Border.all(color: p.ink, width: 3)),
                child: Row(
                  children: [
                    _Thumb(word: w, size: 36),
                    const SizedBox(width: 8),
                    PxIcon('close', size: 12, color: p.ink),
                    const SizedBox(width: 6),
                    Expanded(child: Text(chalkLabel(w).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(15, p.ink))),
                    const SizedBox(width: 6),
                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _dropTag(p, w))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// "26 CORE MOVES": what dropping [w] brings back, named by what stays.
  Widget _dropTag(Pal p, ChalkWord w) {
    final rest = {...line}..remove(w.key);
    final n = index.search(rest).length;
    final kept = [for (final k in rest) ?chalkWordByKey(k)].map((x) => chalkLabel(x).toUpperCase()).join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: p.lime, border: Border.all(color: p.ink, width: 2)),
      child: Text(t('chalk.dropGives', {'n': n, 'words': kept}), style: display(11, p.on)),
    );
  }
}

/// A dashed border, for the empty loot slot.
class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const dash = 9.0, gap = 5.0, w = 3.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawRect(Rect.fromLTWH(x, 0, (dash).clamp(0, size.width - x), w), paint);
      canvas.drawRect(Rect.fromLTWH(x, size.height - w, (dash).clamp(0, size.width - x), w), paint);
    }
    for (var y = 0.0; y < size.height; y += dash + gap) {
      canvas.drawRect(Rect.fromLTWH(0, y, w, (dash).clamp(0, size.height - y)), paint);
      canvas.drawRect(Rect.fromLTWH(size.width - w, y, w, (dash).clamp(0, size.height - y)), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
