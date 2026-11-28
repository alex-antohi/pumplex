// HD (2x) redraw of areas riptide, gainsgard, rustbelt. Run: node tools/art_hd/areas_a.mjs
import fs from 'node:fs';
import { png, decode } from '../moodboard/png.mjs';
const AREAS = ['riptide', 'gainsgard', 'rustbelt'];
const BAYER = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]];
const clamp = v => Math.max(0, Math.min(255, Math.round(v)));
function rng(seed) { let s = seed >>> 0 || 1; return () => (s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296; }
function hash(str) { let h = 2166136261; for (const c of str) h = Math.imul(h ^ c.charCodeAt(0), 16777619); return h >>> 0; }
const lum = (r, g, b) => (0.3 * r + 0.59 * g + 0.11 * b) / 255;
// hue-shifted ramp: darker -> toward blue/violet, lighter -> toward warm
function shade(c, amt) {
  const [r, g, b] = c;
  if (amt < 0) { const t = -amt; return [clamp(r * (1 - t * .55) + 8 * t), clamp(g * (1 - t * .6)), clamp(b * (1 - t * .3) + 22 * t)]; }
  return [clamp(r + (255 - r) * amt * .5 + 14 * amt), clamp(g + (255 - g) * amt * .4 + 6 * amt), clamp(b + (255 - b) * amt * .25 - 8 * amt)];
}
const load = f => decode(fs.readFileSync(f));
function up2(img) {
  const w = img.w * 2, h = img.h * 2, d = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const o = (((y >> 1) * img.w) + (x >> 1)) * 4;
    img.data.copy(d, (y * w + x) * 4, o, o + 4);
  }
  return { w, h, data: d };
}
const get = (im, x, y) => (x < 0 || y < 0 || x >= im.w || y >= im.h) ? [0, 0, 0, 0] : [...im.data.subarray((y * im.w + x) * 4, (y * im.w + x) * 4 + 4)];
const set = (im, x, y, c) => { const o = (y * im.w + x) * 4; im.data[o] = c[0]; im.data[o + 1] = c[1]; im.data[o + 2] = c[2]; if (c.length > 3) im.data[o + 3] = c[3]; };
const same = (a, b) => a[0] === b[0] && a[1] === b[1] && a[2] === b[2] && a[3] === b[3];
const L = c => lum(c[0], c[1], c[2]);

function detailSprite(im, rnd, kind) {
  const src = { w: im.w, h: im.h, data: Buffer.from(im.data) };
  for (let y = 0; y < im.h; y++) for (let x = 0; x < im.w; x++) {
    const c = get(src, x, y); if (c[3] === 0) continue;
    const nb = [get(src, x - 1, y), get(src, x + 1, y), get(src, x, y - 1), get(src, x, y + 1)];
    const edge = nb.some(n => n[3] === 0);
    const l = L(c); let amt = 0;
    if (kind === 'object' || kind === 'mark') {
      if (nb[2][3] === 0 || nb[0][3] === 0) amt += 0.22;
      if (nb[1][3] === 0 || nb[3][3] === 0) amt -= 0.3;
      if (nb[2][3] && L(nb[2]) < l - 0.12) amt += 0.18;
      if (nb[0][3] && L(nb[0]) < l - 0.12) amt += 0.12;
      if (BAYER[y & 3][x & 3] / 16 < 0.14 + l * 0.05 && rnd() < 0.5) amt += (rnd() < 0.5 ? -1 : 1) * 0.1;
      if (l > 0.35 && (x + y * 2) % 7 === 0 && rnd() < 0.5) amt -= 0.1;
    } else if (c[3] === 255 && BAYER[y & 3][x & 3] < 3) amt += 0.15;
    let o = amt ? shade(c, amt) : c.slice(0, 3);
    if (edge && c[3] === 255 && (kind === 'object' || kind === 'mark')) {
      const t = 0.62; o = [clamp(o[0] * (1 - t) + 10), clamp(o[1] * (1 - t) + 4), clamp(o[2] * (1 - t) + 26 * t)];
    }
    set(im, x, y, [o[0], o[1], o[2], c[3]]);
  }
}

function detailFloor(im, rnd, area) {
  const src = { w: im.w, h: im.h, data: Buffer.from(im.data) };
  const seamX = area === 'gainsgard' ? 24 : area === 'riptide' ? 40 : 32;
  for (let y = 0; y < im.h; y++) for (let x = 0; x < im.w; x++) {
    const c = get(src, x, y); if (c[3] === 0) continue;
    let amt = 0;
    const up = get(src, x, y - 1);
    if (up[3] === 0) amt += 0.3; else if (!same(up, c) && L(up) < L(c)) amt += 0.15;
    if (y % 12 === 11) amt -= 0.22;
    const row = Math.floor(y / 12);
    if ((x + row * 17) % seamX === 0 && y % 12 < 11) amt -= 0.25;
    if ((x + row * 17) % seamX === 1) amt += 0.08;
    const r = rnd();
    if (r < 0.06) amt -= 0.12; else if (r < 0.1) amt += 0.1;
    if (BAYER[y & 3][x & 3] === 5 && !same(up, c)) amt -= 0.1;
    const o = amt ? shade(c, amt) : c;
    set(im, x, y, [o[0], o[1], o[2], c[3]]);
  }
}

function detailBackground(im, rnd, area) {
  const W = im.w, H = im.h;
  const base = { w: W, h: H, data: Buffer.from(im.data) };
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const c = get(base, x, y);
    const sx = x & 1, sy = y & 1;
    const nx = get(base, x + (sx ? 2 : -2), y), ny = get(base, x, y + (sy ? 2 : -2));
    const th = BAYER[y & 3][x & 3] / 16;
    let o = c;
    if (!same(nx, c) && nx[3] && Math.abs(L(nx) - L(c)) < 0.18 && th < 0.25 && sx) o = nx;
    if (!same(ny, c) && ny[3] && Math.abs(L(ny) - L(c)) < 0.18 && th < 0.25 && sy) o = ny;
    let amt = 0; const r = rnd();
    if (r < 0.05) amt = -0.08; else if (r < 0.09) amt = 0.07;
    const up = get(base, x, y - 1), lf = get(base, x - 1, y), dn = get(base, x, y + 1);
    if (!same(up, c) && L(up) < L(c) - 0.1) amt += 0.14;
    if (!same(dn, c) && L(dn) < L(c) - 0.1) amt -= 0.12;
    if (!same(lf, c) && L(lf) < L(c) - 0.1) amt += 0.08;
    const s = amt ? shade(o, amt) : o;
    set(im, x, y, [s[0], s[1], s[2], o[3]]);
  }
  const rr = rnd;
  const px = (x, y, c) => { if (x >= 0 && y >= 0 && x < W && y < H) set(im, x, y, [c[0], c[1], c[2], 255]); };
  const rect = (x, y, w, h, c) => { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) px(x + i, y + j, c); };
  if (area === 'riptide') {
    for (let i = 0; i < 26; i++) { const x = Math.floor(rr() * W), y = Math.floor(rr() * H * 0.25); if (L(get(im, x, y)) < 0.35) px(x, y, [200, 225, 255]); }
    for (let i = 0; i < 4; i++) { const x = 20 + Math.floor(rr() * (W - 40)), y = Math.floor(H * 0.40 + rr() * 8); rect(x, y, 4, 1, [150, 200, 235]); rect(x + 1, y + 1, 2, 1, [60, 110, 160]); }
    rect(W - 60, Math.floor(H * 0.34), 2, 8, [14, 22, 48]); px(W - 60, Math.floor(H * 0.34) - 1, [255, 190, 90]);
  } else if (area === 'gainsgard') {
    for (let i = 0; i < 5; i++) { const x = 14 + i * 62 + Math.floor(rr() * 8), y = Math.floor(H * 0.30); rect(x, y, 3, 4, [22, 20, 40]); rect(x, y + 4, 1, 1, [255, 190, 80]); }
    for (let i = 0; i < 18; i++) { const x = Math.floor(rr() * W), y = Math.floor(rr() * H * 0.2); if (L(get(im, x, y)) < 0.3) px(x, y, [235, 230, 255]); }
  } else {
    for (let i = 0; i < 6; i++) { const x = 10 + i * 56 + Math.floor(rr() * 10), y = Math.floor(H * 0.12 + rr() * 30); rect(x, y, 14, 2, [70, 44, 40]); rect(x, y, 14, 1, [120, 76, 56]); px(x + 1, y + 1, [30, 20, 28]); px(x + 12, y + 1, [30, 20, 28]); }
    for (let i = 0; i < 40; i++) { const x = Math.floor(rr() * W), y = Math.floor(rr() * H * 0.5); if (L(get(im, x, y)) < 0.4) px(x, y, [150, 90, 56]); }
  }
}

const writePng = (file, im) => fs.writeFileSync(file, png(im.w, im.h, (x, y) => [...im.data.subarray((y * im.w + x) * 4, (y * im.w + x) * 4 + 4)]));

const sheet = [];
for (const area of AREAS) {
  const dir = `assets/areas/${area}`;
  for (const f of fs.readdirSync(dir).filter(n => n.endsWith('.png'))) {
    const file = `${dir}/${f}`;
    const old = load(file);
    sheet.push({ file, old: { w: old.w, h: old.h, data: Buffer.from(old.data) } });
    const im = up2(old), rnd = rng(hash(file)), n = f.replace('.png', '');
    if (n === 'background') detailBackground(im, rnd, area);
    else if (n === 'floor') detailFloor(im, rnd, area);
    else if (n.startsWith('object')) detailSprite(im, rnd, 'object');
    else if (n.startsWith('mark')) detailSprite(im, rnd, 'mark');
    else if (n.startsWith('burst')) detailSprite(im, rnd, 'burst');
    else if (n.startsWith('fx')) detailSprite(im, rnd, 'fx');
    writePng(file, im);
  }
}
// contact sheet: old (2x nearest) | new
const rows = sheet.filter(s => !/fx5?_[2-6]|burst_[2-5]|object_hit|object_tap/.test(s.file));
const cw = 350, pad = 4; let y0 = 0; const place = [];
for (const s of rows) { const nw = load(s.file); place.push({ s, nw, y: y0 }); y0 += nw.h + pad; }
const SW = cw * 2 + pad * 3, SH = y0;
const out = Buffer.alloc(SW * SH * 4);
for (let i = 0; i < SW * SH; i++) out.set([40, 20, 60, 255], i * 4);
for (const p of place) for (let y = 0; y < p.nw.h; y++) for (let x = 0; x < Math.min(p.nw.w, cw); x++) {
  const o = get(p.s.old, x >> 1, y >> 1), n = get(p.nw, x, y);
  const put = (px0, c) => { if (c[3] === 0) return; out.set([c[0], c[1], c[2], 255], ((p.y + y) * SW + px0 + x) * 4); };
  put(pad, o); put(pad * 2 + cw, n);
}
fs.writeFileSync('tools/art_hd/preview_areas_a.png', png(SW, SH, (x, y) => [...out.subarray((y * SW + x) * 4, (y * SW + x) * 4 + 4)]));
console.log('done', sheet.length, 'files');
