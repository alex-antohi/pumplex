// Preview: full composed scenes. Run: node tools/art_hd/preview_objects_b.mjs [crop-out.png]
import { Img, hx, mix } from './lib_px.mjs';
const ld = (id, n) => Img.load(`assets/areas/${id}/${n}.png`);

function scene(id, frame, extra) {
  const S = new Img(350, 620); S.rect(0, 0, 350, 620, id === 'arcade' ? '12061f' : '1a0b3b');
  S.over(ld(id, 'sky'), 0, 0);
  S.over(ld(id, 'background'), 0, 320);
  S.over(ld(id, 'floor'), 0, 320 + 228);
  S.over(ld(id, 'shadow'), 18, 320 + 270);
  const oy = 320;
  if (id === 'arcade') {
    for (let i = 0; i < 6; i++) S.over(ld(id, 'mark'), (164 - 7 * i) * 2, oy + 142 * 2);
    S.over(ld(id, ['object_idle', 'object_tap', 'object_hit'][frame]), 202, oy + 40);
    // LED text stand-in
    const led = new Img(60, 40); led.rect(0, 0, 60, 40, [0, 0, 0], 0);
    S.rect(274, oy + 94, 3, 3, 'c6ff3d'); // marker of the ledRect corner (137,47)
  } else {
    const pos = [[58, 95], [66.5, 89], [75, 82.5], [83.5, 76], [92, 70]];
    const tint = ['3fd2ff', 'a6f3f6', 'ffa033', 'ff5fb0', 'c6ff3d'];
    pos.forEach(([x, y], i) => {
      S.over(ld(id, 'mark'), Math.round(x * 2), oy + Math.round(y * 2));
      const t = ld(id, 'mark_tint'), c = hx(tint[i]);
      for (let yy = 0; yy < t.h; yy++) for (let xx = 0; xx < t.w; xx++) { const g = t.get(xx, yy); if (g[3]) S.px(Math.round(x * 2) + xx, oy + Math.round(y * 2) + yy, c.map((v, k) => Math.round(v * g[k] / 255))); }
    });
    S.over(ld(id, ['object_idle', 'object_tap', 'object_hit'][frame]), 144, oy + 222);
    if (frame === 2) S.over(ld(id, 'fx_2'), 0, oy);
  }
  if (extra) S.over(ld(id, extra), id === 'arcade' ? 100 : 130, oy + 30);
  return S;
}

const sheet = new Img(1070, 1260); sheet.rect(0, 0, 1070, 1260, '2b2a33');
['arcade', 'frostbite'].forEach((id, r) => {
  for (let f = 0; f < 3; f++) sheet.over(scene(id, f, f === 1 ? 'burst_4' : null), 4 + f * 355, 4 + r * 630);
});
sheet.save('tools/art_hd/preview_objects_b.png');
console.log('preview written');
