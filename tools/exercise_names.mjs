// The composed exercise names (D80): a variation's name is its move's name
// and the name parts of its modifiers, in the word order of the language.
// The same rule as composeName in lib/game/exercises.dart; keep them equal.
//
// Keys in assets/i18n/<lang>.json:
//   move.<base, lower case>   the move's name ("Push-Up", "Flotări")
//   name.move.<base>.<value>  the move's name for the variations with that
//                             value ("Chin-Up" for a reverse-grip Pull-Up);
//                             the value's own part is then left out
//   name.move.<base>          a shorter move name for the composed names, where
//                             a language needs one ("Împins" for "Împins la piept")
//   name.form.<base>          the grammatical form of the move's name, in a
//                             language with agreement (Romanian): ms fs ns mp fp np
//                             (masculine, feminine, neuter; singular, plural)
//   name.order                the slots in word order, for example
//                             "side position angle ... move bands chains"
//   name.<base>.<value>       the part of one modifier value on one move,
//   name.<axis>.<value>       else on one axis,
//   name.<value>              else on any axis ("Close-Grip", "priză îngustă").
//                             An empty part is left out (Medium Grip). A part
//                             "a|b|c|d" agrees with the move: masculine singular,
//                             feminine singular, masculine plural, feminine plural
//                             ("înclinat|înclinată|înclinați|înclinate").
//   exercise.<id>             a special name: it replaces the composed one
//                             (legacy names a rule cannot make, for example
//                             "Treadmill").
// The equipment part shows only when the move has more than one equipment.

/** The agreeing form (index into "a|b|c|d") for a move's grammatical form; no form: 0. */
export const formIndex = (form) => ({ fs: 1, mp: 2, fp: 3, np: 3 })[form] ?? 0;

/**
 * The name of variation [mods] of move [base] in the language of [look]
 * (key -> text or undefined). [equipShown]: the move has more than one
 * equipment. Without the keys, the English fallback is the value itself.
 */
export function composeName(base, mods, equipShown, look) {
  const b = base.toLowerCase();
  const slots = (look('name.order') ?? '').split(' ').filter(Boolean);
  const moveSlot = slots.find((s) => mods[s] != null && look(`name.move.${b}.${mods[s]}`) != null);
  const move = (moveSlot && look(`name.move.${b}.${mods[moveSlot]}`)) ?? look(`name.move.${b}`) ?? look(`move.${b}`) ?? base;
  const form = formIndex(look(`name.form.${b}`));
  const words = [];
  for (const slot of slots) {
    if (slot === 'move') {
      words.push(move);
      continue;
    }
    const v = mods[slot];
    if (v == null || slot === moveSlot || (slot === 'equip' && !equipShown)) continue;
    let p = look(`name.${b}.${v}`) ?? look(`name.${slot}.${v}`) ?? look(`name.${v}`) ?? v;
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
