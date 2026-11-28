// Ember icon: 3 concepts, pick written to assets/icons (+2.0x/3.0x). Run: node tools/art_hd/icon_ember.mjs [a|b|c]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const PICK = process.argv[2] || 'a';

class Bm {
  constructor() { this.g = Array.from({ length: 48 }, () => Array(48).fill(false)); }
  fill(f, v = true) { for (let y = 0; y < 48; y++) for (let x = 0; x < 48; x++) if (f(x + 0.5, y + 0.5)) this.g[y][x] = v; }
  rect(x0, y0, x1, y1, v = true) { this.fill((x, y) => x >= x0 && x <= x1 + 1 && y >= y0 && y <= y1 + 1, v); }
  ell(cx, cy, rx, ry, v = true) { this.fill((x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1, v); }
  line(x0, y0, x1, y1, th, v = true) { const n = 120; for (let i = 0; i <= n; i++) { const x = x0 + (x1 - x0) * i / n, y = y0 + (y1 - y0) * i / n; this.fill((a, b) => Math.hypot(a - x, b - y) <= th / 2, v); } }
  poly(pts, v = true) {
    this.fill((x, y) => { let ins = false; for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) { const [xi, yi] = pts[i], [xj, yj] = pts[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) ins = !ins; } return ins; }, v);
  }
  zig(pts, th, v = false) { for (let i = 0; i < pts.length - 1; i++) this.line(...pts[i], ...pts[i + 1], th, v); }
}
// pointed flame lick: base centre (cx, by), height h, half width w, tip leans by `lean`
const lick = (b, cx, by, h, w, lean = 0) => b.fill((x, y) => {
  const t = (by - y) / h; if (t < 0 || t > 1) return false;
  const c = cx + lean * t * t;
  const hw = w * Math.pow(1 - t, 0.8);
  return Math.abs(x - c) <= hw;
});
const sq = (b, x, y, s = 2) => b.rect(x, y, x + s - 1, y + s - 1);

const C = {};
const mk = (n, fn) => { const b = new Bm(); fn(b); C[n] = b.g; };

mk('a', b => {
  // chunky coal lump
  b.poly([[5, 41], [4, 33], [8, 27], [15, 24], [24, 23], [33, 24], [40, 27], [44, 33], [43, 41], [38, 44], [10, 44]]);
  // glowing zig-zag seams (cut out)
  b.zig([[10, 28], [15, 33], [13, 38], [19, 41]], 2);
  b.zig([[24, 25], [22, 31], [28, 35], [25, 42]], 2);
  b.zig([[38, 29], [33, 33], [37, 38]], 2);
  b.zig([[15, 33], [22, 31]], 2);
  b.zig([[28, 35], [34, 33]], 2);
  // flame licks on the top edge
  lick(b, 13, 26, 9, 4, -1); lick(b, 24, 25, 14, 5.5, 2); lick(b, 35, 26, 8, 3.8, 2);
  // sparks drifting up and right
  sq(b, 33, 9); sq(b, 39, 5); sq(b, 42, 13, 2); sq(b, 8, 12);
});

mk('b', b => {
  b.poly([[4, 44], [3, 37], [8, 33], [40, 33], [45, 37], [44, 44]]); // coal slab
  b.zig([[10, 37], [15, 41], [20, 37], [25, 42], [31, 37], [37, 41]], 2); // cracks
  // short wide flame: 3 tongues, 17 px tall (<40%)
  lick(b, 12, 34, 12, 5.5, -1.5); lick(b, 24, 34, 17, 8, 1.5); lick(b, 36, 34, 11, 5.5, 2);
  b.rect(8, 28, 40, 33);
  b.rect(9, 33, 39, 33, false); b.rect(9, 33, 39, 33, false);
  sq(b, 17, 8); sq(b, 30, 5); sq(b, 38, 11); sq(b, 10, 14);
});

mk('c', b => {
  // diamond ember drifting up and right, curved trail down-left
  b.poly([[33, 4], [42, 15], [33, 26], [24, 15]]);
  b.poly([[33, 9], [38, 15], [33, 21], [28, 15]], false); // hot core cut
  b.poly([[33, 12], [35, 15], [33, 18], [31, 15]]);       // core dot
  for (let i = 0; i <= 60; i++) { const t = i / 60; const x = 25 - 16 * t + 4 * Math.sin(t * Math.PI), y = 24 + 19 * t; b.ell(x, y, 5.2 * (1 - t) + 1, 5.2 * (1 - t) + 1); }
  sq(b, 6, 8, 3); sq(b, 14, 3); sq(b, 40, 33, 3); sq(b, 43, 26);
});

const out = (g, f) => fs.writeFileSync(f, png(48, 48, (x, y) => g[y][x] ? [255, 255, 255, 255] : [0, 0, 0, 0]));
for (const n of ['a', 'b', 'c']) if (n !== PICK) out(C[n], path.join(ROOT, 'tools', 'art_hd', `ember_alt_${n}.png`));
for (const d of ['', '2.0x', '3.0x']) out(C[PICK], path.join(ROOT, 'assets', 'icons', d, 'ember.png'));

// preview
const load = n => { const d = decode(fs.readFileSync(path.join(ROOT, 'assets', 'icons', n + '.png'))); return (x, y) => d.data[(y * d.w + x) * 4 + 3] > 127; };
const rows = [...['a', 'b', 'c'].map(n => [n, (x, y) => C[n][y][x]]), ...['fire', 'flame', 'drop'].map(n => [n, load(n)])];
const PURP = [38, 20, 72], WH = [255, 255, 255], S = 48 * 4 + 12;
const WW = rows.length * S + 12, HH = 48 * 4 + 12 + 24 * 2 + 24;
const cv = Array.from({ length: HH }, () => Array(WW).fill(PURP));
rows.forEach(([, f], i) => {
  const ox = 6 + i * S;
  for (let y = 0; y < 192; y++) for (let x = 0; x < 192; x++) if (f(x >> 2, y >> 2)) cv[6 + y][ox + x] = WH;
  for (let y = 0; y < 24; y++) for (let x = 0; x < 24; x++) {
    let s = 0; for (let j = 0; j < 2; j++) for (let k = 0; k < 2; k++) s += f(x * 2 + k, y * 2 + j) ? 1 : 0;
    const px = PURP.map(p => Math.round(p + (255 - p) * s / 4));
    for (let a = 0; a < 2; a++) for (let c = 0; c < 2; c++) cv[210 + y * 2 + a][ox + x * 2 + c] = px;
  }
});
fs.writeFileSync(path.join(ROOT, 'tools', 'art_hd', 'preview_ember.png'), png(WW, HH, (x, y) => [...cv[y][x], 255]));
