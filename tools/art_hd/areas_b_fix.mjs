// HD (2x) redraw of the arcade + frostbite background.png and floor.png.
// Replaces the noisy result of areas_b.mjs for these 4 files.
// Run: node tools/art_hd/areas_b_fix.mjs
// Reads the clean 1x originals from git commit 40ba8ee. Node only, no packages.
// All shapes are drawn by rule (no random noise). Bayer dither only in smooth gradients.
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { png, decode } from '../moodboard/png.mjs';

const BASE = '40ba8ee';
const W = 350, H = 300, FH = 72, GROUND = 228; // 2x sizes; the floor starts at y 228

// ---------- helpers ----------
const hex = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const mix = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t));
const BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const thr = (x, y) => (BAYER[y & 3][x & 3] + 0.5) / 16;
const hash = (a, b = 0, c = 0) => { let h = (a * 374761393 + b * 668265263 + c * 2147483647) | 0; h = (h ^ (h >>> 13)) * 1274126177 | 0; return ((h ^ (h >>> 16)) >>> 0); };
// gradient step: v in [0, n-1] -> index with ordered dither (smooth gradients only)
const dstep = (x, y, v) => { const f = Math.floor(v); return f + ((v - f) > thr(x, y) ? 1 : 0); };

class Canvas {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
  px(x, y, c) { x |= 0; y |= 0; if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const o = (y * this.w + x) * 4; this.d[o] = c[0]; this.d[o + 1] = c[1]; this.d[o + 2] = c[2]; this.d[o + 3] = 255; }
  get(x, y) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return [0, 0, 0]; const o = (y * this.w + x) * 4; return [this.d[o], this.d[o + 1], this.d[o + 2]]; }
  rect(x, y, w, h, c) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.px(x + i, y + j, c); }
  line(x0, y0, x1, y1, c) { x0 |= 0; y0 |= 0; x1 |= 0; y1 |= 0; const dx = Math.abs(x1 - x0), dy = -Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1; let e = dx + dy; for (;;) { this.px(x0, y0, c); if (x0 === x1 && y0 === y1) break; const e2 = 2 * e; if (e2 >= dy) { e += dy; x0 += sx; } if (e2 <= dx) { e += dx; y0 += sy; } } }
  ell(cx, cy, rx, ry, fn) { for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) { const u = (x - cx) / rx, v = (y - cy) / ry, r = u * u + v * v; if (r <= 1) fn(x, y, r, u, v); } }
}
const save = (cv, file) => fs.writeFileSync(file, png(cv.w, cv.h, (x, y) => { const o = (y * cv.w + x) * 4; return [cv.d[o], cv.d[o + 1], cv.d[o + 2], 255]; }));
function orig(area, name) {
  return decode(execFileSync('git', ['show', `${BASE}:assets/areas/${area}/${name}.png`], { maxBuffer: 1 << 24 }));
}
const o1 = (img, x, y) => { const o = (y * img.w + x) * 4; return [img.data[o], img.data[o + 1], img.data[o + 2]]; };
const same = (a, b) => a[0] === b[0] && a[1] === b[1] && a[2] === b[2];

// palette (grounds and neons from docs/moodboard/palette.json, plus hue-shifted steps)
const INK = hex('#0b0414'), BG = hex('#12061f'), SURF = hex('#1f0d36'), RAISED = hex('#2a1148'), BORDER = hex('#4b2a7a');
const LIME = hex('#c6ff3d'), LIME_HI = hex('#dcfb7b'), LIME_SH = hex('#849b42');
const PINK = hex('#ff5fb0'), PINK_HI = hex('#ff98c2'), PINK_SH = hex('#a63e84');
const SKY = hex('#3fd2ff'), SKY_SH = hex('#3681b2'), SKY_HI = hex('#88dff3');
const VIO = hex('#a77bff'), VIO_HI = hex('#c8a9f3'), VIO_SH = hex('#724eb2');
const ORANGE = hex('#ffa033');
const TEXT = hex('#f6eeff'), MUTED = hex('#c9b8e8');

// =====================================================================
// ARCADE UNDERPASS
// =====================================================================
function arcadeBackground() {
  const src = orig('arcade', 'background');
  const cv = new Canvas(W, H);
  const wallTones = [hex('#150a26'), hex('#170b2a'), hex('#190c2e'), hex('#140924')];
  const WALL_TOP = 34, BH = 28, BW = 56;

  // ---- concrete wall: blocks with seams, bevels, and gradients ----
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (y < WALL_TOP) continue;
    const r = Math.floor((y - WALL_TOP) / BH), off = (r & 1) ? BW / 2 : 0;
    const col = Math.floor((x + off) / BW), lx = (x + off) % BW, ly = (y - WALL_TOP) % BH;
    let face = wallTones[hash(col, r, 7) % wallTones.length];
    // darker near the ceiling, brighter violet bounce light near the floor (smooth gradient -> dither)
    const dark = Math.max(0, (110 - y) / 76);
    const bounce = Math.max(0, (y - 150) / 78);
    if (dark > 0) face = mix(face, INK, 0.55 * (dstep(x, y, dark * 3) / 3));
    if (bounce > 0) face = mix(face, RAISED, 0.8 * (dstep(x, y, bounce * 3) / 3));
    let c = face;
    if (ly === 0 || lx === 0) c = hex('#09030f');                 // mortar seam
    else if (ly === 1) c = mix(face, BORDER, 0.30);               // lit top edge of the block
    else if (lx === 1) c = mix(face, BORDER, 0.14);               // lit left edge
    else if (ly === BH - 1) c = mix(face, INK, 0.45);             // shaded bottom edge
    else if (lx === BW - 1) c = mix(face, INK, 0.25);
    cv.px(x, y, c);
  }
  // chipped corners and hairline cracks on a few blocks (placed by rule)
  for (const [bx, by] of [[3, 2], [5, 4], [1, 5], [6, 1], [2, 3]]) {
    const r = by, off = (r & 1) ? BW / 2 : 0;
    const x0 = bx * BW - off + 8, y0 = WALL_TOP + r * BH + 4;
    const crack = [[0, 0], [1, 1], [1, 2], [2, 3], [2, 4], [3, 5], [3, 6], [4, 7], [4, 8], [5, 9], [5, 10], [6, 11]];
    for (const [i, j] of crack) { cv.px(x0 + i, y0 + j, hex('#0b0414')); cv.px(x0 + i + 1, y0 + j, hex('#241042')); }
    cv.rect(x0 + 20, y0 + 18, 3, 2, mix(wallTones[0], BORDER, 0.35));   // chip
  }
  // grime streaks: dark runs below the pipe hangers, with a damp tail (dither fade)
  const streaks = [];
  for (let k = 0; k < 7; k++) streaks.push([22 + 52 * k, 54, 34 + (hash(k, 3) % 5) * 12, 2]);
  for (const [sx, sy, len, w] of [[44, 100, 50, 3], [118, 90, 40, 2], [196, 104, 60, 3], [262, 80, 44, 2], [296, 110, 52, 3], [330, 96, 36, 2], [6, 150, 44, 2], [150, 150, 30, 2]]) streaks.push([sx, sy, len, w]);
  for (const [sx, sy, len, w] of streaks) {
    for (let j = 0; j < len; j++) {
      const t = j / len, wid = w;
      const keep = t < 0.6 ? 1 : (1 - (t - 0.6) / 0.4);
      for (let i = 0; i < wid; i++) {
        if (keep > thr(sx + i, sy + j) + 0.001 || keep >= 1) {
          const cur = cv.get(sx + i, sy + j);
          cv.px(sx + i, sy + j, mix(cur, INK, i === 0 ? 0.55 : 0.35));
        }
      }
    }
    cv.px(sx - 1, sy + 1, mix(cv.get(sx - 1, sy + 1), BORDER, 0.2));
  }
  // damp stains: smooth gradient patches (dither is allowed here)
  for (const [cx, cy, rx, ry] of [[250, 170, 40, 24], [120, 190, 30, 18], [40, 120, 26, 16], [320, 200, 34, 20]]) {
    cv.ell(cx, cy, rx, ry, (x, y, r) => {
      const v = (1 - r) * 2.6; const s = dstep(x, y, Math.min(v, 2));
      if (s > 0) cv.px(x, y, mix(cv.get(x, y), INK, 0.18 * s));
    });
  }
  // baseboard / curb strip above the floor
  for (let y = 214; y < GROUND; y++) for (let x = 0; x < W; x++) {
    const ly = y - 214, seam = (x % 70) < 2;
    let c = ly === 0 ? hex('#09030f') : ly === 1 ? mix(RAISED, BORDER, 0.5) : ly < 5 ? RAISED : ly < 10 ? mix(RAISED, SURF, 0.5) : SURF;
    if (seam && ly > 0) c = hex('#120824');
    cv.px(x, y, c);
  }

  // ---- ceiling slab ----
  for (let y = 0; y < 34; y++) for (let x = 0; x < W; x++) {
    let c;
    if (y < 2) c = mix(RAISED, BORDER, 0.55);
    else if (y < 28) {
      const v = y / 28; c = mix(mix(RAISED, hex('#32185a'), 0.5), SURF, [0, 0.4, 0.8][Math.min(2, dstep(x, y, v * 2))] || 0);
      if (y === 18) c = mix(RAISED, BORDER, 0.5); // beam line
      if (y === 19) c = hex('#140826');
      if ((x % 104) < 2) c = (x % 104) === 0 ? hex('#140826') : mix(RAISED, BORDER, 0.5); // panel joint
    } else if (y < 30) c = mix(SURF, INK, (y - 27) / 3);
    else c = INK;                     // dark band under the slab
    cv.px(x, y, c);
  }
  for (let x = 10; x < W; x += 26) { // rivets on the slab
    if ((x % 104) < 6) continue;
    cv.rect(x, 9, 2, 2, hex('#8672a5')); cv.px(x + 1, 10, hex('#3a1d63'));
    cv.rect(x, 23, 2, 2, hex('#6b5a8f')); cv.px(x + 1, 24, hex('#2a1148'));
  }
  // main pipe with cylinder shading and flanges
  const pipeRows = [INK, hex('#5a3a92'), hex('#7a58b8'), hex('#5a3a92'), hex('#432a73'), hex('#3a1d63'), hex('#2d1650'), hex('#26123f'), hex('#1d0e33'), hex('#150a26'), hex('#0e0719'), INK];
  for (let j = 0; j < 12; j++) for (let x = 0; x < W; x++) cv.px(x, 36 + j, pipeRows[j]);
  for (let x = 0; x < W; x += 104) { // flange
    cv.rect(x + 40, 34, 8, 16, hex('#2d1650'));
    cv.rect(x + 40, 34, 2, 16, hex('#6b4aa8')); cv.rect(x + 46, 34, 2, 16, INK);
    cv.rect(x + 40, 34, 8, 1, INK); cv.rect(x + 40, 49, 8, 1, INK);
    cv.rect(x + 43, 38, 2, 2, hex('#9b7bd8')); cv.rect(x + 43, 44, 2, 2, hex('#9b7bd8'));
  }
  // thin conduit below it
  const condRows = [INK, hex('#4b2a7a'), hex('#35205f'), hex('#26123f'), INK];
  for (let j = 0; j < 5; j++) for (let x = 0; x < W; x++) cv.px(x, 51 + j, condRows[j]);
  // hanger clamps
  for (let x = 22; x < W; x += 52) {
    cv.rect(x - 2, 32, 8, 3, hex('#3a1d63')); cv.rect(x - 2, 32, 8, 1, hex('#6b4aa8'));
    cv.rect(x - 2, 35, 8, 22, hex('#2d1650')); cv.rect(x - 2, 35, 2, 22, hex('#5a3a92')); cv.rect(x + 4, 35, 2, 22, INK);
    cv.rect(x - 2, 35, 8, 1, INK); cv.rect(x - 2, 56, 8, 1, INK);
    cv.rect(x + 1, 40, 2, 2, hex('#9b7bd8'));
  }
  // drips
  for (const dx of [70, 178, 282]) { cv.rect(dx, 57, 2, 2, SKY_SH); cv.px(dx, 57, SKY_HI); }

  // ---- sign glow halo (1-2 px ring + wide dithered glow) ----
  const sx0 = 74, sy0 = 62, sx1 = 173, sy1 = 87; // lime frame, 2x
  const dist = (x, y) => { const dx = Math.max(sx0 - x, 0, x - sx1), dy = Math.max(sy0 - y, 0, y - sy1); return Math.hypot(dx, dy); };
  for (let y = 36; y < 140; y++) for (let x = 40; x < 215; x++) {
    const d = dist(x, y); if (d < 0.5 || d > 11) continue;
    const cur = cv.get(x, y);
    if (d <= 1.5) cv.px(x, y, mix(cur, LIME, 0.55));
    else if (d <= 2.5) cv.px(x, y, mix(cur, LIME, 0.32));
    else { const s = 1 - (d - 2.5) / 8.5; const k = dstep(x, y, s * 2.4); if (k > 0) cv.px(x, y, mix(cur, LIME, 0.07 * Math.min(k, 2))); }
  }
  // pink glow near the pink board
  for (let y = 40; y < 130; y++) for (let x = 0; x < 80; x++) {
    const dx = Math.max(12 - x, 0, x - 58), dy = Math.max(56 - y, 0, y - 114), d = Math.hypot(dx, dy);
    if (d < 0.5 || d > 12) continue;
    const cur = cv.get(x, y);
    if (d <= 1.5) cv.px(x, y, mix(cur, PINK, 0.35));
    else { const k = dstep(x, y, (1 - d / 12) * 2.2); if (k > 0) cv.px(x, y, mix(cur, PINK, 0.06 * Math.min(k, 2))); }
  }

  // ---- poster scraps ----
  function poster(x, y, w, h, base, accent, kind) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      // torn top-right corner and curled bottom-left corner
      if (i > w - 1 - Math.max(0, 7 - j) && j < 7) continue;
      if (i < Math.max(0, 5 - (h - 1 - j)) && j > h - 6) continue;
      let c = base;
      if (j === 0 || i === 0) c = mix(base, TEXT, 0.18);
      cv.px(x + i, y + j, c);
    }
    // graphic
    if (kind === 0) { for (let k = 0; k < 4; k++) cv.rect(x + 3, y + 8 + k * 5, w - 6 - (k % 2) * 4, 2, accent); cv.rect(x + 3, y + 3, 7, 3, mix(accent, TEXT, 0.4)); }
    if (kind === 1) { cv.ell(x + w / 2, y + h * 0.42, 6, 6, (px, py, r) => cv.px(px, py, r > 0.55 ? accent : mix(accent, TEXT, 0.35))); cv.rect(x + 4, y + h - 9, w - 8, 2, accent); }
    if (kind === 2) { for (let k = 0; k < 5; k++) cv.rect(x + 2 + k * 4, y + 4, 2, h - 14, k % 2 ? accent : mix(accent, INK, 0.3)); cv.rect(x + 3, y + h - 8, w - 6, 2, mix(base, TEXT, 0.4)); }
    // tape
    cv.rect(x + w / 2 - 3, y - 2, 7, 3, mix(hex('#c9b8e8'), BG, 0.5));
    cv.rect(x + 1, y + h - 1, w - 2, 1, mix(base, INK, 0.5)); // shadow edge
  }
  poster(6, 120, 22, 26, mix(PINK_SH, BG, 0.45), PINK_SH, 0);
  poster(120, 134, 22, 32, mix(SKY_SH, BG, 0.55), SKY_SH, 1);
  poster(176, 140, 20, 24, mix(VIO_SH, BG, 0.55), VIO, 2);

  // ---- distant arcade cabinets (dim, only in empty wall space between lifter and object) ----
  function cabinet(x, top, w, accent, screen) {
    const bottom = GROUND, h = bottom - top;
    cv.rect(x - 1, top - 1, w + 2, h + 1, INK);
    cv.rect(x, top, w, h, mix(SURF, hex('#2a1550'), 0.6));
    cv.rect(x, top, 2, h, mix(BORDER, SURF, 0.4));          // lit side edge
    cv.rect(x + w - 2, top, 2, h, mix(SURF, INK, 0.5));     // shaded side
    cv.rect(x + 2, top + 2, w - 4, 6, mix(accent, INK, 0.45));        // marquee
    cv.rect(x + 2, top + 2, w - 4, 1, mix(accent, TEXT, 0.15));
    cv.rect(x + 4, top + 5, w - 8, 1, accent);
    cv.rect(x + 3, top + 10, w - 6, 14, INK);               // screen bezel
    for (let j = 0; j < 12; j++) for (let i = 0; i < w - 8; i++) cv.px(x + 4 + i, top + 11 + j, (j & 1) ? mix(screen, INK, 0.55) : mix(screen, INK, 0.4)); // scanlines
    cv.rect(x + 6, top + 14, 3, 2, TEXT); cv.rect(x + w - 11, top + 17, 3, 2, mix(accent, TEXT, 0.4)); // game pixels
    cv.rect(x + 2, top + 26, w - 4, 4, mix(SURF, INK, 0.3));          // control panel
    cv.px(x + 5, top + 27, LIME_SH); cv.px(x + 8, top + 27, PINK_SH); cv.px(x + 11, top + 27, ORANGE);
    cv.rect(x + 4, top + 33, w - 8, h - 36, mix(SURF, INK, 0.35));    // lower door
    cv.rect(x + 4, top + 33, w - 8, 1, mix(BORDER, SURF, 0.5));
    // screen glow on the wall (smooth gradient)
    for (let j = -8; j < 14; j++) for (let i = -10; i < w + 10; i++) {
      const px = x + i, py = top + 10 + j;
      if (i >= -1 && i <= w && j >= -11 && j < 0) continue;
      const dxx = Math.max(-i, 0, i - (w - 1)), d = Math.hypot(dxx, Math.max(0, j - 13)) + (j < 0 ? -j * 0.5 : 0);
      if (i >= 0 && i < w && j >= 0 && j < h) continue;
      if (d > 0 && d < 8 && (1 - d / 8) * 0.8 > thr(px, py)) cv.px(px, py, mix(cv.get(px, py), screen, 0.10));
    }
  }
  cabinet(126, 192, 22, PINK_SH, SKY_SH);
  cabinet(154, 184, 22, hex('#3a2a8a'), hex('#5a8a3a'));
  cabinet(182, 194, 20, LIME_SH, hex('#a63e84'));

  // ---- protect the existing sign, pink board and text: copy from the clean 1x original ----
  const ground = [BG, hex('#461a3f')];
  const isGround = (c) => ground.some((g) => same(g, c));
  const copyRect = (x0, y0, x1, y1) => {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const c = o1(src, x, y);
      if (isGround(c)) continue;
      cv.rect(x * 2, y * 2, 2, 2, c);
    }
  };
  copyRect(6, 28, 29, 57); copyRect(35, 28, 88, 45); copyRect(36, 54, 95, 63);
  // glow ring and sign outline: nothing else is allowed on top of the sign.
  // text glow: 1 px halo around pink and blue letters
  for (let y = 104; y < 134; y++) for (let x = 66; x < 196; x++) {
    const c = cv.get(x, y);
    const isP = same(c, PINK), isB = same(c, hex('#3bbee9')) || same(c, hex('#3abde8'));
    if (!isP && !isB) continue;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const n = cv.get(x + dx, y + dy);
      if (same(n, PINK) || same(n, hex('#3bbee9')) || same(n, hex('#3abde8')) || same(n, INK)) continue;
      cv.px(x + dx, y + dy, mix(n, isP ? PINK : SKY, 0.32));
    }
  }
  // cables: two sagging runs between the hangers, kept above the sign (y < 58)
  for (let k = 0; k < 7; k++) {
    const xa = 24 + 52 * k, xb = xa + 52;
    for (let x = xa; x <= xb; x++) {
      const t = (x - xa) / 52, sag = Math.round(Math.sin(t * Math.PI) * 4);
      cv.px(x, 55 + sag, mix(PINK_SH, INK, 0.2)); cv.px(x, 56 + sag, mix(PINK_SH, INK, 0.65));
      const sag2 = Math.round(Math.sin(t * Math.PI) * 3);
      cv.px(x, 53 + sag2, mix(SKY_SH, INK, 0.2));
    }
    cv.px(xa + 26, 56 + 4, PINK_HI); cv.px(xa + 20, 54 + 3, SKY_HI);
  }
  // dust on the lit pink sign cap: nothing. Done.
  return cv;
}

function arcadeFloor() {
  const cv = new Canvas(W, FH);
  const SLAB = 60;
  const slabTones = [hex('#724eb2'), hex('#6c49aa'), hex('#7653b8')];
  for (let y = 0; y < FH; y++) for (let x = 0; x < W; x++) {
    let c;
    if (y < 4) c = INK;
    else if (y < 6) c = VIO_HI;
    else if (y < 10) c = mix(VIO, VIO_SH, 0.2 * (y - 6) / 3);
    else if (y < 12) c = mix(VIO_SH, hex('#593597'), 0.5);
    else {
      const col = Math.floor(x / SLAB), base = slabTones[hash(col, 5) % 3];
      const v = (y - 12) / (FH - 12) * 2.2;   // darker toward the bottom (smooth -> dither)
      const s = dstep(x, y, Math.min(v, 2));
      c = s === 0 ? base : s === 1 ? mix(base, hex('#593597'), 0.55) : mix(base, hex('#472a82'), 0.9);
      const lx = x % SLAB;
      if (lx === 0) c = hex('#341d63');                    // seam
      else if (lx === 1) c = mix(c, hex('#2a1550'), 0.55); // seam shadow
      else if (lx === 2) c = mix(c, VIO_HI, 0.22);         // lit slab edge
      else if (lx === SLAB - 1) c = mix(c, INK, 0.2);
    }
    cv.px(x, y, c);
  }
  // seam wear: broken pieces (chips) along some seams, hairline cracks
  for (const [sx, sy, len] of [[60, 14, 10], [120, 40, 14], [180, 22, 8], [240, 50, 12], [300, 30, 9], [60, 52, 8]]) {
    for (let j = 0; j < len; j++) { cv.px(sx + (j >> 2) % 3 - 1, sy + j, hex('#2a1550')); cv.px(sx + (j >> 2) % 3, sy + j, hex('#3d2475')); }
  }
  for (const [x0, y0] of [[22, 20], [214, 44], [268, 16], [322, 52]]) {
    const pts = [[0, 0], [3, 2], [5, 1], [8, 4], [10, 3], [14, 6]];
    for (let i = 0; i < pts.length - 1; i++) cv.line(x0 + pts[i][0], y0 + pts[i][1], x0 + pts[i + 1][0], y0 + pts[i + 1][1], hex('#3a2272'));
    cv.px(x0 + 4, y0 + 3, hex('#8a63cc'));
  }
  // scuffs and tyre marks (short lighter and darker dashes in fixed rows)
  const scuffs = [[14, 16, 14, 1], [34, 40, 18, 0], [84, 22, 12, 0], [96, 48, 16, 1], [212, 18, 18, 0], [256, 38, 14, 1], [292, 60, 18, 0], [330, 24, 12, 1], [160, 62, 16, 1], [190, 50, 10, 0], [8, 66, 12, 0]];
  for (const [x0, y0, len, lite] of scuffs) {
    for (let i = 0; i < len; i++) { const c = lite ? mix(cv.get(x0 + i, y0), VIO_HI, 0.22) : mix(cv.get(x0 + i, y0), hex('#3d2475'), 0.5); cv.px(x0 + i, y0, c); if (i % 4 !== 3) cv.px(x0 + i + 1, y0 + 1, lite ? mix(cv.get(x0 + i, y0 + 1), VIO_HI, 0.1) : mix(cv.get(x0 + i, y0 + 1), hex('#3d2475'), 0.28)); }
  }
  // oil stain: smooth dithered gradient
  cv.ell(262, 44, 22, 8, (x, y, r) => { const s = dstep(x, y, Math.min((1 - r) * 3, 2)); if (s > 0) cv.px(x, y, mix(cv.get(x, y), hex('#3d2475'), 0.28 * s)); });
  // lime dashed line with wear
  for (let x0 = 0; x0 < W; x0 += 40) {
    for (let j = 0; j < 4; j++) for (let i = 0; i < 22; i++) {
      const x = x0 + i, y = 58 + j;
      if (x >= W) continue;
      let c = j === 0 ? LIME_HI : j === 3 ? LIME_SH : LIME;
      const k = Math.floor(x0 / 40);
      if (k % 3 === 1 && i > 17) continue; // worn off end
      if (k % 4 === 2 && i >= 7 && i < 9) { cv.px(x, y, mix(cv.get(x, y), LIME_SH, 0.55)); continue; } // scraped middle
      cv.px(x, y, c);
    }
    cv.rect(x0, 62, 22, 1, mix(cv.get(x0, 62), INK, 0.35)); // dash shadow
  }
  // puddle (centre x 160, y 35): rim, dark water, neon reflections, ripple lines
  const pcx = 160, pcy = 35, prx = 40, pry = 9;
  cv.ell(pcx, pcy + 1, prx + 4, pry + 3, (x, y, r) => { const s = dstep(x, y, Math.min((1 - r) * 5, 2)); if (s > 0) cv.px(x, y, mix(cv.get(x, y), hex('#3d2475'), 0.5 * s / 2)); }); // wet sheen outside
  cv.ell(pcx, pcy, prx, pry, (x, y, r, u, v) => {
    const edge = r > 0.8;
    let c = mix(hex('#10061c'), hex('#2a1148'), Math.min(1, Math.max(0, v + 0.5)) * 0.7);
    if (edge) c = mix(c, hex('#1d0d36'), 0.5);
    cv.px(x, y, c);
  });
  // rim highlight on the lower edge, dark rim on the upper edge
  cv.ell(pcx, pcy, prx, pry, (x, y, r, u, v) => { if (r > 0.82 && v > 0.15) cv.px(x, y, mix(cv.get(x, y), VIO, 0.7)); if (r > 0.82 && v < -0.3) cv.px(x, y, INK); });
  // reflections: broken vertical streaks of the neon sign (lime) and the SWOLE letters (pink, sky)
  const streak = (x0, col, rows) => {
    for (const [ya, yb, w] of rows) for (let y = ya; y < yb; y++) for (let i = 0; i < w; i++) {
      const jx = x0 + i;
      const inside = ((jx - pcx) / prx) ** 2 + ((y - pcy) / pry) ** 2 < 0.78;
      if (inside) cv.px(jx, y, i === 0 && w > 2 ? mix(col, TEXT, 0.25) : col);
    }
  };
  streak(152, LIME, [[27, 33, 5], [35, 39, 4], [41, 43, 3]]);
  streak(133, PINK, [[28, 33, 4], [35, 38, 3]]);
  streak(176, SKY_SH, [[28, 32, 3], [34, 37, 2]]);
  for (const [rx, ry, rw] of [[140, 33, 14], [168, 38, 16], [126, 37, 8]]) cv.rect(rx, ry, rw, 1, mix(cv.get(rx, ry), VIO_HI, 0.4)); // ripples
  cv.rect(154, 30, 2, 1, TEXT); cv.rect(135, 31, 2, 1, TEXT);
  // small second puddle
  cv.ell(300, 22, 12, 3, (x, y, r, u, v) => { cv.px(x, y, r > 0.75 ? hex('#1d0d36') : mix(hex('#10061c'), hex('#2a1148'), 0.35)); if (r > 0.72 && v > 0.1) cv.px(x, y, mix(VIO, VIO_SH, 0.3)); });
  cv.rect(296, 21, 6, 1, LIME_SH);
  return cv;
}

// =====================================================================
// FROSTBITE SUMMIT
// =====================================================================
function frostbiteBackground() {
  const src = orig('frostbite', 'background');
  const cv = new Canvas(W, H);

  const SKY0 = [hex('#140828'), hex('#1a0b3b'), hex('#200f48'), hex('#271553')];
  const skyAt = (x, y) => { const v = Math.min(y, GROUND) / GROUND * 3; return SKY0[Math.min(3, dstep(x, y, v))]; };

  // ---- sky ----
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) cv.px(x, y, y >= GROUND ? hex('#1a0b3b') : skyAt(x, y));

  // ---- stars: sparse, single pixels, a few bright 2 px ones (placed by a spacing rule) ----
  const stars = [];
  for (let n = 0; n < 700 && stars.length < 62; n++) {
    const x = 4 + hash(n, 1, 9) % 340, y = 4 + hash(n, 2, 9) % 200;
    if (stars.every(([sx, sy]) => Math.hypot(sx - x, sy - y) > 17)) stars.push([x, y]);
  }
  stars.forEach(([x, y], i) => {
    const kind = i % 11 === 0 ? 2 : i % 3 === 0 ? 1 : 0;
    if (kind === 2) { cv.px(x, y, TEXT); cv.px(x + 1, y, TEXT); cv.px(x, y - 1, hex('#8672a5')); cv.px(x, y + 1, hex('#61439d')); }
    else if (kind === 1) cv.px(x, y, MUTED);
    else cv.px(x, y, i % 2 ? hex('#8672a5') : hex('#61439d'));
  });

  // ---- aurora: three straight bands at full 2x resolution, soft edges, glow above ----
  const bandTop = (x) => 52 - 0.1034 * x;
  const bands = [[0, 16, hex('#61439d'), hex('#7d5cc0'), hex('#4c3385')], [22, 10, hex('#2b6593'), hex('#3d86b8'), hex('#22507a')], [38, 6, hex('#45483c'), hex('#5e6350'), hex('#35382d')]];
  for (let x = 0; x < W; x++) {
    const bt = bandTop(x);
    // soft glow and faint rays above the purple band
    for (let up = 1; up <= 10; up++) {
      const y = Math.round(bt - up); if (y < 0) continue;
      const ray = 0.5 + 0.5 * Math.sin(x * 0.09 + Math.sin(x * 0.021) * 2);
      const s = (1 - up / 10) * 1.0;
      const k = dstep(x, y, s * 2); if (k > 0) cv.px(x, y, mix(cv.get(x, y), hex('#61439d'), 0.12 * k));
    }
    for (const [off, th, base, hi, lo] of bands) {
      for (let t = 0; t < th; t++) {
        const y = Math.round(bt + off + t);
        if (y < 0 || y >= GROUND) continue;
        let c = base;
        if (t < Math.min(4, th - 1)) c = mix(base, hi, 0.55 * (1 - t / 4));
        if (t >= th - 5) c = mix(base, lo, dstep(x, y, 2 * (t - (th - 5)) / 4) / 2 * 0.9);
        if (t === 0) c = (thr(x, y) > 0.5) ? mix(cv.get(x, y), base, 0.55) : mix(base, hi, 0.4);
        if (t === th - 1 && th > 6) c = (thr(x, y) > 0.5) ? mix(cv.get(x, y), lo, 0.45) : lo;
        cv.px(x, y, c);
      }
    }
  }

  // ---- distant back mountain (apex 64,80): hue-shifted faces, strata, snow cap ----
  const mHalf = (y) => 0.7 * (y - 80);
  const ridgeX = (y) => 64 + ((hash(Math.floor(y / 6), 4) % 5) - 2);
  const inMtn = (x, y) => y >= 80 && Math.abs(x - 64) <= mHalf(y);
  const strataTone = [0, -1, 0, 1, 0, -2];
  for (let y = 80; y < GROUND; y++) for (let x = 0; x < 200; x++) {
    if (!inMtn(x, y)) continue;
    const rx = ridgeX(y), left = x < rx;
    let base = left ? hex('#34195f') : hex('#22103f');
    const s = Math.floor((y + x * 0.35) / 9), seg = hash(Math.floor(x / 14), s, 2) % 3 !== 0;
    const tone = seg ? Math.sign(strataTone[((s % 6) + 6) % 6]) : 0;
    if (tone > 0) base = mix(base, left ? hex('#4a2d80') : hex('#2f1a5c'), 0.4);
    if (tone < 0) base = mix(base, left ? hex('#271250') : hex('#170a30'), 0.4);
    if (seg && ((y + Math.floor(x * 0.35)) % 9) === 0) base = mix(base, hex('#150a2b'), 0.7); // strata crack line
    else if (seg && ((y + Math.floor(x * 0.35)) % 9) === 1) base = mix(base, left ? hex('#5a3d96') : hex('#3b2370'), 0.5);
    // atmospheric haze near the ground (smooth -> dither)
    const hz = Math.max(0, (y - 165) / 63) * 2;
    if (hz > 0) base = mix(base, hex('#2c1a5e'), 0.5 * dstep(x, y, hz) / 2);
    // rim light on the left edge
    if (x - (64 - mHalf(y)) < 2) base = mix(base, hex('#6a49a8'), 0.8);
    cv.px(x, y, base);
  }
  // snow cap with ragged lower edge
  const capBottom = (x) => 99 - 0.18 * Math.abs(x - 64) + (hash(x >> 1, 6) % 4) - (hash(x >> 2, 7) % 3);
  for (let y = 80; y < 108; y++) for (let x = 20; x < 110; x++) {
    if (!inMtn(x, y) || y > capBottom(x)) continue;
    const rx = ridgeX(y), left = x < rx;
    const depth = capBottom(x) - y;
    let c = left ? hex('#e6ddf8') : hex('#a99bdc');
    if (depth < 3) c = left ? hex('#a99bdc') : hex('#8672a5');
    if (left && y - 80 < 5 && x > 60) c = TEXT;
    cv.px(x, y, c);
  }
  cv.px(58, 90, hex('#a4e1ff')); cv.px(59, 90, hex('#a4e1ff')); cv.px(66, 86, hex('#a4e1ff'));

  // ---- helpers for rocks, pines ----
  function pine(cx, base, Ht, Wd, pal, big) {
    const trunkH = big ? 6 : 3, F = Ht - trunkH, topY = base - Ht;
    // trunk
    for (let j = 0; j < trunkH + 3; j++) for (let i = -1; i <= 1; i++) cv.px(cx + i, base - trunkH - 2 + j, i < 0 ? pal.trunkL : i > 0 ? pal.trunkD : pal.trunk);
    const n = Math.max(3, Math.round(F / 15));
    for (let i = n - 1; i >= 0; i--) {
      // tiers drawn bottom first so upper ones overlap
      const t0 = topY + F * (i / (n + 0.7)), b0 = t0 + F * (1.7 / (n + 0.7)), wmax = Wd / 2 * (0.38 + 0.62 * (i + 1) / n);
      const hgt = Math.round(b0 - t0);
      for (let r = 0; r <= hgt; r++) {
        const y = Math.round(t0) + r, frac = r / hgt;
        let hw = wmax * (0.12 + 0.88 * Math.pow(frac, 0.95));
        hw += ((hash(y, i, cx) % 3) - 1) * 0.7;
        for (let dx = -Math.round(hw); dx <= Math.round(hw); dx++) {
          const rel = dx / Math.max(1, hw);
          let c = rel < -0.35 ? pal.lit : rel < 0.35 ? pal.mid : pal.shade;
          if (Math.abs(dx) >= Math.round(hw) - 0) c = pal.edge;
          if (r >= hgt - 1 && Math.abs(dx) < Math.round(hw) - 1) c = pal.under;       // dark underside of the tier
          // snow: top part of the tier, wavy lower boundary, lit left, shaded right
          const wave = Math.sin(dx * 0.9 + i * 2) * 1.2;
          if (frac < 0.42 + wave * 0.12 && Math.abs(dx) < hw * 0.86 && frac > 0.02 + (i === 0 ? 0 : 0)) c = rel < 0.05 ? pal.snowL : pal.snowD;
          if (r >= hgt - 2 && Math.abs(dx) >= Math.round(hw) - 3 && Math.abs(dx) <= Math.round(hw) && hgt > 7) c = rel < 0 ? pal.snowL : pal.snowD; // snow on the branch tips
          cv.px(cx + dx, y, c);
        }
      }
    }
    // snow tip at the top
    cv.px(cx, Math.round(topY), pal.snowL); cv.px(cx, Math.round(topY) + 1, pal.snowL);
    // mound at the foot
    cv.ell(cx, base + 1, Wd * 0.42, 3.2, (x, y, r, u, v) => { if (y <= base + 1) cv.px(x, y, u < -0.2 ? pal.snowL : pal.snowD); });
  }
  const palNear = { lit: hex('#2f6a8a'), mid: hex('#235079'), shade: hex('#19365a'), edge: hex('#0c1830'), under: hex('#11264a'), snowL: TEXT, snowD: MUTED, trunk: hex('#3a2342'), trunkL: hex('#5a3a52'), trunkD: hex('#1e1030') };
  const palFar = { lit: hex('#2d3a7a'), mid: hex('#242c64'), shade: hex('#1b2150'), edge: hex('#120f35'), under: hex('#161a42'), snowL: hex('#8672a5'), snowD: hex('#61439d'), trunk: hex('#241a40'), trunkL: hex('#34285a'), trunkD: hex('#150f2a') };

  function rock(cx, cy, rx, ry, seed) {
    for (let y = cy - ry; y <= cy + ry; y++) for (let x = cx - rx - 2; x <= cx + rx + 2; x++) {
      const u = (x - cx) / rx, v = (y - cy) / ry;
      const edge = 1 + ((hash(Math.floor((x - cx + 40) / 3), seed) % 5) - 2) * 0.07;
      if (u * u * 0.9 + (v < 0 ? v * v * 1.2 : v * v * 0.5) > edge) continue;
      const band = Math.floor((y - cy + 40) / 3);
      let c = u < 0 ? hex('#4a4a8a') : hex('#34306a');
      if (band % 3 === 0) c = mix(c, hex('#22204a'), 0.45);
      if (y > cy + ry * 0.55) c = mix(c, hex('#1a1840'), 0.55);
      if (v < -0.55) c = u < 0.1 ? TEXT : MUTED; // snow cap
      cv.px(x, y, c);
    }
  }

  // crag at the foot of the far mountain
  for (let k = 0; k < 2; k++) {
    const cx = 94 + k * 12, ph = 44 - k * 16, pw = 14 - k * 4;
    for (let y = GROUND - ph; y < GROUND; y++) {
      const f = (y - (GROUND - ph)) / ph, hw = pw * (0.2 + 0.8 * f) + ((hash(y, k, 3) % 3) - 1) * 0.8;
      for (let x = Math.round(cx - hw); x <= Math.round(cx + hw); x++) {
        const u = (x - cx) / hw, s = Math.floor((y + x * 0.4) / 6);
        let c = u < -0.05 ? hex('#33305f') : hex('#201d46');
        if (s % 4 === 0) c = mix(c, hex('#12112c'), 0.5);
        if ((y + Math.floor(x * 0.4)) % 6 === 0 && s % 2 === 1) c = mix(c, hex('#4a4a8a'), 0.5);
        if (f < 0.14) c = u < 0 ? MUTED : hex('#a99bdc');
        if (f < 0.05) c = TEXT;
        cv.px(x, y, c);
      }
    }
  }
  // far pines on the far mountain's foot
  pine(28, 226, 64, 28, palFar, true);
  pine(8, 226, 50, 22, palFar, true);
  pine(78, 226, 42, 18, palFar, false);

  // ---- near snow slope: edge at full 2x resolution, ridges parallel to the edge ----
  const edgeY = (x) => x <= 324 ? 306 - 0.75 * x : 63.5 + 0.55 * (x - 324);
  for (let x = 100; x < W; x++) {
    const e = edgeY(x);
    for (let y = Math.ceil(e); y < GROUND; y++) {
      const v = y - e; // vertical distance under the edge
      let c;
      if (v < 2) c = TEXT;
      else if (v < 6) c = TEXT;
      else if (v < 10) c = hex('#e9e0f9');
      else if (v < 14) c = hex('#dccff2');
      else {
        // drifts: bands that follow the edge, wavy, with a lit lip, body gradient and shadow line
        const per = 24, vv = v - 14 + Math.sin(x * 0.07 + 1.3) * 3 + Math.sin(x * 0.19) * 1.3;
        const b = Math.floor(vv / per), lp = ((vv % per) + per) % per;
        const deepen = Math.min(1, Math.max(0, (y - 120) / 108));      // colder toward the ground
        const baseCol = mix(MUTED, hex('#a79ad8'), deepen * 0.8);
        const shadowCol = mix(hex('#a79ad8'), hex('#7f72c0'), deepen);
        c = baseCol;
        if (lp < 1) c = hex('#e6ddf8');                                   // lit lip
        else if (lp < 2) c = hex('#dccff2');
        else if (lp > per - 7) {                                          // shadow under the lip of the next drift, dithered
          const t = (lp - (per - 7)) / 7;
          c = mix(baseCol, shadowCol, dstep(x, y, t * 2) / 2);
        }
        if (lp > per - 2) c = shadowCol;
        // some drifts end in short pieces so it does not look like ruler lines
        if (hash(Math.floor(x / 26), b, 8) % 4 === 0 && lp < 3) c = baseCol;
      }
      cv.px(x, y, c);
    }
  }
  // sparkles on the lit rim (ice blue, 2 px)
  for (const x of [150, 188, 226, 262, 300]) { const y = Math.round(edgeY(x)) + 3; cv.px(x, y, hex('#a4e1ff')); cv.px(x + 1, y, hex('#a4e1ff')); }
  // rocks poking out of the snow
  // near pines standing on the ground
  pine(232, 227, 62, 30, palNear, true);
  pine(262, 227, 76, 34, palNear, true);
  pine(298, 227, 56, 26, palNear, true);
  pine(328, 227, 70, 32, palNear, true);
  pine(346, 227, 48, 22, palNear, false);

  // ---- snow ground line (scalloped drift along the ground, hidden partly by the floor) ----
  for (let x = 0; x < W; x++) {
    const h = 3 + Math.round(1.6 * Math.sin(x * 0.13) + 1.2 * Math.sin(x * 0.37 + 2));
    for (let j = 0; j < h; j++) { const y = GROUND - 1 - j; const c = j === h - 1 ? TEXT : j > h - 3 ? hex('#dccff2') : MUTED; if (x < 110 || cv.get(x, y)[0] < 150) cv.px(x, y, c); }
  }

  // ---- flag and pole: copy the clean 1x original (pole, flag) ----
  for (let y = 10; y < 36; y++) for (let x = 156; x < 175; x++) {
    const c = o1(src, x, y);
    if (same(c, PINK) || same(c, INK)) cv.rect(x * 2, y * 2, 2, 2, c);
  }
  // flag shading: darker lower edge, light top edge
  for (let x = 328; x < 350; x++) { if (same(cv.get(x, 29), PINK) && !same(cv.get(x, 28), PINK)) cv.px(x, 29, PINK_HI); }
  return cv;
}

function frostbiteFloor() {
  const cv = new Canvas(W, FH);
  const lipBottom = (x) => 8 + Math.round(2.2 * Math.sin(x * 0.11) + 1.6 * Math.sin(x * 0.31 + 1));
  const iceTop = hex('#c9b8e8'), iceMid = hex('#b3a5e0'), iceLow = hex('#9a92d6'), iceDeep = hex('#8590cf');
  for (let y = 0; y < FH; y++) for (let x = 0; x < W; x++) {
    let c;
    const lb = lipBottom(x);
    if (y < 2) c = INK;
    else if (y <= lb) c = (y >= lb - 1) ? ((y === lb) ? hex('#a79ad8') : MUTED) : (y < 4 ? TEXT : hex('#ece4fa'));
    else {
      const v = (y - lb) / (FH - lb) * 3.2;
      const s = Math.min(3, dstep(x, y, Math.min(v, 3)));
      c = [iceTop, iceMid, iceLow, iceDeep][s];
      if (y === lb + 1) c = hex('#a79ad8'); // shadow under the snow lip
    }
    cv.px(x, y, c);
  }
  // horizontal sheen streaks on the ice (fixed positions)
  for (const [x0, y0, len] of [[10, 22, 26], [60, 34, 34], [96, 52, 22], [238, 20, 30], [296, 36, 40], [250, 56, 26], [20, 62, 28], [330, 58, 16]]) {
    for (let i = 0; i < len; i++) cv.px(x0 + i, y0, mix(cv.get(x0 + i, y0), hex('#e2d8f6'), i > len - 5 || i < 3 ? 0.45 : 0.75));
    for (let i = 3; i < len - 3; i += 2) cv.px(x0 + i, y0 + 1, mix(cv.get(x0 + i, y0 + 1), hex('#8f86cc'), 0.3));
  }
  // bright ice patch (the old oval), with dithered edge
  cv.ell(280, 34, 48, 9, (x, y, r) => {
    const s = dstep(x, y, Math.min((1 - r) * 4, 2));
    if (s === 0) return;
    cv.px(x, y, s === 1 ? mix(cv.get(x, y), TEXT, 0.55) : mix(cv.get(x, y), TEXT, 0.9));
  });
  // cracks: jagged dark lines with a pale edge, branching (kept clear of the object area x 144-212)
  const crack = (pts, branch) => {
    for (let i = 0; i < pts.length - 1; i++) {
      cv.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], hex('#6a60b0'));
      cv.line(pts[i][0] + 1, pts[i][1], pts[i + 1][0] + 1, pts[i + 1][1], mix(cv.get(pts[i][0] + 1, pts[i][1]), TEXT, 0.4));
    }
    if (branch) crack(branch, null);
  };
  crack([[232, 14], [236, 20], [233, 26], [240, 33], [244, 40], [241, 47], [248, 54], [250, 62], [247, 70]], [[240, 33], [247, 31], [252, 36], [258, 35]]);
  crack([[322, 10], [326, 18], [324, 24], [330, 32], [334, 38]], [[326, 18], [332, 20], [338, 18]]);
  crack([[128, 30], [132, 36], [130, 42], [136, 50], [139, 58]], [[132, 36], [138, 38], [141, 44]]);
  crack([[6, 40], [10, 46], [8, 52], [14, 58]], null);
  crack([[270, 52], [276, 56], [282, 54], [290, 60], [296, 59]], null);
  // frost glints (small crosses) and ice chips
  for (const [gx, gy] of [[120, 24], [330, 50], [268, 24], [212, 30], [58, 28]]) {
    cv.px(gx, gy, TEXT); cv.px(gx - 1, gy, hex('#e6ddf8')); cv.px(gx + 1, gy, hex('#e6ddf8')); cv.px(gx, gy - 1, hex('#e6ddf8')); cv.px(gx, gy + 1, hex('#e6ddf8'));
    cv.px(gx - 2, gy, hex('#a4e1ff')); cv.px(gx + 2, gy, hex('#a4e1ff'));
  }
  for (const [x0, y0] of [[238, 50], [250, 52], [262, 49], [274, 52]]) { cv.rect(x0, y0, 3, 2, hex('#8672a5')); cv.px(x0, y0 - 1, TEXT); }
  // snow dusting along the bottom edge
  return cv;
}

// ---------- write ----------
const out = (area, name, cv) => save(cv, `assets/areas/${area}/${name}.png`);
out('arcade', 'background', arcadeBackground());
out('arcade', 'floor', arcadeFloor());
out('frostbite', 'background', frostbiteBackground());
out('frostbite', 'floor', frostbiteFloor());
console.log('wrote 4 files');
