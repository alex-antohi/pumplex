import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dates.dart';
import 'movements.dart';
import 'program.dart';
import 'pumplex.dart';
import 'stats.dart';
import 'store.dart';

double roundToPlate(double kg) => (kg / 2.5).round() * 2.5;

/// Heavier, or same weight for more reps.
bool beats(SetEntry now, SetEntry? before) {
  if (before == null || now.isEmpty) return false;
  final a = now.kg ?? 0, b = before.kg ?? 0;
  if (a != b) return a > b;
  return (now.reps ?? 0) > (before.reps ?? 0);
}

// Room at the bottom for the floating "↩ NOW" button.
const _listPadding = EdgeInsets.fromLTRB(16, 22, 24, 100);

/// One page per session. The current one ends with I WORKED / I RESTED.
class DayPage extends StatelessWidget {
  const DayPage({
    super.key,
    required this.n,
    required this.store,
    required this.onComplete,
  });

  /// Session number, 1-based.
  final int n;
  final LogStore store;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final key = sessionKey(n);
        final day = store.dayOf(n);
        final workout = program[day];
        // Upcoming sessions can be looked at, not logged.
        final preview = n > store.currentN;
        final footer = n == store.currentN
            ? _DoneButton(rest: workout == null, onTap: onComplete)
            : store.isDone(n)
                ? _DoneStamp(session: store.sessions[n - 1])
                : _PreviewStamp(current: store.currentN);

        if (workout == null) {
          return ListView(
            padding: _listPadding,
            children: [
              Shout('Session $n · Day $day of 7${preview ? ' · preview' : ''}'),
              const SizedBox(height: 8),
              const MegaText('Rest day', size: 66),
              const SizedBox(height: 14),
              Tag(restTag(n)),
              const SizedBox(height: 30),
              StatsPanel(store: store),
              const SizedBox(height: 30),
              footer,
            ],
          );
        }

        var done = 0, total = 0, due = 0;
        for (final ex in workout.exercises) {
          final log = store.get(key, ex.id);
          total += max(Scheme.parse(ex.scheme).sets, log?.sets.length ?? 0);
          done += log?.sets.where((s) => s.done && !s.isEmpty).length ?? 0;
          if (reminderFor(store, ex, key, movementOn(store, workout, ex, key))?.due ?? false) due++;
        }

        // Session clock: START TRAINING now, the time it took afterwards.
        final Widget? clock;
        if (n == store.currentN) {
          final started = store.startedAt;
          clock = started == null
              ? _StartButton(onTap: store.startTraining)
              : _TrainingClock(started: started);
        } else if (store.isDone(n) && store.sessions[n - 1].duration != null) {
          clock = Tag('⏱ TOOK ${fmtDuration(store.sessions[n - 1].duration!)}', size: 20);
        } else {
          clock = null;
        }

        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: _listPadding,
          children: [
            _DayHeader(
              n: n,
              day: day,
              workout: workout,
              done: done,
              total: total,
              due: due,
              preview: preview,
              clock: clock,
            ),
            const SizedBox(height: 28),
            for (final (i, ex) in workout.exercises.indexed)
              IgnorePointer(
                ignoring: preview,
                child: Opacity(
                  opacity: preview ? 0.6 : 1,
                  child: ExerciseCard(
                    key: ValueKey(ex.id),
                    index: i,
                    n: n,
                    workout: workout,
                    exercise: ex,
                    store: store,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            footer,
          ],
        );
      },
    );
  }
}

/// The one button that moves the program forward.
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.rest, required this.onTap});

  final bool rest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox(
      width: double.infinity,
      child: BrutalButton(
        color: rest ? p.sky : p.pink,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            rest ? 'I RESTED 😴' : 'I WORKED 💪',
            textAlign: TextAlign.center,
            style: display(34, p.on).copyWith(letterSpacing: 1.5),
          ),
        ),
      ),
    );
  }
}

/// START TRAINING: starts the session clock.
class _StartButton extends StatelessWidget {
  const _StartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox(
      width: double.infinity,
      child: BrutalButton(
        color: p.lime,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'START TRAINING ▶',
            textAlign: TextAlign.center,
            style: display(28, p.on).copyWith(letterSpacing: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Running session clock (ticks every second).
class _TrainingClock extends StatefulWidget {
  const _TrainingClock({required this.started});

  final DateTime started;

  @override
  State<_TrainingClock> createState() => _TrainingClockState();
}

class _TrainingClockState extends State<_TrainingClock> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick; // start ticking
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final elapsed = DateTime.now().difference(widget.started);
    return Brutal(
      color: kNight,
      shadow: p.lime,
      offset: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(child: Shout('Training for', color: p.lime)),
            Text('⏱ ${fmtDuration(elapsed.isNegative ? Duration.zero : elapsed)}',
                style: display(34, p.lime)),
          ],
        ),
      ),
    );
  }
}

/// Footer of an upcoming session.
class _PreviewStamp extends StatelessWidget {
  const _PreviewStamp({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Center(
      child: Tag(
        'PREVIEW · FINISH SESSION $current FIRST',
        bg: p.sky,
        fg: p.on,
        angle: 2,
        size: 20,
      ),
    );
  }
}

/// Footer of a session that is already done.
class _DoneStamp extends StatelessWidget {
  const _DoneStamp({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final when = shortDate(parseDateKey(session.date)).toUpperCase();
    final took = session.duration == null ? '' : ' · ⏱ ${fmtDuration(session.duration!)}';
    return Center(
      child: Tag(
        session.rested ? '✔ RESTED · $when' : '✔ WORKED · $when$took',
        bg: p.lime,
        fg: p.on,
        angle: -3,
        size: 24,
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.n,
    required this.day,
    required this.workout,
    required this.done,
    required this.total,
    required this.due,
    this.preview = false,
    this.clock,
  });

  final int n;
  final int day;
  final Workout workout;
  final int done;
  final int total;

  /// Movements that are due a swap in this session.
  final int due;

  /// An upcoming session, shown read-only.
  final bool preview;

  /// START TRAINING / running clock / how long it took.
  final Widget? clock;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shout('Session $n · Day $day of 7 · ${workout.exercises.length} exercises'),
        const SizedBox(height: 8),
        MegaText(workout.title, size: 58),
        const SizedBox(height: 14),
        preview ? Tag('PREVIEW · COMING UP', bg: p.sky, fg: p.on) : Tag(dayTag(n)),
        if (due > 0) ...[
          const SizedBox(height: 14),
          Pulse(
            child: Tag(
              '⚠ $due SWAP${due == 1 ? '' : 'S'} DUE',
              bg: p.orange,
              fg: p.on,
              angle: 1.5,
            ),
          ),
        ],
        if (clock != null) ...[
          const SizedBox(height: 22),
          clock!,
        ],
        const SizedBox(height: 26),
        Brutal(
          shadow: p.violet,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('THE PUMP-O-METER™', style: display(21, p.ink))),
                    Text('$done/$total SETS', style: mono(13, p.ink)),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: PumpOMeter(value: total == 0 ? 0 : done / total),
                  ),
                ),
                const SizedBox(height: 12),
                Terminal([pumpReading(done, total)]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.index,
    required this.n,
    required this.workout,
    required this.exercise,
    required this.store,
  });

  final int index;

  /// Session number.
  final int n;
  final Workout workout;
  final Exercise exercise;
  final LogStore store;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final key = sessionKey(n);
    final scheme = Scheme.parse(exercise.scheme);
    final movement = movementOn(store, workout, exercise, key);
    final title = movement.name;
    final placeholder = movement.placeholder;
    final log = store.get(key, exercise.id);
    // History follows the movement, not just the slot.
    final last = store.lastBefore(key, exercise.id, name: title);
    final lastSets = last?.log.filledSets ?? const <SetEntry>[];
    final best = store.bestBefore(key, exercise.id, name: title);
    final reminder = reminderFor(store, exercise, key, movement);
    final rows = max(scheme.sets, log?.sets.length ?? 0);
    // PRs and "CRUSHED" count ticked sets only.
    double? tickedTop(ExerciseLog? l) {
      double? top;
      for (final s in l?.sets ?? const <SetEntry>[]) {
        if (s.done && s.kg != null && (top == null || s.kg! > top)) top = s.kg;
      }
      return top;
    }

    final top = tickedTop(log);
    final isPr = best != null && top != null && top > best;
    final ticked = log?.sets.where((s) => s.done && !s.isEmpty).length ?? 0;
    final complete = ticked > 0 && ticked >= scheme.sets;

    // Rep-outs: the first time, 75% of what it follows (today's max, or for
    // the second rep-out the first rep-out: -25% on top of -25%). After
    // that, the same weight as the last rep-out of this movement, and the
    // job is to beat its reps. A new movement name starts over.
    final isRepOut = scheme.percent != null;
    final ref = exercise.percentOf == null ? null : workout.byId(exercise.percentOf!);
    final followsRepOut = ref != null && Scheme.parse(ref.scheme).percent != null;
    SetEntry? repOutPrev;
    double? targetKg;
    String? targetText;
    if (isRepOut) {
      final pct = (scheme.percent! * 100).round();
      final source = followsRepOut ? 'REP-OUT ABOVE' : 'MAX ABOVE';
      final prevSets = store.lastBefore(key, exercise.id, name: title)?.log.filledSets;
      if (prevSets != null && prevSets.isNotEmpty && prevSets.first.kg != null) {
        repOutPrev = prevSets.first;
        targetKg = repOutPrev.kg;
        targetText = 'SAME WEIGHT: ${fmtKg(targetKg!)} KG'
            '${repOutPrev.reps != null ? ' · BEAT ${repOutPrev.reps} REPS' : ''}';
      } else {
        final refTop =
            exercise.percentOf == null ? null : store.get(key, exercise.percentOf!)?.topKg;
        if (refTop != null) {
          targetKg = roundToPlate(refTop * scheme.percent!);
          targetText = 'FIRST TIME: ${fmtKg(targetKg)} KG ($pct% OF ${fmtKg(refTop)}) · MAX REPS';
        } else {
          targetText = 'FIRST TIME: LOG THE $source TO GET YOUR $pct%';
        }
      }
    }

    // What each set row is compared against / pre-filled from.
    final compareSets = isRepOut
        ? (repOutPrev == null ? const <SetEntry>[] : [repOutPrev])
        : lastSets;

    // All sets use the same weight: once a weight is typed today, the sets
    // below it offer that weight (greyed out, copied in by ✔).
    double? weightAbove(int i) {
      for (var j = min(i, log?.sets.length ?? 0) - 1; j >= 0; j--) {
        final kg = log!.sets[j].kg;
        if (kg != null) return kg;
      }
      return null;
    }

    void update(int i, double? kg, int? reps) {
      final l = store.edit(key, exercise.id, title);
      while (l.sets.length <= i) {
        l.sets.add(SetEntry());
      }
      final s = l.sets[i]
        ..kg = kg
        ..reps = reps;
      if (s.isEmpty) s.done = false; // cleared out: no longer ticked
      store.changed();
    }

    void addSet() {
      final l = store.edit(key, exercise.id, title);
      while (l.sets.length < rows) {
        l.sets.add(SetEntry());
      }
      l.sets.add(SetEntry());
      store.changed();
    }

    void removeSet() {
      final l = store.edit(key, exercise.id, title);
      if (l.sets.isNotEmpty) l.sets.removeLast();
      store.changed();
    }

    // Called when a set row loses focus or gets ticked.
    void commit() {
      if (!context.mounted) return;
      final l = store.get(key, exercise.id);
      final t = tickedTop(l);
      final b = store.bestBefore(key, exercise.id, name: title);
      if (t != null && b != null && t > b) {
        celebratePr(
          context,
          id: '$key/${exercise.id}/kg$t',
          exercise: title,
          big: '${fmtKg(t)} KG',
          sub: '+${fmtKg(t - b)} KG OVER YOUR BEST.\nTHE BAR IS SCARED.',
        );
        return;
      }
      final prev = repOutPrev;
      final s = (l == null || l.sets.isEmpty || !l.sets.first.done) ? null : l.sets.first;
      if (prev != null && s?.reps != null && s!.kg == prev.kg && s.reps! > (prev.reps ?? 0)) {
        celebratePr(
          context,
          id: '$key/${exercise.id}/reps${s.reps}',
          exercise: title,
          title: 'REP\nPR!!!',
          big: '${s.reps} REPS',
          sub: '+${s.reps! - (prev.reps ?? 0)} REPS AT ${fmtKg(prev.kg!)} KG.\nTHE BAR IS SCARED.',
        );
      }
    }

    // ✔ / un-✔ on set i. Ticking checks for a PR.
    void setDone(int i, bool done) {
      final l = store.edit(key, exercise.id, title);
      while (l.sets.length <= i) {
        l.sets.add(SetEntry());
      }
      l.sets[i].done = done;
      store.changed();
      if (done) commit();
    }

    Future<void> swap() async {
      final used = store.namesUsed(exercise.id);
      if (exercise.name.isNotEmpty && !used.contains(exercise.name)) used.add(exercise.name);
      final name = await showDialog<String>(
        context: context,
        builder: (_) => SwapDialog(
          current: title,
          slot: exercise.hint,
          used: used.where((n) => n != title).toList(),
        ),
      );
      if (name == null || name.isEmpty || name == title) return;
      store.setSwap(exercise.id, key, name);
      // Whatever was already logged today in this slot (and rep-outs that
      // follow it) was this movement.
      bool follows(Exercise e) {
        for (Exercise? cur = e; cur != null; cur = cur.percentOf == null ? null : workout.byId(cur.percentOf!)) {
          if (cur.id == exercise.id) return true;
        }
        return false;
      }

      for (final e in workout.exercises) {
        if (follows(e)) store.get(key, e.id)?.name = name;
      }
      store.changed();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SWAPPED TO ${name.toUpperCase()}. FRESH GAINS UNLOCKED.')),
        );
      }
    }

    final List<String> lastLines;
    if (last == null) {
      lastLines = ['NO HISTORY FOR ${title.toUpperCase()}. BLANK SLATE.', 'WHATEVER YOU LIFT IS A RECORD.'];
    } else {
      final lastN = sessionNumber(last.key);
      final when = shortDate(store.dateOf(lastN)).toUpperCase();
      lastLines = [
        // One program week = 7 sessions.
        '${n - lastN == 7 ? 'LAST WEEK' : 'LAST TIME'} · $when:',
        lastSets.map(fmtSet).join('  '),
        if (best != null) 'ALL-TIME BEST: ${fmtKg(best)} KG',
      ];
    }

    final muted = mono(11.5, p.ink.withValues(alpha: 0.6));

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Brutal(
        angle: index.isEven ? -0.6 : 0.6,
        shadow: isPr ? p.pink : p.accents[index % p.accents.length],
        offset: isPr ? 13 : 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: display(27, placeholder ? p.ink.withValues(alpha: 0.55) : p.ink)
                              .copyWith(
                            fontStyle: placeholder ? FontStyle.italic : null,
                            shadows: placeholder
                                ? null
                                : [
                                    Shadow(offset: const Offset(1.5, 1.5), color: p.lime),
                                    Shadow(offset: const Offset(3, 3), color: p.pink),
                                  ],
                          ),
                        ),
                        if (placeholder)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text('(PICK YOUR POISON)', style: muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Starburst(
                    size: 74,
                    color: index.isEven ? p.lime : p.orange,
                    seconds: 8 + index % 4,
                    child: Text(
                      scheme.badge,
                      textAlign: TextAlign.center,
                      style: display(scheme.badge.length > 4 ? 14 : 19, p.on),
                    ),
                  ),
                ],
              ),
              if (reminder != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _ReminderBox(
                    reminder: reminder,
                    onSwap: swap,
                    // Hidden until this workout comes round again.
                    onSnooze: () => store.snooze(exercise.id, sessionKey(n + 6)),
                  ),
                ),
              if (isPr || complete)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (isPr) Pulse(child: Tag('🔥 NEW PR 🔥', bg: p.pink, fg: p.on)),
                      if (complete) Tag('CRUSHED ✔', bg: p.lime, fg: p.on, angle: 2),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                [
                  followsRepOut
                      ? '1 set, max reps. First time: ${(scheme.percent! * 100).round()}% of the '
                          'rep-out above. After that: same weight, beat the reps'
                      : scheme.description,
                  if (exercise.hint.isNotEmpty && exercise.hint != title) exercise.hint,
                ].join(' · ').toUpperCase(),
                style: mono(12.5, p.ink),
              ),
              if (exercise.note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(exercise.note!, style: muted),
                ),
              if (targetText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Tag(
                    targetText,
                    bg: p.sky,
                    fg: p.on,
                    angle: -1,
                    size: 15,
                  ),
                ),
              const SizedBox(height: 12),
              Terminal(lastLines),
              const SizedBox(height: 14),
              Row(
                children: [
                  const SizedBox(width: 32, child: Shout('Set', size: 11)),
                  const Expanded(child: Center(child: Shout('kg', size: 11))),
                  const SizedBox(width: 24),
                  const Expanded(child: Center(child: Shout('reps', size: 11))),
                  const SizedBox(width: 58),
                ],
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < rows; i++)
                SetRow(
                  key: ValueKey(i),
                  index: i,
                  entry: (log != null && i < log.sets.length) ? log.sets[i] : null,
                  hintKg: targetKg ??
                      weightAbove(i) ??
                      (i < compareSets.length ? compareSets[i].kg : null),
                  hintReps: i < compareSets.length ? compareSets[i].reps : scheme.reps,
                  repsHint: scheme.repsHint,
                  // Rep-outs: the tick sets the weight only; the reps are the fight.
                  fillReps: !isRepOut,
                  beat: log != null &&
                      i < log.sets.length &&
                      log.sets[i].done &&
                      beats(log.sets[i], i < compareSets.length ? compareSets[i] : null),
                  onChanged: (kg, reps) => update(i, kg, reps),
                  onCommit: commit,
                  onDone: (done) => setDone(i, done),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canSwap(exercise))
                    BrutalButton(small: true, color: p.sky, onTap: swap, child: const Text('⇄ SWAP')),
                  const Spacer(),
                  if (rows > scheme.sets) ...[
                    BrutalButton(color: p.pink, onTap: removeSet, child: const Text('− SET')),
                    const SizedBox(width: 14),
                  ],
                  BrutalButton(color: p.lime, onTap: addSet, child: const Text('+ SET')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.index,
    required this.entry,
    required this.hintKg,
    required this.hintReps,
    required this.repsHint,
    required this.beat,
    required this.onChanged,
    required this.onCommit,
    required this.onDone,
    this.fillReps = true,
  });

  final int index;
  final SetEntry? entry;

  /// Last week's (or the target) values: shown greyed out, copied in by the tick.
  final double? hintKg;
  final int? hintReps;
  final String repsHint;

  /// Whether the tick also copies the reps (not for rep-outs).
  final bool fillReps;

  /// This set beats the same set last time.
  final bool beat;
  final void Function(double? kg, int? reps) onChanged;
  final VoidCallback onCommit;

  /// ✔ tapped: true = set done (starts the rest timer), false = un-ticked.
  final void Function(bool done) onDone;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final _kg = TextEditingController(
    text: widget.entry?.kg == null ? '' : fmtKg(widget.entry!.kg!),
  );
  late final _reps = TextEditingController(text: widget.entry?.reps?.toString() ?? '');

  /// Which field ✔ found empty ('kg' / 'reps'), flashed for a moment.
  String? _missing;
  Timer? _nagTimer;

  @override
  void dispose() {
    _nagTimer?.cancel();
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(
        double.tryParse(_kg.text.replaceAll(',', '.')),
        int.tryParse(_reps.text),
      );

  /// ✔: needs a weight and reps. Blank fields take the greyed-out numbers;
  /// if something is still missing, flash that field instead of ticking
  /// (0 kg works for bodyweight). On a ticked set, ✔ un-ticks it.
  void _check() {
    if (widget.entry?.done ?? false) {
      widget.onDone(false);
      return;
    }
    final typedKg = double.tryParse(_kg.text.replaceAll(',', '.'));
    final typedReps = int.tryParse(_reps.text);
    final kg = typedKg ?? widget.hintKg;
    final reps = typedReps ?? (widget.fillReps ? widget.hintReps : null);
    if (kg == null || reps == null) {
      HapticFeedback.vibrate();
      setState(() => _missing = kg == null ? 'kg' : 'reps');
      _nagTimer?.cancel();
      _nagTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _missing = null);
      });
      return;
    }
    _nagTimer?.cancel();
    _missing = null;
    if (typedKg == null) _kg.text = fmtKg(kg);
    if (typedReps == null) _reps.text = '$reps';
    _emit();
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onDone(true);
  }

  Widget _field(
    Pal p, {
    required TextEditingController controller,
    required String hint,
    required bool decimal,
    bool nag = false,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c, width: w),
        );
    if (nag) hint = decimal ? 'KG?' : 'REPS?';
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      style: display(23, p.ink),
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      textInputAction: decimal ? TextInputAction.next : TextInputAction.done,
      onChanged: (_) => _emit(),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: nag ? p.orange.withValues(alpha: 0.25) : p.panel2,
        hintText: hint,
        hintStyle: display(nag ? 19 : 23, nag ? p.orange : p.ink.withValues(alpha: 0.28)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        enabledBorder: border(nag ? p.orange : p.ink, nag ? 4 : 3),
        focusedBorder: border(p.pink, 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final done = widget.entry?.done ?? false;
    return Focus(
      skipTraversal: true,
      onFocusChange: (has) {
        if (!has) widget.onCommit();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text('${widget.index + 1}', style: display(26, p.pink)),
            ),
            Expanded(
              child: _field(
                p,
                controller: _kg,
                hint: widget.hintKg == null ? '' : fmtKg(widget.hintKg!),
                decimal: true,
                nag: _missing == 'kg',
              ),
            ),
            SizedBox(width: 24, child: Center(child: Text('×', style: display(22, p.ink)))),
            Expanded(
              child: _field(
                p,
                controller: _reps,
                hint: widget.hintReps?.toString() ?? widget.repsHint,
                decimal: false,
                nag: _missing == 'reps',
              ),
            ),
            const SizedBox(width: 10),
            _Tick(done: done, beat: widget.beat, onTap: _check),
          ],
        ),
      ),
    );
  }
}

/// Orange "SWAP TIME" (or sky-blue heads-up) box on a card.
class _ReminderBox extends StatelessWidget {
  const _ReminderBox({required this.reminder, required this.onSwap, required this.onSnooze});

  final Reminder reminder;
  final VoidCallback onSwap;
  final VoidCallback onSnooze;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: reminder.due ? p.orange : p.sky,
        border: Border.all(color: p.ink, width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pulse(amount: 0.2, child: Text(reminder.due ? '⚠️' : '⏳', style: const TextStyle(fontSize: 22))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(reminder.due ? 'SWAP TIME' : 'HEADS UP', style: display(21, p.on)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(reminder.text, style: mono(12.5, p.on)),
          if (reminder.due) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                BrutalButton(small: true, color: p.lime, onTap: onSwap, child: const Text('⇄ SWAP NOW')),
                BrutalButton(small: true, color: p.pink, onTap: onSnooze, child: const Text('NOT YET')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Pick a new movement for a slot (or bring back an old one).
class SwapDialog extends StatefulWidget {
  const SwapDialog({
    super.key,
    required this.current,
    required this.slot,
    required this.used,
  });

  final String current;
  final String slot;
  final List<String> used;

  @override
  State<SwapDialog> createState() => _SwapDialogState();
}

class _SwapDialogState extends State<SwapDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    void submit() => Navigator.pop(context, _name.text.trim());
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c, width: w),
        );
    return AlertDialog(
      title: const Text('SWAP MOVEMENT'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.slot.isNotEmpty) Text('SLOT: ${widget.slot.toUpperCase()}', style: mono(13, p.ink)),
            Text('NOW: ${widget.current.toUpperCase()}', style: mono(13, p.ink)),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: display(22, p.ink),
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                hintText: 'NEW MOVEMENT',
                hintStyle: display(22, p.ink.withValues(alpha: 0.3)),
                filled: true,
                fillColor: p.panel2,
                enabledBorder: border(p.ink, 3),
                focusedBorder: border(p.pink, 4),
              ),
            ),
            if (widget.used.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Shout('Or bring one back'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [
                  for (final n in widget.used)
                    BrutalButton(
                      small: true,
                      color: p.lime,
                      onTap: () => Navigator.pop(context, n),
                      child: Text(n.toUpperCase()),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'APPLIES FROM THIS SESSION ON. OLD LOGS KEEP THEIR NAMES.',
              style: mono(11.5, p.ink.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CANCEL', style: display(16, p.ink)),
        ),
        BrutalButton(small: true, color: p.pink, onTap: submit, child: const Text('SWAP')),
      ],
    );
  }
}

/// Square tick: tap to copy the greyed-out numbers in. Lime when done,
/// orange with a flame when the set beat last time.
class _Tick extends StatelessWidget {
  const _Tick({required this.done, required this.beat, required this.onTap});

  final bool done;
  final bool beat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Semantics(
      button: true,
      label: done ? 'Set done (tap to undo)' : 'Log the numbers shown as done',
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          transform: done ? Matrix4.translationValues(3, 3, 0) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: done ? (beat ? p.orange : p.lime) : p.panel,
            border: Border.all(color: p.ink, width: 3),
            boxShadow: [BoxShadow(color: p.ink, offset: done ? const Offset(1, 1) : const Offset(4, 4))],
          ),
          child: Text(
            done && beat ? '🔥' : '✔',
            style: display(24, done ? p.on : p.ink.withValues(alpha: 0.25)),
          ),
        ),
      ),
    );
  }
}
