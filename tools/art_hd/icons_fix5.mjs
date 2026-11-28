// Icons fix5: slot-weapon (sword), mark-rustbelt (spray can). 48x48 white silhouettes.
// Run: node tools/art_hd/icons_fix5.mjs
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
  line(x0, y0, x1, y1, th, v = true) { const n = 120; for (let i = 0; i <= n; i++) { const x = x0 + (x1 - x0) * i / n, y = y0 + (y1 - y0) * i / n; this.fill((a, b) => Math.hypot(a - x, b - y) <= th / 2, v); } }
}
const U = {};
const ui = (name, fn) => { const b = new Bm(); fn(b); U[name] = b.g; };

// Sword on the diagonal. u = along sword (hilt to tip), v = across.
ui('slot-weapon', b => {
  const S2 = Math.SQRT2;
  const uv = (x, y) => [(x - y + 34) / S2, (x + y - 48) / S2];
  b.fill((x, y) => { const [u, v] = uv(x, y); const a = Math.abs(v);
    if (Math.hypot(u - 3.5, v) <= 3.6) return true;
    if (u >= 6 && u <= 16 && a <= 2.3) return true;
    if (u >= 16 && u <= 19.5 && a <= 10.5) return true;
    if (u >= 19.5 && u <= 40 && a <= 3.2) return true;
    if (u > 40 && u <= 48 && a <= 3.2 * (48 - u) / 8) return true;
    return false; });
  b.fill((x, y) => { const [u, v] = uv(x, y); const a = Math.abs(v);
    if (u >= 22 && u <= 41 && a <= 0.5 && u >= 24) return true;
    if (a <= 3 && ((u >= 8.6 && u <= 9.9) || (u >= 12.1 && u <= 13.4))) return true;
    return false; }, false);
});

// Spray can with mist.
ui('mark-rustbelt', b => {
  b.rect(7, 16, 26, 44);
  b.rect(10, 11, 23, 15);
  b.rect(15, 3, 20, 10); b.rect(13, 3, 22, 5);
  b.rect(7, 19, 26, 19, false);
  b.rect(9, 26, 24, 40, false);
  b.line(13, 30, 20, 36, 2.4); b.line(20, 30, 13, 36, 2.4);
  for (const [x, y, s] of [[26, 3, 3], [32, 1, 2], [32, 7, 3], [38, 3, 2], [39, 9, 3], [44, 6, 2]]) b.rect(x, y, x + s - 1, y + s - 1);
});

for (const [n, g] of Object.entries(U)) {
  const buf = png(48, 48, (x, y) => g[y][x] ? [255, 255, 255, 255] : [0, 0, 0, 0]);
  for (const d of ['', '2.0x', '3.0x']) fs.writeFileSync(path.join(ROOT, 'assets', 'icons', d, n + '.png'), buf);
}

const load = (n) => { const d = decode(fs.readFileSync(path.join(ROOT, 'assets', 'icons', n + '.png'))); return (x, y) => d.data[(y * d.w + x) * 4 + 3] > 127; };
const rows = [];
for (const a of ['slot-weapon', 'mark-rustbelt']) rows.push([a, (x, y) => U[a][y][x]]);
rows.push(['close', load('close')], ['bell', load('bell')]);
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
fs.writeFileSync(path.join(ROOT, 'tools', 'art_hd', 'preview_icons_fix5.png'), png(WW, HH, (x, y) => [...cv[y][x], 255]));
