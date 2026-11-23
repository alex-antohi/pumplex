// Which movement fills each slot in a session, and when to swap it.

import 'dart:math';

import 'program.dart';
import 'store.dart';

/// Slots that rotate on a fixed schedule: slot id -> weeks (= sessions of
/// that workout, one per program week) per movement. Heads-up in the last
/// week, swap due after it. The Box Squat (ll1) does not rotate.
const rotateEvery = {
  // First exercise: every 2 weeks.
  'lu1': 2, // Light Upper: Overhead or Bench Press
  'hl1': 2, // Heavy Lower: Squat, DL or Good Morning Variation
  'hu1': 2, // Heavy Upper: Pressing Movement
  // Second movement: every 4 weeks.
  'lu2': 4, // Light Upper: Tricep Dominant Movement
  'hl3': 4, // Heavy Lower: Hard Posterior Chain Movement
  'hu4': 4, // Heavy Upper: Tricep Dominant Movement
  'll2': 4, // Light Lower: Hard Posterior Chain Movement
};

/// Every other slot: swap after this many sessions in a row without progress
/// (one session per program week, so 2 = two weeks).
const stallSessions = 2;

typedef Movement = ({String name, bool placeholder});

/// The movement for [e] in session [key]:
/// what was logged then > a swap in the app > the max-effort movement it
/// follows (rep-outs) > the spreadsheet name > the spreadsheet hint.
Movement movementOn(LogStore store, Workout w, Exercise e, String key) {
  final resolved = _resolve(store, w, e, key);
  final logged = store.get(key, e.id);
  if (logged != null && logged.hasData && logged.name.isNotEmpty && logged.name != resolved.name) {
    return (name: logged.name, placeholder: false);
  }
  return resolved;
}

Movement _resolve(LogStore store, Workout w, Exercise e, String key) {
  final swapped = store.swapOn(e.id, key);
  if (swapped != null) return (name: swapped, placeholder: false);
  final ref = e.percentOf == null ? null : w.byId(e.percentOf!);
  if (ref != null) {
    final m = movementOn(store, w, ref, key);
    if (!m.placeholder) return m;
  }
  if (e.name.isNotEmpty) return (name: e.name, placeholder: false);
  return (name: e.hint.isNotEmpty ? e.hint : 'Exercise', placeholder: true);
}

/// Rep-outs follow their max-effort movement and are not swapped on their own.
bool canSwap(Exercise e) => e.percentOf == null;

double _e1rm(ExerciseLog l) {
  var best = 0.0;
  for (final s in l.sets) {
    if (s.isEmpty) continue;
    final kg = s.kg ?? 0;
    final reps = s.reps ?? 1;
    best = max(best, kg > 0 ? kg * (1 + reps / 30) : reps.toDouble());
  }
  return best;
}

double _volume(ExerciseLog l) => l.sets.fold(0.0, (sum, s) {
      final kg = s.kg ?? 0;
      return sum + (kg > 0 ? kg * (s.reps ?? 1) : (s.reps ?? 0).toDouble());
    });

class Reminder {
  const Reminder(this.text, {required this.due});

  final String text;

  /// True: swap now. False: heads-up only.
  final bool due;
}

/// Swap reminder for [e] in session [key] (based on the sessions before it).
Reminder? reminderFor(LogStore store, Exercise e, String key, Movement m) {
  if (!canSwap(e) || store.snoozed(e.id, key)) return null;
  final name = m.name.toUpperCase();

  final every = rotateEvery[e.id];
  if (every != null) {
    // Length of the current unbroken run of this movement.
    final all = store.history(e.id, key);
    var run = 0;
    for (var i = all.length - 1; i >= 0 && all[i].log.name == m.name; i--) {
      run++;
    }
    if (run >= every) {
      return Reminder(
          '$run WEEKS OF $name. THIS SLOT GETS A NEW MOVEMENT EVERY $every WEEKS. SWAP IT.',
          due: true);
    }
    if (run > 0 && run == every - 1) {
      return Reminder('FINAL WEEK OF $name. NEXT TIME: NEW MOVEMENT.', due: false);
    }
    return null;
  }

  // Progress = a new best estimated 1RM or a new best volume.
  final runs = store.history(e.id, key, name: m.name);
  if (runs.length <= stallSessions) return null;
  var bestE1rm = -1.0, bestVolume = -1.0;
  var lastProgress = 0;
  for (var i = 0; i < runs.length; i++) {
    final e1 = _e1rm(runs[i].log), vol = _volume(runs[i].log);
    if (e1 > bestE1rm || vol > bestVolume) lastProgress = i;
    bestE1rm = max(bestE1rm, e1);
    bestVolume = max(bestVolume, vol);
  }
  final since = runs.length - 1 - lastProgress;
  if (since < stallSessions) return null;
  return Reminder(
      'NO PROGRESS ON $name IN $since WEEKS. THE GAINS HAVE LEFT THE ROOM. SWAP IT.',
      due: true);
}
