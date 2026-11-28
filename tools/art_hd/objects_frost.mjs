// Frostbite Summit: ice block frames, shard fx, flag marks, shadow (2x pixels).
import { Img, hx, rp, bay, rnd, mix, clamp, tri } from './lib_px.mjs';

const OL = '0b0414';
const ICE = ['1d2a63', '2f5fa8', '4a98d8', '7fd0f0', 'b8f0ff', 'f4ffff'];

// block shape: bounds + chamfer; ph selects cracks etc.
function blockMask(x0, y0, x1, y1, ch) {
  return (x, y) => {
    if (x < x0 || x > x1 || y < y0 || y > y1) return false;
    const dx = Math.min(x - x0, x1 - x), dy = Math.min(y - y0, y1 - y);
    return dx + dy >= ch;
  };
}

function shadeBlock(im, x0, y0, x1, y1, ch, o = {}) {
  const inside = blockMask(x0, y0, x1, y1, ch);
  const bt = 6, bs = 5;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    if (!inside(x, y)) continue;
    const dT = y - y0, dL = x - x0, dR = x1 - x, dB = y1 - y;
    let c;
    const noise = (rnd(x, y, 2) - 0.5) * 0.06;
    if (dT < bt && dT <= dL + 1 && dT <= dR + 1) c = rp(ICE.slice(3), 0.55 + (1 - (x - x0) / (x1 - x0)) * 0.4 - dT / bt * 0.25 + noise, x, y, 0.5);
    else if (dL < bs && dL <= dB) c = rp(ICE.slice(2, 5), 0.8 - dL / bs * 0.3 + noise, x, y, 0.5);
    else if (dR < bs && dR <= dB) c = rp(ICE.slice(0, 3), 0.55 + dR / bs * 0.3 + noise, x, y, 0.5);
    else if (dB < bs) c = rp(ICE.slice(0, 3), 0.25 + dB / bs * 0.35 + noise, x, y, 0.5);
    else {
      const u = (x - x0) / (x1 - x0), v = (y - y0) / (y1 - y0);
      let t = 0.86 - (u * 0.5 + v * 0.55) + noise;
      // inner facet: a triangle from the top-right corner reads slightly darker
      if (u + (1 - v) > 1.25 && u > 0.55) t -= 0.12;
      if (v > 0.55 && u < 0.4 && u + v > 0.75) t += 0.06;
      c = rp(ICE.slice(1, 5), t, x, y, 0.55);
    }
    im.px(x, y, c);
  }
}

function crack(im, pts, wide = false) {
  for (let i = 0; i < pts.length - 1; i++) {
    const [ax, ay] = pts[i], [bx, by] = pts[i + 1];
    im.line(ax + 1, ay + 1, bx + 1, by + 1, ICE[0]);
  }
  for (let i = 0; i < pts.length - 1; i++) {
    const [ax, ay] = pts[i], [bx, by] = pts[i + 1];
    im.line(ax, ay, bx, by, wide ? ICE[5] : ICE[4]);
  }
}
function bubble(im, x, y, r) {
  for (let j = -r; j <= r; j++) for (let i = -r; i <= r; i++) if (i * i + j * j <= r * r + 0.5 && im.has(x + i, y + j)) im.px(x + i, y + j, i + j < 0 ? ICE[4] : ICE[2]);
  if (im.has(x - 1, y - 1)) im.px(x - 1, y - 1, ICE[5]);
}
function frost(im, x0, x1, y0, seed, n) {
  for (let i = 0; i < n; i++) { const x = x0 + Math.floor(rnd(i, 1, seed) * (x1 - x0)), y = y0 + Math.floor(rnd(i, 2, seed) * 5); if (im.has(x, y) && im.get(x, y)[0] !== 11) im.px(x, y, rnd(i, 3, seed) < 0.6 ? 'f6eeff' : ICE[4]); }
}
function snowCap(im, x0, x1, y, seed) {
  // lumpy snow on top edge (above the outline row)
  for (let x = x0; x <= x1; x++) {
    const h = 1 + Math.round(1.6 * Math.sin((x - x0) * 0.55 + seed) + 0.8 * rnd(x, 0, seed));
    for (let j = 0; j < h; j++) im.px(x, y - 1 - j, j === h - 1 ? 'f6eeff' : 'dccff2');
    if (h > 0) im.px(x, y - 1 - (h - 1), 'f6eeff');
  }
}

function addOutlineAndRim(im) {
  im.outline(OL);
  // cold rim light: a lighter pixel line just inside the outline on top and left edges
  const a = new Img(im.w, im.h); a.d.set(im.d);
  for (let y = 1; y < im.h - 1; y++) for (let x = 1; x < im.w - 1; x++) {
    const g = a.get(x, y);
    if (g[3] && !(g[0] === 11 && g[1] === 4) && ((a.get(x - 1, y)[0] === 11 && a.get(x - 1, y)[1] === 4 && a.has(x - 1, y)) || (a.get(x, y - 1)[0] === 11 && a.get(x, y - 1)[1] === 4 && a.has(x, y - 1)))) im.px(x, y, mix(g, hx('f4ffff'), 0.55));
  }
}

export function iceBlock(ph) {
  const I = new Img(68, 62);
  if (ph === 0) {
    shadeBlock(I, 6, 6, 61, 55, 5);
    addOutlineAndRim(I);
    // facet edges and inner detail
    for (let i = 0; i < 14; i++) { I.px(12 + i, 12 + 0, ICE[4]); }
    I.line(12, 12, 55, 12, ICE[3]); I.line(12, 12, 12, 49, ICE[4]); I.line(55, 12, 55, 49, ICE[1]); I.line(12, 49, 55, 49, ICE[0]);
    // glare streaks (upper left)
    for (let i = 0; i < 9; i++) { I.px(14 + i, 22 - i, ICE[5]); I.px(15 + i, 22 - i, ICE[4]); }
    for (let i = 0; i < 4; i++) { I.px(14 + i, 29 - i, ICE[4]); }
    // fine inner cracks and bubbles
    crack(I, [[34, 24], [38, 30], [37, 34], [42, 40]]);
    crack(I, [[38, 30], [44, 29]]);
    bubble(I, 22, 38, 2); bubble(I, 47, 20, 1); bubble(I, 26, 44, 1); bubble(I, 49, 38, 2);
    for (let i = 0; i < 12; i++) { const x = 14 + Math.floor(rnd(i, 1, 6) * 40), y = 14 + Math.floor(rnd(i, 2, 6) * 34); if (I.has(x, y)) I.px(x, y, ICE[5]); }
    frost(I, 8, 58, 6, 11, 14);
    snowCap(I, 10, 30, 7, 0.3); snowCap(I, 44, 56, 7, 2.1);
    // frost along left edge
    for (let y = 12; y < 40; y += 3) if (rnd(y, 0, 5) < 0.7) I.px(7, y, 'f6eeff');
    // sparkle
    I.px(10, 10, ICE[5]); I.px(9, 10, ICE[4]); I.px(11, 10, ICE[4]); I.px(10, 9, ICE[4]); I.px(10, 11, ICE[4]);
  } else if (ph === 1) {
    shadeBlock(I, 4, 10, 63, 55, 5);
    addOutlineAndRim(I);
    I.line(10, 16, 57, 16, ICE[3]); I.line(10, 16, 10, 49, ICE[4]); I.line(57, 16, 57, 49, ICE[1]); I.line(10, 49, 57, 49, ICE[0]);
    for (let i = 0; i < 9; i++) { I.px(12 + i, 25 - i, ICE[5]); I.px(13 + i, 25 - i, ICE[4]); }
    // big cracks
    crack(I, [[30, 12], [32, 19], [29, 25], [34, 31], [31, 37], [37, 44], [35, 52]], true);
    crack(I, [[34, 31], [42, 29], [48, 33], [55, 31]], true);
    crack(I, [[29, 25], [22, 27], [17, 33]]);
    crack(I, [[37, 44], [46, 46], [52, 44]]);
    crack(I, [[31, 37], [24, 41]]);
    bubble(I, 14, 40, 1); bubble(I, 52, 22, 1);
    frost(I, 6, 60, 10, 12, 12);
    snowCap(I, 8, 24, 11, 1.2); snowCap(I, 46, 58, 11, 3.0);
    // chips popping off the top
    I.rect(30, 6, 2, 2, ICE[4]); I.px(30, 6, ICE[5]); I.rect(38, 5, 2, 2, ICE[3]); I.px(45, 7, ICE[5]);
    I.px(10, 12, ICE[5]); I.px(9, 12, ICE[4]); I.px(11, 12, ICE[4]); I.px(10, 11, ICE[4]); I.px(10, 13, ICE[4]);
  } else {
    // two halves apart, jagged fracture faces
    const jag = [0, 2, 1, 3, 2, 4, 3, 2, 4, 3, 1, 3, 2, 4, 3, 1, 2, 3, 2, 4, 3, 2, 1, 3, 2, 3, 4, 2, 3, 1, 2, 3, 4, 2, 3, 2, 1, 3, 2, 3, 1, 2, 3, 2, 1, 3, 2, 3];
    const L = new Img(68, 62), R = new Img(68, 62);
    // left half: block bounds 2..34 with jagged right edge (x depends on y); tilted out by shearing the top left
    const lm = blockMask(1, 8, 36, 57, 5), rm = blockMask(33, 10, 66, 57, 5);
    // render the full block shading then cut
    const full = new Img(68, 62); shadeBlock(full, 1, 8, 66, 57, 5);
    for (let y = 8; y <= 57; y++) for (let x = 1; x <= 66; x++) {
      const g = full.get(x, y); if (!g[3]) continue;
      const cutL = 31 + jag[(y - 8) % jag.length] - 2, cutR = 36 + jag[(y + 7) % jag.length];
      if (x <= cutL) L.px(x, y, g); if (x >= cutR + 0 && y >= 10) R.px(x, y, g);
    }
    // shift halves so they lean apart: left half moves left/up a bit, right half down
    const Lh = new Img(68, 62), Rh = new Img(68, 62);
    for (let y = 0; y < 62; y++) for (let x = 0; x < 68; x++) { const g = L.get(x, y); if (g[3]) Lh.px(x - (y < 30 ? 1 : 0), y, g); const h = R.get(x, y); if (h[3]) Rh.px(x + 0, y + (x > 60 ? 0 : 0), h); }
    for (const [H, side] of [[Lh, 'L'], [Rh, 'R']]) {
      addOutlineAndRim(H);
      // fracture face: bright inner glow along the break
      for (let y = 6; y <= 57; y++) for (let x = 0; x < 68; x++) {
        if (!H.has(x, y) || H.get(x, y)[0] === 11 && H.get(x, y)[1] === 4) continue;
        const nearBreak = side === 'L' ? !H.has(x + 1, y) || !H.has(x + 2, y) || !H.has(x + 3, y) : !H.has(x - 1, y) || !H.has(x - 2, y) || !H.has(x - 3, y);
        if (nearBreak) H.px(x, y, rnd(x, y, 4) < 0.5 ? ICE[4] : ICE[5]);
      }
    }
    I.over(Lh); I.over(Rh);
    crack(I, [[10, 20], [16, 26], [14, 33]]); crack(I, [[56, 26], [50, 32], [52, 40]]);
    for (let i = 0; i < 9; i++) { I.px(7 + i, 24 - i, ICE[5]); }
    I.px(59, 18, ICE[5]); I.px(58, 18, ICE[4]); I.px(60, 18, ICE[4]); I.px(59, 17, ICE[4]); I.px(59, 19, ICE[4]);
    // chips floating between the halves
    for (const [x, y, s] of [[33, 16, 3], [35, 29, 2], [32, 44, 3], [34, 52, 2]]) { I.rect(x, y, s, s, ICE[3]); I.px(x, y, ICE[5]); I.rect(x + s, y + 1, 1, s, OL); I.rect(x, y + s, s + 1, 1, OL); I.rect(x - 1, y, 1, s, OL); I.rect(x, y - 1, s, 1, OL); }
    frost(I, 4, 30, 7, 13, 6); frost(I, 38, 62, 9, 14, 6);
  }
  return I;
}

// ---- shard fx (350x300): 6 frames baked with falling alpha
const ALPHA = [255, 213, 170, 128, 85, 42];
const SHARDS = [
  [-1.0, -2.2, 9, 0.2], [0.9, -2.6, 8, 1.0], [-2.1, -1.2, 7, 2.2], [2.2, -1.5, 8, 0.6], [-0.3, -3.0, 6, 1.7],
  [1.6, -0.6, 5, 2.9], [-1.7, -0.3, 6, 0.9], [0.4, -1.8, 5, 2.4], [2.6, -2.2, 5, 1.3], [-2.5, -2.0, 5, 2.6],
];
function shard(im, cx, cy, s, rot) {
  const pts = [[0, -s], [s * 0.7, s * 0.1], [0, s * 0.55], [-s * 0.55, s * 0.05]].map(([x, y]) => [cx + x * Math.cos(rot) - y * Math.sin(rot), cy + x * Math.sin(rot) + y * Math.cos(rot)]);
  const S = new Img(im.w, im.h);
  tri(...pts[0], ...pts[1], ...pts[2], (x, y) => S.px(x, y, rp(ICE.slice(1, 5), 0.6 + (pts[0][0] - x) * 0.04 - (y - cy) * 0.02, x, y, 0.4)));
  tri(...pts[0], ...pts[2], ...pts[3], (x, y) => S.px(x, y, rp(ICE.slice(2, 6), 0.75 + (pts[0][0] - x) * 0.05, x, y, 0.4)));
  S.outline(OL);
  // glint
  const hxp = Math.round((pts[0][0] + pts[3][0]) / 2), hyp = Math.round((pts[0][1] + pts[3][1]) / 2); if (S.has(hxp, hyp) && s > 5) S.px(hxp, hyp, ICE[5]);
  im.over(S);
}
export function frostFx(f) {
  const F = new Img(350, 300), ox = 178, oy = 250;
  if (f === 0) {
    // impact flash: crisp star of ice
    const T = new Img(350, 300);
    for (let a = 0; a < 8; a++) { const an = a / 8 * Math.PI * 2, len = a % 2 ? 6 : 10; T.line(ox, oy, ox + Math.cos(an) * len, oy + Math.sin(an) * len, a % 2 ? ICE[4] : ICE[5]); }
    T.rect(ox - 2, oy - 2, 5, 5, ICE[5]); T.rect(ox - 1, oy - 1, 3, 3, 'ffffff');
    for (let y = oy - 12; y <= oy + 12; y++) for (let x = ox - 12; x <= ox + 12; x++) { if (!T.has(x, y)) continue; }
    T.outline(OL); F.over(T);
    return F;
  }
  const t = f;
  SHARDS.forEach(([vx, vy, s, rot], i) => {
    const x = ox + vx * t * 9 + (i % 3 - 1) * 2, y = oy + vy * t * 8 + 0.9 * t * t * 3 - 4;
    shard(F, x, y, s * 1.35 * (1 - t * 0.04), rot + t * (i % 2 ? 0.5 : -0.5));
  });
  // snow dust and sparkles
  for (let i = 0; i < 18; i++) { const a = rnd(i, 1, 55) * Math.PI * 2, r = 4 + t * (10 + rnd(i, 2, 55) * 14); const x = Math.round(ox + Math.cos(a) * r * 1.2), y = Math.round(oy - 6 + Math.sin(a) * r * 0.8 - t * 3); F.px(x, y, rnd(i, 3, 55) < 0.5 ? 'f6eeff' : ICE[4]); if (i % 4 === 0) F.px(x + 1, y, ICE[3]); }
  for (const [dx, dy] of [[-30, -34], [26, -40], [4, -52]]) { const x = ox + dx * t / 3, y = oy + dy * t / 3 - 6; if (t < 5) { F.px(x, y, ICE[5]); F.px(x - 1, y, ICE[4]); F.px(x + 1, y, ICE[4]); F.px(x, y - 1, ICE[4]); F.px(x, y + 1, ICE[4]); } }
  F.mulAlpha(ALPHA[f] / 255);
  return F;
}

// ---- marks: flag on a pole, and the white tint pennant
export function flagMark() {
  const M = new Img(20, 30);
  // pole 0..5 (outline, light, outline), shaded
  for (let y = 0; y < 30; y++) { M.px(0, y, OL); M.px(1, y, OL); M.px(2, y, 'f6eeff'); M.px(3, y, 'a99ad8'); M.px(4, y, OL); M.px(5, y, OL); }
  // ring/highlights on the pole
  for (let y = 3; y < 28; y += 6) { M.px(2, y, 'ffffff'); M.px(3, y, 'dccff2'); }
  // pole cap
  M.px(2, 0, 'ffffff'); M.px(3, 0, 'dccff2');
  // pennant frame: rows 0-1 and 10-11 outline, right end outline. Interior (6..17, 2..9) stays transparent for the tint
  for (let x = 6; x < 20; x++) { M.px(x, 0, OL); M.px(x, 1, OL); M.px(x, 10, OL); M.px(x, 11, OL); }
  for (let y = 0; y < 12; y++) { M.px(18, y, OL); M.px(19, y, OL); }
  // pole attaches: bright rivets on the flag's left edge
  M.px(6, 1, '8672a5'); M.px(6, 10, '8672a5');
  // snow mound at the foot of the pole
  const mound = [[0, 29], [1, 29], [2, 29], [3, 29], [4, 29], [5, 29], [6, 29], [7, 29], [8, 29], [9, 29], [4, 28], [5, 28], [6, 28], [7, 28], [8, 28], [6, 27], [7, 27]];
  const snow = new Img(20, 30);
  for (const [x, y] of mound) snow.px(x, y, 'f6eeff');
  // keep the foot of the pole: mound only to the right
  for (let x = 6; x <= 11; x++) { snow.px(x, 29, x > 9 ? 'dccff2' : 'f6eeff'); }
  snow.px(6, 28, 'f6eeff'); snow.px(7, 28, 'f6eeff'); snow.px(8, 28, 'dccff2'); snow.px(7, 27, 'f6eeff');
  M.over(snow);
  for (const [x, y] of [[6, 29], [7, 28], [8, 28]]) M.px(x, y, 'f6eeff');
  M.px(9, 29, 'a99ad8'); M.px(10, 29, 'a99ad8'); M.px(11, 29, 'a99ad8'); M.px(8, 28, 'dccff2'); M.px(9, 28, OL);
  return M;
}
export function flagTint() {
  const T = new Img(20, 30);
  for (let y = 2; y <= 9; y++) for (let x = 6; x <= 17; x++) {
    // greys only: white lit top, soft fold shadow bands so the tint colour reads shaded
    let g = 255;
    const fold = Math.sin((x - 6) * 0.9) * 0.9;
    if (y >= 8) g = 226; else if (y >= 6 && fold < -0.4) g = 238;
    if (y === 2) g = 255;
    if (x === 6) g = 214;
    if (x >= 15 && y >= 5) g = Math.min(g, 232);
    if ((x === 17) && (y % 2 === 0)) g = Math.min(g, 222);
    T.px(x, y, [g, g, g]);
  }
  // fold line highlights
  for (let i = 0; i < 4; i++) T.px(9 + i * 3, 5, [200, 200, 205]);
  return T;
}
