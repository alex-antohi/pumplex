// HD (2x) hand-built redo of background.png and floor.png for riptide, gainsgard, rustbelt.
// Run: node tools/art_hd/areas_a_fix.mjs   (node only, no packages)
// Writes assets/areas/<id>/background.png (350x300) and floor.png (350x72)
// and tools/art_hd/preview_areas_a_fix.png (old 1x scaled 2x | new).
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { png, decode } from '../moodboard/png.mjs';

// ---------- toolkit ----------
const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const H = s => s.split(/\s+/).filter(Boolean).map(hex);
const B4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const bay = (x, y) => (B4[y & 3][x & 3] + 0.5) / 16;
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const rgb = c => c.map(v => Math.round(clamp(v, 0, 255)));
function rng(seed) { let s = seed >>> 0 || 1; return () => (s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296; }
const INK = hex('#0b0414');

class Img {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); for (let i = 3; i < w * h * 4; i += 4) this.d[i] = 255; }
  set(x, y, c) { x = Math.round(x); y = Math.round(y); if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const o = (y * this.w + x) * 4; this.d[o] = Math.round(c[0]); this.d[o + 1] = Math.round(c[1]); this.d[o + 2] = Math.round(c[2]); }
  get(x, y) { x = Math.round(x); y = Math.round(y); if (x < 0 || y < 0 || x >= this.w || y >= this.h) return [0, 0, 0]; const o = (y * this.w + x) * 4; return [this.d[o], this.d[o + 1], this.d[o + 2]]; }
  rect(x, y, w, h, c) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, c); }
  hl(x0, x1, y, c) { for (let x = x0; x <= x1; x++) this.set(x, y, c); }
  vl(x, y0, y1, c) { for (let y = y0; y <= y1; y++) this.set(x, y, c); }
  line(x0, y0, x1, y1, c, t = 1) {
    x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
    const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1; let e = dx + dy;
    for (;;) {
      if (t <= 1) this.set(x0, y0, c); else this.rect(x0 - (t >> 1), y0 - (t >> 1), t, t, c);
      if (x0 === x1 && y0 === y1) break; const e2 = 2 * e; if (e2 >= dy) { e += dy; x0 += sx; } if (e2 <= dx) { e += dx; y0 += sy; }
    }
  }
  // fill ellipse; fn(x, y, q, dx, dy) -> colour or null (q = normalised radius 0..1)
  ell(cx, cy, rx, ry, fn) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry, q = Math.hypot(dx, dy); if (q > 1) continue;
      const c = fn(x, y, q, dx, dy); if (c) this.set(x, y, c);
    }
  }
  // scanline polygon fill; fn(x, y) -> colour or null
  poly(pts, fn) {
    let y0 = Infinity, y1 = -Infinity; for (const p of pts) { y0 = Math.min(y0, p[1]); y1 = Math.max(y1, p[1]); }
    for (let y = Math.floor(y0); y <= Math.ceil(y1); y++) {
      const yy = y + 0.5, xs = [];
      for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; if ((a[1] <= yy && b[1] > yy) || (b[1] <= yy && a[1] > yy)) xs.push(a[0] + (yy - a[1]) / (b[1] - a[1]) * (b[0] - a[0])); }
      xs.sort((p, q) => p - q);
      for (let k = 0; k + 1 < xs.length; k += 2) for (let x = Math.round(xs[k]); x < Math.round(xs[k + 1]); x++) { const c = fn(x, y); if (c) this.set(x, y, c); }
    }
  }
  // colour ramp with ordered dither; v 0..1 across stops; sharp>1 narrows the dither zone
  ramp(stops, v, x, y, sharp = 2) {
    const n = stops.length, pos = clamp(v) * (n - 1), i = Math.min(n - 2, Math.floor(pos)), f = pos - i;
    const f2 = clamp((f - 0.5) * sharp + 0.5); return stops[i + (f2 > bay(x, y) ? 1 : 0)];
  }
  // vertical gradient over a rect
  vgrad(x, y, w, h, stops, sharp = 2) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, this.ramp(stops, j / Math.max(1, h - 1), x + i, y + j, sharp)); }
  // mix a tint over existing pixels with k dithered levels: amt 0..1
  tint(x, y, amt, col, maxMix = 1, levels = 4) {
    const q = clamp(amt) * levels, i = Math.floor(q), f = q - i, lv = i + (f > bay(x, y) ? 1 : 0); if (lv <= 0) return;
    this.set(x, y, mix(this.get(x, y), col, clamp(lv / levels * maxMix)));
  }
  // 1px outline around pixels where mask[y*w+x] is set (only on unmasked pixels)
  outline(mask, col, diag = false) {
    const out = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (mask[y * this.w + x]) continue; let hit = false;
      for (const [dx, dy] of diag ? [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]] : [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const xx = x + dx, yy = y + dy; if (xx >= 0 && yy >= 0 && xx < this.w && yy < this.h && mask[yy * this.w + xx]) { hit = true; break; } }
      if (hit) out.push([x, y]);
    }
    for (const [x, y] of out) this.set(x, y, col);
  }
}
const bez3 = (p0, p1, p2, p3, n) => Array.from({ length: n + 1 }, (_, i) => { const t = i / n, u = 1 - t; return [u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0], u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]]; });
const bez2 = (p0, p1, p2, n) => Array.from({ length: n + 1 }, (_, i) => { const t = i / n, u = 1 - t; return [u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0], u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]]; });
const hash = (a, b = 0) => { let h = Math.imul(a + 374761393, 668265263) ^ Math.imul(b + 1274126177, 2246822519); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };

// ============================================================
// RIPTIDE  (night beach)
// ============================================================
function riptideBackground() {
  const W = 350, Hh = 300, im = new Img(W, Hh), r = rng(7);
  const HOR = 124, SHORE = 212;
  // sky
  const sky = H('#090315 #0f0620 #170a33 #220f45 #301859 #422673 #583a8c');
  im.vgrad(0, 0, W, HOR + 2, sky, 2.4);
  // moon halo (dithered, smooth)
  const MX = 232, MY = 58, MR = 20;
  for (let y = 0; y < HOR; y++) for (let x = 0; x < W; x++) {
    const d = Math.hypot(x - MX, y - MY); if (d <= MR || d > 54) continue;
    const k = Math.pow(1 - (d - MR) / (54 - MR), 2.2);
    im.tint(x, y, k * 0.62, hex('#9a84d8'), 1, 5);
  }
  // stars (hand-spaced, no noise)
  const stars = [];
  for (let n = 0; n < 400 && stars.length < 62; n++) {
    const x = Math.floor(r() * W), y = Math.floor(r() * 108);
    if (Math.hypot(x - MX, y - MY) < 58) continue; if (stars.some(s => Math.hypot(s[0] - x, s[1] - y) < 15)) continue; stars.push([x, y]);
  }
  stars.forEach(([x, y], i) => {
    const k = i % 9; const dimC = hex('#7a68b0'), mid = hex('#c9b8e8'), br = hex('#f6eeff');
    if (k === 0) { im.set(x, y, br); im.set(x - 1, y, mid); im.set(x + 1, y, mid); im.set(x, y - 1, mid); im.set(x, y + 1, mid); im.set(x - 2, y, dimC); im.set(x + 2, y, dimC); im.set(x, y - 2, dimC); im.set(x, y + 2, dimC); }
    else if (k === 3 || k === 6) { im.set(x, y, br); im.set(x - 1, y, dimC); im.set(x + 1, y, dimC); im.set(x, y - 1, dimC); im.set(x, y + 1, dimC); }
    else if (k === 4) { im.set(x, y, hex('#ffc075')); im.set(x + 1, y, hex('#a6643c')); }
    else if (k === 7) { im.set(x, y, hex('#88dff3')); }
    else if (k % 2) { im.set(x, y, mid); } else { im.set(x, y, dimC); }
  });
  // moon
  const ML = H('#8a78b8 #a493cc #bfaee0 #d9ccf2 #eee6fb #fbf6ff');
  const craters = [[-6, -8, 4.2], [7, 5, 5.2], [-9, 7, 3], [8, -9, 2.6], [-1, 12, 2.4], [-12, -1, 2], [1, -1, 2.2], [13, -1, 1.8]];
  im.ell(MX, MY, MR, MR, (x, y, q, dx, dy) => {
    let lit = 0.5 - (dx * -0.55 + dy * -0.62) * 0.55 - q * q * 0.18; lit = 1 - clamp(lit);
    let v = lit * 4.6 + 0.6;
    for (const [cx, cy, cr] of craters) {
      const ex = (x + 0.5 - (MX + cx)) / cr, ey = (y + 0.5 - (MY + cy)) / cr, e = Math.hypot(ex, ey);
      if (e < 1) { v -= 1.15; if (ex * -0.7 + ey * -0.7 > 0.25 && e > 0.55) v -= 0.9; if (ex * 0.7 + ey * 0.7 > 0.35 && e > 0.6) v += 1.4; }
      else if (e < 1.3 && ex * 0.7 + ey * 0.7 > 0.4) v += 0.5;
    }
    if (q > 0.93) v -= 1.0;
    const i = clamp(Math.floor(v + (bay(x, y) - 0.5) * 0.9), 0, 5); return ML[i];
  });
  // soft rim on the dark side
  // cloud helper: union of flat-bottomed blobs
  const cloud = (cx, cy, w, h, seed, tones, rimWarm = 0) => {
    const rr = rng(seed), blobs = []; const n = Math.max(4, Math.floor(w / 14));
    for (let i = 0; i < n; i++) { const t = (i + 0.5) / n; blobs.push([cx - w / 2 + t * w + (rr() - 0.5) * 6, cy - Math.sin(Math.PI * t) * h * 0.45 + (rr() - 0.5) * 2, 8 + Math.sin(Math.PI * t) * h * 0.55 + rr() * 3, 3 + Math.sin(Math.PI * t) * h * 0.55]); }
    const top = new Map();
    for (const [bx, by, rx, ry] of blobs) for (let x = Math.floor(bx - rx); x <= Math.ceil(bx + rx); x++) { const k = (x - bx) / rx; if (Math.abs(k) > 1) continue; const yy = by - ry * Math.sqrt(1 - k * k); top.set(x, Math.min(top.get(x) ?? 1e9, yy)); }
    const bot = cy + h * 0.18;
    for (const [x, t0] of top) for (let y = Math.floor(t0); y <= bot; y++) {
      const d = y - t0; const taper = Math.min(1, (bot - y) / 2.5);
      const edge = y > bot - 1; let c;
      if (d < 1.2) c = tones[0]; else if (d < 3.2) c = tones[1]; else if (d < 6 + h * 0.15) c = tones[2]; else c = tones[3];
      if (d >= 1.2 && d < 3.2 && ((x >> 2) + y) % 2 && d > 2) c = tones[2];
      if (edge) c = tones[3];
      im.set(x, y, taper < 0.5 && bay(x, y) > 0.5 ? im.get(x, y) : c);
    }
  };
  const cT = H('#8068b8 #4a3382 #2f2060 #1f1244');       // lit rim (moon side) -> body
  const cT2 = H('#5a4698 #38276e #271a54 #190e38');
  cloud(214, 80, 110, 9, 11, cT);
  cloud(60, 38, 100, 10, 21, cT2);
  cloud(322, 30, 70, 8, 31, cT2);
  cloud(40, 100, 90, 7, 41, cT2);
  cloud(290, 98, 80, 8, 51, cT);
  cloud(150, 24, 56, 6, 61, cT2);
  // horizon haze
  for (let y = 112; y < HOR + 2; y++) for (let x = 0; x < W; x++) im.tint(x, y, (y - 112) / 14 * 0.5, hex('#8a6ac0'), 1, 4);
  // distant islands (silhouette + moon rim light)
  const island = (x0, x1, peak, seed, lamp) => {
    const rr = rng(seed), pk = (x0 + x1) / 2 + (rr() - 0.5) * 10;
    const prof = x => { const u = x < pk ? (x - x0) / (pk - x0) : (x1 - x) / (x1 - pk); return peak * (Math.pow(clamp(u), 0.8) * 0.85 + 0.15 * Math.sin(x * 0.7) * u); };
    const dark = hex('#150a2e'), mid = hex('#1d1040'), rim = hex('#44357e');
    for (let x = x0; x <= x1; x++) { const hgt = Math.round(prof(x)); for (let d = 0; d <= hgt; d++) { const y = HOR - d; let c = d > hgt - 1 && x > pk - 3 ? rim : (d > hgt * 0.55 ? mid : dark); if (d === hgt && x <= pk - 3) c = mid; im.set(x, y, c); } }
    // tiny palms on top
    for (const px of [pk - 8, pk + 3, pk + 9]) { const base = HOR - Math.round(prof(px)); const ht = 5 + Math.floor(rr() * 3); for (let k = 0; k < ht; k++) im.set(px + (k > 3 ? 1 : 0), base - k, dark); for (const [fx, fy] of [[-3, 1], [-2, 0], [2, 0], [3, 1], [0, -1], [-1, -1], [1, -1]]) im.set(px + 1 + fx, base - ht + fy, dark); }
    if (lamp) { const lx = x0 + 10, ly = HOR - Math.round(prof(lx)) - 1; im.rect(lx, ly - 5, 2, 5, dark); im.set(lx, ly - 6, hex('#ffc075')); im.set(lx + 1, ly - 6, hex('#ffa033')); im.set(lx - 1, ly - 6, hex('#7a4a3a')); im.set(lx + 2, ly - 6, hex('#7a4a3a')); }
  };
  island(104, 192, 15, 3, true);
  island(18, 56, 6, 9, false);
  // sea
  const sea = H('#170b32 #1a1048 #1d1a5c #1f2a72 #213f88 #25569c #2b6eae');
  for (let y = HOR; y < SHORE + 8; y++) for (let x = 0; x < W; x++) im.set(x, y, im.ramp(sea, (y - HOR) / (SHORE + 8 - HOR), x, y, 2.2));
  // horizon line: broken shimmer
  for (let x = 0; x < W; x++) if (((x + (x >> 4) * 5) % 9) < 6) im.set(x, HOR, hex('#5f4aa6'));
  // wave rows with perspective
  const rows = []; { let y = HOR + 4, s = 3; while (y < SHORE - 2) { rows.push(y); y += Math.round(s); s *= 1.2; } }
  const pathHalf = y => 4 + (y - HOR) * 0.30;
  rows.forEach((y, k) => {
    const dep = k / rows.length, L = 6 + dep * 34, hh = dep < 0.4 ? 1 : 2, rr = rng(100 + k);
    const lit = dep < 0.3 ? hex('#4a4aa8') : dep < 0.6 ? hex('#3b86c8') : hex('#7fd0ec');
    const dark = dep < 0.3 ? hex('#120a30') : dep < 0.6 ? hex('#16206a') : hex('#1b3e86');
    let x = -((k * 37) % 30);
    while (x < W) {
      const len = Math.round(L * (0.6 + rr() * 0.8)); const nearPath = Math.abs(x + len / 2 - MX) < pathHalf(y) + 6;
      for (let i = 0; i < len; i++) {
        const a = Math.sin(Math.PI * i / len) * hh, yy = y - Math.round(a);
        if (!nearPath) { im.set(x + i, yy, lit); if (a > 0.9 || hh === 1) im.set(x + i, yy + 1, dark); if (hh === 2) { im.set(x + i, yy + 1, mix(lit, dark, 0.45)); im.set(x + i, yy + 2, dark); } }
      }
      x += len + Math.round(L * (0.5 + rr() * 1.2));
    }
  });
  // moonlight path: glow + broken reflections
  for (let y = HOR + 1; y < SHORE; y++) {
    const w = pathHalf(y); for (let x = Math.floor(MX - w - 6); x <= MX + w + 6; x++) {
      const k = 1 - Math.abs(x - MX) / (w + 6); if (k <= 0) continue; im.tint(x, y, k * 0.42, hex('#7a74d0'), 1, 4);
    }
  }
  for (let y = HOR + 2; y < SHORE; y += 2) {
    const dep = (y - HOR) / (SHORE - HOR), w = pathHalf(y), rr = rng(900 + y);
    let x = MX - w + Math.round(rr() * 3);
    while (x < MX + w) {
      const len = Math.max(2, Math.round((2 + dep * 14) * (0.4 + rr() * 1.1))), c = Math.abs(x + len / 2 - MX) / w;
      if (rr() > c * 0.85 + 0.1 * dep) { const col = c < 0.35 ? hex('#fbf6ff') : c < 0.7 ? hex('#d9ccf2') : hex('#a493cc'); for (let i = 0; i < len; i++) { im.set(x + i, y, col); } if (len > 4 && dep > 0.2) { im.hl(x + 1, x + len - 2, y + 1, mix(col, hex('#3a3a90'), 0.55)); } }
      x += len + 1 + Math.round(rr() * (3 + dep * 7));
    }
  }
  // shallow water + foam + wet sand
  const fe = x => SHORE + 1 + Math.round(2.2 * Math.sin(x / 10) + 1.6 * Math.sin(x / 4.7 + 1.3));
  const shallow = H('#2b6eae #2f86bc #36a0c6 #46bcd0 #6ad4dc');
  const wet = H('#5c4670 #6c5478 #7c6482 #8e7690');
  for (let x = 0; x < W; x++) {
    const f = fe(x);
    for (let y = SHORE - 8; y < f - 3; y++) im.set(x, y, im.ramp(shallow, (y - (SHORE - 8)) / (f - 3 - (SHORE - 8) + 1), x, y, 2));
    im.set(x, f - 3, hex('#9ae6ea')); im.set(x, f - 2, hex('#d2f6f4')); im.set(x, f - 1, hex('#fbf6ff')); im.set(x, f, hex('#fbf6ff'));
    im.set(x, f + 1, hex('#c9b8e8'));
    for (let y = f + 2; y < Hh; y++) { const t = (y - f - 2) / 16; im.set(x, y, im.ramp(wet, clamp(t), x, y, 2)); }
    // lace: foam tongues
    if ((x * 7 + (x >> 3) * 3) % 11 < 3) { im.set(x, f + 2, hex('#e8def8')); if (x % 2) im.set(x, f + 3, hex('#b9a8d8')); }
    if ((x * 13) % 29 === 0) { im.set(x, f + 5, hex('#d9ccf2')); im.set(x + 1, f + 5, hex('#a493cc')); }
  }
  // wet-sand sheen of the moon path
  for (let y = SHORE + 6; y < 227; y++) for (let x = MX - 24; x < MX + 24; x++) im.tint(x, y, (1 - Math.abs(x - MX) / 24) * 0.35, hex('#c9b8e8'), 1, 3);
  // second foam line out in the water
  for (let x = 0; x < W; x++) { const y = SHORE - 14 + Math.round(1.6 * Math.sin(x / 7 + 2) + Math.sin(x / 3.1)); if ((x + (x >> 5) * 7) % 21 < 15) { im.set(x, y, hex('#b8e8f0')); im.set(x, y + 1, hex('#3f9cc8')); } }
  // sand mound under the palm
  im.ell(330, 227, 20, 5, (x, y, q, dx, dy) => y > 227 ? null : im.ramp(H('#8e7690 #a58b98 #bfa4a4'), clamp(0.9 - dy * 0.6 - q * 0.4 + 0.2 * (-dx)), x, y, 2));
  // palm
  palm(im);
  // floor-colour fill below (hidden by floor.png)
  return im;
}

function palm(im) {
  const W = im.w, Hh = im.h; const m = new Uint8Array(W * Hh);
  const lay = new Img(W, Hh); // colour layer
  const setL = (x, y, c) => { x = Math.round(x); y = Math.round(y); if (x < 0 || y < 0 || x >= W || y >= Hh) return; m[y * W + x] = 1; lay.set(x, y, c); };
  // trunk
  const path = bez3([330, 228], [321, 172], [347, 138], [337, 100], 260);
  let arc = 0;
  const T = [H('#5e4676 #3c2a58 #281a42 #170d2c'), hex('#150a26'), hex('#6e5688')];
  const ring = 6.5;
  for (let i = 0; i < path.length; i++) {
    const [px, py] = path[i], [qx, qy] = path[Math.min(path.length - 1, i + 1)], [ox, oy] = path[Math.max(0, i - 1)];
    let tx = qx - ox, ty = qy - oy; const tl = Math.hypot(tx, ty) || 1; tx /= tl; ty /= tl; const nx = -ty, ny = tx;
    if (i) arc += Math.hypot(px - ox, py - oy);
    const t = i / (path.length - 1), w = 5.2 - 1.7 * t + (t < 0.06 ? (0.06 - t) * 28 : 0);
    const seg = (arc % ring), segI = Math.floor(arc / ring);
    for (let u = -w; u <= w; u += 0.5) {
      const k = u / w; let ci = k < -0.55 ? 0 : k < 0.05 ? 1 : k < 0.6 ? 2 : 3;
      if (seg < 1.1) { ci = Math.min(3, ci + 1); if (k < -0.2) ci = 2; }
      else if (seg > ring - 1.3 && k < 0.2) ci = Math.max(0, ci - 1);
      let c = T[0][ci];
      if ((seg < 1.1) && k > 0.6) c = T[1];
      if (segI % 3 === 1 && Math.abs(k) < 0.5 && seg > 3 && seg < 4 && bay(Math.round(px), Math.round(py)) > 0.5) c = T[0][1];
      setL(px + nx * u, py + ny * u, c);
    }
  }
  // sand-ring (root flare)
  // fronds
  const C = [337, 98];
  const fronds = [ // angle deg, length, droop, layer
    [-160, 44, 26, 0], [-20, 46, 26, 0], [-118, 36, 10, 0], [-62, 36, 10, 0],
    [-182, 58, 40, 1], [2, 54, 38, 1], [-140, 52, 26, 1], [-40, 48, 26, 1], [-95, 30, 4, 1], [158, 40, 48, 1], [24, 38, 46, 1], [-165, 46, 10, 1], [-15, 44, 12, 1],
  ];
  const cols = [
    { base: hex('#1c1040'), lit: hex('#33267c'), tip: hex('#5c4cb0'), rib: hex('#120926') },
    { base: hex('#2c2068'), lit: hex('#4e40a4'), tip: hex('#9a88e8'), rib: hex('#170c34') },
  ];
  const fl = new Img(W, Hh); const fm = new Uint8Array(W * Hh);
  const mk = (x, y) => { x = Math.round(x); y = Math.round(y); if (x >= 0 && y >= 0 && x < W && y < Hh) fm[y * W + x] = 1; };
  for (const [ang, len, droop, ly] of fronds) {
    const a = ang * Math.PI / 180, dir = [Math.cos(a), Math.sin(a)];
    const p0 = C, p2 = [C[0] + dir[0] * len, C[1] + dir[1] * len + droop], p1 = [C[0] + dir[0] * len * 0.55, C[1] + dir[1] * len * 0.55 - len * 0.22];
    const rib = bez2(p0, p1, p2, 90), co = cols[ly];
    for (let i = 1; i < rib.length - 1; i++) {
      const t = i / (rib.length - 1); if (t < 0.1) continue;
      const [px, py] = rib[i], [qx, qy] = rib[i + 1], [ox, oy] = rib[i - 1]; let tx = qx - ox, ty = qy - oy; const tl = Math.hypot(tx, ty) || 1; tx /= tl; ty /= tl;
      const ll = Math.max(3, len * 0.32 * Math.pow(Math.sin(Math.PI * Math.min(1, t * 1.05)), 0.55) * (1 - 0.3 * t));
      if (i % 2) continue;
      for (const sd of [-1, 1]) {
        const sw = 0.95 - 0.35 * t; // sweep toward the tip
        let dx = tx * sw + (-ty) * sd * 0.7, dy = ty * sw + tx * sd * 0.7; dy += 0.55 + 0.35 * t; const dl = Math.hypot(dx, dy); dx /= dl; dy /= dl;
        const ex = px + dx * ll, ey = py + dy * ll, upper = (sd === (tx >= 0 ? -1 : 1));
        const steps = Math.ceil(ll);
        for (let s = 0; s <= steps; s++) { const f = s / steps, x = px + (ex - px) * f, y = py + (ey - py) * f; const c = (upper && f < 0.5) ? co.lit : (f > 0.82 && upper ? co.tip : co.base); fl.set(x, y, c); mk(x, y); }
      }
    }
    for (let i = 0; i < rib.length; i++) { const [x, y] = rib[i]; fl.set(x, y, co.rib); fl.set(x, y - 1, co.lit); mk(x, y); mk(x, y - 1); }
    // flush this frond layer onto the main image with an outline so layers separate
    for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) if (fm[y * W + x]) { setL(x, y, fl.get(x, y)); fm[y * W + x] = 0; }
  }
  // coconuts
  for (const [cx, cy] of [[333, 103], [339, 104], [336, 108]]) { for (let y = -2; y <= 2; y++) for (let x = -2; x <= 2; x++) if (x * x + y * y <= 5) setL(cx + x, cy + y, hex('#3a2630')); setL(cx - 1, cy - 1, hex('#7a5a58')); setL(cx, cy - 1, hex('#5a3e48')); }
  // outline of the whole silhouette (ink-violet), then composite
  const out = [];
  for (let y = 1; y < Hh - 1; y++) for (let x = 1; x < W - 1; x++) if (!m[y * W + x] && (m[y * W + x + 1] || m[y * W + x - 1] || m[(y + 1) * W + x] || m[(y - 1) * W + x])) out.push([x, y]);
  for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) if (m[y * W + x]) im.set(x, y, lay.get(x, y));
  for (const [x, y] of out) if (y < 227) im.set(x, y, hex('#0e0620'));
}

function riptideFloor() {
  const W = 350, Hh = 72, im = new Img(W, Hh), r = rng(5);
  const sand = H('#7a6482 #8e7690 #a28a98 #b39ca2 #c0aaac #cbb6b2');
  for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) im.set(x, y, im.ramp(sand, clamp((y - 0) / 26) * 0.75 + 0.1 + 0.0 * x, x, y, 1.6));
  // gentle dune shading bands (long, smooth)
  for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) { const k = Math.sin(x / 52 + y / 17) * 0.5 + 0.5; if (y > 8) im.tint(x, y, k * 0.25, hex('#e8d4c8'), 1, 3); }
  // ripples: arcs with light crest above and violet shadow below, perspective spacing
  const rr = rng(77); const rowsY = [11, 20, 31, 44, 58, 69];
  rowsY.forEach((y0, k) => {
    let x = -rr() * 40;
    while (x < W) {
      const len = 26 + Math.floor(rr() * 46) + k * 6, amp = 1 + (k > 2 ? 1 : 0);
      for (let i = 0; i < len; i++) {
        const yy = y0 + Math.round(Math.sin(i / len * Math.PI) * -amp + Math.sin((x + i) / 9 + k) * 0.8);
        const edge = i < 3 || i > len - 4; if (edge && i % 2) continue;
        im.set(x + i, yy - 1, hex('#e8d8cc')); im.set(x + i, yy, hex('#c8aeb0'));
        im.set(x + i, yy + 1, hex('#8e7090')); if (k > 2 && !edge) im.set(x + i, yy + 2, hex('#a08aa0'));
      }
      x += len + 10 + Math.floor(rr() * 36);
    }
  });
  // grain: a few deliberate pebble clusters (light top, shadow below)
  const peb = [[40, 6], [148, 12], [262, 9], [322, 15], [92, 26], [214, 36], [300, 40], [170, 52], [30, 64], [250, 62]];
  peb.forEach(([x, y], i) => { const n = 2 + (i % 3); for (let j = 0; j < n; j++) { const px = x + j * 3 + (j % 2), py = y + (j % 2); im.set(px, py, hex('#e8d4c8')); im.set(px + 1, py, hex('#c8aeb0')); im.set(px, py + 1, hex('#8e7090')); im.set(px + 1, py + 1, hex('#7a5e80')); } });
  // wet-sand trail from the surf (top rows): foam leftovers
  for (let x = 0; x < W; x++) { if ((x * 5 + (x >> 4) * 3) % 17 < 3) im.set(x, 1 + (x % 3), hex('#d9ccf2')); }
  // footprints trail (pairs), shadowed oval with lit rim
  const fp = (cx, cy, flip) => {
    im.ell(cx, cy, 4, 2.4, (x, y, q, dx, dy) => (dx + dy * 0.2 < -0.2 && q > 0.55) ? hex('#6e5472') : mix(hex('#8a7090'), hex('#a08aa0'), q));
    im.ell(cx + (flip ? -5 : 5), cy - 1, 2, 1.2, (x, y, q) => q < 0.8 ? hex('#8a7090') : hex('#a08aa0'));
    im.hl(cx - 3, cx + 3, cy + 3, hex('#d8c0b8'));
  };
  [[20, 63], [42, 68], [66, 62], [88, 67], [112, 62], [134, 67]].forEach(([x, y], i) => fp(x, y, i % 2));
  // shell: scallop fan
  const scallop = (cx, cy, s, pal) => {
    for (let y = -s; y <= 1; y++) for (let x = -s - 1; x <= s + 1; x++) {
      const d = Math.hypot(x, y * 1.15); if (d > s + 0.4 || (y > 0 && Math.abs(x) > 1)) continue;
      const a = Math.atan2(y, x), ridge = Math.floor((a + Math.PI) / (Math.PI / 6)) % 2;
      let c = ridge ? pal[1] : pal[2]; if (d > s - 0.9) c = pal[3]; if (y < -s * 0.3 && x < 0) c = ridge ? pal[0] : pal[1]; im.set(cx + x, cy + y, c);
    }
    im.rect(cx - 1, cy + 1, 3, 1, pal[3]);
  };
  scallop(206, 63, 5, H('#fff0e8 #f0d0c8 #d8a8a8 #8a5a70'));
  scallop(310, 68, 4, H('#ffe0b8 #f0c098 #d09878 #7a4a50'));
  // conch / spiral
  const conch = (cx, cy) => {
    const p = H('#fff0e8 #e8c0b0 #c08a90 #6a3a58');
    im.ell(cx, cy, 6, 3.4, (x, y, q, dx, dy) => (q > 0.82 ? p[3] : dy < -0.3 ? p[0] : dy < 0.2 ? p[1] : p[2]));
    im.vl(cx - 2, cy - 2, cy + 2, p[3]); im.vl(cx + 1, cy - 2, cy + 2, p[2]); im.set(cx + 5, cy, p[3]); im.set(cx + 6, cy + 1, p[3]);
    im.ell(cx + 3, cy, 1.5, 1.8, (x, y, q) => q < 1 ? hex('#a66a78') : null);
  };
  conch(238, 63); conch(272, 36);
  // starfish (pink accent, as the old art)
  const star = (cx, cy) => {
    const body = hex('#ff5fb0'), hi = hex('#ff98c2'), sh = hex('#a63e84');
    for (let k = 0; k < 5; k++) { const a = -Math.PI / 2 + k * Math.PI * 2 / 5; for (let t = 0; t <= 6; t += 0.5) { const w = 2.2 * (1 - t / 7); for (let u = -w; u <= w; u += 0.5) { const x = cx + Math.cos(a) * t - Math.sin(a) * u, y = cy + Math.sin(a) * t + Math.cos(a) * u; im.set(x, y, (u < -0.3 ? hi : u > 0.6 ? sh : body)); } } }
    im.set(cx, cy, hi); im.set(cx, cy - 3, hi); im.set(cx + 2, cy + 1, hex('#ffc0d8')); im.set(cx - 2, cy + 1, hex('#ffc0d8'));
    im.set(cx - 5, cy + 6, sh); im.set(cx + 5, cy + 6, sh);
  };
  star(236, 15);
  // seaweed strand
  for (let i = 0; i < 18; i++) { const x = 236 + i, y = 34 + Math.round(Math.sin(i / 2.2) * 1.8); im.set(x, y, hex('#3a4a3c')); im.set(x, y + 1, hex('#2a3a30')); if (i % 3 === 0) { im.set(x, y - 1, hex('#5a7a4c')); } }
  // driftwood
  { const dw = [H('#9a7a64 #7a5c4c #5a4038 #3a2830')]; const x0 = 148, y0 = 58; for (let i = 0; i < 34; i++) { const yy = y0 - Math.round(i * 0.1); im.set(x0 + i, yy, dw[0][0]); im.set(x0 + i, yy + 1, dw[0][1]); im.set(x0 + i, yy + 2, dw[0][1]); im.set(x0 + i, yy + 3, dw[0][2]); if (i % 7 === 3) im.set(x0 + i, yy + 1, dw[0][3]); } for (const [dx, dy] of [[0, 1], [0, 2], [33, 0], [33, 1], [33, 2]]) im.set(x0 + dx, y0 - 3 + dy + (dx ? 0 : 3), dw[0][3]); im.hl(x0 + 4, x0 + 28, y0 + 4, hex('#8a7090')); }
  return im;
}

// ============================================================
// GAINSGARD  (castle gym hall)
// ============================================================
const pip = (pts, x, y) => { let c = false; for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) { const a = pts[i], b = pts[j]; if ((a[1] > y) !== (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]) c = !c; } return c; };
const maskOf = (im, pts) => { const m = new Uint8Array(im.w * im.h); im.poly(pts, (x, y) => { if (x >= 0 && y >= 0 && x < im.w && y < im.h) m[y * im.w + x] = 1; return null; }); return m; };
function crack(im, pts, dark, lite) {
  for (let i = 0; i + 1 < pts.length; i++) { im.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], dark); if (lite) im.line(pts[i][0] + 1, pts[i][1], pts[i + 1][0] + 1, pts[i + 1][1], lite); }
  for (let i = 0; i + 1 < pts.length; i++) im.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], dark);
}
function moss(im, x0, y0, w, seed, up = 4) {
  const rr = rng(seed), g = H('#2c4a34 #3d6a3a #5f8a3a #9ab83c');
  for (let i = 0; i < w; i++) {
    const hgt = Math.round((Math.sin(i * 0.85 + seed) + 1.15) * up * 0.45 + rr() * 1.2);
    for (let d = 0; d <= hgt; d++) { const k = hgt - d; im.set(x0 + i, y0 - d, k === 0 ? g[3] : k === 1 ? g[2] : d < 1 ? g[0] : g[1]); }
    if (rr() < 0.3) { const l = 2 + Math.floor(rr() * 4); for (let d = 1; d <= l; d++) im.set(x0 + i, y0 + d, d === l ? g[2] : g[1]); }
  }
}
function gainsBackground() {
  const W = 350, Hh = 300, im = new Img(W, Hh);
  const TX = 201, TY = 50;
  const warm = (x, y) => Math.pow(clamp(1 - Math.hypot((x - TX) * 0.92, (y - TY) * 1.0) / 72), 1.6);
  const calm = (x, y) => x >= 118 && y >= 84 && y <= 230;
  const MORT = hex('#221040'), MORT2 = hex('#2c1850');
  const tones = H('#3b2b55 #43325e #392950 #4a3866 #3e2c5c');
  const hi = t => mix(t, hex('#86689c'), 0.38), sh = t => mix(t, hex('#1c0c38'), 0.4), dp = t => mix(t, hex('#150a2c'), 0.6);
  im.rect(0, 0, W, Hh, MORT);
  for (let r = 0; ; r++) {
    const by = 10 + r * 16; if (by > 232) break;
    const rr = rng(300 + r), wl = [30, 38, 44, 34, 40, 48]; let bx = -Math.floor(rr() * 34);
    while (bx < W) {
      const bw = wl[Math.floor(rr() * wl.length)], cxm = bx + bw / 2, cym = by + 8, isCalm = calm(cxm, cym);
      let ti = Math.floor(hash(r, bx) * 5); if (isCalm) ti = hash(r, bx) > 0.5 ? 1 : 4;
      const T = tones[ti], chipHere = !isCalm && hash(bx, r + 99) < 0.22;
      for (let v = 0; v < 14; v++) for (let u = 0; u < bw - 2; u++) {
        const x = bx + 2 + u, y = by + 2 + v; if (x < 0 || x >= W || y >= Hh) continue;
        let c = T;
        if (v === 0) c = hi(T); else if (v === 1 && u > 0) c = mix(T, hi(T), 0.45);
        else if (v >= 12) c = v === 13 ? dp(T) : sh(T);
        else if (v >= 8) c = im.ramp([T, sh(T)], (v - 7) / 5 * 0.7, x, y, 2);
        if (u === 0 && v > 0 && v < 12) c = mix(c, hi(T), 0.35);
        if (u === bw - 3 && v > 1) c = mix(c, sh(T), 0.6);
        if (isCalm && v > 1 && v < 12 && u > 1 && u < bw - 4) c = T; // flat, calm
        im.set(x, y, c);
      }
      // mortar tone: top line a bit darker, a lit lip under each brick
      for (let u = 0; u < bw; u++) { const x = bx + u; if (x >= 0 && x < W) { im.set(x, by, MORT); im.set(x, by + 1, MORT2); } }
      if (chipHere) { const cx = bx + 2 + (hash(r, bx + 5) > 0.5 ? bw - 8 : 1), cy = by + (hash(bx, r) > 0.5 ? 2 : 11); im.rect(cx, cy, 3, 2, MORT2); im.hl(cx, cx + 2, cy + 2, sh(T)); im.set(cx + 3, cy, sh(T)); }
      bx += bw;
    }
  }
  // torch light on the wall (warm tint, dithered)
  for (let y = 10; y < 230; y++) for (let x = 0; x < W; x++) im.tint(x, y, warm(x, y) * 0.95, hex('#ff9440'), 0.62, 6);
  // moonlight beam from the window (cool), crossbars cast as shadows
  const beam = [[26, 140], [70, 140], [136, 228], [52, 228]];
  im.poly(beam, (x, y) => { const fade = 1 - (y - 140) / 100; im.tint(x, y, 0.34 * fade + 0.05, hex('#a8a0f0'), 1, 4); return null; });
  for (let y = 144; y < 228; y++) { const cx = 48 + (y - 140) * 0.52; for (const k of [0, 1]) im.tint(Math.round(cx) + k, y, 0.6, hex('#120626'), 0.5, 3); }
  for (let x = 30; x < 120; x++) { const y = 176 + Math.round((x - 30) * 0.55); if (pip(beam, x, y)) { im.tint(x, y, 0.6, hex('#120626'), 0.5, 3); im.tint(x, y + 1, 0.6, hex('#120626'), 0.5, 3); } }
  // cracks and moss (never in the calm area)
  const cd = hex('#150a2a'), cl = hex('#5e4a84');
  crack(im, [[296, 18], [300, 27], [297, 35], [303, 45], [301, 57], [306, 66]], cd, cl);
  crack(im, [[5, 58], [9, 69], [6, 82], [11, 99], [8, 112]], cd, cl);
  crack(im, [[104, 148], [99, 160], [105, 171], [101, 186]], cd, cl);
  crack(im, [[318, 22], [313, 31], [317, 40]], cd, cl);
  moss(im, 2, 212, 26, 3); moss(im, 76, 212, 36, 5); moss(im, 12, 131, 18, 7, 3); moss(im, 60, 131, 14, 9, 3);
  moss(im, 294, 10, 26, 11, 2); moss(im, 2, 11, 18, 13, 2);
  moss(im, 12, 58, 4, 15, 2);
  // ---- beam (ceiling timber) ----
  for (let y = 0; y < 10; y++) for (let x = 0; x < W; x++) {
    let c = y === 0 ? hex('#6a4a58') : y < 3 ? hex('#4c3646') : y < 7 ? hex('#3a2a3a') : y === 7 ? hex('#2e2030') : hex('#1e1226');
    if ((y === 2 || y === 5) && ((x * 3 + y * 11) % 47) < 30) c = mix(c, hex('#6a4a58'), 0.4);
    if (y === 4 && ((x + 17) % 61) < 9) c = hex('#241628');
    im.set(x, y, c);
  }
  for (let y = 10; y < 15; y++) for (let x = 0; x < W; x++) im.tint(x, y, (1 - (y - 10) / 5) * 0.8, hex('#0c0418'), 0.8, 4);
  for (const sx of [14, 112, 232, 322]) { for (let y = 0; y < 10; y++) { im.hl(sx, sx + 8, y, y === 0 ? hex('#8a7aa8') : y > 7 ? hex('#1a1226') : hex('#4a3e62')); } for (const rx of [sx + 2, sx + 6]) { im.set(rx, 3, hex('#c9b8e8')); im.set(rx, 4, hex('#1a1226')); } }
  // ---- chain ----
  { const cx = 100, S = H('#c9b8e8 #8a7aa8 #4a3e68 #1c1230');
    for (let k = 0; k < 6; k++) { const y = 10 + k * 6;
      if (k % 2 === 0) { im.rect(cx - 2, y, 5, 7, S[2]); im.rect(cx - 1, y + 1, 3, 5, MORT); im.vl(cx - 2, y, y + 6, S[1]); im.hl(cx - 2, cx + 2, y, S[0]); im.hl(cx - 2, cx + 2, y + 6, S[3]); }
      else { im.rect(cx - 1, y, 3, 7, S[1]); im.vl(cx - 1, y, y + 6, S[0]); im.vl(cx + 1, y, y + 6, S[2]); } }
    im.rect(cx - 3, 46, 7, 2, S[1]); im.hl(cx - 3, cx + 3, 46, S[0]); im.set(cx - 2, 48, S[2]); im.set(cx + 2, 48, S[2]); im.set(cx, 49, S[2]); }
  // ---- window ----
  windowDraw(im);
  // ---- banners ----
  banner(im, 128, 46, H('#4a2f8a #6a45b8 #8f66e8 #b896f6'), 'diamond', warm);
  banner(im, 232, 46, H('#8a2f6a #c4468e #ff5fb0 #ff98c2'), 'ring', warm);
  // ---- torch ----
  torch(im, TX, TY);
  // ---- rack with dumbbells ----
  rack(im);
  // ---- plinth ----
  for (let y = 212; y < Hh; y++) for (let x = 0; x < W; x++) im.set(x, y, y === 212 ? hex('#7c68a6') : y === 213 ? hex('#5e4a88') : y > 225 ? hex('#241040') : hex('#4a3870'));
  { let x = -16, k = 0; while (x < W) { const bw = [46, 58, 40, 52][k++ % 4]; for (let y = 214; y < 226; y++) { im.set(x, y, hex('#2c1850')); im.set(x + 1, y, hex('#2c1850')); } for (let xx = x + 2; xx < x + bw; xx++) { im.set(xx, 214, hex('#6a5694')); im.set(xx, 224, hex('#3a2a60')); im.set(xx, 225, hex('#2e1e50')); } x += bw; } }
  for (let y = 212; y < 228; y++) for (let x = 0; x < W; x++) im.tint(x, y, warm(x, y) * 0.5, hex('#ff9440'), 0.5, 4);
  for (let y = 214; y < Hh; y++) for (let x = 0; x < W; x++) if (y >= 228) im.set(x, y, hex('#2c1850'));
  return im;
}

function windowDraw(im) {
  const CX = 48, CY = 84, RO = 33, RI = 24;
  const inOuter = (x, y) => y < CY ? Math.hypot(x + 0.5 - CX, y + 0.5 - CY) <= RO : (x >= CX - RO && x < CX + RO && y < 132);
  const inInner = (x, y) => y < CY ? Math.hypot(x + 0.5 - CX, y + 0.5 - CY) <= RI : (x >= CX - RI && x < CX + RI && y < 130);
  const stone = H('#5a4a80 #6a5894 #4c3c70 #7a68a4'), mortar = hex('#22123e');
  const m = new Uint8Array(im.w * im.h);
  for (let y = CY - RO - 1; y < 142; y++) for (let x = CX - RO - 4; x < CX + RO + 4; x++) {
    if (x < 0) continue;
    // sill
    if (y >= 130 && y < 138 && x >= 11 && x < 85) { const c = y === 130 ? hex('#9a88c4') : y === 131 ? hex('#7a68a4') : y < 136 ? hex('#5e4c88') : y === 136 ? hex('#3c2c60') : hex('#2a1a48'); im.set(x, y, c); m[y * im.w + x] = 1; continue; }
    if (y >= 138 && y < 142 && x >= 11 && x < 85) { im.tint(x, y, (142 - y) / 4 * 0.7, hex('#0c0418'), 0.7, 4); continue; }
    if (!inOuter(x, y) || inInner(x, y)) continue;
    m[y * im.w + x] = 1; let c;
    if (y < CY) {
      const ang = Math.atan2(y + 0.5 - CY, x + 0.5 - CX), sec = (ang + Math.PI) / (Math.PI / 9), si = Math.floor(sec), f = sec - si, rad = Math.hypot(x + 0.5 - CX, y + 0.5 - CY);
      c = stone[(si % 2) ? 1 : 0]; if (si === 4 || si === 5) c = stone[3];
      if (f < 0.07 || f > 0.95 || rad > RO - 0.9 && false) c = mortar;
      if (rad > RO - 1.6) c = mix(c, hex('#8a78b4'), 0.35); if (rad < RI + 1.6) c = mix(c, hex('#1c0e36'), 0.5);
    } else {
      const course = Math.floor((y - CY) / 11), off = ((x < CX) ? 0 : 1) ^ (course & 1); const v = (y - CY) % 11;
      c = stone[(course + (x < CX ? 0 : 1)) % 2 ? 1 : 0]; if (v === 0) c = mortar; else if (v === 1) c = mix(c, hex('#9a88c4'), 0.35);
      if (course % 2 === 0 && (x === 17 || x === 78 || x === 22 || x === 73)) c = mortar;
      if ((x < CX ? x - (CX - RO) : (CX + RO - 1) - x) < 1.5) c = mix(c, hex('#8a78b4'), 0.3); if ((x < CX ? (CX - RI - 1) - x : x - (CX + RI)) < 1.5) c = mix(c, hex('#1c0e36'), 0.5);
      void off;
    }
    im.set(x, y, c);
  }
  im.outline(m, INK);
  // glass: night sky, lead grid, stars
  const night = H('#0a0620 #140a38 #1e1052 #2b1a6e');
  for (let y = CY - RI - 1; y < 130; y++) for (let x = CX - RI; x < CX + RI; x++) {
    if (!inInner(x, y)) continue;
    const u = x - (CX - RI), v = y - (CY - RI);
    let c = im.ramp(night, (y - 58) / 72, x, y, 2);
    const lead = (u % 12 === 0) || (v % 12 === 0) || u === 47 || (u === 23 || u === 24) || (y === 108 || y === 109);
    const pc = Math.floor(u / 12), pr = Math.floor(v / 12);
    if (!lead) {
      if (hash(pc, pr) < 0.34 && u % 12 === 6 && v % 12 === 5) c = hex('#f6eeff');
      if (hash(pc, pr) < 0.34 && ((u % 12 === 5 || u % 12 === 7) && v % 12 === 5 || u % 12 === 6 && (v % 12 === 4 || v % 12 === 6))) c = hex('#8a78c8');
      const gl = (u % 12) - (v % 12); if ((pc + pr) % 3 === 0 && (gl === 7 || gl === 8) && (v % 12) > 1 && (v % 12) < 6) c = mix(c, hex('#6a58b8'), 0.7);
      // inner shadow: left and top reveal
      if (u < 2 || v < 2 && y > CY - 2) c = mix(c, hex('#050212'), 0.55);
    } else c = (u === 23 || u === 24 || y === 108 || y === 109) ? hex('#2a1a4a') : hex('#1a0c34');
    if (lead && (u === 24 || y === 108) && !((u % 12 === 0))) c = hex('#3a2a5e');
    im.set(x, y, c);
  }
  // frame ink bottom: shadow under the sill handled above
}

function banner(im, x0, w, pal, emblem, warm) {
  const yTop = 14, yBot = 66, yNotch = 53, cx = x0 + w / 2;
  const pts = [[x0, yTop + 2], [x0 + w, yTop + 2], [x0 + w, yBot], [cx, yNotch], [x0, yBot]];
  const gold = H('#ffc075 #ffa033 #a6643c #5a3a22');
  // cast shadow on the wall
  im.poly(pts.map(p => [p[0] + 5, p[1] + 4]), (x, y) => { im.tint(x, y, 0.7, hex('#0c0418'), 0.55, 4); return null; });
  const mask = maskOf(im, pts);
  im.poly(pts, (x, y) => {
    const f = Math.sin((x - x0) / w * Math.PI * 2 * 3.5 + 0.5) * 0.5 + 0.5, dn = (y - yTop) / (yBot - yTop);
    let v = clamp(0.2 + f * 0.62 - dn * 0.1);
    // dark rim near the right side, light on the left
    v = clamp(v + ((x - x0) < 5 ? 0.12 : 0) - ((x0 + w - x) < 5 ? 0.15 : 0));
    let c = im.ramp(pal, v, x, y, 3);
    // trim on every edge (2px, gold) via polygon test 2px inside
    const edge = !pip(pts, x - 2, y) || !pip(pts, x + 2, y) || (y > yBot - 12 && !pip(pts, x, y + 2));
    const edge1 = !pip(pts, x - 1, y) || !pip(pts, x + 1, y) || (y > yBot - 12 && !pip(pts, x, y + 1));
    if (edge1) c = gold[2]; else if (edge) c = f > 0.5 ? gold[0] : gold[1];
    if (y < yTop + 8) { c = y === yTop + 7 ? gold[2] : mix(c, hex('#1a0c34'), 0.25); if (y === yTop + 6) c = gold[1]; if (!edge1 && !edge && (x - x0) % 8 === 4 && y === yTop + 3) c = gold[0]; }
    return c;
  });
  im.outline(mask, INK);
  // emblem
  const ex = Math.round(cx), ey = 35;
  if (emblem === 'diamond') {
    for (let y = -11; y <= 11; y++) for (let x = -11; x <= 11; x++) { const d = Math.abs(x) + Math.abs(y); if (d <= 11) { const c = d >= 10 ? gold[2] : d >= 8 ? (x + y < 0 ? gold[0] : gold[1]) : d >= 6 ? mix(pal[1], hex('#1a0c34'), 0.4) : d >= 3 ? (x + y < 0 ? gold[0] : gold[1]) : gold[2]; im.set(ex + x, ey + y, c); } }
    im.set(ex, ey, gold[0]);
  } else {
    im.ell(ex, ey, 11, 11, (x, y, q, dx, dy) => q > 0.88 ? gold[2] : q > 0.66 ? (dx + dy < 0 ? gold[0] : gold[1]) : q > 0.52 ? mix(pal[1], hex('#3a0c34'), 0.4) : null);
    for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2 + Math.PI / 4; for (let t = 0; t < 6; t++) im.set(ex + Math.cos(a) * t, ey + Math.sin(a) * t, t > 3 ? gold[2] : (k < 2 ? gold[0] : gold[1])); }
    im.rect(ex - 1, ey - 1, 3, 3, gold[0]);
  }
  // rod, finials, cords
  for (let x = x0 - 5; x <= x0 + w + 5; x++) { im.set(x, 12, gold[0]); im.set(x, 13, gold[1]); im.set(x, 14, gold[2]); im.set(x, 15, gold[3]); }
  for (const bx of [x0 - 6, x0 + w + 6]) im.ell(bx, 13, 3, 3, (x, y, q, dx, dy) => q > 0.85 ? gold[3] : dx + dy < -0.3 ? gold[0] : gold[1]);
  for (const cxp of [x0 + 6, x0 + w - 6]) { im.vl(cxp, 10, 11, hex('#7a5a3a')); im.set(cxp - 1, 11, hex('#5a3a22')); }
  // tassels
  for (const tx of [x0 + 3, x0 + w - 3, Math.round(cx)]) { const ty = tx === Math.round(cx) ? yNotch + 3 : yBot + 1; im.vl(tx, ty, ty + 3, gold[1]); im.vl(tx - 1, ty + 2, ty + 5, gold[0]); im.vl(tx + 1, ty + 2, ty + 5, gold[2]); im.set(tx, ty + 4, gold[2]); }
  // torchlight on the fabric
  for (let y = yTop; y < yBot + 6; y++) for (let x = x0 - 2; x < x0 + w + 2; x++) if (mask[y * im.w + x]) im.tint(x, y, warm(x, y) * 0.9, hex('#ffb070'), 0.5, 4);
}

function torch(im, cx, cy) {
  // sooty stain above the flame
  for (let y = 12; y < cy - 22; y++) for (let x = cx - 9; x <= cx + 9; x++) im.tint(x, y, (1 - Math.abs(x - cx) / 9) * (y - 12) / (cy - 34) * 0.6, hex('#0e0620'), 0.6, 4);
  // bracket plate behind handle + shadow
  for (let y = 58; y < 92; y++) for (let x = cx + 3; x < cx + 9; x++) im.tint(x, y, 0.8, hex('#0c0418'), 0.45, 4);
  const iron = H('#c9b8e8 #8a7aa8 #4a3e68 #1c1230');
  im.rect(cx - 6, 86, 13, 7, iron[2]); im.hl(cx - 6, cx + 6, 86, iron[1]); im.hl(cx - 6, cx + 6, 92, iron[3]); im.vl(cx - 6, 86, 92, iron[3]); im.vl(cx + 6, 86, 92, iron[3]);
  im.set(cx - 4, 88, iron[0]); im.set(cx + 4, 88, iron[0]); im.set(cx - 4, 90, iron[0]); im.set(cx + 4, 90, iron[0]);
  // wooden handle
  const wood = H('#a07a52 #7a5438 #5a3a24 #3a2214');
  for (let y = cy + 6; y < 90; y++) { im.set(cx - 2, y, wood[0]); im.set(cx - 1, y, wood[1]); im.set(cx, y, wood[1]); im.set(cx + 1, y, wood[2]); im.set(cx + 2, y, wood[3]); if (y % 9 === 4) { im.hl(cx - 2, cx + 1, y, wood[2]); } }
  for (const ry of [62, 76]) { im.hl(cx - 3, cx + 3, ry, iron[1]); im.hl(cx - 3, cx + 3, ry + 1, iron[2]); im.hl(cx - 3, cx + 3, ry + 2, iron[3]); im.set(cx - 3, ry, iron[0]); }
  // cup (iron, flared)
  for (let y = 0; y < 6; y++) { const hw = 7 - y * 0.7; for (let x = Math.round(cx - hw); x <= Math.round(cx + hw); x++) im.set(x, cy + y, y === 0 ? iron[0] : x < cx - hw + 2 ? iron[1] : x > cx + hw - 2 ? iron[3] : iron[2]); }
  im.hl(cx - 7, cx + 7, cy, iron[0]); im.hl(cx - 4, cx + 4, cy + 6, iron[3]);
  // flame
  const fc = H('#ff4a1c #ff7a28 #ffa033 #ffc075 #fff0b8');
  const hF = 26;
  for (let y = cy - hF; y < cy; y++) {
    const u = (cy - y) / hF, hw = 7 * Math.pow(Math.sin(Math.PI * clamp((u + 0.1) / 1.1)), 0.8) * (u < 0.08 ? 0.8 : 1), sway = 3.2 * u * u;
    for (let x = Math.round(cx + sway - hw); x <= Math.round(cx + sway + hw); x++) {
      const q = Math.abs(x - (cx + sway * 0.8)) / Math.max(1, hw);
      let ci = q > 0.8 ? 0 : q > 0.58 ? 1 : q > 0.38 ? 2 : u < 0.62 ? (q > 0.2 ? 3 : 4) : 3; if (u > 0.82) ci = Math.min(ci, 2) ; if (u > 0.9) ci = 1; if (u < 0.08 && q > 0.5) ci = 0;
      im.set(x, y, fc[ci]);
    }
  }
  im.set(cx + 5, cy - hF - 3, fc[2]); im.set(cx - 5, cy - hF + 4, fc[1]); im.set(cx + 9, cy - 20, fc[3]); im.set(cx - 9, cy - 12, fc[2]); im.set(cx + 7, cy - hF - 8, fc[1]);
  // tight glow ring around the flame
  for (let y = cy - 40; y < cy + 12; y++) for (let x = cx - 24; x < cx + 24; x++) { const d = Math.hypot((x - cx) * 1.1, (y - (cy - 12)) * 0.8); if (d > 8) im.tint(x, y, Math.pow(clamp(1 - d / 26), 2) * 0.45, hex('#ffc075'), 0.8, 4); }
}

function rack(im) {
  const x0 = 288, y0 = 166, w = 52, h = 58;
  const wood = H('#a07a52 #7a5438 #5a3a24 #3a2214'), st = H('#fbf6ff #c9b8e8 #8e7cb8 #5a4a88 #2e2250');
  // wall shadow
  rackShadow(im, x0, y0, w, h);
  const m = new Uint8Array(im.w * im.h);
  const box = (x, y, bw, bh, c) => { im.rect(x, y, bw, bh, c); for (let j = 0; j < bh; j++) for (let i = 0; i < bw; i++) m[(y + j) * im.w + x + i] = 1; };
  const post = (x) => { box(x, y0, 6, h, wood[1]); im.vl(x, y0, y0 + h - 1, wood[0]); im.vl(x + 1, y0, y0 + h - 1, wood[0]); im.vl(x + 5, y0, y0 + h - 1, wood[2]); im.vl(x + 4, y0, y0 + h - 1, wood[2]); for (let y = y0 + 6; y < y0 + h; y += 11) im.hl(x + 2, x + 3, y, wood[3]); };
  post(x0); post(x0 + w - 6);
  box(x0 + 6, y0, w - 12, 6, wood[1]); im.hl(x0 + 6, x0 + w - 7, y0, wood[0]); im.hl(x0 + 6, x0 + w - 7, y0 + 5, wood[3]);
  for (const sy of [y0 + 18, y0 + 38]) { box(x0 + 6, sy, w - 12, 5, wood[1]); im.hl(x0 + 6, x0 + w - 7, sy, wood[0]); im.hl(x0 + 6, x0 + w - 7, sy + 3, wood[2]); im.hl(x0 + 6, x0 + w - 7, sy + 4, wood[3]); }
  // iron brackets
  for (const [bx, by] of [[x0, y0], [x0 + w - 6, y0], [x0, y0 + 50], [x0 + w - 6, y0 + 50]]) { im.rect(bx, by, 6, 4, st[3]); im.hl(bx, bx + 5, by, st[2]); im.set(bx + 1, by + 1, st[1]); im.set(bx + 4, by + 1, st[1]); }
  im.outline(m, INK);
  // dumbbells
  const dumb = (xa, xb, yBase, hh, hw, hd) => {
    const hy = yBase - hh, my = hy + (hh >> 1) - 2;
    for (const hx of [xa, xb - hw]) { for (let j = 0; j < hh; j++) for (let i = 0; i < hw; i++) { const c = j === 0 ? st[0] : j === 1 ? st[1] : j >= hh - 2 ? st[3] : j >= hh - 4 ? st[2] : st[1]; im.set(hx + i, hy + j, i === 0 && j > 0 && j < hh - 1 ? st[0] : i === hw - 1 ? st[3] : c); } for (let i = 0; i < hw; i++) { im.set(hx + i, hy - 1, INK); im.set(hx + i, hy + hh, INK); } for (let j = -1; j <= hh; j++) { im.set(hx - 1, hy + j, INK); im.set(hx + hw, hy + j, INK); } if (hd) { im.hl(hx + 1, hx + hw - 2, hy + (hh >> 1), st[3]); im.hl(hx + 1, hx + hw - 2, hy + (hh >> 1) + 1, st[4]); } }
    for (let x = xa + hw; x < xb - hw; x++) { const k = (x % 2); im.set(x, my, st[0]); im.set(x, my + 1, k ? st[1] : st[0]); im.set(x, my + 2, k ? st[2] : st[1]); im.set(x, my + 3, st[3]); im.set(x, my - 1, INK); im.set(x, my + 4, INK); }
    im.rect(xa + hw, my - 1, 1, 6, INK); im.rect(xb - hw - 1, my - 1, 1, 6, INK);
  };
  dumb(x0 + 7, x0 + w - 7, y0 + 18, 12, 6, false);
  dumb(x0 + 7, x0 + w - 7, y0 + 38, 16, 8, true);
}
function rackShadow(im, x0, y0, w, h) { /* shadow on the wall to the right/below, applied by tint */ for (let y = y0 + 3; y < y0 + h + 4; y++) for (let x = x0 + 4; x < x0 + w + 5; x++) { im.tint(x, y, 0.8, hex('#0c0418'), 0.5, 4); } }

function gainsFloor() {
  const W = 350, Hh = 72, im = new Img(W, Hh);
  const rows = [16, 18, 18, 20], wl = [52, 64, 46, 70, 58, 66];
  const T = H('#8672a5 #8e7aae #7d6a9e #9382b2 #8a76aa');
  const hiC = hex('#c4aee4'), hi2 = hex('#a88fd0'), shC = hex('#6a5690'), dpC = hex('#4e3c7c');
  im.rect(0, 0, W, Hh, hex('#2a1148'));
  let y0 = 0;
  rows.forEach((h, r) => {
    const rr = rng(40 + r); let x = -Math.floor(rr() * 50) - 8, k = r * 2;
    while (x < W) {
      const bw = wl[k++ % wl.length]; const ti = Math.floor(hash(r, k) * 5), t = T[ti];
      for (let v = 0; v < h - 2; v++) for (let u = 2; u < bw; u++) {
        const px = x + u, py = y0 + v; if (px < 0 || px >= W) continue;
        let c = t;
        if (v === 0) c = hiC; else if (v === 1) c = hi2; else if (v >= h - 5) c = v === h - 3 ? dpC : shC; else if (v > h * 0.45) c = im.ramp([t, shC], (v - h * 0.45) / (h * 0.45) * 0.8, px, py, 2);
        if (u === 2 && v > 0 && v < h - 4) c = mix(c, hi2, 0.5); if (u === bw - 1 && v > 1) c = mix(c, shC, 0.7);
        im.set(px, py, c);
      }
      for (let u = 0; u < bw; u++) { im.set(x + u, y0 + h - 2, hex('#3d255b')); im.set(x + u, y0 + h - 1, hex('#2a1148')); }
      for (let v = 0; v < h; v++) { im.set(x, y0 + v, hex('#3d255b')); im.set(x + 1, y0 + v, hex('#2a1148')); }
      if (hash(r + 3, k) < 0.4) { const gx = x + 8 + Math.floor(hash(k, r) * 12); for (let i = 0; i < 9; i++) im.set(gx + i, y0 + 3, hex('#d8c8f0')); }
      x += bw;
    }
    y0 += h;
  });
  // cracks
  const cd = hex('#3a2868'), cl = hex('#a88fd0');
  crack(im, [[250, 4], [254, 10], [251, 14], [258, 20], [256, 27]], cd, cl);
  crack(im, [[300, 22], [296, 28], [301, 34], [298, 40], [304, 45], [302, 52]], cd, cl);
  crack(im, [[130, 38], [135, 44], [132, 50], [138, 56]], cd, cl);
  crack(im, [[60, 60], [66, 64], [63, 70]], cd, cl);
  // wall plinth contact shadow
  for (let y = 0; y < 5; y++) for (let x = 0; x < W; x++) im.tint(x, y, (1 - y / 5) * 0.8, hex('#1a0838'), 0.8, 4);
  // rug (training mat), skewed
  const L = t => 24 - 22 * t, Rr = t => 220 - 16 * t, Y0 = 29, Y1 = 63;
  const gold = H('#ffc075 #ffa033 #a6643c'), mag = H('#8a2f6e #a63e84 #b8498f'), pink = hex('#ff5fb0');
  // soft shadow of the rug on the stone
  for (let y = Y0 + 2; y < Y1 + 4; y++) { const t = clamp((y - Y0) / (Y1 - Y0)); for (let x = Math.round(L(t)) + 2; x < Math.round(Rr(t)) + 4; x++) im.tint(x, y, 0.45, hex('#1a0838'), 0.5, 3); }
  for (let y = Y0 - 1; y <= Y1 + 1; y++) {
    const t = clamp((y - Y0) / (Y1 - Y0)), l = Math.round(L(t)), r = Math.round(Rr(t));
    for (let x = l - 1; x <= r + 1; x++) {
      let c; const dl = x - l, dr = r - x, dt = y - Y0, db = Y1 - y;
      const d = Math.min(dl, dr, dt, db);
      if (d < 0) c = INK; else if (d === 0) c = INK; else if (d <= 3) c = (dt === d || (dt <= 3 && dt === d)) ? gold[0] : (db === d ? gold[2] : gold[1]);
      else if (d === 4) c = INK;
      else if (d === 6) c = pink;
      else {
        c = im.ramp(mag, 0.15 + (y - Y0) / (Y1 - Y0) * 0.3 + (x % 2 === 0 && y % 2 === 0 ? 0.04 : 0), x, y, 3);
        // motif band along top and bottom of the field
        if ((dt >= 8 && dt <= 12) || (db >= 8 && db <= 12)) { const j = ((x - l + (y % 2 ? 4 : 0)) % 8); const dd = Math.abs(j - 4) + Math.abs(((dt <= 12 ? dt : db) - 10)); if (dd <= 2) c = dd < 1 ? hex('#ffc075') : hex('#d44a9a'); }
      }
      if (d >= 0 && d <= 3 && dl <= 3 && dl !== d) c = gold[1];
      im.set(x, y, c);
    }
    if (y > Y0 + 1 && y < Y1 && y % 2 === 0) { const l2 = Math.round(L(t)); const r2 = Math.round(Rr(t)); for (let i = 2; i <= 5; i++) { im.set(l2 - i - 1, y, hex('#ecd7d0')); im.set(r2 + i + 1, y, hex('#ecd7d0')); } im.set(l2 - 6, y, hex('#b89a98')); im.set(r2 + 6, y, hex('#b89a98')); }
  }
  return im;
}

// ============================================================
// RUSTBELT  (rusty industrial dusk)
// ============================================================
function rustBackground() {
  const W = 350, Hh = 300, im = new Img(W, Hh), SX = 88, SY = 152, SR = 46;
  // banded sunset sky (hard bands, dithered only between neighbours)
  const sky = H('#0f0620 #1a0b3b #2a1148 #411a5e #62245f #8c3a5c #bb5252 #e57a3e #ffa033 #ffc075');
  for (let y = 0; y < 230; y++) for (let x = 0; x < W; x++) im.set(x, y, im.ramp(sky, clamp(Math.pow(y / 190, 1.35)), x, y, 4.5));
  // halo
  for (let y = 60; y < 200; y++) for (let x = 0; x < 200; x++) { const d = Math.hypot(x - SX, (y - SY) * 1.1); if (d > SR) im.tint(x, y, Math.pow(clamp(1 - (d - SR) / 70), 1.8) * 0.7, hex('#ffb865'), 0.85, 5); }
  // sun with slits
  const sunC = H('#fff6c8 #ffe49a #ffc866 #ffa33a #ff7a3c #e0503e');
  im.ell(SX, SY, SR, SR, (x, y, q, dx, dy) => {
    if (y >= 146) { const band = Math.floor((y - 146) / 9), th = Math.min(6, 1 + band); if ((y - 146) % 9 >= 9 - th) return null; }
    return im.ramp(sunC, (y - (SY - SR)) / (2 * SR) * 0.95, x, y, 2.6);
  });
  // stratus clouds: dark body, sun-lit underside
  const strat = (cx, cy, w, h, seed) => {
    const rr = rng(seed);
    for (let x = Math.round(cx - w / 2); x <= cx + w / 2; x++) {
      const t = (x - cx) / (w / 2), topH = h * Math.sqrt(Math.max(0, 1 - t * t)) * (0.75 + 0.25 * Math.sin(x * 0.4 + seed)), botH = Math.max(1, topH * 0.35);
      for (let y = Math.round(cy - topH); y <= cy + botH; y++) { const d = y - cy; let c = hex('#3a1a52'); if (y < cy - topH + 1.5) c = hex('#5a2a60'); if (d > botH - 1.6) c = hex('#e5683e'); if (d > botH - 0.6) c = hex('#ffa033'); if (d > botH - 2.6 && d <= botH - 1.6) c = hex('#8a3a5a'); im.set(x, y, c); }
    }
    void rr;
  };
  strat(70, 66, 100, 7, 1); strat(30, 96, 60, 5, 2); strat(150, 118, 90, 4, 3); strat(120, 138, 70, 3, 4);
  strat(270, 36, 130, 7, 5); strat(300, 54, 60, 4, 6); strat(180, 40, 60, 4, 7);
  // far hills (hazy)
  const hill = x => 176 + 7 * Math.sin(x / 41) + 4 * Math.sin(x / 14 + 1) + 3 * Math.sin(x / 7.3);
  for (let x = 0; x < W; x++) { const t = Math.round(hill(x)); for (let y = t; y < 232; y++) { const c = y === t ? hex('#8a4252') : y < t + 3 ? hex('#6a3450') : im.ramp(H('#5a2c4c #4a2640 #3b2230'), (y - t) / 52, x, y, 2); im.set(x, y, c); } }
  // mid layer: industrial silhouettes with sun rim on the left edge
  const sil = (shape, base, rim, dark) => {
    const m = new Uint8Array(W * Hh); shape((x, y) => { if (x >= 0 && y >= 0 && x < W && y < Hh) m[y * W + x] = 1; });
    for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) if (m[y * W + x]) { const l = x > 0 && !m[y * W + x - 1], t = y > 0 && !m[(y - 1) * W + x], r = x < W - 1 && !m[y * W + x + 1]; im.set(x, y, l ? rim : t ? mix(rim, base, 0.6) : r ? dark : base); }
  };
  const rect = (put, x, y, w, h) => { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) put(x + i, y + j); };
  const MID = hex('#47223e'), MRIM = hex('#a04a4a'), MDK = hex('#331a34');
  // cooling tower
  sil(put => { for (let y = 150; y < 230; y++) { const u = (y - 150) / 80, hw = 11 + 6 * Math.pow(Math.abs(u - 0.38) * 1.6, 2) * (u < 0.38 ? 0.9 : 1.1) - (u < 0.38 ? 3 * u : 0); for (let x = Math.round(158 - hw); x <= Math.round(158 + hw); x++) put(x, y); } }, MID, MRIM, MDK);
  // chimneys with bands
  const chim = (x, top, w) => sil(put => { for (let y = top; y < 230; y++) { const hw = w / 2 + (y - top) * 0.045; for (let k = Math.round(x - hw); k <= Math.round(x + hw); k++) put(k, y); } rect(put, x - w / 2 - 2, top - 2, w + 4, 3); }, MID, MRIM, MDK);
  chim(26, 112, 8); chim(46, 126, 7); chim(126, 136, 7); chim(176, 146, 6);
  for (const [x, top] of [[26, 112], [46, 126], [126, 136]]) for (let k = 0; k < 3; k++) { const y = top + 6 + k * 14; for (let i = -4; i <= 4; i++) im.set(x + i, y, hex('#a03a3a')); for (let i = -4; i <= 4; i++) im.set(x + i, y + 1, hex('#6a2a34')); }
  // tank farm and shed (kept hazy and low-contrast behind the scrap)
  const TANK = hex('#4a2644'), TR = hex('#8a4452'), TD = hex('#36203a');
  for (const tx of [236, 270, 304]) sil(put => { rect(put, tx - 13, 190, 26, 36); for (let k = 0; k < 6; k++) rect(put, tx - 12 + k * 2 + 2, 187 + (k < 3 ? 3 - k : k - 2), 22 - k * 4 < 0 ? 0 : 22 - 2 * k < 0 ? 0 : 22 - 2 * k - 4 > 0 ? 22 - 2 * k - 4 : 0, 1); }, TANK, TR, TD);
  // smoke plumes
  const smoke = (x0, y0, seed, n) => { const rr = rng(seed); for (let k = 0; k < n; k++) { const x = x0 + k * 5.5 + Math.sin(k * 0.8 + seed) * 4, y = y0 - k * 8.5, r = 4 + k * 1.7 + rr() * 1.5; for (let yy = Math.floor(y - r); yy <= y + r; yy++) for (let xx = Math.floor(x - r); xx <= x + r; xx++) { const d = Math.hypot(xx - x, yy - y) / r; if (d > 1) continue; const dens = (1 - d * 0.55) * (1 - k / (n + 2)) * 0.95; const lit = (xx - x) < -r * 0.2 && (yy - y) > r * 0.1; im.tint(xx, yy, dens, lit ? hex('#8a3a58') : hex('#3a1a48'), 0.85, 5); } } };
  smoke(27, 108, 3, 7); smoke(47, 122, 7, 6); smoke(127, 132, 11, 7); smoke(159, 146, 5, 5);
  // near layer: factory with sawtooth roof, pipes, a few lit windows
  const NEAR = hex('#251232'), NRIM = hex('#8a3a40');
  sil(put => {
    rect(put, 0, 202, 178, 30);
    for (let k = 0; k < 8; k++) { const x0 = k * 23 - 4; for (let i = 0; i < 23; i++) { const h = Math.round(i * 10 / 22); rect(put, x0 + i, 192 + (10 - h), 1, h + 10 - (10 - h) > 0 ? 10 - (10 - h) + 1 : 1); } }
    rect(put, 108, 176, 6, 30); rect(put, 106, 174, 10, 3);
  }, NEAR, NRIM, hex('#190c26'));
  for (let k = 0; k < 14; k++) for (const wy of [210]) { const x = 6 + k * 12; const litW = hash(k, 5) < 0.34; im.rect(x, wy, 4, 6, litW ? hex('#ffa033') : hex('#3a1a44')); if (litW) { im.hl(x, x + 3, wy, hex('#ffe090')); im.hl(x, x + 3, wy + 5, hex('#c0602a')); } else im.hl(x, x + 3, wy, hex('#5a2a50')); }
  for (let x = 0; x < 178; x++) { im.set(x, 200, hex('#5a2a48')); im.set(x, 201, hex('#1a0c28')); } // pipe run
  for (let x = 6; x < 178; x += 22) { im.vl(x, 201, 206, hex('#3a1a3a')); im.vl(x + 1, 201, 206, hex('#1a0c28')); }
  // ground strip behind the curb
  for (let y = 206; y < 232; y++) for (let x = 0; x < W; x++) if (y > 213 || x > 178) im.set(x, y, im.ramp(H('#3b2230 #2a1430'), (y - 206) / 26, x, y, 2));
  for (let x = 0; x < W; x++) { im.set(x, 213, hex('#7a3a46')); }
  // wires (draw before pole and sign)
  const wire = (x0, y0, x1, y1, sag) => { let px = x0, py = y0; const n = Math.abs(x1 - x0); for (let i = 1; i <= n; i++) { const t = i / n, x = x0 + (x1 - x0) * t, y = y0 + (y1 - y0) * t + sag * 4 * t * (1 - t) * 0 + sag * t * t; im.line(px, py, x, y, hex('#1a0a26')); if (i % 13 === 2) im.set(x, y - 1, hex('#c96a44')); px = x; py = y; } };
  for (const [ix, iy, lx, ly] of [[82, 70, -4, 84], [90, 70, -4, 94], [112, 70, -4, 106]]) wire(ix, iy, lx, ly, 0);
  for (const [ix, iy, rx, ry] of [[106, 70, 355, 118], [114, 70, 355, 132], [122, 70, 355, 100]]) wire(ix, iy, rx, ry, 0);
  // curb
  for (let y = 214; y < 228; y++) for (let x = 0; x < W; x++) {
    let c;
    if (y === 214) c = hex('#ffd9b0'); else if (y < 217) c = hex('#f4e0d6'); else if (y === 217) c = hex('#c9a4a0'); else if (y < 224) c = im.ramp(H('#e0c8c4 #c9aaa8 #a88a90'), (y - 218) / 6, x, y, 2); else if (y < 227) c = hex('#8a6a78'); else c = hex('#4a3040');
    if (y >= 214 && y < 218 && x < 130) c = mix(c, hex('#ffc075'), 0.35 * (1 - x / 130));
    im.set(x, y, c);
  }
  for (let jx = 30; jx < W; jx += 62) { im.vl(jx, 214, 227, hex('#6a4a58')); im.vl(jx + 1, 215, 223, hex('#fff0e8')); }
  crack(im, [[78, 218], [81, 222], [79, 226]], hex('#5a3a4a'), null); crack(im, [[250, 219], [253, 223]], hex('#5a3a4a'), null);
  for (const [cx0, cy0] of [[140, 214], [300, 214]]) { im.rect(cx0, cy0, 4, 2, hex('#a88a90')); im.rect(cx0 + 1, cy0 + 2, 2, 1, hex('#6a4a58')); }
  // pole
  pole(im);
  // utility box
  utilBox(im);
  // sign legs and board
  signBoard(im);
  // scrap heap
  scrapPile(im);
  for (let y = 228; y < Hh; y++) for (let x = 0; x < W; x++) im.set(x, y, hex('#4a2c44'));
  return im;
}

function pole(im) {
  const x0 = 97, top = 60, bot = 228;
  const wd = H('#9a5a3a #6b3c2e #4a2a26 #2e1a22');
  for (let y = top; y < bot; y++) for (let i = 0; i < 10; i++) {
    let c = i === 0 ? hex('#ff9a48') : i < 3 ? wd[0] : i < 6 ? wd[1] : i < 8 ? wd[2] : wd[3];
    if (i === 0) c = hex('#e8703c'); if ((i === 3 || i === 5) && ((y * 7 + i * 13) % 31) < 18) c = i === 3 ? wd[1] : wd[2];
    if (i === 4 && y % 23 > 17) c = wd[2];
    im.set(x0 + i, y, c);
  }
  for (let i = 0; i < 10; i++) { const d = Math.abs(i - 4.5); im.vl(x0 + i, top - Math.round(3 - d * 0.6), top, i === 0 ? hex('#e8703c') : wd[Math.min(3, Math.floor(i / 3))]); }
  // knots and steps
  for (const ky of [88, 120, 154, 186]) { im.rect(x0 + 3, ky, 3, 2, wd[3]); im.set(x0 + 2, ky, wd[2]); }
  for (let y = 100; y < 226; y += 16) { const side = (y / 16) % 2; im.rect(side ? x0 + 10 : x0 - 3, y, 3, 2, wd[3]); im.set(side ? x0 + 10 : x0 - 3, y, wd[0]); }
  // cross arms with braces
  const arm = (y, hw, br) => {
    for (let x = x0 + 5 - hw; x <= x0 + 5 + hw; x++) { im.set(x, y, hex('#d08050')); im.set(x, y + 1, wd[0]); im.set(x, y + 2, wd[1]); im.set(x, y + 3, wd[2]); im.set(x, y + 4, wd[3]); }
    for (let k = 0; k < br; k++) { im.set(x0 - 1 - k, y + 5 + k, wd[1]); im.set(x0 + 10 + k, y + 5 + k, wd[2]); im.set(x0 - k, y + 5 + k, wd[2]); im.set(x0 + 9 + k, y + 5 + k, wd[3]); }
  };
  arm(68, 28, 8); arm(90, 20, 6);
  for (const x of [82, 90, 106, 114, 122]) { im.rect(x - 1, 63, 3, 3, hex('#c9b8e8')); im.set(x, 62, hex('#fbf6ff')); im.rect(x - 1, 66, 3, 2, hex('#3a3a70')); }
  for (const x of [88, 100, 112]) { im.rect(x - 1, 85, 3, 3, hex('#c9b8e8')); im.set(x, 84, hex('#fbf6ff')); im.rect(x - 1, 88, 3, 2, hex('#3a3a70')); }
  // transformer can
  const tc = H('#c9a898 #8a6a72 #5a4458 #34243c');
  for (let y = 112; y < 138; y++) for (let x = x0 + 10; x < x0 + 24; x++) { const k = (x - x0 - 10) / 13; im.set(x, y, k < 0.15 ? tc[0] : k < 0.5 ? tc[1] : k < 0.85 ? tc[2] : tc[3]); }
  for (let x = x0 + 10; x < x0 + 24; x++) { im.set(x, 112, tc[0]); im.set(x, 113, tc[1]); im.set(x, 137, INK); im.set(x, 125, tc[3]); }
  im.rect(x0 + 14, 107, 6, 5, tc[2]); im.set(x0 + 15, 107, tc[0]); im.set(x0 + 15, 104, hex('#c9b8e8')); im.rect(x0 + 14, 105, 2, 2, hex('#3a3a70'));
  im.vl(x0 + 10, 112, 137, INK); im.vl(x0 + 23, 112, 137, INK);
}

function utilBox(im) {
  const x0 = 134, y0 = 166, w = 18, h = 61;
  const m = new Uint8Array(im.w * im.h);
  const body = H('#6a5a98 #4a3c7a #342a5c #221a42');
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
    const rx = Math.min(x - x0, x0 + w - 1 - x), ry = y - y0; if (ry < 3 && rx < 3 - ry) continue;
    const k = (x - x0) / (w - 1); let c = k < 0.18 ? body[0] : k < 0.55 ? body[1] : k < 0.85 ? body[2] : body[3]; if (ry < 2) c = body[0];
    m[y * im.w + x] = 1; im.set(x, y, c);
  }
  // pipe on the left
  for (let y = 182; y < 190; y++) for (let x = x0 - 14; x < x0; x++) { const k = (y - 182) / 7; m[y * im.w + x] = 1; im.set(x, y, k < 0.2 ? body[0] : k < 0.6 ? body[1] : body[3]); }
  for (let y = 190; y < y0 + h - 2; y++) for (let x = x0 - 14; x < x0 - 8; x++) { const k = (x - x0 + 14) / 5; m[y * im.w + x] = 1; im.set(x, y, k < 0.2 ? body[0] : k < 0.6 ? body[1] : body[3]); }
  im.outline(m, INK);
  im.hl(x0 - 15, x0 - 1, 186, INK);
  // panel, vent slats, lamps, rust streaks
  im.rect(x0 + 3, y0 + 4, 12, 22, body[3]); im.rect(x0 + 4, y0 + 5, 10, 20, body[2]);
  for (const lx of [x0 + 5, x0 + 10]) { im.rect(lx, y0 + 8, 3, 3, hex('#ffa033')); im.set(lx, y0 + 8, hex('#ffe090')); im.hl(lx, lx + 2, y0 + 11, hex('#7a3a20')); }
  for (let k = 0; k < 6; k++) { im.hl(x0 + 5, x0 + 12, y0 + 30 + k * 3, body[3]); im.hl(x0 + 5, x0 + 12, y0 + 31 + k * 3, body[0]); }
  for (let y = y0 + 40; y < y0 + h; y++) for (const sx of [x0 + 3, x0 + 12]) if (hash(sx, y >> 2) < 0.7) im.tint(sx, y, 0.9, hex('#a6643c'), 0.55, 3);
  im.rect(x0 + 6, y0 + 56, 6, 1, hex('#a6643c'));
  im.rect(x0 - 2, y0 + h - 2, w + 4, 2, hex('#2a2040')); im.hl(x0 - 2, x0 + w + 1, y0 + h - 2, hex('#6a5a98'));
}

function signBoard(im) {
  const bx = 188, by = 64, bw = 154, bh = 98;
  const st = H('#a8643c #7a4a35 #5a3a2c #3a2420');
  // legs with cross brace
  for (const lx of [206, 316]) {
    for (let y = by + bh; y < 228; y++) for (let i = 0; i < 9; i++) im.set(lx + i, y, i === 0 ? hex('#e8803c') : i < 3 ? st[0] : i < 6 ? st[1] : i < 8 ? st[2] : st[3]);
    im.vl(lx - 1, by + bh, 227, INK); im.vl(lx + 9, by + bh, 227, INK);
    im.rect(lx - 3, 222, 15, 6, st[2]); im.hl(lx - 3, lx + 11, 222, st[0]); im.hl(lx - 3, lx + 11, 227, st[3]); im.set(lx - 1, 224, hex('#c98050')); im.set(lx + 9, 224, hex('#c98050'));
  }
  // diagonal braces between the legs
  im.line(215, 172, 316, 220, hex('#2e1a1c')); im.line(215, 173, 316, 221, st[2]); im.line(316, 172, 215, 220, hex('#2e1a1c')); im.line(316, 173, 215, 221, st[2]);
  // lamps on top
  for (const lx of [236, 296]) { im.vl(lx, 52, by, hex('#2e1a1c')); im.vl(lx + 1, 52, by, st[1]); im.line(lx, 52, lx + 8, 48, hex('#2e1a1c')); im.line(lx + 1, 52, lx + 8, 49, st[1]); im.rect(lx + 6, 48, 9, 5, st[2]); im.hl(lx + 6, lx + 14, 48, st[0]); im.hl(lx + 7, lx + 13, 53, hex('#ffe090')); im.hl(lx + 7, lx + 13, 54, hex('#ffa033')); }
  // frame + face
  const m = new Uint8Array(im.w * im.h); for (let y = by; y < by + bh; y++) for (let x = bx; x < bx + bw; x++) m[y * im.w + x] = 1;
  for (let y = by; y < by + bh; y++) for (let x = bx; x < bx + bw; x++) {
    const dl = x - bx, dr = bx + bw - 1 - x, dt = y - by, db = by + bh - 1 - y, d = Math.min(dl, dr, dt, db);
    let c;
    if (d < 6) { c = d === 0 ? (dt === 0 || dl === 0 ? st[0] : st[1]) : d === 1 ? (dt === 1 || dl === 1 ? hex('#c98050') : st[1]) : d < 4 ? st[1] : d === 4 ? st[2] : hex('#2a1a1c'); if (d >= 1 && d < 4 && (dr === d || db === d)) c = st[2]; }
    else {
      const px = x - (bx + 6), pcol = Math.floor(px / 47), ph = ((pcol + Math.floor((y - by) / 90)) & 1);
      c = ph ? hex('#74513a') : hex('#6b4a35');
      const sm = px % 47; if (sm === 0) c = hex('#3a2018'); else if (sm === 1) c = hex('#8a5a3a');
      if (d === 6) c = hex('#4a2c20'); // inner shadow
      if (y < by + 8) c = mix(c, hex('#4a2c20'), 0.25);
      // rust streaks (below the mark area and on the edges only)
      const sx = (x * 5 + 3) % 37; if (y > by + 54 && sx < 3 && ((x >> 3) % 3 === 0)) c = im.ramp([c, hex('#8a4a2a')], clamp(0.9 - (y - by - 54) / 40 * 0.4), x, y, 3);
      // big soft rust stains: corners and bottom edge only (mark area stays calm)
      for (const [sx2, sy2, sr] of [[bx + 10, by + bh - 8, 26], [bx + bw - 10, by + bh - 8, 24], [bx + 8, by + 10, 14], [bx + bw - 8, by + 8, 16], [bx + 80, by + bh - 6, 20]]) { const dd = Math.hypot((x - sx2) * 0.8, (y - sy2) * 1.3) / sr; if (dd < 1) c = im.ramp([c, hex('#8a4a2a'), hex('#a6582c')], (1 - dd) * 0.75, x, y, 2.2); }
      if ((dl < 16 || dr < 16) && y > by + 30 && ((x * 3 + y) % 29) < 2 && hash(x >> 1, y >> 3) < 0.6) c = hex('#7a4630');
      if (y > by + bh - 16 && y < by + bh - 8) { const s = ((x + y) >> 3) & 1; c = s ? hex('#ffa033') : hex('#2a1a1c'); if (y === by + bh - 16 || y === by + bh - 9) c = hex('#2a1a1c'); }
    }
    im.set(x, y, c);
  }
  im.outline(m, INK);
  // rivets along the frame and seams
  const riv = (x, y) => { im.set(x, y, hex('#e8a070')); im.set(x + 1, y, hex('#c98050')); im.set(x, y + 1, hex('#a6643c')); im.set(x + 1, y + 1, hex('#5a3a2c')); im.set(x + 1, y + 2, hex('#2a1a1c')); };
  for (let x = bx + 8; x < bx + bw - 8; x += 22) { riv(x, by + 2); riv(x, by + bh - 5); }
  for (let y = by + 14; y < by + bh - 10; y += 22) { riv(bx + 2, y); riv(bx + bw - 4, y); }
  for (const sxx of [bx + 6 + 47, bx + 6 + 94]) for (const sy of [by + 12, by + bh - 24]) { riv(sxx - 3, sy); riv(sxx + 2, sy); }
  // stains from rivets (short)
  for (const [x, y] of [[bx + 30, by + bh - 5], [bx + 74, by + bh - 5], [bx + 118, by + bh - 5]]) for (let k = 0; k < 5; k++) im.tint(x, y - 8 + k, 0.6, hex('#8a3a20'), 0.5, 3);
}

function scrapPile(im) {
  const m = new Uint8Array(im.w * im.h); const mark = (x, y) => { if (x >= 0 && y >= 0 && x < im.w && y < im.h) m[y * im.w + x] = 1; };
  const R = H('#2d1a22 #4b2d28 #6b3c2e #8a4e34 #a6643c #d08050 #ff9a48');
  const heap = [[226, 227], [227, 216], [234, 208], [246, 201], [260, 196], [276, 198], [291, 203], [303, 211], [310, 227]];
  im.poly(heap, (x, y) => { mark(x, y); const k = clamp(((y - 196) / 31) * 0.55 + ((x - 226) / 84) * 0.4 + (hash(x >> 3, y >> 2) - 0.5) * 0.12); return im.ramp([R[4], R[3], R[2], R[1], R[0]], k, x, y, 2.5); });
  // sheet-metal plates (quads) with lit top edge and dark underside
  const quad = (cx, cy, w, h, a, tone) => {
    const ca = Math.cos(a), sa = Math.sin(a), p = [[-w / 2, -h / 2], [w / 2, -h / 2], [w / 2, h / 2], [-w / 2, h / 2]].map(([x, y]) => [cx + x * ca - y * sa, cy + x * sa + y * ca]);
    im.poly(p, (x, y) => { mark(x, y); const v = (y - (cy - h / 2)) / h; return v < 0.18 ? R[Math.min(6, tone + 2)] : v < 0.6 ? R[tone] : R[Math.max(0, tone - 1)]; });
    for (let i = 0; i < 4; i++) { const a0 = p[i], b0 = p[(i + 1) % 4]; if (i === 2) im.line(a0[0], a0[1], b0[0], b0[1], R[0]); }
  };
  quad(240, 214, 26, 9, -0.25, 3); quad(262, 205, 30, 8, 0.12, 4); quad(284, 211, 28, 9, -0.3, 3); quad(300, 219, 22, 8, 0.2, 2); quad(252, 222, 34, 7, 0.05, 2);
  // tyres
  const tyre = (cx, cy, ro, ri) => { im.ell(cx, cy, ro, ro, (x, y, q, dx, dy) => { mark(x, y); return q > 0.88 ? hex('#0e0816') : (dx + dy < -0.3 ? hex('#4a3a4a') : hex('#241a2a')); }); im.ell(cx, cy, ri, ri, (x, y, q, dx, dy) => (q > 0.7 ? hex('#6a3c2e') : hex('#1a1220'))); for (let a = 0; a < 12; a++) { const t = a / 12 * Math.PI * 2; im.set(cx + Math.cos(t) * (ro - 1.5), cy + Math.sin(t) * (ro - 1.5), hex('#3a2c3a')); } im.set(cx - ro + 2, cy - 2, hex('#8a6a7a')); im.set(cx - ro + 3, cy - 3, hex('#8a6a7a')); };
  tyre(254, 215, 10, 4); tyre(288, 213, 8, 3);
  // crushed drum
  im.ell(272, 207, 11, 7, (x, y, q, dx, dy) => { mark(x, y); return q > 0.86 ? R[0] : dy < -0.45 ? R[5] : dx + dy < -0.2 ? R[4] : q > 0.55 ? R[3] : R[2]; });
  for (const y of [204, 208]) im.hl(263, 281, y, R[1]);
  im.hl(266, 275, 200, R[6]);
  // pipe and rebar sticking out
  im.line(246, 204, 238, 190, hex('#2e1a1c'), 3); im.line(245, 203, 237, 189, R[3]); im.line(244, 203, 236, 189, R[5]);
  im.line(298, 206, 306, 192, R[1]); im.line(300, 205, 309, 195, R[1]); im.line(293, 204, 299, 188, R[2]); im.set(299, 188, R[6]);
  for (const [x, y] of [[238, 190], [236, 189], [306, 192], [309, 195], [299, 188]]) mark(x, y);
  for (let k = 0; k < 8; k++) { const t = k / 8; mark(246 - t * 8, 204 - t * 14); mark(245 - t * 8, 203 - t * 14); mark(247 - t * 8, 204 - t * 14); }
  // outline the whole heap silhouette, rim light on left edges
  const out = [];
  for (let y = 180; y < 230; y++) for (let x = 218; x < 320; x++) if (!m[y * im.w + x] && (m[y * im.w + x + 1] || m[y * im.w + x - 1] || m[(y + 1) * im.w + x] || m[(y - 1) * im.w + x])) out.push([x, y]);
  for (const [x, y] of out) im.set(x, y, INK);
  for (let y = 180; y < 228; y++) for (let x = 218; x < 320; x++) if (m[y * im.w + x] && !m[y * im.w + x - 1] === false && false) im.set(x, y, R[6]);
  // contact shadow
  for (let x = 224; x < 314; x++) { im.set(x, 227, hex('#1a0c1c')); }
}

function rustFloor() {
  const W = 350, Hh = 72, im = new Img(W, Hh);
  const as = H('#4a2c44 #5a3a4c #6a4652 #7a5258 #8a6060');
  for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) im.set(x, y, im.ramp(as, clamp(0.62 - (y / Hh) * 0.28 + Math.sin(x / 61 + y / 23) * 0.05), x, y, 1.5));
  // warm sunset glow on the road surface (strongest near the sun, top rows)
  for (let y = 0; y < 22; y++) for (let x = 0; x < W; x++) im.tint(x, y, Math.pow(1 - y / 22, 1.6) * clamp(1.15 - Math.abs(x - 90) / 170) * 0.8, hex('#e8803c'), 0.8, 5);
  // gutter shadow under the curb
  for (let y = 0; y < 5; y++) for (let x = 0; x < W; x++) im.tint(x, y, (1 - y / 5) * 0.9, hex('#1a0c1c'), 0.8, 4);
  // aggregate: evenly spaced chips (light top, dark underside)
  const rr = rng(21), pts = [];
  for (let n = 0; n < 2500 && pts.length < 150; n++) { const x = Math.floor(rr() * W), y = 6 + Math.floor(rr() * (Hh - 8)); if (pts.every(p => Math.hypot(p[0] - x, p[1] - y) > 11)) pts.push([x, y]); }
  pts.forEach(([x, y], i) => { if (i % 3 === 0) { im.set(x, y, hex('#9a7468')); im.set(x + 1, y, hex('#7a5258')); im.set(x, y + 1, hex('#3e2438')); } else if (i % 3 === 1) { im.set(x, y, hex('#3e2438')); im.set(x + 1, y, hex('#4a2c44')); } else { im.rect(x, y, 2, 1, hex('#86605e')); im.set(x + 1, y + 1, hex('#3e2438')); } });
  // patch of newer asphalt (flat, raised edge)
  { const px = 120, py = 26, pw = 52, ph = 20; for (let y = py; y < py + ph; y++) for (let x = px; x < px + pw; x++) { const d = Math.min(x - px, px + pw - 1 - x, y - py, py + ph - 1 - y); im.set(x, y, d === 0 ? ((y === py || x === px) ? hex('#2a1a28') : hex('#8a6a68')) : d === 1 ? ((y === py + 1 || x === px + 1) ? hex('#7a5a5c') : hex('#3a2236')) : im.ramp(H('#563a4e #5e4252'), (y - py) / ph, x, y, 2)); } }
  // cracks with branches
  const crk = (x, y, ang, len, depth, seed) => {
    const r2 = rng(seed); let cx = x, cy = y, a = ang; const pts = [[cx, cy]];
    for (let i = 0; i < len; i++) { a += (r2() - 0.5) * 1.0; cx += Math.cos(a) * (3 + r2() * 4); cy += Math.sin(a) * (1.4 + r2() * 1.6) * 0.8; if (cy > Hh - 1 || cy < 5 || cx < -2 || cx > W + 2) break; pts.push([cx, cy]); if (depth > 0 && r2() < 0.22) crk(cx, cy, a + (r2() < 0.5 ? 0.8 : -0.8), Math.floor(len / 2), depth - 1, seed + i * 7); }
    for (let i = 0; i + 1 < pts.length; i++) { im.line(pts[i][0] + 1, pts[i][1] + 1, pts[i + 1][0] + 1, pts[i + 1][1] + 1, hex('#8a6460')); } for (let i = 0; i + 1 < pts.length; i++) im.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], hex('#1e0e1e'));
  };
  crk(4, 62, -0.25, 16, 2, 11); crk(246, 8, 0.5, 10, 2, 33); crk(330, 6, 1.4, 9, 1, 55); crk(176, 68, 3.3, 10, 1, 77);
  // oil stain with sheen
  const OX = 288, OY = 46; for (const [rx, ry, col] of [[27, 9, '#2a1a30'], [22, 7, '#34223c']]) im.ell(OX, OY, rx, ry, (x, y, q) => (q > 0.85 && bay(x, y) > 0.5) ? null : hex(col));
  im.ell(OX + 2, OY, 16, 5, (x, y, q, dx, dy) => { const k = q * 3 + dy * 0.6; return k < 0.9 ? hex('#3a2a58') : k < 1.5 ? hex('#2a7a8a') : k < 2.1 ? hex('#8a3a8a') : hex('#34223c'); });
  im.set(OX - 8, OY - 3, hex('#fbf6ff')); im.set(OX - 7, OY - 3, hex('#88dff3')); im.set(OX + 10, OY + 2, hex('#c9b8e8'));
  for (const [x, y] of [[246, 36], [252, 52], [330, 56]]) { im.ell(x, y, 3, 1.5, () => hex('#2a1a30')); }
  // road marking: worn dashed line
  for (let x0 = -6; x0 < W; x0 += 40) {
    const len = 24, ww = 4, fade = hash(x0, 9);
    for (let i = 0; i < len; i++) for (let j = 0; j < ww; j++) {
      const x = x0 + i, y = 60 + j; if (x < 0 || x >= W) continue;
      let c = j === 0 ? hex('#fff0e8') : j < 3 ? hex('#ecd7d0') : hex('#b89a98');
      if (i < 2 || i > len - 3) c = mix(c, im.get(x, y), 0.4);
      if (hash(x >> 1, y + x0) < fade * 0.35) c = mix(c, im.get(x, y), 0.65); // worn paint, patchy
      if (j === 3) c = mix(c, hex('#4a2c44'), 0.35);
      im.set(x, y, c);
    }
  }
  // tyre skid
  for (let x = 120; x < 250; x++) { const y = 66 + Math.round((x - 120) * 0.04); for (const o of [0, 5]) if ((x + o) % 7 < 5) im.tint(x, y + o, 0.7, hex('#1a0c1c'), 0.5, 3); }
  // spray can lying on the road
  { const cx = 314, cy = 34;
    for (let x = -9; x <= 7; x++) im.tint(cx + x, cy + 9, 0.8, hex('#1a0c1c'), 0.8, 3), im.tint(cx + x + 1, cy + 10, 0.6, hex('#1a0c1c'), 0.7, 3);
    const body = H('#8a8ad0 #5a5aa8 #3a3a80 #22225a');
    for (let x = -9; x <= 7; x++) for (let y = -4; y <= 4; y++) { const k = (y + 4) / 8; let c = k < 0.15 ? body[0] : k < 0.45 ? body[1] : k < 0.8 ? body[2] : body[3]; if (x >= -3 && x <= 2) c = k < 0.15 ? hex('#ff98c2') : k < 0.6 ? hex('#ff5fb0') : hex('#a63e84'); im.set(cx + x, cy + y, c); }
    for (let y = -4; y <= 4; y++) { im.set(cx - 10, cy + y, INK); im.set(cx + 8, cy + y, INK); } for (let x = -9; x <= 7; x++) { im.set(cx + x, cy - 5, INK); im.set(cx + x, cy + 5, INK); }
    im.rect(cx + 8, cy - 3, 5, 7, hex('#c9b8e8')); im.rect(cx + 8, cy - 3, 5, 2, hex('#fbf6ff')); im.rect(cx + 8, cy + 2, 5, 2, hex('#8a78b8')); im.vl(cx + 13, cy - 3, cy + 3, INK); im.hl(cx + 8, cx + 13, cy - 4, INK); im.hl(cx + 8, cx + 13, cy + 4, INK);
    im.rect(cx + 14, cy - 1, 2, 2, hex('#fbf6ff')); im.set(cx + 16, cy, INK); for (let y = -1; y <= 2; y++) im.set(cx - 11, cy + y, hex('#c9b8e8'));
    for (let y = -5; y <= 5; y++) im.set(cx - 10, cy + y, y === -5 || y === 5 ? INK : hex('#6a5aa0'));
    im.set(cx - 6, cy - 3, hex('#e8e0ff')); im.set(cx - 5, cy - 3, hex('#e8e0ff')); }
  return im;
}

// @@NEXT

// ---------- output + preview ----------
const MAKERS = {
  riptide: [riptideBackground, riptideFloor],
  gainsgard: typeof gainsBackground === 'function' ? [gainsBackground, gainsFloor] : null,
  rustbelt: typeof rustBackground === 'function' ? [rustBackground, rustFloor] : null,
};
const writeImg = (file, im) => fs.writeFileSync(file, png(im.w, im.h, (x, y) => { const o = (y * im.w + x) * 4; return [im.d[o], im.d[o + 1], im.d[o + 2], 255]; }));
const only = process.argv[2];
const sheet = [];
for (const [id, mk] of Object.entries(MAKERS)) {
  if (!mk || (only && only !== id)) continue;
  const [bg, fl] = [mk[0](), mk[1]()];
  writeImg(`assets/areas/${id}/background.png`, bg); writeImg(`assets/areas/${id}/floor.png`, fl);
  const old = f => decode(execFileSync('git', ['show', `40ba8ee:assets/areas/${id}/${f}.png`], { maxBuffer: 1 << 24 }));
  sheet.push({ id, bg, fl, ob: old('background'), of: old('floor') });
}
const PAD = 6, SW = 350 * 2 + PAD * 3, rowH = 300 + PAD;
const SH = Math.max(1, sheet.length) * rowH + PAD;
const out = new Img(SW, SH); out.rect(0, 0, SW, SH, [40, 20, 60]);
sheet.forEach((s, i) => {
  const y0 = PAD + i * rowH;
  const oldPx = (im, x, y) => { const o = (y * im.w + x) * 4; return [im.data[o], im.data[o + 1], im.data[o + 2]]; };
  for (let y = 0; y < 300; y++) for (let x = 0; x < 350; x++) {
    out.set(PAD + x, y0 + y, y < 228 ? oldPx(s.ob, x >> 1, y >> 1) : oldPx(s.of, x >> 1, (y - 228) >> 1));
    const im = y < 228 ? s.bg : s.fl, yy = y < 228 ? y : y - 228, o = (yy * 350 + x) * 4;
    out.set(PAD * 2 + 350 + x, y0 + y, [im.d[o], im.d[o + 1], im.d[o + 2]]);
  }
});
writeImg(only ? 'tools/art_hd/preview_areas_a_fix_tmp.png' : 'tools/art_hd/preview_areas_a_fix.png', out);
console.log('done', sheet.map(s => s.id).join(','));
