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
    required this.onGear,
  });

  final Rect stage;
  final LogStore store;
  final VoidCallback onTrain, onHistory, onGear;

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
        const SizedBox(height: 14),
        _StreakRow(week: store.thisWeek, streak: store.streakWeeks),
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
                  for (final s in store.todayExercises.where((e) => !e.removed))
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
        Positioned(
          right: 18,
          top: stage.top + 60,
          child: BrutalButton(small: true, color: p.lime, onTap: onGear, child: const Text('⚔ GEAR')),
        ),
        // What the character wears (icons until the gear sprites exist).
        Positioned(
          left: 14,
          top: stage.top + 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final id in store.gear.equipped.values)
                if (itemById(id) != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(itemById(id)!.icon, style: const TextStyle(fontSize: 22)),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// This week's training days against the target, and the streak.
class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.week, required this.streak});

  final ({int days, int n}) week;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      children: [
        for (var i = 0; i < week.n; i++)
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i < week.days ? p.orange : p.panel,
              border: Border.all(color: p.ink, width: 3),
            ),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'THIS WEEK ${week.days}/${week.n} DAYS'
            '${streak > 0 ? ' · 🔥 $streak WEEK${streak == 1 ? '' : 'S'}' : ''}',
            style: mono(11.5, p.ink),
          ),
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
    final diff = store.todaySession == null
        ? store.difficulty
        : difficultyIndex(store.todaySession!.difficultyId);
    final perSet = xpForExercise(1, 1, diff);
    final firstTime = store.history.where((s) => !s.legacy).isEmpty;
    final list = store.todayExercises;
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
              for (final i in store.todayCards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ExerciseCard(
                    key: ValueKey('card-$i'),
                    slot: list[i],
                    difficulty: diff,
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
    required this.difficulty,
    required this.color,
    required this.onAdd,
    required this.onRemove,
    required this.onSwap,
    required this.onReset,
    required this.onDelete,
  });

  final SessionExercise slot;

  /// Difficulty index of today's session (for the XP on the card).
  final int difficulty;
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
                        child: Text('$count/${s.targetSets}', key: ValueKey(count), style: display(32, count >= s.targetSets && count > 0 ? p.pink : p.ink)),
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
                              ? Text(s.switched ? 'SWITCHED · ↺ = BACK TO ${exerciseName(s.originalExerciseId).toUpperCase()}'
                                  : 'TAP WHEN A WORKING SET IS DONE', style: mono(11.5, p.ink), maxLines: 2)
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  child: TallyMarks(count: count),
                                ),
                        ),
                        if (count > 0) Tag('+${xpForExercise(count, s.targetSets, widget.difficulty)} XP${count > s.targetSets ? ' 🔥' : ''}', bg: widget.color, fg: p.on, size: 13, angle: 3),
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
    final all = store.history;
    final game = all.where((s) => !s.legacy).toList();
    final legacy = all.where((s) => s.legacy).toList();
    final today = store.todaySession;
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
                Text('${all.length} TRAINING DAYS IN THE BOOK', style: mono(11.5, p.pink)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 24, 30 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (all.isEmpty) const Terminal(['NOTHING HERE YET.', 'THE BOOK IS HUNGRY. FEED IT SETS.']),
              for (final s in game)
                _SessionTile(session: s, xp: store.xpOfSession(s), live: identical(s, today)),
              if (legacy.isNotEmpty) ...[
                const SizedBox(height: 8),
                Shout('Old saves · +$xpPerLegacySession XP each (beta)', color: p.violet),
                const SizedBox(height: 10),
                for (final s in legacy) _LegacyTile(session: s),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.xp, required this.live});

  final Session session;
  final int xp;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final took = session.duration;
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
                    (live ? 'TODAY · ' : '') + shortDate(parseDateKey(session.date)).toUpperCase(),
                    style: display(19, p.ink),
                  ),
                ),
                Tag('+$xp XP', bg: p.lime, fg: p.on, size: 13, angle: 2),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${session.totalSets} SETS${took == null ? '' : ' · ⏱ ${fmtDuration(took)}'} · '
              '${classById(session.classId).name.toUpperCase()} · ${areaById(session.areaId).name.toUpperCase()}',
              style: mono(11.5, p.ink),
            ),
            const SizedBox(height: 6),
            for (final e in session.exercises)
              if (e.sets > 0)
                Row(
                  children: [
                    Expanded(
                      child: Text('${exerciseName(e.exerciseId).toUpperCase()}  ${e.sets}/${e.targetSets}',
                          style: display(15, p.ink)),
                    ),
                    TallyMarks(count: e.sets, height: 14),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class _LegacyTile extends StatelessWidget {
  const _LegacyTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final took = session.duration == null ? '' : ' · ⏱ ${fmtDuration(session.duration!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text('💪', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${shortDate(parseDateKey(session.date)).toUpperCase()} · OLD WORKOUT$took',
              style: mono(12.5, p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- gear

/// One item per slot. The level unlocks items; the body never changes.
class GearView extends StatelessWidget {
  const GearView({super.key, required this.stage, required this.store, required this.onBack});

  final Rect stage;
  final LogStore store;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final level = levelFor(store.totalXp).level;
    final gear = store.gear;
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: stage.bottom + 4),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, stage.top + 4, stage.width + 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrutalButton(small: true, color: p.sky, onTap: onBack, child: const Text('◀ HUB')),
                const SizedBox(height: 10),
                Text('GEAR', style: display(26, p.ink)),
                const SizedBox(height: 4),
                Text('LEVELS UNLOCK GEAR. ONE ITEM PER SLOT.', style: mono(11.5, p.pink)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 24, 30 + MediaQuery.paddingOf(context).bottom),
            children: [
              for (final slot in GearSlot.values) ...[
                Shout(slot.name, color: p.violet, size: 14),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final it in items.where((i) => i.slot == slot))
                      _ItemChip(
                        item: it,
                        owned: gear.owned.contains(it.id),
                        equipped: gear.equipped[slot.name] == it.id,
                        onTap: () => store.equip(slot, gear.equipped[slot.name] == it.id ? null : it.id),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              Terminal([
                'YOU ARE LVL $level.',
                'THE GEAR ART COMES FROM THE DESIGN TEAM. FOR NOW: ICONS.',
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.item, required this.owned, required this.equipped, required this.onTap});

  final Item item;
  final bool owned, equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Opacity(
      opacity: owned ? 1 : 0.45,
      child: BrutalButton(
        key: ValueKey('item-${item.id}'),
        small: true,
        color: equipped ? p.lime : p.panel,
        onTap: owned ? onTap : null,
        child: Text(
          owned
              ? '${item.icon} ${item.name.toUpperCase()}${equipped ? ' ✔' : ''}'
              : '🔒 LVL ${item.unlockLevel} · ${item.name.toUpperCase()}',
        ),
      ),
    );
  }
}
