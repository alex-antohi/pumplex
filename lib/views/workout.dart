// The workout (design demo screen 08), with the owner's
// rules (docs/decisions.md): one session per calendar day, so there is NO
// I WORKED button and NO clock (D6, D7).
//
// One card, like the starting-area card (D48):
// - The world on top: the area scene (design PNG layers,
//   lib/views/area_scene.dart) with the lifter in it. TAP THE OBJECT = one
//   working set for the exercise shown below, HOLD IT = take the last set
//   back (D17). The marks stay in the world.
// - Under the world: the exercise carousel, one exercise at a time (name,
//   target slots, set line, XP). Swipe it both ways, round and round; dots
//   show where you are. At the target it moves on to the next open
//   exercise. The list is the one the app picks for the day: no swap, skip,
//   remove or add (D32).

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/area_art.dart';
import '../game/content.dart';
import '../game/model.dart';
import '../pumplex.dart';
import '../store.dart';
import 'area_scene.dart';
import 'carousel.dart';

const _advanceDelay = Duration(milliseconds: 800);

/// The workout card in a view of [area]: the world on top, the exercise
/// carousel under it.
Rect workoutCard(Size area) => Rect.fromLTRB(16, 8, area.width - 22, area.height - 14);

/// The scene's rect and whole-number scale in a workout view of [area]: edge
/// to edge in the card; at most 24 px a side are cut off to reach the next
/// whole-number scale (crop the sides, never stretch).
(Rect, int) workoutLayout(Size area) {
  final card = workoutCard(area);
  // Inside the card's 4 px border.
  final avail = Rect.fromLTWH(card.left + 4, card.top + 4, card.width - 8, card.height * 0.6);
  final scale = max(1, min((avail.width + 48) / sceneSize.width, avail.height / sceneSize.height).floor());
  return (sceneRectIn(avail, scale), scale);
}

/// The lifter's place in the scene: the design's lifter position (the same
/// in every area), feet on the shadow.
Rect workoutStage(Size area) {
  final (scene, scale) = workoutLayout(area);
  return sceneLifterRect(areaArt.values.first, scene, scale);
}

class WorkoutView extends StatefulWidget {
  const WorkoutView({
    super.key,
    required this.stage,
    required this.store,
    required this.onAdd,
    required this.onRemove,
  });

  final Rect stage;
  final LogStore store;

  /// Index in `store.todayExercises` -> one set more / one set less.
  final ValueChanged<int> onAdd, onRemove;

  @override
  State<WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<WorkoutView> with SwipeCarousel<WorkoutView> {
  // The carousel runs over the day's cards (indexes in todayExercises).
  @override
  int get count => _store.todayCards.length;

  @override
  int get index => max(0, _store.todayCards.indexOf(active));

  @override
  void select(int i) => setState(() => _active = _store.todayCards[i]);

  int? _active;
  String? _burst;
  int _hitRun = 0;
  Timer? _advance;

  LogStore get _store => widget.store;

  /// The active card: the one picked, else the first open one below its target.
  int get active {
    final cards = _store.todayCards;
    if (cards.isEmpty) return -1;
    if (_active != null && cards.contains(_active)) return _active!;
    final list = _store.todayExercises;
    return cards.firstWhere((i) => list[i].sets < list[i].targetSets, orElse: () => cards.first);
  }

  /// The next card after [i] that is below its target.
  int? _nextOpen(int i) {
    final cards = _store.todayCards, list = _store.todayExercises;
    final at = cards.indexOf(i);
    for (var k = 1; k < cards.length; k++) {
      final j = cards[(at + k) % cards.length];
      if (list[j].sets < list[j].targetSets) return j;
    }
    return null;
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  void _hit() {
    final i = active;
    if (i < 0) return;
    widget.onAdd(i);
    final e = _store.todayExercises[i];
    final area = areaById(_store.todaySession?.areaId ?? _store.profile?.areaId);
    HapticFeedback.lightImpact();
    setState(() {
      _active = i;
      _burst = e.sets == e.targetSets ? 'CRUSHED!' : e.sets % 5 == 0 ? area.stamp : '+1 SET';
      _hitRun++;
    });
    if (e.sets == e.targetSets) {
      // Move on to the next open exercise.
      _advance?.cancel();
      _advance = Timer(_advanceDelay, () {
        if (!mounted) return;
        final next = _nextOpen(i);
        if (next != null) {
          setState(() {
            dir = 1;
            _active = next;
          });
        }
      });
    }
  }

  void _undo() {
    final i = active;
    if (i < 0) return;
    HapticFeedback.mediumImpact();
    widget.onRemove(i);
    setState(() => _burst = null); // undo has no effect animation
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final store = _store;
    final list = store.todayExercises;
    final cards = store.todayCards;
    final act = active;
    final today = store.todaySession;
    final area = areaById(today?.areaId ?? store.profile?.areaId);
    final art = areaArt[area.id]!;
    final accent = Color(area.accent);
    final e = act < 0 ? null : list[act];
    final firstTime = store.history.where((s) => !s.legacy).isEmpty;
    return LayoutBuilder(builder: (context, box) {
      final card = workoutCard(box.biggest);
      final (scene, scale) = workoutLayout(box.biggest);
      final skyLeft = max(scene.left, card.left + 4) + 8;
      return Stack(
        children: [
          Positioned.fromRect(
            rect: card,
            child: Brutal(
              shadow: accent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The world, edge to edge (the shell draws the lifter in it).
                  // TAP THE OBJECT = one working set, HOLD IT = take one back.
                  Container(
                    height: scene.height + 3,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.ink, width: 3))),
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minWidth: scene.width,
                        maxWidth: scene.width,
                        child: AreaScene(
                          art: art,
                          scale: scale,
                          count: e?.sets ?? 0,
                          hitRun: _hitRun,
                          burstText: _burst,
                          hitLabel: '${area.hint}: one working set. Hold to take one back.',
                          onHit: e == null ? null : _hit,
                          onUndo: e == null ? null : _undo,
                        ),
                      ),
                    ),
                  ),
                  // Under the world: the exercise carousel. The world adds
                  // sets to the exercise shown here.
                  Expanded(
                    child: cards.isEmpty
                        ? const SizedBox()
                        : swipe(
                            key: const ValueKey('exercise-card'),
                            child: Column(
                              children: [
                                Expanded(
                                  child: slide(
                                    'exercise-$act',
                                    _ExerciseText(
                                      e: e!,
                                      position: cards.indexOf(act),
                                      count: cards.length,
                                      xp: e.sets > 0 ? store.cardXp(act) : 0,
                                    ),
                                  ),
                                ),
                                CarouselDots(
                                  prefix: 'exercise',
                                  ids: [for (final i in cards) '$i'],
                                  names: [for (final i in cards) exerciseName(list[i].exerciseId)],
                                  current: '$act',
                                  colorOf: (_) => p.orange,
                                  onTap: jump,
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          // The hint over the sky (and the first-workout tip).
          if (e != null)
            Positioned(
              left: skyLeft,
              top: scene.top + 8,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tag(area.hint, bg: kNight, fg: accent, size: 13, angle: -2),
                    // First-workout tip (app-flow §4.2), until the first set.
                    if (firstTime && e.sets == 0) ...[
                      const SizedBox(height: 4),
                      Tag('Only working sets count', bg: p.lime, fg: p.on, size: 11, angle: 1),
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

/// The exercise shown under the world: its place in the day's list, the
/// name, the target slots (filled in rarity colours) with +extra, and the
/// set line with the XP so far.
class _ExerciseText extends StatelessWidget {
  const _ExerciseText({required this.e, required this.position, required this.count, required this.xp});

  final SessionExercise e;
  final int position, count, xp;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final done = e.sets >= e.targetSets;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Shout('Exercise ${position + 1} of $count', size: 12, color: p.pink),
              const Spacer(),
              Text(done ? 'CRUSHED' : 'NOW', style: mono(11, done ? p.lime : p.ink)),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(exerciseName(e.exerciseId).toUpperCase(), style: display(34, p.ink).copyWith(shadows: [
              Shadow(offset: const Offset(2, 2), color: p.orange),
            ])),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var k = 0; k < e.targetSets; k++)
                Text('X',
                    style: display(36, k < e.sets ? rarity(p, k) : p.ink.withValues(alpha: 0.35)).copyWith(
                      shadows: k < e.sets ? [Shadow(offset: const Offset(2, 2), color: p.ink)] : null,
                    )),
              if (e.sets > e.targetSets) Text('+${e.sets - e.targetSets}', style: display(30, p.ink)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${done ? '${e.sets}/${e.targetSets}' : 'SET ${e.sets + 1} OF ${e.targetSets}'}'
            '${xp > 0 ? ' · +$xp XP' : ''}',
            key: const ValueKey('workout-line'),
            style: mono(13, p.ink),
          ),
        ],
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

