// Visor mouth style sheet: one row per style, order top to bottom: none, line, grin, grille, jaw.
//   node tools/art_hd/preview_mouths.mjs [style,style,...] [fatCol 0..4]
// Row: head+torso crops at 6x (male/female x light/deep x without/with beard), then one full body at 3x.
// Bottom strip: heads at 2x (the real phone size), per style 4 crops (male light, male deep+beard, female light, female deep+beard).
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';
const HERE = path.dirname(fileURLToPath(import.meta.url));
const styles = (process.argv[2] || 'none,line,grin,grille,jaw').split(',');
const FATC = +(process.argv[3] || 1);
const K = 6, CX0 = 28, CW = 48, CH = 50, GAP = 4, BG = [60, 40, 90], DARK = [20, 10, 30, 255];
const rd = (p) => decode(fs.readFileSync(p));
const rows = styles.map((st) => {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'mouth-' + st + '-'));
  execFileSync('node', [path.join(HERE, 'characters.mjs')], { env: { ...process.env, FACE_STYLE: 'visor', MOUTH_STYLE: st, ART_OUT: out }, stdio: 'pipe' });
  const L = (p) => rd(path.join(out, p));
  return { st, body: [L('assets/body/body_atlas.png'), L('assets/body/looks/body_deep_blonde.png')], beard: [L('assets/body/looks/beard_brown.png'), L('assets/body/looks/beard_blonde.png')], outfit: L('assets/outfits/cablemancer.png') };
});
const cells = [];
for (const female of [0, 1]) for (const skin of [0, 1]) for (const beard of [0, 1]) cells.push({ skin, beard, female });
const bodyCellW = 104 * 3, rowH = Math.max(CH * K, 128 * 3) + GAP * 2;
const small = [{ female: 0, skin: 0, beard: 0 }, { female: 0, skin: 1, beard: 1 }, { female: 1, skin: 0, beard: 0 }, { female: 1, skin: 1, beard: 0 }];
const K2 = 2, sCW = CW * K2 + GAP, stripH = CH * K2 + GAP * 2;
const W = cells.length * (CW * K + GAP) + bodyCellW + GAP, H = rowH * rows.length + stripH;
const px = (img, sx, sy) => { const o = (sy * img.w + sx) * 4; return img.data[o + 3] ? [img.data[o], img.data[o + 1], img.data[o + 2]] : null; };
const head = (R, c, xx, yy, k) => {
  const row = c.female ? 7 : 2, ox = FATC * 104 + CX0 + Math.floor(xx / k), oy = row * 128 + Math.floor(yy / k);
  let v = BG; const a = px(R.body[c.skin], ox, oy); if (a) v = a;
  if (c.beard) { const b = px(R.beard[c.skin], ox, oy); if (b) v = b; }
  return [...v, 255];
};
fs.writeFileSync(path.join(HERE, 'preview_mouths.png'), png(W, H, (x, y) => {
  if (y >= rowH * rows.length) { // 2x strip
    const yy = y - rowH * rows.length - GAP; if (yy < 0 || yy >= CH * K2) return DARK;
    const i = Math.floor(x / sCW), xx = x % sCW; if (i >= rows.length * small.length || xx >= CW * K2) return DARK;
    return head(rows[Math.floor(i / small.length)], small[i % small.length], xx, yy, K2);
  }
  const r = Math.floor(y / rowH), R = rows[r], yy = y % rowH - GAP; if (yy < 0) return DARK;
  const cw = CW * K + GAP, ci = Math.floor(x / cw);
  if (ci < cells.length) {
    const xx = x % cw; if (xx >= CW * K || yy >= CH * K) return DARK;
    return head(R, cells[ci], xx, yy, K);
  }
  const xx = x - cells.length * cw - GAP; if (xx < 0 || xx >= bodyCellW || yy >= 128 * 3) return DARK;
  const ox = FATC * 104 + Math.floor(xx / 3), oy = 3 * 128 + Math.floor(yy / 3);
  let v = BG; const a = px(R.body[0], ox, oy); if (a) v = a; const o2 = px(R.outfit, ox, oy); if (o2) v = o2;
  return [...v, 255];
}));
console.log('rows top to bottom:', styles.join(', '));
