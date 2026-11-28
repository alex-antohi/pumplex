// Preview sheet: old 1x (shown 2x) beside the new 2x art. Run: node tools/art_hd/preview_areas_b_fix.mjs
// Reads the 1x originals from git commit 40ba8ee and the new files from assets/areas.
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { png, decode } from '../moodboard/png.mjs';

const old = (a, n) => decode(execFileSync('git', ['show', `40ba8ee:assets/areas/${a}/${n}.png`], { maxBuffer: 1 << 24 }));
const cur = (a, n) => decode(fs.readFileSync(`assets/areas/${a}/${n}.png`));
const rows = [];
for (const a of ['arcade', 'frostbite']) {
  rows.push({ a, n: 'background', o: old(a, 'background'), c: cur(a, 'background') });
  rows.push({ a, n: 'floor', o: old(a, 'floor'), c: cur(a, 'floor') });
}
// each row: old scaled 2x, gap, new at 2x pixels shown 1:1
const GAP = 12, PAD = 8;
// layout: backgrounds side by side on one line, floors on one line below
const bgW = rows[0].c.w, bgH = rows[0].c.h;
const W = PAD + (bgW + GAP) * 4, H = PAD + bgH + GAP + rows[1].c.h + PAD;
const blits = [];
const add = (img, scale, x, y) => blits.push({ img, scale, x, y });
add(rows[0].o, 2, PAD, PAD); add(rows[0].c, 1, PAD + bgW + GAP, PAD);
add(rows[2].o, 2, PAD + (bgW + GAP) * 2, PAD); add(rows[2].c, 1, PAD + (bgW + GAP) * 3, PAD);
const fy = PAD + bgH + GAP;
add(rows[1].o, 2, PAD, fy); add(rows[1].c, 1, PAD + bgW + GAP, fy);
add(rows[3].o, 2, PAD + (bgW + GAP) * 2, fy); add(rows[3].c, 1, PAD + (bgW + GAP) * 3, fy);
fs.writeFileSync('tools/art_hd/preview_areas_b_fix.png', png(W, H, (x, y) => {
  for (const b of blits) {
    const lx = x - b.x, ly = y - b.y;
    if (lx >= 0 && ly >= 0 && lx < b.img.w * b.scale && ly < b.img.h * b.scale) {
      const o = (Math.floor(ly / b.scale) * b.img.w + Math.floor(lx / b.scale)) * 4;
      return [b.img.data[o], b.img.data[o + 1], b.img.data[o + 2], 255];
    }
  }
  return [60, 62, 70, 255];
}));
console.log('preview written');
