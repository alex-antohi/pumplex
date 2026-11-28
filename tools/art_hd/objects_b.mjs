// HD (2x) objects, bursts, fx, marks, shadows for arcade and frostbite, plus the sky.png extension.
// Run: node tools/art_hd/objects_b.mjs   (writes assets/areas/<id>/*.png)
import { Img } from './lib_px.mjs';
import * as A from './objects_arcade.mjs';
import * as F from './objects_frost.mjs';
import { arcadeSky, frostSky } from './sky_b.mjs';

const dir = id => `assets/areas/${id}/`;
const w = (id, name, img) => img.save(dir(id) + name + '.png');

for (let i = 0; i < 3; i++) w('arcade', ['object_idle', 'object_tap', 'object_hit'][i], A.arcadeObject(i));
for (let i = 0; i < 5; i++) { w('arcade', `burst_${i + 1}`, A.arcadeBurst(i)); w('frostbite', `burst_${i + 1}`, A.frostBurst(i)); }
w('arcade', 'mark', A.arcadeMark());
w('arcade', 'shadow', A.shadow('0b0414'));
w('frostbite', 'shadow', A.shadow('150c3c'));
for (let i = 0; i < 3; i++) w('frostbite', ['object_idle', 'object_tap', 'object_hit'][i], F.iceBlock(i));
for (let i = 0; i < 6; i++) w('frostbite', `fx_${i + 1}`, F.frostFx(i));
w('frostbite', 'mark', F.flagMark());
w('frostbite', 'mark_tint', F.flagTint());
w('arcade', 'sky', arcadeSky(Img.load(dir('arcade') + 'background.png')));
w('frostbite', 'sky', frostSky(Img.load(dir('frostbite') + 'background.png')));
console.log('objects_b written');
