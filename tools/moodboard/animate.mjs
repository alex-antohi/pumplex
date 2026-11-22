// Builds the moodboard's animation style test from the body-slider sprites.
//
//   node tools/moodboard/animate.mjs
//
// Reads  docs/moodboard/body_sliders/<sex>/fat<F>_muscle<M>.png  (52x64)
// Writes docs/moodboard/animation/<sex>_fat<F>_muscle<M>/<anim>_<n>.png  (80x72 frames)
//        docs/moodboard/animation/<sex>_fat<F>_muscle<M>/<anim>_sheet.png (frames left to right)
//        docs/moodboard/animation/animation.json  (frame order + timing per animation)
//
// No dependencies. The pose code is in poses.mjs (shared with animate_all.mjs).

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { FW, FH, OX, OY, readPng, writePng, blank, get, set, hex, rect, poses } from './poses.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const SRC = path.join(ROOT, 'docs/moodboard/body_sliders');
const OUT = path.join(ROOT, 'docs/moodboard/animation');

const BODIES = [
  ['male', 0, 0], ['male', 50, 50], ['male', 100, 100],
  ['female', 0, 0], ['female', 50, 50], ['female', 100, 100],
];

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
  pr_flex: {
    note: 'Plays on a new PR. Dip, hop, land in a double-biceps hold.',
    loop: true,
    frames: [['dip', 120], ['air2', 90], ['air4', 120], ['air2', 90], ['land', 90], ['hold', 700], ['rest', 400]],
  },
};

const manifest = { frameSize: [FW, FH], bodyOffset: [OX, OY], scaleHint: 'whole numbers only, nearest-neighbour', bodies: [], animations: {} };
for (const [name, def] of Object.entries(ANIMS)) manifest.animations[name] = { note: def.note, loop: def.loop, frames: def.frames.map(([pose, ms]) => ({ pose, ms })) };

for (const [sex, fat, muscle] of BODIES) {
  const id = `${sex}_fat${fat}_muscle${muscle}`;
  const p = poses(readPng(path.join(SRC, sex, `fat${fat}_muscle${muscle}.png`)));
  const dir = path.join(OUT, id);
  fs.rmSync(dir, { recursive: true, force: true });
  for (const [name, def] of Object.entries(ANIMS)) {
    const unique = [...new Set(def.frames.map(([pose]) => pose))];
    const sheet = blank(FW * unique.length, FH);
    unique.forEach((pose, i) => {
      writePng(path.join(dir, `${name}_${i}_${pose}.png`), p[pose]);
      for (let y = 0; y < FH; y++) for (let x = 0; x < FW; x++) { const c = get(p[pose], x, y); if (c) set(sheet, x + i * FW, y, c); }
    });
    writePng(path.join(dir, `${name}_sheet.png`), sheet);
    manifest.animations[name].sheetOrder = unique;
  }
  manifest.bodies.push(id);
}
// contact sheet: one row per animation, every unique frame, 3x, on the sprite-stage colour
function preview(file, ids, scale = 3) {
  const names = Object.keys(ANIMS), cols = Math.max(...names.map((n) => manifest.animations[n].sheetOrder.length)), pad = 4;
  const cw = FW * scale + pad, chh = FH * scale + pad, img = blank(cols * cw * ids.length + pad * ids.length, names.length * chh + pad);
  rect(img, 0, 0, img.w, img.h, hex('#2a1148'));
  ids.forEach((id, b) => names.forEach((n, r) => manifest.animations[n].sheetOrder.forEach((pose, i) => {
    const fr = readPng(path.join(OUT, id, `${n}_${i}_${pose}.png`)), x0 = b * (cols * cw + pad) + pad + i * cw, y0 = pad + r * chh;
    rect(img, x0, y0, FW * scale, FH * scale, hex('#1f0d36'));
    for (let y = 0; y < FH; y++) for (let x = 0; x < FW; x++) { const c = get(fr, x, y); if (c) rect(img, x0 + x * scale, y0 + y * scale, scale, scale, c); }
  })));
  writePng(file, img);
}
for (const id of manifest.bodies) preview(path.join(OUT, id, 'preview_3x.png'), [id]);
fs.writeFileSync(path.join(OUT, 'animation.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`wrote ${manifest.bodies.length} bodies x ${Object.keys(ANIMS).length} animations to ${path.relative(ROOT, OUT)}`);
