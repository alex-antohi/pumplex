// Initial setup: character + class, difficulty, starting area, summary.
// The character itself is drawn by the shell (one sprite for the whole app);
// these views leave room for it at the [stage] rect.

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../pumplex.dart';
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
            BrutalButton(color: p.sky, onTap: onBack, child: const Text('◀ BACK')),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: BrutalButton(
              color: p.pink,
              onTap: onNext,
              child: Text(next, textAlign: TextAlign.center, style: display(24, p.on)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ character creation

/// WoW-style character screen (setup step 1): the character large in the
/// centre, the options around it, everything changes live.
class CreateView extends StatelessWidget {
  const CreateView({
    super.key,
    required this.stage,
    required this.character,
    required this.onCharacter,
    required this.onNext,
  });

  final Rect stage;
  final Character character;
  final ValueChanged<Character> onCharacter;
  final VoidCallback onNext;

  void _random() {
    final r = Random();
    onCharacter(Character(
      sex: r.nextBool() ? 'male' : 'female',
      height: r.nextInt(101),
      muscle: r.nextInt(101),
      fat: r.nextInt(101),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget sexButton(String sex, String label) {
      final on = character.sex == sex;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BrutalButton(
          small: true,
          color: on ? p.pink : p.panel,
          onTap: () => onCharacter(character.copyWith(sex: sex)),
          child: SizedBox(width: 34, child: Text(label, textAlign: TextAlign.center, style: display(24, on ? p.on : p.ink))),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: stage.bottom,
          child: Stack(
            children: [
              Positioned(
                left: 14,
                top: stage.top + 6,
                child: Column(children: [sexButton('male', '♂'), sexButton('female', '♀')]),
              ),
              Positioned(
                right: 18,
                top: stage.top + 6,
                child: BrutalButton(small: true, color: p.orange, onTap: _random, child: const Text('🎲')),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 22, 8),
            children: [
              Shout('Build your lifter', size: 14, color: p.pink),
              const SizedBox(height: 10),
              _BodySlider(
                label: 'HEIGHT',
                low: 'SHORT',
                high: 'TALL',
                value: character.height,
                onChanged: (v) => onCharacter(character.copyWith(height: v)),
              ),
              _BodySlider(
                label: 'MUSCLE',
                low: 'NOODLE',
                high: 'BOULDER',
                value: character.muscle,
                onChanged: (v) => onCharacter(character.copyWith(muscle: v)),
              ),
              _BodySlider(
                label: 'FAT %',
                low: 'SHREDDED',
                high: 'COZY',
                value: character.fat,
                onChanged: (v) => onCharacter(character.copyWith(fat: v)),
              ),
            ],
          ),
        ),
        _Nav(next: 'NEXT ▶', onNext: onNext),
      ],
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
                _Nav(onBack: onBack, next: editing ? 'NEXT ▶' : 'NEXT: DIFFICULTY', onNext: onNext),
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

class _BodySlider extends StatelessWidget {
  const _BodySlider({
    required this.label,
    required this.low,
    required this.high,
    required this.value,
    required this.onChanged,
  });

  final String label, low, high;
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
            const Spacer(),
            Text('$low · $high', style: mono(11, p.ink)),
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

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.selected,
    required this.color,
    required this.title,
    required this.line,
    required this.onTap,
    this.leading,
    this.trailing,
  });

  final bool selected;
  final Color color;
  final String title, line;
  final VoidCallback onTap;
  final String? leading, trailing;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        transform: Matrix4.translationValues(selected ? 6 : 0, 0, 0),
        decoration: BoxDecoration(
          color: selected ? color : p.panel,
          border: Border.all(color: p.ink, width: 4),
          boxShadow: [BoxShadow(color: selected ? p.ink : color, offset: const Offset(5, 5))],
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              Text(leading!, style: display(22, selected ? p.on : p.ink)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: display(20, selected ? p.on : p.ink)),
                  const SizedBox(height: 3),
                  Text(line, style: mono(11.5, selected ? p.on : p.ink)),
                ],
              ),
            ),
            if (trailing != null) Text(trailing!, style: display(15, selected ? p.on : p.ink)),
          ],
        ),
      ),
    );
  }
}

class DifficultyView extends StatelessWidget {
  const DifficultyView({
    super.key,
    required this.stage,
    required this.difficultyId,
    required this.onPick,
    required this.onBack,
    required this.onNext,
  });

  final Rect stage;
  final String difficultyId;
  final ValueChanged<String> onPick;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final sel = difficultyIndex(difficultyId);
    return Column(
      children: [
        _SideTitle(
          stage: stage,
          step: 'Step 3 of 5',
          title: 'How hard?',
          line: 'From never lifted to years of iron. Harder means more XP.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            children: [
              for (var i = 0; i < difficulties.length; i++)
                _Choice(
                  key: ValueKey('difficulty-${difficulties[i].id}'),
                  selected: i == sel,
                  color: p.accents[i % p.accents.length],
                  leading: '${i + 1}',
                  title: difficulties[i].name,
                  line: difficulties[i].line,
                  trailing: '${rulesFor(i).exercisesPerWorkout} EX\n×${rulesFor(i).xpMultiplier} XP',
                  onTap: () => onPick(difficulties[i].id),
                ),
            ],
          ),
        ),
        _Nav(onBack: onBack, next: 'NEXT ▶', onNext: onNext),
      ],
    );
  }
}

// ----------------------------------------------------------- starting area

class AreaView extends StatelessWidget {
  const AreaView({
    super.key,
    required this.stage,
    required this.areaId,
    required this.onPick,
    required this.onBack,
    required this.onNext,
  });

  final Rect stage;
  final String areaId;
  final ValueChanged<String> onPick;
  final VoidCallback onBack, onNext;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      children: [
        _SideTitle(
          stage: stage,
          step: 'Step 4 of 5',
          title: 'Where?',
          line: 'Your starting area. More worlds come later.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            children: [
              for (final (i, a) in areas.indexed)
                _Choice(
                  key: ValueKey('area-${a.id}'),
                  selected: a.id == areaById(areaId).id,
                  color: i.isEven ? p.sky : p.violet,
                  leading: a.icon,
                  title: a.name,
                  line: a.line,
                  onTap: () => onPick(a.id),
                ),
              const SizedBox(height: 6),
              const Terminal(['MORE AREAS: BEING BUILT BY THE DESIGN TEAM.', 'BRING SNACKS.']),
            ],
          ),
        ),
        _Nav(onBack: onBack, next: 'NEXT ▶', onNext: onNext),
      ],
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
    Widget row(int step, String label, String value, Color color) => InkWell(
          onTap: () => onEdit(step),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(width: 92, child: Shout(label, color: color, size: 12)),
                Expanded(child: Text(value.toUpperCase(), style: display(19, Colors.white))),
                Text('✎', style: display(18, color)),
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
                shadow: classColor(p, cls.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      row(1, 'Class', '${cls.icon} ${cls.name}', classColor(p, cls.id)),
                      row(1, 'Gear', cls.equipment, p.sky),
                      row(2, 'Difficulty', d.name, p.pink),
                      row(3, 'Area', '${a.icon} ${a.name}', p.orange),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _Nav(onBack: onBack, next: editing ? 'SAVE ✔' : "LET'S GO!!!", onNext: onGo),
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
