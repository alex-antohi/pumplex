import 'dart:async';

import 'package:flutter/material.dart';

import 'dates.dart';
import 'program.dart';
import 'pumplex.dart';
import 'stats.dart';
import 'store.dart';

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
        final p = Pal.of(context);
        final day = store.dayOf(n);
        final workout = program[day];
        final current = n == store.currentN;
        final preview = n > store.currentN;
        final footer = current
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

        // Session clock: START TRAINING now, the time it took afterwards.
        final Widget? clock;
        if (current) {
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
          padding: _listPadding,
          children: [
            Shout('Session $n · Day $day of 7'),
            const SizedBox(height: 8),
            MegaText(workout.title, size: 58),
            const SizedBox(height: 14),
            preview ? Tag('PREVIEW · COMING UP', bg: p.sky, fg: p.on) : Tag(dayTag(n)),
            if (clock != null) ...[
              const SizedBox(height: 22),
              clock,
            ],
            const SizedBox(height: 26),
            // The new workout system (class, equipment, difficulty) goes here.
            Brutal(
              shadow: p.violet,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TODAY'S WORK", style: display(21, p.ink)),
                    const SizedBox(height: 12),
                    const Terminal([
                      'THE WORKOUT SYSTEM IS BEING REBUILT.',
                      'NO SETS. NO REPS. NO SPREADSHEETS.',
                      'TRAIN. PRESS I WORKED. THAT IS THE JOB.',
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
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
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
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
