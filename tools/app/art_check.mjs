/* Art swap check. Swap any PNG in assets/ for a more detailed one: keep the
 * file name, draw it at a whole-number multiple of its base size (2x, 3x...).
 * The app draws every image into its base box (BoxFit.fill, nearest
 * neighbour), so positions, hit boxes and atlas cells do not change.
 *
 *   node tools/app/art_check.mjs           check all PNGs against the base sizes
 *   node tools/app/art_check.mjs --write   write the base sizes (only when a NEW file is added)
 *
 * Base sizes: tools/app/art_base_sizes.json (logical art px).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const BASE = path.join(ROOT, 'tools', 'app', 'art_base_sizes.json');
const walk = d => fs.readdirSync(d, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]);
const size = f => { const b = fs.readFileSync(f); return [b.readUInt32BE(16), b.readUInt32BE(20)]; };
const files = walk(path.join(ROOT, 'assets')).filter(f => f.endsWith('.png') && !/[\/]\d\.\dx[\/]/.test(f));
const rel = f => path.relative(ROOT, f).split(path.sep).join('/');

if (process.argv.includes('--write')) {
  const old = fs.existsSync(BASE) ? JSON.parse(fs.readFileSync(BASE, 'utf8')) : {};
  for (const f of files) old[rel(f)] ??= size(f);
  fs.writeFileSync(BASE, JSON.stringify(old, null, 0).replaceAll('],', '],\n') + '\n');
  console.log('base sizes:', Object.keys(old).length);
} else {
  const base = JSON.parse(fs.readFileSync(BASE, 'utf8'));
  let bad = 0; const scales = {};
  for (const f of files) {
    const r = rel(f), b = base[r], [w, h] = size(f);
    if (!b) { console.log('NEW (run --write):', r, `${w}x${h}`); bad++; continue; }
    const k = w / b[0];
    if (!Number.isInteger(k) || h !== b[1] * k) { console.log('BAD:', r, `${w}x${h}`, 'base', b.join('x')); bad++; continue; }
    scales[k] = (scales[k] || 0) + 1;
  }
  console.log('scales (k: files):', scales);
  process.exit(bad ? 1 : 0);
}
