// HD (2x) hand-built objects, fx, marks, bursts, shadow and sky for riptide, gainsgard, rustbelt.
// Run: node tools/art_hd/objects_a.mjs   (node only, no packages)
// Writes assets/areas/<id>/{object_*,burst_*,fx*,mark*,shadow,sky}.png and tools/art_hd/preview_objects_a.png
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const AREAS = path.join(ROOT, 'assets/areas');

// ---------- toolkit ----------
const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const H = s => s.split(/\s+/).filter(Boolean).map(hex);
const B4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const bay = (x, y) => (B4[y & 3][x & 3] + 0.5) / 16;
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
function rng(seed) { let s = seed >>> 0 || 1; return () => (s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296; }
const hash = (a, b = 0) => { let h = Math.imul(a + 374761393, 668265263) ^ Math.imul(b + 1274126177, 2246822519); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
const INK = hex('#0b0414');
const WHITE = [255, 255, 255];

function ramp(stops, v, x, y, sharp = 1.8) {
  const n = stops.length, pos = clamp(v) * (n - 1), i = Math.min(n - 2, Math.floor(pos)), f = pos - i;
  const f2 = clamp((f - 0.5) * sharp + 0.5); return stops[i + (f2 > bay(x, y) ? 1 : 0)];
}

class Spr {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
  in(x, y) { return x >= 0 && y >= 0 && x < this.w && y < this.h; }
  set(x, y, c, a = 255) { x = Math.round(x); y = Math.round(y); if (!this.in(x, y)) return; const o = (y * this.w + x) * 4; this.d[o] = Math.round(c[0]); this.d[o + 1] = Math.round(c[1]); this.d[o + 2] = Math.round(c[2]); this.d[o + 3] = a; }
  get(x, y) { x = Math.round(x); y = Math.round(y); if (!this.in(x, y)) return [0, 0, 0, 0]; const o = (y * this.w + x) * 4; return [this.d[o], this.d[o + 1], this.d[o + 2], this.d[o + 3]]; }
  a(x, y) { x = Math.round(x); y = Math.round(y); return this.in(x, y) ? this.d[(y * this.w + x) * 4 + 3] : 0; }
  clear(x, y) { x = Math.round(x); y = Math.round(y); if (this.in(x, y)) this.d[(y * this.w + x) * 4 + 3] = 0; }
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
  ell(cx, cy, rx, ry, fn) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry, q = Math.hypot(dx, dy); if (q > 1) continue;
      const c = fn(x, y, q, dx, dy); if (c) this.set(x, y, c);
    }
  }
  poly(pts, fn) {
    let y0 = Infinity, y1 = -Infinity; for (const p of pts) { y0 = Math.min(y0, p[1]); y1 = Math.max(y1, p[1]); }
    for (let y = Math.floor(y0); y <= Math.ceil(y1); y++) {
      const yy = y + 0.5, xs = [];
      for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; if ((a[1] <= yy && b[1] > yy) || (b[1] <= yy && a[1] > yy)) xs.push(a[0] + (yy - a[1]) / (b[1] - a[1]) * (b[0] - a[0])); }
      xs.sort((p, q) => p - q);
      for (let k = 0; k + 1 < xs.length; k += 2) for (let x = Math.round(xs[k]); x < Math.round(xs[k + 1]); x++) { const c = fn(x, y); if (c) this.set(x, y, c); }
    }
  }
  outline(col = INK, diag = false) {
    const out = [], dirs = diag ? [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]] : [[1, 0], [-1, 0], [0, 1], [0, -1]];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.a(x, y)) continue;
      for (const [dx, dy] of dirs) if (this.a(x + dx, y + dy)) { out.push([x, y]); break; }
    }
    for (const [x, y] of out) this.set(x, y, col);
  }
  bytes() { return png(this.w, this.h, (x, y) => { const o = (y * this.w + x) * 4; return [this.d[o], this.d[o + 1], this.d[o + 2], this.d[o + 3]]; }); }
  save(rel) { fs.writeFileSync(path.join(AREAS, rel), this.bytes()); }
}
// opaque scene image for sky
class Pix extends Spr { constructor(w, h) { super(w, h); for (let i = 3; i < w * h * 4; i += 4) this.d[i] = 255; } }

function sparkle(S, x, y, r, col = WHITE, core = WHITE) {
  for (let i = 1; i <= r; i++) { const c = i === r ? mix(col, INK, 0.0) : col; S.set(x - i, y, c); S.set(x + i, y, c); S.set(x, y - i, c); S.set(x, y + i, c); }
  S.set(x, y, core);
}
function blob(S, cx, cy, rx, ry, fn) { S.ell(cx, cy, rx, ry, fn); }

// ============================================================
// SHADOW (shared look, soft violet-ink ellipse)
// ============================================================
function shadow() {
  const S = new Spr(92, 10);
  for (let y = 0; y < 10; y++) for (let x = 0; x < 92; x++) {
    const dx = (x + 0.5 - 46) / 46, dy = (y + 0.5 - 5) / 5, q = Math.hypot(dx, dy); if (q > 1) continue;
    if (q > 0.78 && bay(x, y) > (1 - q) / 0.22 + 0.15) continue;
    S.set(x, y, q < 0.55 ? hex('#07020e') : INK, q < 0.55 ? 0x9a : 0x6a);
  }
  return S;
}

// ============================================================
// BURSTS (7-point comic star, 5 frames) + facets
// ============================================================
function star(S, cx, cy, R, rot, seed, cols, n = 7, core = 0.32) {
  const v = [];
  for (let i = 0; i < 2 * n; i++) { const ang = rot + i * Math.PI / n, rad = i % 2 === 0 ? R * (0.9 + 0.1 * hash(seed, i)) : R * 0.52 * (0.9 + 0.2 * hash(seed + 7, i)); v.push([cx + Math.cos(ang) * rad, cy + Math.sin(ang) * rad, ang]); }
  for (let k = 0; k < n; k++) {
    const t = v[2 * k], a = v[(2 * k + 2 * n - 1) % (2 * n)], b = v[(2 * k + 1) % (2 * n)];
    for (const [side, o] of [[0, a], [1, b]]) {
      const mid = Math.atan2((t[1] + o[1]) / 2 - cy, (t[0] + o[0]) / 2 - cx), d = Math.cos(mid + 3 * Math.PI / 4);
      const col = side === 0 ? (d > 0 ? cols.light : cols.main) : (d > 0 ? cols.main : cols.dark);
      S.poly([[cx, cy], [t[0], t[1]], [o[0], o[1]]], () => col);
    }
  }
  S.ell(cx - R * 0.04, cy - R * 0.04, R * core, R * core, (x, y, q) => q < 0.6 ? cols.core : (q > bay(x, y) * 0.5 + 0.55 ? null : cols.light));
  S.outline(INK, false);
}
const BURSTS = {
  riptide: { main: hex('#ff5fb0'), light: hex('#ffa8de'), dark: hex('#c02c80'), core: hex('#fff0fa') },
  gainsgard: { main: hex('#ffa033'), light: hex('#ffd36e'), dark: hex('#c8601c'), core: hex('#fff2c0') },
  rustbelt: { main: hex('#ff9a2a'), light: hex('#ffd24a'), dark: hex('#c4501a'), core: hex('#fff6c8') },
};
function bursts(id) {
  const Rs = [9, 25, 38, 47, 47], rots = [0.2, 0.28, 0.35, 0.4, 0.46];
  Rs.forEach((R, i) => {
    const S = new Spr(100, 100); star(S, 50, 50, R, rots[i], 11 + i * 3, BURSTS[id], 7, i === 0 ? 0.0 : 0.17 + i * 0.02);
    if (i === 4) { const r = rng(5); for (let k = 0; k < 6; k++) { const a = r() * 6.28; S.set(50 + Math.cos(a) * 46, 50 + Math.sin(a) * 46, WHITE, 0); } }
    S.save(`${id}/burst_${i + 1}.png`);
  });
}

// ============================================================
// RIPTIDE: wooden treasure chest
// ============================================================
const WOOD = H('#1c0c1c #3a1c26 #5e3028 #8a4e30 #b8743c #e0a458');
const IRON = H('#10091e #241c3c #3c3860 #625e92 #9a98c4 #d6d4f0');
const GOLD = H('#5a2c0a #a2560e #e08a1c #ffc040 #ffe688 #fffbd0');
const SAND = H('#5a4658 #8c7478 #c0a496 #e6ccb6');
const WEED = H('#0e2a2a #1c5a4a #2c8a62 #5cc084');

function woodPix(x, y, v, grainSeed) {
  // v 0..1 lit value; grain streaks along x
  const g = hash(Math.floor(x / 9) + grainSeed, y) ;
  const streak = hash(Math.floor((x + hash(y, grainSeed) * 20) / 11), y * 3 + grainSeed);
  let vv = v + (streak > 0.86 ? -0.13 : streak < 0.08 ? 0.1 : 0) + (g - 0.5) * 0.05;
  return ramp(WOOD, vv, x, y, 1.6);
}
function chestLid(S, ox, oyL, oyR, x0 = 8, x1 = 91, top = 50, bot = 74, pose = 0) {
  // lid with per-column vertical offset (shear), arch top, planks, iron bands, hasp
  const w = x1 - x0 + 1;
  for (let x = x0; x <= x1; x++) {
    const t = (x - x0) / (w - 1), off = Math.round(oyL + (oyR - oyL) * t), u = (x - x0 + 0.5) / w * 2 - 1;
    const archTop = top + Math.round(9 * (1 - Math.sqrt(1 - Math.pow(Math.abs(u), 2.6))));
    for (let y = archTop; y <= bot; y++) {
      const rel = (y - archTop) / (bot - top);
      let lum = 0.76 - rel * 0.52 - (u + 1) * 0.07 + (1 - Math.abs(u)) * 0.04;
      if (y === archTop || y === archTop + 1) lum += 0.22;
      if (x - x0 < 2) lum += 0.15; if (x1 - x < 2) lum -= 0.18;
      // plank seams (curved bands)
      const s1 = top + 14 - Math.round(3 * Math.pow(Math.abs(u), 2.2)), s2 = top + 21;
      if (y === s1 || y === s2) lum = 0.08; else if (y === s1 + 1 || y === s2 + 1) lum += 0.16;
      let c = woodPix(x, y, lum, 31);
      // iron bands
      const inBand = (x >= x0 + 8 && x <= x0 + 19) || (x >= x1 - 19 && x <= x1 - 8);
      if (inBand) {
        const bx = (x >= x0 + 8 && x <= x0 + 19) ? x - (x0 + 8) : x - (x1 - 19);
        let il = 0.62 - rel * 0.3 + (bx < 2 ? 0.2 : bx > 9 ? -0.22 : 0);
        if (y === archTop || y === archTop + 1) il += 0.2;
        c = ramp(IRON, il, x, y, 1.6);
        if ((bx === 3 || bx === 8) && (y === top + 10 || y === top + 19)) c = IRON[5];
        else if ((bx === 3 || bx === 8) && (y === top + 11 || y === top + 20)) c = IRON[1];
      }
      S.set(x, y + off, c);
    }
    // bottom lip shadow
    S.set(x, bot + 1 + off, WOOD[0]);
  }
}
function chestBody(S, x0 = 10, x1 = 89, y0 = 75, y1 = 112, open = false) {
  const w = x1 - x0 + 1;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const rel = (y - y0) / (y1 - y0), seam = 92;
    let lum = 0.7 - rel * 0.38 + (rel > 0.88 ? -0.14 : 0);
    if (x - x0 < 2) lum += 0.14; if (x1 - x < 3) lum -= 0.2;
    if (y === y0 || y === y0 + 1) lum += open ? 0.22 : -0.1;
    if (!open && y > y0 + 1 && y < y0 + 5) lum -= 0.12 * (1 - (y - y0) / 5);
    if (y === seam) lum = 0.06; else if (y === seam + 1) lum += 0.2;
    // vertical plank joints
    const jx = [x0 + 28, x0 + 55][y < seam ? 0 : 1]; if (x === jx) lum -= 0.3;
    let c = woodPix(x, y, lum, 77);
    // knots
    for (const [kx, ky] of [[x0 + 36, y0 + 9], [x0 + 62, 100]]) { const d = Math.hypot((x - kx) / 2.6, y - ky); if (d < 1.4) c = WOOD[1]; else if (d < 2.2 && x < kx) c = WOOD[4]; }
    // iron bands
    const bnd = (x >= x0 + 6 && x <= x0 + 17) || (x >= x1 - 17 && x <= x1 - 6);
    if (bnd) {
      const bx = (x >= x0 + 6 && x <= x0 + 17) ? x - (x0 + 6) : x - (x1 - 17);
      let il = 0.6 - rel * 0.3 + (bx < 2 ? 0.2 : bx > 9 ? -0.22 : 0);
      c = ramp(IRON, il, x, y, 1.6);
      if ((bx === 3 || bx === 8) && (y === y0 + 6 || y === y0 + 20 || y === y1 - 6)) c = IRON[5];
      else if ((bx === 3 || bx === 8) && (y === y0 + 7 || y === y0 + 21 || y === y1 - 5)) c = IRON[1];
    }
    S.set(x, y, c);
  }
  // iron corner feet
  for (const [fx, dir] of [[x0, 1], [x1, -1]]) for (let j = 0; j < 9; j++) for (let i = 0; i < 6; i++) { if (i + j * 0.0 > 5 - Math.floor(j / 3)) continue; S.set(fx + dir * i, y1 - 8 + j, ramp(IRON, 0.55 - j * 0.03 + (dir > 0 && i < 1 ? 0.2 : 0), fx + i, y1 - 8 + j)); }
}
function lock(S, cx, cy, opened = false) {
  // gold lock plate with keyhole
  const x0 = cx - 9, y0 = cy - 13, w = 19, h = 27;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const cr = (x < 2 || x > w - 3) && (y < 2 || y > h - 3); if (cr) continue;
    let l = 0.78 - y / h * 0.5 - x / w * 0.15; if (x < 2) l += 0.15; if (y < 2) l += 0.2; if (x > w - 3) l -= 0.2; if (y > h - 3) l -= 0.15;
    S.set(x0 + x, y0 + y, ramp(GOLD, l, x0 + x, y0 + y, 1.5));
  }
  S.outline; // (outline applied globally)
  // rivets
  for (const [rx, ry] of [[3, 3], [w - 4, 3], [3, h - 4], [w - 4, h - 4]]) { S.set(x0 + rx, y0 + ry, GOLD[5]); S.set(x0 + rx + 1, y0 + ry + 1, GOLD[1]); }
  // inner rim ring
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const dx = (x - 9) / 6.5, dy = (y - 13) / 8, q = Math.hypot(dx, dy); if (q > 0.9 && q < 1.05 && y > 4) S.set(x0 + x, y0 + y, q > 1 ? GOLD[1] : GOLD[0]); }
  // keyhole
  S.ell(cx, cy - 1, 2.5, 2.5, () => INK); S.rect(cx - 1, cy, 3, 6, INK);
  S.set(cx - 1, cy - 3, GOLD[2]);
}
function chestExtras(S, dy = 0) {
  // seaweed strand on the right, pebbles and sand at the base
  const r = rng(91);
  for (let k = 0; k < 5; k++) { const x = 86 + Math.round(Math.sin(k * 1.4) * 2) + 2, y = 90 + k * 5; for (let j = 0; j < 4; j++) S.set(x + (k % 2) - j * 0, y + j, ramp(WEED, 0.8 - j * 0.2, x, y + j)); }
  for (let x = 6; x < 93; x++) { const hgt = Math.round(2.4 * hash(x >> 1, 4) + (x < 14 || x > 84 ? 2.5 : 0.4)); for (let j = 0; j < hgt; j++) { const y = 112 - j; const c = ramp(SAND, 0.95 - j * 0.25 - (x > 60 ? 0.1 : 0), x, y); S.set(x, y, c); } }
}
function sparkles(S, pts) { for (const [x, y, r] of pts) sparkle(S, x, y, r, [255, 245, 200], WHITE); }

function chestIdle() {
  const S = new Spr(100, 114);
  chestBody(S); chestLid(S, 0, 0, 0); lock(S, 50, 76);
  chestExtras(S);
  S.outline(INK, false);
  sparkles(S, [[22, 54, 2], [70, 94, 1]]);
  S.set(33, 53, WHITE); S.set(34, 53, WHITE);
  return S;
}
function chestTap() {
  const S = new Spr(100, 114);
  chestBody(S, 10, 89, 75, 112, true);
  // dark gap with golden light under the lid
  for (let x = 12; x <= 87; x++) for (let y = 66; y <= 76; y++) { const t = (y - 66) / 10; S.set(x, y, y >= 75 ? ramp(GOLD, 0.7 - (x - 12) / 200, x, y) : y === 74 ? GOLD[4] : ramp([hex('#0e0618'), hex('#2a1230'), hex('#5a2c0a')], t, x, y)); }
  chestLid(S, 0, -6, -13, 6, 91, 50, 72);
  lock(S, 50, 70);
  chestExtras(S);
  S.outline(INK, false);
  sparkles(S, [[46, 72, 3], [30, 73, 1], [66, 73, 2], [14, 45, 2]]);
  return S;
}
function coinMound(S, x0, x1, baseY, hgt, seed) {
  for (let x = x0; x <= x1; x++) {
    const u = (x - (x0 + x1) / 2) / ((x1 - x0) / 2), top = baseY - Math.round(hgt * Math.pow(Math.max(0, 1 - u * u), 0.8) + hash(x, seed) * 2.2);
    for (let y = top; y <= baseY; y++) {
      const cxx = Math.floor((x + (Math.floor(y / 3) % 2) * 2) / 4), cyy = Math.floor(y / 3), lx = (x + (Math.floor(y / 3) % 2) * 2) % 4, ly = y % 3;
      const hv = hash(cxx, cyy + seed); let l = 0.45 + hv * 0.4 - (y - top) / 40 * 0.2 + (u < 0 ? 0.05 : -0.08);
      let c;
      if (lx === 3 || ly === 2) c = GOLD[0 + (hv > 0.6 ? 1 : 0)]; else if (lx === 0 && ly === 0) c = GOLD[5]; else c = ramp(GOLD, l, x, y, 2.2);
      S.set(x, y, c);
    }
  }
  // gems
  const gems = [[x0 + 18, baseY - hgt + 5, '#ff5fb0', '#ffc0e6', '#a82670'], [x0 + 46, baseY - hgt + 4, '#3fd2ff', '#b8f0ff', '#1c7aa8'], [x0 + 33, baseY - hgt + 9, '#a77bff', '#d8c4ff', '#5a38b0']];
  for (const [gx, gy, m, l, d] of gems) { S.rect(gx, gy, 3, 3, hex(m)); S.set(gx, gy, hex(l)); S.set(gx + 2, gy + 2, hex(d)); S.set(gx + 1, gy - 1, hex(l)); S.set(gx + 1, gy + 3, hex(d)); S.set(gx - 1, gy + 1, hex(m)); S.set(gx + 3, gy + 1, hex(d)); }
}
function chestHit() {
  const S = new Spr(100, 114);
  chestBody(S, 10, 89, 75, 112, true);
  // open: back wall of the interior above the front rim
  for (let x = 12; x <= 87; x++) for (let y = 68; y <= 74; y++) S.set(x, y, ramp([hex('#0e0618'), hex('#2a1230'), hex('#4a2430')], (74 - y) / 7 * 0.7 + (x - 12) / 150, x, y));
  coinMound(S, 14, 85, 76, 15, 5);
  lock(S, 50, 94, true);
  // overwrite the lock area: front plate sits lower (body only)
  chestExtras(S);
  // detached lid, rotated, flung up-left
  const th = -0.78, cx = 40, cy = 32, L = 66, T = 24, cs = Math.cos(th), sn = Math.sin(th);
  for (let y = 0; y < 76; y++) for (let x = 0; x < 100; x++) {
    const dx = x + 0.5 - cx, dy = y + 0.5 - cy, u = dx * cs + dy * sn + L / 2, v = -dx * sn + dy * cs + T / 2;
    if (u < 0 || u >= L || v < 0 || v >= T) continue;
    const ex = Math.min(u, L - u); if (ex < 5 && v < (5 - ex) * 0.9 + 0) continue; if (ex < 3 && v > T - (3 - ex) * 3) continue;
    let lum = 0.8 - v / T * 0.55 - (u / L) * 0.05; if (v < 2) lum += 0.2; if (u < 2) lum += 0.1; if (u > L - 3) lum -= 0.15;
    if (Math.abs(v - 10) < 0.7 || Math.abs(v - 17) < 0.7) lum = 0.1;
    let c = woodPix(Math.round(u) + 200, Math.round(v) + 60, lum, 12);
    if ((u > 9 && u < 21) || (u > L - 21 && u < L - 9)) { const bx = (u > 9 && u < 21) ? u - 9 : u - (L - 21); let il = 0.65 - v / T * 0.3 + (bx < 2 ? 0.2 : bx > 10 ? -0.22 : 0) + (v < 2 ? 0.2 : 0); c = ramp(IRON, il, x, y, 1.6); if (Math.abs(bx - 3) < 1 && Math.abs(v - 8) < 1) c = IRON[5]; }
    S.set(x, y, c);
  }
  S.outline(INK, false);
  sparkles(S, [[46, 76, 3], [30, 74, 2], [62, 73, 2], [78, 62, 1], [20, 40, 2], [80, 44, 3]]);
  return S;
}

// shells / pearl fx (350x300)
function shellAt(S, cx, cy, ang, R = 9, pearl = false) {
  const tmp = new Spr(S.w, S.h);
  if (pearl) {
    const P = H('#3a3a80 #6c78c0 #aab8f0 #e4ecff #ffffff');
    tmp.ell(cx, cy, 8, 8, (x, y, q, dx, dy) => { const l = clamp(0.62 - dx * 0.42 - dy * 0.42 - q * 0.25 + (hash(x, y) - 0.5) * 0.04); const c = ramp(P, l, x, y, 2); return c; });
    tmp.set(cx - 3, cy - 3, WHITE); tmp.set(cx - 4, cy - 3, P[3]); tmp.set(cx - 3, cy - 4, P[3]); tmp.set(cx + 3, cy + 3, hex('#ff9ad8'));
  } else {
    const PK = H('#6a1a4a #a8306e #ff5fb0 #ff9ad0 #ffd8f0');
    const cs = Math.cos(-ang), sn = Math.sin(-ang);
    for (let y = cy - 15; y <= cy + 15; y++) for (let x = cx - 15; x <= cx + 15; x++) {
      const dx = x + 0.5 - cx, dy = y + 0.5 - cy, lx = dx * cs - dy * sn, ly = dx * sn + dy * cs - R * 0.45;
      const r = Math.hypot(lx, ly), a = Math.atan2(ly, lx);
      if (ly > 3.2 && a < 0 === false) { /* below hinge */ }
      if (a > 0 || a < -Math.PI) continue; // fan only above hinge line
      const edge = R * (1 - 0.1 * Math.abs(Math.sin((a + Math.PI) * 3.5))); if (r > edge) continue;
      const rib = Math.floor((a + Math.PI) / (Math.PI / 7)); let l = 0.58 + (rib % 2 ? 0.1 : -0.06) - r / R * 0.15 + (-dx * 0.03 - dy * 0.03) - (((a + Math.PI) / (Math.PI / 7)) % 1 < 0.16 ? 0.4 : 0);
      if (r > edge - 1.5) l += 0.2; if (r < 2) l = 0.2;
      tmp.set(x, y, ramp(PK, l, x, y, 2));
    }

  }
  tmp.outline(INK, false);
  for (let i = 0; i < tmp.d.length; i += 4) if (tmp.d[i + 3]) { S.d[i] = tmp.d[i]; S.d[i + 1] = tmp.d[i + 1]; S.d[i + 2] = tmp.d[i + 2]; S.d[i + 3] = 255; }
}
function riptideFx(id, pearl) {
  const pts = [[169, 198], [182, 171], [196, 143], [211, 117], [227, 153], [241, 191]], angs = [0.2, 0.9, 1.7, 2.6, 3.5, 4.3];
  pts.forEach(([x, y], i) => {
    const S = new Spr(350, 300);
    // trail of sparkles behind
    for (let k = 1; k <= 3; k++) { const p = pts[Math.max(0, i - k)], q = k * 4; if (i - k >= 0) { const sx = p[0] + (k % 2 ? 6 : -6), sy = p[1] + 6 + k * 2; const c = pearl ? [200, 220, 255] : [255, 160, 220]; if (k === 1 && i < 5) sparkle(S, sx, sy, 2, c, WHITE); else S.set(sx, sy, k === 3 ? c : WHITE); } }
    if (i === 0) { const rr = rng(8); for (let k = 0; k < 14; k++) { const a = Math.PI * (0.1 + 0.8 * rr()), d = 8 + rr() * 9; S.set(x + Math.cos(a + Math.PI) * d, y + 8 - Math.sin(a) * d * 0.7, SAND[2 + (k % 2)]); } }
    shellAt(S, x, y, angs[i], 11, pearl);
    if (pearl) { sparkle(S, x + 11, y - 9, 3, [255, 235, 250], WHITE); if (i % 2) sparkle(S, x - 12, y + 8, 2, [200, 220, 255], WHITE); }
    S.save(`${id}/${pearl ? 'fx5' : 'fx'}_${i + 1}.png`);
  });
}
function riptideMarks(id) {
  // mark 20x16: pink scallop shell lying in the sand
  const S = new Spr(20, 16);
  const PK = H('#6a1a4a #a8306e #ff5fb0 #ff9ad0 #ffe0f4');
  for (let y = 0; y < 16; y++) for (let x = 0; x < 20; x++) {
    const dx = (x + 0.5 - 10) / 9, dy = (y + 0.5 - 14) / 13; const r = Math.hypot(dx, dy); if (r > 1 || y > 14) continue;
    const a = Math.atan2(dy, dx), edge = 1 - 0.08 * Math.abs(Math.sin((a + Math.PI) * 4.5)); if (r > edge) continue;
    const rib = Math.floor((a + Math.PI) / (Math.PI / 9)); let l = 0.6 + (rib % 2 ? 0.14 : -0.1) - r * 0.2 - dx * 0.1; if (r > edge - 0.1) l += 0.2; if (r < 0.2) l = 0.2;
    S.set(x, y, ramp(PK, l, x, y, 2.2));
  }
  S.rect(7, 13, 6, 2, PK[1]); S.hl(8, 11, 13, PK[3]);
  S.outline(INK, false); S.save(`${id}/mark.png`);
  // mark_fifth 18x18: blue pearl
  const P = new Spr(18, 18); const PL = H('#1c3a8a #3f8ae0 #7ad2ff #c4f0ff #ffffff');
  P.ell(9, 9, 7.5, 7.5, (x, y, q, dx, dy) => ramp(PL, clamp(0.6 - dx * 0.4 - dy * 0.42 - q * 0.22), x, y, 2));
  P.set(6, 5, WHITE); P.set(5, 6, PL[3]); P.set(6, 6, PL[3]); P.set(12, 12, hex('#9a78ff'));
  P.outline(INK, false); P.save(`${id}/mark_fifth.png`);
}

// ============================================================
// RUSTBELT: hazard barrel
// ============================================================
const STEEL = H('#150c24 #2a2038 #463e62 #6a6288 #9a94b8 #d0cce0');
const HOOP = H('#120a20 #281e3c #3e3660 #6a62a0 #a8a4d0 #e8e4ff');
const RUST = H('#2a1218 #5a2a22 #8a4a2a #c0703e #e8a050');
const YEL = H('#5a3008 #a86010 #f0a020 #ffd25a #fff0a8');
const BLK = H('#07020c #120a1a #221830 #3a2e50');
function barrel(S, cx, yt, yb, rx, ry, seed = 3) {
  const L = [-0.62, 0.78], rr = rng(seed);
  const streaks = Array.from({ length: 7 }, () => ({ x: Math.round(cx - rx + 3 + rr() * (2 * rx - 6)), y: yt + 4 + rr() * (yb - yt) * 0.5, len: 8 + rr() * 22 }));
  const span = yb - yt, R2 = yt + span * 0.3, R3 = yt + span * 0.64;
  for (let y = Math.floor(yt - ry) - 1; y <= Math.ceil(yb + ry) + 1; y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
    const u = (x + 0.5 - cx) / rx; if (Math.abs(u) > 1) continue; const k = Math.sqrt(1 - u * u);
    const yy = y + 0.5; if (yy < yt - ry * k || yy > yb + ry * k) continue;
    const s = clamp(-0.62 * u + 0.78 * k) , sv = 0.04 + 0.66 * s;
    if (yy <= yt + ry * k) { // lid
      const q = Math.hypot(u, (yy - yt) / ry);
      if (q > 0.8) { S.set(x, y, ramp(HOOP, sv * 0.95 + (yy < yt ? 0.12 : -0.05), x, y, 1.6)); continue; }
      let l = 0.4 + 0.2 * (-u * 0.5 - (yy - yt) / ry * 0.5) + (hash(x, y) - 0.5) * 0.06;
      if (hash(x >> 1, y >> 1) > 0.8) { S.set(x, y, ramp(RUST, 0.35 + l * 0.4, x, y)); continue; }
      S.set(x, y, ramp(STEEL, l, x, y, 1.6)); continue;
    }
    const yc = yy - ry * k; // ring-compensated y
    let c, v = sv;
    const ringAt = (y0) => yc >= y0 && yc < y0 + 5 ? Math.floor(yc - y0) : -1;
    const rings = [yt - 0.2, R2, R3, yb - 4.8];
    let ri = -1, rr_ = -1; for (let i = 0; i < 4; i++) { const t = ringAt(rings[i]); if (t >= 0) { ri = i; rr_ = t; } }
    if (ri >= 0) {
      const lum = [0.95, 0.72, 0.6, 0.2, 0.0][rr_]; c = ramp(HOOP, clamp(sv * 0.9 + (lum - 0.5) * 0.5 + 0.08), x, y, 1.6);
      const rx2 = Math.floor((x - cx) / 1);
      if (rr_ === 2 && ((Math.round(x - cx) % 9 + 9) % 9 === 0) && Math.abs(u) < 0.92) c = HOOP[5];
      if (rr_ === 3 && ((Math.round(x - cx) % 9 + 9) % 9 === 0) && Math.abs(u) < 0.92) c = HOOP[0];
      if (rr_ === 4) c = ramp(STEEL, sv * 0.4, x, y);
      if (hash(x, y + seed) > 0.9 && ri > 0) c = ramp(RUST, 0.3 + sv * 0.5, x, y);
      S.set(x, y, c); continue;
    }
    if (yc > R2 + 5.2 && yc < R3 - 0.2) { // hazard band
      const edge = yc < R2 + 6.5 || yc > R3 - 1.5;
      const stripe = (Math.floor((x - cx + yc + 300) / 5.5)) % 2 === 0;
      if (edge) c = ramp(BLK, sv * 0.7, x, y); else c = stripe ? ramp(YEL, clamp(sv * 1.05), x, y, 1.8) : ramp(BLK, sv * 0.9, x, y);
      if (!edge && stripe && hash(x, y + 5) > 0.93) c = ramp(RUST, 0.3 + sv * 0.6, x, y); // chipped paint
      S.set(x, y, c); continue;
    }
    // plain body: steel with rust
    let l = sv + (hash(x, y + 9) - 0.5) * 0.06;
    c = ramp(STEEL, l, x, y, 1.6);
    const bottomness = clamp((yc - yt) / span);
    const patch = hash(x >> 2, y >> 2) * 0.55 + hash(x >> 3, y >> 3) * 0.45 + bottomness * 0.3 + (u > 0.4 ? 0.05 : 0);
    if (patch > 0.7) c = ramp(RUST, 0.25 + l * 0.7 + (hash(x, y) - 0.5) * 0.2, x, y, 2);
    for (const st of streaks) if (Math.abs(x - st.x) < 1.2 && yc > st.y && yc < st.y + st.len) c = ramp(RUST, 0.15 + l * 0.5 - (yc - st.y) / st.len * 0.1, x, y, 2);
    S.set(x, y, c);
  }
}
function dust(S, x, y, r) {
  const D = H('#3a2238 #6a4a58 #a8858e #d8bcc0');
  S.ell(x, y, r, r * 0.7, (px, py, q, dx, dy) => ramp(D, 0.8 - q * 0.5 - dx * 0.18 - dy * 0.2, px, py, 1.8));
}
function barrelIdle() { const S = new Spr(52, 68); barrel(S, 26, 9, 58, 22, 5); S.outline(INK, false); for (const [x, y] of [[14, 22], [36, 46]]) S.set(x, y, STEEL[5]); return S; }
function barrelTap() {
  const S = new Spr(52, 68); barrel(S, 26, 17, 57, 24, 6); dust(S, 7, 59, 6); dust(S, 45, 60, 6);
  S.outline(INK, false);
  S.set(12, 8, WHITE); S.set(40, 9, WHITE); S.set(26, 6, hex('#ffd25a')); // impact flecks
  return S;
}
function scorch() {
  const S = new Spr(52, 68), C = H('#07020c #160e1c #2a1c2a #463a48 #6a5a68');
  for (let y = 50; y < 64; y++) for (let x = 4; x < 52; x++) {
    const dx = (x + 0.5 - 28) / 24, dy = (y + 0.5 - 58) / 6.2, q = Math.hypot(dx, dy) + (hash(x, y) - 0.5) * 0.25; if (q > 1) continue;
    S.set(x, y, ramp(C, clamp(0.85 - q * 0.9 + (hash(x >> 1, y) - 0.5) * 0.2), x, y, 2));
  }
  // embers + ash
  const r = rng(21); for (let k = 0; k < 14; k++) { const x = 8 + r() * 36, y = 54 + r() * 8; if (S.a(x, y)) S.set(x, y, k % 3 === 0 ? hex('#ff8a2a') : k % 3 === 1 ? hex('#8a8090') : hex('#c0703e')); }
  S.set(21, 58, hex('#ffd25a')); S.set(34, 60, hex('#ffd25a'));
  // bent hoop piece and rusty scraps
  for (let i = 0; i < 18; i++) { const a = -0.5 + i * 0.12, x = 12 + i * 1.1, y = 56 - Math.sin(i * 0.17) * 3.5 + 0; S.set(x, y, HOOP[4]); S.set(x, y + 1, HOOP[2]); S.set(x, y + 2, HOOP[0]); }
  S.rect(36, 52, 5, 3, RUST[2]); S.hl(36, 40, 52, RUST[4]); S.hl(36, 40, 54, RUST[0]);
  S.rect(44, 56, 3, 3, YEL[2]); S.hl(44, 46, 56, YEL[4]); S.hl(44, 46, 58, YEL[0]);
  S.rect(8, 51, 3, 2, YEL[2]); S.set(9, 51, YEL[4]);
  S.outline(INK, false);
  return S;
}
function smoke(S, cx, cy, r, fade = 1, seed = 3) {
  const SM = H('#3a2a4c #5c4a70 #8e7ea0 #c4b8cc');
  // a puff = cluster of lobes; lit from the upper left, shaded lower right
  const lobes = [[0, 0, 0.62], [-0.45, 0.2, 0.42], [0.46, 0.18, 0.44], [-0.1, -0.42, 0.4], [0.3, -0.3, 0.34]];
  for (const [ox, oy, lr] of lobes) {
    const lx = cx + ox * r, ly = cy + oy * r * 0.8;
    S.ell(lx, ly, lr * r, lr * r * 0.9, (x, y, q, dx, dy) => { if (fade < 1 && bay(x, y) > fade) return null; return ramp(SM, clamp(0.74 - q * 0.3 - dx * 0.3 - dy * 0.34 + (hash(x >> 1, (y >> 1) + seed) - 0.5) * 0.06), x, y, 5); });
  }
}
function debris(S, x, y, ang, sz = 3) {
  const c = Math.cos(ang), s = Math.sin(ang);
  for (let j = -sz; j <= sz; j++) for (let i = -sz; i <= sz; i++) { const lx = i * c + j * s, ly = -i * s + j * c; if (Math.abs(lx) <= sz && Math.abs(ly) <= sz * 0.6) S.set(x + i, y + j, ly < 0 ? RUST[3] : RUST[1]); }
}
function rustFx(id) {
  const cx = 208, cy = 262;
  const specs = [
    { R: 12, sm: [[200, 246, 8, 1]], deb: [[196, 250, 0.4, 2], [220, 252, 1, 2], [208, 236, 2, 2]], ember: 8 },
    { R: 24, sm: [[190, 232, 12, 1], [226, 228, 10, 1]], deb: [[186, 242, 0.6, 3], [232, 238, 2.1, 3], [210, 214, 1.3, 3], [172, 262, 0.2, 2]], ember: 14 },
    { R: 34, sm: [[184, 214, 17, 1], [232, 206, 15, 1], [208, 196, 12, 1]], deb: [[170, 236, 0.5, 3], [246, 232, 1.9, 3], [204, 186, 0.9, 3], [160, 266, 2.4, 2], [258, 270, 0.7, 2]], ember: 20 },
    { R: 24, sm: [[176, 190, 20, 0.95], [236, 178, 18, 0.95], [204, 168, 15, 0.9]], deb: [[162, 250, 0.9, 3], [254, 254, 1.8, 3], [196, 220, 0.3, 2], [152, 280, 1.2, 2], [266, 284, 2.0, 2]], ember: 16 },
    { R: 14, sm: [[170, 168, 22, 0.8], [242, 154, 20, 0.8], [206, 150, 18, 0.7]], deb: [[158, 270, 1.4, 3], [264, 276, 0.5, 3], [186, 284, 2.2, 2]], ember: 10 },
    { R: 0, sm: [[164, 150, 22, 0.55], [252, 134, 20, 0.5], [208, 128, 16, 0.45]], deb: [[152, 288, 0.7, 2], [276, 290, 1.5, 2]], ember: 6 },
  ];
  specs.forEach((sp, i) => {
    const S = new Spr(350, 300);
    for (const [x, y, r, f] of sp.sm) smoke(S, x, y, r, f, i);
    if (sp.R > 0) {
      const cols = i === 3 ? { main: hex('#ff7a22'), light: hex('#ffb040'), dark: hex('#b83c18'), core: hex('#ffe08a') } : i === 4 ? { main: hex('#e0601c'), light: hex('#ff8a2a'), dark: hex('#8a2c18'), core: hex('#ffb040') } : { main: hex('#ffa033'), light: hex('#ffd36e'), dark: hex('#c8601c'), core: hex('#fffbe0') };
      star(S, cx, cy, sp.R, 0.3 + i * 0.2, 40 + i, cols, 8, 0.35);
    }
    for (const [x, y, a, sz] of sp.deb) debris(S, x, y, a, sz);
    S.outline(INK, false);
    const r = rng(100 + i); for (let k = 0; k < sp.ember; k++) { const a = r() * 6.28, d = 14 + r() * (24 + i * 8); sparkle(S, Math.round(cx + Math.cos(a) * d), Math.round(cy - 6 + Math.sin(a) * d * 0.8), 1, hex('#ffd25a'), hex('#fff6c8')); }
    S.save(`${id}/fx_${i + 1}.png`);
  });
}
function rustMark(id) {
  const S = new Spr(16, 24), t = [[1, 1, 10, 20], [10, 1, 1, 20]];
  const draw = (ox, oy, col, edge) => {
    for (let k = 0; k < 24; k++) { const f = k / 23, x = Math.round(ox + 1 + f * 9.5), y = Math.round(oy + 1 + f * 20); for (let w = 0; w < 3; w++) S.set(x + w, y, col); const x2 = Math.round(ox + 10.5 - f * 9.5); for (let w = 0; w < 3; w++) S.set(x2 + w - 1, y, col); }
  };
  draw(2, 2, INK); draw(1, 1, hex('#f0eaf8')); draw(0, 0, WHITE);
  // light-grey underside on X strokes + paint drips
  for (const [x, y] of [[3, 12], [4, 13], [8, 12], [7, 13]]) S.set(x, y, hex('#e4dcf0'));
  for (const [x, y, n] of [[4, 21, 2], [10, 22, 1], [1, 20, 1]]) for (let j = 0; j < n; j++) S.set(x, y + j, WHITE);
  S.set(7, 3, WHITE); S.set(12, 8, hex('#f0eaf8'));
  S.save(`${id}/mark.png`);
}

// ============================================================
// GAINSGARD: stone wall slab
// ============================================================
const STONE = H('#1c1030 #2c1c4c #43325e #5e4c7c #80709e #a898b8 #d8c8d0');
const MORT = H('#14082a #1e1038 #2c1c4c');
const MOSS = H('#16301a #2a5624 #4a8a32 #8ac04a');
function slab(S, x0, y0, w, h, o = {}) {
  const rows = 6, inner = { x: x0 + 3, y: y0 + 3, w: w - 6, h: h - 6 };
  const rh = inner.h / rows, rr = rng(7);
  for (let y = inner.y; y < inner.y + inner.h; y++) for (let x = inner.x; x < inner.x + inner.w; x++) S.set(x, y, ramp(MORT, 0.2 + (hash(x >> 1, y >> 1) > 0.9 ? 0.5 : 0) + ((y - inner.y) % 2) * 0.1, x, y));
  const bricks = [];
  for (let r = 0; r < rows; r++) {
    const by0 = Math.round(inner.y + r * rh), by1 = Math.round(inner.y + (r + 1) * rh) - 2;
    let x = inner.x - (r % 2 ? 22 : 0) - Math.round(rr() * 8);
    while (x < inner.x + inner.w) { const bw = 38 + Math.round(rr() * 22); bricks.push({ x: x + 2, y: by0 + (r === 0 ? 0 : 2), w: bw - 2, h: by1 - by0 + (r === 0 ? 2 : 0), r }); x += bw; }
  }
  for (const b of bricks) {
    const t0 = 0.4 + hash(b.x, b.y) * 0.18, bx0 = Math.max(b.x, inner.x), bx1 = Math.min(b.x + b.w - 1, inner.x + inner.w - 1);
    for (let y = b.y; y < b.y + b.h; y++) for (let x = bx0; x <= bx1; x++) {
      const lx = x - b.x, ly = y - b.y, rx = b.x + b.w - 1 - x, ry = b.y + b.h - 1 - y;
      let v = t0 + (0.1 - ly / b.h * 0.22) + (hash(x, y) - 0.5) * 0.1 + (hash(x >> 2, y >> 1) - 0.5) * 0.1;
      if (ly < 2) v += 0.3; else if (ly < 3) v += 0.1; if (lx < 1) v += 0.22; if (ry < 3) v -= 0.26; if (rx < 2) v -= 0.18;
      if (hash(x + 99, y) > 0.985) v -= 0.25; // pits
      // chipped corners
      if ((lx + ly < 3 && hash(b.x, b.y + 1) > 0.5) || (rx + ry < 3 && hash(b.x + 3, b.y) > 0.55)) { S.set(x, y, ramp(MORT, 0.15, x, y)); continue; }
      if (o.tap) v += 0.12;
      S.set(x, y, ramp(STONE, clamp(v), x, y, 1.7));
    }
    // moss clumps
    if (hash(b.x, b.y + 11) > 0.62) {
      const mx = b.x + 4 + Math.floor(hash(b.x, 5) * (b.w - 16)), mw = 8 + Math.floor(hash(b.y, b.x) * 12);
      for (let x = mx; x < mx + mw; x++) { if (x < inner.x || x >= inner.x + inner.w) continue; const t = (x - mx) / mw, d = Math.round(1 + 3.5 * Math.sin(t * Math.PI) * (0.5 + hash(x, b.y))); for (let j = 0; j < d; j++) S.set(x, b.y + j, ramp(MOSS, 0.95 - j / 4 * 0.75 + (hash(x, j) - 0.5) * 0.2, x, b.y + j, 2)); }
    }
  }
  // frame: ink outline 2px, rim light top/left, dark bottom/right
  for (let i = 0; i < w; i++) { for (const j of [0, 1]) { S.set(x0 + i, y0 + j, INK); S.set(x0 + i, y0 + h - 1 - j, INK); } S.set(x0 + i, y0 + 2, i > 1 && i < w - 3 ? STONE[5] : STONE[3]); S.set(x0 + i, y0 + h - 3, STONE[0]); }
  for (let j = 0; j < h; j++) { for (const i of [0, 1]) { S.set(x0 + i, y0 + j, INK); S.set(x0 + w - 1 - i, y0 + j, INK); } if (j > 1 && j < h - 3) { S.set(x0 + 2, y0 + j, STONE[5]); S.set(x0 + w - 3, y0 + j, STONE[0]); } }
  // rounded corners cut
  for (const [cx, cy, sx, sy] of [[x0, y0, 1, 1], [x0 + w - 1, y0, -1, 1], [x0, y0 + h - 1, 1, -1], [x0 + w - 1, y0 + h - 1, -1, -1]]) { S.clear(cx, cy); S.clear(cx + sx, cy); S.clear(cx, cy + sy); }
}
function cracks(S, x0, y0, w, h, ix, iy, seed, n = 7) {
  const r = rng(seed), DK = hex('#0e0620'), LT = hex('#a898b8');
  const walk = (x, y, a, len, depth) => {
    for (let i = 0; i < len; i++) {
      a += (r() - 0.5) * 0.9; x += Math.cos(a) * 2; y += Math.sin(a) * 2;
      if (x < x0 + 3 || x > x0 + w - 4 || y < y0 + 3 || y > y0 + h - 4) return;
      S.set(x, y, DK); S.set(x + 1, y, DK); S.set(x, y + 1, DK); S.set(x + 1, y + 1, DK); S.set(x - 1, y, hex('#1c1030'));
      S.set(x - 1, y - 1, LT); if (i % 2) S.set(x - 1, y, STONE[4]);
      if (r() < 0.035 && depth < 2) walk(x, y, a + (r() < 0.5 ? 0.8 : -0.8), Math.round(len * 0.5), depth + 1);
    }
  };
  for (let k = 0; k < n; k++) walk(ix, iy, (k / n) * 6.28 + r() * 0.5, 9 + Math.round(r() * 14), 0);
  // impact crater
  S.ell(ix, iy, 6, 5, (x, y, q) => q > 0.7 ? STONE[5] : q > 0.4 ? STONE[1] : DK);
  S.set(ix - 2, iy - 2, STONE[6]); S.set(ix - 3, iy - 1, STONE[5]);
}
function stoneChips(S, x0, y0, w, h, seed) {
  const r = rng(seed), DK = hex('#0e0620');
  for (let k = 0; k < 6; k++) {
    const x = x0 + 10 + r() * (w - 30), y = y0 + 8 + r() * (h - 24), sz = 4 + r() * 4;
    S.poly([[x, y], [x + sz, y + 1], [x + sz * 0.6, y + sz]], () => DK);
    S.hl(Math.round(x), Math.round(x + sz * 0.6), Math.round(y + sz + 0), STONE[5]);
  }
  // knocked-out edge chunks (transparent)
  for (const [cx, cy, a] of [[x0 + w - 2, y0 + 20, 8], [x0 + 1, y0 + h - 30, 7], [x0 + w - 30, y0 + h - 1, 6], [x0 + 40, y0, 6]]) {
    for (let j = -a; j <= a; j++) for (let i = -a; i <= a; i++) { const d = Math.hypot(i, j * 0.9) + (hash(cx + i, cy + j) - 0.5) * 3; if (d < a * 0.55 && S.a(cx + i, cy + j)) { const edge = d > a * 0.38; if (cx > x0 + 5 && cx < x0 + w - 5 && cy > y0 + 5 && cy < y0 + h - 5) continue; S.clear(cx + i, cy + j); } }
  }
}
function chalkDust(S, cx, cy, seed) {
  const r = rng(seed), C = [hex('#ffffff'), hex('#e9e0fa'), hex('#c9b8e8'), hex('#a898c8')];
  for (let k = 0; k < 90; k++) { const a = r() * 6.28, d = 3 + Math.pow(r(), 0.8) * 52, x = Math.round(cx + Math.cos(a) * d * 1.3), y = Math.round(cy + Math.sin(a) * d * 0.9); if (!S.a(x, y)) continue; const c = C[Math.floor(r() * r() * 4)]; S.set(x, y, c); if (r() < 0.25) S.set(x + 1, y, c); if (r() < 0.12) S.set(x, y + 1, c); }
}
function wallIdle() { const S = new Spr(150, 132); slab(S, 0, 0, 150, 132); return S; }
function wallTap() {
  const S = new Spr(150, 132); slab(S, 0, 7, 150, 125, { tap: true });
  // dust puffs + impact lines on the upper margin
  const D = [hex('#e9e0fa'), hex('#c9b8e8'), hex('#8a7aa8')];
  for (const [x, y, r] of [[22, 4, 5], [58, 3, 4], [100, 4, 6], [132, 5, 4]]) S.ell(x, y, r, 2.4, (px, py, q, dx, dy) => ramp([D[2], D[1], D[0]].reverse(), 0.3 + (1 - q) * 0.6 - dy * 0.2, px, py, 2));
  for (const x of [38, 76, 118]) { S.vl(x, 0, 2, hex('#c9b8e8')); }
  return S;
}
function wallHit() {
  const S = new Spr(150, 132); slab(S, 0, 0, 150, 132);
  cracks(S, 0, 0, 150, 132, 78, 62, 17, 6);
  stoneChips(S, 0, 0, 150, 132, 5);
  chalkDust(S, 78, 62, 3);
  return S;
}
// chalk marks
const CH = H('#ffffff #f6eeff #e9e0fa #c9b8e8');
function chalkMark(id) {
  const S = new Spr(8, 44), r = rng(5);
  for (let y = 0; y < 44; y++) { const wob = Math.round(Math.sin(y * 0.35) * 0.6 + (hash(y, 2) - 0.5) * 0.8), x0 = 2 + wob; const w = (y < 3 || y > 40) ? 2 : 3 + (hash(y, 9) > 0.7 ? 1 : 0);
    for (let i = 0; i < w; i++) { if (hash(i + x0, y + 40) > 0.88 && i > 0) continue; S.set(x0 + i, y, i === 0 ? CH[0] : i === w - 1 ? CH[2] : CH[1]); }
    S.set(x0 + w, y, hex('#3a2c58')); if (hash(y, 4) > 0.5) S.set(x0 + w + 1, y, hex('#2c1c48')); }
  S.save(`${id}/mark.png`);
  // fifth: diagonal slash up-right across the group, 60x34 canvas, bbox 0..49 x 0..27
  const F = new Spr(60, 34);
  for (let i = 0; i <= 62; i++) { const f = i / 62, x = Math.round(f * 47), y = Math.round(26 - f * 25) + Math.round((hash(i, 6) - 0.5) * 1.2);
    for (let w = 0; w < 3; w++) { if (hash(i, w + 70) > 0.9 && w === 2) continue; F.set(x + w, y, w === 0 ? CH[0] : w === 1 ? CH[1] : CH[2]); }
    F.set(x + 1, y + 1, hex('#3a2c58')); F.set(x + 2, y + 1, hex('#3a2c58')); F.set(x + 3, y, hex('#2c1c48')); if (hash(i, 3) > 0.6) F.set(x, y + 2, hex('#2c1c48')); }
  F.save(`${id}/mark_fifth.png`);
}

// ============================================================
// SKY EXTENSIONS (350x120): continue the top of background.png upward
// ============================================================
function bgRow0(id) { const b = decode(fs.readFileSync(path.join(AREAS, id, 'background.png'))); return x => { const i = x * 4; return [b.data[i], b.data[i + 1], b.data[i + 2]]; }; }
function drawCloud(S, cx, cy, wd, ht, cols, seed) {
  // flat-bottom pixel cloud: bumps along the top, 3 tones (top lit, body, bottom shade)
  const [top, body, shade] = cols;
  for (let x = Math.round(cx - wd / 2); x <= cx + wd / 2; x++) {
    const u = (x - cx) / (wd / 2), env = Math.sqrt(Math.max(0, 1 - u * u)), bump = 0.6 + 0.4 * Math.abs(Math.sin(u * 5 + seed)), hgt = Math.round(ht * env * bump);
    for (let j = 0; j < hgt; j++) { const y = cy - j; S.set(x, y, j === hgt - 1 ? top : j < 2 ? shade : body); }
  }
}
const SKY = 320; // sky.png height (2x): 160 art px
function skyRiptide() {
  const S = new Pix(350, SKY), id = 'riptide', row0 = bgRow0(id), top = hex('#12061f'), bot = hex('#090315');
  for (let y = 0; y < SKY; y++) for (let x = 0; x < 350; x++) S.set(x, y, ramp([top, mix(top, bot, 0.5), bot], y / (SKY - 1), x, y, 1.2));
  const r = rng(77);
  for (let k = 0; k < 230; k++) { const y = 34 + Math.floor(r() * (SKY - 40)); if (r() > 0.35 + 0.65 * (y - 34) / (SKY - 40)) continue; const x = Math.floor(r() * 350), c = [WHITE, hex('#c8c0ff'), hex('#7a70c0'), hex('#9ae0ff'), hex('#ffc080')][Math.floor(r() * r() * 5)]; S.set(x, y, c); }
  for (const [x, y] of [[40, 160], [160, 70], [250, 210], [320, 120], [96, 270], [210, 280], [20, 240]]) sparkle(S, x, y, 2, hex('#c8c0ff'), WHITE);
  const CL = [hex('#4a3e90'), hex('#2e2468'), hex('#221a52')], CL2 = [hex('#3a3078'), hex('#261e5a'), hex('#1c1648')];
  drawCloud(S, 70, 300, 118, 12, CL, 0.3); drawCloud(S, 190, 270, 70, 9, CL, 1.1); drawCloud(S, 300, 250, 100, 11, CL, 2.2);
  drawCloud(S, 120, 190, 60, 6, CL2, 3); drawCloud(S, 280, 150, 80, 7, CL2, 5); drawCloud(S, 40, 110, 70, 5, [hex('#2a2268'), hex('#1c1650'), hex('#160f40')], 7);
  for (let x = 0; x < 350; x++) S.set(x, SKY - 1, row0(x));
  return S;
}
function skyRust() {
  const S = new Pix(350, SKY), id = 'rustbelt', row0 = bgRow0(id), top = hex('#1f0d36'), bot = hex('#0f0620');
  for (let y = 0; y < SKY; y++) for (let x = 0; x < 350; x++) S.set(x, y, ramp([top, mix(top, bot, 0.5), bot], y / (SKY - 1), x, y, 1.2));
  const r = rng(33);
  for (let k = 0; k < 120; k++) { const y = 40 + Math.floor(r() * (SKY - 60)); if (r() > 0.3 + 0.7 * (y - 40) / (SKY - 60)) continue; S.set(Math.floor(r() * 350), y, [hex('#a898c8'), hex('#6a5a90'), hex('#ffb070')][Math.floor(r() * 3)]); }
  for (const [cx, cy, w, h] of [[110, 296, 90, 6], [250, 270, 130, 8], [320, 304, 60, 5], [40, 230, 70, 5], [190, 200, 100, 6], [300, 150, 80, 5], [70, 120, 90, 5]]) {
    const fadeUp = clamp((cy - 90) / 120);
    drawCloud(S, cx, cy, w, h, [mix(hex('#2a1646'), hex('#6a3a78'), fadeUp), mix(hex('#24113e'), hex('#3a2050'), fadeUp), mix(hex('#200e38'), hex('#2a1640'), fadeUp)], cx);
    if (fadeUp > 0.35) for (let x = cx - w / 2 + 3; x < cx + w / 2 - 3; x++) { S.set(Math.round(x), cy + 1, mix(hex('#4a2448'), hex('#ff8a30'), fadeUp)); if (hash(x, cy) > 0.5) S.set(Math.round(x), cy + 2, mix(hex('#3a1c44'), hex('#ffc075'), fadeUp * 0.8)); }
  }
  for (let x = 0; x < 350; x++) S.set(x, SKY - 1, row0(x));
  return S;
}
function skyGains() {
  const S = new Pix(350, SKY), top = hex('#3a2a52'), dark = hex('#16082a');
  for (let y = 0; y < SKY; y++) for (let x = 0; x < 350; x++) S.set(x, y, ramp([top, hex('#33244c'), hex('#2a1a42'), hex('#241638')], y / (SKY - 1), x, y, 1.3));
  const amp = y => clamp((y - 40) / 150); // texture strength: 0 at the top (flat sky colour), 1 near the beam
  // stone courses with running bond
  const ys = []; for (let y = SKY - 3, k = 0; y > 30; k++) { ys.push(y); y -= 20 + Math.round(hash(k, 3) * 6); }
  ys.forEach((yy, ri) => {
    const a = amp(yy), mort = mix(top, dark, a), lit = mix(top, hex('#5a4878'), a * 0.9), step = 20;
    for (let x = 0; x < 350; x++) { S.set(x, yy, mort); S.set(x, yy - 1, mix(mort, top, 0.45)); S.set(x, yy - step + 2, lit); }
    let x = ri % 2 ? 24 : 0; while (x < 350) { for (let j = 2; j < step - 1; j++) S.set(x, yy - j, mort); x += 44 + Math.round(hash(x, yy) * 24); }
  });
  for (let y = 0; y < SKY - 3; y++) for (let x = 0; x < 350; x++) { const a = amp(y), n = hash(x >> 1, y >> 1); if (n > 0.88 && bay(x, y) < a * 2) S.set(x, y, mix(S.get(x, y).slice(0, 3), hex('#5a4878'), 0.3 * a)); else if (n < 0.06 && bay(x, y) < a * 2) S.set(x, y, mix(S.get(x, y).slice(0, 3), dark, 0.35 * a)); }
  // vault ribs: three stone arches springing from the corners toward the centre (calm, low contrast)
  const rib = (cx, w, hgt, base) => {
    for (let t = 0; t <= 1; t += 0.002) { const ang = Math.PI * t, x = cx + Math.cos(ang) * w, y = base - Math.sin(ang) * hgt; const a = clamp(0.25 + (y - 40) / 220);
      for (let k = 0; k < 6; k++) { const xx = Math.round(x), yy = Math.round(y) + k; if (xx < 0 || xx >= 350 || yy >= SKY - 12) continue; const lum = k < 1 ? 0.7 : k < 4 ? 0.25 : -0.2; S.set(xx, yy, mix(S.get(xx, yy).slice(0, 3), lum > 0.5 ? hex('#7a6a98') : lum > 0 ? hex('#4a3a68') : dark, 0.75 * a)); } }
  };
  rib(70, 140, 150, SKY - 12); rib(280, 140, 150, SKY - 12);
  // wooden beams across the ceiling
  for (const by of [150, 236]) {
    const a = clamp(0.2 + (by - 40) / 240);
    for (let x = 0; x < 350; x++) for (let j = 0; j < 9; j++) { const l = j === 0 ? hex('#7a5a52') : j < 6 ? hex('#4a3446') : j < 8 ? hex('#33223a') : dark; S.set(x, by + j, mix(S.get(x, by + j).slice(0, 3), l, 0.8 * a)); }
    for (const sx of [30, 120, 210, 300]) { S.rect(sx, by + 2, 4, 4, mix(S.get(sx, by + 2).slice(0, 3), hex('#1a1226'), 0.7 * a)); S.set(sx + 1, by + 3, mix(S.get(sx, by).slice(0, 3), hex('#8a7aa8'), 0.5 * a)); }
  }
  // hanging chains from the upper beam, small banners on the lower one (muted)
  for (const x of [58, 226]) for (let j = 0; j < 46; j++) { const y = 159 + j; const a = 0.75; S.set(x + (j % 4 < 2 ? 0 : 1), y, mix(S.get(x, y).slice(0, 3), j % 4 < 2 ? hex('#8a7aa8') : hex('#3a2c58'), a)); }
  for (const [x, c1, c2] of [[150, '#4a3a8a', '#7a6ab8'], [290, '#6a2a58', '#a8508a']]) { for (let j = 0; j < 40; j++) for (let i = 0; i < 18; i++) { const tail = j > 28 && Math.abs(i - 9) < j - 28 - 0; if (tail && j > 28 + (9 - Math.abs(i - 9))) continue; const y = 246 + j; if (j > 34 - (i < 9 ? i : 18 - i) * 0 && j > 33 + Math.abs(i - 9) * -0 + 6 - Math.abs(i - 9) * 0.6) continue; S.set(x + i, y, mix(S.get(x + i, y).slice(0, 3), i % 6 < 3 ? hex(c1) : hex(c2), 0.6)); } }
  // moss tufts on the lower courses
  for (const x of [42, 188, 296, 120]) for (let j = 0; j < 8; j++) S.set(x + (j % 2), 296 + j, ramp(MOSS, 0.6 - j * 0.07, x, 296 + j));
  // flat sky colour at the very top
  for (let y = 0; y < 30; y++) for (let x = 0; x < 350; x++) if (bay(x, y) < clamp(1 - y / 30) ** 0.8 * 0 + (y < 14 ? 1 : (30 - y) / 16)) S.set(x, y, top);
  // seam: contact shadow above the beam's lit top edge
  for (let x = 0; x < 350; x++) { S.set(x, SKY - 1, hex('#1e1230')); S.set(x, SKY - 2, hex('#2a1a42')); }
  return S;
}

// ============================================================
// PREVIEW
// ============================================================
function loadPng(rel) { return decode(fs.readFileSync(path.join(AREAS, rel))); }
function blit(canvas, im, ox, oy, tint) {
  for (let y = 0; y < im.h; y++) for (let x = 0; x < im.w; x++) {
    const i = (y * im.w + x) * 4, a = im.data[i + 3]; if (!a) continue; const X = x + ox, Y = y + oy; if (X < 0 || Y < 0 || X >= canvas.w || Y >= canvas.h) continue;
    let c = [im.data[i], im.data[i + 1], im.data[i + 2]]; if (tint) c = c.map((v, k) => v * tint[k] / 255);
    canvas.set(X, Y, c);
  }
}
function scene(id, state) {
  const C = new Pix(350, SKY + 300), cfg = JSON.parse(fs.readFileSync(path.join(AREAS, id, 'anim.json'), 'utf8'));
  blit(C, loadPng(`${id}/sky.png`), 0, 0); blit(C, loadPng(`${id}/background.png`), 0, SKY); blit(C, loadPng(`${id}/floor.png`), 0, SKY + 228);
  blit(C, loadPng(`${id}/shadow.png`), 18, SKY + 270);
  // lifter placeholder
  for (let y = 0; y < 128; y++) for (let x = 0; x < 104; x++) if (x < 2 || y < 2 || x > 101 || y > 125) C.set(12 + x, SKY + 146 + y, [90, 90, 100]); else if ((x + y) % 7 === 0) C.set(12 + x, SKY + 146 + y, [60, 60, 70]);
  const o = cfg.object.frames.idle.pos, fr = state === 'tap' ? 'tap' : state === 'hit' ? 'hit' : 'idle';
  // marks
  const mk = cfg.marks;
  if (id === 'riptide') { const [ax, ay, aw, ah] = mk.layout.area.map(v => v * 2); const m = loadPng(`${id}/mark.png`), f = loadPng(`${id}/mark_fifth.png`); for (let i = 0; i < 7; i++) { const row = Math.floor(i / 4), col = i % 4, n = row === 1 ? 3 : 4; const x = ax + (aw - n * 22) / 2 + col * 22 + 1, y = SKY + ay + ah - 16 - row * 16; blit(C, i === 4 ? f : m, Math.round(x), Math.round(y)); } }
  if (id === 'gainsgard') { const m = loadPng(`${id}/mark.png`), f = loadPng(`${id}/mark_fifth.png`); blit(C, loadPng(`${id}/object_${fr}.png`), o[0] * 2, SKY + o[1] * 2); for (let g = 0; g < 2; g++) { const ox = 68 * 2 + (g % 2) * 64, oy = SKY + 50 * 2; const n = g === 0 ? 4 : 2; for (let s = 0; s < n; s++) blit(C, m, ox + s * 12, oy + 6); if (g === 0) blit(C, f, ox - 2, oy + 4 + 2 + 4); } }
  else blit(C, loadPng(`${id}/object_${fr}.png`), o[0] * 2, SKY + o[1] * 2);
  if (id === 'rustbelt') { const m = loadPng(`${id}/mark.png`), cols = ['#c9b8e8', '#c6ff3d', '#3fd2ff', '#a77bff', '#ffa033', '#ff5fb0'].map(hex); for (let i = 0; i < 6; i++) blit(C, m, 99 * 2 + i * 22, SKY + 39 * 2, cols[i]); }
  if (state === 'hit') { blit(C, loadPng(`${id}/burst_4.png`), cfg.burst.pos[0] * 2, SKY + cfg.burst.pos[1] * 2); if (id !== 'gainsgard') blit(C, loadPng(`${id}/fx_${id === 'riptide' ? 3 : 4}.png`), 0, SKY); }
  return C;
}
function preview() {
  const ids = ['riptide', 'gainsgard', 'rustbelt'], states = ['idle', 'tap', 'hit'];
  const out = new Pix(350 * 3 + 20, (SKY + 300 + 10) * 3 + 10);
  for (let i = 0; i < out.d.length; i += 4) { out.d[i] = 20; out.d[i + 1] = 14; out.d[i + 2] = 30; }
  ids.forEach((id, r) => states.forEach((st, c) => { const C = scene(id, st); for (let y = 0; y < C.h; y++) for (let x = 0; x < C.w; x++) { const o = (y * C.w + x) * 4; out.set(x + c * 360, y + r * (SKY + 310), [C.d[o], C.d[o + 1], C.d[o + 2]]); } }));
  fs.writeFileSync(path.join(ROOT, 'tools/art_hd/preview_objects_a.png'), out.bytes());
}

// ============================================================
// MAIN
// ============================================================
for (const id of ['riptide', 'gainsgard', 'rustbelt']) { shadow().save(`${id}/shadow.png`); bursts(id); }
chestIdle().save('riptide/object_idle.png'); chestTap().save('riptide/object_tap.png'); chestHit().save('riptide/object_hit.png');
riptideFx('riptide', false); riptideFx('riptide', true); riptideMarks('riptide');
barrelIdle().save('rustbelt/object_idle.png'); barrelTap().save('rustbelt/object_tap.png'); scorch().save('rustbelt/object_hit.png');
rustFx('rustbelt'); rustMark('rustbelt');
wallIdle().save('gainsgard/object_idle.png'); wallTap().save('gainsgard/object_tap.png'); wallHit().save('gainsgard/object_hit.png');
chalkMark('gainsgard');
skyRiptide().save('riptide/sky.png'); skyGains().save('gainsgard/sky.png'); skyRust().save('rustbelt/sky.png');
preview();
console.log('done');
