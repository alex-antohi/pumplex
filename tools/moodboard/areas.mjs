/* Area scenes -> PNG layers for the Flutter app (design handoff item 1).
 *
 *   node tools/moodboard/areas.mjs
 *
 * Source art: the CSS boxes of the design demo's area scenes (demo since removed). The demo scene was
 * 350 x 300 CSS px. This generator rasterises those boxes at 1 art pixel = 2 CSS px,
 * so every layer lives on a 175 x 150 pixel grid. Write coordinates in CSS px below
 * (copied from the demo); they are sampled at pixel centres and snapped to even values.
 * No npm packages. Output: docs/moodboard/areas/<id>/*.png + anim.json.
 */
import fs from 'node:fs';
import path from 'node:path';
import { png } from './png.mjs';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const OUT = path.join(ROOT, 'docs', 'moodboard', 'areas');
const K = 2, W = 175, H = 150; // CSS px per art px, scene size in art px
const SC = { x: 0, y: 0, w: 350, h: 300 }; // scene box in CSS px

/* ---------- raster layer ---------- */
const cc = new Map();
function col(s) {
  if (Array.isArray(s)) return s;
  let c = cc.get(s);
  if (!c) { let h = s.slice(1); if (h.length === 3) h = [...h].map(x => x + x).join(''); c = [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]; cc.set(s, c); }
  return c;
}
class Layer {
  /* x,y,w,h in art px. Drawing calls use scene coordinates; the layer crops. */
  constructor(x, y, w, h) { this.x = x; this.y = y; this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
  blend(px, py, color, a = 1) {
    const X = px - this.x, Y = py - this.y;
    if (X < 0 || Y < 0 || X >= this.w || Y >= this.h || a <= 0) return;
    const c = col(color), d = this.d, i = (Y * this.w + X) * 4, da = d[i + 3] / 255, oa = a + da * (1 - a);
    for (let k = 0; k < 3; k++) d[i + k] = Math.round((c[k] * a + d[i + k] * da * (1 - a)) / oa);
    d[i + 3] = Math.round(oa * 255);
  }
  encode() { return png(this.w, this.h, (x, y) => { const i = (y * this.w + x) * 4; return [this.d[i], this.d[i + 1], this.d[i + 2], this.d[i + 3]]; }); }
  opaque() { let n = 0; for (let i = 3; i < this.d.length; i += 4) if (this.d[i]) n++; return n; }
}
const R = (L, x, y, w, h, color, a = 1) => { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) L.blend(x + i, y + j, color, a); }; // art px rect
const P = (L, x, y, color, a = 1) => L.blend(x, y, color, a);

/* ---------- CSS-like shape ---------- */
const sn = v => Math.round(v / 2) * 2;
const snb = v => (v > 0 ? Math.max(2, sn(v)) : 0);
function box(par, s) {
  const w = s.w != null ? s.w : par.w - (s.l || 0) - (s.r || 0);
  const h = s.h != null ? s.h : par.h - (s.t || 0) - (s.b || 0);
  const x = s.l != null ? par.x + s.l : par.x + par.w - s.r - w;
  const y = s.t != null ? par.y + s.t : par.y + par.h - s.b - h;
  return { x, y, w, h };
}
function inBox(lx, ly, w, h, rad) {
  if (lx < 0 || ly < 0 || lx >= w || ly >= h || w <= 0 || h <= 0) return false;
  const [tl, tr, br, bl] = rad;
  if (tl[0] && lx < tl[0] && ly < tl[1]) { const a = (tl[0] - lx) / tl[0], b = (tl[1] - ly) / tl[1]; return a * a + b * b <= 1; }
  if (tr[0] && lx > w - tr[0] && ly < tr[1]) { const a = (lx - (w - tr[0])) / tr[0], b = (tr[1] - ly) / tr[1]; return a * a + b * b <= 1; }
  if (br[0] && lx > w - br[0] && ly > h - br[1]) { const a = (lx - (w - br[0])) / br[0], b = (ly - (h - br[1])) / br[1]; return a * a + b * b <= 1; }
  if (bl[0] && lx < bl[0] && ly > h - bl[1]) { const a = (bl[0] - lx) / bl[0], b = (ly - (h - bl[1])) / bl[1]; return a * a + b * b <= 1; }
  return true;
}
function pip(pts, x, y) {
  let c = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
}
const ZERO = [0, 0];
function normRad(r, w, h) {
  if (r === 'ell') return [[w / 2, h / 2], [w / 2, h / 2], [w / 2, h / 2], [w / 2, h / 2]];
  if (r == null) return [ZERO, ZERO, ZERO, ZERO];
  if (typeof r === 'number') return [[r, r], [r, r], [r, r], [r, r]];
  return r.map(v => (Array.isArray(v) ? v : [v, v]));
}
function pickFill(f, lx, ly, w, h) {
  if (f == null) return null;
  if (typeof f === 'string' || (Array.isArray(f) && typeof f[0] === 'number')) return f;
  if (Array.isArray(f)) { for (const g of f) { const c = pickFill(g, lx, ly, w, h); if (c) return c; } return null; }
  return f(lx, ly, w, h);
}
/* o: {x,y,w,h (CSS, scene coords)} + fill, bc/bw (border), rad, clip (% points), ins [[dx,dy,color,spread]], a, tf {rot,sx,sy,tx,ty,skx,sky,org} */
function shape(L, o) {
  const x = sn(o.x), y = sn(o.y), w = Math.max(2, sn(o.w)), h = Math.max(2, sn(o.h));
  let bw = o.bw == null ? 0 : o.bw; bw = (Array.isArray(bw) ? bw : [bw, bw, bw, bw]).map(snb);
  if (!o.bc) bw = [0, 0, 0, 0];
  const [bt, br, bb, bl] = bw, hasB = bt + br + bb + bl > 0;
  const rad = normRad(o.rad, w, h);
  const radIn = [[rad[0][0] - bl, rad[0][1] - bt], [rad[1][0] - br, rad[1][1] - bt], [rad[2][0] - br, rad[2][1] - bb], [rad[3][0] - bl, rad[3][1] - bb]].map(p => [Math.max(0, p[0]), Math.max(0, p[1])]);
  const iw = w - bl - br, ih = h - bt - bb;
  const tf = o.tf || null, a = o.a == null ? 1 : o.a;
  const org = (tf && tf.org) || [w / 2, h / 2];
  const rot = tf && tf.rot ? -tf.rot * Math.PI / 180 : 0, cs = Math.cos(rot), sin = Math.sin(rot);
  const skx = tf && tf.skx ? Math.tan(tf.skx * Math.PI / 180) : 0, sky = tf && tf.sky ? Math.tan(tf.sky * Math.PI / 180) : 0;
  for (let py = L.y; py < L.y + L.h; py++) for (let px = L.x; px < L.x + L.w; px++) {
    let lx = (px + 0.5) * K - x, ly = (py + 0.5) * K - y;
    if (tf) {
      lx -= org[0] + (tf.tx || 0); ly -= org[1] + (tf.ty || 0);
      if (rot) { const nx = lx * cs - ly * sin; ly = lx * sin + ly * cs; lx = nx; }
      if (skx) lx -= skx * ly;
      if (sky) ly -= sky * lx;
      lx /= tf.sx || 1; ly /= tf.sy || 1;
      lx += org[0]; ly += org[1];
    }
    if (!inBox(lx, ly, w, h, rad)) continue;
    if (o.clip && !pip(o.clip, lx / w * 100, ly / h * 100)) continue;
    if (hasB && !inBox(lx - bl, ly - bt, iw, ih, radIn)) { L.blend(px, py, o.bc, a); continue; }
    let c = null;
    if (o.ins) {
      const qx = lx - bl, qy = ly - bt;
      for (const [dx, dy, ic, sp = 0] of o.ins) {
        if (!inBox(qx - dx - sp, qy - dy - sp, iw - 2 * sp, ih - 2 * sp, radIn)) { c = ic; break; }
      }
    }
    if (!c) c = pickFill(o.fill, lx - bl, ly - bt, iw, ih);
    if (c) L.blend(px, py, c, a);
  }
}
/* S(layer, parent box, spec): spec has l/r/t/b + w/h like the demo's CSS */
const S = (L, par, s) => shape(L, { ...s, ...box(par, s) });

/* fills */
const stripes = (dir, stops) => {
  const total = stops[stops.length - 1][1];
  return (lx, ly, w, h) => {
    const t = dir === 'u' ? h - ly : dir === 'd' ? ly : lx;
    const m = ((t % total) + total) % total;
    for (const [c, end] of stops) if (m < end) return c;
    return null;
  };
};
const diag45 = stops => { const total = stops[stops.length - 1][1]; return (lx, ly, w, h) => { const m = (((lx + (h - ly)) * 0.7071) % total + total) % total; for (const [c, end] of stops) if (m < end) return c; return null; }; };
const dots = (tw, th, cx, cy, r, color, ox = 0, oy = 0) => (lx, ly) => {
  const x = ((lx - ox) % tw + tw) % tw, y = ((ly - oy) % th + th) % th;
  return Math.hypot(x - cx, y - cy) <= Math.max(r, 1.5) ? color : null;
};
const grid = (lines) => (lx, ly, w, h) => { for (const [dir, c, thick, period, shift = 0] of lines) { const t = dir === 'u' ? h - ly : lx; if (((t - shift) % period + period) % period < thick) return c; } return null; };
const STAR = [[50, 0], [61, 30], [93, 18], [74, 45], [100, 62], [68, 66], [72, 100], [50, 76], [28, 100], [32, 66], [0, 62], [26, 45], [7, 18], [39, 30]];
function starfield(L, tw, th, ox, oy, color) { // CSS bg tile: dot at the tile centre
  for (let j = -1; j < 12; j++) for (let i = -1; i < 12; i++) { const cx = ox + tw / 2 + i * tw, cy = oy + th / 2 + j * th; P(L, Math.floor(cx / K), Math.floor(cy / K), color); }
}

/* 3x5 pixel font for the few words the scenes carry */
const FONT = {
  A: '010101111101101', C: '011100100100011', E: '111100110100111', G: '011100101101011', H: '101101111101101', I: '111010010010111',
  L: '100100100100111', N: '101111111111101', O: '111101101101111', P: '111101111100100', R: '110101110101101', S: '011100010001110',
  T: '111010010010010', U: '101101101101111', W: '101101111111101', Z: '111001010100111', X: '101101010101101', '-': '000000111000000',
  '/': '001001010100100', 0: '111101101101111', 1: '010110010010111', 2: '111001111100111', 3: '111001111001111', 4: '101101111001001',
  5: '111100111001111', 6: '111100111101111', 7: '111001001010010', 8: '111101111101111', 9: '111101111001111',
};
function text(L, str, ax, ay, color, scale = 1, a = 1) {
  let x = ax;
  for (const ch of str) {
    const g = FONT[ch];
    if (g) for (let r = 0; r < 5; r++) for (let c = 0; c < 3; c++) if (g[r * 3 + c] === '1') R(L, x + c * scale, ay + r * scale, scale, scale, color, a);
    x += 3 * scale + scale;
  }
}

const lerp = (a, b, t) => a + (b - a) * t;
const kf = (t, ks) => { for (let i = 1; i < ks.length; i++) if (t <= ks[i][0]) { const [t0, v0] = ks[i - 1], [t1, v1] = ks[i]; return lerp(v0, v1, (t - t0) / (t1 - t0)); } return ks[ks.length - 1][1]; };

const INK = '#0b0414';
const toArt = v => v / K;
const full = () => new Layer(0, 0, W, H);
const crop = (rc) => new Layer(rc[0] / K, rc[1] / K, rc[2] / K, rc[3] / K); // CSS rect -> layer
const fileList = [];
function save(dir, name, L) { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, name), L.encode()); fileList.push([path.relative(OUT, path.join(dir, name)), L.w, L.h, L.opaque()]); return { file: name, pos: [L.x, L.y], size: [L.w, L.h] }; }

/* shared drawing */
function shell(L, x, y, tf, a) {
  shape(L, { x, y, w: 20, h: 15, bc: INK, bw: 3, rad: [[10, 7.5], [10, 7.5], 4, 4], fill: stripes('r', [['#ff5fb0', 3], ['#ff98c2', 5]]), ins: [[0, -4, '#a63e84']], tf, a });
}
function pearl(L, x, y, tf, a) {
  shape(L, { x, y, w: 17, h: 17, bc: INK, bw: 3, rad: 'ell', fill: '#88dff3', ins: [[-5, -5, '#3681b2'], [3, 3, '#f6eeff', -3]], tf, a });
}
function dumbbell(L, cx, cy, color) { // art px, centred
  R(L, cx - 9, cy - 1, 18, 3, color); R(L, cx - 11, cy - 4, 3, 9, color); R(L, cx + 9, cy - 4, 3, 9, color);
}
function burstFrames(color) {
  const out = [];
  for (let i = 0; i < 5; i++) {
    const t = i / 5, sx = kf(t, [[0, .2], [.6, 1.15], [1, 1]]), rot = kf(t, [[0, -40], [.6, 6], [1, 0]]);
    const L = new Layer(0, 0, 50, 50), tf = { sx, sy: sx, rot, org: [50, 50] };
    shape(L, { x: 0, y: 0, w: 100, h: 100, fill: INK, clip: STAR, tf });
    shape(L, { x: 7, y: 7, w: 86, h: 86, fill: color, clip: STAR, tf: { ...tf, org: [43, 43] } });
    out.push(L);
  }
  return out;
}

/* ---------- area definitions ---------- */
const AREAS = {};

/* ===== Riptide Shore ===== */
{
  const hit = { x: 128, y: 204, w: 84, h: 74 };
  const body = stripes('r', [['#6b5033', 12], ['#ffa033', 22], ['#6b5033', 56], ['#ffa033', 66], ['#6b5033', 9999]]);
  const lidFill = stripes('r', [['#6b5033', 14], ['#ffa033', 24], ['#6b5033', 58], ['#ffa033', 68], ['#6b5033', 9999]]);
  const chest = (L, lid) => {
    S(L, hit, { l: 6, t: 34, w: 72, h: 10, fill: '#ffc075', bc: INK, bw: 3 });
    S(L, hit, { l: 2, b: 0, w: 80, h: 44, bc: INK, bw: 3, fill: body, ins: [[0, -6, '#4b2d19']] });
    S(L, hit, { l: 34, b: 18, w: 14, h: 16, fill: '#ffa033', bc: INK, bw: 2, ins: [[0, -5, '#a6643c']] });
    S(L, hit, { l: 0, b: 40, w: 84, h: 26, bc: INK, bw: 3, rad: [16, 16, 0, 0], fill: lidFill, ins: [[0, 5, '#a6643c']], tf: { rot: lid.rot, ty: lid.ty, org: [6, 26] } });
  };
  AREAS.riptide = {
    name: 'Riptide Shore', color: '#ff5fb0',
    bg(L) {
      R(L, 0, 0, W, H, '#12061f');
      starfield(L, 41, 31, 5, 7, '#f6eeff'); starfield(L, 67, 47, 23, 19, '#c9b8e8');
      S(L, SC, { r: 96, t: 36, w: 46, h: 46, rad: 'ell', fill: '#f6eeff', bc: INK, bw: 3, ins: [[-10, -6, '#c9b8e8'], [6, 8, '#ecd7d0', -3]] });
      S(L, SC, { l: 0, r: 0, b: 70, h: 110, fill: [stripes('u', [[null, 9], ['#3a2a52', 11]]), '#2a1148'], bc: INK, bw: [3, 0, 0, 0] });
      S(L, SC, { r: 104, b: 86, w: 36, h: 80, fill: stripes('u', [['#c9b8e8', 3], [null, 9]]), clip: [[30, 0], [70, 0], [100, 100], [0, 100]], a: 0.8 });
      S(L, SC, { l: 116, b: 177, w: 60, h: 9, fill: '#1f0d36', rad: [[30, 4.5], [30, 4.5], 0, 0] });
      S(L, SC, { l: 142, b: 183, w: 4, h: 28, fill: '#1f0d36', tf: { rot: 8 } });
      S(L, SC, { l: 128, b: 204, w: 36, h: 15, fill: '#1f0d36', clip: [[50, 40], [100, 100], [70, 50], [50, 0], [30, 50], [0, 100]] });
      S(L, SC, { l: 0, r: 0, b: 70, h: 8, fill: stripes('r', [['#3fd2ff', 16], ['#88dff3', 20], [null, 30]]), bc: INK, bw: [2, 0, 0, 0] });
      S(L, SC, { l: 0, r: 0, b: 118, h: 3, fill: stripes('r', [['#3fd2ff', 10], [null, 34]]), a: 0.7 });
      S(L, SC, { r: 14, b: 72, w: 14, h: 130, bc: INK, bw: 3, fill: stripes('u', [['#6b5033', 10], ['#4b2d19', 12]]), tf: { rot: 6, org: [7, 130] } });
      S(L, SC, { r: -16, b: 190, w: 92, h: 48, fill: '#4b2a7a', clip: [[50, 40], [100, 70], [62, 52], [90, 100], [50, 58], [10, 100], [38, 52], [0, 70], [50, 40], [30, 0], [50, 30], [70, 0]] });
    },
    floor(L) {
      S(L, SC, { l: 0, r: 0, b: 0, h: 72, bc: INK, bw: [4, 0, 0, 0], fill: [dots(13, 9, 6.5, 4.5, 1.2, '#8a6f73'), dots(19, 11, 9.5, 5.5, 1, '#ecd7d0'), '#ad9293'], ins: [[0, 8, '#6b5033']] });
      S(L, SC, { l: 226, b: 50, w: 18, h: 18, fill: '#ff5fb0', clip: [[50, 0], [62, 36], [100, 38], [70, 60], [80, 100], [50, 76], [20, 100], [30, 60], [0, 38], [38, 36]] });
    },
    hit, objRect: [120, 164, 100, 114],
    obj: {
      idle: L => chest(L, { rot: 0, ty: 0 }),
      tap: L => chest(L, { rot: -6, ty: -2 }),
      hit: L => chest(L, { rot: -42, ty: -8 }),
    },
    seq: [['tap', 80], ['hit', 300], ['idle', 0]],
    fx: { n: 6, ms: 84, frame(L, i, fifth) {
      const t = i / 6, tf = { tx: kf(t, [[0, 0], [.5, 42], [1, 86]]), ty: kf(t, [[0, 0], [.5, -80], [1, 30]]), rot: t * 360 }, a = 1 - t;
      fifth ? pearl(L, 160, 300 - 96 - 17, tf, a) : shell(L, 160, 300 - 96 - 15, tf, a);
    }, fifth: true },
    burst: { left: 130, bottom: 120, color: '#ff5fb0' },
    mark(dir) {
      let L = new Layer(0, 0, 10, 8); shell(L, 0, 0); const m = save(dir, 'mark.png', L);
      L = new Layer(0, 0, 9, 9); pearl(L, 0, 0); const m5 = save(dir, 'mark_fifth.png', L);
      return { file: m, fifth: m5, layout: { type: 'pile', note: 'rows fill from the bottom up, each row centred in the area, 4 per row, every 5th mark (index 4, 9) is mark_fifth', area: [W - 4 - 43, 150 - 3 - 32, 43, 32], cols: 4, pitch: [11, 8], gap: 0.5, max: 12, origin: 'bottom-up' } };
    },
    markZ: 'below_lifter',
  };
}

/* ===== Gainsgard Keep ===== */
{
  const hit = { x: 124, y: 88, w: 150, h: 132 };
  const wall = (L, base, rim, extra) => {
    S(L, hit, { l: 0, t: 0, w: 150, h: 132, bc: INK, bw: 4, fill: [grid([['u', base[1], 3, 30], ['r', base[1], 3, 60]]), base[0]], ins: [[6, 6, rim]] });
    if (extra) extra(L);
  };
  const banner = (L, left, c, hi, lo) => {
    S(L, SC, { l: left, t: 0, w: 42, h: 70, fill: c, clip: [[0, 0], [100, 0], [100, 100], [50, 84], [0, 100]], ins: [[6, 0, hi, 0], [-6, 0, lo, 0]] });
    dumbbell(L, Math.round((left + 21) / K), 14, INK);
  };
  AREAS.gainsgard = {
    name: 'Gainsgard Keep', color: '#ffa033',
    bg(L) {
      S(L, SC, { l: 0, t: 0, w: 350, h: 300, fill: [grid([['u', '#2a1148', 3, 26], ['r', '#2a1148', 3, 44]]), '#3a2a52'] });
      S(L, SC, { l: 16, t: 50, w: 64, h: 90, bc: INK, bw: 4, rad: [32, 32, 0, 0], fill: [dots(13, 17, 6.5, 8.5, 1, '#f6eeff'), '#1a0b3b'], ins: [[0, 0, '#4b2a7a', 4]] });
      S(L, SC, { l: 45, t: 54, w: 6, h: 86, fill: INK }); S(L, SC, { l: 20, t: 92, w: 56, h: 5, fill: INK });
      S(L, SC, { l: 0, t: 144, w: 100, h: 84, fill: '#c9b8e8', a: 0.12, clip: [[22, 0], [78, 0], [100, 100], [0, 100]] });
      S(L, SC, { l: 98, t: 0, w: 4, h: 44, fill: stripes('d', [['#8672a5', 6], [INK, 8]]) });
      banner(L, 128, '#a77bff', '#c8a9f3', '#724eb2');
      banner(L, 232, '#ff5fb0', '#ff98c2', '#a63e84');
      S(L, SC, { l: 177, t: 28, w: 48, h: 48, rad: 'ell', fill: '#ffa033', a: 0.18 });
      S(L, SC, { l: 196, t: 50, w: 10, h: 26, fill: '#6b5033', bc: INK, bw: 2 });
      S(L, SC, { l: 192, t: 26, w: 18, h: 24, fill: '#ffa033', bc: INK, bw: 2, rad: [[9, 12], [9, 12], [3.6, 4.8], [3.6, 4.8]], ins: [[0, -8, '#ff5fb0'], [0, 5, '#ffc075']] });
      S(L, SC, { r: 8, b: 74, w: 54, h: 60, bc: INK, bw: [3, 3, 0, 3], fill: stripes('u', [[null, 18], ['#6b5033', 22]]) });
      for (const b of [112, 90]) { dumbbell(L, Math.round((350 - 18 - 17) / K), Math.round((300 - b - 2) / K), '#c9b8e8'); }
    },
    floor(L) {
      S(L, SC, { l: 0, r: 0, b: 0, h: 72, bc: INK, bw: [4, 0, 0, 0], fill: [grid([['r', '#593597', 3, 52], ['u', '#593597', 3, 22]]), '#8672a5'], ins: [[0, 6, '#ad8ed6']] });
      S(L, SC, { l: 0, b: 8, w: 210, h: 34, fill: '#a63e84', bc: INK, bw: 3, ins: [[0, 0, '#ffa033', 3]], tf: { skx: -20, org: [0, 34] } });
    },
    hit, objRect: [124, 88, 150, 132],
    obj: {
      idle: L => wall(L, ['#4b2a7a', '#3a2a52'], '#593597'),
      tap: L => wall(L, ['#5a3a8c', '#3a2a52'], '#6b4aa6'),
      hit: L => wall(L, ['#4b2a7a', '#3a2a52'], '#593597', Lx => { // chalk dust specks
        for (const [x, y] of [[20, 14], [26, 20], [32, 12], [44, 22], [50, 16], [56, 26]]) P(Lx, hit.x / K + x, hit.y / K + y, '#f6eeff', 0.9);
      }),
    },
    seq: [['tap', 80], ['hit', 200], ['idle', 0]],
    fx: null,
    burst: { left: 248, bottom: 300 - 60 - 100, top: 60, color: '#ffa033' },
    mark(dir) {
      let L = new Layer(0, 0, 4, 22);
      R(L, 0, 0, 3, 22, '#f6eeff'); R(L, 3, 0, 1, 22, '#c9b8e8'); const m = save(dir, 'mark.png', L);
      L = new Layer(0, 0, 30, 17);
      shape(L, { x: 0, y: 24, w: 56, h: 6, fill: '#f6eeff', ins: [[0, -2, '#c9b8e8']], tf: { rot: -28, org: [0, 3] } }); const m5 = save(dir, 'mark_fifth.png', L);
      return { file: m, fifth: m5, layout: { type: 'tally', note: 'groups of 5 wrap 2 per row inside the wall; a group is 4 strokes (mark.png, pitch 6 px) then mark_fifth.png slash across them. Rows centre vertically in the wall.', origin: [68, 50], groupPitch: [32, 30], strokePitch: 6, slashOffset: [-1, 2], max: 12 } };
    },
    markZ: 'above_object',
  };
}

/* ===== Rustbelt Flats ===== */
{
  const hit = { x: 186, y: 218, w: 44, h: 60 };
  const barrel = (L, sy) => S(L, hit, { l: 0, b: 0, w: 44, h: 60, bc: INK, bw: 3, rad: 5, fill: diag45([['#ffa033', 7], [INK, 14]]), ins: [[0, 6, '#a6643c'], [0, -6, '#a6643c']], tf: sy === 1 ? null : { sy, org: [22, 60] } });
  AREAS.rustbelt = {
    name: 'Rustbelt Flats', color: '#ffa033',
    bg(L) {
      R(L, 0, 0, W, H, '#1f0d36');
      S(L, SC, { l: 0, r: 0, t: 70, h: 90, fill: '#2a1148' }); S(L, SC, { l: 0, r: 0, t: 160, h: 68, fill: '#3b2230' });
      S(L, SC, { l: 36, t: 108, w: 104, h: 52, bc: INK, bw: [3, 3, 0, 3], rad: [52, 52, 0, 0], fill: stripes('u', [['#ffa033', 7], ['#1f0d36', 10]]) });
      S(L, SC, { l: 0, r: 0, b: 72, h: 12, fill: '#ecd7d0', bc: INK, bw: [2, 0, 0, 0] });
      S(L, SC, { l: -10, b: 84, w: 130, h: 70, fill: '#3b2230', clip: [[14, 0], [86, 0], [100, 100], [0, 100]], ins: [[6, 0, '#6b4a5e']] });
      S(L, SC, { l: 100, t: 24, w: 6, h: 250, fill: '#4b2d19', bc: INK, bw: 2, tf: { rot: -4 } });
      S(L, SC, { l: 80, t: 40, w: 46, h: 5, fill: '#4b2d19', bc: INK, bw: 2, tf: { rot: -4 } });
      S(L, SC, { l: -20, t: 40, w: 400, h: 50, bc: INK, bw: [0, 0, 2, 0], rad: [0, 0, [200, 25], [200, 25]] });
      S(L, SC, { l: 132, b: 72, w: 20, h: 62, fill: '#3a2a52', bc: INK, bw: 3, rad: [10, 10, 0, 0] });
      S(L, SC, { l: 118, b: 96, w: 14, h: 24, fill: '#3a2a52', bc: INK, bw: [3, 0, 3, 3], rad: [8, 0, 0, 0] });
      for (const x of [137, 144]) R(L, x / K | 0, Math.round((300 - 112 - 4) / K), 2, 2, '#ffa033');
      S(L, SC, { r: 26, b: 72, w: 8, h: 150, fill: '#4b2d19', bc: INK, bw: 2 }); S(L, SC, { r: 136, b: 72, w: 8, h: 150, fill: '#4b2d19', bc: INK, bw: 2 });
      S(L, SC, { r: 8, t: 64, w: 156, h: 100, bc: INK, bw: 4, fill: [dots(47, 37, 23.5, 18.5, 6, '#4b2d19'), dots(23, 29, 11.5, 14.5, 3, '#a6643c'), '#6b5033'], ins: [[6, 0, '#a6643c'], [0, -6, '#4b2d19']] });
      for (const [rx, ty] of [[14, 70], [150, 70], [14, 150], [150, 150]]) S(L, SC, { r: rx, t: ty, w: 6, h: 6, rad: 'ell', fill: '#c9b8e8', bc: INK, bw: 2 });
      S(L, SC, { r: 40, b: 74, w: 84, h: 30, bc: INK, bw: 3, rad: [14, 18, 4, 4], fill: [dots(19, 13, 9.5, 6.5, 3, '#a6643c'), '#6b5033'], ins: [[0, -8, '#4b2d19']] });
    },
    floor(L) {
      S(L, SC, { l: 0, r: 0, b: 0, h: 72, bc: INK, bw: [4, 0, 0, 0], fill: '#a6643c', ins: [[0, 6, '#ffc075']] });
      S(L, SC, { r: 20, b: 8, w: 110, h: 30, bc: '#4b2d19', bw: [2, 0, 0, 2], tf: { skx: 40 } });
      S(L, SC, { r: -2, b: 34, w: 22, h: 10, rad: 'ell', fill: '#3a2a52' });
      S(L, SC, { r: 16, b: 30, w: 26, h: 14, rad: 'ell', fill: '#3a2a52', bc: INK, bw: 3 });
    },
    hit, objRect: [182, 214, 52, 68],
    obj: {
      idle: L => barrel(L, 1),
      tap: L => barrel(L, 0.93),
      hit: L => { // barrel is gone: a scorch decal and a few embers
        S(L, hit, { l: 2, b: 0, w: 40, h: 10, rad: 'ell', fill: INK, a: 0.55 });
        for (const [x, y, c] of [[6, 24, '#ffa033'], [14, 27, '#a6643c'], [26, 26, '#ffa033'], [33, 28, '#a6643c']]) P(L, hit.x / K + x - 3, hit.y / K + y, c);
      },
    },
    seq: [['tap', 80], ['hit', 450], ['idle', 0]],
    rollIn: { note: 'after hit the new barrel rolls in: object_idle slides from dx +75 px, rotation 90 deg to 0, 5 hard steps over 450 ms', dx: 75, rot: 90, steps: 5, ms: 450 },
    fx: { n: 6, ms: 100, frame(L, i) {
      const t = i / 6;
      const puff = (x, y, s, delay) => { const tt = Math.max(0, t - delay); shape(L, { x, y, w: s, h: s, rad: 'ell', fill: '#593597', bc: INK, bw: 3, a: 1 - tt, tf: { sx: lerp(.3, 1.6, tt), sy: lerp(.3, 1.6, tt), ty: -30 * tt } }); };
      puff(174, 300 - 62 - 40, 40, 0); puff(206, 300 - 76 - 32, 32, 0.08 / 0.6);
      const sc = t <= .35 ? lerp(.2, 1.25, t / .35) : lerp(1.25, 1.4, (t - .35) / .65), a = t <= .35 ? 1 : 1 - (t - .35) / .65, tf = { sx: sc, sy: sc };
      shape(L, { x: 162, y: 300 - 6 - 92, w: 92, h: 92, fill: INK, clip: STAR, a, tf });
      shape(L, { x: 170, y: 300 - 14 - 76, w: 76, h: 76, fill: '#ffa033', clip: STAR, a, tf });
      shape(L, { x: 188, y: 300 - 32 - 40, w: 40, h: 40, rad: 'ell', fill: '#ffc075', a, tf });
      for (const [dx, dy, c] of [[-70, -90, '#a6643c'], [60, -110, '#a6643c'], [90, -30, '#ffa033'], [-40, -140, '#ffa033']])
        shape(L, { x: 204, y: 300 - 50 - 8, w: 8, h: 8, fill: c, bc: INK, bw: 2, a: 1 - t, tf: { tx: dx * t, ty: dy * t, rot: 270 * t } });
    } },
    burst: { left: 150, bottom: 116, color: '#ffa033', tint: 'rarity ladder: tint the inner star with the mark colour' },
    mark(dir) {
      const L = new Layer(0, 0, 8, 12);
      const g = FONT.X;
      for (let r = 0; r < 5; r++) for (let c = 0; c < 3; c++) if (g[r * 3 + c] === '1') { R(L, c * 2 + 1, r * 2 + 1, 2, 2, INK); }
      for (let r = 0; r < 5; r++) for (let c = 0; c < 3; c++) if (g[r * 3 + c] === '1') { R(L, c * 2, r * 2, 2, 2, '#ffffff'); }
      R(L, 3, 11, 1, 1, INK); R(L, 2, 10, 2, 2, '#ffffff'); R(L, 3, 11, 1, 1, '#ffffff');
      const m = save(dir, 'mark.png', L);
      return { file: m, fifth: null, tint: 'white X with an ink shadow: tint white with the rarity ladder colour (#c9b8e8, #c6ff3d, #3fd2ff, #a77bff, #ffa033, #ff5fb0; mark index i uses rung min(i,5)). Every 5th mark (TAGGED!) is the same sprite.', layout: { type: 'grid', note: 'spray X on the scrap sign, left to right, 6 per row, rows downward', origin: [(350 - 8 - 156 + 4 + 8) / K, (64 + 4 + 10) / K], pitch: [11, 13], cols: 6, max: 12 } };
    },
    markZ: 'below_lifter',
  };
}

/* ===== Arcade Underpass ===== */
{
  const hit = { x: 202, y: 40, w: 140, h: 190 };
  const machine = (L, padTx, padSx) => {
    S(L, hit, { r: 0, b: 0, w: 82, h: 150, fill: '#2a1148', bc: INK, bw: 4, ins: [[8, 0, '#4b2a7a']] });
    S(L, hit, { r: 0, b: 146, w: 82, h: 40, fill: '#ff5fb0', bc: INK, bw: 4 });
    const hx = (hit.x + hit.w - 82) / K;
    text(L, 'PUNCH-O-', hx + 6, hit.y / K + 4 + 8, INK, 1); text(L, 'TRON', hx + 14, hit.y / K + 4 + 14, INK, 1);
    S(L, hit, { r: 8, b: 96, w: 66, h: 46, fill: INK, bc: '#c6ff3d', bw: 3 });
    const lx = (hit.x + hit.w - 8 - 66) / K + 3, ly = (hit.y + hit.h - 96 - 46) / K + 3;
    text(L, '88', lx + 3, ly + 3, '#c6ff3d', 2, 0.14); // ghost segments; the app draws the live count on top
    S(L, hit, { r: 80, b: 72, w: 26, h: 10, fill: '#8672a5', bc: INK, bw: 3 });
    S(L, hit, { r: 94, b: 54, w: 46, h: 46, rad: 'ell', fill: '#ff5fb0', bc: INK, bw: 4, ins: [[-8, -8, '#a63e84'], [6, 6, '#ff98c2']], tf: { tx: padTx, sx: padSx, org: [46, 23] } });
    S(L, hit, { r: 22, b: 16, w: 38, h: 10, fill: INK, bc: '#8672a5', bw: 3 });
    S(L, hit, { r: 30, b: 40, w: 22, h: 22, rad: 'ell', fill: '#ffa033', bc: INK, bw: 3 });
  };
  AREAS.arcade = {
    name: 'Arcade Underpass', color: '#c6ff3d',
    bg(L) {
      R(L, 0, 0, W, H, '#12061f');
      for (let j = 0; j < 7; j++) for (let i = 0; i < 15; i++) P(L, 6 + i * 12, 6 + j * 12, '#ff5fb0', 0.22);
      S(L, SC, { l: 0, r: 0, t: 0, h: 34, bc: INK, bw: [0, 0, 4, 0], fill: [dots(16, 34, 8, 17, 2, '#8672a5', 4), '#2a1148'] });
      S(L, SC, { l: 0, r: 0, t: 34, h: 16, fill: stripes('r', [[null, 22], ['#2a1148', 26]]) });
      S(L, SC, { l: 14, t: 58, w: 44, h: 56, fill: '#f6eeff', bc: INK, bw: 3, clip: [[0, 0], [100, 0], [100, 80], [76, 100], [0, 100]], ins: [[0, 20, '#ff5fb0']], tf: { rot: -4 } });
      S(L, SC, { l: 72, t: 60, w: 104, h: 30, bc: INK, bw: 3, fill: INK });
      S(L, SC, { l: 74, t: 62, w: 100, h: 26, bc: '#c6ff3d', bw: 3, fill: INK });
      text(L, 'OPEN 24/7', 44, 36, '#c6ff3d', 1);
      text(L, 'SWOLE', 36, 54, '#ff5fb0', 2);
      text(L, 'GAINZ', 77, 57, INK, 1); text(L, 'GAINZ', 76, 56, '#3fd2ff', 1, 0.9);
    },
    floor(L) {
      S(L, SC, { l: 0, r: 0, b: 0, h: 72, bc: INK, bw: [4, 0, 0, 0], fill: [grid([['r', '#593597', 3, 60]]), '#724eb2'], ins: [[0, 6, '#a77bff']] });
      S(L, SC, { l: 0, r: 0, b: 10, h: 4, fill: stripes('r', [['#c6ff3d', 22], [null, 40]]) });
      S(L, SC, { l: 120, b: 30, w: 80, h: 16, rad: 'ell', bc: INK, bw: 2, fill: [stripes('u', [[null, 4], ['#c6ff3d', 5]]), '#2a1148'] });
    },
    hit, objRect: [202, 40, 140, 190],
    obj: { idle: L => machine(L, 0, 1), tap: L => machine(L, 4, 0.9), hit: L => machine(L, 22, 0.7) },
    seq: [['tap', 80], ['hit', 120], ['tap', 120], ['idle', 0]],
    fx: null,
    burst: { left: 100, bottom: 170, color: '#c6ff3d' },
    ledNote: 'object frames carry only the dim "88" ghost; the app draws the live LED count (Space Mono, #c6ff3d) in the window at LED rect.',
    led: [(202 + 140 - 8 - 66) / K + 3, (40 + 190 - 96 - 46) / K + 3, 30, 20],
    mark(dir) {
      const L = new Layer(0, 0, 6, 5);
      R(L, 0, 0, 6, 5, INK); R(L, 1, 1, 4, 2, '#ffc075'); R(L, 1, 3, 4, 1, '#ffa033');
      const m = save(dir, 'mark.png', L);
      return { file: m, fifth: null, layout: { type: 'row', note: 'tickets lie on the floor in a row from the right edge going left', origin: [170 - 6, 150 - 3 - 5], pitch: [-7, 0], max: 12 } };
    },
    markZ: 'below_lifter',
  };
}

/* ===== Frostbite Summit ===== */
{
  const hit = { x: 150, y: 228, w: 56, h: 50 };
  const ice = (L, o = {}) => {
    const base = { w: 56, h: 50, bc: INK, bw: 3, fill: '#88dff3', ins: [[8, 8, '#c9f2ff'], [-8, -8, '#3681b2']] };
    if (!o.split) {
      S(L, hit, { l: 0, b: 0, ...base, tf: o.sy ? { sy: o.sy, org: [28, 50] } : null });
      S(L, hit, { l: 10, t: 8, w: 3, h: 20, fill: '#f6eeff', tf: { rot: 30 } });
      S(L, hit, { l: 30, t: 18, w: 3, h: 16, fill: '#3681b2', tf: { rot: -40 } });
      if (o.cracks) { S(L, hit, { l: 22, t: 4, w: 3, h: 22, fill: INK, tf: { rot: -12 } }); S(L, hit, { l: 40, t: 24, w: 3, h: 18, fill: INK, tf: { rot: 24 } }); }
    } else {
      S(L, hit, { l: 0, b: 0, ...base, clip: [[0, 0], [55, 0], [45, 50], [60, 100], [0, 100]], tf: { tx: -3, rot: -4, org: [28, 50] } });
      S(L, hit, { l: 0, b: 0, ...base, clip: [[55, 0], [100, 0], [100, 100], [60, 100], [45, 50]], tf: { tx: 3, rot: 4, org: [28, 50] } });
    }
  };
  AREAS.frostbite = {
    name: 'Frostbite Summit', color: '#3fd2ff',
    bg(L) {
      R(L, 0, 0, W, H, '#1a0b3b');
      starfield(L, 41, 31, 5, 7, '#f6eeff'); starfield(L, 67, 47, 23, 19, '#c9b8e8');
      S(L, SC, { l: -30, r: -30, t: 34, h: 16, fill: '#a77bff', a: 0.5, tf: { sky: -6 } });
      S(L, SC, { l: -30, r: -30, t: 56, h: 10, fill: '#3fd2ff', a: 0.45, tf: { sky: -6 } });
      S(L, SC, { l: -30, r: -30, t: 72, h: 6, fill: '#c6ff3d', a: 0.25, tf: { sky: -6 } });
      S(L, SC, { l: -40, b: 70, w: 210, h: 150, fill: '#2a1148', clip: [[50, 0], [100, 100], [0, 100]] });
      S(L, SC, { l: -40, b: 174, w: 210, h: 46, fill: '#c9b8e8', clip: [[50, 0], [64, 40], [57, 34], [50, 50], [43, 34], [36, 40]] });
      S(L, SC, { l: 10, b: 70, w: 34, h: 66, fill: '#1f0d36', clip: [[50, 0], [70, 30], [60, 30], [85, 62], [70, 62], [100, 100], [0, 100], [30, 62], [15, 62], [40, 30], [30, 30]] });
      S(L, SC, { l: 10, b: 110, w: 34, h: 26, fill: '#c9b8e8', clip: [[50, 0], [70, 30], [50, 22], [30, 30]] });
      S(L, SC, { l: 0, t: 0, w: 350, h: 300, fill: '#c9b8e8', clip: [[30, 76], [92, 22], [100, 26], [100, 76]] });
      S(L, SC, { l: 0, t: 0, w: 350, h: 300, fill: '#f6eeff', clip: [[30, 76], [92, 22], [95, 25], [36, 76]] });
      S(L, SC, { r: 22, t: 28, w: 4, h: 38, fill: '#f6eeff', bc: INK, bw: 2 });
      S(L, SC, { r: -2, t: 28, w: 24, h: 16, fill: '#ff5fb0', clip: [[0, 0], [100, 50], [0, 100]] });
    },
    floor(L) {
      S(L, SC, { l: 0, r: 0, b: 0, h: 72, bc: INK, bw: [4, 0, 0, 0], fill: '#c9b8e8', ins: [[0, 6, '#f6eeff']] });
      S(L, SC, { r: 20, b: 30, w: 100, h: 16, rad: 'ell', fill: '#f6eeff' });
      for (const [x, y] of [[230, 14], [244, 18], [258, 14], [272, 18], [286, 14]]) R(L, x / K | 0, Math.round((300 - y - 4) / K), 3, 2, '#8672a5');
    },
    hit, objRect: [144, 222, 68, 62],
    obj: { idle: L => ice(L), tap: L => ice(L, { sy: 0.94, cracks: true }), hit: L => ice(L, { split: true }) },
    seq: [['tap', 80], ['hit', 200], ['idle', 0]],
    reform: { note: 'object_idle reforms after the shatter: scale 0 to 1 from the bottom centre in 4 hard steps over 400 ms', steps: 4, ms: 400 },
    fx: { n: 6, ms: 92, frame(L, i) {
      const t = i / 6;
      for (const [dx, dy, c] of [[-60, -80, '#88dff3'], [50, -100, '#88dff3'], [80, -20, '#c9f2ff'], [-30, -130, '#3681b2'], [-90, -10, '#88dff3']])
        shape(L, { x: 172, y: 300 - 46 - 12, w: 12, h: 12, fill: c, bc: INK, bw: 2, a: 1 - t, tf: { tx: dx * t, ty: dy * t, rot: 200 * t } });
    } },
    burst: { left: 130, bottom: 170, color: '#3fd2ff' },
    mark(dir) {
      const L = new Layer(0, 0, 10, 15), T = new Layer(0, 0, 10, 15);
      R(L, 0, 0, 1, 15, INK); R(L, 1, 0, 1, 15, '#f6eeff'); R(L, 2, 0, 1, 15, INK);
      for (let x = 2; x <= 9; x++) { R(L, x, 0, 1, 1, INK); R(L, x, 5, 1, 1, INK); }
      for (let y = 0; y <= 5; y++) { R(L, 2, y, 1, 1, INK); R(L, 9, y, 1, 1, INK); }
      R(T, 3, 1, 6, 4, '#ffffff');
      const m = save(dir, 'mark.png', L), mt = save(dir, 'mark_tint.png', T);
      const pos = []; for (let i = 0; i < 12; i++) { const x = 116 + i * 17, b = Math.round(70 + (x + 2 - 105) * 0.7465); pos.push([x / K, (300 - b - 30) / K]); }
      return { file: m, fifth: null, tint: { file: mt, note: 'white pennant fill: tint it with the rarity ladder colour and draw it over mark.png. Same 10x15 px canvas.' }, layout: { type: 'slope', note: 'flag i stands on the slope; top-left corners in scene art px, climbing to the summit', positions: pos, max: 12 } };
    },
    markZ: 'below_lifter',
  };
}

/* ---------- write everything ---------- */
fs.mkdirSync(OUT, { recursive: true });
const sceneAnim = {};
for (const [id, A] of Object.entries(AREAS)) {
  const dir = path.join(OUT, id);
  fs.rmSync(dir, { recursive: true, force: true });
  const layers = [];
  let L = full(); A.bg(L); layers.push({ id: 'background', z: 0, ...save(dir, 'background.png', L) });
  L = new Layer(0, 114, W, 36); A.floor(L); layers.push({ id: 'floor', z: 1, ...save(dir, 'floor.png', L) });
  L = new Layer(9, 135, 46, 5); S(L, SC, { l: 18, b: 20, w: 92, h: 10, rad: 'ell', fill: INK, a: 0.45 }); layers.push({ id: 'shadow', z: 2, ...save(dir, 'shadow.png', L) });
  const mk = A.mark(dir);
  const objFrames = {};
  for (const f of ['idle', 'tap', 'hit']) { L = crop(A.objRect); A.obj[f](L); objFrames[f] = save(dir, `object_${f}.png`, L); }
  const fx = [];
  const fxSets = {};
  if (A.fx) {
    const make = (fifth) => { const arr = []; for (let i = 0; i < A.fx.n; i++) { L = full(); A.fx.frame(L, i, fifth); const s = save(dir, `${fifth ? 'fx5' : 'fx'}_${i + 1}.png`, L); arr.push({ file: s.file, ms: A.fx.ms }); } return arr; };
    fxSets.fx = { pos: [0, 0], size: [W, H], loop: false, z: 8, frames: make(false) };
    if (A.fx.fifth) fxSets.fx5 = { note: 'same as fx but on every 5th mark (the pearl)', pos: [0, 0], size: [W, H], loop: false, z: 8, frames: make(true) };
  }
  const bp = { left: A.burst.left, top: A.burst.top != null ? A.burst.top : 300 - A.burst.bottom - 100 };
  const bf = burstFrames(A.burst.color).map((b, i) => { const s = save(dir, `burst_${i + 1}.png`, b); return { file: s.file, ms: 100 }; });
  const lifterTop = 73;
  const json = {
    area: id, name: A.name, color: A.color,
    note: 'Generated by tools/moodboard/areas.mjs. All positions are art pixels from the scene top-left. Scale by whole numbers only, nearest neighbour. The demo draws 1 art px as 2 CSS px.',
    sceneSize: [W, H], demoCssPerPixel: K,
    stack: ['background', 'floor', 'shadow', A.markZ === 'above_object' ? 'lifter, object, marks' : 'marks, lifter, object', 'fx', 'burst'],
    lifter: { pos: [6, lifterTop], size: [52, 64], note: 'body_atlas cell at 1x; its feet sit 13 px above the scene bottom, on the shadow' },
    layers,
    object: {
      hitBox: [A.hit.x / K, A.hit.y / K, A.hit.w / K, A.hit.h / K], z: 6,
      frames: objFrames,
      sequence: A.seq.map(([f, ms]) => ({ frame: f, ms })), sequenceNote: 'on tap play the sequence once, then rest on the last frame (ms 0 = hold). Total about 0.5-0.7 s like the demo.',
      ...(A.rollIn ? { rollIn: A.rollIn } : {}), ...(A.reform ? { reform: A.reform } : {}),
      ...(A.led ? { led: { rect: A.led, note: A.ledNote } } : {}),
    },
    effects: fxSets,
    burst: { pos: [bp.left / K, bp.top / K], size: [50, 50], z: 10, frames: bf, color: A.burst.color, ...(A.burst.tint ? { tint: A.burst.tint } : {}), note: 'star only, no text: the app writes "+1 SET" or the 5th-mark stamp in Anton on top. Play once, hold the last frame ~300 ms.' },
    marks: { z: A.markZ === 'above_object' ? 7 : 3, sprite: mk.file, fifthSprite: mk.fifth, ...(mk.tint ? { tint: mk.tint } : {}), ...mk.layout ? { layout: mk.layout } : {}, newMark: 'a new mark pops in: scale 2.2 to 1, rotate -14 deg to 0, 4 hard steps over 220 ms (like the demo)' },
    shake: { ms: 320, steps: 6, note: 'shake the whole stack on tap; amplitude like px-shake in the demo' },
  };
  fs.writeFileSync(path.join(dir, 'anim.json'), JSON.stringify(json, null, 2) + '\n');
  sceneAnim[id] = json;
}
let bytes = 0;
for (const [f, w, h, n] of fileList) { const s = fs.statSync(path.join(OUT, f)).size; bytes += s; console.log(f.padEnd(34), `${w}x${h}`.padEnd(8), 'px set:', String(n).padStart(6), 'bytes:', s); }
console.log(fileList.length, 'png files,', bytes, 'bytes');
