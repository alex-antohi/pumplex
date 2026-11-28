// Icons fix4b: class-cablemancer, object-punch, slot-shoes, mark-rustbelt, slot-weapon (48x48 white silhouettes).
// Run: node tools/art_hd/icons_fix4b.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

class Bm {
  constructor() { this.g = Array.from({ length: 48 }, () => Array(48).fill(false)); }
  fill(f, v = true) { for (let y = 0; y < 48; y++) for (let x = 0; x < 48; x++) if (f(x + 0.5, y + 0.5)) this.g[y][x] = v; }
  rect(x0, y0, x1, y1, v = true) { this.fill((x, y) => x >= x0 && x <= x1 + 1 && y >= y0 && y <= y1 + 1, v); }
  disc(cx, cy, r, v = true, ri = 0) { this.fill((x, y) => { const d = Math.hypot(x - cx, y - cy); return d <= r && d >= ri; }, v); }
  ell(cx, cy, rx, ry, v = true) { this.fill((x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1, v); }
  line(x0, y0, x1, y1, th, v = true) { const n = 120; for (let i = 0; i <= n; i++) { const x = x0 + (x1 - x0) * i / n, y = y0 + (y1 - y0) * i / n; this.fill((a, b) => Math.hypot(a - x, b - y) <= th / 2, v); } }
  poly(pts, v = true) {
    this.fill((x, y) => { let ins = false; for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) { const [xi, yi] = pts[i], [xj, yj] = pts[j]; if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) ins = !ins; } return ins; }, v);
  }
}
const U = {};
const ui = (name, fn) => { const b = new Bm(); fn(b); U[name] = b.g; };

// Cable machine: one big pulley, one thick cable, one big D-handle.
ui('class-cablemancer', b => {
  b.disc(24, 11, 11);
  b.disc(24, 11, 7.2, false);
  b.line(24, 5, 24, 17, 3); b.line(18, 11, 30, 11, 3);
  b.disc(24, 11, 3.6);
  b.rect(22, 21, 25, 31);
  b.rect(8, 30, 39, 34);
  b.fill((x, y) => y >= 33 && ((x - 24) / 15.5) ** 2 + ((y - 33) / 12) ** 2 <= 1);
  b.fill((x, y) => y >= 34 && ((x - 24) / 9.5) ** 2 + ((y - 34) / 7) ** 2 <= 1, false);
});

// Boxing glove, side view, fist left, cuff right.
ui('object-punch', b => {
  b.ell(20, 21, 17, 16);
  b.rect(33, 12, 45, 34);
  b.rect(38, 12, 39, 34, false);
  b.rect(30, 13, 33, 33);
  b.ell(15, 34, 12.5, 8.5, false);
  b.ell(15, 34, 10.5, 6.5);
  b.rect(26, 28, 32, 40);
  b.rect(26, 38, 32, 40, false);
});

// High-top sneaker, side view, toe right. Laces, thick sole, toe cap.
ui('slot-shoes', b => {
  b.poly([[6, 4], [20, 4], [21, 18], [30, 21], [42, 27], [44, 36], [4, 36]]); // upper
  b.rect(2, 35, 45, 43);                               // thick sole
  b.rect(2, 35, 45, 35, false);                        // sole / upper gap
  b.line(7, 10, 17, 10, 2, false); b.line(7, 16, 17, 16, 2, false); b.line(8, 22, 20, 24, 2, false); // laces
  b.line(32, 28, 31, 35, 2, false);                    // toe cap seam
  b.rect(2, 43, 8, 44);                                // heel tab
});

// Rustbelt: spray-painted X with drips and overspray dots.
ui('mark-rustbelt', b => {
  b.line(8, 6, 38, 30, 8); b.line(39, 6, 9, 30, 8);
  b.disc(5, 3, 2); b.disc(43, 3, 2); b.disc(45, 11, 1.4);
  b.rect(10, 29, 13, 42); b.rect(9, 41, 14, 44);       // drip left, long
  b.rect(22, 25, 24, 34); b.rect(21, 33, 25, 36);      // drip middle, short
  b.rect(34, 29, 37, 39); b.rect(33, 38, 38, 41);      // drip right
  b.disc(25, 44, 2);                                   // paint drop
});

// Weapon slot: heavy barbell at an angle, big round plates with holes.
ui('slot-weapon', b => {
  b.line(4, 44, 44, 4, 5);
  for (const t of [0.22, 0.78]) { const x = 4 + 40 * t, y = 44 - 40 * t; b.disc(x, y, 9); b.disc(x, y, 2.8, false); }
});

// ---------- write ----------
for (const [n, g] of Object.entries(U)) {
  const buf = png(48, 48, (x, y) => g[y][x] ? [255, 255, 255, 255] : [0, 0, 0, 0]);
  for (const d of ['', '2.0x', '3.0x']) fs.writeFileSync(path.join(ROOT, 'assets', 'icons', d, n + '.png'), buf);
}

// ---------- preview ----------
const load = (n) => { const d = decode(fs.readFileSync(path.join(ROOT, 'assets', 'icons', n + '.png'))); return (x, y) => d.data[(y * d.w + x) * 4 + 3] > 127; };
const pairs = [['class-cablemancer', 'class-scrapper'], ['object-punch', 'gear'], ['slot-shoes', 'class-scrapper'], ['mark-rustbelt', 'close'], ['slot-weapon', 'bell']];
const rows = []; for (const [a, c] of pairs) rows.push([a, (x, y) => U[a][y][x]], [c, load(c)]);
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
fs.writeFileSync(path.join(ROOT, 'tools', 'art_hd', 'preview_icons_fix4b.png'), png(WW, HH, (x, y) => [...cv[y][x], 255]));
