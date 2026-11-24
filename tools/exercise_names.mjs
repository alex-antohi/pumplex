// The composed exercise names (D80): a variation's name is its move's name
// and the name parts of its modifiers, in the word order of the language.
// The same rule as composeName in lib/game/exercises.dart; keep them equal.
//
// Keys in assets/i18n/<lang>.json:
//   move.<base, lower case>   the move's name ("Push-Up", "Flotări")
//   name.move.<base>          a shorter move name for the composed names, where
//                             a language needs one ("Împins" for "Împins la piept")
//   name.order                the slots in word order, for example
//                             "side position angle ... move bands chains"
//   name.<axis>.<value>       the part of one modifier value on one axis,
//   name.<value>              else on any axis ("Close-Grip", "priză îngustă").
//                             An empty part is left out (Medium Grip). A part
//                             "a|b|c" has a form per gender of the move's first
//                             word (Romanian): masculine or neuter, feminine,
//                             plural ("înclinat|înclinată|înclinate").
//   exercise.<id>             a special name: it replaces the composed one
//                             (legacy names a rule cannot make, for example
//                             "Chin-Up", "Treadmill").
// The equipment part shows only when the move has more than one equipment.

/** The form of a part for a move name: 0 masculine or neuter, 1 feminine, 2 plural. */
export function formOf(moveName) {
  const w = moveName.split(' ')[0].toLowerCase();
  if (/[ie]$/.test(w)) return 2;
  if (/[ăa]$/.test(w)) return 1;
  return 0;
}

/**
 * The name of variation [mods] of move [base] in the language of [look]
 * (key -> text or undefined). [equipShown]: the move has more than one
 * equipment. Without the keys, the English fallback is the value itself.
 */
export function composeName(base, mods, equipShown, look) {
  const b = base.toLowerCase();
  const move = look(`name.move.${b}`) ?? look(`move.${b}`) ?? base;
  const form = formOf(move);
  const words = [];
  for (const slot of (look('name.order') ?? '').split(' ').filter(Boolean)) {
    if (slot === 'move') {
      words.push(move);
      continue;
    }
    const v = mods[slot];
    if (v == null || (slot === 'equip' && !equipShown)) continue;
    let p = look(`name.${slot}.${v}`) ?? look(`name.${v}`) ?? v;
    if (p.includes('|')) {
      const forms = p.split('|');
      p = forms[Math.min(form, forms.length - 1)];
    }
    if (p) words.push(p);
  }
  return words.join(' ');
}

/** Whether the variations [rows] of one move use more than one equipment. */
export const equipShownOf = (rows) => new Set(rows.map((r) => r.mods?.equip)).size > 1;

/** The stable id of a generated variation (D80): the move and its modifier values, lower case. */
export const AXIS_ORDER = ['equip', 'type', 'angle', 'width', 'hand', 'stance', 'side', 'position', 'attach', 'bands', 'chains'];
export const variationId = (base, mods) =>
  [base, ...AXIS_ORDER.filter((a) => mods[a]).map((a) => mods[a])].join('|').toLowerCase();
