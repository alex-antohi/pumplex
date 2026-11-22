// PUMPLEX pixel icon set (design handoff item 3).
//
// One source of truth: every icon is drawn here on a 24x24 pixel grid, then written as
//   docs/moodboard/icons/svg/<id>.svg           one-colour SVG (fill="currentColor"), crisp pixel runs
//   docs/moodboard/icons/png/<id>.png           24x24 white on transparent, for Flutter (tint with Image.asset color:)
//   docs/moodboard/icons/png/2.0x|3.0x/<id>.png nearest-neighbour 48/72 px, Flutter's resolution-aware asset folders
//   docs/moodboard/icons/icons.json             index: id, group, use, the emoji or glyph it replaces
//   docs/moodboard/icons/sheet.png              contact sheet for review (3x, in index order)
// and the demo's icon table in docs/demo/shared/demo.js (between ICONS:BEGIN and ICONS:END).
//
// Run: node tools/moodboard/icons.mjs
// Ids never change once shipped. Add new icons at the end of a group.

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const OUT = path.join(ROOT, 'docs', 'moodboard', 'icons');
const DEMO = path.join(ROOT, 'docs', 'demo', 'shared', 'demo.js');
const N = 24;

/* ---------------- drawing helpers: a 24x24 grid, sampled at pixel centres ---------------- */
function canvas() {
  const g = Array.from({ length: N }, () => new Array(N).fill(0));
  const each = (f) => { for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) f(x, y, x + 0.5, y + 0.5); };
  const api = {
    rect(x, y, w, h) { each((px, py, cx, cy) => { if (cx > x && cx < x + w && cy > y && cy < y + h) g[py][px] = 1; }); return api; },
    clear(x, y, w, h) { each((px, py, cx, cy) => { if (cx > x && cx < x + w && cy > y && cy < y + h) g[py][px] = 0; }); return api; },
    /* SVG path subset (M L H V Z, absolute and relative, implicit line-tos), nonzero or evenodd fill */
    path(d, evenodd = false, erase = false) {
      const polys = parsePath(d);
      each((px, py, cx, cy) => {
        let wind = 0, cross = 0;
        for (const p of polys) for (let i = 0; i < p.length; i++) {
          const [x1, y1] = p[i], [x2, y2] = p[(i + 1) % p.length];
          if ((y1 <= cy) !== (y2 <= cy)) {
            const xi = x1 + (cy - y1) * (x2 - x1) / (y2 - y1);
            if (xi > cx) { cross++; wind += y2 > y1 ? 1 : -1; }
          }
        }
        if (evenodd ? cross % 2 : wind !== 0) g[py][px] = erase ? 0 : 1;
      });
      return api;
    },
    /* a polyline with width w and square caps */
    stroke(pts, w, erase = false) {
      each((px, py, cx, cy) => {
        for (let i = 0; i < pts.length - 1; i++) {
          const [x1, y1] = pts[i], [x2, y2] = pts[i + 1], dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy);
          const ux = dx / L, uy = dy / L, ax = cx - x1, ay = cy - y1;
          const along = ax * ux + ay * uy, perp = Math.abs(-ax * uy + ay * ux);
          if (along >= -w / 2 && along <= L + w / 2 && perp <= w / 2) { g[py][px] = erase ? 0 : 1; break; }
        }
      });
      return api;
    },
    /* ring of radius r and width w; skip = [fromDeg, toDeg] gap (screen angles, 0 = right, 90 = down) */
    ring(cx0, cy0, r, w, skip, erase = false) {
      each((px, py, cx, cy) => {
        const dist = Math.hypot(cx - cx0, cy - cy0);
        if (Math.abs(dist - r) > w / 2) return;
        if (skip) { let a = Math.atan2(cy - cy0, cx - cx0) * 180 / Math.PI; if (a < 0) a += 360; if (a > skip[0] && a < skip[1]) return; }
        g[py][px] = erase ? 0 : 1;
      });
      return api;
    },
    disk(cx0, cy0, r, erase = false) { each((px, py, cx, cy) => { if (Math.hypot(cx - cx0, cy - cy0) <= r) g[py][px] = erase ? 0 : 1; }); return api; },
    star(cx0, cy0, rOut, rIn, n, rot = -90) {
      const pts = [];
      for (let i = 0; i < n * 2; i++) { const r = i % 2 ? rIn : rOut, a = (rot + i * 180 / n) * Math.PI / 180; pts.push([cx0 + r * Math.cos(a), cy0 + r * Math.sin(a)]); }
      return api.path('M' + pts.map((p) => p.join(' ')).join('L') + 'Z');
    },
    mirror() { for (const row of g) row.reverse(); return api; },
    grid: g
  };
  return api;
}

function parsePath(d) {
  const tok = d.match(/[MmLlHhVvZz]|-?(?:\d+\.?\d*|\.\d+)/g) || [];
  const polys = []; let cur = null, x = 0, y = 0, cmd = 'M', i = 0, sx = 0, sy = 0;
  const num = () => parseFloat(tok[i++]);
  while (i < tok.length) {
    if (/[A-Za-z]/.test(tok[i])) cmd = tok[i++];
    switch (cmd) {
      case 'M': x = num(); y = num(); cur = [[x, y]]; polys.push(cur); sx = x; sy = y; cmd = 'L'; break;
      case 'm': x += num(); y += num(); cur = [[x, y]]; polys.push(cur); sx = x; sy = y; cmd = 'l'; break;
      case 'L': x = num(); y = num(); cur.push([x, y]); break;
      case 'l': x += num(); y += num(); cur.push([x, y]); break;
      case 'H': x = num(); cur.push([x, y]); break;
      case 'h': x += num(); cur.push([x, y]); break;
      case 'V': y = num(); cur.push([x, y]); break;
      case 'v': y += num(); cur.push([x, y]); break;
      case 'Z': case 'z': x = sx; y = sy; break;
      default: throw new Error('path command ' + cmd);
    }
  }
  return polys;
}

/* ---------------- the icons ---------------- */
// group: ui | profile | milestone | menu | class | area | object | mark | slot
// replaces: the emoji or glyph the app or demo shows today (handoff: "no emojis")
const ICONS = [
  /* UI (demo PX.icon set, same art, now on the pixel grid) */
  { id: 'back', group: 'ui', use: 'Back, ◀ HUB, ◀ BACK', replaces: '◀', draw: (c) => c.stroke([[15, 4], [7, 12], [15, 20]], 3) },
  { id: 'next', group: 'ui', use: 'NEXT ▶, CHANGE ▸, HUB ▶', replaces: '▶ ▸', draw: (c) => c.stroke([[9, 4], [17, 12], [9, 20]], 3) },
  { id: 'menu', group: 'ui', use: 'Open the menu', replaces: '', draw: (c) => c.rect(10, 3, 4, 4).rect(10, 10, 4, 4).rect(10, 17, 4, 4) },
  { id: 'close', group: 'ui', use: 'Close, ✕ remove', replaces: '✕', draw: (c) => c.stroke([[5, 5], [19, 19]], 3).stroke([[19, 5], [5, 19]], 3) },
  { id: 'play', group: 'ui', use: 'TRAIN', replaces: '▶', draw: (c) => c.path('M6 3h3v2h3v2h3v2h3v2h1v2h-1v2h-3v2h-3v2H9v2H6z') },
  { id: 'history', group: 'ui', use: 'Past sessions', replaces: '', draw: (c) => c.ring(12, 12, 8, 3, [180, 226]).stroke([[4, 4], [4, 8], [8, 8]], 3).stroke([[12, 8], [12, 13], [15, 15]], 3) },
  { id: 'user', group: 'ui', use: 'Profile, ★ ME', replaces: '★', draw: (c) => c.rect(8, 3, 8, 8).rect(4, 14, 16, 7) },
  { id: 'check', group: 'ui', use: 'Done, equipped, SAVE ✔', replaces: '✔', draw: (c) => c.stroke([[4, 12], [9, 17], [20, 6]], 3.5) },
  { id: 'bolt', group: 'ui', use: 'XP, overkill', replaces: '', draw: (c) => c.path('M13 2 4 14h6l-1 8 9-12h-6z') },
  { id: 'save', group: 'ui', use: 'Backup', replaces: '', draw: (c) => c.path('M4 3h13l3 3v15H4zm4 2v5h8V5zm0 9v5h8v-5z', true) },
  { id: 'restore', group: 'ui', use: 'Restore backup', replaces: '', draw: (c) => c.stroke([[12, 20], [12, 8]], 3).stroke([[7, 13], [12, 8], [17, 13]], 3).stroke([[4, 4], [20, 4]], 3) },
  { id: 'flame', group: 'ui', use: 'Streak, last session', replaces: '🔥', draw: (c) => c.path('M11 2h2v3h2v3h2v4h1v6h-2v2h-2v2H10v-2H8v-2H6v-6h2V9h2V6h1z') },
  { id: 'gem', group: 'ui', use: 'Difficulty XP gem', replaces: '◆', draw: (c) => c.path('M7 3h10l5 6-10 12L2 9z') },
  { id: 'star', group: 'ui', use: 'Mastery star, open milestone', replaces: '★', draw: (c) => c.path('M10 2h4v6h8v4h-3v3h2v7h-4v-3h-2v-2h-2v2H9v3H5v-7h2v-3H4V8h6z') },
  { id: 'ember', group: 'ui', use: 'Streak ember', replaces: '', draw: (c) => c.path('M11 3h2v2h2v2h2v4h2v6h-2v2h-2v2H9v-2H7v-2H5v-6h2V9h2V5h2z').clear(11, 13, 2, 4) },
  { id: 'swap', group: 'ui', use: 'Swap exercise, change path', replaces: '⇅', draw: (c) => c.path('M4 7h11V4h2v2h2v2h2v2h-2v2h-2v2h-2v-3H4zM20 17H9v3H7v-2H5v-2H3v-2h2v-2h2v-2h2v3h11z') },
  { id: 'plus', group: 'ui', use: '+ ADD EXERCISE', replaces: '+', draw: (c) => c.path('M10 3h4v7h7v4h-7v7h-4v-7H3v-4h7z') },
  { id: 'skip', group: 'ui', use: 'Skip exercise', replaces: '', draw: (c) => c.path('M3 4h3v2h2v2h2v2h2v4h-2v2H8v2H6v2H3zM12 4h3v2h2v2h2v2h2v4h-2v2h-2v2h-2v2h-3z') },
  { id: 'trash', group: 'ui', use: 'Remove', replaces: '', draw: (c) => c.path('M9 2h6v2h6v3H3V4h6zM5 8h14v14H5zm4 3v8h2v-8zm4 0v8h2v-8z', true) },
  { id: 'undo', group: 'ui', use: '↺ back to the first exercise, take a set back', replaces: '↺', draw: (c) => c.path('M8 3h2v4h6v2h2v2h2v8h-3v-7h-1V9h-6v4H8v-2H6V9H4V7h2V5h2z') },
  { id: 'edit', group: 'ui', use: '✎ BODY, edit a choice', replaces: '✎', draw: (c) => c.stroke([[8, 16], [15, 9]], 5).path('M2 22l2-7 5 5z').stroke([[18, 6], [19, 5]], 5).stroke([[15.6, 8.4], [17.4, 6.6]], 1, true) },
  { id: 'gear', group: 'ui', use: '⚔ GEAR', replaces: '⚔', draw: (c) => c.path('M2 2h4l11 11-4 4L2 6zM22 2h-4L7 13l4 4L22 6z').stroke([[12, 19], [19, 12]], 3).stroke([[5, 12], [12, 19]], 3).stroke([[18, 18], [21, 21]], 3).stroke([[6, 18], [3, 21]], 3) },
  { id: 'arm', group: 'ui', use: 'Flex, strength', replaces: '💪', draw: (c) => c.path('M3 21V13h3v-3h2V7h2V4h5v3h-2v2h-1v4h2v-2h4v2h2v4h-2v2h-3v2h-3v2z') },
  { id: 'dice', group: 'ui', use: 'Random body', replaces: '🎲', draw: (c) => c.rect(2, 2, 20, 20).clear(5, 5, 4, 4).clear(10, 10, 4, 4).clear(15, 15, 4, 4) },
  { id: 'male', group: 'ui', use: 'Body type: male', replaces: '♂', draw: (c) => c.ring(10, 14, 5.5, 3).stroke([[13.5, 10.5], [18, 6]], 3).path('M13 3h8v8h-3V6h-5z') },
  { id: 'female', group: 'ui', use: 'Body type: female', replaces: '♀', draw: (c) => c.ring(12, 8.5, 5.5, 3).rect(10.5, 14, 3, 9).rect(7, 17, 10, 3) },

  /* profile and menu */
  { id: 'body', group: 'profile', use: 'Rebuild body', replaces: '', draw: (c) => c.rect(9, 2, 6, 6).path('M3 9h18v3h-5v10h-3v-6h-2v6H8V12H3z') },
  { id: 'lock', group: 'milestone', use: 'Locked milestone or gear', replaces: '🔒', draw: (c) => c.path('M8 3h8v2h2v5h2v12H4V10h2V5h2zm1 3v4h6V6zm2 7v5h2v-5z', true) },
  { id: 'sound', group: 'menu', use: 'SOUND toggle', replaces: '', draw: (c) => c.path('M3 9h4l5-5h2v16h-2l-5-5H3z').rect(16, 9, 2, 6).rect(19, 6, 2, 12) },
  { id: 'chaos', group: 'menu', use: 'Chaos mode', replaces: '', draw: (c) => c.star(12, 12, 11, 5, 8).disk(12, 12, 2.5, true) },
  { id: 'cel', group: 'menu', use: 'Cel shader', replaces: '', draw: (c) => { c.ring(12, 12, 8.5, 3); c.path('M12 4.5V19.5H11V4.5z'); for (let y = 0; y < N; y++) for (let x = 0; x < 12; x++) if (Math.hypot(x + .5 - 12, y + .5 - 12) < 8) c.grid[y][x] = 1; } },

  /* milestones (11-profile) */
  { id: 'drop', group: 'milestone', use: 'First blood', replaces: '', draw: (c) => c.path('M11 2h2v3h2v3h2v3h2v7h-2v2h-2v2H9v-2H7v-2H5v-7h2V8h2V5h2z') },
  { id: 'fire', group: 'milestone', use: 'On a roll', replaces: '🔥', draw: (c) => c.path('M10 1h2v2h2v4h2V5h2v4h2v8h-2v3h-2v2H8v-2H6v-3H4v-6h2v2h2V5h2z') },
  { id: 'bell', group: 'milestone', use: '50 sets club', replaces: '', draw: (c) => c.path('M1 9h3v6H1zM20 9h3v6h-3zM4 7h3v10H4zM17 7h3v10h-3zM7 10h10v4H7z') },
  { id: 'crown', group: 'milestone', use: 'Double digits, change world', replaces: '👑', draw: (c) => c.path('M2 6h3v4h2V6h3v3h4V6h3v4h2V6h3v12H2zM2 19h20v3H2z') },
  { id: 'skull', group: 'milestone', use: 'Centurion', replaces: '', draw: (c) => c.path('M6 2h12v2h2v10h-2v3h-2v5H8v-5H6v-3H4V4h2zm1 6v4h4V8zm6 0v4h4V8zm-2 6v2h2v-2z', true) },

  /* classes, by demo id (app ids: speedy, rogue, warrior, mage) */
  { id: 'class-scrapper', group: 'class', use: 'Scrapper: no equipment', replaces: '👟', draw: (c) => c.path('M7 8h5v3h3v-1h2l5 5v4H7z').rect(7, 19, 15, 1).clear(7, 18, 15, 1).rect(1, 11, 4, 2).rect(2, 15, 4, 2) },
  { id: 'class-bruiser', group: 'class', use: 'Bargain Bruiser: basic home gym', replaces: '🗡️', draw: (c) => c.ring(12, 7.5, 4.5, 3, [20, 160]).disk(12, 15.5, 6.5).clear(8, 13, 2, 2) },
  { id: 'class-paladin', group: 'class', use: 'Plate Paladin: free weights', replaces: '🛡️', draw: (c) => c.path('M3 3h18v9l-2 4-7 6-7-6-2-4z').clear(10.5, 6, 3, 12).clear(6, 9.5, 12, 3) },
  { id: 'class-cablemancer', group: 'class', use: 'Cablemancer: machines', replaces: '🔮', draw: (c) => c.rect(2, 2, 20, 3).ring(12, 8.5, 3, 2.5).rect(11, 11, 2, 3).rect(5, 14, 14, 8).clear(5, 16, 14, 1).clear(5, 19, 14, 1).rect(11, 14, 2, 8) },

  /* starting areas */
  { id: 'area-riptide', group: 'area', use: 'Riptide Shore', replaces: '🏝️', draw: (c) => c.path('M2 21h20v-2h-3v-2H5v2H2z').stroke([[11, 17], [12, 11], [14, 7]], 2).path('M5 9h3V7h3V5h6v2h3v2h-3v2h-2V9h-2v2h-2V9H8v2H5z') },
  { id: 'area-gainsgard', group: 'area', use: 'Gainsgard Keep', replaces: '🏰', draw: (c) => c.path('M2 5h4v3h2V5h3v3h2V5h3v3h2V5h4v17h-8v-6h-4v6H2z') },
  { id: 'area-rustbelt', group: 'area', use: 'Rustbelt Flats', replaces: '🏜️', draw: (c) => c.disk(18.5, 5, 3).path('M2 21h20v-3h-3v-4h-3v-3H8v3H5v4H2z').clear(2, 18, 20, 1) },
  { id: 'area-arcade', group: 'area', use: 'Arcade Underpass', replaces: '🕹️', draw: (c) => c.rect(3, 16, 18, 6).clear(5, 18, 3, 2).rect(11, 8, 2, 8).disk(12, 6, 4) },
  { id: 'area-frostbite', group: 'area', use: 'Frostbite Summit', replaces: '🏔️', draw: (c) => c.path('M1 21 9 6l4 6 3-3 7 12z').path('M7.4 9 9 6l2.5 3.7-1.5 1-1-1.5-1 1.5z', false, true) },

  /* the object to hit in each area */
  { id: 'object-chest', group: 'object', use: 'Riptide Shore: treasure chest', replaces: '🧰', draw: (c) => c.path('M3 9V6h2V4h14v2h2v3z').rect(3, 10, 18, 11).clear(3, 9, 18, 1).clear(10, 8, 4, 5).rect(11, 9, 2, 3) },
  { id: 'object-wall', group: 'object', use: 'Gainsgard Keep: stone wall', replaces: '🧱', draw: (c) => c.rect(2, 4, 20, 17).clear(2, 9, 20, 1).clear(2, 15, 20, 1).clear(8, 4, 1, 5).clear(16, 4, 1, 5).clear(4, 10, 1, 5).clear(12, 10, 1, 5).clear(20, 10, 1, 5).clear(8, 16, 1, 5).clear(16, 16, 1, 5) },
  { id: 'object-barrel', group: 'object', use: 'Rustbelt Flats: hazard barrel', replaces: '🛢️', draw: (c) => c.rect(5, 3, 14, 18).clear(5, 7, 14, 1).clear(5, 16, 14, 1).path('M7 9h3l-3 4zM12 9h3l-5 6H7zM17 10v4l-1 1h-3z', false, true) },
  { id: 'object-punch', group: 'object', use: 'Arcade Underpass: PUNCH-O-TRON glove', replaces: '🥊', draw: (c) => c.path('M6 4h10v2h2v2h2v7h-2v2H6zM8 18h9v4H8z').clear(6, 11, 8, 1).clear(14, 8, 1, 4) },
  { id: 'object-ice', group: 'object', use: 'Frostbite Summit: ice block', replaces: '🧊', draw: (c) => c.path('M4 7 12 3l8 4v10l-8 4-8-4z').stroke([[4.5, 7.5], [12, 11], [19.5, 7.5]], 1, true).stroke([[12, 11], [12, 21]], 1, true).rect(6, 9, 2, 2) },

  /* how each area records a set (11-profile, history) */
  { id: 'mark-riptide', group: 'mark', use: 'A shell in the loot pile', replaces: '', draw: (c) => c.path('M9 3h6v2h3v2h2v4h2v6h-2v2h-3v2H7v-2H4v-2H2v-6h2V7h2V5h3zm2 4v10h2V7zM7 9v7h2V9zm8 0v7h2V9z', true) },
  { id: 'mark-gainsgard', group: 'mark', use: 'Tally marks on the wall', replaces: '', draw: (c) => c.path('M4 3h2v18H4zM8 3h2v18H8zM12 3h2v18h-2zM16 3h2v18h-2zM2 15h4v-2h4v-2h4V9h4V7h4v3h-4v2h-4v2h-4v2H6v2H2z') },
  { id: 'mark-rustbelt', group: 'mark', use: 'A spray-painted X', replaces: '', draw: (c) => c.path('M3 3h4v2h2v2h2v2h2V7h2V5h2V3h4v4h-2v2h-2v2h-2v2h2v2h2v2h2v4h-4v-2h-2v-2h-2v-2h-2v2H9v2H7v2H3v-4h2v-2h2v-2h2v-2H7V9H5V7H3z') },
  { id: 'mark-arcade', group: 'mark', use: 'A ticket on the floor', replaces: '', draw: (c) => c.path('M2 6h20v4h-2v4h2v4H2v-4h2v-4H2zm7 3v6h2V9zm4 0v6h2V9z', true) },
  { id: 'mark-frostbite', group: 'mark', use: 'A flag up the slope', replaces: '', draw: (c) => c.path('M5 2h3v20H5zM8 3h11v2h-2v2h2v2h2v2H8z') },

  /* gear slots (D21) */
  { id: 'slot-head', group: 'slot', use: 'Gear slot: head', replaces: '🎽', draw: (c) => c.path('M3 14v-4h2V8h2V6h2V4h6v2h2v2h2v2h2v4zM2 15h20v4H2z') },
  { id: 'slot-top', group: 'slot', use: 'Gear slot: top', replaces: '👕', draw: (c) => c.path('M7 3h3v2h4V3h3l5 4-2 4h-3v10H7V11H4L2 7z') },
  { id: 'slot-bottom', group: 'slot', use: 'Gear slot: bottom', replaces: '🩳', draw: (c) => c.path('M4 4h16v15h-6l-1-7h-2l-1 7H4z').clear(4, 7, 16, 1) },
  { id: 'slot-shoes', group: 'slot', use: 'Gear slot: shoes', replaces: '👟', draw: (c) => c.path('M3 8h6v3h4v-1h3l5 5v4H3z').clear(3, 17, 18, 1) },
  { id: 'slot-weapon', group: 'slot', use: 'Gear slot: weapon (a dumbbell)', replaces: '🗡️', draw: (c) => c.rect(2, 8, 3, 8).rect(5, 6, 3, 12).rect(16, 6, 3, 12).rect(19, 8, 3, 8).rect(8, 10, 8, 4) }
];

/* ---------------- outputs ---------------- */
function svgOf(g) {
  // one subpath per horizontal run of filled pixels
  let d = '';
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    if (!g[y][x] || (x && g[y][x - 1])) continue;
    let w = 1; while (x + w < N && g[y][x + w]) w++;
    d += `M${x} ${y}h${w}v1h-${w}z`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" shape-rendering="crispEdges"><path d="${d}"/></svg>`;
}

const CRC = new Uint32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
function crc32(buf) { let c = 0xffffffff; for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
/* RGBA PNG from a pixel callback */
function png(w, h, px) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) { const [r, g, b, a] = px(x, y), o = y * (w * 4 + 1) + 1 + x * 4; raw[o] = r; raw[o + 1] = g; raw[o + 2] = b; raw[o + 3] = a; }
  }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
const WHITE = [255, 255, 255, 255], NONE = [0, 0, 0, 0];

const seen = new Set();
for (const dir of ['svg', 'png', 'png/2.0x', 'png/3.0x']) fs.mkdirSync(path.join(OUT, dir), { recursive: true });
const drawn = ICONS.map((ic) => {
  if (seen.has(ic.id)) throw new Error('duplicate id ' + ic.id);
  seen.add(ic.id);
  const c = canvas(); ic.draw(c);
  const filled = c.grid.flat().filter(Boolean).length;
  if (filled < 20) throw new Error(ic.id + ' is nearly empty (' + filled + ' px)');
  return { ...ic, grid: c.grid, svg: svgOf(c.grid) };
});
for (const ic of drawn) {
  fs.writeFileSync(path.join(OUT, 'svg', ic.id + '.svg'), ic.svg + '\n');
  for (const [dir, s] of [['png', 1], ['png/2.0x', 2], ['png/3.0x', 3]])
    fs.writeFileSync(path.join(OUT, dir, ic.id + '.png'), png(N * s, N * s, (x, y) => (ic.grid[Math.floor(y / s)][Math.floor(x / s)] ? WHITE : NONE)));
}

/* index */
fs.writeFileSync(path.join(OUT, 'icons.json'), JSON.stringify({
  grid: N, colour: 'one colour: SVG uses currentColor, PNGs are white on transparent (tint them)',
  png: { '1x': 'png/<id>.png', '2x': 'png/2.0x/<id>.png', '3x': 'png/3.0x/<id>.png' },
  icons: drawn.map((ic) => ({ id: ic.id, group: ic.group, use: ic.use, replaces: ic.replaces || null }))
}, null, 2) + '\n');

/* contact sheet: 10 per row at 3x, white on the app's violet, 12 px gutters */
const COLS = 10, S = 3, CELL = N * S, GAP = 12, rows = Math.ceil(drawn.length / COLS);
const SW = COLS * CELL + (COLS + 1) * GAP, SH = rows * CELL + (rows + 1) * GAP;
fs.writeFileSync(path.join(OUT, 'sheet.png'), png(SW, SH, (x, y) => {
  const cx = Math.floor((x - GAP) / (CELL + GAP)), cy = Math.floor((y - GAP) / (CELL + GAP));
  const ox = x - GAP - cx * (CELL + GAP), oy = y - GAP - cy * (CELL + GAP), ic = drawn[cy * COLS + cx];
  if (!ic || ox < 0 || oy < 0 || ox >= CELL || oy >= CELL) return [42, 17, 72, 255];
  return ic.grid[Math.floor(oy / S)][Math.floor(ox / S)] ? [246, 238, 255, 255] : [31, 13, 54, 255];
}));

/* the demo's icon table, so the demo and the app show the same icons */
const demo = fs.readFileSync(DEMO, 'utf8');
const begin = '/* ICONS:BEGIN', end = '/* ICONS:END */';
const a = demo.indexOf(begin), b = demo.indexOf(end);
if (a < 0 || b < 0) throw new Error('ICONS markers not found in demo.js');
const table = begin + ' (generated by tools/moodboard/icons.mjs: do not edit by hand) */\n  var ICONS = {\n' +
  drawn.map((ic) => `    ${JSON.stringify(ic.id)}: '${ic.svg.replace(' xmlns="http://www.w3.org/2000/svg"', '')}'`).join(',\n') + '\n  };\n  ';
fs.writeFileSync(DEMO, demo.slice(0, a) + table + demo.slice(b));

console.log(`${drawn.length} icons -> ${path.relative(ROOT, OUT)} (svg, png 1x/2x/3x, icons.json, sheet.png) and demo.js`);
