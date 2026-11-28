// Debug view: crop some atlas cells, upscale, write PNG. node view.mjs src out [k] [bg]
import fs from 'node:fs';
import { png, decode } from '../moodboard/png.mjs';
const [,, src, out, k = '6', bg = '#555555'] = process.argv;
const a = decode(fs.readFileSync(src)); const K = +k;
const cells = [[0, 0], [2, 0], [4, 0], [0, 4], [4, 4], [2, 5], [2, 9]]; const cw = a.w / 5, ch = a.h / 10;
const W = cells.length * cw * K, H = ch * K; const b = [...bg.slice(1).match(/../g)].map(v => parseInt(v, 16));
fs.writeFileSync(out, png(W, H, (x, y) => { const ci = Math.floor(x / (cw * K)); const [cx, cy] = cells[ci]; const sx = Math.floor((x - ci * cw * K) / K) + cx * cw, sy = Math.floor(y / K) + cy * ch; const i = (sy * a.w + sx) * 4; return a.data[i + 3] ? [a.data[i], a.data[i + 1], a.data[i + 2], 255] : [...b, 255]; }));
