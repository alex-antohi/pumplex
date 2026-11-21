// Rest-day statistics: how much work was done (sessions and time, no numbers
// about sets or weights).

import 'package:flutter/material.dart';

import 'dates.dart';
import 'pumplex.dart';
import 'store.dart';

class WorkStats {
  WorkStats({
    required this.workouts,
    required this.rests,
    required this.weekWorkouts,
    this.totalTime,
    this.avgTime,
    this.lastTime,
    this.longestTime,
  });

  final int workouts;
  final int rests;

  /// Workouts in the last 7 sessions (one program week).
  final int weekWorkouts;

  /// From START TRAINING to I WORKED, when the clock was used.
  final Duration? totalTime;
  final Duration? avgTime;
  final Duration? lastTime;
  final Duration? longestTime;

  bool get empty => workouts == 0 && rests == 0;
}

WorkStats computeStats(LogStore store) {
  final sessions = store.sessions;
  final recent = sessions.length > 7 ? sessions.sublist(sessions.length - 7) : sessions;
  final times = [
    for (final s in sessions)
      if (!s.rested && s.duration != null) s.duration!,
  ];
  final total = times.fold(Duration.zero, (a, b) => a + b);
  return WorkStats(
    workouts: sessions.where((s) => !s.rested).length,
    rests: sessions.where((s) => s.rested).length,
    weekWorkouts: recent.where((s) => !s.rested).length,
    totalTime: times.isEmpty ? null : total,
    avgTime: times.isEmpty ? null : Duration(seconds: total.inSeconds ~/ times.length),
    lastTime: times.isEmpty ? null : times.last,
    longestTime: times.isEmpty ? null : times.reduce((a, b) => a > b ? a : b),
  );
}

class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key, required this.store});

  final LogStore store;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final s = computeStats(store);

    Widget tile(String label, String value, Color shadow, double angle) => Expanded(
          child: Brutal(
            shadow: shadow,
            offset: 5,
            border: 3,
            angle: angle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                children: [
                  FittedBox(child: Text(value, style: display(32, p.ink))),
                  const SizedBox(height: 4),
                  Shout(label, size: 11),
                ],
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE STATS™',
          style: display(28, p.ink).copyWith(shadows: [
            Shadow(offset: const Offset(2, 2), color: p.lime),
            Shadow(offset: const Offset(4, 4), color: p.pink),
          ]),
        ),
        const SizedBox(height: 16),
        Brutal(
          color: kNight,
          shadow: p.pink,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shout('Time under iron', color: p.lime),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    s.totalTime == null ? '–' : fmtDuration(s.totalTime!),
                    style: display(56, Colors.white).copyWith(shadows: [
                      Shadow(offset: const Offset(4, 4), color: p.pink),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.totalTime == null
                      ? 'PRESS START TRAINING NEXT TIME. THE CLOCK IS HUNGRY.'
                      : 'ALL OF IT SPENT WORKING. NONE OF IT SPENT TYPING.',
                  style: mono(13, p.lime),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            tile('Workouts', '${s.workouts}', p.lime, -1.5),
            const SizedBox(width: 14),
            tile('Rest days', '${s.rests}', p.sky, 1),
            const SizedBox(width: 14),
            tile('This week', '${s.weekWorkouts}', p.orange, -1),
          ],
        ),
        const SizedBox(height: 18),
        Terminal([
          if (s.empty) ...[
            'NOTHING DONE YET.',
            'THE STATISTICS ARE HUNGRY. FEED THEM.',
          ] else if (s.avgTime == null)
            'NO TIMED WORKOUTS YET.'
          else ...[
            'AVG WORKOUT: ${fmtDuration(s.avgTime!)} · LAST: ${fmtDuration(s.lastTime!)}',
            'LONGEST: ${fmtDuration(s.longestTime!)}',
          ],
        ]),
      ],
    );
  }
}
