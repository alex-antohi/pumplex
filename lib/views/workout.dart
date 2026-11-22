// The workout (design demo docs/demo/08-workout.html), with the owner's
// rules (docs/decisions.md): one session per calendar day, so there is NO
// I WORKED button and NO clock (D6, D7).
//
// Top to bottom:
// - Header: ◀ HUB, the class and the area name.
// - Exercise strip: one card per exercise with its target slots, then an
//   ADD card. Tap a card to make it the active exercise.
// - Tool row for the active exercise: SWAP (another exercise from the
//   class pool), FIRST (back to the first exercise), SKIP (do no sets, go
//   to the next one) and REMOVE (D15, D16).
// - The area scene (design PNG layers, lib/views/area_scene.dart): TAP THE
//   OBJECT = one working set, HOLD IT = take the last set back (D17). The
//   marks stay in the world; at the target the strip moves on.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/area_art.dart';
import '../game/content.dart';
import '../game/model.dart';
import '../pumplex.dart';
import '../store.dart';
import 'area_scene.dart';

const _advanceDelay = Duration(milliseconds: 800);

/// Top of the scene area in the workout view (header, strip, tools above).
const _sceneTop = 220.0;

/// The scene's rect and whole-number scale in a workout view of [area].
(Rect, int) workoutLayout(Size area) {
  final avail = Rect.fromLTRB(16, _sceneTop, area.width - 22, area.height - 16);
  final scale = sceneScale(avail.size);
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

class _WorkoutViewState extends State<WorkoutView> {
  int? _active;
  final Set<int> _skipped = {};
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
    return cards.firstWhere((i) => list[i].sets < list[i].targetSets && !_skipped.contains(i),
        orElse: () => cards.first);
  }

  /// The next card after [i] that is below its target and not skipped.
  int? _nextOpen(int i) {
    final cards = _store.todayCards, list = _store.todayExercises;
    final at = cards.indexOf(i);
    for (var k = 1; k < cards.length; k++) {
      final j = cards[(at + k) % cards.length];
      if (list[j].sets < list[j].targetSets && !_skipped.contains(j)) return j;
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
      _skipped.remove(i);
      _burst = e.sets == e.targetSets ? 'CRUSHED!' : e.sets % 5 == 0 ? area.stamp : '+1 SET';
      _hitRun++;
    });
    if (e.sets == e.targetSets) {
      // Move on to the next open exercise.
      _advance?.cancel();
      _advance = Timer(_advanceDelay, () {
        if (!mounted) return;
        final next = _nextOpen(i);
        if (next != null) setState(() => _active = next);
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

  void _skip(int i) => setState(() {
        _skipped.add(i);
        _active = _nextOpen(i) ?? i;
      });

  void _removeCard(int i) {
    final name = exerciseName(_store.todayExercises[i].exerciseId).toUpperCase();
    if (!_store.removeSlot(i)) return;
    setState(() => _active = null);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$name REMOVED'), duration: const Duration(seconds: 3)));
  }

  Future<void> _openAdd() async {
    final p = Pal.of(context);
    final unused = _store.unusedExercises;
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.panel,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Shout('Add an exercise · from your path', color: p.ink),
              const SizedBox(height: 12),
              if (unused.isEmpty)
                Text('Every exercise of your path is already in. Greedy. Respect.', style: mono(12, p.ink))
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final e in unused)
                          BrutalButton(
                            key: ValueKey('add-${e.id}'),
                            small: true,
                            color: p.panel2,
                            onTap: () => Navigator.pop(context, e.id),
                            child: Text(e.name.toUpperCase()),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              BrutalButton(color: p.panel2, onTap: () => Navigator.pop(context), child: const Text('CANCEL')),
            ],
          ),
        ),
      ),
    );
    if (id == null || !mounted) return;
    _store.addExercise(id);
    setState(() => _active = _store.todayExercises.length - 1);
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
    final art = areaArt[area.artId]!;
    final accent = Color(area.accent);
    final cls = classById(today?.classId ?? store.gameClass.id);
    final e = act < 0 ? null : list[act];
    // SKIP and REMOVE: only for an exercise with no sets, and never the last one.
    final canDrop = e != null && e.sets == 0 && cards.length >= 2;
    final firstTime = store.history.where((s) => !s.legacy).isEmpty;
    return LayoutBuilder(builder: (context, box) {
      final (scene, scale) = workoutLayout(box.biggest);
      return Stack(
        children: [
          // Header: ◀ HUB, class and area.
          Positioned(
            left: 16,
            right: 22,
            top: 6,
            child: Row(
              children: [
                BrutalButton(
                  key: const ValueKey('workout-hub'),
                  small: true,
                  color: p.sky,
                  onTap: widget.onBack,
                  child: const IconText('back', 'HUB'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cls.name.toUpperCase(), style: mono(11, p.ink)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(area.name.toUpperCase(), style: display(24, accent)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Exercise strip, then the ADD card.
          Positioned(
            left: 0,
            right: 0,
            top: 60,
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 22, 8),
              children: [
                for (final i in cards)
                  _StripCard(
                    key: ValueKey('strip-$i'),
                    e: list[i],
                    active: i == act,
                    skipped: _skipped.contains(i) && list[i].sets == 0,
                    onTap: () => setState(() => _active = i),
                  ),
                _AddCard(onTap: _openAdd),
              ],
            ),
          ),
          // Tools for the active exercise.
          if (e != null)
            Positioned(
              left: 16,
              right: 22,
              top: 166,
              height: 44,
              child: Row(
                children: [
                  _Tool(
                    key: const ValueKey('tool-swap'),
                    icon: 'swap',
                    label: 'SWAP',
                    onTap: () => widget.onSwap(act, 1),
                  ),
                  if (e.switched)
                    _Tool(
                      key: const ValueKey('tool-first'),
                      icon: 'undo',
                      label: 'FIRST',
                      onTap: e.sets > 0 ? null : () => store.resetSlot(act),
                    ),
                  _Tool(
                    key: const ValueKey('tool-skip'),
                    icon: 'skip',
                    label: 'SKIP',
                    onTap: canDrop ? () => _skip(act) : null,
                  ),
                  _Tool(
                    key: const ValueKey('tool-remove'),
                    icon: 'trash',
                    label: 'REMOVE',
                    onTap: canDrop ? () => _removeCard(act) : null,
                  ),
                ],
              ),
            ),
          // The scene: ink frame and a hard shadow in the area colour.
          sceneFrame(scene, ink: p.ink, shadow: accent),
          Positioned.fromRect(
            rect: scene,
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
          // The hint and the active exercise, over the sky.
          if (e != null)
            Positioned(
              left: scene.left + 8,
              right: box.maxWidth - scene.right + 8,
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
                    const SizedBox(height: 4),
                    Container(
                      color: kNight,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        '${exerciseName(e.exerciseId).toUpperCase()} · '
                        '${e.sets >= e.targetSets ? '${e.sets}/${e.targetSets}' : 'SET ${e.sets + 1} OF ${e.targetSets}'}'
                        '${e.sets > 0 ? ' · +${store.cardXp(act)} XP' : ''}',
                        key: const ValueKey('workout-line'),
                        style: mono(11, Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// The last card on the strip: opens the add sheet.
class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Semantics(
      button: true,
      label: 'Add an exercise',
      child: GestureDetector(
        key: const ValueKey('strip-add'),
        onTap: onTap,
        child: Container(
          width: 80,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: p.panel,
            border: Border.all(color: p.ink, width: 3),
            boxShadow: [BoxShadow(color: p.ink, offset: const Offset(4, 4))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PxIcon('plus', size: 24, color: p.lime),
              const SizedBox(height: 4),
              Text('ADD', style: display(16, p.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One button of the tool row (disabled when [onTap] is null).
class _Tool extends StatelessWidget {
  const _Tool({super.key, required this.icon, required this.label, required this.onTap});

  final String icon, label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Opacity(
              opacity: onTap == null ? 0.35 : 1,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.panel,
                  border: Border.all(color: p.ink, width: 3),
                  boxShadow: [BoxShadow(color: p.panel2, offset: const Offset(3, 3))],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PxIcon(icon, size: 14, color: p.ink),
                        const SizedBox(width: 4),
                        Text(label, style: display(13, p.ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A card on the exercise strip: name, target slots, +extra, status.
class _StripCard extends StatelessWidget {
  const _StripCard({super.key, required this.e, required this.active, required this.onTap, this.skipped = false});

  final SessionExercise e;
  final bool active, skipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final done = e.sets >= e.targetSets;
    final status = done ? 'CRUSHED' : active ? 'NOW' : skipped ? 'SKIPPED' : 'NEXT UP';
    final fg = active ? p.on : p.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 112,
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

