// sky.png for arcade and frostbite: 350x320 (base 175x160). Bottom row continues background.png row 0.
import { Img, hx, rp, bay, rnd, mix, clamp } from './lib_px.mjs';

const W = 350, H = 320;
const OL = '0b0414';

// top fade: dither into the area's sky colour over the first `n` rows
function fadeTop(S, sky, n, pow = 1.25) {
  const c = hx(sky);
  for (let y = 0; y < n; y++) {
    const p = Math.pow(1 - y / n, pow);
    for (let x = 0; x < W; x++) if (bay(x, y) < p) S.px(x, y, c);
  }
}

export function arcadeSky(bg) {
  const S = new Img(W, H);
  const T = 28; // ceiling tile height taken from background rows 0..27
  for (let y = 0; y < H; y++) { const r = ((y - H) % T + T) % T; for (let x = 0; x < W; x++) { const g = bg.get(x, r); S.px(x, y, g, 255); } }
  // darker toward the top: concrete gets less lit up there (dithered towards the deep colour)
  const deep = hx('120a24');
  for (let y = 0; y < 200; y++) { const p = Math.pow(1 - y / 200, 1.6) * 0.45; for (let x = 0; x < W; x++) if (bay(x, y) < p) S.tint(x, y, deep, 0.7); }
  // beams across the whole width
  const beam = (y0, h) => {
    for (let y = y0; y < y0 + h; y++) for (let x = 0; x < W; x++) {
      const t = (y - y0) / (h - 1);
      let c;
      if (y === y0) c = '5a3a8c'; else if (y === y0 + 1) c = '3c2468';
      else if (y >= y0 + h - 2) c = '0b0414'; else if (y >= y0 + h - 5) c = rp(['0e0618', '190c2e'], (y0 + h - 2 - y) / 3, x, y, 0.5);
      else c = rp(['1e0d38', '2a1450', '36195c'], 0.75 - t * 0.9 + (rnd(x, y, 4) - 0.5) * 0.16, x, y, 0.5);
      S.px(x, y, c);
    }
    // bolt plates and rivets
    for (let x = 18; x < W; x += 76) {
      for (let y = y0 + 2; y < y0 + h - 3; y++) for (let i = 0; i < 10; i++) S.px(x + i, y, i < 1 ? '4a2e78' : i > 8 ? '120824' : (y - y0 < 4 ? '3a2470' : '2e1a56'));
      for (const yy of [y0 + 5, y0 + h - 8]) for (const xx of [x + 2, x + 7]) { S.px(xx, yy, '6a4a9c'); S.px(xx + 1, yy + 1, '0e0618'); S.px(xx + 1, yy, '4a3280'); }
    }
    // shadow under the beam onto the ceiling
    for (let i = 0; i < 5; i++) for (let x = 0; x < W; x++) if (bay(x, i) < (1 - i / 5) * 0.8) S.tint(x, y0 + h + i, '0b0414', 0.6);
  };
  beam(210, 24); beam(100, 22);
  // hanging cables (sagging) from the beams
  const cable = (x0, x1, y, sag, col, hi) => {
    let px = null;
    for (let x = x0; x <= x1; x++) {
      const u = (x - x0) / (x1 - x0), yy = Math.round(y + Math.sin(u * Math.PI) * sag);
      S.px(x, yy, OL); S.px(x, yy + 1, col); S.px(x, yy + 2, OL); if (x % 5 === 0) S.px(x, yy + 1, hi);
    }
  };
  cable(20, 120, 236, 16, '2a1a46', '4a3a78'); cable(100, 200, 236, 12, '1e1238', '3a2a60'); cable(190, 320, 236, 18, '2a1a46', '4a3a78');
  cable(0, 60, 124, 9, '1e1238', '3a2a60'); cable(240, 350, 124, 12, '2a1a46', '4a3a78');
  for (const [x, y, c] of [[70, 251, 'ff5fb0'], [158, 249, '3fd2ff'], [255, 253, 'c6ff3d'], [30, 133, 'ff5fb0'], [300, 135, '3fd2ff']]) { S.px(x, y, c); S.px(x + 1, y, c); S.px(x, y + 1, mix(hx(c), [30, 10, 50], 0.4)); S.px(x + 1, y + 1, mix(hx(c), [30, 10, 50], 0.4)); }
  // straight hanging cables and conduit
  for (const [x, y0, y1] of [[132, 234, 266], [44, 124, 148], [205, 234, 250], [290, 124, 158]]) { for (let y = y0; y < y1; y++) { S.px(x - 1, y, OL); S.px(x, y, '2e1e52'); S.px(x + 1, y, OL); } S.rect(x - 2, y1, 5, 3, '120824'); S.px(x - 1, y1, '4a3a78'); }
  // flickering tube light, hanging on two chains
  const tx0 = 120, tx1 = 232, ty = 160;
  for (const cx of [tx0 + 8, tx1 - 8]) for (let y = 122; y < ty; y++) { S.px(cx, y, y % 3 === 0 ? '6a5a98' : '2a1a46'); }
  // glow on the ceiling around the tube (dithered, calm)
  for (let y = ty - 24; y < ty + 34; y++) for (let x = tx0 - 36; x < tx1 + 36; x++) {
    const dx = Math.max(tx0 - x, x - tx1, 0), dy = Math.abs(y - (ty + 3)); const d = Math.hypot(dx, dy * 1.5);
    const p = 0.34 * Math.max(0, 1 - d / 34); if (p > 0 && bay(x, y) < p) S.tint(x, y, 'a8e8b0', 0.34);
  }
  S.rect(tx0, ty - 1, tx1 - tx0, 10, OL); S.rect(tx0 + 1, ty, tx1 - tx0 - 2, 8, '2e1a56'); S.rect(tx0 + 1, ty, tx1 - tx0 - 2, 1, '4a3280'); S.rect(tx0 + 1, ty + 7, tx1 - tx0 - 2, 1, '150a28');
  S.rect(tx0 + 3, ty + 2, tx1 - tx0 - 6, 4, OL);
  for (let x = tx0 + 4; x < tx1 - 4; x++) {
    const off = (x > tx0 + 40 && x < tx0 + 46); // flicker: one dead stretch
    const dim = x > tx0 + 70 && x < tx0 + 100; // half-lit stretch
    const c1 = off ? '2a3a3a' : dim ? '8ac8a0' : 'e8ffd8', c2 = off ? '1a2a2a' : dim ? '5a9a78' : 'a8f0b8';
    S.px(x, ty + 3, c1); S.px(x, ty + 4, c2); if (!off && (x % 7 !== 0)) S.px(x, ty + 2, dim ? '3a6a58' : '7ad0a0');
  }
  for (const x of [tx0 + 3, tx1 - 4]) { S.rect(x, ty + 1, 1, 6, '6a4a9c'); }
  // overpass edge: a lit expansion joint and lip near the top
  for (let x = 0; x < W; x++) { S.px(x, 52, '0b0414'); S.px(x, 53, '2a1450'); S.px(x, 54, '4a2e78'); if (bay(x, 55) < 0.5) S.px(x, 55, '1e0d38'); }
  fadeTop(S, '12061f', 70);
  // keep the last rows an exact match for the background tile
  return S;
}

export function frostSky(bg) {
  const S = new Img(W, H);
  const base = hx('140828'), mid = hx('1a0b3b');
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    // dark near the horizon (matches row 0), a touch lighter higher up, dithered
    const u = clamp((H - y) / 90); // 0 at bottom, 1 above
    S.px(x, y, bay(x, y) < u * 0.5 + (y > H - 8 ? 0 : 0) ? mid : base);
  }
  // bottom rows: exact copy of the background's first row band
  for (let y = H - 3; y < H; y++) for (let x = 0; x < W; x++) S.px(x, y, base);
  // aurora: faint ribbons rising to the right, plus vertical rays
  const ribbon = (y0, slope, th, cols, seed, amp) => {
    for (let x = 0; x < W; x++) {
      const yc = y0 + slope * x;
      for (let k = 0; k < cols.length; k++) {
        const ya = yc + k * th, yb = ya + th;
        for (let y = Math.floor(ya); y < yb; y++) {
          if (y < 0 || y >= H - 14) continue;
          const wob = Math.round(Math.sin(x * 0.07 + seed) * 1.4);
          const yy = y + wob; if (yy < 0 || yy >= H - 14) continue;
          if (bay(x, yy) < amp) S.px(x, yy, cols[k]);
        }
      }
    }
  };
  ribbon(176, -0.1, 11, ['2a1660', '332070'], 1.2, 0.9);
  ribbon(205, -0.1, 9, ['3a2a88', '2b4a86', '33466a'], 0.4, 0.55);
  // curtain rays above the bg ribbon at the right, fading upward
  for (let x = 130; x < W; x += 3) {
    const h = 20 + Math.floor(rnd(x, 1, 7) * 40) + (x - 130) * 0.12, top = H - 24 - h;
    for (let y = Math.floor(top); y < H - 18; y++) { const p = clamp((y - top) / h) * (0.35 + 0.4 * (x - 130) / 220); if (bay(x, y) < p * 0.55) S.px(x, y, rnd(x, 3, 7) < 0.5 ? '2a1a5a' : '34226a'); }
  }
  // stars: sparse, a few with a cross
  for (let i = 0; i < 70; i++) {
    const x = Math.floor(rnd(i, 1, 90) * W), y = Math.floor(rnd(i, 2, 90) * (H - 40)); const b = rnd(i, 3, 90);
    const c = b < 0.5 ? '7a6aa8' : b < 0.85 ? 'c9b8e8' : 'f6eeff';
    S.px(x, y, c);
    if (b > 0.92) { S.px(x - 1, y, '8a7ab8'); S.px(x + 1, y, '8a7ab8'); S.px(x, y - 1, '8a7ab8'); S.px(x, y + 1, '8a7ab8'); }
  }
  fadeTop(S, '1a0b3b', 60, 1.0);
  return S;
}
