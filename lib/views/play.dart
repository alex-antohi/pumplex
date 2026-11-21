// Play: the hub, the workout (count working sets), and past sessions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dates.dart';
import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../store.dart';
import 'sprite.dart';

/// Level number and XP bar.
class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final l = levelFor(xp);
    return Row(
      children: [
        Tag('LVL ${l.level}', bg: p.pink, fg: p.on, size: 22, angle: -4),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 22,
                decoration: BoxDecoration(
                  color: kNight,
                  border: Border.all(color: p.ink, width: 3),
                  boxShadow: [BoxShadow(color: p.lime, offset: const Offset(4, 4))],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: l.into / l.need),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, f, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: f.clamp(0.0, 1.0),
                    child: Container(color: p.lime),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text('${l.into} / ${l.need} XP TO LVL ${l.level + 1}', style: mono(11.5, p.ink)),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- hub

class HubView extends StatelessWidget {
  const HubView({
    super.key,
    required this.stage,
    required this.store,
    required this.onTrain,
    required this.onHistory,
    required this.onBody,
  });

  final Rect stage;
  final LogStore store;
  final VoidCallback onTrain, onHistory;

  /// Opens the body sliders (tap on the character or ✎ BODY).
  final VoidCallback onBody;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = store.gameClass;
    final d = difficulties[store.difficulty];
    final today = store.todaySession;
    final color = classColor(p, cls.id);
    final list = ListView(
      padding: EdgeInsets.fromLTRB(16, stage.bottom + 10, 24, 30 + MediaQuery.paddingOf(context).bottom),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: kNight, border: Border.all(color: color, width: 2)),
            child: Text('${cls.name} · ${d.name}'.toUpperCase(), style: display(17, color)),
          ),
        ),
        const SizedBox(height: 16),
        LevelBar(xp: store.totalXp),
        const SizedBox(height: 22),
        // The workout card. Tapping it zooms the camera into the workout.
        GestureDetector(
          key: const ValueKey('hub-workout'),
          onTap: onTrain,
          child: Brutal(
            shadow: color,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text("TODAY'S WORKOUT", style: display(22, p.ink))),
                      if (today != null && today.totalSets > 0)
                        Tag('ON · ${today.totalSets} SETS', bg: p.lime, fg: p.on, size: 13),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final s in store.todaySlots)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text('▸ ', style: display(18, color)),
                          Expanded(child: Text(exerciseName(s.exerciseId).toUpperCase(), style: display(18, p.ink))),
                          if (s.sets > 0) TallyMarks(count: s.sets, height: 16),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Pulse(
                    amount: 0.03,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: p.pink, border: Border.all(color: p.ink, width: 4)),
                      child: Text(
                        today == null || today.totalSets == 0 ? 'TRAIN ▶' : 'KEEP GOING ▶',
                        textAlign: TextAlign.center,
                        style: display(28, p.on).copyWith(letterSpacing: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('NO CLOCK. NO PLAN. ONE SESSION PER DAY: EVERY SET TODAY COUNTS FOR TODAY.',
            style: mono(11.5, p.ink)),
      ],
    );
    return Stack(
      children: [
        list,
        // Tap the character to change the body sliders.
        Positioned.fromRect(
          rect: stage,
          child: GestureDetector(
            key: const ValueKey('hub-character'),
            behavior: HitTestBehavior.translucent,
            onTap: onBody,
          ),
        ),
        // Corner buttons beside the character.
        Positioned(
          left: 14,
          top: stage.top + 8,
          child: BrutalButton(small: true, color: p.sky, onTap: onHistory, child: const Text('◀ PAST')),
        ),
        Positioned(
          right: 18,
          top: stage.top + 8,
          child: BrutalButton(small: true, color: p.orange, onTap: onBody, child: const Text('✎ BODY')),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- workout

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

  /// Card index -> one set more / one set less.
  final ValueChanged<int> onAdd, onRemove;

  /// Card index, direction (+1 next, -1 previous).
  final void Function(int i, int dir) onSwap;
  final VoidCallback onBack;

  @override
  State<WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends State<WorkoutView> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final store = widget.store;
    final stage = widget.stage;
    final perSet = xpForSets(1, store.todaySession == null
        ? store.difficulty
        : difficultyIndex(store.todaySession!.difficultyId));
    final firstTime = store.sessions.isEmpty;
    final slots = store.todaySlots;
    final unused = store.unusedExercises;
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: stage.bottom + 4),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, stage.top + 4, stage.width + 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrutalButton(small: true, color: p.sky, onTap: widget.onBack, child: const Text('◀ HUB')),
                const SizedBox(height: 10),
                Text("TODAY'S WORKOUT", style: display(26, p.ink)),
                const SizedBox(height: 4),
                Text('TAP +1 SET · HOLD −1 · SWIPE = SWITCH', style: mono(11.5, p.pink)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 24, 30 + MediaQuery.paddingOf(context).bottom),
            children: [
              for (final (i, s) in slots.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ExerciseCard(
                    key: ValueKey('card-$i'),
                    slot: s,
                    xpPerSet: perSet,
                    color: p.accents[i % p.accents.length],
                    onAdd: () => widget.onAdd(i),
                    onRemove: () => widget.onRemove(i),
                    onSwap: (dir) => widget.onSwap(i, dir),
                    onReset: () => store.resetSlot(i),
                    onDelete: () => store.removeSlot(i),
                  ),
                ),
              // Add an exercise from the class pool.
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
                                    setState(() => _adding = false);
                                  },
                                  child: Text('+ ${e.name.toUpperCase()}'),
                                ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 18),
              ],
              Terminal([
                if (firstTime) 'WORKING SETS ONLY. WARM-UP SETS DO NOT COUNT.',
                'SKIP AN EXERCISE? JUST DO NO SETS.',
                '+$perSet XP PER SET. NO REPS. NO KILOS.',
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// One exercise: tap adds a working set, long-press takes one away, a
/// horizontal swipe switches it for another exercise from the class pool.
class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.slot,
    required this.xpPerSet,
    required this.color,
    required this.onAdd,
    required this.onRemove,
    required this.onSwap,
    required this.onReset,
    required this.onDelete,
  });

  final Slot slot;
  final int xpPerSet;
  final Color color;
  final VoidCallback onAdd, onRemove, onReset, onDelete;
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
      button: true,
      label: '$name: $count working sets',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onAdd();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onRemove();
        },
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                          child: Text(name.toUpperCase(), key: ValueKey(s.exerciseId), style: display(24, p.ink)),
                        ),
                      ),
                      if (count == 0 && s.switched)
                        _Mini(key: const ValueKey('reset'), label: '↺', color: p.sky, onTap: widget.onReset),
                      if (count == 0)
                        _Mini(key: const ValueKey('delete'), label: '✕', color: p.panel2, onTap: widget.onDelete),
                      // The count pops when it changes.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, a) => ScaleTransition(
                          scale: Tween(begin: 1.8, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                          child: FadeTransition(opacity: a, child: child),
                        ),
                        child: Text('$count', key: ValueKey(count), style: display(36, p.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        Expanded(
                          child: count == 0
                              ? Text(s.switched ? 'SWITCHED · ↺ = BACK TO ${exerciseName(s.initialId!).toUpperCase()}'
                                  : 'TAP WHEN A WORKING SET IS DONE', style: mono(11.5, p.ink), maxLines: 2)
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: TallyMarks(count: count),
                                ),
                        ),
                        if (count > 0) Tag('+${count * widget.xpPerSet} XP', bg: widget.color, fg: p.on, size: 13, angle: 3),
                      ],
                    ),
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

// ----------------------------------------------------------------- history

class HistoryView extends StatelessWidget {
  const HistoryView({super.key, required this.stage, required this.store, required this.onBack});

  final Rect stage;
  final LogStore store;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final today = store.todaySession;
    final game = [if (today != null && today.totalSets > 0) today, ...store.sessions.reversed];
    final old = store.oldSessions.reversed.toList();
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: stage.bottom + 4),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, stage.top + 4, stage.width + 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrutalButton(small: true, color: p.sky, onTap: onBack, child: const Text('HUB ▶')),
                const SizedBox(height: 10),
                Text('PAST SESSIONS', style: display(26, p.ink)),
                const SizedBox(height: 4),
                Text('${game.length + old.length} IN THE BOOK', style: mono(11.5, p.pink)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 24, 30 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (game.isEmpty && old.isEmpty)
                const Terminal(['NOTHING HERE YET.', 'THE BOOK IS HUNGRY. FEED IT SETS.']),
              for (final s in game) _GameSessionTile(session: s, live: identical(s, today)),
              if (old.isNotEmpty) ...[
                const SizedBox(height: 8),
                Shout('Old saves · +$xpPerOldWorkout XP each (beta)', color: p.violet),
                const SizedBox(height: 10),
                for (final s in old) _OldSessionTile(session: s),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GameSessionTile extends StatelessWidget {
  const _GameSessionTile({required this.session, required this.live});

  final GameSession session;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final names = {for (final c in gameClasses) for (final e in c.exercises) e.id: e.name};
    return Brutal(
      margin: const EdgeInsets.only(bottom: 16),
      shadow: live ? p.lime : p.violet,
      offset: 5,
      border: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (live ? 'NOW · ' : '') + shortDate(session.start).toUpperCase(),
                    style: display(19, p.ink),
                  ),
                ),
                Tag('+${LogStore.xpOf(session)} XP', bg: p.lime, fg: p.on, size: 13, angle: 2),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${session.totalSets} SETS · ⏱ ${fmtDuration(session.duration)} · ${classById(session.classId).name.toUpperCase()}',
              style: mono(11.5, p.ink),
            ),
            const SizedBox(height: 6),
            for (final e in session.sets.entries)
              Row(
                children: [
                  Expanded(child: Text((names[e.key] ?? e.key).toUpperCase(), style: display(15, p.ink))),
                  TallyMarks(count: e.value, height: 14),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OldSessionTile extends StatelessWidget {
  const _OldSessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final took = session.duration == null ? '' : ' · ⏱ ${fmtDuration(session.duration!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(session.rested ? '😴' : '💪', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${shortDate(parseDateKey(session.date)).toUpperCase()} · ${session.rested ? 'RESTED' : 'WORKED'}$took',
              style: mono(12.5, p.ink),
            ),
          ),
        ],
      ),
    );
  }
}
