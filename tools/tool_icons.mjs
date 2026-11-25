// The CHALK gear-rack tool icons (D87): 12×12 pixel art, 2 colours
// ('#' ink, 'o' the tool's fill, '.' clear), written as PNGs to
// assets/icons/tools/<tool id>.png. The art is from the visual-map mockup
// (docs/moodboard/chalk/debate-02/visual-map.html). The app draws them
// scaled up with no smoothing, on a light slot, so they read in both themes.
//
// Run: node tools/tool_icons.mjs

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const INK = [0x1a, 0x0b, 0x3b];
const ORANGE = [0xff, 0x8a, 0x00], SKY = [0x00, 0xc2, 0xff], VIOLET = [0x7b, 0x2c, 0xff], PINK = [0xff, 0x2e, 0x93];

// Keys are the CHALK tool word ids (lib/game/chalk.dart).
const ICONS = {
  dumbbell: [ORANGE, ['............', '............', '............', '.##......##.', '#oo#....#oo#', '#oo######oo#', '#oo######oo#', '#oo#....#oo#', '.##......##.', '............', '............', '............']],
  barbell: [ORANGE, ['............', '............', '..#......#..', '.##......##.', '.##......##.', '############', '.##......##.', '.##......##.', '..#......#..', '............', '............', '............']],
  kettlebell: [ORANGE, ['...######...', '..#......#..', '..#......#..', '..########..', '.#oooooooo#.', '#oooooooooo#', '#oo#oooooo##', '#oooooooooo#', '#oooooooooo#', '.#oooooooo#.', '..########..', '............']],
  cable: [SKY, ['..####......', '.#oooo#.....', '.#o##o#.....', '.#oooo#.....', '..####......', '....#.......', '....#.......', '....#.......', '....#.......', '..#####.....', '..#ooo#.....', '..#####.....']],
  machine: [VIOLET, ['.##########.', '.#oooooooo#.', '.##########.', '.#oooooooo#.', '.##########.', '.#oooooooo#.', '.##########.', '.....##.....', '.....##.....', '...######...', '...#....#...', '............']],
  smith: [ORANGE, ['##........##', '##........##', '############', '##.##..##.##', '##.##..##.##', '##........##', '##........##', '##........##', '##........##', '##........##', '####....####', '............']],
  ezbar: [ORANGE, ['............', '............', '.#........#.', '##........##', '##........##', '####.##.####', '##..#..#..##', '##........##', '.#........#.', '............', '............', '............']],
  bands: [PINK, ['............', '..########..', '.#oooooooo#.', '#o#......#o#', '#o#......#o#', '#o#......#o#', '#o#......#o#', '.#oooooooo#.', '..########..', '............', '............', '............']],
  ball: [SKY, ['............', '...######...', '.##oooooo##.', '#oooooo..oo#', '#ooooooo.oo#', '#oooooooooo#', '#oooooooooo#', '.##oooooo##.', '...######...', '............', '............', '............']],
  // Rings/TRX (D90 step 2): a PLACEHOLDER, a plain box. The final pixel art
  // belongs to the design team (docs/moodboard/chalk/HANDOFF-D89-D91.md).
  rings: [SKY, ['............', '............', '..########..', '..#oooooo#..', '..#oooooo#..', '..#oooooo#..', '..#oooooo#..', '..#oooooo#..', '..#oooooo#..', '..########..', '............', '............']],
  towel: [PINK, ['............', '.##########.', '.#oooooooo#.', '.#oooooooo#.', '.##########.', '.#oooooooo#.', '.#oooooooo#.', '.##########.', '.#.#.#.#.#..', '............', '............', '............']],
  // Not a tool: the FORGE IT button's hammer (D87).
  hammer: [VIOLET, ['............', '.######.....', '#oooooo#....', '#oooooo##...', '.######.##..', '.....#...#..', '......#...#.', '.......#...#', '........#..#', '.........##.', '............', '............']],
  bodyweight: [ORANGE, ['....##......', '....##......', '............', '..######....', '.#..##..#...', '.#..##..#...', '....##......', '...#..#.....', '...#..#.....', '..#....#....', '..#....#....', '............']],
};

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc32 = (buf) => {
  let c = 0xffffffff;
  for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
};
const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
};

function png(rows, fill) {
  const w = 12, h = 12;
  const raw = Buffer.alloc(h * (1 + w * 4));
  rows.forEach((row, y) => {
    raw[y * (1 + w * 4)] = 0; // no filter
    [...row].forEach((ch, x) => {
      const o = y * (1 + w * 4) + 1 + x * 4;
      const c = ch === '#' ? INK : ch === 'o' ? fill : null;
      if (c) [raw[o], raw[o + 1], raw[o + 2], raw[o + 3]] = [...c, 255];
    });
  });
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

const out = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1')), '..', 'assets', 'icons', 'tools');
fs.mkdirSync(out, { recursive: true });
for (const [id, [fill, rows]] of Object.entries(ICONS)) {
  if (rows.length !== 12 || rows.some((r) => r.length !== 12)) throw new Error(`${id}: not 12×12`);
  fs.writeFileSync(path.join(out, `${id}.png`), png(rows, fill));
}
console.log(`${Object.keys(ICONS).length} tool icons in ${out}`);
