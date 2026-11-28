// Gainsgard sky.png (350 x 320, base 175 x 160): calm castle ceiling above background.png.
// Run: node tools/art_hd/sky_gainsgard.mjs   (node only)
// Writes assets/areas/gainsgard/sky.png and tools/art_hd/preview_sky_gainsgard.png (2x, sky above background + floor)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { png, decode } from '../moodboard/png.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const W = 350, H = 320;
const hex = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16));
const B4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
const bay = (x, y) => (B4[y & 3][x & 3] + 0.5) / 16;
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const hash = (a, b = 0) => { let h = Math.imul(a + 374761393, 668265263) ^ Math.imul(b + 1274126177, 2246822519); h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };

const SKYC = hex('#3a2a52');      // gainsgard sky: 0xFF3A2A52
const INK = hex('#150928');
const MORT = hex('#221040'), SHADE = hex('#2c1850');
const BRICKS = ['#43325e', '#3e2c5c', '#4a3866', '#392950'].map(hex);
const HI = hex('#8a7aa8');
const px = new Array(W * H);
const put = (x, y, c) => { if (x >= 0 && y >= 0 && x < W && y < H) px[y * W + x] = c; };
const get = (x, y) => px[y * W + x];

// quantised (Bayer) mix: only used for gradients
const qmix = (a, b, t, x, y, steps = 4) => mix(a, b, Math.floor(clamp(t) * steps + bay(x, y)) / steps);

// ---------- brick wall ----------
const CH = 12; // course height (same as background.png)
function brickWall(x, y, tone) {
  const c = Math.floor((H - 1 - y) / CH), r = (H - 1 - y) % CH;
  // joints: running bond, widths vary a little
  let xx = -((c % 2) * 17) - 40, bi = 0;
  const ws = [34, 38, 31, 36, 33];
  while (true) { const w = ws[Math.floor(hash(c, bi) * ws.length)]; if (x < xx + w) { xx = [xx, w, bi]; break; } xx += w; bi++; }
  const [bx, bw, bidx] = xx;
  let col = BRICKS[Math.floor(hash(c * 7 + 3, bidx) * 4)];
  if (r === 0 || x === bx + bw - 1) col = MORT;
  else if (r === 1) col = mix(col, MORT, 0.4);
  else if (r === CH - 1) col = mix(col, HI, 0.22);
  else if (x === bx) col = mix(col, HI, 0.12);
  return mix(col, INK, tone);
}
// darker with height
const tone = (x, y) => { const t = 0.1 + 0.42 * (1 - y / H); return Math.floor(t * 8 + bay(x, y)) / 8; };

for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) put(x, y, brickWall(x, y, tone(x, y)));

// ---------- vault geometry ----------
const SPRING = 128, CORN = 168; // spring line of the arches; cornice top
const PIL = [0, 117, 233, 350], PH = 10; // pilaster centres, half width
const ARCH = [[58.5, 48.5], [175, 48], [291.5, 48.5]];
const RIB = 6;

// recessed back wall inside the arch openings: darker
const inOpening = (x, y) => ARCH.some(([cx, r]) => (y >= SPRING && x > cx - r && x < cx + r && y < CORN) || Math.hypot(x + 0.5 - cx, y + 0.5 - SPRING) < r);
for (let y = 0; y < CORN; y++) for (let x = 0; x < W; x++) if (inOpening(x, y)) {
  const d = Math.min(...ARCH.map(([cx, r]) => y < SPRING ? r - Math.hypot(x + 0.5 - cx, y + 0.5 - SPRING) : Math.min(x + 0.5 - (cx - r), cx + r - x - 0.5)));
  const c = get(x, y);
  // soft inner shade next to the ribs, only gradient dither
  put(x, y, qmix(mix(c, INK, 0.3), INK, clamp(1 - d / 14) * 0.55, x, y, 4));
}

// ribs: thick stone arch with voussoirs, highlight outside, shadow inside
for (const [cx, r] of ARCH) {
  for (let y = Math.floor(SPRING - r - RIB - 1); y <= SPRING; y++) for (let x = Math.floor(cx - r - RIB - 1); x <= Math.ceil(cx + r + RIB + 1); x++) {
    const dx = x + 0.5 - cx, dy = y + 0.5 - SPRING, d = Math.hypot(dx, dy), k = d - r;
    if (k < 0 || k >= RIB) continue;
    const ang = Math.atan2(-dy, dx); // 0..pi on top
    if (ang < 0 || ang > Math.PI) continue;
    const seg = ang * 9 / Math.PI, frac = seg - Math.floor(seg);
    let col;
    const key = Math.abs(seg - 4.5) < 0.5;
    if (k < 1) col = hex('#1c1030');                    // shadow edge inside
    else if (k < 2) col = hex('#33244f');
    else if (k >= RIB - 1) col = hex("#7a6a98");        // lit outer edge
    else col = key ? hex('#5c4a7c') : hex('#4a3a68');
    if ((frac < 0.07 || frac > 0.93) && !key && k > 0.5 && k < RIB - 0.5) col = hex('#2a1a44');
    if (key && (Math.abs(seg - 4.5) > 0.42) && k > 0.5 && k < RIB - 0.5) col = hex('#2a1a44');
    put(x, y, mix(col, INK, 0.1));
  }
}

// pilasters
for (const pc of PIL) {
  for (let y = SPRING - 2; y < CORN; y++) for (let x = pc - PH; x < pc + PH; x++) {
    if (x < 0 || x >= W) continue;
    const u = x - (pc - PH); let col = u < 2 ? hex('#5c4a7c') : u < 14 ? hex('#4a3a68') : u < 17 ? hex('#3a2a58') : hex('#2c1850');
    if (u === 0 || u === 2 * PH - 1) col = hex('#221040');
    if ((y - SPRING) % 14 === 13) col = hex('#221040');
    put(x, y, mix(col, INK, 0.1));
  }
  // capital (top slab) and base
  for (const [y0, hh] of [[SPRING - 6, 4], [CORN - 4, 4]]) for (let y = y0; y < y0 + hh; y++) for (let x = pc - PH - 2; x < pc + PH + 2; x++) {
    const col = y === y0 ? hex('#7a6a98') : y === y0 + hh - 1 ? hex('#221040') : hex('#54406f');
    put(x, y, col);
  }
}
// re-draw the rib ends over the capitals so ribs spring out of the pilaster tops
// (ribs end at SPRING; capitals sit just above, so draw capital top after ribs only where no rib)

// ---------- cornice (stone ledge) ----------
for (let x = 0; x < W; x++) {
  const joint = [47, 131, 214, 290, 337].some(j => x === j);
  const col = (y0, c) => put(x, y0, c);
  col(CORN, hex('#8a7aa8'));
  col(CORN + 1, hex('#6a5a88'));
  for (let y = CORN + 2; y < CORN + 8; y++) put(x, y, y < CORN + 5 ? hex('#54406f') : hex('#43325e'));
  col(CORN + 8, hex('#2c1850'));
  col(CORN + 9, hex('#221040'));
  if (joint) for (let y = CORN + 1; y < CORN + 9; y++) put(x, y, hex('#2c1850'));
  // dentils under the slab
  const dent = (x % 14) < 8;
  for (let y = CORN + 10; y < CORN + 16; y++) put(x, y, dent ? (y === CORN + 10 ? hex('#43325e') : y > CORN + 13 ? hex('#33244f') : hex('#3e2c5c')) : hex('#1e1226'));
  if (dent && (x % 14) === 7) for (let y = CORN + 10; y < CORN + 16; y++) put(x, y, hex('#2c1850'));
  // cast shadow below the cornice fading into the wall
  for (let y = CORN + 16; y < CORN + 24; y++) put(x, y, qmix(mix(get(x, y), INK, 0.2), INK, 0.7 * (1 - (y - CORN - 16) / 8), x, y, 4));
}

// ---------- chandelier ----------
const CX = 175, HOOP_Y = 96, HRX = 27, HRY = 5;
const IRON = hex('#2a2440'), IRON_HI = hex('#625e92'), IRON_DK = hex('#100a1e');
const glows = [[CX - 22, 84], [CX, 80], [CX + 22, 84]];
// warm glow (gradient with Bayer dither only)
const WARM = hex('#ffa033');
for (let y = 30; y < 170; y++) for (let x = 90; x < 262; x++) {
  let g = 0; for (const [gx, gy] of glows) g = Math.max(g, 1 - Math.hypot((x - gx) * 0.9, (y - gy)) / 30);
  if (g <= 0) continue;
  put(x, y, qmix(get(x, y), WARM, g * g * 0.38, x, y, 8));
}
// chain from the top (links alternate), fades in with dither
for (let y = 14; y < HOOP_Y - 24; y++) {
  if (y < 34 && bay(CX, y) > (y - 14) / 20) continue;
  const link = y % 5 < 3;
  put(CX - 1, y, link ? IRON_HI : IRON); put(CX, y, link ? hex('#8a88b8') : IRON); put(CX + 1, y, link ? IRON : IRON_DK);
}
// bracket ring where chains meet
for (let dy = -2; dy <= 2; dy++) for (let dx = -3; dx <= 3; dx++) if (Math.abs(dx) + Math.abs(dy) <= 3) put(CX + dx, HOOP_Y - 24 + dy, Math.abs(dx) + Math.abs(dy) === 3 ? IRON_DK : dy < 0 ? IRON_HI : IRON);
// three support chains to the hoop (simple diagonals)
const dline = (x0, y0, x1, y1) => { const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)); for (let i = 0; i <= n; i++) { const x = Math.round(x0 + (x1 - x0) * i / n), y = Math.round(y0 + (y1 - y0) * i / n); put(x, y, i % 4 < 2 ? IRON_HI : IRON); put(x + 1, y, IRON_DK); } };
dline(CX - 1, HOOP_Y - 22, CX - HRX + 2, HOOP_Y - 3);
dline(CX + 1, HOOP_Y - 22, CX + HRX - 3, HOOP_Y - 3);
for (let y = HOOP_Y - 21; y < HOOP_Y - 4; y++) { put(CX - 1, y, IRON); put(CX, y, y % 4 < 2 ? IRON_HI : IRON); put(CX + 1, y, IRON_DK); }
// hoop: elliptical iron band, 3 px thick
for (let a = 0; a < 720; a++) {
  const t = a / 720 * Math.PI * 2;
  for (let k = 0; k < 3; k++) {
    const x = Math.round(CX + Math.cos(t) * HRX), y = Math.round(HOOP_Y + Math.sin(t) * HRY + k);
    const front = Math.sin(t) > 0;
    put(x, y, k === 0 ? (front ? IRON_HI : IRON) : k === 1 ? IRON : IRON_DK);
  }
}
// pendant spike
for (let j = 0; j < 9; j++) { const w = j < 6 ? 1 : 0; for (let i = -w; i <= w; i++) put(CX + i, HOOP_Y + 6 + j, i < 0 ? IRON_HI : i > 0 ? IRON_DK : IRON); }
for (let i = -2; i <= 2; i++) put(CX + i, HOOP_Y + 5, i < 0 ? IRON_HI : IRON);
// candles + flames
const CANDLE = [hex('#e6ccb6'), hex('#c0a496'), hex('#8c7478')];
for (const [gx, gy] of glows) {
  const base = gy + 7; // sits on the hoop
  for (let j = 0; j < 7; j++) { put(gx - 1, base - j, CANDLE[0]); put(gx, base - j, CANDLE[1]); put(gx + 1, base - j, CANDLE[2]); }
  put(gx - 2, base + 1, IRON_HI); put(gx - 1, base + 1, IRON_HI); put(gx, base + 1, IRON); put(gx + 1, base + 1, IRON); put(gx + 2, base + 1, IRON_DK);
  const fy = base - 8;
  put(gx, fy + 1, hex('#ffc075')); put(gx - 1, fy + 1, hex('#ffa033')); put(gx + 1, fy + 1, hex('#ffa033'));
  put(gx, fy, hex('#ffe9a8')); put(gx, fy - 1, hex('#ffc075')); put(gx, fy - 2, hex('#ffa033'));
  put(gx - 1, fy, hex('#ffa033')); put(gx + 1, fy, hex('#ffa033'));
  put(gx, fy + 2, hex('#ffe9a8')); // bright core at the wick
}

// ---------- fade into the area sky colour (top ~30 px) ----------
for (let y = 0; y < 34; y++) for (let x = 0; x < W; x++) {
  const t = y < 4 ? 1 : 1 - (y - 4) / 30; // 1 = pure sky colour
  put(x, y, qmix(get(x, y), SKYC, t, x, y, 5));
}
// chain end at the very top stays hidden by the fade; seam row: dark contact shadow above the beam in background.png
for (let x = 0; x < W; x++) put(x, H - 1, hex('#1e1226'));

fs.writeFileSync(path.join(ROOT, 'assets/areas/gainsgard/sky.png'), png(W, H, (x, y) => [...get(x, y).map(Math.round), 255]));

// ---------- preview (2x): sky stacked above background + floor ----------
const ld = f => decode(fs.readFileSync(path.join(ROOT, 'assets/areas/gainsgard', f)));
const bg = ld('background.png'), fl = ld('floor.png'), sk = ld('sky.png');
const TH = H + bg.h + 0; const S = 2;
const canvas = new Uint8Array(W * (H + bg.h) * 4);
const blit = (im, oy) => { for (let y = 0; y < im.h; y++) for (let x = 0; x < im.w; x++) { const i = (y * im.w + x) * 4; if (!im.data[i + 3]) continue; const o = ((y + oy) * W + x) * 4; canvas[o] = im.data[i]; canvas[o + 1] = im.data[i + 1]; canvas[o + 2] = im.data[i + 2]; canvas[o + 3] = 255; } };
blit(sk, 0); blit(bg, H); blit(fl, H + 228);
fs.writeFileSync(path.join(ROOT, 'tools/art_hd/preview_sky_gainsgard.png'), png(W * S, (H + bg.h) * S, (x, y) => { const o = (((y / S) | 0) * W + ((x / S) | 0)) * 4; return [canvas[o], canvas[o + 1], canvas[o + 2], 255]; }));
console.log('done');
