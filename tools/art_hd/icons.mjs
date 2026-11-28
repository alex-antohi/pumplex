// HD icons: Scale2x (EPX) smoothing of the 1x icons from commit 40ba8ee, plus shading on tool icons.
// Run: node tools/art_hd/icons.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import { png, decode } from '../moodboard/png.mjs';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const old = f => decode(execSync(`git show 40ba8ee:${f}`, { cwd: ROOT, maxBuffer: 1 << 26 }));
const key = (d, i) => d.data.readUInt32BE(i * 4);
function epx(w, h, get) {
  const W = w * 2, out = new Array(W * h * 2);
  const g = (x, y) => (x < 0 || y < 0 || x >= w || y >= h) ? 0 : get(x, y);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const P = g(x, y), A = g(x, y - 1), B = g(x + 1, y), C = g(x - 1, y), D = g(x, y + 1);
    const e = [C === A && C !== D && A !== B ? A : P, A === B && A !== C && B !== D ? B : P,
      D === C && D !== B && C !== A ? C : P, B === D && B !== A && D !== C ? D : P];
    out[(2 * y) * W + 2 * x] = e[0]; out[(2 * y) * W + 2 * x + 1] = e[1];
    out[(2 * y + 1) * W + 2 * x] = e[2]; out[(2 * y + 1) * W + 2 * x + 1] = e[3];
  }
  return out;
}
const rgba = k => [(k >>> 24) & 255, (k >>> 16) & 255, (k >>> 8) & 255, k & 255];
const write = (f, W, H, px) => { fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, png(W, H, (x, y) => rgba(px[y * W + x]))); };
const list = d => fs.readdirSync(path.join(ROOT, d)).filter(f => f.endsWith('.png'));
const sheet = [];
for (const n of list('assets/icons')) {
  const o = old(`assets/icons/${n}`);
  const px = epx(o.w, o.h, (x, y) => o.data[(y * o.w + x) * 4 + 3] >= 128 ? 0xffffffff : 0);
  for (const d of ['', '2.0x/', '3.0x/']) write(path.join(ROOT, 'assets/icons', d, n), o.w * 2, o.h * 2, px);
  sheet.push([o, px, o.w * 2]);
}
const mix = (k, t) => { const [r, g, b, a] = rgba(k); const f = c => Math.round(t > 0 ? c + (255 - c) * t : c * (1 + t)); return ((f(r) << 24) | (f(g) << 16) | (f(b) << 8) | a) >>> 0; };
const lum = k => { const [r, g, b] = rgba(k); return r + g + b; };
for (const n of list('assets/icons/tools')) {
  const o = old(`assets/icons/tools/${n}`);
  const px = epx(o.w, o.h, (x, y) => key(o, y * o.w + x));
  const W = o.w * 2, H = o.h * 2;
  const op = [...new Set(px)].filter(k => k & 255).sort((a, b) => lum(a) - lum(b));
  const inkK = op[0], at = (x, y) => (x < 0 || y < 0 || x >= W || y >= H) ? 0 : px[y * W + x];
  const res = px.slice();
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const k = px[y * W + x]; if (!(k & 255) || k === inkK) continue;
    if (at(x, y - 1) === inkK || at(x - 1, y) === inkK) res[y * W + x] = mix(k, 0.45);
    else if (at(x, y + 1) === inkK || at(x + 1, y) === inkK) res[y * W + x] = mix(k, -0.3);
  }
  write(path.join(ROOT, 'assets/icons/tools', n), W, H, res);
  sheet.push([o, res, W]);
}
const CW = 204, CH = 100, cols = 6, rows = Math.ceil(sheet.length / cols), SW = cols * CW, SH = rows * CH;
const buf = new Uint32Array(SW * SH).fill(0x1a0b3bff);
sheet.forEach(([o, px, W], i) => {
  const ox = (i % cols) * CW, oy = Math.floor(i / cols) * CH;
  const s = o.w > 12 ? 2 : 4;
  for (let y = 0; y < o.h; y++) for (let x = 0; x < o.w; x++) {
    const a = o.data.readUInt32BE((y * o.w + x) * 4); if (!(a & 255)) continue;
    for (let dy = 0; dy < s * 2; dy++) for (let dx = 0; dx < s * 2; dx++) { const X = ox + 2 + x * s * 2 + dx, Y = oy + 2 + y * s * 2 + dy; if (X < ox + 100 && Y < oy + 100) buf[Y * SW + X] = a >>> 0; }
  }
  const H = px.length / W;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const a = px[y * W + x]; if (!(a & 255)) continue;
    for (let dy = 0; dy < s; dy++) for (let dx = 0; dx < s; dx++) { const X = ox + 104 + x * s + dx, Y = oy + 2 + y * s + dy; if (X < ox + CW && Y < oy + 100) buf[Y * SW + X] = a >>> 0; }
  }
});
fs.writeFileSync(path.join(ROOT, 'tools/art_hd/preview_icons.png'), png(SW, SH, (x, y) => rgba(buf[y * SW + x])));
console.log('done', sheet.length);
