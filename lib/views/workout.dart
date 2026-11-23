// The workout (design demo screen 08), with the owner's
// rules (docs/decisions.md): one session per calendar day, so there is NO
// I WORKED button and NO clock (D6, D7).
//
// One card, like the starting-area card (D48):
// - The world on top: the area scene (design PNG layers,
//   lib/views/area_scene.dart) with the lifter in it. TAP THE OBJECT = one
//   working set for the exercise shown below, HOLD IT = take the last set
//   back (D17). The marks stay in the world.
// - The filter tags (D49-D53): CLASS, DIFFICULTY and BODY PART open the
//   filter sheet (lib/views/filters.dart); the star tag shows favorites
//   only.
// - Under them: the exercise carousel over every exercise the filters
//   show (D50), one at a time, with a star button. Swipe it both ways,
//   round and round. No targets (D52).
// - TODAY (D79): the carousel shows the Today cards first, with dots and
//   no total, then a thin line and SUGGESTED (the rest of the cards). An
//   empty Today starts with the COPY A PAST DAY card.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dates.dart';
import '../game/area_art.dart';
import '../game/content.dart';
import '../game/exercises.dart';
import '../i18n.dart';
import '../pumplex.dart';
import '../store.dart';
import 'area_scene.dart';
import 'carousel.dart';
import 'chalk.dart';
import 'filters.dart';
import 'sprite.dart' show classColor;

/// The least room the exercise part under the world keeps (D75): the filter
/// tags, the exercise (title, star, modifier rows) and the counter.
const _exerciseMin = 240.0;

/// The scene's part of the world in a workout view of [area] (D75): the whole
/// width, from the top, just tall enough for the scene at the biggest
/// whole-number scale for the width. It depends on the size only, so the
/// scene (and the lifter the shell draws in it) never moves. The exercise
/// part is only as tall as its content, at the bottom; the world's floor
/// colour fills the space between them. The workout is no card (only when
/// minimised).
Rect workoutWorld(Size area, [double bottomInset = 0]) {
  final byWidth = max(1, (area.width / sceneSize.width).floor());
  final h = min(sceneSize.height * byWidth + 8, area.height - bottomInset - _exerciseMin);
  return Rect.fromLTWH(0, 0, area.width, h);
}

/// The scene's rect and whole-number scale in a workout view of [area]: the
/// biggest scale at which the whole scene fits in [workoutWorld], so no mark
/// is ever cut off (D75). It stands on the bottom of that rect; the area's
/// sky and floor colours fill the rest of the world.
(Rect, int) workoutLayout(Size area, [double bottomInset = 0]) {
  final world = workoutWorld(area, bottomInset);
  final scale = max(1, min(world.width / sceneSize.width, world.height / sceneSize.height).floor());
  final w = sceneSize.width * scale, h = sceneSize.height * scale;
  return (Rect.fromLTWH(world.center.dx - w / 2, world.bottom - h, w, h), scale);
}

/// The arena only (D61): the scene cut to a square around its middle. The
/// minimised workout shows this.
Rect workoutArena(Size area, [double bottomInset = 0]) {
  final (scene, _) = workoutLayout(area, bottomInset);
  final side = min(scene.width, scene.height);
  return Rect.fromCenter(center: scene.center, width: side, height: side);
}

/// The lifter's place in the scene: the design's lifter position (the same
/// in every area), feet on the shadow.
Rect workoutStage(Size area, [double bottomInset = 0]) {
  final (scene, scale) = workoutLayout(area, bottomInset);
  return sceneLifterRect(areaArt.values.first, scene, scale);
}

/// Where the set-count badge goes (size [badge]) for a scene at [scene],
/// scale [scale], in a view whose free world is [bounds]: next to the marks'
/// box (above it first), inside [bounds], off the object to hit, the marks
/// and [avoid] (the hint over the sky). The least covering spot when none is
/// free.
Offset sceneCountPos(AreaArt art, Rect scene, int scale, Size badge, Rect bounds, {Rect avoid = Rect.zero}) {
  final s = scale.toDouble();
  final marks = markBox(art, scene, scale);
  final object = Rect.fromLTWH(
      scene.left + art.hitBox.left * s, scene.top + art.hitBox.top * s, art.hitBox.width * s, art.hitBox.height * s);
  // Marks on the object (the Gainsgard wall): go round both.
  final m = marks.overlaps(object) ? marks.expandToInclude(object) : marks;
  const gap = 6.0;
  final w = badge.width, h = badge.height;
  final above = m.top - gap - h, below = m.bottom + gap;
  final candidates = [
    Offset(m.right - w, above),
    Offset(m.center.dx - w / 2, above),
    Offset(m.left, above),
    Offset(m.right + gap, m.top),
    Offset(m.left - gap - w, m.top),
    Offset(m.right - w, below),
    Offset(m.left, below),
  ];
  double cover(Rect r, Rect o) {
    final i = r.intersect(o);
    return i.width > 0 && i.height > 0 ? i.width * i.height : 0;
  }

  var best = Offset.zero;
  var least = double.infinity;
  for (final c in candidates) {
    final x = c.dx.clamp(bounds.left, max(bounds.left, bounds.right - w)).toDouble();
    final y = c.dy.clamp(bounds.top, max(bounds.top, bounds.bottom - h)).toDouble();
    final r = Rect.fromLTWH(x, y, w, h);
    final k = cover(r, object) + cover(r, marks) + cover(r, avoid);
    if (k < least) {
      least = k;
      best = Offset(x, y);
      if (k == 0) break;
    }
  }
  return best;
}

/// The box around every mark spot of [art] for a scene at [scene], scale [scale].
Rect markBox(AreaArt art, Rect scene, int scale) {
  final s = scale.toDouble();
  var box = Rect.zero;
  for (final (i, p) in art.markPositions.indexed) {
    final size = art.markFifth != null && i % 5 == 4 ? art.markFifth!.size : art.mark.size;
    final r = Rect.fromLTWH(scene.left + p.dx * s, scene.top + p.dy * s, size.width * s, size.height * s);
    box = i == 0 ? r : box.expandToInclude(r);
  }
  return box;
}

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
  /// The key of the COPY A PAST DAY card in the carousel (D79).
  static const _copyKey = '__copy__';

  /// The card shown (a group key, or [_copyKey]). Null: the first one. Kept
  /// in the store, so it is still there after leaving (D75).
  late String? _currentKey = widget.store.pickedCard;

  /// The store's picked card at the last build: when the store picks another
  /// one (a CHALK row, COPY, FORGE IT), the carousel goes there.
  late String? _seenPick = widget.store.pickedCard;
  bool _started = false;
  String? _burst;
  int _hitRun = 0;

  /// The carousel (D79), refreshed on every build: the COPY A PAST DAY card
  /// (null) on an empty Today, the Today cards, then the rest.
  List<ExerciseGroup?> _items = const [];

  /// How many Today cards: the first ones after the COPY card.
  int _todayCount = 0;

  LogStore get _store => widget.store;

  @override
  int get count => _items.length;

  @override
  int get index => max(0, _items.indexWhere((g) => (g?.key ?? _copyKey) == _currentKey));

  @override
  void select(int i) => setState(() => _keep(_items[i]?.key ?? _copyKey));

  /// Shows card [key] and remembers it (D75; not the COPY card).
  void _keep(String key) {
    _currentKey = key;
    if (key == _copyKey) return;
    _store.setPickedCard(key);
    _seenPick = key;
  }

  ExerciseGroup? get _current => _items.isEmpty ? null : _items[index];

  void _hit() {
    final g = _current;
    if (g == null) return;
    widget.onAdd(_store.variantFor(g).id);
    final sets = _store.groupSetsToday(g.key);
    final area = areaById(_store.todaySession?.areaId ?? _store.profile?.areaId);
    HapticFeedback.lightImpact();
    setState(() {
      _keep(g.key);
      _burst = sets % 5 == 0 ? area.stamp : t('workout.plusOne');
      _hitRun++;
    });
  }

  /// Takes back the last set of the exercise picked on the card.
  void _undo() {
    final g = _current;
    if (g == null) return;
    HapticFeedback.mediumImpact();
    widget.onRemove(_store.variantFor(g).id);
    setState(() => _burst = null); // undo has no effect animation
  }

  /// The star saves the exercise shown (D72), not the card.
  void _star(ExerciseGroup g) {
    HapticFeedback.selectionClick();
    setState(() => _keep(g.key)); // stay on this card
    _store.toggleFavorite(_store.variantFor(g).id);
  }

  void _pick(ExerciseGroup g, String id) {
    HapticFeedback.selectionClick();
    setState(() => _keep(g.key));
    _store.pickVariant(id);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final store = _store;
    final pick = store.pickedCard;
    if (pick != _seenPick) {
      _seenPick = pick;
      _currentKey = pick;
    }
    final todayKeys = store.todayCards;
    // An empty Today starts with COPY A PAST DAY (D79), not in a search.
    final past = todayKeys.isEmpty && store.chalk.isEmpty ? store.pastDays : const <String>[];
    _items = [if (past.isNotEmpty) null, ...store.carousel];
    _todayCount = todayKeys.length;
    if (!_started) {
      _started = true;
      if (past.isNotEmpty) _currentKey = _copyKey; // a new day opens on it
    }
    final todayStart = past.isNotEmpty ? 1 : 0;
    final e = _current;
    final onCopy = _items.isNotEmpty && _items[index] == null;
    // The first card after Today gets a thin line on top (D79).
    final firstRest = e != null && _todayCount > 0 && index == todayStart + _todayCount;
    final f = store.filter;
    final today = store.todaySession;
    final area = areaById(today?.areaId ?? store.profile?.areaId);
    final art = areaArt[area.id]!;
    final accent = Color(area.accent);
    final cls = classById(f.classId);
    final sets = e == null ? 0 : store.groupSetsToday(e.key);
    // Old-app days have no class; days frozen by D54 keep theirs and count.
    final firstTime = store.history.where((s) => !s.legacy || s.classId.isNotEmpty).isEmpty;
    final body = f.muscle != null ? muscleLabel(f.muscle!) : f.body != null ? bodyPartLabel(f.body!) : t('filter.allBodyParts');
    void openBody() => showFilterSheet(context, store);
    return LayoutBuilder(builder: (context, box) {
      final inset = MediaQuery.paddingOf(context).bottom;
      final world = workoutWorld(box.biggest, inset);
      final (scene, scale) = workoutLayout(box.biggest, inset);
      final spots = art.markPositions.length;
      return Stack(
        children: [
          // The world fills the width and everything above the exercise part
          // (D75): the area's sky and floor around the scene (the shell draws
          // the lifter in it). The floor goes down to the exercise part.
          Positioned.fill(child: ColoredBox(color: Color(area.sky))),
          Positioned(
            left: 0,
            right: 0,
            top: scene.top + art.floorPos.dy * scale,
            bottom: 0,
            child: ColoredBox(color: Color(area.floor)),
          ),
          // The exercise part: at the bottom, only as tall as its content, at
          // most the room under the scene (a taller card is cut off there).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: max(0.0, box.maxHeight - world.bottom)),
              child: DecoratedBox(
              key: const ValueKey('exercise-part'),
              decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.ink, width: 3))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 3), // the border
                  // The tag row (D72): the class as a label (not a filter),
                  // BODY PART (opens its sheet) and the star (favorites
                  // only). Difficulty is not a filter (D70). The row
                  // shrinks to fit when the names are long.
                  Padding(
                    key: const ValueKey('workout-filters'),
                    padding: const EdgeInsets.fromLTRB(16, 10, 22, 0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                      spacing: 6,
                      children: [
                        Tag(cls.name, key: const ValueKey('class-label'), bg: kNight, fg: classColor(p, cls.id), size: 12, angle: 0),
                        _TapTag(
                          key: const ValueKey('filter-body'),
                          onTap: openBody,
                          child: Tag(body, bg: f.body == null ? p.panel2 : p.sky, fg: f.body == null ? p.ink : p.on, size: 12, angle: 0),
                        ),
                        _TapTag(
                          key: const ValueKey('filter-favorites'),
                          label: f.favorites ? t('filter.favOn') : t('filter.favOff'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            store.setFilter(f.copyWith(favorites: !f.favorites));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: f.favorites ? p.orange : p.panel2,
                            child: PxIcon('star', size: 16, color: f.favorites ? p.on : p.ink.withValues(alpha: 0.4)),
                          ),
                        ),
                        // CHALK, the search over all exercises (D72): chalk
                        // white on night ink; CHALK · n with n words picked.
                        _TapTag(
                          key: const ValueKey('filter-chalk'),
                          onTap: () => showChalkSheet(context, store),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 3),
                            decoration: BoxDecoration(
                              color: kNight,
                              border: Border(bottom: BorderSide(color: kChalk.withValues(alpha: 0.6), width: 2)),
                            ),
                            child: Text(
                              store.chalk.isEmpty ? t('chalk.title') : '${t('chalk.title')} · ${store.chalk.length}',
                              style: display(12, kChalk),
                            ),
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),
                  // Under the tags: the exercise carousel. The world adds
                  // sets to the exercise shown here.
                  Flexible(
                    child: _items.isEmpty
                        ? _Empty(store: store)
                        : swipe(
                            key: const ValueKey('exercise-card'),
                            // As tall as the exercise, the counter at the
                            // bottom: no empty band (D75).
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Bounded, so a tall card is cut off, not overflowing.
                                Flexible(child: AnimatedSize(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: e == null
                                      ? slide('copy-day', _CopyDay(store: store, days: past))
                                      : slide(
                                    'exercise-${e.key}',
                                    _TopLine(on: firstRest, child: _ExerciseText(
                                      g: e,
                                      full: exerciseCatalog.byKey[e.key] ?? e,
                                      v: store.variantFor(e),
                                      sets: sets,
                                      xp: store.groupXpToday(e.key),
                                      favorite: store.isFavorite(store.variantFor(e).id),
                                      hard: store.isHard(e, store.variantFor(e)),
                                      onStar: () => _star(e),
                                      onPick: (id) => _pick(e, id),
                                    )),
                                ))),
                                // Dots for the Today cards (no total, D79),
                                // then a thin line and SUGGESTED.
                                _TodayDots(
                                  key: const ValueKey('exercise-counter'),
                                  today: _todayCount,
                                  current: onCopy ? -1 : index - todayStart,
                                  onCopy: onCopy,
                                  hasRest: count - todayStart > _todayCount,
                                  restLabel: store.chalk.isEmpty ? t('today.suggested') : t('chalk.title'),
                                  onDot: (i) => jump(todayStart + i),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ),
                  ),
                  SizedBox(height: inset),
                ],
              ),
            ),
            ),
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
          // More sets than mark spots: the number of sets, next to the marks,
          // in the world and never cut off (D74, D75). The arcade has its own
          // counter.
          if (sets > spots && art.ledRect == null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomSingleChildLayout(
                  delegate: _CountLayout(
                    (badge) => sceneCountPos(
                      art,
                      scene,
                      scale,
                      badge,
                      Rect.fromLTRB(world.left + 6, world.top + 6, world.right - 6, world.bottom - 6),
                      avoid: Rect.fromLTWH(world.left + 8, world.top + 4, 230, firstTime && sets == 0 ? 64 : 38),
                    ),
                  ),
                  child: Container(
                  key: const ValueKey('scene-count'),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: kNight,
                  child: Text('$sets SETS', style: display(15, markLaps[(markLap(0, sets, spots) - 1) % markLaps.length])),
                ),
                ),
              ),
            ),
          // Tap the lifter to open the lifter profile (D59).
          Positioned.fromRect(
            rect: widget.stage,
            child: GestureDetector(
              key: const ValueKey('workout-character'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBody,
            ),
          ),
          // The hint over the sky (and the first-workout tip).
          if (e != null)
            Positioned(
              left: world.left + 12,
              top: world.top + 8,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tag(area.hint, bg: kNight, fg: accent, size: 13, angle: -2),
                    // First-workout tip (app-flow §4.2), until the first set.
                    if (firstTime && sets == 0) ...[
                      const SizedBox(height: 4),
                      Tag(t('workout.firstTip'), bg: p.lime, fg: p.on, size: 11, angle: 1),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    });
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

/// A filter tag you can tap.
class _TapTag extends StatelessWidget {
  const _TapTag({super.key, required this.child, required this.onTap, this.label});

  final Widget child;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );
}

/// No exercise passes the filters.
class _Empty extends StatelessWidget {
  const _Empty({required this.store});

  final LogStore store;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final f = store.filter;
    final text = !f.favorites
        ? t('filter.empty')
        : store.favorites.isEmpty
            ? t('filter.noFavorites')
            : t('filter.noFavoritesMatch');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, key: const ValueKey('exercise-empty'), textAlign: TextAlign.center, style: mono(13, p.ink)),
            const SizedBox(height: 10),
            BrutalButton(
              key: const ValueKey('filter-reset-empty'),
              small: true,
              color: p.lime,
              onTap: store.resetFilter,
              child: Text(t('filter.reset')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The first card after Today: a thin line on top (D79).
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
/// no total; then a thin line and SUGGESTED (bright on a card after Today).
/// On the COPY card: SWIPE FOR SUGGESTED.
class _TodayDots extends StatelessWidget {
  const _TodayDots({
    super.key,
    required this.today,
    required this.current,
    required this.onCopy,
    required this.hasRest,
    required this.restLabel,
    required this.onDot,
  });

  /// How many Today cards, and the one shown (0-based; >= [today]: a card
  /// after Today; -1: the COPY card).
  final int today, current;
  final bool onCopy, hasRest;
  final String restLabel;
  final ValueChanged<int> onDot;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    if (onCopy) return Text(t('today.swipe'), style: mono(11, p.ink.withValues(alpha: 0.6)));
    final inRest = current >= today;
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
            if (hasRest) ...[
              if (today > 0) Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 8), color: p.ink.withValues(alpha: 0.5)),
              Text(restLabel,
                  key: const ValueKey('suggested-label'),
                  style: mono(11, inRest ? p.ink : p.ink.withValues(alpha: 0.5)).copyWith(fontWeight: inRest ? FontWeight.bold : null)),
            ],
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
          Text(t('today.emptyHint'), style: mono(11, p.ink.withValues(alpha: 0.75))),
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
                  child: Text(shortDate(parseDateKey(day)).toUpperCase(), key: const ValueKey('copy-date'), style: display(17, Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              arrow('copy-newer', t('today.newerDay'), '▶', i - 1),
            ],
          ),
          const SizedBox(height: 6),
          for (final m in moves.take(_names))
            Text('▪ ${(m.nick ?? exerciseLabel(m.id, m.name)).toUpperCase()}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11.5, p.ink)),
          if (moves.length > _names) Text(t('today.more', {'n': moves.length - _names}), style: mono(11, p.ink.withValues(alpha: 0.6))),
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

/// The card shown under the world: the move's name and the star, the
/// exercise picked (its database name and what it trains), today's set
/// marks for the move (in rarity colours), the XP so far, and the modifier
/// chips that pick the exercise (D55).
class _ExerciseText extends StatelessWidget {
  const _ExerciseText({
    required this.g,
    required this.full,
    required this.v,
    required this.sets,
    required this.xp,
    required this.favorite,
    this.hard = false,
    required this.onStar,
    required this.onPick,
  });

  /// The card with only its exercises that pass the filters.
  final ExerciseGroup g;

  /// The same move with all its exercises (for the greyed-out chips).
  final ExerciseGroup full;

  /// The exercise picked.
  final CatalogExercise v;
  final int sets, xp;
  final bool favorite;

  /// Above your mode (D70): a HARD badge by the title.
  final bool hard;
  final VoidCallback onStar;
  final ValueChanged<String> onPick;


  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SingleChildScrollView(
      // Only left / right moves the exercise carousel (D65): no vertical scroll.
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // The exercise picked is the title (D75).
                  child: Text((v.nick ?? exerciseLabel(v.id, v.name)).toUpperCase(), key: const ValueKey('exercise-title'), style: display(28, p.ink).copyWith(shadows: [
                    Shadow(offset: const Offset(2, 2), color: p.orange),
                  ])),
                ),
              ),
              if (hard)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 6),
                  child: Tag(t('workout.hard'), key: const ValueKey('hard-badge'), bg: p.pink, fg: p.on, size: 11, angle: -3),
                ),
              Semantics(
                button: true,
                selected: favorite,
                label: favorite ? t('workout.favRemove') : t('workout.favAdd'),
                child: GestureDetector(
                  key: const ValueKey('favorite-star'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onStar,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: PxIcon('star', size: 30, color: favorite ? p.orange : p.ink.withValues(alpha: 0.25)),
                  ),
                ),
              ),
            ],
          ),
          // No subtitle and no sets here (D74): the sets show in the world.
          // Modifiers: equipment first, then one row per way the exercises
          // with this equipment differ (D57).
          for (final (axis, values) in full.axesFor(v)) ...[
            const SizedBox(height: 10),
            Text(axisLabel(axis).toUpperCase(), style: mono(10.5, p.ink.withValues(alpha: 0.7))),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in values)
                  _ModChip(
                    key: ValueKey('mod-${axis.id}-${value ?? 'none'}'),
                    label: value == null ? axisNone(axis) : modLabel(value),
                    selected: v.mods[axis.id] == value,
                    target: v.mods[axis.id] == value ? null : chipTarget(g, v, axis.id, value),
                    onPick: onPick,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One modifier value on the card. Greyed out when no exercise of the move
/// has it (with this equipment, within the filters). A thin border means a
/// tap also changes another modifier (D57).
class _ModChip extends StatelessWidget {
  const _ModChip({super.key, required this.label, required this.selected, required this.target, required this.onPick});

  final String label;
  final bool selected;

  /// What a tap picks (null when selected or not available).
  final ({CatalogExercise v, bool exact})? target;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final off = !selected && target == null;
    final jump = target != null && !target!.exact;
    return Semantics(
      button: true,
      selected: selected,
      enabled: !off,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: target == null ? null : () => onPick(target!.v.id),
        child: Opacity(
          opacity: off ? 0.3 : jump ? 0.7 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? p.lime : p.panel,
              border: Border.all(color: p.ink, width: jump ? 1 : 2),
              boxShadow: selected ? [BoxShadow(color: p.ink, offset: const Offset(2, 2))] : null,
            ),
            child: Text(label.toUpperCase(), style: display(13, selected ? p.on : p.ink)),
          ),
        ),
      ),
    );
  }
}

/// Rarity-ladder colour for mark [k] (filled target slots, records).
Color rarity(Pal p, int k) => [p.lime, p.sky, p.violet, p.orange, p.pink][k % 5];

/// The marks an area leaves for each working set, grouped in fives so they
/// can be counted without numbers (shells, tally, crosses, tickets, flags).
class SetMarks extends StatelessWidget {
  const SetMarks({super.key, required this.style, required this.count, required this.color});

  final MarkStyle style;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return CustomPaint(
      size: Size(146, 22.0 * ((count + 9) ~/ 10).clamp(1, 6)),
      painter: _Marks(style, count, color, p.ink, [for (var k = 0; k < 5; k++) rarity(p, k)]),
    );
  }
}

class _Marks extends CustomPainter {
  _Marks(this.style, this.n, this.color, this.ink, this.ladder);

  final MarkStyle style;
  final int n;
  final Color color, ink;
  final List<Color> ladder;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    final fill = Paint()..color = color;
    final white = Paint()..color = Colors.white; // the fifth shell or ticket
    final outline = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const cell = 14.0, gap = 6.0, row = 22.0;
    for (var i = 0; i < n && i < 60; i++) {
      final group = i ~/ 5, k = i % 5;
      // Read left to right: two groups of five per row, then the next row.
      final x = (group % 2) * (5 * cell + gap) + k * cell;
      final y = (group ~/ 2) * row + 2;
      final fifth = k == 4;
      switch (style) {
        case MarkStyle.tally:
          if (fifth) {
            final x0 = x - 4 * cell;
            canvas.drawLine(Offset(x0, y + 15), Offset(x0 + 4 * cell, y + 3), stroke);
          } else {
            canvas.drawLine(Offset(x + 6, y + 2), Offset(x + 6, y + 16), stroke);
          }
        case MarkStyle.shells:
          final c = Offset(x + 7, y + 9);
          canvas.drawCircle(c, fifth ? 6 : 5, fifth ? white : fill);
          canvas.drawCircle(c, fifth ? 6 : 5, outline);
        case MarkStyle.crosses:
          final paint = Paint()
            ..color = ladder[group % ladder.length]
            ..strokeWidth = 3;
          canvas.drawLine(Offset(x + 2, y + 3), Offset(x + 12, y + 15), paint);
          canvas.drawLine(Offset(x + 12, y + 3), Offset(x + 2, y + 15), paint);
        case MarkStyle.tickets:
          final r = Rect.fromLTWH(x + 1, y + 4, 12, 9);
          canvas.drawRect(r, fifth ? white : fill);
          canvas.drawRect(r, outline);
        case MarkStyle.flags:
          final up = k * 2.0; // a step higher up the slope
          canvas.drawLine(Offset(x + 3, y + 17 - up), Offset(x + 3, y + 3 - up), outline..strokeWidth = 2);
          final path = Path()
            ..moveTo(x + 3, y + 3 - up)
            ..lineTo(x + 13, y + 7 - up)
            ..lineTo(x + 3, y + 11 - up)
            ..close();
          canvas.drawPath(path, Paint()..color = ladder[group % ladder.length]);
      }
    }
  }

  @override
  bool shouldRepaint(_Marks old) => old.n != n || old.style != style || old.color != color;
}

