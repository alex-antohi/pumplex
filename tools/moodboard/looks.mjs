/* Head looks for the character creator: skin tones, hair colours and facial hair.
 *
 *   node tools/moodboard/looks.mjs
 *
 * Source: docs/moodboard/creator/body_atlas.png (260x640, 52x64 cells, 5 fat x 5 muscle per sex).
 * Every cell draws skin with the same 3 colours and hair with the same 3 colours, so a look is a recolour:
 *   body_<skin>_<hair>.png  the whole atlas with the skin and hair ramps swapped
 *                           (light + brown is the source atlas itself, so it is not written again)
 *   beard_<hair>.png        a transparent overlay: the jaw of every cell in the hair colours
 * Output: docs/moodboard/looks/ (design copy) and assets/body/looks/ (app copy).
 * No npm packages. Ids never change once shipped: add new looks at the end of a list.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png, decode } from './png.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const ATLAS = path.join(ROOT, 'docs/moodboard/creator/body_atlas.png');
const OUT = [path.join(ROOT, 'docs/moodboard/looks'), path.join(ROOT, 'assets/body/looks')];
const W = 52, H = 64, COLS = 5, ROWS = 10;

/* Ramps: highlight, base, shadow. The first entry of each list is the source atlas. */
const SKINS = {
  light: ['#e4bc97', '#d39a6a', '#8c605c'],
  deep: ['#b07a52', '#8a5534', '#5a3322'],
};
const HAIRS = {
  brown: ['#997d6b', '#5a3424', '#462533'],
  blonde: ['#f6d77c', '#d9a93e', '#9c6a2a'],
};
const EYE = '#281424';

const atlas = decode(fs.readFileSync(ATLAS));
if (atlas.w !== W * COLS || atlas.h !== H * ROWS) throw new Error(`atlas size ${atlas.w}x${atlas.h}`);
const rgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const hexAt = (d, i) => '#' + [d[i], d[i + 1], d[i + 2]].map((v) => v.toString(16).padStart(2, '0')).join('');

function write(name, w, h, data) {
  const buf = png(w, h, (x, y) => { const i = (y * w + x) * 4; return [data[i], data[i + 1], data[i + 2], data[i + 3]]; });
  for (const dir of OUT) { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, name), buf); }
}

/* ---- body atlases: swap the skin and hair ramps */
const [skin0, hair0] = [SKINS.light, HAIRS.brown];
let bodies = 0;
for (const [sid, skin] of Object.entries(SKINS)) {
  for (const [hid, hair] of Object.entries(HAIRS)) {
    if (sid === 'light' && hid === 'brown') continue; // the source atlas
    const map = new Map();
    skin0.forEach((c, k) => map.set(c, rgb(skin[k])));
    hair0.forEach((c, k) => map.set(c, rgb(hair[k])));
    const d = Buffer.from(atlas.data);
    for (let i = 0; i < d.length; i += 4) {
      if (!d[i + 3]) continue;
      const to = map.get(hexAt(d, i));
      if (to) [d[i], d[i + 1], d[i + 2]] = to;
    }
    write(`body_${sid}_${hid}.png`, atlas.w, atlas.h, d);
    bodies++;
  }
}

/* ---- beard overlays: per cell, the skin under the eyes becomes hair.
 * Rows eye+3 (sideburns only: 2 px at each side) and eye+4 .. eye+6 (the whole jaw).
 * The skin shade picks the hair shade, so the jaw keeps its light and shadow. */
function beardCells() {
  const cells = [];
  for (let cy = 0; cy < ROWS; cy++) for (let cx = 0; cx < COLS; cx++) {
    const at = (x, y) => { const i = ((cy * H + y) * atlas.w + cx * W + x) * 4; return atlas.data[i + 3] ? hexAt(atlas.data, i) : null; };
    let eye = -1;
    for (let y = 0; y < 24 && eye < 0; y++) for (let x = 0; x < W; x++) if (at(x, y) === EYE) { eye = y; break; }
    if (eye < 0) throw new Error(`no eyes in cell ${cx},${cy}`);
    const px = [];
    for (let y = eye + 3; y <= eye + 6; y++) {
      const skinX = [];
      for (let x = 0; x < W; x++) { const k = skin0.indexOf(at(x, y)); if (k >= 0) skinX.push([x, k]); }
      const side = y === eye + 3;
      skinX.forEach(([x, k], n) => { if (!side || n < 2 || n >= skinX.length - 2) px.push([cx * W + x, cy * H + y, k]); });
    }
    cells.push(px);
  }
  return cells;
}
const beard = beardCells().flat();
for (const [hid, hair] of Object.entries(HAIRS)) {
  const d = Buffer.alloc(atlas.data.length);
  for (const [x, y, k] of beard) { const i = (y * atlas.w + x) * 4; [d[i], d[i + 1], d[i + 2]] = rgb(hair[k]); d[i + 3] = 255; }
  write(`beard_${hid}.png`, atlas.w, atlas.h, d);
}

console.log(`${bodies} body atlases, ${Object.keys(HAIRS).length} beard overlays (${beard.length} px) -> docs/moodboard/looks, assets/body/looks`);
