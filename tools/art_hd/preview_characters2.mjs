// Contact sheet for the character fixes: old (left of each pair) vs new, body + outfit stacked, 4x.
//   node tools/art_hd/preview_characters2.mjs <dir with old body_atlas.png + outfit PNGs>
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';
const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const OLD = process.argv[2];
const rd = (p) => decode(fs.readFileSync(p));
const oldB = rd(path.join(OLD, 'body_atlas.png')), newB = rd(path.join(ROOT, 'assets/body/body_atlas.png'));
const ids = ['scrapper', 'bruiser', 'paladin', 'cablemancer'];
const O = {}, N = {};
for (const id of ids) { O[id] = rd(path.join(OLD, id + '.png')); N[id] = rd(path.join(ROOT, `assets/outfits/${id}.png`)); }
// [fat col, row, outfit]
const pick = (process.argv[3] ? JSON.parse(process.argv[3]) : [[0, 0, 'scrapper'], [2, 2, 'bruiser'], [4, 4, 'paladin'], [0, 4, 'cablemancer'], [0, 5, 'bruiser'], [2, 7, 'scrapper'], [4, 9, 'cablemancer'], [0, 9, 'paladin']]);
const K = 4, CW = 104 * K, CH = 128 * K, bg = [60, 40, 90], PER = 4, GAP = 8;
const rowsN = Math.ceil(pick.length / PER);
const SW = CW * 2 + GAP;
fs.writeFileSync(path.join(ROOT, 'tools/art_hd/preview_characters2.png'), png(SW * PER, CH * rowsN, (x, y) => {
  const r = Math.floor(y / CH), slot = Math.floor(x / SW), rx = x % SW;
  if (rx >= CW * 2) return [20, 10, 30, 255];
  const side = Math.floor(rx / CW), i = r * PER + slot; if (!pick[i]) return [20, 10, 30, 255];
  const [cx, cy, out] = pick[i];
  const lx = Math.floor((rx % CW) / K), ly = Math.floor((y % CH) / K);
  const layers = side === 0 ? [oldB, O[out]] : [newB, N[out]];
  let c = bg;
  for (const l of layers) {
    const sx = cx * 104 + lx, sy = cy * 128 + ly, o = (sy * l.w + sx) * 4;
    if (l.data[o + 3]) c = [l.data[o], l.data[o + 1], l.data[o + 2]];
  }
  return [...c, 255];
}));
