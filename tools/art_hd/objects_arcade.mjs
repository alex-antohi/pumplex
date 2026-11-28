// Arcade Underpass: PUNCH-O-TRON object frames, bursts, marks, shadow (2x pixels).
import { Img, hx, rp, bay, rnd, mix, clamp, text, textW, sphere, tri } from './lib_px.mjs';

const OL = '0b0414';
const BODY = ['150a26', '1e0d38', '2a1148', '3a1a66', '553096', '7a56c8'];
const PINK = ['3f1048', '7e2670', 'c23f8e', 'ff5fb0', 'ff9cc8', 'ffe0ee'];
const ORNG = ['5a1a40', '9a3a3a', 'ea7a38', 'ffa033', 'ffd070', 'fff4c0'];
const STEEL = ['2a1f4a', '4a3a7a', '7d65a3', 'b9a8e0', 'efe6ff'];
const LIME = ['4f7a1c', '8fbf2a', 'c6ff3d', 'e4ff7a', 'f6ffc0'];

export function cabinet(ph) {
  const L = new Img(140, 190);
  const X0 = 58, X1 = 139, Y0 = 6, Y1 = 189;
  // plastic body base: left lit, right in violet shade, a little speckle
  for (let y = Y0; y <= Y1; y++) for (let x = X0; x <= X1; x++) {
    const t = 0.78 - (x - X0) / (X1 - X0) * 0.7 + (rnd(x, y, 3) - 0.5) * 0.12;
    L.px(x, y, rp(BODY.slice(0, 5), t * 0.62 + 0.18, x, y, 0.5));
  }
  // side trims (lit left, dark right) and inset panel
  for (let y = 43; y <= 188; y++) {
    L.px(59, y, BODY[5]); L.px(60, y, BODY[4]); L.px(61, y, BODY[4]); L.px(62, y, BODY[3]); L.px(63, y, BODY[2]);
    L.px(134, y, BODY[1]); L.px(135, y, BODY[1]); L.px(136, y, BODY[0]); L.px(137, y, BODY[0]); L.px(138, y, '120620');
  }
  for (let y = 44; y <= 187; y++) for (let x = 64; x <= 133; x++) {
    const t = 0.55 - (x - 64) / 70 * 0.28 + (rnd(x, y, 5) - 0.5) * 0.1;
    L.px(x, y, rp(BODY.slice(0, 4), t, x, y, 0.5));
  }
  L.rect(64, 43, 70, 1, OL); L.rect(64, 188, 70, 1, OL); L.rect(63, 43, 1, 146, OL); L.rect(134, 43, 1, 146, OL);
  L.rect(64, 44, 70, 1, BODY[4]); L.rect(64, 44, 1, 143, BODY[4]); L.rect(133, 45, 1, 142, BODY[0]); L.rect(65, 187, 69, 1, BODY[0]);
  // glossy vertical streak on the left trim
  for (let y = 52; y < 92; y++) L.px(65, y, BODY[5]);
  for (let y = 100; y < 124; y++) { L.px(65, y, BODY[4]); }

  // ---- sign: lilac bezel + glowing pink box + marquee bulbs
  for (let y = 7; y <= 41; y++) for (let x = 59; x <= 138; x++) {
    const lit = (y - 7) < (x - 59) / 1.0 && y < 22 && x < 100;
    L.px(x, y, (y < 11 || x < 64) ? (x < 64 && y > 10 ? STEEL[3] : STEEL[3]) : STEEL[1]);
  }
  for (let y = 7; y <= 41; y++) for (let x = 59; x <= 138; x++) {
    const top = y - 7, bot = 41 - y, lef = x - 59, rig = 138 - x; const m = Math.min(top, bot, lef, rig);
    if (m > 4) continue;
    let c;
    if (m === top && top <= 1) c = STEEL[4]; else if (m === lef && lef <= 1) c = STEEL[4];
    else if (m === bot && bot <= 1) c = STEEL[0]; else if (m === rig && rig <= 1) c = STEEL[0];
    else if (m === top || m === lef) c = STEEL[3]; else c = STEEL[2];
    L.px(x, y, c);
  }
  const flash = ph === 2 ? 0.28 : ph === 1 ? 0.1 : 0;
  for (let y = 11; y <= 37; y++) for (let x = 64; x <= 133; x++) {
    let t = 0.82 - (y - 11) / 26 * 0.7 + flash; t += (rnd(x, y, 8) - 0.5) * 0.04;
    let c = rp(PINK.slice(1, 5), t, x, y, 0.4);
    if ((y - 11) % 4 === 3) c = rp(PINK.slice(1, 5), t - 0.2, x, y, 0.4); // scanlines
    if (((x - y * 1.3) % 46 + 46) % 46 < 3 && y < 24) c = PINK[4]; // gloss streak
    L.px(x, y, c);
  }
  L.rect(63, 10, 72, 1, OL); L.rect(63, 38, 72, 1, OL); L.rect(63, 10, 1, 29, OL); L.rect(134, 10, 1, 29, OL);
  // inner shadow under the top lip
  for (let x = 64; x <= 133; x++) { L.px(x, 11, PINK[1]); }
  // text
  const ink = '2c0b3c', hl = 'ffd0e6';
  text(L, 'PUNCH', 71, 15, 2, hl); text(L, 'PUNCH', 70, 14, 2, ink);
  const t2 = 'O-TRON', tx = Math.round(99 - textW(t2, 1) / 2);
  text(L, t2, tx + 1, 30, 1, hl); text(L, t2, tx, 29, 1, ink);
  for (const sx of [70, 126]) { L.rect(sx, 31, 3, 1, LIME[2]); L.rect(sx + 1, 30, 1, 3, LIME[2]); }
  // bulbs
  const bulb = (x, y, on) => {
    if (on) { L.rect(x, y, 2, 2, '9a5a10'); L.px(x, y, 'fff0a0'); L.px(x + 1, y, 'ffd060'); L.px(x, y + 1, 'ffd060'); }
    else { L.rect(x, y, 2, 2, '4a2a6a'); L.px(x, y, '6a4a8a'); }
  };
  let k = 0;
  const on = i => ph === 2 ? true : ((i + ph) % 2 === 0);
  for (let x = 63; x <= 134; x += 6, k++) bulb(x, 8, on(k));
  for (let x = 63; x <= 134; x += 6, k++) bulb(x, 39, on(k));
  for (let y = 14; y <= 36; y += 6, k++) { bulb(60, y, on(k)); bulb(136, y, on(k + 1)); }
  // screws in the sign corners
  const screw = (x, y) => { L.rect(x, y, 3, 3, STEEL[2]); L.px(x, y, STEEL[4]); L.px(x + 2, y + 2, STEEL[0]); L.px(x + 1, y + 1, '241a40'); L.px(x + 2, y, STEEL[1]); };

  // ---- LED window frame (the dark interior x 70..129, y 52..89 is untouched and plain)
  for (let y = 48; y <= 93; y++) for (let x = 66; x <= 133; x++) {
    if (x >= 70 && x <= 129 && y >= 52 && y <= 89) { L.px(x, y, OL); continue; }
    const dt = y - 48, db = 93 - y, dl = x - 66, dr = 133 - x; const m = Math.min(dt, db, dl, dr);
    const tl = (dt === m || dl === m) && !(db === m || dr === m) ? 1 : (db === m || dr === m) && !(dt === m || dl === m) ? 2 : (dt + dl < db + dr ? 1 : 2);
    let c;
    if (tl === 1) c = ['e4ff7a', 'c6ff3d', 'c6ff3d', '8fbf2a'][m]; else c = ['5f8a22', '8fbf2a', 'c6ff3d', 'e4ff7a'][m];
    if (m === 1 && rnd(x, y, 12) < 0.12) c = 'dcff5a';
    L.px(x, y, c);
  }
  // outline around the frame + glow bleeding onto the plastic
  for (let y = 47; y <= 94; y++) for (let x = 65; x <= 134; x++) if (x === 65 || x === 134 || y === 47 || y === 94) L.px(x, y, OL);
  const gl = ph === 2 ? 1.9 : ph === 1 ? 1.25 : 1;
  for (let y = 40; y <= 102; y++) for (let x = 56; x <= 142; x++) {
    const dx = Math.max(65 - x, x - 134, 0), dy = Math.max(47 - y, y - 94, 0), d = Math.max(dx, dy); if (d < 1 || d > 5) continue;
    if (y < 44 || x < 60 || x > 137) continue;
    const p = [0, 0.3, 0.14, 0.06, 0.02, 0][d] * gl; if (bay(x, y) < p) L.tint(x, y, 'c6ff3d', 0.4);
  }
  screw(61, 50); screw(61, 89); screw(135, 50); screw(135, 89);
  // sticker wear / scratches near the window
  L.line(104, 96, 109, 99, BODY[4], 255);

  // ---- speaker grille + gauge
  L.rect(70, 100, 30, 12, OL); L.rect(71, 101, 28, 10, BODY[0]);
  for (let j = 0; j < 5; j++) { L.rect(72, 102 + j * 2, 26, 1, '07020e'); L.rect(72, 103 + j * 2, 26, 1, BODY[2]); }
  L.rect(70, 112, 30, 1, BODY[4]); L.rect(99, 100, 1, 12, BODY[4]);
  L.rect(104, 98, 28, 14, OL); L.rect(105, 99, 26, 12, STEEL[1]); L.rect(105, 99, 26, 1, STEEL[2]); L.rect(105, 110, 26, 1, STEEL[0]);
  L.rect(106, 101, 24, 8, BODY[0]);
  const lit = [2, 4, 6][ph]; const pc = [LIME[2], LIME[2], LIME[2], ORNG[3], ORNG[3], 'ff3d6b'];
  for (let i = 0; i < 6; i++) {
    const x = 107 + i * 4, c = i < lit ? pc[i] : '2a1a4a';
    L.rect(x, 102, 3, 6, c); if (i < lit) { L.rect(x, 102, 3, 1, mix(hx(c), [255, 255, 255], 0.45)); L.rect(x, 107, 3, 1, mix(hx(c), [60, 10, 70], 0.4)); }
  }
  screw(106, 113 - 1 + 0);
  // stickers (worn)
  const sticker = (x, y, w, h, c0, c1, peel) => {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      if ((i === 0 || i === w - 1) && (j === 0 || j === h - 1)) continue;
      let c = rp([c1, c0], 1 - j / h, x + i, y + j, 0.4);
      if (rnd(x + i, y + j, 21) < 0.06) c = BODY[3];
      L.px(x + i, y + j, c);
    }
    L.rect(x + 1, y, w - 2, 1, '#'.length ? 'ffe8f4' : 'ffffff'); // glossy top edge
    if (peel) { for (let i = 0; i < 4; i++) for (let j = 0; j < 4 - i; j++) L.px(x + w - 1 - j, y + i, i + j < 3 ? 'ffd0e6' : BODY[2]); L.px(x + w - 1, y, BODY[2]); L.px(x + w - 2, y, BODY[2]); L.px(x + w - 1, y + 1, BODY[2]); L.line(x + w - 4, y + 3, x + w - 1, y, '8a3a7a'); }
  };
  sticker(112, 115, 18, 12, 'ff5fb0', 'a23a84', true);
  const star = ['...1...', '...1...', '1111111', '.11111.', '..111..', '.11.11.', '.1...1.'];
  star.forEach((r, j) => [...r].forEach((c, i) => { if (c === '1') L.px(116 + i + 1, 117 + j, LIME[2]); }));
  L.px(120, 119, LIME[4]);
  // second sticker: cyan with a bolt
  sticker(70, 116, 14, 10, '3fd2ff', '2a7ac0', false);
  [[75, 117], [76, 118], [77, 119], [76, 120], [77, 121], [78, 122], [79, 120], [78, 119]].forEach(([x, y]) => L.px(x, y, '1b0f3a'));

  // ---- big glowing button (centre 98,138) + small buttons
  const glowRing = (cx, cy, r0, r1, col, p) => {
    for (let y = cy - r1; y <= cy + r1; y++) for (let x = cx - r1; x <= cx + r1; x++) {
      const d = Math.hypot(x - cx, y - cy); if (d < r0 || d > r1) continue;
      const q = p * (1 - (d - r0) / (r1 - r0)); if (bay(x, y) < q) L.tint(x, y, col, 0.5);
    }
  };
  glowRing(98, 138, 12, 20, 'ffa033', [0.5, 0.7, 0.95][ph]);
  L.rect(86, 126, 24, 24, BODY[0]);
  for (let y = 124; y < 153; y++) for (let x = 84; x < 113; x++) { const d = Math.hypot(x - 97.5, y - 138); if (d <= 13.5) L.px(x, y, d > 12.3 ? OL : rp(STEEL, 0.9 - ((x - 84) + (y - 124)) / 40, x, y, 0.5)); }
  for (let y = 124; y < 153; y++) for (let x = 84; x < 113; x++) { const d = Math.hypot(x - 97.5, y - 138); if (d > 10.4 && d <= 12.3 && !L.has(x, y)) L.px(x, y, STEEL[1]); }
  for (let y = 124; y < 153; y++) for (let x = 84; x < 113; x++) { const d = Math.hypot(x - 97.5, y - 138); if (d > 9.6 && d <= 10.4) L.px(x, y, '1a0830'); }
  sphere(L, 97.5, 138 + (ph ? 1 : 0), 9.6, 9.6, ORNG, { bias: [0, 0.12, 0.3][ph], rim: 0.6 });
  const small = (cx, cy, base) => {
    glowRing(cx, cy, 4, 9, base[2], [0.3, 0.5, 0.8][ph]);
    for (let y = cy - 5; y <= cy + 5; y++) for (let x = cx - 5; x <= cx + 5; x++) { const d = Math.hypot(x - cx + 0.5, y - cy + 0.5); if (d <= 5.2) L.px(x, y, d > 4.2 ? OL : STEEL[1]); }
    sphere(L, cx, cy, 3.6, 3.6, base, { bias: [0, 0.05, 0.2][ph], rim: 0.4 });
  };
  small(75, 138, ['1a4a1c', '4a9a2a', 'c6ff3d', 'e4ff7a', 'f6ffc0']);
  small(121, 138, ['1a2a6a', '2a6ab0', '3fd2ff', '9af0ff', 'e8ffff']);

  // ---- chevrons above the slot (blink) + coin slot
  for (let i = 0; i < 3; i++) {
    const x = 92 + i * 8, litc = ph === 2 ? true : (i === ph);
    const c = litc ? LIME[2] : '2e1a52';
    for (let j = 0; j < 3; j++) { L.px(x + j, 157 + j, c); L.px(x + 6 - j, 157 + j, c); }
    if (litc) { L.px(x + 3, 160, LIME[3]); }
  }
  L.rect(78, 163, 44, 11, OL); L.rect(79, 164, 42, 9, STEEL[2]);
  L.rect(79, 164, 42, 1, STEEL[4]); L.rect(79, 165, 42, 1, STEEL[3]); L.rect(79, 172, 42, 1, STEEL[0]); L.rect(79, 171, 42, 1, STEEL[1]);
  L.rect(86, 166, 28, 4, OL); L.rect(87, 170, 26, 1, STEEL[4]);
  L.rect(95, 167, 10, 2, '1c0a2e'); // slit depth
  screw(80, 166 - 1); screw(118, 166 - 1);
  for (const [x, y] of [[81, 168], [117, 168]]) { /* rivet hole */ }
  L.px(86, 166, '3a2a5a');

  // ---- hazard kick plate
  for (let y = 177; y <= 186; y++) for (let x = 65; x <= 132; x++) {
    const st = (((x + y) % 12) + 12) % 12 < 6;
    let c = st ? rp(LIME.slice(0, 4), 0.62 - (y - 177) / 24 - (x - 65) / 200, x, y, 0.4) : rp(['0f0820', '1e0d38'], 0.4 + rnd(x, y, 4) * 0.2, x, y);
    if (st && rnd(x, y, 9) < 0.07) c = '1e0d38'; // chipped paint
    L.px(x, y, c);
  }
  L.rect(65, 177, 68, 1, OL); L.rect(65, 186, 68, 1, OL); L.rect(65, 177, 1, 10, OL); L.rect(132, 177, 1, 10, OL);
  screw(66, 179); screw(128, 179);
  // scuffs and scratches
  const sc = (x0, y0, x1, y1) => { L.line(x0, y0, x1, y1, BODY[4]); L.px(x1 + 1, y1, BODY[5]); };
  sc(72, 160, 76, 154); sc(125, 98, 128, 94); sc(108, 172, 113, 168); sc(68, 168, 70, 163);
  for (let i = 0; i < 40; i++) { const x = 65 + Math.floor(rnd(i, 1, 30) * 68), y = 150 + Math.floor(rnd(i, 2, 30) * 26); if (L.has(x, y) && L.get(x, y)[0] < 70 && y < 176) L.px(x, y, BODY[3]); }
  // cabinet outline
  for (let x = X0; x <= X1; x++) { L.px(x, Y0, OL); L.px(x, Y1, OL); }
  for (let y = Y0; y <= Y1; y++) { L.px(X0, y, OL); L.px(X1, y, OL); }
  for (let x = 60; x <= 137; x++) L.px(x, 42, OL), L.px(x, 6, OL);
  L.rect(59, 42, 80, 1, OL);
  L.px(X0, Y0, [0, 0, 0], 0); L.px(X1, Y0, [0, 0, 0], 0); L.px(X0 + 1, Y0, OL); L.px(X1 - 1, Y0, OL);
  // top highlight
  for (let x = 60; x <= 136; x++) L.px(x, 7, STEEL[4]);
  return L;
}

export function padLayer(ph) {
  const P = new Img(140, 190), A = new Img(140, 190);
  const G = [{ cx: 23, rx: 21.5, ry: 24 }, { cx: 30, rx: 20.5, ry: 24 }, { cx: 47, rx: 14, ry: 21 }][ph];
  const cy = 113;
  // piston arm (steel) from the pad to the cabinet
  const ax1 = 57;
  const ax0 = Math.round(G.cx);
  // outer sleeve at the cabinet
  A.rect(46, 104, 12, 19, STEEL[2]);
  for (let j = 0; j < 19; j++) for (let i = 0; i < 12; i++) A.px(46 + i, 104 + j, rp(STEEL, 0.95 - j / 18 * 0.95 + (i < 2 ? 0.05 : 0), 46 + i, 104 + j, 0.5));
  for (let j = 0; j < 19; j++) { A.px(51, 104 + j, STEEL[0]); A.px(52, 104 + j, STEEL[1]); }
  A.outline(OL);
  // rod
  const rod = new Img(140, 190);
  for (let x = ax0; x <= 47; x++) for (let j = 0; j < 9; j++) { const t = 1 - j / 8; rod.px(x, 109 + j, rp(STEEL, t * 0.95 + 0.05, x, 109 + j, 0.4)); }
  rod.outline(OL);
  const ang = new Img(140, 190); ang.over(rod); ang.over(A);
  // collar flange hugging the cabinet
  const C = new Img(140, 190);
  for (let j = 0; j < 27; j++) for (let i = 0; i < 4; i++) C.px(54 + i, 100 + j, rp(STEEL, 0.95 - j / 26 - 0.0, 54 + i, 100 + j, 0.5));
  C.outline(OL);
  ang.over(C);
  // pad
  sphere(P, G.cx, cy, G.rx, G.ry, PINK, { bias: ph === 2 ? -0.05 : 0, rim: 0.7 });
  // seams: two horizontal arcs + a vertical one (padded sections)
  const seam = new Img(140, 190);
  for (let x = Math.floor(G.cx - G.rx); x <= Math.ceil(G.cx + G.rx); x++) {
    const u = (x + 0.5 - G.cx) / G.rx; if (Math.abs(u) >= 0.97) continue;
    for (const s of [-0.46, 0.46]) { const y = Math.round(cy + G.ry * s * Math.sqrt(1 - u * u) + (s > 0 ? 0 : 0)); if (P.has(x, y)) { P.px(x, y, PINK[0]); if (P.has(x, y + 1)) P.px(x, y + 1, PINK[1]); if (x % 4 === 0 && P.has(x, y - 1)) P.px(x, y - 1, PINK[4]); } }
  }
  for (let y = Math.floor(cy - G.ry); y <= Math.ceil(cy + G.ry); y++) {
    const v = (y + 0.5 - cy) / G.ry; if (Math.abs(v) >= 0.97) continue; const x = Math.round(G.cx - G.rx * 0.08 * v * 0 + 0 + (ph ? 2 : 0));
    const xx = Math.round(G.cx + 0.0); if (P.has(xx, y)) { P.px(xx, y, PINK[0]); if (P.has(xx + 1, y)) P.px(xx + 1, y, PINK[1]); if (y % 4 === 0 && P.has(xx - 1, y)) P.px(xx - 1, y, PINK[4]); }
  }
  // scuffs and wear
  for (let i = 0; i < 26; i++) {
    const x = Math.round(G.cx - G.rx * 0.5 + rnd(i, 3, 41) * G.rx * 1.2), y = Math.round(cy - G.ry * 0.7 + rnd(i, 4, 41) * G.ry * 1.4);
    if (P.has(x, y) && P.get(x, y)[0] > 150) { P.px(x, y, rnd(i, 5, 41) < 0.5 ? PINK[4] : PINK[2]); if (rnd(i, 6, 41) < 0.4) P.px(x + 1, y, PINK[4]); }
  }
  // dent from the punch
  if (ph >= 1) {
    const dr = ph === 1 ? 0.28 : 0.4;
    for (let y = 0; y < 190; y++) for (let x = 0; x < 140; x++) {
      if (!P.has(x, y)) continue; const u = (x + 0.5 - (G.cx - 3)) / G.rx, v = (y + 0.5 - cy) / G.ry; const d = Math.hypot(u, v);
      if (d < dr && d > dr - 0.09 && bay(x, y) < 0.7) P.px(x, y, PINK[1]);
      else if (d < dr - 0.09 && (x + y) % 2 === 0 && ph === 2) P.px(x, y, PINK[2]);
    }
  }
  P.outline(OL);
  // reflected light on the lower-right inside rim
  for (let y = 0; y < 190; y++) for (let x = 0; x < 140; x++) { if (P.has(x, y) && P.has(x - 1, y - 1) && !P.has(x + 1, y + 1) && x > G.cx && y > cy + G.ry * 0.3 && P.get(x, y)[0] !== 11) { if (P.get(x - 1, y - 1)[0] !== 11) P.px(x - 1, y - 1, PINK[2]); } }
  const out = new Img(140, 190); out.over(ang); out.over(P);
  return out;
}

export function arcadeObject(ph) {
  const o = new Img(140, 190);
  o.over(padLayer(ph));
  o.over(cabinet(ph));
  if (ph === 2) {
    // impact: radial yellow-white lines and sparks around the pad, drawn over the cabinet edge
    const cx = 40, cy = 113;
    for (let a = 0; a < 12; a++) {
      const an = a / 12 * Math.PI * 2 + 0.2, r0 = 27 + (a % 2) * 3, r1 = r0 + 7 + (a % 3) * 3;
      const x0 = cx + Math.cos(an) * r0 * 0.9, y0 = cy + Math.sin(an) * r0 * 1.02, x1 = cx + Math.cos(an) * r1 * 0.9, y1 = cy + Math.sin(an) * r1 * 1.02;
      if (x0 > 56 || x1 > 56 || x1 < 0) continue;
      o.line(x0, y0, x1, y1, a % 2 ? 'fff4c0' : 'ffd070');
    }
    [[6, 86], [3, 140], [26, 82], [30, 146], [14, 78], [14, 150]].forEach(([x, y], i) => { o.rect(x, y, 2, 2, i % 2 ? 'ffd070' : 'fff4c0'); o.px(x - 1, y, 'ffa033'); });
  }
  // old light-grey LED ghost "88" is not drawn: the window interior stays plain
  return o;
}

// ---- burst: 7-point faceted star, 100x100
function burst(frame, pal) {
  const B = new Img(100, 100);
  const R = [10, 26, 42, 50, 50][frame], rot = [-0.1, -0.15, -0.05, -0.12, 0.02][frame];
  const cx = 50, cy = 50, N = 7, ri = frame === 0 ? 0.5 : frame === 4 ? 0.54 : 0.5;
  const pts = []; for (let i = 0; i < N * 2; i++) { const a = rot - Math.PI / 2 + i * Math.PI / N, r = (i % 2 ? R * ri : R) * (frame === 3 ? 0.99 : 1); pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r * 0.98]); }
  const lightA = Math.atan2(-1, -1);
  const draw = (img, offx, offy, shaded) => {
    for (let i = 0; i < N * 2; i++) {
      const a = pts[i], b = pts[(i + 1) % (N * 2)];
      // two triangles per sector: centre-a-b
      tri(cx + offx, cy + offy, a[0] + offx, a[1] + offy, b[0] + offx, b[1] + offy, (x, y) => {
        if (!shaded) { img.px(x, y, '201216'); return; }
        const fa = Math.atan2((a[1] + b[1]) / 2 - cy, (a[0] + b[0]) / 2 - cx); let d = Math.cos(fa - lightA);
        const rr = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
        let c;
        if (rr < R * ri * 0.92) c = pal[2];
        else c = d > 0.72 ? pal[3] : d > 0.2 ? pal[2] : d > -0.45 ? pal[1] : pal[0];
        
        img.px(x, y, c);
      });
    }
  };
  draw(B, 2, 2, false);
  const S = new Img(100, 100); draw(S, 0, 0, true);
  // lighter rim on upper-left edges
  const edge = new Img(100, 100); edge.d.set(S.d);
  for (let y = 1; y < 99; y++) for (let x = 1; x < 99; x++) if (S.has(x, y) && (!S.has(x - 1, y) || !S.has(x, y - 1)) && S.has(x + 1, y + 1)) edge.px(x, y, pal[4]);
  edge.outline(OL);
  B.over(edge);
  // crisp second outline on the shadow side
  return B;
}
export const arcadeBurst = f => burst(f, ['4c8a3a', '8fcb2e', 'c6ff3d', 'e8ff8a', 'f8ffd0']);
export const frostBurst = f => burst(f, ['3a3aa8', '3992eb', '3fd2ff', '8aeaff', 'dffaff']);

// ---- marks and shadows
export function arcadeMark() {
  const M = new Img(12, 10);
  for (let y = 0; y < 10; y++) for (let x = 0; x < 12; x++) {
    const notch = (y === 0 || y === 9) && false;
    if ((x === 0 || x === 11) && (y === 0 || y === 9)) continue;
    const c = rp(['c45a2c', 'ea8e38', 'ffa033', 'ffc075', 'ffe6a8'], 0.9 - y / 9 * 0.95 + (x < 3 ? 0.04 : 0), x, y, 0.4);
    M.px(x, y, c);
  }
  M.rect(1, 1, 10, 1, 'ffe6a8'); // top highlight
  M.rect(1, 8, 10, 1, 'c45a2c');
  // perforation line and printed stripe
  for (let y = 2; y < 8; y += 2) { M.px(3, y, OL); M.px(8, y, OL); }
  M.rect(4, 4, 4, 2, 'ea8e38'); M.px(5, 4, 'c45a2c'); M.px(6, 5, 'c45a2c');
  M.px(4, 3, 'ffe6a8');
  M.outline(OL);
  // notches in the left and right edge
  M.px(0, 4, [0, 0, 0], 0); M.px(0, 5, [0, 0, 0], 0); M.px(11, 4, [0, 0, 0], 0); M.px(11, 5, [0, 0, 0], 0);
  M.px(1, 4, OL); M.px(1, 5, OL); M.px(10, 4, OL); M.px(10, 5, OL);
  return M;
}

export function shadow(col) {
  const S = new Img(92, 10);
  for (let y = 0; y < 10; y++) for (let x = 0; x < 92; x++) {
    const u = (x + 0.5 - 46) / 46, v = (y + 0.5 - 5) / 5, d = Math.sqrt(u * u + v * v); if (d > 1) continue;
    let a = d < 0.5 ? 150 : d < 0.78 ? 108 : 66;
    const e = d > 0.9 ? 0.5 : d > 0.7 ? 0.35 : d > 0.45 ? 0.3 : 0; // dither at ring borders
    const edge = [0.5, 0.78, 1]; for (const b of edge.slice(0, 2)) if (Math.abs(d - b) < 0.05 && bay(x, y) < 0.5) a = a === 150 ? 108 : a === 108 ? 66 : a;
    if (d > 0.93 && bay(x, y) < 0.5) a = 34;
    S.px(x, y, col, a);
  }
  return S;
}
