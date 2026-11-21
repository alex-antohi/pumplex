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

/// WoW-style character screen: the character large in the centre, the
/// options around it, everything changes live.
class CreateView extends StatelessWidget {
  const CreateView({
    super.key,
    required this.stage,
    required this.character,
    required this.classId,
    required this.onCharacter,
    required this.onClass,
    required this.onNext,
  });

  final Rect stage;
  final Character character;
  final String classId;
  final ValueChanged<Character> onCharacter;
  final ValueChanged<String> onClass;
  final VoidCallback onNext;

  void _random() {
    final r = Random();
    onCharacter(Character(
      sex: r.nextBool() ? 'male' : 'female',
      height: r.nextInt(101),
      muscle: r.nextInt(101),
      fat: r.nextInt(101),
    ));
    onClass(gameClasses[r.nextInt(gameClasses.length)].id);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = classById(classId);
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
                child: BrutalButton(
                  small: true,
                  color: p.orange,
                  onTap: _random,
                  child: const Text('🎲'),
                ),
              ),
            ],
          ),
        ),
        // Name tag under the character.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: child),
          ),
          child: Container(
            key: ValueKey(cls.id),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kNight,
              border: Border.all(color: classColor(p, cls.id), width: 2),
            ),
            child: Column(
              children: [
                Text(cls.name.toUpperCase(), style: display(22, classColor(p, cls.id))),
                const SizedBox(height: 2),
                Text(cls.style, style: mono(11.5, Colors.white)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 22, 8),
            children: [
              Shout('What do you train with?', size: 14),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final c in gameClasses)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ClassIcon(c: c, selected: c.id == classId, onTap: () => onClass(c.id)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
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

class _ClassIcon extends StatelessWidget {
  const _ClassIcon({required this.c, required this.selected, required this.onTap});

  final GameClass c;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final color = classColor(p, c.id);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : p.panel,
          border: Border.all(color: p.ink, width: selected ? 4 : 3),
          boxShadow: [BoxShadow(color: selected ? p.ink : color, offset: const Offset(4, 4))],
        ),
        child: Column(
          children: [
            Text(c.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 2),
            FittedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(c.short, style: display(11, selected ? p.on : p.ink)),
              ),
            ),
          ],
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
          step: 'Step 2 of 4',
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
          step: 'Step 3 of 4',
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

  /// Jump back to a step: 0 character/class, 1 difficulty, 2 area.
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
              Center(child: Tag('Step 4 of 4 · ready?', bg: p.lime, fg: p.on, size: 18)),
              const SizedBox(height: 14),
              Brutal(
                color: kNight,
                shadow: classColor(p, cls.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      row(0, 'Class', '${cls.icon} ${cls.name}', classColor(p, cls.id)),
                      row(0, 'Gear', cls.equipment, p.sky),
                      row(1, 'Difficulty', d.name, p.pink),
                      row(2, 'Area', '${a.icon} ${a.name}', p.orange),
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
