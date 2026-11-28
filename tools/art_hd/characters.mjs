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
const OUT = process.env.ART_OUT || ROOT;
const FACE_STYLE = process.env.FACE_STYLE || 'visor';
const MOUTH_STYLE = process.env.MOUTH_STYLE || 'line'; // visor only: none | line | grin | grille | jaw
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

/* ---------- sci-fi faces (FACE_STYLE=visor|cyborg|android|helmet|human) ----------
 * Each style gets the cell helpers, paints only skin pixels (hair and outline stay) with fixed neon colours (class FIX),
 * so every skin variant shares the lights and only the skin parts differ. Rows are relative to ey (the eye row).
 * The jaw rows ey+6..ey+13 stay skin (only the mouth is fixed colour) so the beard overlay works on every style. */
const SM = hx('#43182e'), NAVY = hx('#1a1033'), WH = hx('#ffffff');
const CY = [hx('#88dff3'), hx('#3fd2ff'), hx('#3681b2')], PK = [hx('#ff98c2'), hx('#ff5fb0'), hx('#a63e84')];
const LM = [hx('#dcfb7b'), hx('#c6ff3d'), hx('#849b42')], VI = [hx('#c8a9f3'), hx('#a77bff'), hx('#724eb2')];
const MT = ramp5(['#e6ecf2', '#b4bfcc', '#7a8799']);
const faceKit = (c) => {
  const { g, set, rowRange, ey, fmid } = c;
  const P = (x, y, rgb) => { if (g(x, y) === S || g(x, y) === FIX) set(x, y, FIX, 0, rgb); };
  const row = (y, fn) => { const r = rowRange(y, S); if (r) for (let x = r[0]; x <= r[1]; x++) fn(x, x - r[0], r[1] - x); };
  const span = (y, x0, x1, rgb) => { for (let x = x0; x <= x1; x++) P(x, y, rgb); };
  return { P, row, span, ey, fmid, cs: c.groups.map((gr) => gr[0] + 2) };
};
/* visor mouths (no lips). Jaw rows ey+9..ey+12 are skin; fixed-colour pixels there also clear the beard overlay. */
const MDK = hx('#2a0e1f');
const MOUTHS = {
  none(k) { chin(k); },
  line(k) { // wide flat calm line, darker end points
    const { P, span, ey, fmid } = k;
    span(ey + 9, fmid - 5, fmid + 4, SM); P(fmid - 5, ey + 9, MDK); P(fmid + 4, ey + 9, MDK);
    for (let x = fmid - 3; x <= fmid + 2; x++) k.shade(x, ey + 10, 1, S);
    chin(k);
  },
  grin(k) { // wide smirk rising on the viewer-right side, one cheek crease
    const { P, span, ey, fmid } = k;
    span(ey + 9, fmid - 5, fmid + 1, SM); span(ey + 8, fmid + 2, fmid + 4, SM); P(fmid - 5, ey + 9, MDK); P(fmid + 4, ey + 8, MDK);
    k.setSh(fmid + 6, ey + 7, 3); k.setSh(fmid + 6, ey + 8, 3);
    for (let x = fmid - 3; x <= fmid + 1; x++) k.shade(x, ey + 10, 1, S);
    chin(k);
  },
  grille(k) { // respirator plate: edge light, 3 vent slits, dark bottom
    const { P, row, ey, fmid } = k;
    for (let y = ey + 8; y <= ey + 12; y++) row(y, (x) => {
      if (x < fmid - 5 || x > fmid + 4) return;
      const end = x === fmid - 5 || x === fmid + 4;
      let c = MT[3];
      if (y === ey + 8) c = MT[1]; else if (y === ey + 9 || y === ey + 11) c = INK; else if (y === ey + 12) c = MT[4];
      if (end && y !== ey + 8) c = y === ey + 10 ? MT[4] : INK;
      P(x, y, c);
    });
    P(fmid - 4, ey + 8, MT[0]); P(fmid - 3, ey + 8, MT[0]);
  },
  jaw(k) { // metal chin band with one neon dot
    const { P, row, ey, fmid } = k;
    for (let y = ey + 11; y <= ey + 12; y++) row(y, (x, i, j) => { if (i >= 1 && j >= 1) P(x, y, y === ey + 11 ? MT[2] : MT[4]); });
    P(fmid, ey + 11, CY[1]); P(fmid + 1, ey + 11, CY[1]); 
  },
};
function chin(k) { // clean jaw: chin highlight, under-jaw shadow
  const { ey, fmid } = k;
  for (let x = fmid - 2; x <= fmid + 2; x++) k.shade(x, ey + 11, -1, S);
  k.row(ey + 12, (x, i, j) => { if (i >= 2 && j >= 2) k.shade(x, ey + 12, 1, S); });
}
const SCIFI = {
  visor(c) { // wraparound neon band across the eyes, skin below
    const { P, row, span, ey, fmid } = faceKit(c);
    for (let y = ey - 1; y <= ey + 3; y++) row(y, (x, i, j) => {
      const edge = i < 1 || j < 1, dy = y - ey;
      if (dy === -1 || dy === 3) return P(x, y, edge ? NAVY : NAVY);
      if (edge) return P(x, y, PK[dy === 1 ? 0 : 1]);
      P(x, y, dy === 0 ? CY[0] : dy === 1 ? CY[1] : CY[2]);
    });
    span(ey + 1, fmid - 9, fmid - 4, WH); span(ey + 1, fmid + 5, fmid + 6, WH); // glass shine
    span(ey + 2, fmid - 3, fmid + 3, CY[1]); // brighter middle
    c.setSh(fmid, ey + 5, 4); c.setSh(fmid, ey + 6, 4); c.setSh(fmid - 1, ey + 5, 1);
    const mouth = MOUTHS[MOUTH_STYLE]; if (!mouth) throw new Error('MOUTH_STYLE must be one of: ' + Object.keys(MOUTHS).join(', '));
    mouth({ P, row, span, ey, fmid, shade: c.shade, setSh: c.setSh });
  },
  cyborg(c) { // viewer-left calm human eye, viewer-right metal plate with a glowing LED eye
    const { P, row, span, ey, fmid, cs } = faceKit(c);
    c.humanEye(c.groups[0], 0);
    const top = ey - 4, bot = ey + 7, edge = c.rowRange(ey + 4, S);
    for (let y = top; y <= bot; y++) row(y, (x, i, j) => {
      if (x < fmid + 1) return;
      if (y >= ey + 5 && j < (y - (ey + 4))) return; // chamfered jaw corner
      if (x === fmid + 1) return P(x, y, NAVY); // seam
      let s = 2; if (x === fmid + 2) s = 1; if (j < 2) s = 3; if (j === 0) s = 4; if (y === top) s = 1; if (y === bot) s = 4;
      P(x, y, MT[s]);
    });
    row(bot + 1, (x, i, j) => { if (x >= fmid + 1 && j >= 3) P(x, bot + 1, NAVY); });
    const cx = cs[1];
    span(ey - 2, cx - 3, cx + 3, MT[0]); span(ey - 1, cx - 3, cx + 3, NAVY); span(ey + 3, cx - 3, cx + 3, NAVY);
    for (let y = ey; y <= ey + 2; y++) span(y, cx - 3, cx + 3, NAVY);
    span(ey, cx - 2, cx + 2, PK[1]); span(ey + 1, cx - 2, cx + 2, PK[0]); span(ey + 2, cx - 2, cx + 2, PK[1]);
    span(ey + 1, cx - 1, cx + 1, WH);
    P(fmid + 4, top + 1, MT[0]); P(fmid + 4, top + 2, MT[4]); P(fmid + 4, bot - 1, MT[0]); P(fmid + 4, bot, MT[4]);
    if (edge) { P(edge[1] - 2, ey + 4, LM[1]); P(edge[1] - 2, ey + 5, LM[2]); }
    c.setSh(fmid - 1, ey + 5, 4); c.setSh(fmid - 1, ey + 6, 4);
    span(ey + 9, fmid - 3, fmid + 1, SM);
  },
  android(c) { // smooth faceplate, two glowing slit eyes, mouth seam, panel lines
    const { P, span, ey, fmid, cs } = faceKit(c);
    cs.forEach((cx, gi) => {
      const d = gi === 0 ? 1 : -1;
      span(ey, cx - 2, cx + 2, NAVY); span(ey + 3, cx - 2, cx + 2, NAVY);
      span(ey + 1, cx - 3, cx + 3, NAVY); span(ey + 2, cx - 3, cx + 3, NAVY);
      span(ey + 1, cx - 2, cx + 2, CY[0]); span(ey + 2, cx - 2, cx + 2, CY[1]); span(ey + 1, cx - 1, cx, WH);
      for (const [dx, dy] of [[-4, 4], [-4, 5], [-3, 6], [-2, 7], [-1, 7]]) c.setSh(cx + dx * d, ey + dy, 4); // cheek panel line
      for (const [dx, dy] of [[-3, 5], [-2, 6], [-1, 6], [0, 7]]) c.shade(cx + dx * d, ey + dy, -1, S); // its light edge
    });
    for (let y = 12; y <= ey - 3; y++) c.setSh(fmid, y, 4);
    span(ey - 3, fmid - 1, fmid + 1, CY[1]); // status light
    c.setSh(fmid, ey + 5, 3); c.setSh(fmid, ey + 6, 3);
    span(ey + 9, fmid - 3, fmid + 2, NAVY); P(fmid - 4, ey + 8, NAVY); P(fmid + 3, ey + 8, NAVY);
  },
  helmet(c) { // open helmet: brow plate, cheek rails, ear pods, lime eye strip, mic boom
    const { P, row, span, ey, fmid, cs } = faceKit(c);
    for (let y = 12; y <= ey + 8; y++) row(y, (x, i, j) => {
      const pod = y >= ey - 1 && y <= ey + 4, w = pod ? 4 : 3;
      if (y === ey + 8) return (i < 3 || j < 3) && P(x, y, NAVY);
      if (i < w) { if (pod && i === 3) return P(x, y, VI[2]); return P(x, y, pod && i === 2 ? VI[1] : MT[Math.min(4, i + 1)]); }
      if (j < w) { if (pod && j === 3) return P(x, y, VI[2]); return P(x, y, pod && j === 2 ? VI[1] : MT[Math.min(4, 3 - j + 1)]); }
      if (y === 12) return P(x, y, MT[1]);
      if (y === 13) return P(x, y, MT[3]);
    });
    const r = c.rowRange(ey + 1, S); if (r) { span(ey + 1, r[0] + 1, r[0] + 2, PK[1]); span(ey + 1, r[1] - 2, r[1] - 1, PK[1]); }
    cs.forEach((cx) => {
      span(ey - 1, cx - 3, cx + 3, NAVY); span(ey + 3, cx - 3, cx + 3, NAVY);
      span(ey, cx - 3, cx + 3, LM[0]); span(ey + 1, cx - 3, cx + 3, LM[1]); span(ey + 2, cx - 3, cx + 3, LM[2]);
      span(ey, cx - 1, cx + 1, WH);
    });
    span(ey + 1, cs[0] + 4, cs[1] - 4, LM[1]);
    c.setSh(fmid, ey + 5, 4); c.setSh(fmid, ey + 6, 4);
    const l = c.rowRange(ey + 7, S); if (l) { span(ey + 7, l[0] + 3, fmid - 5, MT[2]); span(ey + 8, fmid - 5, fmid - 4, LM[1]); }
    span(ey + 9, fmid - 2, fmid + 1, SM); span(ey + 10, fmid - 1, fmid, SM);
  },
};

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

  /* torso: clean tone bands (lit left, shadow right, edges follow the chest curve), then muscle lines (m) and belly (f).
     Only the tone moves, so the outfit shows it too. */
  const setSh = (x, y, s) => { if (g(x, y)) sh[(oy + y) * AW + ox + x] = clampSh(s); };
  const sstep = (a, b, v) => { const q = Math.max(0, Math.min(1, (v - a) / (b - a))); return q * q * (3 - 2 * q); };
  const hw = (tr0[1] - tr0[0]) / 2;
  for (let y = ty0; y <= ty1; y++) {
    const r = tr(y); if (!r) continue;
    const w = r[1] - r[0] + 1, t = (y - ty0) / span, bulge = Math.sin(t * Math.PI) * 1.6;
    const litW = Math.round(w * 0.2 + bulge), shW = Math.round(w * (0.3 + f * 0.16 * sstep(0.4, 0.9, t)) - bulge * 0.5);
    for (let x = r[0]; x <= r[1]; x++) {
      if (g(x, y) !== T) continue;
      const i = x - r[0], j = r[1] - x; let s = 2;
      if (i < litW) s = 1; else if (j < shW) s = 3;
      if (j === 0) s = 4; else if (i === 0) s = 3;
      if (y <= ty0 + 1) s -= 1;
      if (y === ty1) s += 1;
      setSh(x, y, s);
    }
  }
  const lines = [];
  const tr1 = (y) => tr(y) || tr(ty1);
  const hline = (y, x0, x1, d) => { for (let x = x0; x <= x1; x++) if (g(x, y) === T) lines.push([x, y, d]); };
  if (m > 0 && f <= 0.75) {
    const py = ty0 + Math.round(span * (female ? 0.3 : 0.26));
    hline(py, tr0[0] + 5, mid - 2, 1); hline(py + 1, tr0[0] + 7, mid - 5, 1);
    hline(py, mid + 2, tr0[1] - 5, 1); hline(py + 1, mid + 5, tr0[1] - 7, 1);
    if (m >= 0.5) for (let y = py - 5; y <= py + 1; y++) { lines.push([mid, y, 1]); lines.push([mid - 1, y, 1]); }
    if (!female && m >= 0.5 && f <= 0.5) {
      for (let r = 0; r < (m >= 1 ? 3 : 2); r++) { const y = ty0 + Math.round(span * (0.44 + 0.13 * r)); hline(y, mid - 6, mid - 2, 1); hline(y, mid + 2, mid + 6, 1); lines.push([mid, y - 1, 1], [mid - 1, y - 1, 1], [mid, y, 1], [mid - 1, y, 1]); }
    }
  }
  if (f >= 0.25) {
    const cy2 = ty0 + Math.round(span * 0.7), depth = 1.5 + f * 3.5, r2 = tr(cy2);
    for (let x = r2[0] + 4; x <= r2[1] - 4; x++) { const u = (x - mid) / (hw - 4); lines.push([x, cy2 + Math.round(depth * (1 - u * u)), 1]); }
    lines.push([mid, ty0 + Math.round(span * 0.55), 2], [mid - 1, ty0 + Math.round(span * 0.55), 2]);
    if (f >= 0.5) { const hy = ty0 + Math.round(span * 0.5); for (let x = mid - 8; x <= mid - 3; x++) lines.push([x, hy, -1]); }
  }
  for (const [x, y, d] of lines) shade(x, y, d, T);
  void tr1;

  /* shorts: tone bands, waistband and a single centre seam */
  for (let y = by0; y <= by1; y++) {
    const r = rowRange(y, B); if (!r) continue;
    const w = r[1] - r[0] + 1;
    for (let x = r[0]; x <= r[1]; x++) {
      if (g(x, y) !== B) continue;
      const i = x - r[0], j = r[1] - x; let s = 2;
      if (i < Math.round(w * 0.22)) s = 1; else if (j < Math.round(w * 0.32)) s = 3;
      if (j === 0) s = 4; else if (i === 0) s = 3;
      if (y === by0) s -= 1; else if (y === by0 + 1) s += 0;
      if (y === by1) s += 1;
      setSh(x, y, s);
    }
    if (y >= by0 + 2) shade(Math.round((r[0] + r[1]) / 2), y, 1, B);
  }

  /* arms: rounded shoulder and hand, biceps/forearm bulge by muscle, light on the left, shadow on the right */
  const runs = (y, c = S) => { const out = []; let a = -1; for (let x = 0; x <= W; x++) { if (g(x, y) === c) { if (a < 0) a = x; } else if (a >= 0) { out.push([a, x - 1]); a = -1; } } return out; };
  const bodyRange = (y) => { const t = rowRange(y, T), b = rowRange(y, B); if (t && b) return [Math.min(t[0], b[0]), Math.max(t[1], b[1])]; return t || b; };
  const BR = []; { let last = null; for (let y = 0; y < H; y++) { const r = bodyRange(y); if (r) last = r; BR[y] = r || (y > by1 ? last : null); } }
  let armBottom = by1;
  for (const side of [-1, 1]) {
    const A = {}, B2 = {}; let ay0 = -1, ay1 = -1;
    for (let y = ty0 - 1; y <= by1 + 10; y++) {
      const r = BR[y]; if (!r) continue;
      let pick = null;
      for (const [a, b] of runs(y)) if (side < 0 ? b < r[0] : a > r[1]) if (!pick || (side < 0 ? a < pick[0] : b > pick[1])) pick = [a, b];
      if (pick && (ay1 < 0 || y === ay1 + 1)) { if (ay0 < 0) ay0 = y; ay1 = y; A[y] = pick[0]; B2[y] = pick[1]; }
    }
    if (ay0 < 0) continue;
    const refA = A[ay1], refB = B2[ay1];
    for (let y = ay1 + 1; y <= ay1 + 4; y++) { const x = side < 0 ? refA : refB; if (g(x, y) === S) { ay1 = y; A[y] = refA; B2[y] = refB; } else break; }
    const L = ay1 - ay0, yb = ay1 + 1; armBottom = Math.max(armBottom, yb);
    const outer = (y) => (side < 0 ? A[y] - 1 : B2[y] + 1);
    /* biceps and forearm bulge (outer edge moves out) */
    for (let y = ay0; y <= ay1; y++) {
      const t = (y - ay0) / L; let e = 0;
      if (t > 0.1 && t < 0.42) e = m * 2 * Math.sin(Math.PI * (t - 0.1) / 0.32);
      else if (t > 0.5 && t < 0.74) e = m * 1.5 * Math.sin(Math.PI * (t - 0.5) / 0.24);
      e = Math.round(e); if (e <= 0) continue;
      const xo = outer(y);
      for (let k = 0; k < e; k++) set(xo + side * k, y, S, 2);
      set(xo + side * e, y, 1, 0);
      if (side < 0) A[y] -= e; else B2[y] += e;
    }
    /* rounded corners: carve, then the skin next to a hole becomes outline */
    const cut = [];
    const carve = (y, k, xo) => { for (let i = 0; i <= k; i++) { const x = xo - side * i; set(x, y, 0, 0); cut.push([x, y]); } };
    const xs = outer(ay0 + 3);
    carve(ay0 - 1, 3, xs); carve(ay0, 1, xs); carve(ay0 + 1, 0, xs);
    const xb = outer(ay1 - 2);
    carve(yb, 1, xb); carve(yb - 1, 0, xb);
    for (const [x, y] of cut) for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) if (g(x + dx, y + dy) === S) set(x + dx, y + dy, 1, 0);
    for (let y = ay0; y <= ay1; y++) { // recompute the skin extent
      if (side < 0) { for (let x = A[y] - 6; x <= B2[y]; x++) if (g(x, y) === S) { A[y] = x; break; } } else { for (let x = B2[y] + 6; x >= A[y]; x--) if (g(x, y) === S) { B2[y] = x; break; } }
    }
    /* shading */
    const eb = ay0 + Math.round(L * 0.5), dl = ay0 + Math.round(L * 0.17), bt = ay0 + Math.round(L * 0.42);
    for (let y = ay0; y <= ay1; y++) {
      const a = A[y], b = B2[y], w = b - a + 1, t = (y - ay0) / L; if (w < 4) continue;
      const hs = side < 0 ? 0 : 1, hl = w >= 13 ? 3 : 2;
      for (let x = a; x <= b; x++) {
        if (g(x, y) !== S) continue;
        const i = x - a; let s = 2;
        if (i < hs) s = 3; else if (i < hs + hl) s = 1; else if (i >= w - 3) s = 3;
        if (i === w - 1) s = 4;
        if (y <= ay0 + 2 && i < w * 0.62) s = Math.max(0, s - 1);         // lit shoulder cap
        if (m >= 0.5 && t > 0.14 && t < 0.36 && i === hs + hl - 1) s = 0;     // biceps peak
        if (m >= 0.5 && t > 0.56 && t < 0.82 && i === hs + hl) s = 1;         // forearm ridge
        setSh(x, y, s);
      }
      const inner = (x) => x >= a + 1 && x <= b - 1;
      if (m >= 0.25 && y === dl) for (let x = b - 5; x <= b - 1; x++) shade(x, y, 1, S);   // deltoid edge
      if (m >= 0.5 && y === bt) for (let x = b - 6; x <= b - 2; x++) shade(x, y, 1, S);                                     // biceps underside
      if (y === eb) for (let x = a + 1; x <= b - 1; x++) if (inner(x)) setSh(x, y, 3);                                       // elbow line
      if (y === eb + 1) for (let x = a + hs + 1; x <= a + hs + 2; x++) setSh(x, y, 1);                                      // forearm top light
      if (y >= ay1 - 3 && y <= ay1 - 1) for (const k of [Math.round(w / 3), Math.round(2 * w / 3)]) setSh(a + k, y, 3);       // fingers
    }
  }

  /* legs: clean knee crease, quad line and calf light */
  const leg = [];
  const lg0 = Math.max(by1 + 1, armBottom + 1);
  let lg1 = lg0; for (let y = lg0; y < H; y++) if (rowRange(y, S)) lg1 = y;
  for (let y = lg0; y <= lg1; y++) for (const [a, b] of runs(y)) {
    const w = b - a + 1, t = (y - lg0) / Math.max(1, lg1 - lg0); if (w < 5) continue;
    if (t > 0.46 && t < 0.5) for (let x = a + 2; x <= b - 3; x++) leg.push([x, y, 1]);
    if (m >= 0.75 && t > 0.56 && t < 0.85) leg.push([a + 1, y, -1], [a + 2, y, -1]);
    leg.push([b - 1, y, 1]);
  }
  for (const [x, y, d] of leg) shade(x, y, d, S);

  /* crotch: close the gap between the thighs with skin; one 1-px seam in the middle, darker at the top */
  {
    const filled = [];
    for (let y = by0 + 1; y < fy0; y++) {
      const x0 = g(mid, y) === 0 ? mid : g(mid - 1, y) === 0 ? mid - 1 : -1; if (x0 < 0) continue;
      let l = x0, r = x0; while (l > 0 && g(l - 1, y) === 0) l--; while (r < W - 1 && g(r + 1, y) === 0) r++;
      if (l === 0 || r === W - 1 || r - l > 26) continue;
      filled.push([y, l, r]);
    }
    const pts = [];
    filled.forEach(([y, l, r], k) => { const c = Math.round((l + r) / 2); for (let x = l; x <= r; x++) { set(x, y, S, x === c ? 4 : 3); pts.push([x, y]); } });
    filled.forEach(([y, l, r]) => { for (let x = l - 4; x <= r + 4; x++) if (g(x, y) === S && gs(x, y) === 4 && x !== Math.round((l + r) / 2)) setSh(x, y, 3); });
    const ink = new Set();
    for (const [x, y] of pts) for (const [dx, dy] of [[-1, 0], [1, 0], [0, -1]]) if (g(x + dx, y + dy) === 1) ink.add((y + dy) * W + x + dx);
    for (const k of ink) {
      const x = k % W, y = (k - x) / W;
      if ([[1, 0], [-1, 0], [0, 1], [0, -1]].every(([dx, dy]) => g(x + dx, y + dy) !== 0)) set(x, y, S, 3);
    }
  }
  /* shoes: toe cap highlight, lace line */
  for (let x = 0; x < W; x++) { if (g(x, fy0) === F) shade(x, fy0, -1); if (g(x, fy0 + 3) === F && x % 3 === 0) shade(x, fy0 + 3, 1); }

  /* fat 100: the feet are wide and leave a 4 px hole between the shoes; fill it with one shared ink shadow */
  if (cx === 4) for (let y = fy0; y < H; y++) {
    let x = 0;
    while (x < W) {
      if (g(x, y) !== 0) { x++; continue; }
      let e = x; while (e < W && g(e, y) === 0) e++;
      if (x > 0 && e < W && e - x <= 6) for (let k = x; k < e; k++) set(k, y, 1, 0);
      x = e;
    }
  }

  /* neck shadow under the chin */
  for (let y = ty0 - 5; y < ty0; y++) for (let x = 0; x < W; x++) if (g(x, y) === S) shade(x, y, 1);

  /* hair: a few clean strands. Shadow right, lit top and left, dark fringe edge, no dots. */
  for (let y = 0; y < H; y++) for (const [a, b] of runs(y, HR)) {
    const v = y - headTop; if (v > 44) continue;
    for (let x = a; x <= b; x++) {
      const dL = x - a, dR = b - x; let s = 2;
      const ph = (x - a + (y >> 2)) % 9;
      if (ph === 2 || ph === 3) s = 1; else if (ph === 6) s = 3;
      if (dL <= 2 && v <= 16 && a < mid - 6) s = 1;
      if (dR <= 2) s = 3;
      if (dR === 0) s = 4;
      if (v <= 1) s = 1;
      const open = g(x, y + 1) !== HR || g(x, y + 2) !== HR;
      if (open && v > 3) s = 3;
      setSh(x, y, s);
    }
  }

  /* face: eyes, brows, nose, mouth */
  if (exs.length) {
    const groups = []; for (const x of exs) { const l = groups[groups.length - 1]; if (l && x - l[l.length - 1] <= 1) l.push(x); else groups.push([x]); }
    const fmid = Math.round((exs[0] + exs[exs.length - 1]) / 2);
    groups.forEach((gr) => { // wipe the old eye
      for (let y = ey - 1; y <= ey + 3; y++) for (let x = gr[0] - 3; x <= gr[gr.length - 1] + 3; x++) if (g(x, y) === 2 || (g(x, y) === FIX && col[(oy + y) * AW + ox + x] === EYEWHITE)) { const s0 = g(x, ey + 4) === S ? gs(x, ey + 4) : 2; set(x, y, S, s0); }
    });
    const humanEye = (gr, i) => {
      const c = gr[0] + 2, left = i === 0 && groups.length > 1, dirOut = left ? -1 : 1;
      for (let x = c - 2; x <= c + 2; x++) { set(x, ey, 2, 0); set(x, ey + 1, FIX, 0, EYEWHITE); set(x, ey + 2, FIX, 0, EYEWHITE); }
      const px = left ? c : c - 1; // pupil looks a little to the middle
      for (const x of [px, px + 1]) { set(x, ey + 1, 2, 0); set(x, ey + 2, 2, 0); }
      /* brow: outer 3 px high, inner 4 px one row lower (determined); male brow is 2 px thick */
      for (let k = -3; k <= 3; k++) {
        const x = c + k, outerSide = k * dirOut > 0; // outerSide: toward the ear
        if (outerSide || k === 0) { if (g(x, ey - 3) === S) set(x, ey - 3, HR, 3); }
        if (!outerSide && k !== 0 && g(x, ey - 2) === S) set(x, ey - 2, HR, 3);
      }
    };
    for (let y = ey + 2; y <= ey + 8; y++) for (let x = exs[0] - 3; x <= exs[exs.length - 1] + 3; x++) if (g(x, y) === S && gs(x, y) === 4 && Math.abs(x - fmid) > 3) setSh(x, y, gs(x, ey - 1)); // old under-eye marks
    if (FACE_STYLE === 'human') {
      groups.forEach(humanEye);
      if (g(fmid, ey + 4) === S) { set(fmid, ey + 4, S, 4); set(fmid, ey + 5, S, 4); }
      if (g(fmid - 1, ey + 3) === S) shade(fmid - 1, ey + 3, -1);
      if (g(fmid + 1, ey + 5) === S) shade(fmid + 1, ey + 5, 1);
      for (const x of [fmid - 2, fmid - 1, fmid, fmid + 1]) if (g(x, ey + 9) === S) set(x, ey + 9, FIX, 0, MOUTH);
      for (const x of [fmid - 1, fmid]) if (g(x, ey + 10) === S) shade(x, ey + 10, 1);
    } else {
      const style = SCIFI[FACE_STYLE]; if (!style) throw new Error('FACE_STYLE must be one of: human, ' + Object.keys(SCIFI).join(', '));
      style({ g, gs, set, shade, setSh, rowRange, ey, groups, fmid, humanEye, female });
    }
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
const BODY = [path.join(OUT, 'assets/body')], LOOKS = [path.join(OUT, 'assets/body/looks')], OUTF = [path.join(OUT, 'assets/outfits')];
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
      if (FACE_STYLE === 'human' && (y === c.ey + 9 || y === c.ey + 10) && Math.abs(x - c.fmid + 0.5) < 2.5) return; // keep the mouth
      const o = (c.oy + y) * AW + c.ox + x; let s = 2; // clean bands: base, a lit strand, a shadow edge below
      if ((x + (y >> 2)) % 8 < 2) s = 1;
      if (y >= c.ey + 12 || c.g(x, y + 1) !== S) s = 3;
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
