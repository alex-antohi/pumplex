// Shared pose code for animate.mjs (6-body style test) and animate_all.mjs
// (all 50 atlas bodies).
//
// The poses are made by editing the source pixels (cutting repeated rows,
// bending legs, redrawing arms), so every frame keeps the source's outline,
// three skin tones and outfit colours.

import fs from 'node:fs';
import path from 'node:path';
import { png, decode } from './png.mjs';

export const FW = 80, FH = 72;   // frame size
export const OX = 14, OY = 8;    // where the 52x64 body sits in the frame

// ---------- PNG I/O ----------
export function readPng(file) {
  const { w, h, data } = decode(fs.readFileSync(file));
  return { w, h, px: new Uint8Array(data) };
}
export function writePng(file, img) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, png(img.w, img.h, (x, y) => { const o = (y * img.w + x) * 4; return [img.px[o], img.px[o + 1], img.px[o + 2], img.px[o + 3]]; }));
}

// ---------- pixel helpers ----------
export const blank = (w, h) => ({ w, h, px: new Uint8Array(w * h * 4) });
const clone = (img) => ({ w: img.w, h: img.h, px: img.px.slice() });
export const get = (img, x, y) => (x < 0 || y < 0 || x >= img.w || y >= img.h) ? 0 : img.px[(y * img.w + x) * 4 + 3] ? ((img.px[(y * img.w + x) * 4] << 16) | (img.px[(y * img.w + x) * 4 + 1] << 8) | img.px[(y * img.w + x) * 4 + 2]) | 0x1000000 : 0;
export function set(img, x, y, c) {
  if (x < 0 || y < 0 || x >= img.w || y >= img.h) return;
  const o = (y * img.w + x) * 4;
  if (!c) { img.px[o] = img.px[o + 1] = img.px[o + 2] = img.px[o + 3] = 0; return; }
  img.px[o] = (c >> 16) & 255; img.px[o + 1] = (c >> 8) & 255; img.px[o + 2] = c & 255; img.px[o + 3] = 255;
}
export const hex = (s) => parseInt(s.replace('#', ''), 16) | 0x1000000;
const rowEq = (img, a, b) => { for (let x = 0; x < img.w; x++) if (get(img, x, a) !== get(img, x, b)) return false; return true; };
export const rect = (img, x0, y0, w, h, c) => { for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) set(img, x, y, c); };

const INK = hex('#0b0414');
const BAR = { hi: hex('#c9b8e8'), base: hex('#8672a5'), sh: hex('#4b2a7a') };
const PLATE = { hi: hex('#724eb2'), base: hex('#2a1148'), sh: hex('#1f0d36'), rim: hex('#a77bff') };

// ---------- reading a body ----------
// Finds what the poses need: the shoulder row, each arm as a pixel mask
// (flood-filled skin plus the ink that only borders that skin), the torso
// edge next to each arm, the legs, and the skin tones.
function analyse(img) {
  const span = (y) => { let l = -1, r = -1; if (y < 0 || y >= img.h) return [l, r]; for (let x = 0; x < img.w; x++) if (get(img, x, y)) { if (l < 0) l = x; r = x; } return [l, r]; };
  let top = 0; while (top < img.h && span(top)[0] < 0) top++;
  let feet = img.h - 1; while (feet > 0 && span(feet)[0] < 0) feet--;
  const headW = span(top + 5)[1] - span(top + 5)[0];
  let S = top + 8; while (S < feet && span(S)[1] - span(S)[0] < headW + 5) S++;   // shoulder outline row
  const armTones = (side, y0) => { const [l, r] = span(y0), dir = side === 'L' ? 1 : -1; let x = side === 'L' ? l : r; while (get(img, x, y0) === INK) x += dir; const t = []; while (get(img, x, y0) && get(img, x, y0) !== INK) { t.push(get(img, x, y0)); x += dir; } return t; };
  const allSkin = new Set(); for (let y = S + 2; y < S + 14; y++) for (const sd of ['L', 'R']) armTones(sd, y).forEach((c) => allSkin.add(c));
  // the shorts' hem: arms never reach below it, legs never above it
  const cx = img.w >> 1; let hem = S + 6; while (hem < feet && !allSkin.has(get(img, cx - 4, hem + 1))) hem++;
  // hands are shaded on their own: add every tone found on the arm's outer run down to the hem
  for (let y = S + 2; y <= hem; y++) for (const sd of ['L', 'R']) { const t = armTones(sd, y); if (t.length && t.length <= 12 && t.some((c) => allSkin.has(c))) t.forEach((c) => allSkin.add(c)); }
  const arms = {};
  for (const side of ['L', 'R']) {
    const y0 = S + 4, [l, r] = span(y0), dir = side === 'L' ? 1 : -1;
    let x = side === 'L' ? l : r; while (get(img, x, y0) === INK) x += dir;
    const tones = []; let xs = x; while (get(img, xs, y0) && get(img, xs, y0) !== INK) { tones.push(get(img, xs, y0)); xs += dir; }
    const mask = new Set(), stack = [[x, y0]];
    while (stack.length) {
      const [px, py] = stack.pop(), k = py * img.w + px;
      if (mask.has(k) || py < S || py > hem || !allSkin.has(get(img, px, py))) continue;
      mask.add(k); stack.push([px + 1, py], [px - 1, py], [px, py + 1], [px, py - 1]);
    }
    // ink that touches the arm and nothing else opaque belongs to the arm
    const ink = new Set();
    for (const k of mask) {
      const mx = k % img.w, my = (k / img.w) | 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]]) {
        const nx = mx + dx, ny = my + dy, nk = ny * img.w + nx;
        if (get(img, nx, ny) !== INK || ink.has(nk)) continue;
        const own = [[1, 0], [-1, 0], [0, 1], [0, -1]].every(([ex, ey]) => { const c = get(img, nx + ex, ny + ey); return !c || c === INK || mask.has((ny + ey) * img.w + nx + ex); });
        if (own) ink.add(nk);
      }
    }
    let bottom = 0; for (const k of mask) bottom = Math.max(bottom, (k / img.w) | 0);
    const edge = xs;                                                            // torso outline column at y0
    arms[side] = { mask, ink, bottom, edge, width: tones.length + 2, skin: { hi: tones[0], base: tones[Math.min(1, tones.length - 1)], sh: tones[tones.length - 1] } };
  }
  const skin = arms.L.skin, armBottom = Math.max(arms.L.bottom, arms.R.bottom);
  const isSkin = (c) => c === skin.hi || c === skin.base || c === skin.sh;
  let legTop = armBottom + 1;
  while (legTop < feet && ![...Array(img.w).keys()].some((x) => isSkin(get(img, x, legTop)) && !arms.L.mask.has(legTop * img.w + x) && !arms.R.mask.has(legTop * img.w + x))) legTop++;
  let legBottom = feet; while (legBottom > legTop && ![...Array(img.w).keys()].some((x) => isSkin(get(img, x, legBottom)))) legBottom--;
  return { S, hem, top, feet, arms, skin, allSkin, armBottom, legTop, legBottom };
}

// ---------- pose edits ----------
function removeArms(img, a) {
  const out = clone(img);
  for (const side of ['L', 'R']) for (const k of [...a.arms[side].mask, ...a.arms[side].ink]) set(out, k % img.w, (k / img.w) | 0, 0);
  // whatever is left outside the torso's own outline on each row (wrists, odd shades)
  const cloth = (c) => c && c !== INK && !a.allSkin.has(c);
  for (let y = a.S + 1; y <= a.hem; y++) {
    let l = 0; while (l < img.w && !cloth(get(out, l, y))) l++;
    let r = img.w - 1; while (r >= 0 && !cloth(get(out, r, y))) r--;
    if (l >= r) continue;
    for (let x = 0; x < l - 1; x++) set(out, x, y, 0);
    for (let x = r + 2; x < img.w; x++) set(out, x, y, 0);
    set(out, l - 1, y, INK); set(out, r + 1, y, INK);
  }
  return out;
}

// Cuts `rows` rows from the upper body (copies of a neighbouring row), moving
// everything above them down: the body sinks, the feet stay put.
function sinkUpper(img, a, rows) {
  let out = img;
  for (let n = 0; n < rows; n++) {
    let cut = -1;
    for (let y = a.armBottom - 2; y > a.S + 2; y--) if (rowEq(out, y, y - 1)) { cut = y; break; }
    if (cut < 0) break;
    const next = blank(out.w, out.h);
    for (let y = 0; y < out.h; y++) for (let x = 0; x < out.w; x++) {
      const sy = y <= cut ? y - 1 : y; if (sy >= 0) set(next, x, y, get(out, x, sy));
    }
    out = next;
  }
  return out;
}

// Squat: cuts leg rows (feet planted) and bows the knees out.
function squat(img, a, depth, spread) {
  let out = img, cuts = 0;
  for (let n = 0; n < depth; n++) {
    let cut = -1;
    for (let y = a.legBottom - 1; y > a.legTop + 1; y--) if (rowEq(out, y, y - 1)) { cut = y; break; }
    if (cut < 0) break;
    const next = blank(out.w, out.h);
    for (let y = 0; y < out.h; y++) for (let x = 0; x < out.w; x++) { const sy = y <= cut ? y - 1 : y; if (sy >= 0) set(next, x, y, get(out, x, sy)); }
    out = next; cuts++;
  }
  const lt = a.legTop + cuts, lb = a.legBottom, cx = img.w / 2, bent = blank(out.w, out.h);
  for (let y = 0; y < out.h; y++) {
    const t = (y - lt) / (lb - lt), dx = y >= lt && y <= lb ? Math.round(spread * Math.sin(Math.PI * t)) : 0;
    for (let x = 0; x < out.w; x++) { const c = get(out, x, y); if (!c) continue; set(bent, x < cx ? x - dx : x + dx, y, c); }
  }
  // bowing pulls each leg's top corner away from the shorts' hem: close the gap with ink
  for (let y = lt; y <= lb; y++) for (const side of [-1, 1]) {
    const yAbove = y - 1; let edge = -1;
    for (let x = side < 0 ? 0 : out.w - 1; side < 0 ? x < cx : x >= cx; x -= side) if (get(bent, x, y)) { edge = x; break; }
    let above = -1; for (let x = side < 0 ? 0 : out.w - 1; side < 0 ? x < cx : x >= cx; x -= side) if (get(bent, x, yAbove)) { above = x; break; }
    if (edge < 0 || above < 0) continue;
    if (side < 0) for (let x = edge; x < above; x++) if (get(bent, x, yAbove) === 0) set(bent, x, yAbove, INK);
    if (side > 0) for (let x = above + 1; x <= edge; x++) if (get(bent, x, yAbove) === 0) set(bent, x, yAbove, INK);
  }
  return { img: bent, sunk: cuts };
}

// A limb block: ink outline, then highlight / base / shadow bands lit from the top-left.
function limb(img, x0, y0, w, h, skin, vertical) {
  rect(img, x0, y0, w, h, INK);
  for (let y = y0 + 1; y < y0 + h - 1; y++) for (let x = x0 + 1; x < x0 + w - 1; x++) {
    const t = vertical ? (x - x0 - 1) / Math.max(1, w - 3) : (y - y0 - 1) / Math.max(1, h - 3);
    set(img, x, y, t < 0.25 ? skin.hi : t > 0.75 ? skin.sh : skin.base);
  }
}

function frontSquatArms(img, a, sink) {
  const S = a.S + sink, w = Math.max(5, a.arms.L.width), out = img;
  const by = S - 2;                                          // bar sits on the front of the shoulders
  // bar: full frame width behind nothing, in front of the neck
  for (let x = 0; x < out.w; x++) { set(out, x, by, INK); set(out, x, by + 1, BAR.hi); set(out, x, by + 2, BAR.base); set(out, x, by + 3, INK); }
  // elbows forward: forearm foreshortened under each fist
  const lx = a.arms.L.edge - w + 1, rx = a.arms.R.edge;
  for (const x of [lx, rx]) { limb(out, x, by + 3, w, 8, a.skin, true); limb(out, x, by - 2, w, 6, a.skin, true); }
  return out;
}

function plates(frame, by) {
  for (const x0 of [1, FW - 8]) {
    rect(frame, x0, by - 10, 7, 24, INK);
    rect(frame, x0 + 1, by - 9, 5, 22, PLATE.base);
    rect(frame, x0 + 1, by - 9, 1, 22, PLATE.hi);
    rect(frame, x0 + 5, by - 9, 1, 22, PLATE.sh);
    rect(frame, x0 + 1, by - 9, 5, 1, PLATE.rim);
    rect(frame, x0 + 2, by + 1, 3, 2, BAR.sh);
  }
}

function flexArms(img, a, sink) {
  const out = img, S = a.S + sink, w = Math.max(5, a.arms.L.width), upper = 11, fore = 12;
  const bump = w >= 8 ? 3 : 2;
  for (const side of ['L', 'R']) {
    const edge = a.arms[side].edge;
    const ux = side === 'L' ? edge - upper : edge + 1;
    limb(out, ux, S + 1, upper, w, a.skin, false);                         // upper arm out to the side
    // biceps: a bump on the top edge
    const fx = side === 'L' ? ux : ux + upper - w;
    const fy = S + 1 - fore + w;
    limb(out, fx, fy, w, fore, a.skin, true);                              // forearm straight up
    // biceps peak: a rounded bump on top of the upper arm, beside the forearm
    const bw = 6, bx = side === 'L' ? fx + w - 1 : fx - bw + 1;
    rect(out, bx + 1, S + 1 - bump, bw - 2, 1, INK);
    rect(out, bx, S + 2 - bump, bw, bump, INK);
    rect(out, bx + 1, S + 2 - bump, bw - 2, bump, a.skin.hi);
    rect(out, bx + 1, S + 1 + bump, bw - 2, 1, a.skin.base);
    for (let y = S + 2 - bump; y <= S + 1; y++) set(out, side === 'L' ? fx + w - 1 : fx, y, INK);   // keep the forearm's edge
    // fist: same width as the forearm, a knuckle line across
    rect(out, fx, fy - 4, w, 5, INK);
    rect(out, fx + 1, fy - 3, w - 2, 3, a.skin.base);
    rect(out, fx + 1, fy - 3, w - 2, 1, a.skin.hi);
    rect(out, fx + 2, fy - 1, w - 4, 1, a.skin.sh);
  }
  return out;
}

// Arms and bars may reach past the 52 px body: copy the body onto a
// frame-sized canvas first, then pose it there.
function widen(img) { const out = blank(FW, FH); for (let y = 0; y < img.h; y++) for (let x = 0; x < img.w; x++) { const c = get(img, x, y); if (c) set(out, x + OX, y + OY, c); } return out; }
function lift(frame, dy) { const out = blank(frame.w, frame.h); for (let y = 0; y < frame.h; y++) for (let x = 0; x < frame.w; x++) { const c = get(frame, x, y); if (c && y - dy >= 0) set(out, x, y - dy, c); } return out; }

export function poses(src) {
  const wide = widen(src), a = analyse(wide), noArms = removeArms(wide, a);
  const p = {};
  p.rest = clone(wide);
  p.out = sinkUpper(wide, a, 1);
  const sq = (depth, spread) => { const s = squat(noArms, a, depth, spread); const img = frontSquatArms(s.img, a, s.sunk); plates(img, a.S + s.sunk - 2); return img; };
  p.top = sq(0, 0); p.d1 = sq(2, 1); p.d2 = sq(3, 2); p.d3 = sq(5, 2); p.bottom = sq(6, 3);
  const flex = (dy, depth = 0) => { const s = squat(noArms, a, depth, depth ? 1 : 0); return lift(flexArms(s.img, a, s.sunk), dy); };
  const dip = squat(wide, a, 3, 1).img;
  p.dip = dip; p.air2 = flex(2); p.air4 = flex(4); p.land = flex(0, 2); p.hold = flex(0);
  return p;
}
