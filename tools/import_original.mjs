#!/usr/bin/env node
// One-time import of the owner's workouts from the ORIGINAL app (branch
// `original`, a separate app) into a PUMPLEX backup file (version 7).
//
//   node tools/import_original.mjs <original-backup.json> <out.json> [--into <main-backup.json>]
//
// Without --into: a version 7 backup with only sessions and XP (no profile,
// body, favorites or my gear). LOAD BACKUP in the app then keeps the
// lifter and replaces only sessions and XP; the sessions take the current
// class, mode and area (they are empty in the file).
// With --into: the main backup (made by SAVE BACKUP) with the workouts
// merged in. Nothing in it is deleted or replaced.
//
// Rules (same as normal logging): each non-rested original session with
// logs becomes the training day of its date. Each slot becomes the mapped
// exercise id; sets = the done sets, one set log (kg, reps) per set. Two
// slots of one day with the same id become one entry, sets in order. A
// date that already has the id: that entry is skipped. A date with an old
// (legacy or frozen) day is skipped: it already holds its XP. Each entry
// saves the exercise's score (D91), like the first set in the app. All
// sets are saved; the D52 cap (10 sets of a move a day) is in the XP rules,
// as in the app. XP is not written: the app works it out from the sets.
//
// `node tools/import_original.mjs --self-test` checks the rules.
// Name map: tools/original_import_map.md.

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

/** Original-app name (lower case, trimmed) -> exercise id. Never change an id. */
export const NAME_MAP = {
  'bench': 'Barbell_Bench_Press_-_Medium_Grip',
  'close bench': 'Close-Grip_Barbell_Bench_Press',
  'bb row': 'Bent_Over_Barbell_Row',
  'pull up': 'Pullups',
  'side raise': 'Side_Lateral_Raise',
  'bicep curl': 'Dumbbell_Bicep_Curl',
  'rear delt fly': 'Reverse_Flyes',
  'lb squat': 'Barbell_Squat',
  'good morning': 'Good_Morning',
  'lunges': 'Barbell_Lunge',
  'leg curl': 'Lying_Leg_Curls',
  'cable ab curls': 'Cable_Crunch',
  'rolling db ext.': 'Lying_Dumbbell_Tricep_Extension',
  'db row': 'One-Arm_Dumbbell_Row',
  'lat pulldown': 'lat pulldown|cable|medium grip',
  'front raise': 'Front_Dumbbell_Raise',
  'ez bar curl': 'EZ-Bar_Curl',
  'face pulls': 'Face_Pull',
  'box squat': 'Box_Squat',
  'stiff leg dl': 'Stiff-Legged_Barbell_Deadlift',
  'bulgarian split squats': 'Dumbbell_Bulgarian_Split_Squat',
  'leg raise': 'Flat_Bench_Lying_Leg_Raise',
  'over head press': 'Standing_Military_Press',
};

const SESSIONS = 'sessions_v3';
const XP = 'xp_events_v1';
const PROFILE = 'profile_v1';
/** Saved XP events that belong to one old day (see LogStore._sessionSources). */
const OLD_DAY_SOURCES = new Set(['legacy', 'streak', 'workout']);

/** The app's exercise list: id -> {name, score}. */
export function loadCatalog(path = join(root, 'assets/exercises/exercises.json')) {
  const list = JSON.parse(readFileSync(path, 'utf8'));
  return new Map(list.map((e) => [e.id, e]));
}

const two = (n) => String(n).padStart(2, '0');
/** Like isoNow in lib/game/model.dart: local time, no milliseconds. */
const iso = (ms) => {
  const d = new Date(ms);
  return `${d.getFullYear()}-${two(d.getMonth() + 1)}-${two(d.getDate())}T${two(d.getHours())}:${two(d.getMinutes())}:${two(d.getSeconds())}`;
};

/** The id of an original-app name, or null. */
export const idOf = (name) => NAME_MAP[String(name ?? '').trim().toLowerCase()] ?? null;

/**
 * Merges [original] (the original app's backup, version 2 with logs) into
 * [main] (a PUMPLEX backup of version 7, or null). Returns the new backup
 * and the counts. Does not change its inputs.
 */
export function merge(original, main, catalog) {
  if (original?.app !== 'pumplex' || original.version !== 2 || typeof original.logs !== 'object' || !original.logs) {
    throw new Error('Not an original-app backup (version 2 with logs)');
  }
  if (main && (main.app !== 'pumplex' || main.version !== 7)) {
    throw new Error('--into needs a PUMPLEX backup of version 7 (SAVE BACKUP)');
  }
  for (const id of Object.values(NAME_MAP)) {
    if (!catalog.has(id)) throw new Error(`Map id not in the exercise list: ${id}`);
  }
  const out = main ? structuredClone(main) : { app: 'pumplex', version: 7, [SESSIONS]: {}, [XP]: [] };
  out[SESSIONS] ??= {};
  out[XP] ??= [];
  const profile = out[PROFILE] ?? {};
  const oldDays = new Set(out[XP].filter((e) => OLD_DAY_SOURCES.has(e.source)).map((e) => e.ref));
  const r = {
    daysAdded: 0, daysExtended: 0, setsAdded: 0, entriesAdded: 0,
    entriesSkipped: 0, setsSkipped: 0, restedSkipped: 0, noLogsSkipped: 0, oldDaysSkipped: 0,
    unknown: new Map(),
  };
  (original.sessions ?? []).forEach((s, i) => {
    if (s.rested) return void r.restedSkipped++;
    const logs = original.logs[`S${String(i + 1).padStart(5, '0')}`];
    // One entry per id, in the order of its first slot; slots join in order.
    const entries = new Map();
    for (const slot of Object.values(logs ?? {})) {
      const done = (slot?.sets ?? []).filter((x) => x?.done === true);
      if (done.length === 0) continue;
      const id = idOf(slot.name);
      if (!id) {
        r.unknown.set(slot.name, (r.unknown.get(slot.name) ?? 0) + done.length);
        continue;
      }
      const log = done.map((x) => ({
        ...(typeof x.kg === 'number' ? { kg: Math.round(Math.min(Math.max(x.kg, 0), 9999) * 2) / 2, kgTyped: true } : {}),
        ...(typeof x.reps === 'number' ? { reps: Math.round(x.reps), repsTyped: true } : {}),
      }));
      entries.set(id, [...(entries.get(id) ?? []), ...log]);
    }
    if (entries.size === 0) return void r.noLogsSkipped++;
    const date = s.date;
    const had = out[SESSIONS][date];
    if (had?.legacy || oldDays.has(date)) {
      r.oldDaysSkipped++;
      for (const log of entries.values()) {
        r.entriesSkipped++;
        r.setsSkipped += log.length;
      }
      return;
    }
    const day = had ?? {
      classId: profile.classId ?? '',
      difficultyId: profile.difficultyId ?? '',
      areaId: profile.areaId ?? '',
      ...(typeof s.startMs === 'number' ? { firstMarkAt: iso(s.startMs) } : {}),
      ...(typeof s.endMs === 'number' ? { lastMarkAt: iso(s.endMs) } : {}),
      legacy: false,
      exercises: [],
    };
    day.exercises ??= [];
    let added = 0;
    for (const [id, log] of entries) {
      if (day.exercises.some((e) => e.exerciseId === id)) {
        r.entriesSkipped++;
        r.setsSkipped += log.length;
        continue;
      }
      const score = catalog.get(id).score;
      day.exercises.push({
        exerciseId: id,
        sets: log.length,
        ...(log.some((l) => Object.keys(l).length > 0) ? { log } : {}),
        ...(typeof score === 'number' ? { score } : {}),
      });
      r.entriesAdded++;
      r.setsAdded += log.length;
      added++;
    }
    if (added === 0) return;
    if (had) r.daysExtended++;
    else r.daysAdded++;
    out[SESSIONS][date] = day;
  });
  // Sorted by date, like a file the app writes.
  out[SESSIONS] = Object.fromEntries(Object.entries(out[SESSIONS]).sort(([a], [b]) => a.localeCompare(b)));
  return { backup: out, report: r };
}

function selfTest() {
  const catalog = loadCatalog();
  const assert = (ok, what) => {
    if (!ok) throw new Error(`self-test failed: ${what}`);
  };
  const set = (kg, reps, done = true) => ({ kg, reps, done });
  const original = {
    app: 'pumplex', version: 2,
    sessions: [
      { day: 1, date: '2026-11-11', rested: false },
      { day: 2, date: '2026-11-12', rested: true },
      { day: 3, date: '2026-11-13', rested: false },
      { day: 4, date: '2026-11-14', rested: false },
    ],
    logs: {
      S00001: {
        hu1: { name: ' Bench ', sets: [set(92, 4)] },
        hu2: { name: 'bench', sets: [set(72, 12), set(72, 12), set(72, 10, false)] },
        hu3: { name: 'BB Row', sets: [set(52, 8)] },
        hu4: { name: 'Mystery Move', sets: [set(1, 1)] },
      },
      S00002: { lu1: { name: 'Bench', sets: [set(1, 1)] } }, // rested: skipped
      S00003: { lu1: { name: 'Pull up', sets: [set(85, 8), set(85, 6)] } },
    },
  };
  // Into empty data.
  const a = merge(original, null, catalog);
  const s = a.backup[SESSIONS];
  assert(Object.keys(s).join() === '2026-11-11,2026-11-13', 'days');
  const bench = s['2026-11-11'].exercises[0];
  assert(bench.exerciseId === NAME_MAP.bench && bench.sets === 3, 'slot merge');
  assert(bench.log.map((l) => `${l.kg}x${l.reps}`).join() === '92x4,72x12,72x12', 'set logs in order');
  assert(bench.score === catalog.get(NAME_MAP.bench).score, 'score');
  assert(a.report.unknown.get('Mystery Move') === 1, 'unknown');
  assert(a.report.restedSkipped === 1 && a.report.noLogsSkipped === 1, 'rested and no-logs skip');
  assert(!(PROFILE in a.backup) && a.backup.version === 7, 'no profile, version 7');
  // Into data with a day: same id skipped, the rest added, nothing removed.
  const main = {
    app: 'pumplex', version: 7,
    [PROFILE]: { classId: 'paladin', difficultyId: 'pain', areaId: 'gainsgard' },
    [SESSIONS]: {
      '2026-11-11': { classId: 'paladin', difficultyId: 'sweat', areaId: 'gainsgard', legacy: false,
        exercises: [{ exerciseId: NAME_MAP.bench, sets: 1 }] },
      '2026-11-01': { classId: 'paladin', difficultyId: 'sweat', areaId: 'gainsgard', legacy: false,
        exercises: [{ exerciseId: 'Barbell_Squat', sets: 2 }] },
    },
    [XP]: [{ at: '2026-11-13T00:00:00', source: 'legacy', amount: 150, ref: '2026-11-13' }],
    favorites_v1: ['Barbell_Squat'],
  };
  const b = merge(original, main, catalog);
  const t = b.backup[SESSIONS];
  assert(t['2026-11-11'].exercises.length === 2 && t['2026-11-11'].exercises[0].sets === 1, 'same id skipped');
  assert(t['2026-11-01'].exercises[0].sets === 2, 'old day kept');
  assert(!('2026-11-13' in t) && b.report.oldDaysSkipped === 1, 'legacy day skipped');
  assert(b.report.entriesSkipped === 2 && b.report.daysExtended === 1, 'counts');
  assert(b.backup.favorites_v1[0] === 'Barbell_Squat' && main[SESSIONS]['2026-11-11'].exercises.length === 1, 'kept');
  console.log('self-test OK');
}

function main(argv) {
  if (argv[0] === '--self-test') return selfTest();
  const i = argv.indexOf('--into');
  const into = i >= 0 ? argv[i + 1] : null;
  const rest = argv.filter((_, k) => i < 0 || (k !== i && k !== i + 1));
  if (rest.length !== 2 || (i >= 0 && !into)) {
    console.error('usage: node tools/import_original.mjs <original-backup.json> <out.json> [--into <main-backup.json>]');
    process.exit(2);
  }
  const read = (p) => JSON.parse(readFileSync(p, 'utf8').replace(/^﻿/, ''));
  const { backup, report: r } = merge(read(rest[0]), into ? read(into) : null, loadCatalog());
  writeFileSync(rest[1], JSON.stringify(backup, null, 1));
  console.log(`added: ${r.daysAdded} new days, ${r.daysExtended} days extended, ${r.entriesAdded} exercises, ${r.setsAdded} sets`);
  console.log(`skipped: ${r.entriesSkipped} exercises (${r.setsSkipped} sets) already there or on old days; ` +
    `${r.restedSkipped} rest days; ${r.noLogsSkipped} sessions without logs; ${r.oldDaysSkipped} old days`);
  console.log(r.unknown.size ? `unknown names (skipped): ${[...r.unknown].map(([n, k]) => `${n} (${k} sets)`).join(', ')}` : 'unknown names: none');
  console.log(`wrote ${rest[1]}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main(process.argv.slice(2));
