/* Class outfits and gear overlays for the body atlas.  node tools/moodboard/outfits.mjs */
import fs from 'node:fs';
import { png, decode } from './png.mjs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const ATLAS = path.join(ROOT, 'docs/moodboard/creator/body_atlas.png');
const W = 52, H = 64, COLS = 5, ROWS = 10, AW = W * COLS, AH = H * ROWS;


/* ---------- label the atlas (same table as the demo's paintLook) ---------- */
const ORIG = { e4bc97: 's0', d39a6a: 's1', '8c605c': 's2', decfe5: 't0', c9b8e8: 't1', '8672a5': 't2',
  ad8ed6: 'b0', '7b4fd0': 'b1', '593597': 'b2', '857788': 'f0', '3a2a52': 'f1', '33204e': 'f2',
  '997d6b': 'h0', '5a3424': 'h1', '462533': 'h2', '0b0414': 'k', '281424': 'e' };
const atlas = decode(fs.readFileSync(ATLAS));
if (atlas.w !== AW || atlas.h !== AH) throw new Error('atlas size ' + atlas.w + 'x' + atlas.h);
/* label(x, y) over the whole atlas: null = transparent */
function label(x, y) {
  const o = (y * AW + x) * 4, d = atlas.data;
  if (!d[o + 3]) return null;
  return ORIG[[d[o], d[o + 1], d[o + 2]].map(v => v.toString(16).padStart(2, '0')).join('')] || 'x';
}

/* ---------- per-cell geometry ---------- */
const hexc = (h, a = 255) => { h = h.replace('#', ''); return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16), a]; };
const ramp = a => a.map(h => hexc(h));
function cellInfo(cx, cy) {
  const lab = (x, y) => (x < 0 || y < 0 || x >= W || y >= H) ? null : label(cx * W + x, cy * H + y);
  const rng = (pred, y) => { let l = -1, r = -1; for (let x = 0; x < W; x++) if (pred(lab(x, y))) { if (l < 0) l = x; r = x; } return l < 0 ? null : [l, r]; };
  const isR = c => l => !!l && l.length === 2 && l[0] === c;
  const t = [], b = [];
  for (let y = 0; y < H; y++) { const rt = rng(isR('t'), y), rb = rng(isR('b'), y); if (rt) t[y] = rt; if (rb) b[y] = rb; }
  const ty = Object.keys(t).map(Number), by = Object.keys(b).map(Number);
  const ey = (() => { for (let y = 0; y < 16; y++) if (rng(l => l === 'e', y)) return y; return 8; })();
  let headTop = 0; for (let y = 0; y < 16; y++) if (rng(l => !!l, y)) { headTop = y; break; }
  const ext = y => rng(l => !!l, y);
  const hx = ext(headTop + 3), hcx = Math.round((hx[0] + hx[1]) / 2);
  /* right hand: the right-most skin run in rows 36-41, and the last row it reaches */
  let ax = 0, ay = 0;
  for (let y = 41; y >= 36; y--) { const r = rng(isR('s'), y); if (r && r[1] > 32) { const e = r[1]; let s = e; while (lab(s - 1, y) && lab(s - 1, y)[0] === 's') s--; ax = Math.round((s + e) / 2); ay = y; break; } }
  return { cx, cy, lab, t, b, ty0: ty[0], ty1: ty[ty.length - 1], by0: by[0], by1: by[by.length - 1],
    mid: Math.round((t[ty[0]][0] + t[ty[0]][1]) / 2), ey, headTop, hcx, ext, ax, ay };
}
const CELLS = []; for (let cy = 0; cy < ROWS; cy++) for (let cx = 0; cx < COLS; cx++) CELLS.push(cellInfo(cx, cy));

class Overlay {
  constructor() { this.d = Buffer.alloc(AW * AH * 4); }
  set(c, x, y, col) { if (x < 0 || y < 0 || x >= W || y >= H || !col) return; this.d.set(col, ((c.cy * H + y) * AW + c.cx * W + x) * 4); }
  has(c, x, y) { return this.d[((c.cy * H + y) * AW + c.cx * W + x) * 4 + 3] > 0; }
  png() { return png(AW, AH, (x, y) => [...this.d.subarray((y * AW + x) * 4, (y * AW + x) * 4 + 4)]); }
}
/* visit every labelled pixel of a ramp letter in a cell: f(x, y, shadeIndex) */
function each(c, letter, f) {
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const l = c.lab(x, y); if (l && l.length === 2 && l[0] === letter) f(x, y, +l[1]); }
}
/* soles: opaque non-ink "x" pixels in the foot rows */
function eachSole(c, f) { for (let y = 58; y < H; y++) for (let x = 0; x < W; x++) if (c.lab(x, y) === 'x') f(x, y); }
function firstRow(c, letter) { let y0 = 99; each(c, letter, (x, y) => { if (y < y0) y0 = y; }); return y0; }

/* ---------- class outfits ---------- */
const TAPE = ['#f3e6b0', '#e8d9a0', '#bfae78'].map(h => hexc(h));
const OUTFITS = {
  scrapper: { t: ramp(['#ffc36b', '#ffa033', '#c4681a']), b: ramp(['#7a5a3c', '#5a3d28', '#3e2a1c']), f: ramp(['#6b5a4a', '#4a3b30', '#33271f']) },
  bruiser: { t: ramp(['#8ae6ff', '#3fd2ff', '#1f8fb8']), b: ramp(['#2f4f8a', '#243b6b', '#182a4e']), f: ramp(['#ffffff', '#dfe9f5', '#9fb3cc']) },
  paladin: { t: ramp(['#e4ffa0', '#c6ff3d', '#7fa81f']), b: ramp(['#6b8a2a', '#4d6620', '#344716']), f: ramp(['#b4bfcc', '#7a8799', '#4d5766']) },
  cablemancer: { t: ramp(['#4a3380', '#2e1f55', '#1a1033']), b: ramp(['#3a2870', '#241747', '#150c2b']), f: ramp(['#4a3380', '#241747', '#150c2b']) },
};
const SILVER = ramp(['#e6ecf2', '#b4bfcc', '#7a8799']), BROWN = ramp(['#a8723a', '#7a4d24', '#4f3016']), GOLD = ramp(['#fff0a0', '#ffd447', '#c28a14']);
const WHITE = hexc('#ffffff'), VIOLET = hexc('#a77bff'), GLOW = hexc('#e4d4ff'), INK = hexc('#0b0414');

function drawOutfit(id) {
  const o = new Overlay(), P = OUTFITS[id];
  for (const c of CELLS) {
    const hw = (c.t[c.ty0][1] - c.t[c.ty0][0]) / 2, span = c.ty1 - c.ty0;
    each(c, 't', (x, y, i) => {
      const [l, r] = c.t[y], dl = x - l, dr = r - x, u = x - c.mid, v = y - c.ty0, tt = v / span;
      let col = P.t[i];
      if (id === 'scrapper') {
        const dx = (tt * 2 - 1) * (hw - 1.5);
        if (tt > 0.08 && tt < 0.8 && (Math.abs(u - dx) <= 1 || Math.abs(u + dx) <= 1)) col = Math.abs(u - dx) < 0.6 || Math.abs(u + dx) < 0.6 ? TAPE[1] : TAPE[2];
        if (y === c.ty1) col = TAPE[1];
      } else if (id === 'bruiser') {
        if (dl === 2 || dl === 3 || dr === 2 || dr === 3) col = WHITE;
        if ((v === 0 && Math.abs(u) <= 4) || (v === 1 && Math.abs(u) <= 2)) col = WHITE;
      } else if (id === 'paladin') {
        if (dl >= 2 && dr >= 2 && v >= 1 && y <= c.ty1 - 2) {
          col = SILVER[i];
          if (v % 5 === 0 || u === 0) col = SILVER[2];
          else if (v % 5 === 2 && (Math.abs(u) === 4 || Math.abs(u) === Math.max(6, Math.round(hw) - 4))) col = WHITE;
        }
      } else {
        if (u === 0 || dl === 2 || dr === 2) col = VIOLET;
        if ((v === 0 && Math.abs(u) <= 3) || (Math.abs(u) === 4 && v === 6)) col = GLOW;
      }
      o.set(c, x, y, col);
    });
    each(c, 'b', (x, y, i) => {
      const [l, r] = c.b[y], dl = x - l, dr = r - x, u = x - c.mid;
      let col = P.b[i];
      if (id === 'scrapper' && y === c.by1) col = TAPE[1];
      if (id === 'bruiser' && (dl === 1 || dr === 1)) col = WHITE;
      if (id === 'paladin' && y <= c.by0 + 1) col = Math.abs(u) <= 2 ? GOLD[1] : BROWN[y === c.by0 ? 0 : 1];
      if (id === 'cablemancer' && (dl === 1 || dr === 1)) col = VIOLET;
      o.set(c, x, y, col);
    });
    const fy0 = firstRow(c, 'f');
    let fy1 = 0; each(c, 'f', (x, y) => { if (y > fy1) fy1 = y; });
    each(c, 'f', (x, y, i) => {
      let col = P.f[i];
      if (id === 'scrapper' && y === fy0 + 2) col = TAPE[1];
      if (id === 'paladin' && y === fy0) col = hexc('#c6ff3d');
      if (id === 'cablemancer' && y === fy1) col = VIOLET;
      o.set(c, x, y, col);
    });
    eachSole(c, (x, y) => o.set(c, x, y, P.f[2]));
  }
  return o;
}

/* ---------- gear ---------- */
const PINK = ramp(['#ff9fd0', '#ff5fb0', '#b8337e']), RED = ramp(['#ff7a7a', '#e83a3a', '#9c1f2a']);
const STEEL = ramp(['#9aa6b8', '#5d6a80', '#3a4456']), LEATHER = ramp(['#8a5a34', '#5e3a1f', '#3b2312']);
const GEAR = {
  'head.sweatband'(c, o) {
    for (const y of [c.ey - 3, c.ey - 2]) {
      const e = c.ext(y); if (!e) continue;
      for (let x = e[0]; x <= e[1]; x++) o.set(c, x, y, x === e[0] || x === e[1] ? INK : y === c.ey - 3 ? WHITE : hexc('#ff5fb0'));
    }
  },
  'head.crown'(c, o) {
    const top = c.headTop;
    for (const y of [top + 1, top + 2]) { const e = c.ext(y); for (let x = e[0] + 1; x <= e[1] - 1; x++) o.set(c, x, y, y === top + 2 ? GOLD[2] : GOLD[1]); }
    for (const du of [-4, 0, 4]) {
      const h = du === 0 ? 3 : 2;
      for (let k = 0; k <= h; k++) { const y = top + 1 - k; o.set(c, c.hcx + du, y, GOLD[1]); o.set(c, c.hcx + du + 1, y, GOLD[0]); }
    }
    o.set(c, c.hcx, top + 1, hexc('#ff5fb0')); o.set(c, c.hcx + 1, top + 1, hexc('#ff5fb0'));
  },
  'top.tank'(c, o) {
    each(c, 't', (x, y, i) => { const v = y - c.ty0; let col = PINK[i]; if (v === 0 || (v === 1 && Math.abs(x - c.mid) > 3)) col = WHITE; if (v >= 9 && v <= 10) col = WHITE; o.set(c, x, y, col); });
  },
  'top.cape'(c, o) {
    /* mantle over the shoulder rows, and cloth hanging outside both arms */
    each(c, 't', (x, y) => { if (y <= c.ty0 + 1) o.set(c, x, y, y === c.ty0 ? RED[0] : RED[1]); });
    for (let y = c.ty0; y <= c.ty0 + 28; y++) {
      const e = c.ext(y); if (!e) continue;
      const len = Math.min(3, 1 + Math.floor((y - c.ty0) / 6));
      for (let k = 1; k <= len; k++) { const sh = y > c.ty0 + 20 ? 2 : k === 1 ? 1 : 0; o.set(c, e[0] - k, y, RED[sh]); o.set(c, e[1] + k, y, RED[sh]); }
    }
    o.set(c, c.mid - 1, c.ty0 + 2, GOLD[1]); o.set(c, c.mid, c.ty0 + 2, GOLD[1]);
  },
  'bottom.shorts'(c, o) {
    each(c, 'b', (x, y, i) => { const [l, r] = c.b[y]; let col = PINK[i]; if (y === c.by0 || x - l === 1 || r - x === 1) col = WHITE; o.set(c, x, y, col); });
  },
  'bottom.belt'(c, o) {
    for (let y = c.by0 - 1; y <= c.by0 + 1; y++) {
      for (let x = 0; x < W; x++) {
        const l = c.lab(x, y); if (!l || l.length !== 2 || (l[0] !== 't' && l[0] !== 'b')) continue;
        const du = Math.abs(x - c.mid);
        o.set(c, x, y, du <= 2 ? (y === c.by0 && du <= 1 ? GOLD[0] : GOLD[1]) : LEATHER[y === c.by0 - 1 ? 0 : y === c.by0 ? 1 : 2]);
      }
    }
  },
  'shoes.sneakers'(c, o) {
    const y0 = firstRow(c, 'f');
    each(c, 'f', (x, y, i) => o.set(c, x, y, y === y0 + 1 && (x + y) % 2 === 0 ? RED[1] : [WHITE, hexc('#e8e4f4'), hexc('#a9a3c4')][i]));
    eachSole(c, (x, y) => o.set(c, x, y, hexc('#ff5fb0')));
  },
  'shoes.boots'(c, o) {
    const y0 = firstRow(c, 'f');
    each(c, 'f', (x, y, i) => o.set(c, x, y, y === y0 + 1 ? GOLD[1] : LEATHER[i]));
    eachSole(c, (x, y) => o.set(c, x, y, STEEL[2]));
    /* tall shafts: the calf rows just above the boot, only on leg skin */
    each(c, 's', (x, y) => { if (y >= y0 - 3 && y < y0) o.set(c, x, y, y === y0 - 3 ? STEEL[0] : STEEL[1]); });
  },
  'weapon.shaker'(c, o) {
    const x0 = c.ax - 2, y0 = c.ay - 3;
    for (let k = 0; k < 14; k++) for (let j = 0; j < 5; j++) {
      let col = k < 2 ? STEEL[1] : k < 3 ? STEEL[0] : j === 0 ? hexc('#e8e4f4') : j === 4 ? hexc('#a9a3c4') : WHITE;
      if (k >= 6 && k <= 8 && j > 0 && j < 4) col = hexc('#3fd2ff');
      o.set(c, x0 + j, y0 + k, col);
    }
    for (const j of [1, 2, 3]) o.set(c, x0 + j, y0 - 1, STEEL[1]);
  },
  'weapon.kettlebell'(c, o) {
    const cxk = c.ax, cyk = c.ay + 8, R = 5;
    for (let y = cyk - R; y <= cyk + R; y++) for (let x = cxk - R; x <= cxk + R; x++) {
      const d = Math.hypot(x - cxk, y - cyk); if (d > R + 0.3) continue;
      o.set(c, x, y, d > R - 1 ? STEEL[2] : (x - cxk < -1 && y - cyk < -1) ? STEEL[0] : STEEL[1]);
    }
    for (let k = 0; k < 4; k++) { o.set(c, cxk - 2, cyk - R - 3 + k, STEEL[2]); o.set(c, cxk + 2, cyk - R - 3 + k, STEEL[2]); }
    for (let x = cxk - 2; x <= cxk + 2; x++) o.set(c, x, cyk - R - 3, STEEL[2]);
    o.set(c, cxk, cyk, WHITE); o.set(c, cxk + 1, cyk, WHITE);
  },
};
const ITEM_SLOT = id => id.split('.')[0];

/* ---------- 24x24 white menu icons ---------- */
function icon(fn) {
  const g = Array.from({ length: 24 }, () => new Array(24).fill(0));
  const R = (x, y, w, h, v = 1) => { for (let j = y; j < y + h; j++) for (let i = x; i < x + w; i++) if (i >= 0 && i < 24 && j >= 0 && j < 24) g[j][i] = v; };
  const C = (cx, cy, r, v = 1) => { for (let j = 0; j < 24; j++) for (let i = 0; i < 24; i++) if (Math.hypot(i + .5 - cx, j + .5 - cy) <= r) g[j][i] = v; };
  fn(R, C);
  return png(24, 24, (x, y) => g[y][x] ? [255, 255, 255, 255] : [0, 0, 0, 0]);
}
const ICONS = {
  'head.sweatband': (R) => { R(2, 8, 20, 7); R(2, 11, 20, 1, 0); R(18, 15, 3, 4); R(15, 15, 3, 3); },
  'head.crown': (R) => { R(3, 15, 18, 5); R(3, 6, 4, 9); R(10, 3, 4, 12); R(17, 6, 4, 9); R(7, 12, 3, 3, 0); R(14, 12, 3, 3, 0); R(11, 16, 2, 2, 0); },
  'top.tank': (R) => { R(5, 3, 4, 7); R(15, 3, 4, 7); R(4, 9, 16, 12); R(9, 3, 6, 6, 0); R(4, 9, 2, 3, 0); R(18, 9, 2, 3, 0); },
  'top.cape': (R) => { for (let y = 3; y < 22; y++) { const h = Math.round(4 + (y - 3) * 0.4); R(12 - h, y, 2 * h, 1); } R(10, 4, 4, 2, 0); R(11, 4, 2, 2); R(11, 10, 2, 8, 0); },
  'bottom.shorts': (R) => { R(4, 4, 16, 4); R(4, 8, 7, 11); R(13, 8, 7, 11); R(11, 8, 2, 4); R(4, 6, 16, 1, 0); },
  'bottom.belt': (R) => { R(1, 8, 22, 8); R(8, 9, 8, 6, 0); R(10, 11, 4, 2); R(1, 11, 5, 1, 0); R(18, 11, 5, 1, 0); },
  'shoes.sneakers': (R) => { R(2, 16, 20, 4); R(3, 6, 8, 10); R(10, 11, 11, 5); R(11, 13, 2, 1, 0); R(13, 14, 2, 1, 0); R(5, 6, 4, 2, 0); },
  'shoes.boots': (R) => { R(6, 2, 9, 15); R(6, 15, 17, 5); R(6, 6, 9, 1, 0); R(8, 9, 5, 1, 0); R(2, 18, 5, 2, 0); },
  'weapon.shaker': (R) => { R(9, 1, 6, 3); R(7, 4, 10, 2); R(8, 6, 8, 16); R(8, 11, 8, 3, 0); R(10, 12, 4, 1); R(15, 2, 6, 2, 0); },
  'weapon.kettlebell': (R, C) => { C(12, 15, 8); R(7, 2, 10, 2); R(7, 2, 2, 8); R(15, 2, 2, 8); C(12, 15, 3, 0); R(9, 4, 6, 6, 0); },
};

/* ---------- write ---------- */
const OUT = { outfits: path.join(ROOT, 'docs/moodboard/outfits'), gear: path.join(ROOT, 'docs/moodboard/gear') };
function write(p, buf) { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, buf); }
const overlays = {};
for (const id of Object.keys(OUTFITS)) { const o = drawOutfit(id); overlays['outfit:' + id] = o; write(path.join(OUT.outfits, id + '.png'), o.png()); }
for (const [id, fn] of Object.entries(GEAR)) {
  const o = new Overlay(); for (const c of CELLS) fn(c, o);
  overlays[id] = o; write(path.join(OUT.gear, ITEM_SLOT(id), id + '.png'), o.png());
}
for (const [id, fn] of Object.entries(ICONS)) write(path.join(OUT.gear, 'icons', id + '.png'), icon(fn));

/* ---------- pixel checks: every overlay pixel must sit on the right atlas labels ---------- */
const WANT = {
  'head.sweatband': 'hske', 'head.crown': 'hske.', 'top.tank': 't', 'top.cape': 't.sk', 'bottom.shorts': 'b', 'bottom.belt': 'tb',
  'shoes.sneakers': 'fx', 'shoes.boots': 'fxs', 'weapon.shaker': '.sbtk', 'weapon.kettlebell': '.sbtkf',
};
let bad = 0;
const fail = m => { bad++; console.log('FAIL', m); };
const cellName = c => 'cell(' + c.cx + ',' + c.cy + ')';
for (const [key, o] of Object.entries(overlays)) {
  const outfit = key.startsWith('outfit:');
  const want = outfit ? 'tbfx' : WANT[key];
  for (const c of CELLS) {
    let n = 0, wrong = 0;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (o.has(c, x, y)) {
      n++; const l = c.lab(x, y), k = l === null ? '.' : l.length === 2 ? l[0] : l === 'k' ? 'k' : l === 'e' ? 'e' : 'x';
      if (!want.includes(k)) wrong++;
    }
    if (!n) fail(key + ' empty ' + cellName(c));
    if (wrong) fail(key + ' ' + cellName(c) + ' ' + wrong + ' px off-label');
  }
  if (outfit) for (const c of CELLS) {
    let miss = 0;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const l = c.lab(x, y); if (l && l.length === 2 && 'tbf'.includes(l[0]) && !o.has(c, x, y)) miss++; }
    if (miss) fail(key + ' ' + cellName(c) + ' uncovered ' + miss);
  }
}
for (const c of CELLS) {
  const sw = overlays['head.sweatband'], cr = overlays['head.crown'];
  for (let y = c.ey; y < H; y++) for (let x = 0; x < W; x++) if (sw.has(c, x, y)) fail('sweatband below eyes ' + cellName(c));
  for (let y = c.ey - 1; y < H; y++) for (let x = 0; x < W; x++) if (cr.has(c, x, y)) fail('crown low ' + cellName(c));
  if (!c.ax) fail('no right hand ' + cellName(c));
  if (c.headTop < 2) fail('headTop<2 ' + cellName(c));
}
console.log(bad ? bad + ' failures' : 'all pixel checks passed (' + Object.keys(overlays).length + ' overlays x 50 cells)');
process.exit(bad ? 1 : 0);
