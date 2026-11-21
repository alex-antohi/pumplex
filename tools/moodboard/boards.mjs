// Builds the "Animation" and "Phone readability" moodboard boards.
//
//   node tools/moodboard/animate.mjs   (frames first)
//   node tools/moodboard/boards.mjs
//
// Writes each board twice from one template:
//   docs/moodboard/canvas/<Board>.dc.html  for the claude.ai design canvas (sprite sheets as uploaded /_blob/ urls)
//   docs/moodboard/<board>.html            standalone page, sprite sheets by relative path
// Animation timing comes from docs/moodboard/animation/animation.json.

import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '../..');
const MB = path.join(ROOT, 'docs/moodboard');
const manifest = JSON.parse(fs.readFileSync(path.join(MB, 'animation/animation.json'), 'utf8'));
const [FW, FH] = manifest.frameSize, [OX, OY] = manifest.bodyOffset, BW = 52, BH = 64;

// Uploaded copies of the sheets on the design canvas. Re-upload and update
// these after regenerating frames, or the canvas shows the old ones.
const BLOBS = {
  male_fat0_muscle0: { idle: 'a245f898959e6325ee5b5e0597c7740d', front_squat: 'ac253b836e96c4b794e9b48a760f8485', pr_flex: 'eff03a6558567ed34747ea526acae3b2' },
  male_fat50_muscle50: { idle: 'be63c9bfc8e53c6ca582b46ddbacd27e', front_squat: '9a6780c924cf04f45c358423e9b308f7', pr_flex: 'c3f6a357357836a4a5de25e3974d3a83' },
  male_fat100_muscle100: { idle: '3b6a5f795422bfdfbb5beea7cd23c21b', front_squat: '64f7fe841167a65cae1eccd23c2c2580', pr_flex: 'f515cc39390afc060fb27a7069be116d' },
  female_fat0_muscle0: { idle: 'dc4eb4fe9ee21ef9739f516e180356b7', front_squat: '7419a902c2d652a466c9c99b9556d310', pr_flex: '595fa7b0b8d5c42b28e7105c04697f9b' },
  female_fat50_muscle50: { idle: 'ebb2b838f3af8c4317e91b4186620aca', front_squat: '134979903171cd320c7badb7423f6f44', pr_flex: '689a197dca359eef92469bae852dabda' },
  female_fat100_muscle100: { idle: 'af87da40a979f5a0306a8e94ef97f25e', front_squat: '70860c71ca3eca85f299f26e40b07606', pr_flex: 'f52e680628c48768a87f3b9a65c6445c' },
};
const ANIMS = ['idle', 'front_squat', 'pr_flex'];
const TITLES = { idle: 'Idle', front_squat: 'Front squat', pr_flex: 'PR flex' };
const label = (id) => { const [sex, f, m] = id.split('_'); return `${sex === 'male' ? 'M' : 'F'} · FAT ${f.slice(3)} · MUSCLE ${m.slice(6)}`; };

const C = {
  bg: '#12061f', panel: '#1f0d36', panel2: '#2a1148', ink: '#0b0414', text: '#f6eeff', muted: '#c9b8e8',
  pink: '#ff5fb0', lime: '#c6ff3d', orange: '#ffa033', violet: '#a77bff', sky: '#3fd2ff', night: '#1a0b3b',
  appInk: '#f6eeff', lightBg: '#e3fbff', lightPanel: '#ffffff',
};
const FONTS = '<link rel="preconnect" href="https://fonts.googleapis.com">\n<link href="https://fonts.googleapis.com/css2?family=Anton&amp;family=Space+Mono:wght@400;700&amp;family=Roboto+Condensed:wght@900&amp;family=Roboto+Mono:wght@700&amp;display=swap" rel="stylesheet">';

// CSS keyframes that hop between sheet cells, holding each for its ms.
// crop: show only the 52x64 body (phone cards), else the whole 80x72 frame.
function keyframes(name, anim, scale, crop) {
  const a = manifest.animations[anim], total = a.frames.reduce((s, f) => s + f.ms, 0);
  let t = 0; const stops = [];
  for (const f of a.frames) {
    const i = a.sheetOrder.indexOf(f.pose);
    const x = -(i * FW + (crop ? OX : 0)) * scale, y = -(crop ? OY : 0) * scale;
    stops.push(`${((t / total) * 100).toFixed(3)}%{background-position:${x}px ${y}px}`);
    t += f.ms;
  }
  return { css: `@keyframes ${name}{${stops.join('')}100%{background-position:${-(a.sheetOrder.indexOf(a.frames[0].pose) * FW + (crop ? OX : 0)) * scale}px ${-(crop ? OY : 0) * scale}px}}`, total };
}
const timing = (anim) => manifest.animations[anim].frames.map((f) => `${f.pose} ${f.ms}`).join(' · ');

function page(title, size, helmetCss, body, canvas) {
  const head = canvas ? '<script src="./support.js"></script>\n' : '<meta name="viewport" content="width=device-width, initial-scale=1">\n';
  const open = canvas ? '<x-dc>\n<helmet>\n' : '';
  const mid = canvas ? '</helmet>\n' : '';
  const close = canvas ? `</x-dc>\n<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":${size[0]},"height":${size[1]}}}'>\nclass Component extends DCLogic {\n  renderVals() {\n    return {};\n  }\n}\n</script>\n` : '';
  return `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<title>${title}</title>\n${head}${canvas ? '' : FONTS + '\n<style>\n' + helmetCss + '\n</style>\n'}</head>\n<body>\n${open}${canvas ? FONTS + '\n<style>\n' + helmetCss + '\n</style>\n' : ''}${mid}${body}\n${close}</body>\n</html>\n`;
}

const H1 = (text, s1, s2) => `<h1 style="margin: 0; font-family: Anton, Impact, sans-serif; font-weight: 400; letter-spacing: 1px; font-size: 56px; line-height: 1; text-transform: uppercase; text-shadow: 3px 3px 0 ${s1}, 6px 6px 0 ${s2}">${text}</h1>`;
const H2 = (text, color, size = 26) => `<h2 style="margin: 0; font-family: Anton, Impact, sans-serif; font-weight: 400; letter-spacing: 1px; font-size: ${size}px; text-transform: uppercase; color: ${color}">${text}</h2>`;
const note = (title, shadow, text) => `<div style="flex: 1 1 0; padding: 14px 16px; background: ${C.panel}; border: 3px solid ${C.ink}; box-shadow: 5px 5px 0 ${shadow}; display: flex; flex-direction: column; gap: 6px"><span style="font-family: Anton, Impact, sans-serif; font-size: 20px; letter-spacing: 1px">${title}</span><span style="font-size: 13px; line-height: 1.5; color: ${C.muted}">${text}</span></div>`;
const stageBg = `background-color: ${C.panel2}; background-image: radial-gradient(rgba(255,95,176,.22) 2px, transparent 2.5px); background-size: 20px 20px; border: 4px solid ${C.ink}`;

// ---------- Animation board ----------
function animationBoard(canvas) {
  const S = 3, W = 1696, Hh = 1480, url = (id, anim) => canvas ? `/_blob/${BLOBS[id][anim]}` : `animation/${id}/${anim}_sheet.png`;
  let css = `body{margin:0}\na{color:${C.lime}}a:hover{color:#dcfb7b}\n.spr{width:${FW * S}px;height:${FH * S}px;background-repeat:no-repeat;background-size:auto ${FH * S}px;image-rendering:pixelated;image-rendering:crisp-edges}\n`;
  for (const anim of ANIMS) { const k = keyframes(`k_${anim}`, anim, S, false); css += `${k.css}\n.a_${anim}{animation:k_${anim} ${k.total}ms steps(1,end) infinite}\n`; }
  for (const id of manifest.bodies) for (const anim of ANIMS) css += `.s_${id}_${anim}{background-image:url(${url(id, anim)})}\n`;
  const rows = ANIMS.map((anim) => `
    <div style="display: flex; flex-direction: column; gap: 12px">
      <div style="display: flex; align-items: baseline; gap: 20px">${H2(TITLES[anim], anim === 'idle' ? C.sky : anim === 'front_squat' ? C.lime : C.pink)}<span style="font-size: 13px; color: ${C.muted}">${manifest.animations[anim].note}</span></div>
      <div style="display: flex; gap: 16px">${manifest.bodies.map((id) => `
        <div style="display: flex; flex-direction: column; gap: 6px; align-items: center">
          <div style="${stageBg}; box-sizing: content-box"><div class="spr a_${anim} s_${id}_${anim}" role="img" aria-label="${TITLES[anim]} loop, ${label(id).toLowerCase()}"></div></div>
          <span style="font-size: 12px; color: ${C.muted}">${label(id)}</span>
        </div>`).join('')}
      </div>
      <span style="font-size: 12px; color: ${C.muted}">ms per frame: ${timing(anim)}</span>
    </div>`).join('');
  const body = `<div style="width: ${W}px; height: ${Hh}px; box-sizing: border-box; padding: 48px 56px; background: ${C.bg}; color: ${C.text}; font-family: 'Space Mono', monospace; display: flex; flex-direction: column; gap: 28px">
  <div style="display: flex; align-items: flex-end; justify-content: space-between; gap: 24px">
    <div style="display: flex; flex-direction: column; gap: 6px">
      ${H1('Animation style test', C.lime, C.pink)}
      <p style="margin: 0; font-size: 15px; color: ${C.muted}">3 loops × 6 bodies · starter outfit · scripted from the body sliders</p>
    </div>
    <p style="margin: 0; font-size: 13px; color: ${C.muted}; text-align: right">Frames: ${FW}×${FH} px (body ${BW}×${BH} at ${OX},${OY}), shown at ${S}×<br>Light from top-left · no in-betweens, no smoothing</p>
  </div>
  ${rows}
  <div style="display: flex; gap: 20px">
    ${note('1 · Made by script', C.lime, 'tools/moodboard/animate.mjs edits the slider sprites: cuts repeated rows to sink the body, bows the knees, cuts the arms out and redraws them in the same three skin tones. Rerun it when a body changes.')}
    ${note('2 · Timing', C.sky, 'Holds do the work: 500 ms at the top of the squat, 700 ms on the flex. Moves are 90 to 160 ms per frame. Down slow, up fast.')}
    ${note('3 · Needs a hand pass', C.pink, 'Squat bottom on the skinniest bodies (knees read as loops). Fists on the bar are plain blocks. Flex forearms on fat 100 bodies are very wide. Bar and plates break the "neon only on clothes" rule a little: they use the dark violets.')}
  </div>
</div>`;
  return page('Animation style test', [W, Hh], css, body, canvas);
}

// ---------- Phone readability board ----------
function readabilityBoard(canvas) {
  const W = 1760, Hh = 1640, id = 'female_fat50_muscle50', sheet = canvas ? `/_blob/${BLOBS[id].idle}` : `animation/${id}/idle_sheet.png`;
  let css = `body{margin:0}\na{color:${C.lime}}a:hover{color:#dcfb7b}\n.body{background-image:url(${sheet});background-repeat:no-repeat;image-rendering:pixelated;image-rendering:crisp-edges}\n`;
  css += `.mega{font-family:'Roboto Condensed',sans-serif;font-weight:900;font-size:58px;line-height:.92;letter-spacing:.8px;text-transform:uppercase;color:transparent;background:linear-gradient(90deg,${C.pink},${C.orange},${C.lime},${C.sky},${C.violet},${C.pink});-webkit-background-clip:text;background-clip:text;-webkit-text-stroke:2.6px ${C.appInk};text-shadow:4.6px 4.6px 0 ${C.appInk}}\n`;
  for (const s of [1, 2, 3, 4, 5]) { const k = keyframes(`idle${s}`, 'idle', s, true); css += `${k.css}\n.b${s}{width:${BW * s}px;height:${BH * s}px;background-size:auto ${FH * s}px;background-position:${-OX * s}px ${-OY * s}px}\n.b${s}.live{animation:idle${s} ${k.total}ms steps(1,end) infinite}\n`; }

  const cond = (size, color, extra = '') => `font-family: 'Roboto Condensed', sans-serif; font-weight: 900; font-size: ${size}px; line-height: 1; color: ${color}; ${extra}`;
  const mono = (size, color) => `font-family: 'Roboto Mono', monospace; font-weight: 700; font-size: ${size}px; line-height: 1.35; color: ${color}`;
  const phone = (s) => `
    <div style="display: flex; flex-direction: column; gap: 12px; align-items: center">
      <div style="width: 390px; height: 844px; box-sizing: border-box; overflow: hidden; border: 6px solid #4b2a7a; border-radius: 36px; background-color: ${C.bg}; background-image: radial-gradient(rgba(255,95,176,.22) 2.5px, transparent 3px); background-size: 24px 24px; background-position: 0 0; padding: 28px 16px 16px; display: flex; flex-direction: column; gap: 0">
        <span style="${cond(13, C.appInk, 'letter-spacing: 1.6px')}">SESSION 9 · DAY 2 OF 7 · 6 EXERCISES</span>
        <div class="mega" style="margin-top: 8px">Heavy Lower</div>
        <span style="align-self: flex-start; margin-top: 14px; padding: 5px 10px; background: ${C.night}; transform: rotate(-2deg); ${cond(17, C.lime, 'letter-spacing: 1px')}">SQUATS, BUT MORE.</span>
        <div style="margin-top: 26px; background: ${C.panel}; border: 4px solid ${C.appInk}; box-shadow: 8px 8px 0 ${C.lime}; padding: 14px; display: flex; flex-direction: column; gap: 10px">
          <div style="display: flex; justify-content: space-between; align-items: baseline"><span style="${cond(21, C.appInk)}">YOUR LIFTER</span><span style="${mono(13, C.appInk)}">LV [LEVEL]</span></div>
          <div style="display: flex; justify-content: center; padding: 10px 0; background-color: ${C.panel2}; background-image: radial-gradient(rgba(255,95,176,.22) 2px, transparent 2.5px); background-size: 20px 20px"><div class="body b${s} live" role="img" aria-label="Lifter idling, shown at ${s}x"></div></div>
          <div style="padding: 10px 12px; background: ${C.night}; ${mono(13.5, C.lime)}">[LIFTER NAME] · ${BW * s}×${BH * s} DP</div>
        </div>
        <div style="margin-top: 34px; background: ${C.panel}; border: 4px solid ${C.appInk}; box-shadow: 8px 8px 0 ${C.violet}; padding: 14px; display: flex; flex-direction: column; gap: 12px">
          <div style="display: flex; justify-content: space-between; align-items: baseline"><span style="${cond(21, C.appInk)}">THE PUMP-O-METER™</span><span style="${mono(13, C.appInk)}">0/6 SETS</span></div>
          <div style="height: 120px; background: ${C.panel2}"></div>
          <div style="padding: 10px 12px; background: ${C.night}; ${mono(13.5, C.lime)}">WAITING FOR YOUR FIRST SET…</div>
        </div>
      </div>
      <span style="font-family: Anton, Impact, sans-serif; font-size: 22px; letter-spacing: 1px">${s}× · BODY ${BW * s}×${BH * s} DP · ${Math.round((BW * s) / 390 * 100)}% OF WIDTH</span>
    </div>`;

  const grounds = [
    ['App dark bg', C.bg, C.muted], ['Panel', C.panel, C.muted], ['Panel 2 (stage)', C.panel2, C.muted], ['Night (terminal)', C.night, C.muted],
    ['App light bg', C.lightBg, '#1a0b3b'], ['Light panel', C.lightPanel, '#1a0b3b'], ['Pink button', '#ff5fb0', '#1a0b3b'], ['Lime button', '#c6ff3d', '#1a0b3b'],
  ];
  const swatch = ([name, bg, fg]) => `<div style="display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 12px 8px 8px; background: ${bg}; border: 3px solid ${C.ink}"><div class="body b2" role="img" aria-label="Lifter at 2x on ${name}"></div><span style="font-size: 11px; color: ${fg}">${name} ${bg}</span></div>`;
  const ladder = [1, 2, 3, 4, 5].map((s) => `<div style="display: flex; flex-direction: column; align-items: center; gap: 8px; justify-content: flex-end"><div class="body b${s} live" role="img" aria-label="Lifter at ${s}x"></div><span style="font-family: Anton, Impact, sans-serif; font-size: 18px; letter-spacing: 1px">${s}×</span><span style="font-size: 11px; color: ${C.muted}">${BW * s}×${BH * s} dp</span></div>`).join('');

  const body = `<div style="width: ${W}px; height: ${Hh}px; box-sizing: border-box; padding: 48px 56px; background: ${C.bg}; color: ${C.text}; font-family: 'Space Mono', monospace; display: flex; flex-direction: column; gap: 32px">
  <div style="display: flex; align-items: flex-end; justify-content: space-between; gap: 24px">
    <div style="display: flex; flex-direction: column; gap: 6px">
      ${H1('Phone readability', C.sky, C.violet)}
      <p style="margin: 0; font-size: 15px; color: ${C.muted}">A lifter card on the real Heavy Lower page · dark theme · 390×844 dp</p>
    </div>
    <p style="margin: 0; font-size: 13px; color: ${C.muted}; text-align: right">Page chrome copied from lib/day_page.dart and lib/pumplex.dart<br>The lifter card is new. [BRACKETS] are placeholders</p>
  </div>
  <div style="display: flex; gap: 40px; align-items: flex-start">
    <div style="display: flex; gap: 40px">${[3, 4, 5].map(phone).join('')}</div>
    <div style="flex: 1 1 auto; display: flex; flex-direction: column; gap: 14px">
      ${H2('Every ground in the app · 2×', C.pink, 22)}
      <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px">${grounds.map(swatch).join('')}</div>
    </div>
  </div>
  <div style="display: flex; gap: 40px; align-items: stretch">
    <div style="display: flex; flex-direction: column; gap: 14px">
      ${H2('Size ladder', C.lime, 22)}
      <div style="display: flex; gap: 28px; align-items: flex-end; padding: 20px 24px 14px; ${stageBg}">${ladder}</div>
    </div>
    <div style="flex: 1 1 0; display: flex; flex-direction: column; gap: 14px">
      ${H2('What the boards show', C.orange, 22)}
      <div style="display: flex; flex-direction: column; gap: 12px">
        ${note('Outline disappears on dark grounds', C.pink, 'The #0b0414 ink line is only 1.0 to 1.2:1 against the dark bg, panels and stage, so on dark the silhouette comes from skin and shirt only. On light grounds and the buttons it reads strongly.')}
        ${note('Panel borders don’t match', C.sky, 'In the app’s dark theme, panel borders are light (#f6eeff, the theme’s ink). Moodboard v0.1 draws panels with dark #0b0414 borders. Pick one before building game UI.')}
        ${note('Width budget', C.lime, `On a 390 dp screen the body takes ${Math.round(BW * 3 / 3.9)}% of the width at 3×, ${Math.round(BW * 4 / 3.9)}% at 4× and ${Math.round(BW * 5 / 3.9)}% at 5×. At 5× nothing fits beside it.`)}
      </div>
    </div>
  </div>
</div>`;
  return page('Phone readability', [W, Hh], css, body, canvas);
}

const out = [
  ['canvas/Animation.dc.html', animationBoard(true)], ['animation.html', animationBoard(false)],
  ['canvas/Readability.dc.html', readabilityBoard(true)], ['readability.html', readabilityBoard(false)],
];
for (const [file, html] of out) fs.writeFileSync(path.join(MB, file), html);
console.log('wrote', out.map(([f]) => f).join(', '));
