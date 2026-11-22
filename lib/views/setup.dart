// Initial setup: character + class, difficulty, starting area, summary.
// The character itself is drawn by the shell (one sprite for the whole app);
// these views leave room for it at the [stage] rect.

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/area_art.dart';
import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import 'area_scene.dart';
import 'sprite.dart';

/// Bottom row with BACK / NEXT style buttons.
class _Nav extends StatelessWidget {
  const _Nav({this.onBack, required this.next, required this.onNext});

  final VoidCallback? onBack;
  final String next;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 22, 14 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          if (onBack != null) ...[
            BrutalButton(color: p.sky, onTap: onBack, child: const IconText('back', 'BACK')),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: BrutalButton(
              color: p.pink,
              onTap: onNext,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(next, maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: display(24, p.on)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ character creation

/// WoW-style character screen (setup step 1): the character large in the
/// centre, the options around it, everything changes live. Tap the head:
/// the camera zooms in and the panel shows skin, hair and facial hair.
class CreateView extends StatelessWidget {
  const CreateView({
    super.key,
    required this.stage,
    required this.character,
    required this.onCharacter,
    required this.onNext,
    required this.headOpen,
    required this.onHead,
  });

  final Rect stage;
  final Character character;
  final ValueChanged<Character> onCharacter;
  final VoidCallback onNext;

  /// The head looks panel is open (the shell zooms the character in).
  final bool headOpen;
  final ValueChanged<bool> onHead;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget sexButton(String sex, String label) {
      final on = character.sex == sex;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BrutalButton(
          key: ValueKey('sex-$sex'),
          small: true,
          color: on ? p.pink : p.panel,
          onTap: () => onCharacter(character.copyWith(sex: sex)),
          child: SizedBox(width: 34, height: 26, child: Center(child: PxIcon(label, size: 24, color: on ? p.on : p.ink))),
        ),
      );
    }

    final head = headRect(spriteGeometry(stage.size, character.height).sprite).shift(stage.topLeft);
    return Column(
      children: [
        SizedBox(
          height: stage.bottom,
          child: Stack(
            children: [
              if (!headOpen)
                Positioned(
                  left: 14,
                  top: stage.top + 6,
                  child: Column(children: [sexButton('male', 'male'), sexButton('female', 'female')]),
                ),
              // Tap the head to open (or close) the head looks.
              Positioned.fromRect(
                rect: headOpen ? stage : head.inflate(8),
                child: GestureDetector(
                  key: const ValueKey('creator-head'),
                  behavior: HitTestBehavior.translucent,
                  onTap: () => onHead(!headOpen),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 22, 8),
            children: headOpen ? _headPanel(p) : _bodyPanel(p),
          ),
        ),
        _Nav(next: headOpen ? 'DONE' : 'NEXT', onNext: headOpen ? () => onHead(false) : onNext),
      ],
    );
  }

  List<Widget> _bodyPanel(Pal p) => [
        Shout('Build your lifter', size: 14, color: p.pink),
        const SizedBox(height: 4),
        Text('TAP THE HEAD FOR SKIN AND HAIR.', style: mono(11, p.ink)),
        const SizedBox(height: 10),
        _BodySlider(
          label: 'HEIGHT',
          ends: '${heightMetres(0).toStringAsFixed(2)} M · ${heightMetres(100).toStringAsFixed(2)} M',
          shown: '${heightMetres(character.height).toStringAsFixed(2)} M',
          value: character.height,
          onChanged: (v) => onCharacter(character.copyWith(height: v)),
        ),
        _BodySlider(
          label: 'WEIGHT',
          ends: '$minWeightKg KG · $maxWeightKg KG',
          shown: '${weightKg(character.fat)} KG',
          value: character.fat,
          onChanged: (v) => onCharacter(character.copyWith(fat: v)),
        ),
        _BodySlider(
          label: 'MUSCLE',
          value: character.muscle,
          onChanged: (v) => onCharacter(character.copyWith(muscle: v)),
        ),
      ];

  List<Widget> _headPanel(Pal p) {
    Widget row(String title, String kind, List<Look> looks, String current, Character Function(String) pick) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shout(title, size: 14),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final l in looks) ...[
                    _LookButton(
                      key: ValueKey('look-$kind-${l.id}'),
                      look: l,
                      on: l.id == current,
                      onTap: () => onCharacter(pick(l.id)),
                    ),
                    const SizedBox(width: 12),
                  ],
                ],
              ),
            ],
          ),
        );
    return [
      Shout('Your head', size: 14, color: p.pink),
      const SizedBox(height: 10),
      row('SKIN', 'skin', skinLooks, character.skin, (id) => character.copyWith(skin: id)),
      row('HAIR', 'hair', hairLooks, character.hair, (id) => character.copyWith(hair: id)),
      row('FACIAL HAIR', 'facial', facialHairLooks, character.facialHair, (id) => character.copyWith(facialHair: id)),
    ];
  }
}

/// One head look: a swatch and its name. Pink when picked.
class _LookButton extends StatelessWidget {
  const _LookButton({super.key, required this.look, required this.on, required this.onTap});

  final Look look;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final fg = on ? p.on : p.ink;
    return BrutalButton(
      small: true,
      color: on ? p.pink : p.panel,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: look.swatch == 0 ? null : Color(look.swatch),
              border: Border.all(color: fg, width: 2),
            ),
          ),
          const SizedBox(width: 8),
          Text(look.name, style: mono(13, fg)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ class select

/// The preview card around the character on the class-select step.
Rect classCardRect(Rect stage, double width) =>
    Rect.fromLTRB(16, stage.top - 10, width - 22, stage.bottom + 10);

/// Setup step 2, "CHOOSE YOUR PATH" (docs/moodboard/README.md "Class
/// select"): a preview card with the lifter, the loadout and 3 tags (no
/// stat table), a description, 4 class buttons, NEXT: DIFFICULTY.
class ClassView extends StatelessWidget {
  const ClassView({
    super.key,
    required this.stage,
    required this.classId,
    required this.onPick,
    required this.onBack,
    required this.onNext,
    required this.editing,
  });

  final Rect stage;
  final String classId;
  final ValueChanged<String> onPick;
  final VoidCallback onBack, onNext;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = classById(classId);
    final color = classColor(p, cls.id);
    return LayoutBuilder(builder: (context, box) {
      final card = classCardRect(stage, box.maxWidth);
      return Stack(
        children: [
          // Kicker, title, subline.
          Positioned(
            left: 16,
            right: 22,
            top: 6,
            height: card.top - 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Shout('Step 2 of 5 · $pathsKicker', color: p.pink, size: 12),
                ),
                const SizedBox(height: 6),
                const FittedBox(fit: BoxFit.scaleDown, child: MegaText('Choose your path', size: 34)),
                const SizedBox(height: 6),
                Text('What do you train with?', style: mono(12.5, p.ink)),
              ],
            ),
          ),
          // Preview card: the shell draws the lifter at [stage], inside it.
          Positioned.fromRect(
            rect: card,
            child: Brutal(
              key: const ValueKey('class-card'),
              shadow: color,
              child: Padding(
                padding: EdgeInsets.fromLTRB(stage.right - card.left + 4, 10, 10, 10),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    key: ValueKey(cls.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(cls.name.toUpperCase(), style: display(26, p.ink).copyWith(shadows: [
                          Shadow(offset: const Offset(2, 2), color: color),
                        ])),
                      ),
                      const SizedBox(height: 6),
                      Text(cls.loadout, style: mono(11.5, p.ink), maxLines: 3),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final t in cls.tags) Tag(t, bg: color, fg: p.on, size: 11, angle: 0)],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: card.bottom + 14,
            bottom: 0,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 22, 8),
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(cls.style, key: ValueKey(cls.id), style: mono(12, p.ink)),
                      ),
                      const SizedBox(height: 14),
                      for (final c in gameClasses)
                        _PathButton(c: c, selected: c.id == classId, onTap: () => onPick(c.id)),
                    ],
                  ),
                ),
                _Nav(onBack: onBack, next: editing ? 'NEXT' : 'NEXT: DIFFICULTY', onNext: onNext),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// One class in the radio group: name left, equipment right.
class _PathButton extends StatelessWidget {
  const _PathButton({required this.c, required this.selected, required this.onTap});

  final GameClass c;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final color = classColor(p, c.id);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        key: ValueKey('path-${c.id}'),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : p.panel,
            border: Border.all(color: p.ink, width: selected ? 4 : 3),
            boxShadow: [BoxShadow(color: selected ? p.ink : color, offset: const Offset(4, 4))],
          ),
          child: Row(
            children: [
              Expanded(child: Text(c.name.toUpperCase(), style: display(19, selected ? p.on : p.ink))),
              Text(c.equipment.toUpperCase(), style: mono(11, selected ? p.on : p.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A body slider (0..100). [ends] (lowest · highest) shows above the slider
/// on the right; [shown] is the live value next to the label.
class _BodySlider extends StatelessWidget {
  const _BodySlider({
    required this.label,
    this.ends,
    this.shown,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? ends, shown;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Shout(label, size: 14),
            if (shown != null) ...[
              const SizedBox(width: 10),
              Text(shown!, key: ValueKey('value-$label'), style: display(16, p.lime)),
            ],
            const SizedBox(width: 10),
            Expanded(
              child: ends == null
                  ? const SizedBox()
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(ends!, style: mono(11, p.ink)),
                    ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            activeTrackColor: p.pink,
            inactiveTrackColor: p.panel2,
            thumbColor: p.lime,
            overlayColor: p.pink.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
          ),
          child: Slider(
            key: ValueKey('slider-$label'),
            value: value.toDouble(),
            max: 100,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- difficulty

/// Top of the ladder on the difficulty step (under the title block).
const _ladderTop = 92.0;

/// Rarity-ladder colour of difficulty [i] (borderlands-reference.md §4):
/// muted, lime, sky, violet, orange, pink. Harder reads as rarer.
Color difficultyColor(Pal p, int i) =>
    [const Color(0xFFC9B8E8), p.lime, p.sky, p.violet, p.orange, p.pink][i.clamp(0, 5)];

/// Difficulty [i] as a rank, e.g. "3 OF 6" (profile path row).
String gems(int i) => '${i + 1} OF ${difficulties.length}';

/// XP gems: a row of gem icons, a picture of the multiplier (no numbers).
class Gems extends StatelessWidget {
  const Gems(this.count, {super.key, this.size = 12, required this.color});

  final int count;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(padding: const EdgeInsets.only(right: 2), child: PxIcon('gem', size: size, color: color)),
        ],
      );
}

/// Where the detail card sits on the difficulty step (the freeze-frame
/// title card covers it).
Rect difficultyCardRect(Size area) {
  final ladderBottom = _ladderTop + area.height * 0.46;
  return Rect.fromLTRB(16, ladderBottom + 10, area.width - 22, area.height - 96);
}

/// Setup step 3 (docs/moodboard/README.md "Difficulty"): a six-rung ladder,
/// hardest at the top, a detail card, NEXT: STARTING AREA. Picking a rung
/// plays the freeze-frame title card (the shell shows it).
class DifficultyView extends StatelessWidget {
  const DifficultyView({
    super.key,
    required this.stage,
    required this.difficultyId,
    required this.editing,
    required this.onPick,
    required this.onBack,
    required this.onNext,
  });

  final Rect stage;
  final String difficultyId;
  final bool editing;
  final ValueChanged<String> onPick;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final sel = difficultyIndex(difficultyId);
    final d = difficulties[sel];
    final color = difficultyColor(p, sel);
    return LayoutBuilder(builder: (context, box) {
      final card = difficultyCardRect(box.biggest);
      final ladder = Rect.fromLTRB(16, _ladderTop, box.maxWidth - 22, card.top - 10);
      const rail = 10.0;
      final rung = (ladder.height - 8) / difficulties.length;
      return Stack(
        children: [
          Positioned(
            left: 16,
            right: stage.width + 26,
            top: 6,
            height: _ladderTop - 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shout('Step 3 of 5 · difficulty', color: p.pink, size: 12),
                const SizedBox(height: 6),
                const FittedBox(fit: BoxFit.scaleDown, child: MegaText('How hard do you go?', size: 30)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Pick a difficulty mode. Harder modes earn more XP.', style: mono(12, p.ink)),
                ),
              ],
            ),
          ),
          // The ladder: two rails, 6 rungs, hardest at the top.
          Positioned.fromRect(
            rect: ladder,
            child: Stack(
              children: [
                for (final left in [true, false])
                  Positioned(
                    left: left ? 0 : null,
                    right: left ? null : 0,
                    top: 0,
                    bottom: 0,
                    width: rail,
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF8A5A3B), border: Border.all(color: p.ink, width: 3)),
                    ),
                  ),
                for (var i = 0; i < difficulties.length; i++)
                  Positioned(
                    left: rail + 6,
                    right: rail + 10,
                    top: (difficulties.length - 1 - i) * rung + 4,
                    height: rung - 8,
                    child: _Rung(
                      key: ValueKey('difficulty-${difficulties[i].id}'),
                      index: i,
                      selected: i == sel,
                      onTap: () => onPick(difficulties[i].id),
                    ),
                  ),
              ],
            ),
          ),
          // Detail card.
          Positioned.fromRect(
            rect: card,
            child: Brutal(
              shadow: color,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    key: ValueKey(d.id),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(d.name.toUpperCase(), style: display(28, p.ink).copyWith(shadows: [
                          Shadow(offset: const Offset(2, 2), color: color),
                        ])),
                      ),
                      const SizedBox(height: 4),
                      Shout('Difficulty ${sel + 1} of ${difficulties.length}', color: p.pink, size: 12),
                      const SizedBox(height: 6),
                      Flexible(child: Text(d.line, style: mono(12, p.ink), overflow: TextOverflow.fade)),
                      const SizedBox(height: 6),
                      Gems(sel + 1, size: 18, color: color),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Nav(onBack: onBack, next: editing ? 'NEXT' : 'NEXT: STARTING AREA', onNext: onNext),
          ),
        ],
      );
    });
  }
}

/// One rung: a diamond in its rarity colour, the name, the XP gems.
class _Rung extends StatelessWidget {
  const _Rung({super.key, required this.index, required this.selected, required this.onTap});

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final color = difficultyColor(p, index);
    final fg = selected ? p.on : p.ink;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? color : p.panel,
            border: Border.all(color: p.ink, width: selected ? 4 : 3),
            boxShadow: [BoxShadow(color: selected ? p.pink : p.ink, offset: const Offset(4, 4))],
          ),
          child: Row(
            children: [
              Transform.rotate(
                angle: pi / 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, border: Border.all(color: p.ink, width: 2)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(difficulties[index].name.toUpperCase(), style: display(18, fg)),
                ),
              ),
              Gems(index + 1, size: 12, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- starting area

/// Title block beside the small character at the top left.
class _SideTitle extends StatelessWidget {
  const _SideTitle({required this.stage, required this.step, required this.title, required this.line});

  final Rect stage;
  final String step, title, line;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: stage.bottom + 6),
      child: Padding(
        padding: EdgeInsets.fromLTRB(stage.right + 10, stage.top + 4, 18, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shout(step, color: p.pink),
            const SizedBox(height: 6),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: MegaText(title, size: 40)),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(line, key: ValueKey(line), style: mono(12.5, p.ink), maxLines: 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Setup step 4 (docs/moodboard/README.md "Starting areas"): five areas,
/// each with its scene colours, the object to hit and the default path.
/// The class picks the default; the player can choose any area.
class AreaView extends StatelessWidget {
  const AreaView({
    super.key,
    required this.stage,
    required this.areaId,
    required this.classId,
    required this.editing,
    required this.onPick,
    required this.onBack,
    required this.onNext,
  });

  final Rect stage;
  final String areaId, classId;
  final bool editing;
  final ValueChanged<String> onPick;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SideTitle(
          stage: stage,
          step: 'Step 4 of 5',
          title: 'Where?',
          line: 'Your starting area: the look, and what you hit to log a set.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            children: [
              for (final a in areas)
                _AreaCard(
                  key: ValueKey('area-${a.id}'),
                  area: a,
                  selected: a.id == areaById(areaId).id,
                  isDefault: a.defaultFor == classId,
                  onTap: () => onPick(a.id),
                ),
            ],
          ),
        ),
        _Nav(onBack: onBack, next: editing ? 'NEXT' : 'NEXT: READY?', onNext: onNext),
      ],
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({super.key, required this.area, required this.selected, required this.isDefault, required this.onTap});

  final Area area;
  final bool selected, isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final accent = Color(area.accent);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        transform: Matrix4.translationValues(selected ? 6 : 0, 0, 0),
        decoration: BoxDecoration(
          color: selected ? accent : p.panel,
          border: Border.all(color: p.ink, width: 4),
          boxShadow: [BoxShadow(color: selected ? p.ink : accent, offset: const Offset(5, 5))],
        ),
        child: Row(
          children: [
            // Scene thumbnail from the design art (no lifter, no taps).
            SizedBox(
              width: 88,
              height: 75,
              child: FittedBox(child: AreaScene(art: areaArt[area.id]!, scale: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(area.name.toUpperCase(), style: display(19, selected ? p.on : p.ink)),
                    const SizedBox(height: 3),
                    Text(area.line, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(10.5, selected ? p.on : p.ink)),
                    if (isDefault) ...[
                      const SizedBox(height: 5),
                      Tag('Your path\'s home', bg: kNight, fg: accent, size: 11, angle: 0),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- summary

class SummaryView extends StatelessWidget {
  const SummaryView({
    super.key,
    required this.stage,
    required this.classId,
    required this.difficultyId,
    required this.areaId,
    required this.editing,
    required this.onEdit,
    required this.onBack,
    required this.onGo,
  });

  final Rect stage;
  final String classId, difficultyId, areaId;

  /// Changing an existing profile from the menu (not the first launch).
  final bool editing;

  /// Jump back to a step: 0 character, 1 class, 2 difficulty, 3 area.
  final ValueChanged<int> onEdit;
  final VoidCallback onBack, onGo;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = classById(classId);
    final d = difficulties[difficultyIndex(difficultyId)];
    final a = areaById(areaId);
    final color = classColor(p, cls.id);
    Widget row(int step, String label, String value, Color color) => InkWell(
          onTap: () => onEdit(step),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(width: 92, child: Shout(label, color: color, size: 12)),
                Expanded(child: Text(value.toUpperCase(), style: display(19, Colors.white))),
                PxIcon('edit', size: 18, color: color),
              ],
            ),
          ),
        );
    return Column(
      children: [
        SizedBox(height: stage.bottom + 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 8),
            children: [
              Center(child: Tag('Step 5 of 5 · ready?', bg: p.lime, fg: p.on, size: 18)),
              const SizedBox(height: 14),
              Brutal(
                color: kNight,
                shadow: color,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      row(1, 'Class', cls.name, color),
                      row(1, 'Gear', cls.equipment, p.sky),
                      row(2, 'Difficulty', d.name, p.pink),
                      row(3, 'Area', a.name, p.orange),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _Nav(onBack: onBack, next: editing ? 'SAVE' : "LET'S GO!!!", onNext: onGo),
      ],
    );
  }
}

// --------------------------------------------------------------- migration

/// One time, before the setup: the old app's data. A backup file is saved
/// first; only then are the old sessions turned into XP and the old kg /
/// reps data deleted (docs/data-schema.md §5).
class MigrateView extends StatelessWidget {
  const MigrateView({
    super.key,
    required this.stage,
    required this.oldWorkouts,
    required this.onUpgrade,
    required this.onLater,
  });

  final Rect stage;
  final int oldWorkouts;
  final VoidCallback onUpgrade, onLater;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      children: [
        SizedBox(height: stage.bottom + 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 8),
            children: [
              Center(child: Tag('Old save found', bg: p.orange, fg: p.on, size: 20)),
              const SizedBox(height: 16),
              Terminal([
                '$oldWorkouts OLD WORKOUT DAYS FOUND.',
                'THEY BECOME XP: +$xpPerLegacySession EACH (BETA).',
                'THE OLD KG AND REPS DATA GETS DELETED.',
                'FIRST: SAVE A BACKUP FILE. NO FILE, NO CHANGE.',
              ]),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 22, 14 + MediaQuery.paddingOf(context).bottom),
          child: Row(
            children: [
              BrutalButton(color: p.sky, onTap: onLater, child: const Text('NOT NOW')),
              const SizedBox(width: 14),
              Expanded(
                child: BrutalButton(
                  color: p.pink,
                  onTap: onUpgrade,
                  child: Text('SAVE BACKUP & UPGRADE', textAlign: TextAlign.center, style: display(19, p.on)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
