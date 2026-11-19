// Rest-day statistics: how much iron has been moved.

import 'dart:math';

import 'package:flutter/material.dart';

import 'dates.dart';
import 'program.dart';
import 'pumplex.dart';
import 'store.dart';

class LiftStats {
  LiftStats({
    required this.totalKg,
    required this.sets,
    required this.reps,
    required this.workouts,
    required this.rests,
    required this.prs,
    required this.weekKg,
    required this.prevWeekKg,
    required this.heaviest,
    required this.byWorkout,
    this.avgTime,
    this.lastTime,
  });

  /// Workout length (START TRAINING → I WORKED), when the clock was used.
  final Duration? avgTime;
  final Duration? lastTime;

  /// Sum of kg × reps over every set.
  final double totalKg;
  final int sets;
  final int reps;
  final int workouts;
  final int rests;

  /// Sessions where a movement beat its previous heaviest weight.
  final int prs;

  /// Last 7 sessions (one program week) and the 7 before that.
  final double weekKg;
  final double prevWeekKg;

  /// Heaviest weight per movement, heaviest first.
  final List<(String, double)> heaviest;

  /// Total kg per workout type, in program order.
  final List<(String, double)> byWorkout;

  bool get empty => sets == 0;
}

LiftStats computeStats(LogStore store) {
  var total = 0.0, week = 0.0, prevWeek = 0.0;
  var sets = 0, reps = 0, prs = 0;
  final cur = store.currentN;
  final heaviest = <String, double>{};
  final byWorkout = {for (final w in program.values) w.title: 0.0};
  final best = <String, double>{}; // "slot|movement" -> heaviest so far

  for (final e in store.allLogs()) {
    var vol = 0.0;
    for (final s in e.log.sets) {
      if (s.isEmpty) continue;
      sets++;
      reps += s.reps ?? 0;
      if (s.kg != null && s.reps != null) vol += s.kg! * s.reps!;
    }
    total += vol;
    if (e.n > cur - 7) {
      week += vol;
    } else if (e.n > cur - 14) {
      prevWeek += vol;
    }
    final title = program[store.dayOf(e.n)]?.title;
    if (title != null) byWorkout[title] = (byWorkout[title] ?? 0) + vol;

    final top = e.log.topKg;
    if (top != null) {
      if (top > (heaviest[e.log.name] ?? 0)) heaviest[e.log.name] = top;
      final k = '${e.id}|${e.log.name}';
      final b = best[k];
      if (b != null && top > b) prs++;
      if (b == null || top > b) best[k] = top;
    }
  }

  final sessions = store.sessions;
  final times = [
    for (final s in sessions)
      if (!s.rested && s.duration != null) s.duration!,
  ];
  return LiftStats(
    avgTime: times.isEmpty
        ? null
        : Duration(seconds: times.fold(0, (sum, d) => sum + d.inSeconds) ~/ times.length),
    lastTime: times.isEmpty ? null : times.last,
    totalKg: total,
    sets: sets,
    reps: reps,
    workouts: sessions.where((s) => !s.rested).length,
    rests: sessions.where((s) => s.rested).length,
    prs: prs,
    weekKg: week,
    prevWeekKg: prevWeek,
    heaviest: (heaviest.entries.map((e) => (e.key, e.value)).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2)))
        .take(6)
        .toList(),
    byWorkout: byWorkout.entries.map((e) => (e.key, e.value)).toList(),
  );
}

/// 12345.6 → "12,346"
String fmtThousands(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

const _things = [
  (150000.0, 'BLUE WHALES'),
  (6000.0, 'ELEPHANTS'),
  (1500.0, 'CARS'),
  (450.0, 'GRAND PIANOS'),
  (30.0, 'GOLDEN RETRIEVERS'),
];

/// "≈ 3.2 ELEPHANTS"
String inThings(double kg) {
  for (final (w, name) in _things) {
    if (kg >= w) return '≈ ${(kg / w).toStringAsFixed(1)} $name. THEY ARE CONCERNED.';
  }
  return 'LESS THAN ONE GOLDEN RETRIEVER. FOR NOW.';
}

class StatsPanel extends StatelessWidget {
  const StatsPanel({super.key, required this.store});

  final LogStore store;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final s = computeStats(store);

    final heading = display(28, p.ink).copyWith(shadows: [
      Shadow(offset: const Offset(2, 2), color: p.lime),
      Shadow(offset: const Offset(4, 4), color: p.pink),
    ]);

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

    final change = s.prevWeekKg > 0 ? (s.weekKg - s.prevWeekKg) / s.prevWeekKg * 100 : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THE STATS™', style: heading),
        const SizedBox(height: 16),
        Brutal(
          color: kNight,
          shadow: p.pink,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shout('Total iron moved', color: p.lime),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    '${fmtThousands(s.totalKg)} KG',
                    style: display(56, Colors.white).copyWith(shadows: [
                      Shadow(offset: const Offset(4, 4), color: p.pink),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(inThings(s.totalKg), style: mono(13, p.lime)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            tile('Workouts', '${s.workouts}', p.lime, -1.5),
            const SizedBox(width: 14),
            tile('Sets', '${s.sets}', p.sky, 1),
            const SizedBox(width: 14),
            tile('Reps', fmtThousands(s.reps.toDouble()), p.orange, -1),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            tile('Rest days', '${s.rests}', p.violet, 1),
            const SizedBox(width: 14),
            tile('PRs', '${s.prs}', p.pink, -1.5),
            const SizedBox(width: 14),
            tile('KG this week', fmtThousands(s.weekKg), p.lime, 1.5),
          ],
        ),
        const SizedBox(height: 18),
        Terminal([
          if (s.empty) ...[
            'NO LIFTS LOGGED YET.',
            'THE STATISTICS ARE HUNGRY. FEED THEM.',
          ] else if (change == null)
            'THIS WEEK: ${fmtThousands(s.weekKg)} KG. NOTHING TO COMPARE WITH YET.'
          else
            'THIS WEEK: ${change >= 0 ? '+' : ''}${change.round()}% VS LAST WEEK. '
                '${change >= 0 ? 'NUMBER GO UP.' : 'DELOAD? SURE. LET\'S CALL IT A DELOAD.'}',
          if (s.avgTime != null)
            'AVG WORKOUT: ${fmtDuration(s.avgTime!)} · LAST: ${fmtDuration(s.lastTime!)}',
        ]),
        if (s.heaviest.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('HEAVIEST THINGS LIFTED', style: heading),
          const SizedBox(height: 14),
          Brutal(
            shadow: p.sky,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final (i, (name, kg)) in s.heaviest.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(width: 30, child: Text('${i + 1}', style: display(24, p.pink))),
                          Expanded(child: Text(name.toUpperCase(), style: display(19, p.ink))),
                          Text('${fmtKg(kg)} KG', style: display(22, p.ink)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (!s.empty) ...[
          const SizedBox(height: 28),
          Text('IRON BY WORKOUT', style: heading),
          const SizedBox(height: 14),
          Brutal(
            shadow: p.lime,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, (title, kg)) in s.byWorkout.indexed) ...[
                    Row(
                      children: [
                        Expanded(child: Shout(title, size: 13)),
                        Text('${fmtThousands(kg)} KG', style: mono(13, p.ink)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    LayoutBuilder(
                      builder: (context, c) {
                        final most = s.byWorkout.map((e) => e.$2).fold(0.0, max);
                        final w = most == 0 ? 0.0 : c.maxWidth * kg / most;
                        return Container(
                          height: 22,
                          width: max(w, 4),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: p.accents[i % p.accents.length],
                            border: Border.all(color: p.ink, width: 3),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
