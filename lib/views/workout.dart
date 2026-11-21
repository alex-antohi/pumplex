// The workout (docs/moodboard/README.md "Workout screen" and "Starting
// areas"), with the owner's rules (docs/decisions.md): one session per
// calendar day, so there is NO I WORKED button and NO clock.
//
// - Exercise strip: one card per exercise with its target slots. Tap a
//   card to make it the active exercise.
// - The world: the area's scene with the lifter. TAP THE OBJECT = one
//   working set of the active exercise. HOLD THE OBJECT = take the last
//   set back. The scene shakes, a starburst says +1 SET (or CRUSHED! at the
//   target, or the area's stamp on every 5th set), and the marks stay in
//   the world. At the target, the strip moves on to the next exercise.
// - The active exercise card: swipe it to switch the exercise for another
//   one from the class pool, ↺ back to the first one, ✕ remove; + ADD
//   EXERCISE adds one. Skipping = doing no sets.
//
// The scenes and objects are placeholders (colours and emoji) until the
// design team's pixel art exists.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../store.dart';

/// Where the world scene sits in the workout view. The shell puts the
/// lifter inside it (see [workoutStage]).
Rect workoutSceneRect(Size area) => Rect.fromLTRB(16, 148, area.width - 22, 148 + area.height * 0.38);

/// The lifter's place in the scene: on the light floor, left side.
Rect workoutStage(Size area) {
  final s = workoutSceneRect(area);
  return Rect.fromLTWH(s.left + 6, s.top + s.height * 0.2, s.width * 0.36, s.height * 0.76);
}

const _shake = Duration(milliseconds: 320);
const _advanceDelay = Duration(milliseconds: 800);

class WorkoutView extends StatefulWidget {
  const WorkoutView({
    super.key,
    required this.stage,
    required this.store,
    required this.onAdd,
    required this.onRemove,
    required this.onSwap,
    required this.onBack,
  });

  final Rect stage;
  final LogStore store;

  /// Index in `store.todayExercises` -> one set more / one set less.
  final ValueChanged<int> onAdd, onRemove;

  /// Index, direction (+1 next, -1 previous).
  final void Function(int i, int dir) onSwap;
  final VoidCallback onBack;

  @override
  State<WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<WorkoutView> with SingleTickerProviderStateMixin {
  late final _shakeC = AnimationController(vsync: this, duration: _shake);
  int? _active;
  bool _adding = false;
  String? _burst;
  int _burstRun = 0;
  Timer? _advance;

  LogStore get _store => widget.store;

  /// The active card: the one picked, else the first one below its target.
  int get active {
    final cards = _store.todayCards;
    if (cards.isEmpty) return -1;
    if (_active != null && cards.contains(_active)) return _active!;
    final list = _store.todayExercises;
    return cards.firstWhere((i) => list[i].sets < list[i].targetSets, orElse: () => cards.first);
  }

  @override
  void dispose() {
    _advance?.cancel();
    _shakeC.dispose();
    super.dispose();
  }

  void _hit() {
    final i = active;
    if (i < 0) return;
    widget.onAdd(i);
    final e = _store.todayExercises[i];
    final area = areaById(_store.todaySession?.areaId ?? _store.profile?.areaId);
    HapticFeedback.lightImpact();
    if (!MediaQuery.disableAnimationsOf(context)) _shakeC.forward(from: 0);
    setState(() {
      _active = i;
      _burst = e.sets == e.targetSets ? 'CRUSHED!' : e.sets % 5 == 0 ? area.stamp : '+1 SET';
      _burstRun++;
    });
    if (e.sets == e.targetSets) {
      // Move on to the next exercise below its target.
      _advance?.cancel();
      _advance = Timer(_advanceDelay, () {
        if (!mounted) return;
        final list = _store.todayExercises;
        final next = _store.todayCards.where((k) => list[k].sets < list[k].targetSets);
        if (next.isNotEmpty) setState(() => _active = next.first);
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
    final diff = today == null ? store.difficulty : difficultyIndex(today.difficultyId);
    final unused = store.unusedExercises;
    final firstTime = store.history.where((s) => !s.legacy).isEmpty;
    return LayoutBuilder(builder: (context, box) {
      final scene = workoutSceneRect(box.biggest);
      return Stack(
        children: [
          // Header.
          Positioned(
            left: 16,
            right: 22,
            top: 6,
            child: Row(
              children: [
                BrutalButton(small: true, color: p.sky, onTap: widget.onBack, child: const Text('◀ HUB')),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text("TODAY'S WORKOUT · ${area.name.toUpperCase()}", style: display(18, p.ink)),
                  ),
                ),
              ],
            ),
          ),
          // Exercise strip.
          Positioned(
            left: 0,
            right: 0,
            top: 52,
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 22, 8),
              children: [
                for (final i in cards)
                  _StripCard(
                    key: ValueKey('strip-$i'),
                    e: list[i],
                    active: i == act,
                    onTap: () => setState(() => _active = i),
                  ),
              ],
            ),
          ),
          // The world.
          Positioned.fromRect(
            rect: scene,
            child: AnimatedBuilder(
              animation: _shakeC,
              builder: (context, child) {
                // Hard-stepped shake, no easing.
                final step = (_shakeC.value * 8).floor();
                final dx = _shakeC.isAnimating ? (step.isEven ? 4.0 : -4.0) : 0.0;
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: _World(
                area: area,
                exercise: act < 0 ? null : list[act],
                burst: _burst,
                burstRun: _burstRun,
                onHit: _hit,
                onUndo: _undo,
              ),
            ),
          ),
          // Active card, add, tips.
          Positioned(
            left: 0,
            right: 0,
            top: scene.bottom + 12,
            bottom: 0,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 24, 30 + MediaQuery.paddingOf(context).bottom),
              children: [
                if (act >= 0)
                  ExerciseCard(
                    key: ValueKey('card-$act'),
                    slot: list[act],
                    xp: store.cardXp(act),
                    color: Color(area.accent),
                    onSwap: (dir) => widget.onSwap(act, dir),
                    onReset: () => store.resetSlot(act),
                    onDelete: () {
                      if (store.removeSlot(act)) setState(() => _active = null);
                    },
                  ),
                const SizedBox(height: 14),
                if (unused.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BrutalButton(
                      small: true,
                      color: p.lime,
                      onTap: () => setState(() => _adding = !_adding),
                      child: Text(_adding ? '✕ CLOSE' : '+ ADD EXERCISE'),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: !_adding
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final e in unused)
                                  BrutalButton(
                                    key: ValueKey('add-${e.id}'),
                                    small: true,
                                    color: p.panel,
                                    onTap: () {
                                      store.addExercise(e.id);
                                      setState(() {
                                        _adding = false;
                                        _active = store.todayExercises.length - 1;
                                      });
                                    },
                                    child: Text('+ ${e.name.toUpperCase()}'),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
                Terminal([
                  if (firstTime) 'ONLY WORKING SETS COUNT. WARM-UPS DON\'T.',
                  '${area.hint}: +1 SET. HOLD IT: TAKE ONE BACK.',
                  'SKIP AN EXERCISE? JUST DO NO SETS.',
                  '+${(xpPerSet * rulesFor(diff).xpMultiplier).round()} XP PER SET. NO REPS. NO KILOS.',
                ]),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// A card on the exercise strip: name, target slots, +extra, status.
class _StripCard extends StatelessWidget {
  const _StripCard({super.key, required this.e, required this.active, required this.onTap});

  final SessionExercise e;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final done = e.sets >= e.targetSets;
    final status = active ? 'NOW' : done ? 'CRUSHED' : 'NEXT UP';
    final fg = active ? p.on : p.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 132,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: active ? p.orange : p.panel,
          border: Border.all(color: p.ink, width: 3),
          boxShadow: [BoxShadow(color: active ? p.pink : p.ink, offset: const Offset(4, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exerciseName(e.exerciseId).toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: display(14, fg)),
            const SizedBox(height: 4),
            Row(
              children: [
                for (var k = 0; k < e.targetSets; k++)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Text('X',
                        style: display(15, k < e.sets ? rarity(p, k) : fg.withValues(alpha: 0.35)).copyWith(
                          shadows: k < e.sets ? [Shadow(offset: const Offset(1, 1), color: p.ink)] : null,
                        )),
                  ),
                if (e.sets > e.targetSets) Text('+${e.sets - e.targetSets}', style: display(13, fg)),
              ],
            ),
            const Spacer(),
            Text(status, style: mono(10, fg)),
          ],
        ),
      ),
    );
  }
}

/// Rarity-ladder colour for mark [k] (filled target slots, records).
Color rarity(Pal p, int k) => [p.lime, p.sky, p.violet, p.orange, p.pink][k % 5];

/// The area's scene: dark sky, light floor, the object to hit, the hint,
/// the marks that stay, and the starburst.
class _World extends StatefulWidget {
  const _World({
    required this.area,
    required this.exercise,
    required this.burst,
    required this.burstRun,
    required this.onHit,
    required this.onUndo,
  });

  final Area area;
  final SessionExercise? exercise;
  final String? burst;
  final int burstRun;
  final VoidCallback onHit, onUndo;

  @override
  State<_World> createState() => _WorldState();
}

class _WorldState extends State<_World> with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final a = widget.area;
    final e = widget.exercise;
    final accent = Color(a.accent);
    final still = MediaQuery.disableAnimationsOf(context);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: p.ink, width: 4)),
      child: ClipRect(
        child: LayoutBuilder(builder: (context, box) {
          final floorTop = box.maxHeight * 0.55;
          final objectSize = min(box.maxWidth * 0.26, box.maxHeight * 0.34);
          final objectCenter = Offset(box.maxWidth * 0.7, floorTop + (box.maxHeight - floorTop) * 0.3);
          final hintTop = objectCenter.dy - objectSize - 50;
          final hintWidth = box.maxWidth * 0.56;
          final hintLeft = min(objectCenter.dx - hintWidth / 2, box.maxWidth - hintWidth - 10);
          return Stack(
            children: [
              Positioned.fill(child: Container(color: Color(a.sky))),
              Positioned(left: 0, right: 0, top: floorTop, bottom: 0, child: Container(color: Color(a.floor))),
              // Marks that stay in the world (the count), top right, above
              // the hint (they never run into it: the box clips).
              Positioned(
                right: 10,
                top: 8,
                width: box.maxWidth * 0.5,
                height: max(0, hintTop - 12),
                child: e == null
                    ? const SizedBox()
                    : ClipRect(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: SetMarks(style: a.marks, count: e.sets, color: accent, key: const ValueKey('marks')),
                        ),
                      ),
              ),
              // The hint, bobbing in hard steps.
              Positioned(
                left: hintLeft,
                width: hintWidth,
                top: hintTop,
                child: AnimatedBuilder(
                  animation: _bob,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, still ? 0 : (_bob.value * 3).floor() * -2.0),
                    child: child,
                  ),
                  child: Column(
                    children: [
                      Tag(a.hint, bg: kNight, fg: accent, size: 12, angle: -2),
                      if (e != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${exerciseName(e.exerciseId).toUpperCase()} · SET ${e.sets + 1} OF ${e.targetSets}',
                          style: mono(12, Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // The object: tap = one working set, hold = take one back.
              Positioned(
                left: objectCenter.dx - objectSize / 2 - 10,
                top: objectCenter.dy - objectSize / 2 - 10,
                width: objectSize + 20,
                height: objectSize + 20,
                child: Semantics(
                  button: true,
                  label: '${a.hint}: one working set. Hold to take one back.',
                  child: GestureDetector(
                    key: const ValueKey('world-object'),
                    behavior: HitTestBehavior.opaque,
                    onTap: e == null ? null : widget.onHit,
                    onLongPress: e == null ? null : widget.onUndo,
                    child: CustomPaint(
                      painter: _DashedRing(accent),
                      child: Center(child: Text(a.object, style: TextStyle(fontSize: objectSize * 0.7))),
                    ),
                  ),
                ),
              ),
              // Starburst: +1 SET, CRUSHED! or the 5th-set stamp.
              if (widget.burst != null)
                Positioned(
                  left: objectCenter.dx - 70,
                  top: objectCenter.dy - objectSize - 20,
                  child: IgnorePointer(
                    child: _Burst(key: ValueKey(widget.burstRun), text: widget.burst!, color: accent),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  _DashedRing(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final r = size.shortestSide / 2 - 3;
    final c = size.center(Offset.zero);
    const dashes = 16;
    for (var i = 0; i < dashes; i++) {
      final a0 = i * 2 * pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a0, pi / dashes, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}

/// A short starburst label that pops and fades (hard steps).
class _Burst extends StatefulWidget {
  const _Burst({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final step = (_c.value * 5).floor() / 5;
        return Opacity(
          opacity: _c.value < 0.7 ? 1 : (1 - (_c.value - 0.7) / 0.3).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.6 + 0.5 * min(1.0, step * 2),
            child: Starburst(
              size: 140,
              color: widget.color,
              seconds: 2,
              child: Text(widget.text, textAlign: TextAlign.center, style: display(18, kNight)),
            ),
          ),
        );
      },
    );
  }
}

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
          final paint = fifth ? (Paint()..color = Colors.white) : fill;
          canvas.drawCircle(c, fifth ? 6 : 5, paint);
          canvas.drawCircle(c, fifth ? 6 : 5, outline);
        case MarkStyle.crosses:
          final paint = Paint()
            ..color = ladder[group % ladder.length]
            ..strokeWidth = 3;
          canvas.drawLine(Offset(x + 2, y + 3), Offset(x + 12, y + 15), paint);
          canvas.drawLine(Offset(x + 12, y + 3), Offset(x + 2, y + 15), paint);
        case MarkStyle.tickets:
          final r = Rect.fromLTWH(x + 1, y + 4, 12, 9);
          canvas.drawRect(r, fifth ? (Paint()..color = Colors.white) : fill);
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

/// The active exercise: name, sets / target, XP. Swipe it to switch the
/// exercise for another one from the class pool; ↺ back to the first one;
/// ✕ removes it (both only with no sets).
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.slot,
    required this.xp,
    required this.color,
    required this.onSwap,
    required this.onReset,
    required this.onDelete,
  });

  final SessionExercise slot;

  /// XP this card brought today (criticals and streak bonus included).
  final int xp;
  final Color color;
  final VoidCallback onReset, onDelete;
  final ValueChanged<int> onSwap;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  double _dx = 0;
  bool _dragging = false;

  /// Direction of the last swap, for the slide-in.
  int _dir = 1;

  void _end(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final go = _dx.abs() > 90 || v.abs() > 700;
    final dir = (_dx != 0 ? _dx : v) < 0 ? 1 : -1; // swipe left = next exercise
    setState(() {
      _dragging = false;
      _dx = 0;
      if (go) _dir = dir;
    });
    if (go) widget.onSwap(dir);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final s = widget.slot;
    final count = s.sets;
    final name = exerciseName(s.exerciseId);
    return Semantics(
      label: '$name: $count of ${s.targetSets} working sets. Swipe to switch the exercise.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => setState(() => _dx += d.delta.dx),
        onHorizontalDragEnd: _end,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _dragging ? 0 : 220),
          curve: Curves.easeOutBack,
          transform: Matrix4.translationValues(_dx, 0, 0)..rotateZ(_dx / 2400),
          child: Brutal(
            shadow: widget.color,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        // The name slides in when the exercise is switched.
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (child, a) => ClipRect(
                            child: SlideTransition(
                              position: Tween(begin: Offset(_dir * 0.6, 0), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                              child: FadeTransition(opacity: a, child: child),
                            ),
                          ),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, if (current != null) current],
                          ),
                          child: Text(name.toUpperCase(), key: ValueKey(s.exerciseId), style: display(22, p.ink)),
                        ),
                      ),
                      if (count == 0 && s.switched)
                        _Mini(key: const ValueKey('reset'), label: '↺', color: p.sky, onTap: widget.onReset),
                      if (count == 0)
                        _Mini(key: const ValueKey('delete'), label: '✕', color: p.panel2, onTap: widget.onDelete),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, a) => ScaleTransition(
                          scale: Tween(begin: 1.8, end: 1.0)
                              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                          child: FadeTransition(opacity: a, child: child),
                        ),
                        child: Text('$count/${s.targetSets}',
                            key: ValueKey(count),
                            style: display(30, count >= s.targetSets && count > 0 ? p.pink : p.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          count > 0
                              ? 'WORKING SETS DONE'
                              : s.switched
                                  ? 'SWITCHED · ↺ = BACK TO ${exerciseName(s.originalExerciseId).toUpperCase()}'
                                  : '◀ SWIPE TO SWITCH THE EXERCISE ▶',
                          style: mono(11, p.ink),
                          maxLines: 2,
                        ),
                      ),
                      if (count > 0)
                        Tag(
                          '+${widget.xp} XP${count > s.targetSets * overTargetCap ? ' · MAX' : count > s.targetSets ? ' 🔥' : ''}',
                          bg: widget.color,
                          fg: p.on,
                          size: 13,
                          angle: 3,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small square button on an exercise card.
class _Mini extends StatelessWidget {
  const _Mini({super.key, required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, border: Border.all(color: p.ink, width: 3)),
          child: Text(label, style: display(18, p.on)),
        ),
      ),
    );
  }
}
