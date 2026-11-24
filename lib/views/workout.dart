// The workout (design demo screen 08), with the owner's
// rules (docs/decisions.md): one session per calendar day, so there is NO
// I WORKED button and NO clock (D6, D7).
//
// One card, like the starting-area card (D48):
// - The world on top: the area scene (design PNG layers,
//   lib/views/area_scene.dart) with the lifter in it. TAP THE OBJECT = one
//   working set for the exercise shown below, HOLD IT = take the last set
//   back (D17). The marks stay in the world.
// - Under it: the exercise carousel, one card at a time, with a star
//   button and a delete button. Swipe it both ways, round and round. No
//   targets (D52). No tag row: the class shows in the outfit and the
//   lifter profile (D82).
// - TODAY (D79, D82): one card per Today exercise (variation), with dots
//   and no total, and "+ CHALK" at the right end of the dots row (CHALK is
//   the only way to the catalog). An exercise a CHALK row selected that is
//   not in Today shows after them as a preview (a thin line on top) until
//   you swipe away; its first set adds it. An empty Today shows COPY A PAST
//   DAY and OPEN CHALK.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dates.dart';
import '../game/area_art.dart';
import '../game/content.dart';
import '../game/exercises.dart';
import '../i18n.dart';
import '../labels.dart';
import '../pumplex.dart';
import '../store.dart';
import 'area_scene.dart';
import 'carousel.dart';
import 'chalk.dart';
import 'forge.dart' show showForgeEdit;
import 'workout_layout.dart';

class WorkoutView extends StatefulWidget {
  const WorkoutView({
    super.key,
    required this.stage,
    required this.store,
    required this.onAdd,
    required this.onRemove,
    required this.onBody,
  });

  final Rect stage;
  final LogStore store;

  /// Exercise id -> one set more / one set less.
  final ValueChanged<String> onAdd, onRemove;

  /// Tap on the lifter: opens the lifter profile (D59).
  final VoidCallback onBody;

  @override
  State<WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<WorkoutView> with SwipeCarousel<WorkoutView> {
  /// The keys of the COPY A PAST DAY card and the OPEN CHALK card in the
  /// carousel (D79, D82).
  static const _copyKey = '__copy__', _emptyKey = '__empty__';

  /// The card shown (its exercise id, [_copyKey] or [_emptyKey]). Null: the
  /// first one. Kept in the store, so it is still there after leaving (D75).
  late String? _currentKey = widget.store.pickedCard;

  /// The store's picked card at the last build: when the store picks another
  /// one (a CHALK row, COPY, FORGE IT, a delete), the carousel goes there.
  late String? _seenPick = widget.store.pickedCard;
  String? _burst;
  int _hitRun = 0;

  /// The carousel (D82), refreshed on every build: on an empty Today the
  /// COPY A PAST DAY card (if a past day has cards) and the OPEN CHALK card
  /// (their [String] keys), else the Today cards; then the CHALK preview
  /// card, if any.
  List<Object> _items = const [];

  /// How many Today cards, and how many cards come before them.
  int _todayCount = 0, _todayStart = 0;

  LogStore get _store => widget.store;

  static String _keyOf(Object o) => o is TodayEntry ? o.id : o as String;

  @override
  int get count => _items.length;

  @override
  int get index => max(0, _items.indexWhere((o) => _keyOf(o) == _currentKey));

  @override
  void select(int i) => setState(() => _keep(_keyOf(_items[i])));

  /// Shows card [key] and remembers it (D75; not the COPY or OPEN CHALK card).
  void _keep(String key) {
    _currentKey = key;
    if (key == _copyKey || key == _emptyKey) return;
    _store.setPickedCard(key);
    _seenPick = key;
  }

  TodayEntry? get _current {
    if (_items.isEmpty) return null;
    final o = _items[index];
    return o is TodayEntry ? o : null;
  }

  void _hit() {
    final e = _current;
    if (e == null) return;
    widget.onAdd(e.id); // the first set adds this variation (D79, D82)
    final sets = _store.setsToday(e.id);
    final area = areaById(_store.todaySession?.areaId ?? _store.profile?.areaId);
    HapticFeedback.lightImpact();
    setState(() {
      _keep(e.id);
      _burst = sets % 5 == 0 ? area.stamp : t('workout.plusOne');
      _hitRun++;
    });
  }

  /// Takes back the last set of the exercise on the card.
  void _undo() {
    final e = _current;
    if (e == null) return;
    HapticFeedback.mediumImpact();
    widget.onRemove(e.id);
    setState(() => _burst = null); // undo has no effect animation
  }

  /// The star saves the exercise shown (D72), not the card.
  void _star(TodayEntry e) {
    HapticFeedback.selectionClick();
    setState(() => _keep(e.id)); // stay on this card
    _store.toggleFavorite(e.id);
  }

  /// A chip changes the variation of this card (D82): [id] takes its place.
  void _pick(TodayEntry e, String id) {
    HapticFeedback.selectionClick();
    _store.changeVariant(e.id, id);
    setState(() => _keep(id));
  }

  /// The delete button (D82): exercise [e] leaves Today. With sets today, a
  /// dialog asks first: its sets and their XP go too.
  Future<void> _remove(TodayEntry e) async {
    final sets = _store.setsToday(e.id);
    if (sets > 0 && await _confirmRemove(context, sets) != true) return;
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _burst = null);
    _store.removeFromToday(e.id);
  }

  /// The slide key of carousel item [i]: the move's key, and its number when
  /// the move has an earlier card too. It stays when a chip changes the
  /// variation, so the card does not slide (D79).
  String _slideId(int i) {
    final e = _items[i] as TodayEntry;
    final n = _items.take(i).where((o) => o is TodayEntry && o.card.key == e.card.key).length;
    return n == 0 ? 'exercise-${e.card.key}' : 'exercise-${e.card.key}#${n + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final pick = store.pickedCard;
    if (pick != _seenPick) {
      _seenPick = pick;
      _currentKey = pick;
    }
    final todayIds = store.todayIds;
    // An empty Today (D82): COPY A PAST DAY (D79), then OPEN CHALK when no
    // CHALK preview is there. The carousel never shows the catalog.
    final past = todayIds.isEmpty ? store.pastDays : const <String>[];
    final cards = store.carousel;
    _items = [if (past.isNotEmpty) _copyKey, if (cards.isEmpty) _emptyKey, ...cards];
    _todayCount = todayIds.length;
    _todayStart = _items.length - cards.length;
    final e = _current;
    final onCopy = _keyOf(_items[index]) == _copyKey;
    // The CHALK preview (not in Today, D82) gets a thin line on top.
    final preview = e != null && !todayIds.contains(e.id);
    final area = areaById(store.todaySession?.areaId ?? store.profile?.areaId);
    final art = areaArt[area.id]!;
    // The sets of this exercise (variation) today (D82).
    final sets = e == null ? 0 : store.setsToday(e.id);
    // Old-app days have no class; days frozen by D54 keep theirs and count.
    final firstTime = store.history.where((s) => !s.legacy || s.classId.isNotEmpty).isEmpty;
    // The first-workout tip (app-flow §4.2), until the first set.
    final tip = firstTime && sets == 0;
    return LayoutBuilder(builder: (context, box) {
      final inset = MediaQuery.paddingOf(context).bottom;
      final world = workoutWorld(box.biggest, inset);
      final (scene, scale) = workoutLayout(box.biggest, inset);
      return Stack(
        children: [
          _WorldBackdrop(area: area, floorTop: scene.top + art.floorPos.dy * scale),
          _ExercisePanel(
            maxHeight: max(0.0, box.maxHeight - world.bottom),
            inset: inset,
            swipe: swipe,
            card: _card(context, e, onCopy: onCopy, past: past, preview: preview),
            dots: _dotsRow(context, onCopy, sets),
          ),
          // The scene. TAP THE OBJECT = one working set, HOLD IT = take one back.
          Positioned.fromRect(
            rect: scene,
            child: AreaScene(
              art: art,
              scale: scale,
              count: sets,
              hitRun: _hitRun,
              burstText: _burst,
              hitLabel: '${area.hint}: one working set. Hold to take one back.',
              onHit: e == null ? null : _hit,
              onUndo: e == null ? null : _undo,
            ),
          ),
          // More sets than mark spots (the arcade has its own counter).
          if (sets > art.markPositions.length && art.ledRect == null)
            _SetCountBadge(art: art, scene: scene, scale: scale, world: world, sets: sets, tip: tip),
          // Tap the lifter to open the lifter profile (D59).
          Positioned.fromRect(
            rect: widget.stage,
            child: GestureDetector(
              key: const ValueKey('workout-character'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBody,
            ),
          ),
          if (e != null) _SkyHint(world: world, area: area, tip: tip),
        ],
      );
    });
  }

  /// The card the carousel shows: COPY A PAST DAY, OPEN CHALK or exercise [e].
  Widget _card(BuildContext context, TodayEntry? e,
      {required bool onCopy, required List<String> past, required bool preview}) {
    final store = _store;
    if (onCopy) return slide('copy-day', _CopyDay(store: store, days: past));
    if (e == null) return slide('open-chalk', _OpenChalk(onOpen: () => showChalkSheet(context, store)));
    return slide(
      _slideId(index),
      _TopLine(
        on: preview,
        child: _ExerciseText(
          g: e.card,
          full: exerciseCatalog.byKey[e.card.key] ?? e.card,
          v: e.exercise,
          favorite: store.isFavorite(e.id),
          hard: store.isHard(e.card, e.exercise),
          onStar: () => _star(e),
          onPick: (id) => _pick(e, id),
          onRemove: preview ? null : () => _remove(e),
          onEdit: switch (store.forgedById(e.id)) {
            final f? => () {
                HapticFeedback.mediumImpact();
                showForgeEdit(Navigator.of(context), store, f);
              },
            null => null,
          },
        ),
      ),
    );
  }

  /// Dots for the Today cards (no total, D79; no label after them, D81),
  /// and "+ CHALK" at the right end, in thumb reach (D82). With [sets] on
  /// the card shown, its set count ("2 SETS") at the left end: the world's
  /// count badge shows only past the mark spots.
  Widget _dotsRow(BuildContext context, bool onCopy, int sets) => Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Row(
          children: [
            if (sets > 0) ...[
              Tag(tn('sets', sets), key: const ValueKey('card-set-count'), bg: kNight, fg: Pal.of(context).lime, size: 13, angle: 0),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: _TodayDots(
                key: const ValueKey('exercise-counter'),
                today: _todayCount,
                current: onCopy ? -1 : index - _todayStart,
                onCopy: onCopy,
                onDot: (i) => jump(_todayStart + i),
              ),
            ),
            const SizedBox(width: 8),
            _ChalkButton(chalk: _store.chalk.length, onTap: () => showChalkSheet(context, _store)),
          ],
        ),
      );
}

/// The world behind the scene (D75): the area's sky fills the view, and its
/// floor goes from [floorTop] down to the exercise part (the shell draws the
/// lifter in the scene).
class _WorldBackdrop extends StatelessWidget {
  const _WorldBackdrop({required this.area, required this.floorTop});

  final Area area;
  final double floorTop;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: Color(area.sky))),
            Positioned(left: 0, right: 0, top: floorTop, bottom: 0, child: ColoredBox(color: Color(area.floor))),
          ],
        ),
      );
}

/// The exercise part: at the bottom, [maxHeight] tall (all the room under
/// the world; a taller card is cut off there), so an empty Today has no
/// floor band above it.
/// No tag row (D82): the class shows in the outfit and the lifter profile.
/// The world adds sets to the exercise on the [card]; the [dots] row is
/// under it, and both swipe the carousel.
class _ExercisePanel extends StatelessWidget {
  const _ExercisePanel({
    required this.maxHeight,
    required this.inset,
    required this.swipe,
    required this.card,
    required this.dots,
  });

  final double maxHeight, inset;
  final Widget Function({required Key key, required Widget child}) swipe;
  final Widget card, dots;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      // All the room under the world, whatever the card: a short card (an
      // empty Today) leaves no floor band between the world and the panel.
      child: SizedBox(
        height: maxHeight,
        child: DecoratedBox(
          key: const ValueKey('exercise-part'),
          decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.ink, width: 3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 3), // the border
              Expanded(
                child: swipe(
                  key: const ValueKey('exercise-card'),
                  // The card at the top, the dots at the bottom.
                  child: Column(
                    children: [
                      // Bounded, so a tall card is cut off, not overflowing.
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: card,
                        ),
                      ),
                      dots,
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
              SizedBox(height: inset),
            ],
          ),
        ),
      ),
    );
  }
}

/// More sets than mark spots: the number of [sets], next to the marks, in
/// the [world] and never cut off (D74, D75), off the sky hint (taller with
/// the first-workout [tip]).
class _SetCountBadge extends StatelessWidget {
  const _SetCountBadge({
    required this.art,
    required this.scene,
    required this.scale,
    required this.world,
    required this.sets,
    required this.tip,
  });

  final AreaArt art;
  final Rect scene, world;
  final int scale, sets;
  final bool tip;

  @override
  Widget build(BuildContext context) {
    final spots = art.markPositions.length;
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _CountLayout(
            (badge) => sceneCountPos(
              art,
              scene,
              scale,
              badge,
              Rect.fromLTRB(world.left + 6, world.top + 6, world.right - 6, world.bottom - 6),
              avoid: Rect.fromLTWH(world.left + 8, world.top + 4, 230, tip ? 64 : 38),
            ),
          ),
          child: Container(
            key: const ValueKey('scene-count'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: kNight,
            child: Text(tn('sets', sets), style: display(15, markLaps[(markLap(0, sets, spots) - 1) % markLaps.length])),
          ),
        ),
      ),
    );
  }
}

/// The hint over the sky, and the first-workout [tip] under it.
class _SkyHint extends StatelessWidget {
  const _SkyHint({required this.world, required this.area, required this.tip});

  final Rect world;
  final Area area;
  final bool tip;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Positioned(
      left: world.left + 12,
      top: world.top + 8,
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tag(area.hint, bg: kNight, fg: Color(area.accent), size: 13, angle: -2),
            if (tip) ...[
              const SizedBox(height: 4),
              Tag(t('workout.firstTip'), bg: p.lime, fg: p.on, size: 11, angle: 1),
            ],
          ],
        ),
      ),
    );
  }
}

/// Puts the set-count badge where [pos] says for its size.
class _CountLayout extends SingleChildLayoutDelegate {
  _CountLayout(this.pos);

  final Offset Function(Size badge) pos;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => pos(childSize);

  @override
  bool shouldRelayout(_CountLayout old) => true;
}

/// The tap target of "+ CHALK": at least this high and wide (D82).
const kChalkButtonSize = 48.0;

/// "+ CHALK" at the right end of the dots row (D82): it opens the CHALK
/// sheet, the only way to the catalog. Chalk white on night ink; "· n"
/// with n words picked.
class _ChalkButton extends StatelessWidget {
  const _ChalkButton({required this.chalk, required this.onTap});

  final int chalk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconTapButton(
        key: const ValueKey('filter-chalk'),
        size: kChalkButtonSize,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kNight,
          border: Border(bottom: BorderSide(color: kChalk.withValues(alpha: 0.6), width: 3)),
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        icon: Text(chalk == 0 ? t('chalk.add') : '${t('chalk.add')} · $chalk', style: display(14, kChalk)),
      );
}

/// An empty Today (D82): one card that sends the lifter to CHALK, the only
/// way to the catalog.
class _OpenChalk extends StatelessWidget {
  const _OpenChalk({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      key: const ValueKey('today-empty-card'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Shout(t('today.empty'), size: 15, color: p.ink),
          const SizedBox(height: 2),
          Text(t('today.openChalkHint'), style: mono(11, p.inkHint)),
          const SizedBox(height: 12),
          BrutalButton(
            key: const ValueKey('today-open-chalk'),
            small: true,
            color: p.lime,
            onTap: () {
              HapticFeedback.selectionClick();
              onOpen();
            },
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(t('today.openChalk'))),
          ),
        ],
      ),
    );
  }
}

/// Asks before a Today card with [sets] sets today goes (D82). True: remove.
Future<bool?> _confirmRemove(BuildContext context, int sets) => showDialog<bool>(
      context: context,
      builder: (context) {
        final p = Pal.of(context);
        return Dialog(
          key: const ValueKey('today-remove-dialog'),
          backgroundColor: p.bg,
          shape: Border.all(color: p.ink, width: 3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Shout(t('today.removeTitle'), size: 18, color: p.ink),
                const SizedBox(height: 4),
                Text(tn('today.removeSets', sets), style: mono(12, p.ink)),
                const SizedBox(height: 14),
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: BrutalButton(
                        key: const ValueKey('today-remove-cancel'),
                        small: true,
                        color: p.sky, // the secondary button: night ink on sky
                        onTap: () => Navigator.pop(context, false),
                        child: Text(t('today.removeKeep')),
                      ),
                    ),
                    Expanded(
                      child: BrutalButton(
                        key: const ValueKey('today-remove-confirm'),
                        small: true,
                        color: p.pink,
                        onTap: () => Navigator.pop(context, true),
                        child: Text(t('today.removeYes')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

/// The chip rows the fixed chip area holds (D79): the most any card of the
/// catalog has (Bench Press, Pull-Up, Lat Pulldown). A test checks it.
const chipAreaRows = 5;

/// One chip row: the gap, the row name and the chips.
const _chipRowHeight = 57.0;
/// The CHALK preview card, not in Today: a thin line on top (D82).
class _TopLine extends StatelessWidget {
  const _TopLine({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => !on
      ? child
      : DecoratedBox(
          key: const ValueKey('suggested-line'),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: Pal.of(context).ink.withValues(alpha: 0.35)))),
          child: child,
        );
}

/// Under the carousel (D79): one dot per Today card (the one shown filled),
/// no total, and no label after them (D81). On the COPY card: SWIPE FOR
/// SUGGESTED.
class _TodayDots extends StatelessWidget {
  const _TodayDots({
    super.key,
    required this.today,
    required this.current,
    required this.onCopy,
    required this.onDot,
  });

  /// How many Today cards, and the one shown (0-based; >= [today]: a card
  /// after Today; -1: the COPY card).
  final int today, current;
  final bool onCopy;
  final ValueChanged<int> onDot;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    if (onCopy) return Text(t('today.swipe'), style: mono(11, p.inkQuiet));
    return SizedBox(
      height: 18,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < today; i++)
              GestureDetector(
                key: ValueKey('today-dot-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onDot(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: i == current ? p.lime : p.panel,
                      border: Border.all(color: p.ink, width: 2),
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

/// COPY A PAST DAY (D79): the first card of an empty Today. ◀ ▶ step
/// through the past days with sessions (newest first); the day's exercises;
/// COPY puts their cards in Today (no sets).
class _CopyDay extends StatefulWidget {
  const _CopyDay({required this.store, required this.days});

  final LogStore store;

  /// Past days with cards, newest first.
  final List<String> days;

  @override
  State<_CopyDay> createState() => _CopyDayState();
}

class _CopyDayState extends State<_CopyDay> {
  int _i = 0;

  /// The most names shown; the rest are "+ n MORE".
  static const _names = 4;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final days = widget.days;
    final i = _i.clamp(0, days.length - 1);
    final day = days[i];
    final moves = widget.store.dayMoves(day);
    Widget arrow(String key, String label, String glyph, int to) {
      final on = to >= 0 && to < days.length;
      return Semantics(
        button: true,
        enabled: on,
        label: label,
        child: GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: on ? () => setState(() => _i = to) : null,
          child: Opacity(
            opacity: on ? 1 : 0.3,
            child: Container(
              width: 38,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.sky, border: Border.all(color: p.ink, width: 2)),
              child: Text(glyph, style: display(16, p.on)),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('copy-day-card'),
      // Only left / right moves the carousel (D65).
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Shout(t('today.empty'), size: 15, color: p.ink),
          const SizedBox(height: 2),
          Text(t('today.emptyHint'), style: mono(11, p.inkHint)),
          const SizedBox(height: 8),
          Row(
            children: [
              arrow('copy-older', t('today.olderDay'), '◀', i + 1),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  color: kNight,
                  child: Text(shortDate(parseDateKey(day)).toUpperCase(), key: const ValueKey('copy-date'), style: display(17, p.onNight)),
                ),
              ),
              const SizedBox(width: 8),
              arrow('copy-newer', t('today.newerDay'), '▶', i - 1),
            ],
          ),
          const SizedBox(height: 6),
          for (final m in moves.take(_names))
            Text('▪ ${displayName(m).toUpperCase()}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, p.ink)),
          if (moves.length > _names) Text(t('today.more', {'n': moves.length - _names}), style: mono(11, p.inkQuiet)),
          const SizedBox(height: 8),
          BrutalButton(
            key: const ValueKey('copy-day-button'),
            small: true,
            color: p.lime,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.store.copyDay(day);
            },
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(tn('today.copyCards', moves.length))),
          ),
          const SizedBox(height: 4),
          Text(t('today.copyNote'), style: mono(9.5, p.ink.withValues(alpha: 0.55))),
        ],
      ),
    );
  }
}

/// The card shown under the world: the exercise picked as the title, the
/// HARD badge, the delete button and the star, then the modifier chips that
/// pick the exercise (D55). The sets show in the world (D74).
class _ExerciseText extends StatelessWidget {
  const _ExerciseText({
    required this.g,
    required this.full,
    required this.v,
    required this.favorite,
    this.hard = false,
    required this.onStar,
    required this.onPick,
    this.onRemove,
    this.onEdit,
  });

  /// The long-press on the title of a forged move (D78); null otherwise.
  final VoidCallback? onEdit;

  /// The card (all its exercises, D82).
  final ExerciseGroup g;

  /// The same move with all its exercises (for the greyed-out chips).
  final ExerciseGroup full;

  /// The exercise picked.
  final CatalogExercise v;
  final bool favorite;

  /// Above your mode (D70): a HARD badge by the title.
  final bool hard;
  final VoidCallback onStar;
  final ValueChanged<String> onPick;

  /// The delete button (D82): the card leaves Today. Null: no button (the
  /// CHALK preview is not in Today).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The exercise picked is the title (D75).
              // A forged move (D78): a long-press on the title opens the
              // FORGE card in edit mode. Only here, away from the world's
              // hold (D17, D48).
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('exercise-title-area'),
                  behavior: HitTestBehavior.opaque,
                  onLongPress: onEdit,
                  child: ShadowTitle(
                    displayName(v).toUpperCase(),
                    textKey: const ValueKey('exercise-title'),
                    size: 28,
                    shadowColor: p.orange,
                  ),
                ),
              ),
              if (hard)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 6),
                  child: Tag(t('workout.hard'), key: const ValueKey('hard-badge'), bg: p.pink, fg: p.on, size: 11, angle: -3),
                ),
              // A tap, so it does not take the carousel's swipes (D66); it
              // sits on the card, away from the world (D48).
              if (onRemove != null)
                IconTapButton(
                  key: const ValueKey('today-remove'),
                  label: t('today.remove'),
                  size: 0,
                  padding: const EdgeInsets.fromLTRB(6, 9, 4, 6),
                  decoration: const BoxDecoration(),
                  onTap: onRemove!,
                  icon: PxIcon('trash', size: 24, color: p.ink.withValues(alpha: 0.45)),
                ),
              IconTapButton(
                key: const ValueKey('favorite-star'),
                selected: favorite,
                label: favorite ? t('workout.favRemove') : t('workout.favAdd'),
                size: 0,
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(),
                onTap: onStar,
                icon: PxIcon('star', size: 30, color: favorite ? p.orange : p.ink.withValues(alpha: 0.25)),
              ),
            ],
          ),
          ),
          // No subtitle and no sets here (D74): the sets show in the world.
          // Modifiers: equipment first, then one row per way the exercises
          // with this equipment differ (D57). The area has a fixed height for
          // the most rows a card has (D79), so the card does not move with
          // its number of rows; on a short screen it shrinks and scrolls up
          // and down. Each row scrolls sideways: a drag on a long row scrolls
          // it, a drag elsewhere swipes the carousel.
          Flexible(
            child: SizedBox(
              key: const ValueKey('mod-area'),
              height: chipAreaRows * _chipRowHeight,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (axis, values) in full.axesFor(v)) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(axisLabel(axis).toUpperCase(), style: mono(10.5, p.inkSoft)),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        key: ValueKey('mod-row-${axis.id}'),
                        scrollDirection: Axis.horizontal,
                        // Room for the selected chip's shadow.
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                        child: Row(
                          spacing: 6,
                          children: [
                            for (final value in values)
                              _modChip(
                                p,
                                'mod-${axis.id}-${value ?? 'none'}',
                                value == null ? axisNone(axis) : modLabel(value),
                                selected: v.mods[axis.id] == value,
                                target: v.mods[axis.id] == value ? null : chipTarget(g, v, axis.id, value),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One modifier value on the card (key [id]). Greyed out when no exercise
  /// of the move has it ([target] null and not [selected]). A thin border
  /// means a tap also changes another modifier (D57).
  Widget _modChip(Pal p, String id, String label, {required bool selected, required ({CatalogExercise v, bool exact})? target}) {
    final off = !selected && target == null;
    final jump = target != null && !target.exact;
    return PickChip(
      id: id,
      label: label,
      selected: selected,
      color: p.lime,
      line: jump ? 1 : 2,
      opacity: off ? 0.3 : jump ? 0.7 : 1,
      enabled: !off,
      onTap: target == null ? null : () => onPick(target.v.id),
    );
  }
}
