// Procedural 8/16-bit sound pack. Run: node tools/moodboard/sounds.mjs
// Writes 16-bit mono 44.1 kHz WAV files + sounds.json + README.md to docs/moodboard/sounds/.
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const SR = 44100;
const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'docs', 'moodboard', 'sounds');
const PEAK = Math.pow(10, -3 / 20); // -3 dBFS

// Seeded noise (mulberry32) so output is repeatable.
function rng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

class Track {
  constructor(ms, seed) { this.n = Math.round(ms * SR / 1000); this.b = new Float32Array(this.n); this.r = rng(seed); }
  // Oscillator with exponential pitch sweep f0->f1, attack + power decay envelope, start t (s).
  osc({ type = 'square', f0, f1 = f0, t = 0, dur, vol = 1, att = 0.003, curve = 3, duty = 0.5, vib = 0 }) {
    const s0 = Math.round(t * SR), n = Math.round(dur * SR);
    let ph = 0;
    for (let i = 0; i < n && s0 + i < this.n; i++) {
      const x = i / n;
      let f = f0 * Math.pow(f1 / f0, x);
      if (vib) f *= 1 + 0.04 * Math.sin(2 * Math.PI * vib * i / SR);
      ph = (ph + f / SR) % 1;
      let v;
      if (type === 'square') v = ph < duty ? 1 : -1;
      else if (type === 'tri') v = 4 * Math.abs(ph - 0.5) - 1;
      else if (type === 'saw') v = 2 * ph - 1;
      else v = Math.sin(2 * Math.PI * ph);
      const env = Math.min(1, i / (att * SR)) * Math.pow(1 - x, curve);
      this.b[s0 + i] += v * env * vol;
    }
    return this;
  }
  // Noise burst; hp 0..1 high-pass amount, hold = sample-and-hold steps (lo-fi), buzz = AM rate in Hz.
  noise({ t = 0, dur, vol = 1, att = 0.001, curve = 3, hp = 0, hold = 1, buzz = 0 }) {
    const s0 = Math.round(t * SR), n = Math.round(dur * SR);
    let lp = 0, held = 0;
    for (let i = 0; i < n && s0 + i < this.n; i++) {
      const x = i / n;
      if (i % hold === 0) held = this.r() * 2 - 1;
      lp += (held - lp) * (1 - hp * 0.95);
      const o = hp > 0 ? held - lp : held;
      const am = buzz ? (Math.sin(2 * Math.PI * buzz * i / SR) > 0 ? 1 : 0.2) : 1;
      this.b[s0 + i] += o * am * Math.min(1, i / (att * SR)) * Math.pow(1 - x, curve) * vol;
    }
    return this;
  }
  arp(freqs, { t = 0, step = 0.06, dur = 0.09, vol = 0.5, type = 'square', curve = 1.5 } = {}) {
    freqs.forEach((f, i) => this.osc({ type, f0: f, t: t + i * step, dur, vol, curve }));
    return this;
  }
}

const N = (m) => 440 * Math.pow(2, (m - 69) / 12); // midi note -> Hz

const defs = [
  { id: 'set_riptide', ms: 360, when: 'Set logged, area Riptide (chest open and shell clack)', build(k) {
    k.osc({ type: 'saw', f0: 90, f1: 260, dur: 0.12, vol: 0.35, curve: 1, vib: 40 })
     .noise({ t: 0.12, dur: 0.04, vol: 0.8, hp: 0.6, curve: 6 })
     .arp([N(76), N(80), N(83), N(88)], { t: 0.13, step: 0.05, dur: 0.11, vol: 0.4 }); } },
  { id: 'set_gainsgard', ms: 340, when: 'Set logged, area Gainsgard (chalk scratch and thump)', build(k) {
    for (let i = 0; i < 4; i++) k.noise({ t: i * 0.05, dur: 0.045, vol: 0.55, hp: 0.9, hold: 2, curve: 1.2 });
    k.osc({ type: 'tri', f0: 150, f1: 55, t: 0.2, dur: 0.14, vol: 0.9, curve: 2 })
     .osc({ type: 'square', f0: N(72), t: 0.2, dur: 0.1, vol: 0.3 }); } },
  { id: 'set_rustbelt', ms: 390, when: 'Set logged, area Rustbelt (barrel boom)', build(k) {
    k.osc({ type: 'sine', f0: 140, f1: 38, dur: 0.38, vol: 1, curve: 1.6 })
     .noise({ dur: 0.18, vol: 0.55, hold: 6, curve: 3 })
     .osc({ type: 'square', f0: 70, f1: 40, dur: 0.1, vol: 0.25, curve: 2 }); } },
  { id: 'set_arcade', ms: 330, when: 'Set logged, area Arcade (punch-o-tron pad)', build(k) {
    k.noise({ dur: 0.05, vol: 0.9, hold: 3, curve: 4 })
     .osc({ type: 'tri', f0: 110, f1: 50, dur: 0.1, vol: 0.8, curve: 2 })
     .osc({ type: 'square', f0: N(79), t: 0.09, dur: 0.07, vol: 0.4, duty: 0.25 })
     .osc({ type: 'square', f0: N(91), t: 0.16, dur: 0.16, vol: 0.4, duty: 0.25, curve: 1 }); } },
  { id: 'set_frostbite', ms: 380, when: 'Set logged, area Frostbite (ice smash)', build(k) {
    k.noise({ dur: 0.1, vol: 0.9, hp: 0.5, curve: 4 })
     .noise({ t: 0.05, dur: 0.3, vol: 0.4, hp: 0.95, hold: 2, curve: 2, buzz: 60 });
    [96, 91, 88, 84, 93].forEach((m, i) => k.osc({ type: 'sine', f0: N(m), t: 0.08 + i * 0.045, dur: 0.14, vol: 0.28, curve: 2.5 })); } },
  { id: 'stamp5', ms: 320, when: '5th mark of a set gets stamped (ka-chunk)', build(k) {
    k.osc({ type: 'tri', f0: 200, f1: 45, dur: 0.18, vol: 1, curve: 2.5 })
     .noise({ dur: 0.05, vol: 0.9, hp: 0.3, curve: 5 })
     .osc({ type: 'square', f0: N(67), t: 0.1, dur: 0.07, vol: 0.4 })
     .osc({ type: 'square', f0: N(79), t: 0.16, dur: 0.15, vol: 0.45, curve: 1.5 }); } },
  { id: 'critical', ms: 390, when: 'Critical set (bigger and brasher than a normal set)', build(k) {
    k.osc({ type: 'sine', f0: 160, f1: 40, dur: 0.25, vol: 1, curve: 2 })
     .noise({ dur: 0.12, vol: 0.8, hold: 2, curve: 3 })
     .arp([N(72), N(76), N(79), N(84), N(88)], { t: 0.05, step: 0.055, dur: 0.14, vol: 0.45, curve: 1.2 })
     .osc({ type: 'square', f0: N(96), t: 0.3, dur: 0.09, vol: 0.3, duty: 0.25 }); } },
  { id: 'levelup', ms: 1400, when: 'Level-up (fanfare, plays with the flex animation)', build(k) {
    const seq = [60, 64, 67, 72, 67, 72, 76, 79];
    seq.forEach((m, i) => k.osc({ type: 'square', f0: N(m), t: i * 0.09, dur: 0.1, vol: 0.45, duty: 0.25, curve: 1 }));
    const t0 = seq.length * 0.09;
    [72, 76, 79, 84].forEach((m) => k.osc({ type: 'square', f0: N(m), t: t0, dur: 0.6, vol: 0.28, curve: 1.3 }));
    k.osc({ type: 'tri', f0: N(48), t: t0, dur: 0.65, vol: 0.7, curve: 1.2 })
     .osc({ type: 'square', f0: N(91), t: t0 + 0.55, dur: 0.1, vol: 0.3, duty: 0.25 })
     .osc({ type: 'square', f0: N(96), t: t0 + 0.65, dur: 0.6, vol: 0.35, duty: 0.25, curve: 1.2, vib: 6 })
     .noise({ t: t0, dur: 0.1, vol: 0.4, hp: 0.5, curve: 5 }); } },
  { id: 'ui_button', ms: 70, when: 'Any button tap in the menu or flow', build(k) {
    k.osc({ type: 'square', f0: N(84), f1: N(88), dur: 0.06, vol: 0.7, duty: 0.25, curve: 2 }); } },
  { id: 'ui_toggle', ms: 120, when: 'A toggle flips (the SOUND toggle plays it when turned on)', build(k) {
    k.osc({ type: 'square', f0: N(76), dur: 0.05, vol: 0.6, curve: 1 })
     .osc({ type: 'square', f0: N(83), t: 0.055, dur: 0.06, vol: 0.6, curve: 2 }); } },
  { id: 'set_back', ms: 360, when: 'Take a set back (undo): sad wobbly slide down', build(k) {
    k.osc({ type: 'saw', f0: N(67), f1: N(48), dur: 0.34, vol: 0.5, curve: 1.2, vib: 14 })
     .osc({ type: 'square', f0: N(55), f1: N(36), t: 0.05, dur: 0.28, vol: 0.3, duty: 0.25, curve: 1.5 })
     .noise({ t: 0.3, dur: 0.05, vol: 0.3, hold: 8, curve: 3 }); } },
];

function wav(f32) {
  const buf = Buffer.alloc(44 + f32.length * 2);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + f32.length * 2, 4); buf.write('WAVEfmt ', 8);
  buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write('data', 36); buf.writeUInt32LE(f32.length * 2, 40);
  f32.forEach((v, i) => buf.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(v * 32767))), 44 + i * 2));
  return buf;
}

mkdirSync(OUT, { recursive: true });
const manifest = [];
defs.forEach((d, idx) => {
  const k = new Track(d.ms, 1000 + idx);
  d.build(k);
  const b = k.b;
  const fade = Math.round(0.002 * SR); // 2 ms fades against clicks
  for (let i = 0; i < fade; i++) { b[i] *= i / fade; b[b.length - 1 - i] *= i / fade; }
  let pk = 0; for (const v of b) pk = Math.max(pk, Math.abs(v));
  const g = PEAK / pk; for (let i = 0; i < b.length; i++) b[i] *= g;
  writeFileSync(join(OUT, d.id + '.wav'), wav(b));
  manifest.push({ id: d.id, file: d.id + '.wav', ms: Math.round(b.length / SR * 1000), when: d.when, peakDb: -3 });
});
writeFileSync(join(OUT, 'sounds.json'), JSON.stringify({ sampleRate: SR, bits: 16, channels: 1, peakDbfs: -3, sounds: manifest }, null, 2) + '\n');

const rows = manifest.map((m) => `| \`${m.id}\` | ${m.ms} ms | ${m.when} |`).join('\n');
writeFileSync(join(OUT, 'README.md'), `# Sound pack

Short 8/16-bit chiptune sounds for the menu SOUND toggle. Loud and funny, in the tone of \`docs/moodboard/README.md\`.
Generated by \`node tools/moodboard/sounds.mjs\` (square, triangle, sine and saw oscillators, seeded noise, so the output is the same every run). Do not edit the WAV files by hand; change the script and run it again.

| id | length | plays when |
| --- | --- | --- |
${rows}

\`sounds.json\` lists id, file, length in ms, when it plays and peak level.

## Format and loudness

- 16-bit mono WAV, 44.1 kHz. WAV is used because no OGG encoder is available offline. If the app wants smaller files, convert to OGG in its build step.
- Every file is normalised so its peak is about -3 dBFS. Keep it that way: all sounds are equally loud, so the app needs no per-sound gain. Do not play two at full volume at once (for example the level-up and a UI tap); drop the UI tap.
- Set sounds are under 400 ms, the level-up is under 1.5 s.

## How the app should play them

- Play only when the SOUND toggle is on. Default is off. Save the choice with the other settings.
- Preload the files on the first user tap (browsers block audio before a tap). Use one \`Audio\` per sound or an \`AudioContext\` with decoded buffers; restart or clone the sound so fast taps can overlap.
- A set logged plays the sound of the current area: \`set_<area-id>\` with area ids riptide, gainsgard, rustbelt, arcade, frostbite. If the area is unknown, use \`set_gainsgard\`.
- The 5th mark of a set plays \`stamp5\` right after the set sound (about 150 ms later). A critical set plays \`critical\` instead of the area sound. A level-up plays \`levelup\` with the flex animation.
- Use \`ui_button\` for button taps, \`ui_toggle\` for toggles, \`set_back\` when a set is taken back.
`);
console.log('wrote', manifest.length, 'sounds to', OUT);
