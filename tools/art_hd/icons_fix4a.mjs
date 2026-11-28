// UI icons redrawn after a blind test: arm, crown, mark-arcade, slot-head (48x48 white silhouettes).
// Run: node tools/art_hd/icons_fix4a.mjs
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
const star = (cx, cy, R, r) => { const p = []; for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, q = i % 2 ? r : R; p.push([cx + q * Math.cos(a), cy + q * Math.sin(a)]); } return p; };

// Flexed arm, side view: upper arm flat, forearm up, fist on top, big biceps bulge.
ui('arm', b => {
  b.rect(3, 33, 42, 44);            // upper arm
  b.poly([[33, 14], [43, 14], [45, 44], [29, 44], [29, 32]]); // forearm, wider at the elbow
  b.ell(15, 26, 12.5, 10.5);        // big biceps hump
  b.ell(38, 8.5, 10, 8.5);          // round fist
  b.rect(33, 15, 43, 15, false);    // wrist cut
  b.rect(31, 8, 37, 9, false);      // finger fold cut
  // 2 px peak line inside the hump
  b.fill((x, y) => { const d = Math.sqrt(((x - 13) / 8.5) ** 2 + ((y - 29) / 8) ** 2); return Math.abs(d - 1) * 8 <= 1 && x > 12 && y < 31; }, false);
});

// Royal crown: three tall spikes with gem balls, band with gem cut-outs.
ui('crown', b => {
  b.poly([[6, 38], [6, 17], [15, 27], [24, 12], [33, 27], [42, 17], [42, 38]]);
  b.disc(6.5, 14, 3.6); b.disc(24, 8.5, 4.2); b.disc(41.5, 14, 3.6);
  b.rect(5, 35, 42, 43);
  b.rect(5, 34, 42, 34, false);     // seam between spikes and band
  b.disc(13, 39, 2.3, false); b.disc(24, 39, 2.3, false); b.disc(35, 39, 2.3, false);
  b.disc(15.5, 22, 1.8, false); b.disc(32.5, 22, 1.8, false);
});

// Arcade token: round coin with rim and a star cut-out, notched edge.
ui('mark-arcade', b => {
  b.disc(24, 24, 21);
  b.disc(24, 24, 17.5, false, 15.5);              // rim groove
  b.poly(star(24, 25, 12, 5.2), false);           // star cut-out
  for (let i = 0; i < 12; i++) { const a = i * Math.PI / 6 + Math.PI / 12; b.disc(24 + 20 * Math.cos(a), 24 + 20 * Math.sin(a), 1.3, false); }
});

// Helmet, front view: crest fin, dome, visor slit, cheek guards, vents.
ui('slot-head', b => {
  b.poly([[24, 2], [29, 10], [19, 10]]);                                             // crest fin
  b.poly([[7, 41], [7, 22], [11, 13], [24, 9], [37, 13], [41, 22], [41, 41], [33, 45], [29, 37], [19, 37], [15, 45]]);
  b.poly([[11, 19], [37, 19], [35, 27], [28, 26], [24, 28], [20, 26], [13, 27]], false); // visor slit
  b.rect(21, 31, 21, 36, false); b.rect(24, 31, 24, 36, false); b.rect(27, 31, 27, 36, false); // vents
});

// ---------- write ----------
for (const [n, g] of Object.entries(U)) {
  const buf = png(48, 48, (x, y) => g[y][x] ? [255, 255, 255, 255] : [0, 0, 0, 0]);
  for (const d of ['', '2.0x', '3.0x']) fs.writeFileSync(path.join(ROOT, 'assets', 'icons', d, n + '.png'), buf);
}

// ---------- preview ----------
const load = (n) => { const d = decode(fs.readFileSync(path.join(ROOT, 'assets', 'icons', n + '.png'))); return (x, y) => d.data[(y * d.w + x) * 4 + 3] > 127; };
const rows = [...Object.keys(U).map(n => [n, (x, y) => U[n][y][x]]), ...['area-gainsgard', 'class-scrapper', 'gear'].map(n => [n, load(n)])];
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
fs.writeFileSync(path.join(ROOT, 'tools', 'art_hd', 'preview_icons_fix4a.png'), png(WW, HH, (x, y) => [...cv[y][x], 255]));
