// Tool icons (24x24, coloured) and 4 UI icons (48x48, white) redrawn. Shapes are painted with small
// primitives on a grid, then a 1-px ink outline is added so all 13 tool icons share one style:
// dark outline, 3 shades of one accent per tool, shared grey metal, light from the top left.
// Run: node tools/art_hd/icons_fix2.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png } from '../moodboard/png.mjs';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const hex = (s) => [1, 3, 5].map(i => parseInt(s.slice(i, i + 2), 16));
const INK = hex('#1a0b3b');
const METAL = { W: hex('#e4e8f2'), G: hex('#a2abc2'), D: hex('#626b88') };
const WOOD = { a: hex('#d99a55'), b: hex('#a8692f'), c: hex('#6d4120') };
const ACC = {
  orange: [hex('#ffc24a'), hex('#ff8a00'), hex('#b34d00')],
  sky: [hex('#8fe3ff'), hex('#00a8e8'), hex('#005e9e')],
  violet: [hex('#b78cff'), hex('#7b2cff'), hex('#4310a8')],
  pink: [hex('#ff9fcf'), hex('#ff2e93'), hex('#a3125c')],
};
const MET = [METAL.W, METAL.G, METAL.D];

class Cv {
  constructor(n, accent) { this.n = n; this.p = Array.from({ length: n }, () => Array(n).fill(null)); this.acc = accent; }
  col(c) {
    if (Array.isArray(c)) return c;
    if (c === 'h') return this.acc[0]; if (c === 'm') return this.acc[1]; if (c === 'l') return this.acc[2];
    if (c === 'k') return INK; if (c === 'w') return [255, 255, 255];
    return METAL[c] || WOOD[c];
  }
  set(x, y, c) { x = Math.round(x); y = Math.round(y); if (x >= 0 && y >= 0 && x < this.n && y < this.n) this.p[y][x] = c === null ? null : this.col(c); }
  rect(x0, y0, x1, y1, c) { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) this.set(x, y, c); }
  boxH(x0, y0, x1, y1, cs) { for (let x = x0; x <= x1; x++) this.rect(x, y0, x, y1, x === x0 ? cs[0] : x === x1 ? cs[2] : cs[1]); }
  boxV(x0, y0, x1, y1, cs) { for (let y = y0; y <= y1; y++) this.rect(x0, y, x1, y, y === y0 ? cs[0] : y === y1 ? cs[2] : cs[1]); }
  disc(cx, cy, rx, ry, cs) {
    for (let y = Math.floor(cy - ry - 1); y <= cy + ry + 1; y++) for (let x = Math.floor(cx - rx - 1); x <= cx + rx + 1; x++) {
      const dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy > 1) continue;
      const l = -dx * 0.6 - dy * 0.8;
      this.set(x, y, l > 0.38 ? cs[0] : l < -0.3 ? cs[2] : cs[1]);
    }
  }
  ring(cx, cy, ro, ri, cs, ryScale = 1) {
    for (let y = 0; y < this.n; y++) for (let x = 0; x < this.n; x++) {
      const d = Math.hypot(x - cx, (y - cy) / ryScale);
      if (d > ro || d < ri) continue;
      const l = (-(x - cx) * 0.6 - (y - cy) * 0.8) / ro;
      this.set(x, y, l > 0.35 ? cs[0] : l < -0.3 ? cs[2] : cs[1]);
    }
  }
  line(x0, y0, x1, y1, c, th = 1) {
    const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)) * 2 + 1;
    for (let i = 0; i <= n; i++) { const x = x0 + (x1 - x0) * i / n, y = y0 + (y1 - y0) * i / n; for (let a = 0; a < th; a++) for (let b = 0; b < th; b++) this.set(Math.round(x) + a, Math.round(y) + b, c); }
  }
  outline() {
    const q = this.p.map(r => r.slice());
    for (let y = 0; y < this.n; y++) for (let x = 0; x < this.n; x++) if (!this.p[y][x]) {
      for (const [a, b] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) if (this.p[y + b]?.[x + a]) { q[y][x] = INK; break; }
    }
    this.p = q;
  }
}

const T = {};
const tool = (name, accent, fn) => { const c = new Cv(24, ACC[accent]); fn(c); c.outline(); T[name] = c; };

tool('barbell', 'orange', c => {
  c.boxV(1, 10, 22, 13, ['W', 'G', 'D']);
  c.boxH(3, 2, 6, 21, ['h', 'm', 'l']); c.boxH(7, 5, 8, 18, ['m', 'm', 'l']);
  c.boxH(17, 2, 20, 21, ['h', 'm', 'l']); c.boxH(15, 5, 16, 18, ['m', 'm', 'l']);
  c.rect(4, 3, 4, 20, 'h'); c.rect(18, 3, 18, 20, 'h');
  c.rect(9, 10, 9, 13, 'D'); c.rect(14, 10, 14, 13, 'D');
});
tool('ezbar', 'orange', c => {
  const pts = [[3, 14], [6, 14], [8, 8], [12, 15], [16, 8], [18, 14], [21, 14]];
  for (let i = 0; i < pts.length - 1; i++) c.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], 'G', 2);
  c.rect(3, 14, 6, 14, 'W'); c.rect(18, 14, 21, 14, 'W');
  c.rect(3, 15, 6, 15, 'D'); c.rect(18, 15, 21, 15, 'D');
  c.boxH(1, 10, 3, 19, ['h', 'm', 'l']); c.boxH(20, 10, 22, 19, ['h', 'm', 'l']);
});
tool('dumbbell', 'sky', c => {
  c.boxV(8, 10, 15, 13, ['W', 'G', 'D']);
  const head = (x0, x1) => {
    c.boxH(x0, 5, x1, 18, ['h', 'm', 'l']);
    for (const y of [5, 18]) { c.set(x0, y, null); c.set(x1, y, null); }
    for (const y of [6, 17]) { c.set(x0, y, null); c.set(x1, y, null); }
    c.rect(x0 + 1, 7, x0 + 1, 16, 'h');
  };
  head(1, 7); head(16, 22);
  c.rect(8, 10, 8, 13, 'D'); c.rect(15, 10, 15, 13, 'D');
});
tool('kettlebell', 'violet', c => {
  c.ring(11.5, 8, 6.5, 3.6, MET, 1.1);
  for (let y = 8; y < 14; y++) for (let x = 0; x < 24; x++) if (Math.hypot(x - 11.5, (y - 8) / 1.1) > 6.5 || Math.hypot(x - 11.5, (y - 8) / 1.1) < 3.6) { /* keep clean */ }
  c.rect(5, 8, 6, 13, 'G'); c.rect(17, 8, 18, 13, 'D'); c.rect(6, 8, 6, 13, 'W');
  c.disc(11.5, 15, 9.5, 8, ACC.violet);
  c.rect(0, 22, 23, 23, null);
  c.rect(7, 20, 16, 20, 'l');
  c.rect(7, 11, 9, 12, 'h'); c.rect(5, 14, 6, 15, 'h');
  c.rect(8, 8, 15, 9, null);
});
tool('bodyweight', 'pink', c => {
  c.disc(12, 4.5, 3, 3, ACC.pink);
  c.line(8, 8, 3, 3, 'm', 2); c.line(15, 8, 20, 3, 'm', 2);
  c.boxV(8, 8, 15, 14, ['h', 'm', 'm']);
  c.line(9, 14, 6, 20, 'l', 3); c.line(13, 14, 16, 20, 'l', 3);
  c.rect(8, 12, 15, 14, 'l');
  c.rect(8, 8, 8, 11, 'h');
  c.rect(4, 21, 8, 22, 'm'); c.rect(14, 21, 18, 22, 'm');
});
tool('cable', 'sky', c => {
  c.rect(10, 0, 13, 3, 'D'); c.rect(10, 0, 10, 3, 'G');
  c.disc(12, 9, 7.5, 7.5, MET);
  c.ring(12, 9, 4.5, 2.2, ACC.sky);
  c.disc(12, 9, 1.6, 1.6, ACC.sky);
  c.rect(3, 9, 4, 16, 'W'); c.rect(4, 9, 4, 16, 'G');
  // D handle
  c.boxV(1, 17, 8, 22, ['h', 'm', 'l']);
  c.rect(2, 18, 7, 20, null); c.rect(3, 19, 6, 20, null);
  c.rect(3, 18, 6, 18, null);
  c.rect(2, 19, 7, 20, null);
  c.rect(2, 21, 7, 21, 'm'); c.rect(2, 20, 7, 20, 'm');
  c.rect(2, 18, 7, 19, null);
});
tool('machine', 'violet', c => {
  c.boxV(1, 20, 22, 22, ['G', 'D', 'D']);
  c.rect(15, 2, 20, 3, 'D'); c.rect(15, 2, 20, 2, 'G');
  for (let y = 5; y <= 17; y += 3) c.boxH(14, y, 21, y + 1, ['h', 'm', 'l']);
  c.rect(17, 4, 18, 19, 'G'); c.rect(18, 4, 18, 19, 'D');
  for (let y = 5; y <= 17; y += 3) { c.rect(17, y, 18, y + 1, 'k'); }
  c.boxH(2, 3, 4, 14, ['h', 'm', 'l']);
  c.boxV(2, 15, 10, 17, ['h', 'm', 'l']);
  c.rect(5, 8, 13, 8, 'G'); c.rect(5, 9, 13, 9, 'D');
  c.rect(3, 18, 4, 19, 'D'); c.rect(8, 18, 9, 19, 'D');
});
tool('smith', 'orange', c => {
  c.boxV(3, 0, 20, 2, ['G', 'D', 'D']);
  c.boxH(3, 0, 5, 21, ['W', 'G', 'D']); c.boxH(18, 0, 20, 21, ['W', 'G', 'D']);
  c.rect(1, 21, 7, 22, 'D'); c.rect(16, 21, 22, 22, 'D');
  for (const y of [4, 7, 15, 18]) { c.rect(4, y, 4, y, 'D'); c.rect(19, y, 19, y, 'D'); }
  c.boxV(0, 11, 23, 13, ['W', 'G', 'D']);
  c.boxH(2, 8, 6, 15, ['h', 'm', 'l']); c.boxH(17, 8, 21, 15, ['h', 'm', 'l']);
  c.rect(3, 9, 5, 9, 'h');
  c.rect(18, 9, 20, 9, 'h');
  c.rect(0, 10, 0, 14, 'k');
});
tool('bands', 'pink', c => {
  c.ring(12, 12, 10.5, 7, ACC.pink, 0.75);
  c.boxV(0, 9, 3, 15, ['W', 'G', 'D']); c.boxV(20, 9, 23, 15, ['W', 'G', 'D']);
  c.rect(4, 11, 5, 13, 'm'); c.rect(18, 11, 19, 13, 'm');
  c.rect(3, 10, 3, 14, 'D'); c.rect(20, 10, 20, 14, 'D');
});
tool('ball', 'sky', c => {
  c.disc(12, 12, 10.5, 10.5, ACC.sky);
  for (let i = 0; i <= 300; i++) { const t = i / 300 * 2 - 1; c.set(12 + t * 10.5, 12 + Math.sqrt(Math.max(0, 1 - t * t)) * 4.5, 'k'); }
  for (let i = 0; i <= 300; i++) { const t = i / 300 * 2 - 1; c.set(12 + Math.sqrt(Math.max(0, 1 - t * t)) * 4.5, 12 + t * 10.5, 'k'); }
  c.rect(6, 5, 8, 6, 'h'); c.rect(5, 7, 6, 8, 'h');
});
tool('rings', 'sky', c => {
  c.boxV(1, 0, 22, 1, ['G', 'D', 'D']);
  for (const x of [6, 17]) {
    c.rect(x, 2, x + 1, 8, 'W'); c.rect(x + 1, 2, x + 1, 8, 'G');
    c.rect(x - 1, 6, x + 2, 7, 'D');
    c.ring(x + 0.5, 15.5, 6.2, 3.4, ACC.sky);
  }
});
tool('hammer', 'violet', c => {
  c.line(3, 21, 14, 10, 'b', 3);
  c.line(3, 22, 14, 11, 'c', 1);
  c.line(3, 20, 13, 10, 'a', 1);
  c.rect(2, 20, 4, 22, 'c');
  const s2 = Math.SQRT1_2;
  for (let y = 0; y < 24; y++) for (let x = 0; x < 24; x++) {
    const dx = x - 16.5, dy = y - 7.5, t = (dx - dy) * s2, s = (dx + dy) * s2;
    if (Math.abs(t) <= 3.4 && Math.abs(s) <= 7.2) c.set(x, y, t > 1.4 ? 'h' : t < -1.8 ? 'l' : 'm');
  }
});
tool('towel', 'pink', c => {
  c.boxV(3, 3, 21, 8, ['h', 'm', 'm']);
  c.boxV(1, 9, 20, 14, ['h', 'm', 'l']);
  c.boxV(1, 15, 20, 20, ['m', 'm', 'l']);
  c.rect(1, 14, 20, 14, 'l');
  for (const x of [5, 6, 15, 16]) { c.rect(x, 4, x, 7, 'w'); c.rect(x - 2, 10, x - 2, 13, 'w'); c.rect(x - 2, 16, x - 2, 19, 'w'); }
  for (let y = 9; y <= 20; y += 2) c.rect(21, y, 22, y, 'h');
  c.rect(21, 3, 21, 8, 'l');
});

// ---------- UI icons (48x48 white silhouettes) ----------
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

ui('class-cablemancer', b => {
  b.rect(26, 0, 31, 8);
  b.disc(29, 18, 13);
  b.disc(29, 18, 9, false);
  b.disc(29, 18, 4.5);
  b.rect(16, 18, 19, 31);
  b.fill((x, y) => ((x - 17.5) / 12) ** 2 + ((y - 39) / 8) ** 2 <= 1 && y >= 30);
  b.fill((x, y) => ((x - 17.5) / 7) ** 2 + ((y - 39) / 3.8) ** 2 <= 1, false);
});
ui('ember', b => {
  b.poly([[7, 40], [11, 31], [19, 26], [29, 27], [38, 31], [42, 40], [38, 46], [11, 46]]);
  b.line(24, 31, 20, 26, 1.6, false); b.line(24, 31, 33, 29, 1.6, false);
  b.poly([[24, 33], [30, 38], [24, 43], [18, 38]], false);
  const spark = (cx, cy, r) => { b.poly([[cx, cy - r], [cx + r * 0.4, cy], [cx, cy + r], [cx - r * 0.4, cy]]); b.poly([[cx - r, cy], [cx, cy - r * 0.4], [cx + r, cy], [cx, cy + r * 0.4]]); };
  spark(13, 16, 6); spark(27, 8, 5.5); spark(37, 18, 4);
});
ui('fire', b => {
  const tongue = (cx, tipY, baseY, half, lean) => b.fill((x, y) => {
    if (y < tipY || y > baseY) return false;
    const t = (y - tipY) / (baseY - tipY);
    const w = half * Math.sin(Math.min(1, t * 1.15) * Math.PI / 2);
    return Math.abs(x - (cx + lean * (1 - t) * (1 - t))) <= w;
  });
  tongue(24, 1, 31, 9.5, 4); tongue(13, 11, 31, 6.5, -3); tongue(35, 13, 31, 6, 3);
  b.fill((x, y) => { const t = (y - 19) / 12; return y >= 19 && y <= 30 && Math.abs(x - 24) <= 3.6 * Math.sin(Math.min(1, t * 1.1) * Math.PI / 2); }, false);
  b.line(4, 35, 44, 46, 7);
  b.line(4, 46, 44, 35, 9.5, false); b.line(4, 46, 44, 35, 7);
  for (const [x, y] of [[4, 35.5], [44, 45.5], [4, 45.5], [44, 35.5]]) b.disc(x, y, 1.2, false);
  b.rect(0, 47, 47, 47, false);
});
ui('flame', b => {
  const sh = (tipY, baseY, half, lean, ctr) => (x, y) => {
    if (y < tipY || y > baseY) return false;
    const t = (y - tipY) / (baseY - tipY);
    return Math.abs(x - (ctr + lean * (1 - t) ** 2.2)) <= half * Math.max(0, t < 0.78 ? Math.sin(Math.pow(t, 0.8) * Math.PI / 2) : Math.sqrt(Math.max(0, 1 - ((t - 0.78) / 0.22) ** 2)) * 0.99);
  };
  b.fill(sh(1, 46, 16, 8, 23));
  b.fill(sh(27, 41, 7, 2, 24), false);
});
ui('object-punch', b => {
  b.ell(27, 17, 16, 14);
  b.rect(11, 19, 42, 31);
  b.rect(14, 36, 38, 46);
  b.rect(8, 33, 45, 34, false);
  b.rect(14, 40, 38, 41, false);
  for (const x of [19, 26, 33]) b.rect(x, 36, x, 38, false);
  // thumb lobe on the left: gap arc
  for (let i = 0; i <= 80; i++) { const a = Math.PI * (1.0 + 1.25 * i / 80); b.disc(20 + 9 * Math.cos(a), 26 + 5.5 * Math.sin(a), 0.95, false); }
  // finger fold on the right
  for (let i = 0; i <= 60; i++) { const a = Math.PI * (-0.5 + 1.0 * i / 60); b.disc(43 + 11 * Math.cos(a) * -1 * 0 + 0 - 0, 0, 0, false); }
  b.line(43, 14, 31, 14, 1.8, false); b.line(31, 14, 28, 20, 1.8, false); b.line(43, 22, 33, 22, 1.8, false);
});

// ---------- write ----------
for (const [n, c] of Object.entries(T)) {
  fs.writeFileSync(path.join(ROOT, 'assets', 'icons', 'tools', n + '.png'), png(24, 24, (x, y) => { const p = c.p[y][x]; return p ? [...p, 255] : [0, 0, 0, 0]; }));
}
for (const [n, g] of Object.entries(U)) {
  const buf = png(48, 48, (x, y) => g[y][x] ? [255, 255, 255, 255] : [0, 0, 0, 0]);
  for (const d of ['', '2.0x', '3.0x']) fs.writeFileSync(path.join(ROOT, 'assets', 'icons', d, n + '.png'), buf);
}

// ---------- preview ----------
const WHITE = [255, 255, 255], LIME = [190, 242, 60], PURP = [38, 20, 72], GREY = [60, 60, 60];
const tn = Object.keys(T), un = Object.keys(U);
const PAD = 8, S = 96 + PAD, perRow = 7, rA = Math.ceil(tn.length / perRow);
const y1 = rA * 2 * S + 8, y2 = y1 + 60;
const WW = PAD + 5 * 200 + 8, HH = y2 + 192 + 8 + 56;
const cvs = Array.from({ length: HH }, () => Array.from({ length: WW }, () => GREY));
const box = (ox, oy, w, h, bg) => { for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) cvs[oy + y][ox + x] = bg; };
const blit = (ox, oy, n, k, f) => { for (let y = 0; y < n * k; y++) for (let x = 0; x < n * k; x++) { const p = f(Math.floor(x / k), Math.floor(y / k)); if (p) cvs[oy + y][ox + x] = p; } };
tn.forEach((n, i) => {
  const c = T[n], ox = PAD + (i % perRow) * S, oy = PAD + Math.floor(i / perRow) * 2 * S;
  box(ox, oy, 96, 96, WHITE); blit(ox, oy, 24, 4, (x, y) => c.p[y][x]);
  box(ox, oy + S, 96, 96, LIME); blit(ox, oy + S, 24, 4, (x, y) => c.p[y][x]);
});
tn.forEach((n, i) => { const c = T[n], ox = PAD + i * 30; box(ox, y1, 26, 26, WHITE); blit(ox + 1, y1 + 1, 24, 1, (x, y) => c.p[y][x]); });
un.forEach((n, i) => {
  const g = U[n], ox = PAD + i * 200;
  box(ox, y2, 192, 192, PURP);
  blit(ox, y2, 48, 4, (x, y) => g[y][x] ? WHITE : null);
  box(ox, y2 + 196, 48, 48, PURP);
  for (let y = 0; y < 24; y++) for (let x = 0; x < 24; x++) { let s = 0; for (let j = 0; j < 2; j++) for (let k = 0; k < 2; k++) s += g[y * 2 + j][x * 2 + k] ? 1 : 0; const v = s / 4; const px = PURP.map(p => Math.round(p + (255 - p) * v)); for (let a = 0; a < 2; a++) for (let b2 = 0; b2 < 2; b2++) cvs[y2 + 196 + y * 2 + a][ox + x * 2 + b2] = px; }
});
fs.writeFileSync(path.join(ROOT, 'tools', 'art_hd', 'preview_icons_fix2.png'), png(WW, HH, (x, y) => [...cvs[y][x], 255]));
console.log('wrote', tn.length, 'tool icons,', un.length, 'UI icons');
