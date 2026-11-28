// Face style sheet: one row per style, fixed order top to bottom: visor, cyborg, android, helmet.
//   node tools/art_hd/preview_faces.mjs [style,style,...] [fatCol 0..4]
// Each style is generated into a scratch dir (FACE_STYLE + ART_OUT), not into assets/.
// Row: head+torso crops at 6x (male light, male light+beard, male deep, male deep+beard, then female the same),
// then one full-body cell at 3x with an outfit.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';
const HERE = path.dirname(fileURLToPath(import.meta.url));
const styles = (process.argv[2] || 'visor,cyborg,android,helmet').split(',');
const FATC = +(process.argv[3] || 1);
const K = 6, CX0 = 28, CW = 48, CH = 50, GAP = 4, BG = [60, 40, 90];
const rd = (p) => decode(fs.readFileSync(p));
const rows = styles.map((st) => {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'faces-' + st + '-'));
  execFileSync('node', [path.join(HERE, 'characters.mjs')], { env: { ...process.env, FACE_STYLE: st, ART_OUT: out }, stdio: 'pipe' });
  const L = (p) => rd(path.join(out, p));
  return { st, body: [L('assets/body/body_atlas.png'), L('assets/body/looks/body_deep_blonde.png')], beard: [L('assets/body/looks/beard_brown.png'), L('assets/body/looks/beard_blonde.png')], outfit: L('assets/outfits/cablemancer.png') };
});
const cells = [];
for (const female of [0, 1]) for (const skin of [0, 1]) for (const beard of [0, 1]) cells.push({ skin, beard, female });
const bodyCellW = 104 * 3, rowH = Math.max(CH * K, 128 * 3) + GAP * 2;
const W = cells.length * (CW * K + GAP) + bodyCellW + GAP, H = rowH * rows.length;
const px = (img, sx, sy) => { const o = (sy * img.w + sx) * 4; return img.data[o + 3] ? [img.data[o], img.data[o + 1], img.data[o + 2]] : null; };
fs.writeFileSync(path.join(HERE, 'preview_faces.png'), png(W, H, (x, y) => {
  const r = Math.floor(y / rowH), R = rows[r], yy = y % rowH - GAP; if (yy < 0) return [20, 10, 30, 255];
  const cw = CW * K + GAP, ci = Math.floor(x / cw);
  if (ci < cells.length) {
    const c = cells[ci], xx = x % cw; if (xx >= CW * K || yy >= CH * K) return [20, 10, 30, 255];
    const row = c.female ? 7 : 2, ox = FATC * 104 + CX0 + Math.floor(xx / K), oy = row * 128 + Math.floor(yy / K);
    let v = BG; const a = px(R.body[c.skin], ox, oy); if (a) v = a;
    if (c.beard) { const b = px(R.beard[c.skin], ox, oy); if (b) v = b; }
    return [...v, 255];
  }
  const xx = x - cells.length * cw - GAP; if (xx < 0 || xx >= bodyCellW || yy >= 128 * 3) return [20, 10, 30, 255];
  const ox = FATC * 104 + Math.floor(xx / 3), oy = 3 * 128 + Math.floor(yy / 3);
  let v = BG; const a = px(R.body[0], ox, oy); if (a) v = a; const o2 = px(R.outfit, ox, oy); if (o2) v = o2;
  return [...v, 255];
}));
console.log('rows top to bottom:', styles.join(', '));
