// HD (2x) redraw of arcade + frostbite area art. Run: node tools/art_hd/areas_b.mjs
// Always reads the 1x originals from git commit 40ba8ee, so it is repeatable.
import fs from 'node:fs'; import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { png, decode } from '../moodboard/png.mjs';
const AREAS = ['arcade', 'frostbite'];
const BASE = '40ba8ee';
const BAYER = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]];
const rng = (s) => () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));
const lum = (r, g, b) => 0.3 * r + 0.59 * g + 0.11 * b;
// hue-shifted shade: t<0 toward blue/violet and darker, t>0 toward warm and lighter
function shade([r, g, b, a], t) {
  if (t < 0) { const k = -t; return [clamp(r * (1 - .5 * k) + 20 * k), clamp(g * (1 - .55 * k)), clamp(b * (1 - .3 * k) + 40 * k), a]; }
  return [clamp(r + 60 * t), clamp(g + 40 * t), clamp(b + 5 * t), a];
}
function up2(img) {
  const w = img.w * 2, h = img.h * 2, d = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) for (let c = 0; c < 4; c++) d[(y * w + x) * 4 + c] = img.data[((y >> 1) * img.w + (x >> 1)) * 4 + c];
  return { w, h, d };
}
const get = (m, x, y) => (x < 0 || y < 0 || x >= m.w || y >= m.h) ? null : [m.d[(y * m.w + x) * 4], m.d[(y * m.w + x) * 4 + 1], m.d[(y * m.w + x) * 4 + 2], m.d[(y * m.w + x) * 4 + 3]];
function set(m, x, y, p) { const o = (y * m.w + x) * 4; m.d[o] = p[0]; m.d[o + 1] = p[1]; m.d[o + 2] = p[2]; m.d[o + 3] = p[3]; }
const bayer = (x, y) => BAYER[y & 3][x & 3] > 7;

function detail(m, kind, area, R) {
  const src = { ...m, d: Uint8Array.from(m.d) };
  const sprite = kind !== 'background' && kind !== 'floor';
  const small = sprite && kind !== 'object' && kind !== 'burst' && kind !== 'fx'; // mark, shadow: keep simple
  for (let y = 0; y < m.h; y++) for (let x = 0; x < m.w; x++) {
    const p = get(src, x, y);
    if (sprite && p[3] === 0) continue;
    const L = lum(p[0], p[1], p[2]);
    const up = get(src, x, y - 1), dn = get(src, x, y + 1), lf = get(src, x - 1, y), rt = get(src, x + 1, y);
    const open = (q) => !q || q[3] === 0;
    const bay = BAYER[y & 3][x & 3] / 16;
    let out = p;
    if (sprite) {
      if (small || p[3] < 255) { /* leave as upscaled */ }
      else if (open(dn) || open(rt)) out = shade(p, -0.55);
      else if (open(up) || open(lf)) out = shade(p, 0.35);
      else if (L > 45) { // L>45 skips the dark LED window and ghost digits
        const r = R();
        if (area === 'frostbite') { if (r < 0.06) out = shade(p, 0.5); else if (r < 0.12 && bay > .5) out = shade(p, -0.25); }
        else { if (r < 0.05) out = shade(p, 0.4); else if (((x ^ y) & 1) === 0 && bay < .25 && (y & 7) < 2) out = shade(p, -0.2); }
        if (kind === 'object' && y > m.h * 0.6 && bay < .4) out = shade(out, -0.2);
      }
    } else if (kind === 'background') {
      const t = y / m.h - 0.5, th = bay - 0.5;
      out = shade(p, t * 0.5 + th * 0.25);
      const r = R();
      if (area === 'arcade' && r < 0.004 && L < 90) out = [255, 95, 176, 255];
      if (area === 'arcade' && r > .996 && L < 90) out = [90, 220, 255, 255];
      if (area === 'frostbite' && r < 0.01) out = [235, 245, 255, 255];
      if (area === 'frostbite' && r > .995) out = shade(p, 0.6);
      if (area === 'arcade' && (y % 16) === 0 && (x % 32) < 28 && L < 80) out = shade(p, -0.3);
    } else { // floor
      const tile = area === 'arcade' ? 16 : 24;
      if (x % tile === 0 || y === 0) out = shade(p, -0.4);
      else if (x % tile === 1 && bay < .6) out = shade(p, 0.25);
      else if (R() < 0.05) out = shade(p, bay > .5 ? 0.3 : -0.3);
      if (area === 'frostbite' && (x + y * 3) % 41 === 0) out = [235, 248, 255, 255];
    }
    set(m, x, y, [out[0], out[1], out[2], p[3]]);
  }
  if (kind === 'background') { // depth props, only over dark pixels of the original
    const put = (x, y, c) => { if (x >= 0 && y >= 0 && x < m.w && y < m.h) set(m, x, y, [...c, 255]); };
    if (area === 'arcade') for (let i = 0; i < 5; i++) { const bx = 12 + i * 66, by = 60 + (i % 2) * 14;
      for (let yy = 0; yy < 40; yy++) for (let xx = 0; xx < 22; xx++) {
        const edge = xx === 0 || yy === 0 || xx === 21;
        put(bx + xx, by + yy, edge ? [10, 4, 20] : (yy > 6 && yy < 22 && xx > 3 && xx < 18 ? (bayer(xx, yy) ? [60, 40, 120] : [40, 120, 160]) : [34, 16, 62]));
      } }
    else for (let i = 0; i < 7; i++) { const bx = 8 + i * 50, by = 150 + (i % 3) * 14;
      for (let yy = 0; yy < 50; yy++) { const hw = Math.max(0, 12 - yy * 0.25);
        for (let xx = -Math.floor(hw); xx <= hw; xx++) put(bx + xx, by + yy, Math.abs(xx) >= hw - 1 ? [14, 30, 60] : (xx < 0 ? [50, 90, 140] : [30, 60, 110])); } }
  }
}

const sheet = [];
for (const area of AREAS) {
  const dir = `assets/areas/${area}`;
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.png'))) {
    const fp = `${dir}/${f}`;
    const old = decode(execFileSync('git', ['show', `${BASE}:${fp}`], { maxBuffer: 1 << 26 }));
    const kind = f.replace('.png', '').replace(/_.*/, '');
    let seed = 7; for (const ch of area + f) seed = (seed * 31 + ch.charCodeAt(0)) >>> 0;
    const m = up2(old);
    detail(m, kind, area, rng(seed));
    fs.writeFileSync(fp, png(m.w, m.h, (x, y) => { const o = (y * m.w + x) * 4; return [m.d[o], m.d[o + 1], m.d[o + 2], m.d[o + 3]]; }));
    sheet.push({ old, w: m.w, h: m.h, d: m.d });
  }
}
// contact sheet: old (nearest 2x) left, new right, on grey
const pad = 6; let cx = 0, cy = 0, rowH = 0, W = 1600; const place = [];
for (const s of sheet) { const cw = s.w * 2 + pad * 2; if (cx + cw > W) { cx = 0; cy += rowH + pad; rowH = 0; } place.push({ s, x: cx, y: cy }); cx += cw; rowH = Math.max(rowH, s.h); }
const H = cy + rowH + pad;
const buf = new Uint8Array(W * H * 4); for (let i = 0; i < W * H; i++) { buf[i * 4] = 70; buf[i * 4 + 1] = 70; buf[i * 4 + 2] = 78; buf[i * 4 + 3] = 255; }
const blit = (w, h, ox, oy, dd) => { for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const o = (y * w + x) * 4, a = dd[o + 3] / 255, t = ((oy + y) * W + ox + x) * 4; for (let c = 0; c < 3; c++) buf[t + c] = buf[t + c] * (1 - a) + dd[o + c] * a; } };
for (const { s, x, y } of place) {
  const o2 = new Uint8Array(s.w * s.h * 4);
  for (let yy = 0; yy < s.h; yy++) for (let xx = 0; xx < s.w; xx++) for (let c = 0; c < 4; c++) o2[(yy * s.w + xx) * 4 + c] = s.old.data[((yy >> 1) * s.old.w + (xx >> 1)) * 4 + c];
  blit(s.w, s.h, x, y, o2); blit(s.w, s.h, x + s.w + pad, y, s.d);
}
fs.writeFileSync('tools/art_hd/preview_areas_b.png', png(W, H, (x, y) => { const o = (y * W + x) * 4; return [buf[o], buf[o + 1], buf[o + 2], 255]; }));
console.log('done', sheet.length, 'files');
