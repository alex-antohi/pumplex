/* HD (2x) character art: body atlas, looks (skin/hair variants, beards) and class outfits.
 *
 *   node tools/art_hd/characters.mjs
 *
 * Source: docs/moodboard/creator/body_atlas.png (1x, 260x640). Steps:
 *  1. label every pixel (skin/shirt/shorts/feet/hair as ramp + shade, ink, eye, other)
 *  2. scale2x (EPX) the label grid: smooth diagonals, still hard pixels
 *  3. detail at 2x: 1-px outline, rim light/shadow, muscle lines by muscle row, belly by fat column,
 *     face (eyes, brows, nose, mouth), hair strands, fabric folds
 *  4. draw the body in each skin/hair ramp; beards and outfits come from the same 2x grid, so layers match.
 * Output: assets/body/body_atlas.png, assets/body/looks/*.png, assets/outfits/*.png (520x1280).
 * No npm packages. Fat column = cx (0..4), muscle = cy % 5, rows 5..9 are female.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = path.join(ROOT, 'docs/moodboard/creator/body_atlas.png');
const W1 = 52, H1 = 64, COLS = 5, ROWS = 10, W = 104, H = 128, AW = W * COLS, AH = H * ROWS;

const hx = (h) => parseInt(h.slice(1), 16);
const mix = (a, b, t) => { const c = [16, 8, 0].map((s) => Math.round(((a >> s) & 255) * (1 - t) + ((b >> s) & 255) * t)); return (c[0] << 16) | (c[1] << 8) | c[2]; };
/* 5 tones: 0 spec, 1 highlight, 2 base, 3 shadow, 4 deep. Source shades 0,1,2 are tones 1,2,3. */
const ramp5 = ([a, b, c]) => [mix(hx(a), 0xffffff, 0.35), hx(a), hx(b), hx(c), mix(hx(c), hx('#0b0414'), 0.45)];
const SKINS = {
  light: [hx('#f6dcc0'), hx('#e4bc97'), hx('#d39a6a'), hx('#8c605c'), hx('#5e3548')],
  deep: [hx('#cf9970'), hx('#b07a52'), hx('#8a5534'), hx('#5a3322'), hx('#3a1f2c')],
};
const HAIRS = {
  brown: [hx('#b39682'), hx('#997d6b'), hx('#5a3424'), hx('#462533'), hx('#2f1626')],
  blonde: [hx('#fff0b0'), hx('#f6d77c'), hx('#d9a93e'), hx('#9c6a2a'), hx('#64401e')],
};
const SHIRT = ramp5(['#decfe5', '#c9b8e8', '#8672a5']), SHORTS = ramp5(['#ad8ed6', '#7b4fd0', '#593597']), FEET = ramp5(['#857788', '#3a2a52', '#33204e']);
const INK = hx('#0b0414'), EYE = hx('#281424'), EYEWHITE = hx('#f2eaf6'), MOUTH = hx('#8a3a52');
const ORIG = { e4bc97: [3, 0], d39a6a: [3, 1], '8c605c': [3, 2], decfe5: [4, 0], c9b8e8: [4, 1], '8672a5': [4, 2], ad8ed6: [5, 0], '7b4fd0': [5, 1], '593597': [5, 2],
  '857788': [6, 0], '3a2a52': [6, 1], '33204e': [6, 2], '997d6b': [7, 0], '5a3424': [7, 1], '462533': [7, 2], '0b0414': [1, 0], '281424': [2, 0] };
const S = 3, T = 4, B = 5, F = 6, HR = 7, X = 8, FIX = 9; // class codes

/* ---------- 1. label the 1x atlas ---------- */
const src = decode(fs.readFileSync(SRC));
if (src.w !== 260 || src.h !== 640) throw new Error('source size');
const n1 = src.w * src.h, c1 = new Uint8Array(n1), s1 = new Uint8Array(n1), r1 = new Uint32Array(n1);
for (let i = 0; i < n1; i++) {
  const d = src.data, o = i * 4; if (!d[o + 3]) continue;
  const rgb = (d[o] << 16) | (d[o + 1] << 8) | d[o + 2], m = ORIG[rgb.toString(16).padStart(6, '0')];
  if (m) { c1[i] = m[0]; s1[i] = m[0] >= S ? m[1] + 1 : 0; } else { c1[i] = X; r1[i] = rgb; }
}

/* ---------- 2. scale2x (EPX) ---------- */
const cls = new Uint8Array(AW * AH), sh = new Uint8Array(AW * AH), col = new Uint32Array(AW * AH);
{
  const key = (x, y) => { if (x < 0 || y < 0 || x >= src.w || y >= src.h) return 0; const i = y * src.w + x; return c1[i] ? (c1[i] << 24) | (s1[i] << 20) | (c1[i] === X ? r1[i] : 0) + 0 : 0; };
  const K = (x, y) => { if (x < 0 || y < 0 || x >= src.w || y >= src.h) return -1; const i = y * src.w + x; return c1[i] ? c1[i] * 1e9 + s1[i] * 1e8 + r1[i] : -1; };
  const put = (x2, y2, x, y) => { const i = y * src.w + x, o = y2 * AW + x2; cls[o] = c1[i]; sh[o] = s1[i]; col[o] = r1[i]; };
  for (let y = 0; y < src.h; y++) for (let x = 0; x < src.w; x++) {
    const P = K(x, y), A = K(x, y - 1), Bk = K(x + 1, y), C = K(x - 1, y), D = K(x, y + 1);
    const q = [[x, y], [x, y], [x, y], [x, y]];
    if (C === A && C !== D && A !== Bk) q[0] = [x, y - 1];
    if (A === Bk && A !== C && Bk !== D) q[1] = [x + 1, y];
    if (D === C && D !== Bk && C !== A) q[2] = [x - 1, y];
    if (Bk === D && Bk !== A && D !== C) q[3] = [x, y + 1];
    for (let k = 0; k < 4; k++) put(x * 2 + (k & 1), y * 2 + (k >> 1), q[k][0], q[k][1]);
    void P; void key;
  }
}

/* ---------- 3. detail ---------- */
const clampSh = (v) => Math.max(0, Math.min(4, v));
const cells = [];
for (let cy = 0; cy < ROWS; cy++) for (let cx = 0; cx < COLS; cx++) {
  const ox = cx * W, oy = cy * H;
  const g = (x, y) => (x < 0 || y < 0 || x >= W || y >= H ? 0 : cls[(oy + y) * AW + ox + x]);
  const gs = (x, y) => sh[(oy + y) * AW + ox + x];
  const set = (x, y, c, s, rgb = 0) => { if (x < 0 || y < 0 || x >= W || y >= H) return; const o = (oy + y) * AW + ox + x; cls[o] = c; sh[o] = s; col[o] = rgb; };
  const shade = (x, y, d, only) => { if (g(x, y) && (!only || g(x, y) === only)) { const o = (oy + y) * AW + ox + x; sh[o] = clampSh(sh[o] + d); } };
  const rowRange = (y, c) => { let l = -1, r = -1; for (let x = 0; x < W; x++) if (g(x, y) === c) { if (l < 0) l = x; r = x; } return l < 0 ? null : [l, r]; };
  const m = (cy % 5) / 4, f = cx / 4, female = cy >= 5;
  const info = { cx, cy, ox, oy, g, set, shade, rowRange };

  /* geometry (2x) */
  let ey = -1; const exs = [];
  for (let y = 0; y < 40 && ey < 0; y++) for (let x = 0; x < W; x++) if (g(x, y) === 2) { ey = y; break; }
  for (let x = 0; x < W; x++) if (g(x, ey) === 2) exs.push(x);
  let ty0 = 999, ty1 = 0, by0 = 999, by1 = 0, fy0 = 999, headTop = 0;
  for (let y = 0; y < H; y++) { if (rowRange(y, T)) { ty0 = Math.min(ty0, y); ty1 = y; } if (rowRange(y, B)) { by0 = Math.min(by0, y); by1 = y; } if (rowRange(y, F)) fy0 = Math.min(fy0, y); }
  for (let y = 0; y < 40; y++) { let any = false; for (let x = 0; x < W; x++) if (g(x, y)) any = true; if (any) { headTop = y; break; } }
  const tr0 = rowRange(ty0, T), mid = Math.round((tr0[0] + tr0[1]) / 2), span = ty1 - ty0;
  Object.assign(info, { ey, exs, ty0, ty1, by0, by1, fy0, headTop, mid, span });
  const tr = (y) => rowRange(y, T);

  /* outline: keep the outer 1 px; inner ink rows become the deepest tone of the colour next to them */
  const inner = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (g(x, y) === 1) {
    if (!(g(x - 1, y) === 0 || g(x + 1, y) === 0 || g(x, y - 1) === 0 || g(x, y + 1) === 0)) inner.push([x, y]);
  }
  for (const [x, y] of inner) {
    let best = null;
    for (const [dx, dy] of [[0, 1], [1, 0], [-1, 0], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1], [0, 2], [2, 0], [-2, 0], [0, -2]]) { const c = g(x + dx, y + dy); if (c >= S && c <= HR) { best = [c, c === HR ? 4 : 4]; break; } if (c === X) { best = [FIX, 0, col[(oy + y + dy) * AW + ox + x + dx]]; break; } }
    if (best) set(x, y, best[0], best[1], best[2] || 0);
  }

  /* skin light and rim: top-left edge lighter, bottom-right edge darker */
  const rim = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (g(x, y) === S) {
    let d = 0; const e = (a, b) => { const c = g(a, b); return c !== S && c !== 2; };
    if (e(x - 1, y) || e(x, y - 1)) d = -1; if (e(x + 1, y) || e(x, y + 1)) d = 1;
    if (d && g(x, y) === S) rim.push([x, y, d]);
  }
  for (const [x, y, d] of rim) shade(x, y, d, S);
  /* shirt / shorts edges: same light */
  const rimC = [];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const c = g(x, y); if (c === T || c === B) { const e = (a, b) => g(a, b) !== c && g(a, b) !== 1; if (e(x + 1, y) || e(x, y + 1)) rimC.push([x, y, 1]); else if (e(x - 1, y) || e(x, y - 1)) rimC.push([x, y, -1]); } }
  for (const [x, y, d] of rimC) shade(x, y, d);

  /* torso: muscle lines (m) and softness (f). Only the tone moves, so the outfit shows it too. */
  const lines = [];
  const hw = (tr0[1] - tr0[0]) / 2;
  const hline = (y, x0, x1, d) => { for (let x = x0; x <= x1; x++) if (g(x, y) === T) lines.push([x, y, d]); };
  if (m > 0 && f <= 0.75) {
    const py = ty0 + Math.round(span * (female ? 0.3 : 0.26));
    const k = Math.round(hw * 0.2);
    hline(py, tr0[0] + 5 + k - k, mid - 2, 1); hline(py + 1, tr0[0] + 7, mid - 5, 1);
    hline(py, mid + 2, tr0[1] - 5, 1); hline(py + 1, mid + 5, tr0[1] - 7, 1);
    if (m >= 0.5) for (let y = py - 5; y <= py + 1; y++) { lines.push([mid, y, 1]); lines.push([mid - 1, y, 1]); }
    if (!female && m >= 0.5 && f <= 0.5) {
      for (let r = 0; r < (m >= 1 ? 3 : 2); r++) { const y = ty0 + Math.round(span * (0.44 + 0.13 * r)); hline(y, mid - 6, mid - 2, 1); hline(y, mid + 2, mid + 6, 1); lines.push([mid, y - 1, 1], [mid - 1, y - 1, 1], [mid, y, 1], [mid - 1, y, 1]); }
    }
    if (m >= 0.75) for (let k2 = 0; k2 < 4; k2++) { const y = ty0 + Math.round(span * 0.4) + k2 * 3; lines.push([tr(y)[0] + 3 + k2 % 2, y, 1], [tr(y)[1] - 3 - k2 % 2, y, 1]); }
    /* spec on the upper chest */
    lines.push([mid - 7, py - 3, -1], [mid + 7, py - 3, -1], [mid - 8, py - 3, -1], [mid + 6, py - 3, -1]);
  }
  if (f >= 0.25) {
    const by = ty0 + Math.round(span * 0.6);
    for (let y = by; y <= ty1; y++) { const r = tr(y); if (!r) continue; for (let x = r[0]; x <= r[1]; x++) if (x > r[1] - 3 - Math.round(f * 8)) lines.push([x, y, 1]); }
    const cy2 = ty0 + Math.round(span * 0.7);
    for (let x = tr(cy2)[0] + 4; x <= tr(cy2)[1] - 4; x++) lines.push([x, cy2 + (Math.abs(x - mid) < hw * 0.4 ? 1 : 0), 1], [x, cy2 + 1 + (Math.abs(x - mid) < hw * 0.4 ? 1 : 0), 1]);
    lines.push([mid, ty0 + Math.round(span * 0.55), 2], [mid - 1, ty0 + Math.round(span * 0.55), 2]);
    if (f >= 0.5) { const hy = ty0 + Math.round(span * 0.5); for (let x = mid - 8; x <= mid - 3; x++) lines.push([x, hy, -1]); }
    if (f >= 0.75) for (let y = ty0 + 8; y < ty1 - 2; y++) { const r = tr(y); lines.push([r[0] + 2, y, 1], [r[1] - 2, y, 1]); }
  }
  /* fabric folds: armpit creases and waist bunching */
  for (let k2 = 0; k2 < 6; k2++) { const y = ty0 + 8 + k2; lines.push([tr(y)[0] + 3 + k2, y, 1], [tr(y)[1] - 3 - k2, y, 1]); }
  for (let x = tr0[0] + 4; x <= tr0[1] - 4; x += 5) { const y = ty1 - 6 + ((x >> 1) % 2); lines.push([x, y, 1], [x + 1, y, 1], [x + 2, y + 1, 1]); }
  for (const [x, y, d] of lines) shade(x, y, d, T);

  /* shorts: centre seam, thigh crease */
  const bl = [];
  for (let y = by0 + 2; y <= by1; y++) { const r = rowRange(y, B); if (!r) continue; const c = Math.round((r[0] + r[1]) / 2); bl.push([c, y, 1], [c - 1, y, 1]); }
  for (let x = 0; x < W; x++) if (g(x, by0) === B) bl.push([x, by0, -1]);
  for (const [x, y, d] of bl) shade(x, y, d, B);

  /* arms and legs: skin runs below the shoulder line */
  const runs = (y, c = S) => { const out = []; let a = -1; for (let x = 0; x <= W; x++) { if (g(x, y) === c) { if (a < 0) a = x; } else if (a >= 0) { out.push([a, x - 1]); a = -1; } } return out; };
  const arm = [];
  for (let y = ty0 + 3; y <= ty0 + Math.round(span * 0.85); y++) {
    const r = tr(y); if (!r) continue;
    for (const [a, b] of runs(y)) {
      if (b < r[0] || a > r[1]) {
        const c = Math.round((a + b) / 2), t = (y - ty0) / span;
        if (m >= 0.25 && t > 0.2 && t < 0.38) arm.push([c, y, -1], [c - 1, y, -1]);
        if (m >= 0.5 && t >= 0.4 && t < 0.46) arm.push([c, y, 1], [c - 1, y, 1], [c + 1, y, 1]);
        if (m >= 0.75 && t > 0.5 && t < 0.62) arm.push([c, y, -1]);
        if (f >= 0.5 && t > 0.55) arm.push([a < r[0] ? a + 1 : b - 1, y, 1]);
        arm.push([a < r[0] ? b : a, y, 1]); // inner edge of the arm, in the torso's shade
      }
    }
  }
  for (const [x, y, d] of arm) shade(x, y, d, S);
  const leg = [];
  const lg0 = by1 + 1;
  let lg1 = lg0; for (let y = lg0; y < H; y++) if (rowRange(y, S)) lg1 = y;
  for (let y = lg0; y <= lg1; y++) for (const [a, b] of runs(y)) {
    const c = Math.round((a + b) / 2), t = (y - lg0) / Math.max(1, lg1 - lg0);
    if (m >= 0.5 && t < 0.5) leg.push([c, y, 1], [c - 1, y, 1]);
    if (m >= 0.25 && t >= 0.5 && t < 0.62) leg.push([c, y, -1]);
    if (t > 0.45 && t < 0.52 && b - a > 4) leg.push([c, y, 1], [c - 1, y, 1], [c + 1, y, 1]);
    if (m >= 0.75 && t >= 0.62 && t < 0.9) leg.push([a + 2, y, -1], [a + 3, y, -1]);
    if (b - a >= 3) leg.push([b - 1, y, 1]);
  }
  for (const [x, y, d] of leg) shade(x, y, d, S);
  /* shoes: toe cap highlight, lace line */
  for (let x = 0; x < W; x++) { if (g(x, fy0) === F) shade(x, fy0, -1); if (g(x, fy0 + 3) === F && x % 3 === 0) shade(x, fy0 + 3, 1); }

  /* neck shadow under the chin, ears */
  for (let y = ty0 - 5; y < ty0; y++) for (let x = 0; x < W; x++) if (g(x, y) === S) shade(x, y, 1);

  /* hair strands: dark strands, lit top */
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (g(x, y) === HR) {
    const v = y - headTop; if (v > 36) continue;
    if ((x * 2 + y) % 6 === 0 && v > 1) shade(x, y, 1, HR); else if ((x + 2 * y) % 7 === 0 && v <= 6) shade(x, y, -1, HR);
    if (v <= 1) shade(x, y, -1, HR);
  }

  /* face: eyes, brows, nose, mouth */
  if (exs.length) {
    const groups = []; for (const x of exs) { const l = groups[groups.length - 1]; if (l && x - l[l.length - 1] <= 1) l.push(x); else groups.push([x]); }
    const fmid = Math.round((exs[0] + exs[exs.length - 1]) / 2);
    groups.forEach((gr, i) => {
      const x0 = gr[0], left = i === 0 && groups.length > 1;
      set(x0, ey, 2, 0); set(x0 + 1, ey, 2, 0);
      set(x0, ey + 1, left ? FIX : 2, 0, EYEWHITE); set(x0 + 1, ey + 1, left ? 2 : FIX, 0, EYEWHITE);
      if (!left && groups.length > 1) { set(x0, ey + 1, 2, 0); set(x0 + 1, ey + 1, FIX, 0, EYEWHITE); }
      if (left) { set(x0, ey + 1, FIX, 0, EYEWHITE); set(x0 + 1, ey + 1, 2, 0); }
      for (let x = x0 - 1; x <= x0 + 2; x++) if (g(x, ey - 2) === S) set(x, ey - 2, HR, 3);
      if (g(x0, ey - 3) === S && !female) set(x0, ey - 3, HR, 3);
      if (g(x0, ey + 2) === S) shade(x0, ey + 2, 1); if (g(x0 + 1, ey + 2) === S) shade(x0 + 1, ey + 2, 1);
    });
    if (g(fmid, ey + 4) === S) { set(fmid, ey + 4, S, 4); set(fmid, ey + 5, S, 4); }
    if (g(fmid - 1, ey + 3) === S) shade(fmid - 1, ey + 3, -1);
    if (g(fmid + 1, ey + 5) === S) shade(fmid + 1, ey + 5, 1);
    for (const x of [fmid - 2, fmid - 1, fmid, fmid + 1]) if (g(x, ey + 9) === S) set(x, ey + 9, FIX, 0, MOUTH);
    for (const x of [fmid - 1, fmid]) if (g(x, ey + 10) === S) shade(x, ey + 10, 1);
    for (const x of [fmid - 5, fmid + 4]) if (g(x, ey + 6) === S) shade(x, ey + 6, 1); // cheeks
    info.fmid = fmid;
  }
  cells.push(info);
}

/* ---------- 4. write ---------- */
const rgbOf = (c) => [(c >> 16) & 255, (c >> 8) & 255, c & 255];
function pixelColour(o, skin, hair) {
  const c = cls[o]; if (!c) return null;
  if (c === 1) return INK; if (c === 2) return EYE;
  if (c === X || c === FIX) return col[o];
  return [null, null, null, skin, SHIRT, SHORTS, FEET, hair][c][sh[o]];
}
const write = (dirs, name, fn) => {
  const buf = png(AW, AH, (x, y) => { const c = fn(y * AW + x, x, y); return c === null ? [0, 0, 0, 0] : [...rgbOf(c), 255]; });
  for (const d of dirs) { fs.mkdirSync(d, { recursive: true }); fs.writeFileSync(path.join(d, name), buf); }
};
const BODY = [path.join(ROOT, 'assets/body')], LOOKS = [path.join(ROOT, 'assets/body/looks')], OUTF = [path.join(ROOT, 'assets/outfits')];
write(BODY, 'body_atlas.png', (o) => pixelColour(o, SKINS.light, HAIRS.brown));
let nb = 0;
for (const [sid, skin] of Object.entries(SKINS)) for (const [hid, hair] of Object.entries(HAIRS)) {
  if (sid === 'light' && hid === 'brown') continue;
  write(LOOKS, `body_${sid}_${hid}.png`, (o) => pixelColour(o, skin, hair)); nb++;
}

/* beards: skin under the eyes becomes hair (2x rows ey+6 .. ey+13; sideburns only on the first 2 rows) */
const beardPx = [];
for (const c of cells) {
  if (!c.exs.length) continue;
  for (let y = c.ey + 6; y <= c.ey + 13; y++) {
    const xs = []; for (let x = 0; x < W; x++) if (c.g(x, y) === S) xs.push(x);
    xs.forEach((x, n) => {
      if (y <= c.ey + 7 && n >= 4 && n < xs.length - 4) return;
      if ((y === c.ey + 9 || y === c.ey + 10) && Math.abs(x - c.fmid + 0.5) < 2.5) return; // keep the mouth
      const o = (c.oy + y) * AW + c.ox + x; let s = sh[o];
      if ((x + y * 2) % 5 === 0) s = clampSh(s + 1); else if ((x * 2 + y) % 7 === 0) s = clampSh(s - 1);
      beardPx.push([o, s]);
    });
  }
}
for (const [hid, hair] of Object.entries(HAIRS)) {
  const map = new Map(beardPx);
  write(LOOKS, `beard_${hid}.png`, (o) => (map.has(o) ? hair[map.get(o)] : null));
}

/* outfits: colour ramp by the body's tone (so muscle, belly and folds show), plus trim */
const hr = (h) => hx(h);
const TAPE = ramp5(['#f3e6b0', '#e8d9a0', '#bfae78']), SILVER = ramp5(['#e6ecf2', '#b4bfcc', '#7a8799']), BROWN = ramp5(['#a8723a', '#7a4d24', '#4f3016']), GOLD = ramp5(['#fff0a0', '#ffd447', '#c28a14']);
const OUTFITS = {
  scrapper: { t: ramp5(['#ffc36b', '#ffa033', '#c4681a']), b: ramp5(['#7a5a3c', '#5a3d28', '#3e2a1c']), f: ramp5(['#6b5a4a', '#4a3b30', '#33271f']) },
  bruiser: { t: ramp5(['#8ae6ff', '#3fd2ff', '#1f8fb8']), b: ramp5(['#2f4f8a', '#243b6b', '#182a4e']), f: ramp5(['#ffffff', '#dfe9f5', '#9fb3cc']) },
  paladin: { t: ramp5(['#e4ffa0', '#c6ff3d', '#7fa81f']), b: ramp5(['#6b8a2a', '#4d6620', '#344716']), f: ramp5(['#b4bfcc', '#7a8799', '#4d5766']) },
  cablemancer: { t: ramp5(['#4a3380', '#2e1f55', '#1a1033']), b: ramp5(['#3a2870', '#241747', '#150c2b']), f: ramp5(['#4a3380', '#241747', '#150c2b']) },
};
const WHITE = hr('#ffffff'), VIOLET = hr('#a77bff'), VIOLET2 = hr('#724eb2'), GLOW = hr('#e4d4ff');
for (const [id, P] of Object.entries(OUTFITS)) {
  const out = new Map();
  for (const c of cells) {
    const { g, ox, oy, ty0, ty1, by0, by1, fy0, mid, span } = c;
    const tr = (y) => c.rowRange(y, T), br = (y) => c.rowRange(y, B);
    const hw = (tr(ty0)[1] - tr(ty0)[0]) / 2;
    const put = (x, y, v) => out.set((oy + y) * AW + ox + x, v);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const k = g(x, y), o = (oy + y) * AW + ox + x; if (k !== T && k !== B && k !== F && !(k === X && y >= 116)) continue;
      const s = sh[o]; let v;
      if (k === T) {
        const r = tr(y), dl = x - r[0], dr = r[1] - x, u = x - mid, vv = y - ty0, tt = vv / span;
        v = P.t[s];
        if (id === 'scrapper') {
          const dx = (tt * 2 - 1) * (hw - 3);
          if (tt > 0.08 && tt < 0.8) { const a = Math.min(Math.abs(u - dx), Math.abs(u + dx)); if (a <= 1.5) v = a < 0.9 ? TAPE[clampSh(s)] : TAPE[clampSh(s + 1)]; }
          if (y >= ty1 - 1) v = TAPE[clampSh(s)]; else if (y === ty1 - 2) v = TAPE[clampSh(s + 2)];
          if (dl === 2 && vv % 4 < 2) v = TAPE[3]; // stitched hem
        } else if (id === 'bruiser') {
          if ((dl >= 4 && dl <= 6) || (dr >= 4 && dr <= 6)) v = WHITE; else if (dl === 7 || dr === 7) v = hr('#9fb3cc');
          if ((vv <= 1 && Math.abs(u) <= 8) || (vv >= 2 && vv <= 3 && Math.abs(u) <= 5) || (vv === 4 && Math.abs(u) <= 2)) v = WHITE;
          if (vv === 5 && Math.abs(u) <= 3 && Math.abs(u) >= 1) v = hr('#1f8fb8');
        } else if (id === 'paladin') {
          if (dl >= 4 && dr >= 4 && vv >= 2 && y <= ty1 - 4) {
            v = SILVER[s];
            const q = (vv - 2) % 10;
            if (q === 0 || q === 1) v = SILVER[clampSh(s + 2)]; else if (q === 2) v = SILVER[clampSh(s - 1)];
            if (Math.abs(u) <= 1) v = SILVER[clampSh(s + 2)];
            if (q === 5 && (Math.abs(u) === 8 || Math.abs(u) === Math.max(12, Math.round(hw) - 8))) v = WHITE;
            if (q === 6 && (Math.abs(u) === 8 || Math.abs(u) === Math.max(12, Math.round(hw) - 8))) v = SILVER[4];
          } else if (vv <= 3 && dl >= 2) v = P.t[clampSh(s - 1)];
        } else {
          if (Math.abs(u) <= 1 || dl === 4 || dl === 5 || dr === 4 || dr === 5) v = dl <= 5 || dr <= 5 ? VIOLET2 : VIOLET;
          if (vv <= 1 && Math.abs(u) <= 6) v = GLOW;
          if (vv >= 12 && vv <= 16 && Math.abs(u) <= 4 && (Math.abs(u) === 4 || vv === 14 || vv === 12 || vv === 16) && Math.abs(u) > 1) v = GLOW;
        }
      } else if (k === B) {
        const r = br(y), dl = x - r[0], dr = r[1] - x, u = x - mid;
        v = P.b[s];
        if (id === 'scrapper' && y >= by1 - 1) v = TAPE[clampSh(s)];
        if (id === 'bruiser' && (dl === 2 || dl === 3 || dr === 2 || dr === 3)) v = WHITE;
        if (id === 'paladin' && y <= by0 + 3) v = Math.abs(u) <= 3 ? GOLD[y === by0 ? 1 : 2] : BROWN[clampSh(y === by0 ? 1 : y <= by0 + 1 ? 2 : 3)];
        if (id === 'cablemancer' && (dl === 2 || dl === 3 || dr === 2 || dr === 3)) v = dl <= 3 ? VIOLET2 : VIOLET2;
        if (id === 'cablemancer' && y === by0) v = VIOLET;
      } else if (k === F) {
        v = P.f[s];
        if (id === 'scrapper' && (y === fy0 + 4 || y === fy0 + 5)) v = TAPE[clampSh(s)];
        if (id === 'paladin' && y <= fy0 + 1) v = hr('#c6ff3d');
        if (id === 'cablemancer' && y === fy0 + 2) v = VIOLET2;
        if (id === 'bruiser' && y === fy0 + 3 && x % 3 === 0) v = hr('#3fd2ff');
      } else v = P.f[3];
      put(x, y, v);
    }
  }
  write(OUTF, `${id}.png`, (o) => (out.has(o) ? out.get(o) : null));
}
console.log(`body atlas + ${nb} looks + 2 beards + ${Object.keys(OUTFITS).length} outfits at 2x (${AW}x${AH})`);
