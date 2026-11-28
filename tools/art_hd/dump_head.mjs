// Debug: print the head of one atlas cell as letters. node tools/art_hd/dump_head.mjs <fatCol> <row> [file]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { decode } from '../moodboard/png.mjs';
const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const im = decode(fs.readFileSync(process.argv[4] || path.join(ROOT, 'assets/body/body_atlas.png')));
const [cx, cy] = [+process.argv[2], +process.argv[3]];
const pal = new Map(); let n = 0; const ch = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
for (let y = (+process.argv[6] || 0); y < (+process.argv[5] || 50); y++) {
  let s = String(y).padStart(2) + ' ';
  for (let x = 24; x < 82; x++) {
    const o = ((cy * 128 + y) * im.w + cx * 104 + x) * 4;
    if (!im.data[o + 3]) { s += '.'; continue; }
    const k = im.data[o] + ',' + im.data[o + 1] + ',' + im.data[o + 2];
    if (!pal.has(k)) pal.set(k, ch[n++]);
    s += pal.get(k);
  }
  console.log(s);
}
console.log([...pal].map(([k, v]) => v + '=' + k).join(' '));
