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
  });

  final Rect stage;
  final LogStore store;
  final VoidCallback onTrain, onHistory;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = store.gameClass;
    final d = difficulties[store.difficulty];
    final open = store.open;
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
                      if (open != null) Tag('ON · ${open.totalSets} SETS', bg: p.lime, fg: p.on, size: 13),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final e in cls.exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text('▸ ', style: display(18, color)),
                          Expanded(child: Text(e.name.toUpperCase(), style: display(18, p.ink))),
                          if (store.setsOf(e.id) > 0) TallyMarks(count: store.setsOf(e.id), height: 16),
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
                        open == null ? 'TRAIN ▶' : 'KEEP GOING ▶',
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
        Text(
          open == null
              ? 'NO CLOCK. NO PLAN. THE FIRST SET STARTS A SESSION.'
              : 'SESSION ON. IT CLOSES ${sessionTimeout.inHours} H AFTER YOUR LAST SET, OR TOMORROW.',
          style: mono(11.5, p.ink),
        ),
      ],
    );
    // The past-sessions button stays in the stage corner, beside the character.
    return Stack(
      children: [
        list,
        Positioned(
          left: 14,
          top: stage.top + 8,
          child: BrutalButton(small: true, color: p.sky, onTap: onHistory, child: const Text('◀ PAST')),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- workout

class WorkoutView extends StatelessWidget {
  const WorkoutView({
    super.key,
    required this.stage,
    required this.store,
    required this.onAdd,
    required this.onRemove,
    required this.onBack,
  });

  final Rect stage;
  final LogStore store;
  final ValueChanged<Exercise> onAdd, onRemove;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = store.gameClass;
    final perSet = xpForSets(1, store.difficulty);
    final firstTime = store.sessions.isEmpty;
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
                Text("TODAY'S WORKOUT", style: display(26, p.ink)),
                const SizedBox(height: 4),
                Text('TAP = +1 WORKING SET · HOLD = −1', style: mono(11.5, p.pink)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 24, 30 + MediaQuery.paddingOf(context).bottom),
            children: [
              for (final (i, e) in cls.exercises.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ExerciseCard(
                    exercise: e,
                    count: store.setsOf(e.id),
                    xpPerSet: perSet,
                    color: p.accents[i % p.accents.length],
                    onAdd: () => onAdd(e),
                    onRemove: () => onRemove(e),
                  ),
                ),
              Terminal([
                if (firstTime) 'WORKING SETS ONLY. WARM-UP SETS DO NOT COUNT.',
                'NO REPS. NO KILOS. NO SPREADSHEETS.',
                '+$perSet XP PER SET AT ${difficulties[store.difficulty].name.toUpperCase()}.',
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// One exercise: tap adds a working set, long-press takes one away.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.count,
    required this.xpPerSet,
    required this.color,
    required this.onAdd,
    required this.onRemove,
  });

  final Exercise exercise;
  final int count;
  final int xpPerSet;
  final Color color;
  final VoidCallback onAdd, onRemove;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Semantics(
      button: true,
      label: '${exercise.name}: $count working sets',
      child: GestureDetector(
        key: ValueKey('card-${exercise.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onAdd();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onRemove();
        },
        child: Brutal(
          shadow: color,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(exercise.name.toUpperCase(), style: display(24, p.ink))),
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
                            ? Text('TAP WHEN A WORKING SET IS DONE', style: mono(11.5, p.ink))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: TallyMarks(count: count),
                              ),
                      ),
                      if (count > 0) Tag('+${count * xpPerSet} XP', bg: color, fg: p.on, size: 13, angle: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final game = [if (store.open != null) store.open!, ...store.sessions.reversed];
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
              for (final s in game) _GameSessionTile(session: s, live: identical(s, store.open)),
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
