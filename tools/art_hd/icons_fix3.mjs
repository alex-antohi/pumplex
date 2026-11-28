// UI icons redrawn after a blind test: class-cablemancer, object-punch, ember (48x48 white silhouettes).
// Run: node tools/art_hd/icons_fix3.mjs
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
  // rotate the bitmap by deg (clockwise) around (cx, cy), nearest sampling
  rot(deg, cx, cy) {
    const a = deg * Math.PI / 180, c = Math.cos(a), s = Math.sin(a), out = Array.from({ length: 48 }, () => Array(48).fill(false));
    for (let y = 0; y < 48; y++) for (let x = 0; x < 48; x++) {
      const dx = x + 0.5 - cx, dy = y + 0.5 - cy;
      const sx = Math.floor(cx + dx * c + dy * s), sy = Math.floor(cy - dx * s + dy * c);
      out[y][x] = !!this.g[sy]?.[sx];
    }
    this.g = out;
  }
}
const U = {};
const ui = (name, fn) => { const b = new Bm(); fn(b); U[name] = b.g; };
const spark = (b, cx, cy, r, v = true) => { b.poly([[cx, cy - r], [cx + r * 0.6, cy], [cx, cy + r], [cx - r * 0.6, cy]], v); };

// Cable machine, side view: upright frame, pulley on an arm, cable down to a D-handle.
ui('class-cablemancer', b => {
  b.rect(5, 4, 11, 44);            // upright
  b.rect(3, 41, 22, 44);           // base
  b.rect(5, 4, 22, 9);             // top arm
  b.disc(25, 12, 8.5);             // pulley wheel
  b.disc(25, 12, 5.5, false);      // hollow rim
  b.disc(25, 12, 2.4);             // hub
  b.line(25, 7, 25, 17, 2); b.line(20, 12, 30, 12, 2); // spokes
  b.rect(32, 12, 33, 23);          // cable drops from the wheel rim
  b.line(32.5, 22, 28, 33, 2);     // V attachment left
  b.line(32.5, 22, 38, 33, 2);     // V attachment right
  b.rect(24, 33, 42, 38);          // grip bar
});

// Boxing glove, punching up and to the right, with speed lines.
ui('object-punch', b => {
  b.ell(32, 21, 13, 12);                         // fist mass
  b.ell(27, 34, 9.5, 6);                         // thumb bump
  b.fill((x, y) => { const d = ((x - 27) / 9.5) ** 2 + ((y - 34) / 6) ** 2; const d2 = ((x - 27) / 11.9) ** 2 + ((y - 34) / 8.4) ** 2; return d > 1 && d2 <= 1 && y < 34; }, false); // gap above the thumb
  b.rect(13, 13, 21, 31);                        // cuff
  b.rect(20, 15, 24, 29);                        // wrist join
  b.rect(16, 14, 17, 30, false);                 // lace band gaps
  b.rect(19, 14, 19, 30, false);
  b.rect(1, 17, 7, 18); b.rect(0, 23, 9, 24); b.rect(2, 29, 7, 30); // speed lines
  b.rot(-18, 24, 24);
});

// Ember: faceted coal, a flame tongue and rising sparks.
ui('ember', b => {
  const coal = () => {
    b.poly([[8, 43], [5, 34], [12, 27], [24, 24], [36, 27], [43, 34], [40, 43]]);
    b.line(24, 24, 20, 43, 2, false); b.line(21, 34, 38, 31, 2, false);
  };
  // flame tongue
  b.fill((x, y) => { const t = (y - 5) / 20; if (t < 0 || t > 1) return false; const w = 7.5 * Math.sin(Math.min(1, t * 1.1) * Math.PI / 2); return Math.abs(x - (24 + 3 * (1 - t) * 0.6)) <= w; });
  b.fill((x, y) => { const t = (y - 14) / 10; if (t < 0 || t > 1) return false; return Math.abs(x - 24.5) <= 2.6 * Math.sin(Math.min(1, t * 1.1) * Math.PI / 2); }, false);
  b.rect(10, 21, 40, 22, false); // gap between flame and coal
  coal();
  spark(b, 10, 15, 4); spark(b, 38, 12, 3.4); spark(b, 40, 22, 2.4); spark(b, 14, 5, 2.4);
});

// ---------- write ----------
for (const [n, g] of Object.entries(U)) {
  const buf = png(48, 48, (x, y) => g[y][x] ? [255, 255, 255, 255] : [0, 0, 0, 0]);
  for (const d of ['', '2.0x', '3.0x']) fs.writeFileSync(path.join(ROOT, 'assets', 'icons', d, n + '.png'), buf);
}

// ---------- preview ----------
const load = (n) => { const d = decode(fs.readFileSync(path.join(ROOT, 'assets', 'icons', n + '.png'))); return (x, y) => d.data[(y * d.w + x) * 4 + 3] > 127; };
const rows = [...Object.keys(U).map(n => [n, (x, y) => U[n][y][x]]), ...['fire', 'flame', 'drop', 'gear'].map(n => [n, load(n)])];
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
fs.writeFileSync(path.join(ROOT, 'tools', 'art_hd', 'preview_icons_fix3.png'), png(WW, HH, (x, y) => [...cv[y][x], 255]));
