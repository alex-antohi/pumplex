// Contact sheet: old (top) vs new (bottom), body + outfit stacked. node tools/art_hd/preview_characters.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';
const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const rd = (p) => decode(fs.readFileSync(path.join(ROOT, p)));
const oldB = rd('docs/moodboard/creator/body_atlas.png'), newB = rd('assets/body/body_atlas.png');
const outs = ['bruiser', 'paladin', 'scrapper', 'cablemancer', 'paladin', null];
const pick = [[0, 0], [2, 2], [4, 4], [1, 7], [3, 9], [2, 5]];
const O = {}, N = {};
for (const id of new Set(outs)) if (id) { O[id] = rd(`docs/moodboard/outfits/${id}.png`); N[id] = rd(`assets/outfits/${id}.png`); }
const K = 3, CW = 104 * K, CH = 128 * K, bg = [60, 40, 90];
fs.writeFileSync(path.join(ROOT, 'tools/art_hd/preview_characters.png'), png(CW * pick.length, CH * 2, (x, y) => {
  const i = Math.floor(x / CW), row = Math.floor(y / CH), [cx, cy] = pick[i];
  const lx = Math.floor((x % CW) / K), ly = Math.floor((y % CH) / K);
  const layers = row === 0 ? [oldB, O[outs[i]]] : [newB, N[outs[i]]];
  const s = row === 0 ? 2 : 1; // old art is 1x: scale it to the 2x grid
  let c = bg;
  for (const l of layers) {
    if (!l) continue;
    const sx = cx * (l.w / 5) + Math.floor(lx / s), sy = cy * (l.h / 10) + Math.floor(ly / s), o = (sy * l.w + sx) * 4;
    if (l.data[o + 3]) c = [l.data[o], l.data[o + 1], l.data[o + 2]];
  }
  return [...c, 255];
}));
