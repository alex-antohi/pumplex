// Tiny pixel-art helpers for the HD (2x) art scripts. No packages.
import fs from 'node:fs';
import { png, decode } from '../moodboard/png.mjs';

export const hx = h => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
export const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const BAY = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
export const bay = (x, y) => (BAY[y & 3][x & 3] + 0.5) / 16;
export function rnd(x, y, s = 0) {
  let h = (x * 374761393 + y * 668265263 + s * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177); h ^= h >>> 16;
  return ((h >>> 0) % 100000) / 100000;
}
export const mix = (a, b, t) => [0, 1, 2].map(i => Math.round(a[i] + (b[i] - a[i]) * t));

export class Img {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
  in(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h; }
  px(x, y, c, a = 255) {
    x = Math.round(x); y = Math.round(y); if (!this.in(x, y)) return;
    if (typeof c === 'string') c = hx(c);
    this.d.set([c[0], c[1], c[2], a], (y * this.w + x) * 4);
  }
  get(x, y) { if (!this.in(x, y)) return [0, 0, 0, 0]; const o = (y * this.w + x) * 4; return [this.d[o], this.d[o + 1], this.d[o + 2], this.d[o + 3]]; }
  has(x, y) { return this.in(x, y) && this.d[(y * this.w + x) * 4 + 3] > 0; }
  // blend a colour over an existing pixel
  tint(x, y, c, t) { if (!this.has(x, y)) return; if (typeof c === 'string') c = hx(c); const g = this.get(x, y); this.px(x, y, mix(g, c, t), g[3]); }
  rect(x, y, w, h, c, a = 255) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.px(x + i, y + j, c, a); }
  line(x0, y0, x1, y1, c, a = 255) {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1; let e = dx + dy;
    for (;;) { this.px(x0, y0, c, a); if (x0 === x1 && y0 === y1) break; const e2 = 2 * e; if (e2 >= dy) { e += dy; x0 += sx; } if (e2 <= dx) { e += dx; y0 += sy; } }
  }
  over(o, ox = 0, oy = 0) {
    for (let y = 0; y < o.h; y++) for (let x = 0; x < o.w; x++) {
      const s = (y * o.w + x) * 4, a = o.d[s + 3]; if (!a) continue;
      const X = x + ox, Y = y + oy; if (!this.in(X, Y)) continue;
      const t = (Y * this.w + X) * 4;
      if (a === 255 || !this.d[t + 3]) { this.d[t] = o.d[s]; this.d[t + 1] = o.d[s + 1]; this.d[t + 2] = o.d[s + 2]; this.d[t + 3] = a; }
      else { const k = a / 255; for (let i = 0; i < 3; i++) this.d[t + i] = Math.round(this.d[t + i] * (1 - k) + o.d[s + i] * k); this.d[t + 3] = Math.max(this.d[t + 3], a); }
    }
  }
  // dark outline on the inside edge of the silhouette (keeps the silhouette size)
  outline(c, oob = false) {
    const a = new Uint8Array(this.w * this.h); for (let i = 0; i < a.length; i++) a[i] = this.d[i * 4 + 3] > 0 ? 1 : 0;
    const at = (x, y) => (x < 0 || y < 0 || x >= this.w || y >= this.h) ? (oob ? 1 : 0) : a[y * this.w + x];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) if (a[y * this.w + x] && (!at(x - 1, y) || !at(x + 1, y) || !at(x, y - 1) || !at(x, y + 1))) this.px(x, y, c);
  }
  mulAlpha(k) { for (let i = 0; i < this.w * this.h; i++) this.d[i * 4 + 3] = Math.round(this.d[i * 4 + 3] * k); }
  save(path) { fs.writeFileSync(path, png(this.w, this.h, (x, y) => { const o = (y * this.w + x) * 4; return [this.d[o], this.d[o + 1], this.d[o + 2], this.d[o + 3]]; })); }
  static load(path) { const i = decode(fs.readFileSync(path)); const m = new Img(i.w, i.h); m.d.set(i.data); return m; }
}

// pick a colour from a ramp (dark -> light) with t in 0..1, ordered dither between steps
export function rp(ramp, t, x, y, dw = 0.7) {
  const n = ramp.length; const f = clamp(t) * (n - 1); let i = Math.floor(f); if (i >= n - 1) i = n - 2; if (n < 2) return ramp[0];
  const fr = f - i; const k = clamp((fr - 0.5) / dw + 0.5);
  return ramp[i + (k > bay(x, y) ? 1 : 0)];
}

// 5x7 font
const F = {
  P: ['1111.', '1...1', '1...1', '1111.', '1....', '1....', '1....'],
  U: ['1...1', '1...1', '1...1', '1...1', '1...1', '1...1', '.111.'],
  N: ['1...1', '11..1', '1.1.1', '1.1.1', '1..11', '1...1', '1...1'],
  C: ['.111.', '1...1', '1....', '1....', '1....', '1...1', '.111.'],
  H: ['1...1', '1...1', '1...1', '11111', '1...1', '1...1', '1...1'],
  O: ['.111.', '1...1', '1...1', '1...1', '1...1', '1...1', '.111.'],
  T: ['11111', '..1..', '..1..', '..1..', '..1..', '..1..', '..1..'],
  R: ['1111.', '1...1', '1...1', '1111.', '1.1..', '1..1.', '1...1'],
  '-': ['.....', '.....', '.....', '.111.', '.....', '.....', '.....'],
};
export function textW(s, k) { return s.length * 5 * k + (s.length - 1) * k; }
export function text(im, s, x, y, k, col) {
  let cx = x;
  for (const ch of s) {
    const g = F[ch]; if (g) for (let j = 0; j < 7; j++) for (let i = 0; i < 5; i++) if (g[j][i] === '1') im.rect(cx + i * k, y + j * k, k, k, col);
    cx += 6 * k;
  }
}

// shaded sphere/ellipse; returns nothing, paints into im. opts: bias, spec, rim, bounce
export function sphere(im, cx, cy, rx, ry, ramp, o = {}) {
  const L = [-0.55, -0.6, 0.58]; const ln = Math.hypot(...L); L[0] /= ln; L[1] /= ln; L[2] /= ln;
  const { bias = 0, spec = true, rim = 0.5 } = o;
  for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
    const u = (x + 0.5 - cx) / rx, v = (y + 0.5 - cy) / ry, r2 = u * u + v * v; if (r2 > 1) continue;
    const z = Math.sqrt(1 - r2); let t = (u * L[0] + v * L[1] + z * L[2]) * 0.85 + 0.12 + bias;
    if (r2 > 0.72) t -= (r2 - 0.72) * rim * 2.2;
    if (u > 0.25 && v > 0.15 && r2 > 0.6) t += (r2 - 0.6) * 0.9; // floor bounce light
    im.px(x, y, rp(ramp, t, x, y, 0.55));
  }
  if (spec) {
    const sx = cx - rx * 0.4, sy = cy - ry * 0.45;
    for (let y = Math.floor(sy - ry * 0.3); y <= Math.ceil(sy + ry * 0.3); y++) for (let x = Math.floor(sx - rx * 0.3); x <= Math.ceil(sx + rx * 0.3); x++) {
      const a = (x + 0.5 - sx) / (rx * 0.2), b = (y + 0.5 - sy) / (ry * 0.14); const d = a * a + b * b;
      if (d < 1 && im.has(x, y)) im.px(x, y, ramp[ramp.length - 1]);
      else if (d < 2.4 && im.has(x, y) && (x + y) % 2 === 0) im.px(x, y, ramp[ramp.length - 2]);
    }
  }
}

// triangle fill: calls fn(x,y)
export function tri(ax, ay, bx, by, cx, cy, fn) {
  const minx = Math.floor(Math.min(ax, bx, cx)), maxx = Math.ceil(Math.max(ax, bx, cx));
  const miny = Math.floor(Math.min(ay, by, cy)), maxy = Math.ceil(Math.max(ay, by, cy));
  const d = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay); if (!d) return;
  for (let y = miny; y <= maxy; y++) for (let x = minx; x <= maxx; x++) {
    const px = x + 0.5, py = y + 0.5;
    const w1 = ((px - ax) * (cy - ay) - (cx - ax) * (py - ay)) / d, w2 = ((bx - ax) * (py - ay) - (px - ax) * (by - ay)) / d;
    if (w1 >= 0 && w2 >= 0 && w1 + w2 <= 1) fn(x, y);
  }
}
