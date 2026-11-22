// Builds idle / front_squat / level_up_flex for ALL 50 atlas bodies.
//
//   node tools/moodboard/animate_all.mjs
//
// Reads  docs/moodboard/creator/body_atlas.png  (5 x 10 cells of 52x64)
// Writes docs/moodboard/animation/atlas/<anim>_atlas.png  (one atlas per animation, 80x72 cells)
//        docs/moodboard/animation/atlas/animation_atlas.json  (layout, frame order + timing, per-body checks)
//
// No dependencies. The pose code is in poses.mjs (shared with animate.mjs).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { FW, FH, OX, OY, readPng, writePng, blank, get, set, poses } from './poses.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const SRC = path.join(ROOT, 'docs/moodboard/creator/body_atlas.png');
const OUT = path.join(ROOT, 'docs/moodboard/animation/atlas');

// ---------- animations ----------
// Each frame is [pose, ms]. Timing lives in animation.json for the game code.
const ANIMS = {
  idle: {
    note: 'Breathing. Upper body sinks 1 px on the out-breath; feet never move.',
    loop: true,
    frames: [['rest', 420], ['out', 300], ['out', 260], ['rest', 300]],
  },
  front_squat: {
    note: 'Heavy Lower main lift. Bar racked on the front of the shoulders, elbows forward. Down slow, up fast, pause at the top.',
    loop: true,
    frames: [['top', 500], ['d1', 140], ['d2', 140], ['d3', 160], ['bottom', 260], ['d2', 90], ['d1', 90]],
  },
  level_up_flex: {
    note: 'Plays on level-up or a critical set (no PRs, D2). Dip, hop, land in a double-biceps hold.',
    loop: true,
    frames: [['dip', 120], ['air2', 90], ['air4', 120], ['air2', 90], ['land', 90], ['hold', 700], ['rest', 400]],
  },
};

const atlas = readPng(SRC);
if (atlas.w !== 260 || atlas.h !== 640) throw new Error(`atlas is ${atlas.w}x${atlas.h}, expected 260x640`);
const cellOf = (col, row) => { const c = blank(52, 64); for (let y = 0; y < 64; y++) for (let x = 0; x < 52; x++) { const o = ((row * 64 + y) * 260 + col * 52 + x) * 4; c.px.set(atlas.px.subarray(o, o + 4), (y * 52 + x) * 4); } return c; };
const AN = Object.keys(ANIMS);
const orderOf = (n) => [...new Set(ANIMS[n].frames.map(([p]) => p))];
const sheets = {}; for (const n of AN) sheets[n] = blank(5 * FW * orderOf(n).length, 10 * FH);
const bodies = [], problems = [];
const count = (img) => { let k = 0; for (let i = 3; i < img.px.length; i += 4) if (img.px[i]) k++; return k; };
const same = (a, b) => a.px.every((v, i) => v === b.px[i]);
for (let row = 0; row < 10; row++) for (let col = 0; col < 5; col++) {
  const sex = row < 5 ? 'male' : 'female', fat = col * 25, muscle = (row % 5) * 25, id = `${sex}_fat${fat}_muscle${muscle}`;
  const entry = { id, sex, fat, muscle, col, row, ok: true, issues: [] };
  let p = null;
  try { p = poses(cellOf(col, row)); } catch (e) { entry.issues.push('analyse failed: ' + e.message); }
  if (p) {
    const base = count(p.rest);
    for (const [k, img] of Object.entries(p)) {
      if (k === 'rest') continue;
      const n = count(img);
      if (n < base * 0.6 || n > base * 2.2) entry.issues.push(`${k}: pixel count ${n} vs rest ${base}`);
      if (same(img, p.rest) && k !== 'out') entry.issues.push(`${k}: identical to rest`);
      for (let y = 0; y < FH; y++) for (const x of [0, FW - 1]) if (k !== 'top' && !/^(d|bottom)/.test(k) && get(img, x, y)) { entry.issues.push(`${k}: touches frame edge`); y = FH; break; }
    }
    if (same(p.out, p.rest)) entry.issues.push('out: identical to rest (no breathing)');
  }
  if (entry.issues.length) { entry.ok = false; problems.push(entry); }
  if (p) for (const n of AN) orderOf(n).forEach((pose, i) => {
    const ox = (i * 5 + col) * FW, oy = row * FH, f = p[pose];
    for (let y = 0; y < FH; y++) for (let x = 0; x < FW; x++) { const c = get(f, x, y); if (c) set(sheets[n], ox + x, oy + y, c); }
  });
  bodies.push(entry);
}
const manifest = {
  frameSize: [FW, FH], bodyOffset: [OX, OY], scaleHint: 'whole numbers only, nearest-neighbour',
  layout: 'Per animation one atlas <anim>_atlas.png. Atlas cell = 80x72 (body_atlas 52x64 cell + 14,8 offset, so bars/arms fit). Within a pose block: x = col*80 (col = fat/25), y = row*72 (row = (female?5:0) + muscle/25). Pose blocks sit side by side in sheetOrder, each 5 cols (400 px) wide: x = (poseIndex*5 + col)*80.',
  blockSize: [400, 720],
  rowFormula: '(female ? 5 : 0) + muscle/25', colFormula: 'fat/25',
  compat: { level_up_flex: 'Renamed from pr_flex (animate.mjs, 6-body style test). Same poses and timing; only the key and note changed. Old per-body folders in docs/moodboard/animation/<body>/pr_flex_* are unchanged.' },
  animations: {},
  bodies: bodies.map(({ id, sex, fat, muscle, col, row, ok, issues }) => ({ id, sex, fat, muscle, col, row, ok, ...(issues.length ? { issues } : {}) })),
};
for (const n of AN) {
  const d = ANIMS[n], order = orderOf(n);
  manifest.animations[n] = { note: d.note, loop: d.loop, atlas: `${n}_atlas.png`, atlasSize: [order.length * 400, 720], sheetOrder: order, frames: d.frames.map(([pose, ms]) => ({ pose, ms })) };
  writePng(path.join(OUT, `${n}_atlas.png`), sheets[n]);
}
fs.writeFileSync(path.join(OUT, 'animation_atlas.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`wrote ${bodies.length} bodies x ${AN.length} animations; ${problems.length} flagged`);
for (const b of problems) console.log(b.id, b.issues.join('; '));
