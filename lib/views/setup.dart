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
import 'carousel.dart';
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
              // An outline box marks the head: tap it for the head looks.
              if (!headOpen)
                Positioned.fromRect(
                  // Ends at the chin, so the shoulders do not hide its bottom edge.
                  rect: Rect.fromLTRB(head.left - 4, head.top - 4, head.right + 4, head.bottom),
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('head-outline'),
                      decoration: BoxDecoration(border: Border.all(color: p.lime, width: 3)),
                    ),
                  ),
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
        const SizedBox(height: 10),
        _BodySlider(
          label: 'HEIGHT',
          shown: '${heightMetres(character.height).toStringAsFixed(2)} M',
          value: character.height,
          onChanged: (v) => onCharacter(character.copyWith(height: v)),
        ),
        _BodySlider(
          label: 'WEIGHT',
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

/// Room under the class card: the dots row, the difficulty slider and the
/// BACK / NEXT row.
const _classDotsHeight = 30.0, _classDifficultyHeight = 74.0, _classNavHeight = 92.0;

/// Top of the setup cards (class, area): no title block above them.
const _setupCardTop = 8.0;

/// Room the class texts keep under the lifter (name to description).
const _classTextMin = 150.0;

/// The class card and, inside it, where the shell draws the lifter, in a
/// view of [area] with [bottomInset] (the phone's navigation bar).
/// The lifter gets the biggest whole-number scale that leaves
/// [_classTextMin] for the texts, and the stage is cut to that size, so
/// there is no empty band above the head.
({Rect card, Rect stage}) classLayout(Size area, double bottomInset) {
  final card = Rect.fromLTRB(16, _setupCardTop, area.width - 22,
      area.height - bottomInset - _classNavHeight - _classDifficultyHeight - _classDotsHeight);
  // CharacterSprite: pedestal = 10% of the box, the sprite gets the rest
  // minus half of it, at most spriteHeight × maxHeightScale × scale.
  const perScale = spriteHeight * maxHeightScale / 0.945;
  final avail = card.height - 16 - _classTextMin;
  final byWidth = (card.width - 24) / spriteWidth;
  final scale = max(2, min(byWidth, avail / perScale).floor());
  final stage = Rect.fromLTWH(card.left + 12, card.top + 8, card.width - 24, min(avail, perScale * scale + 2));
  return (card: card, stage: stage);
}

/// Setup step 2 (docs/moodboard/README.md "Class select", D46, D47): one
/// big card with the lifter, the class name, the equipment, the loadout,
/// 3 tags and the description. Swipe the card to change the class, both
/// ways, round and round. Dots show where you are. Under them, the
/// DIFFICULTY slider (6 modes) with the mode name on the right.
class ClassView extends StatefulWidget {
  const ClassView({
    super.key,
    required this.stage,
    required this.classId,
    required this.difficultyId,
    required this.onPick,
    required this.onDifficulty,
    required this.onBack,
    required this.onNext,
    required this.editing,
  });

  final Rect stage;
  final String classId, difficultyId;
  final ValueChanged<String> onPick, onDifficulty;
  final VoidCallback onBack, onNext;
  final bool editing;

  @override
  State<ClassView> createState() => _ClassViewState();
}

class _ClassViewState extends State<ClassView> with SwipeCarousel<ClassView> {
  @override
  int get count => gameClasses.length;

  @override
  int get index => max(0, gameClasses.indexWhere((c) => c.id == widget.classId));

  @override
  void select(int i) => widget.onPick(gameClasses[i].id);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = classById(widget.classId);
    final color = classColor(p, cls.id);
    final di = difficultyIndex(widget.difficultyId);
    final dColor = difficultyColor(p, di);
    return LayoutBuilder(builder: (context, box) {
      final card = classLayout(box.biggest, MediaQuery.paddingOf(context).bottom).card;
      final stage = widget.stage;
      return Stack(
        children: [
          // The card: the shell draws the lifter at [stage], at its top.
          Positioned.fromRect(
            rect: card,
            child: swipe(
              key: const ValueKey('class-card'),
              child: Brutal(
                shadow: color,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: stage.bottom - card.top),
                    Expanded(child: slide(cls.id, _ClassText(cls: cls, color: color))),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: card.bottom + 8,
            height: _classDotsHeight - 8,
            child: CarouselDots(
              prefix: 'class',
              ids: [for (final c in gameClasses) c.id],
              names: [for (final c in gameClasses) c.name],
              current: cls.id,
              colorOf: (id) => classColor(p, id),
              onTap: jump,
            ),
          ),
          // Difficulty (D47): 6 modes, the current one named on the right.
          Positioned(
            left: 16,
            right: 22,
            top: card.bottom + _classDotsHeight,
            height: _classDifficultyHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Shout('Difficulty', size: 14),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(difficulties[di].name.toUpperCase(),
                            key: const ValueKey('value-DIFFICULTY'), style: display(16, dColor)),
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 10,
                    activeTrackColor: dColor,
                    inactiveTrackColor: p.panel2,
                    thumbColor: p.lime,
                    overlayColor: dColor.withValues(alpha: 0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                    tickMarkShape: SliderTickMarkShape.noTickMark,
                  ),
                  child: Slider(
                    key: const ValueKey('slider-DIFFICULTY'),
                    value: di.toDouble(),
                    max: difficulties.length - 1.0,
                    divisions: difficulties.length - 1,
                    onChanged: (v) => widget.onDifficulty(difficulties[v.round()].id),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Nav(onBack: widget.onBack, next: widget.editing ? 'NEXT' : 'NEXT: STARTING AREA', onNext: widget.onNext),
          ),
        ],
      );
    });
  }
}

/// The texts of one class in the card: name, equipment, loadout, tags,
/// description. Scrolls if the phone is short.
class _ClassText extends StatelessWidget {
  const _ClassText({required this.cls, required this.color});

  final GameClass cls;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(cls.name.toUpperCase(), style: display(30, p.ink).copyWith(shadows: [
              Shadow(offset: const Offset(2, 2), color: color),
            ])),
          ),
          const SizedBox(height: 2),
          Text(cls.equipment.toUpperCase(), style: display(15, color).copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(cls.loadout, style: mono(11.5, p.ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in cls.tags) Tag(t, bg: color, fg: p.on, size: 11, angle: 0)],
          ),
          const SizedBox(height: 10),
          Text(cls.style, style: mono(12, p.ink)),
        ],
      ),
    );
  }
}

/// A body slider (0..100). [shown] is the current value, above the slider
/// on the right.
class _BodySlider extends StatelessWidget {
  const _BodySlider({
    required this.label,
    this.shown,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? shown;
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
            if (shown != null) Text(shown!, key: ValueKey('value-$label'), style: display(16, p.lime)),
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

// ----------------------------------------------------------- starting area

/// Room under the area card: the dots row and the BACK / NEXT row.
const _areaDotsHeight = 30.0;

/// The area card, the scene in it (whole-number scale) and where the shell
/// draws the lifter (standing in the scene, like on the hub). The scene
/// fills the top of the card edge to edge; at most 24 px a side are cut
/// off to reach the next whole-number scale (crop the sides, never stretch).
({Rect card, Rect scene, int scale, Rect stage}) areaLayout(Size area, double bottomInset) {
  final card = Rect.fromLTRB(16, _setupCardTop, area.width - 22, area.height - bottomInset - _classNavHeight - _areaDotsHeight);
  // Inside the card's 4 px border.
  final avail = Rect.fromLTWH(card.left + 4, card.top + 4, card.width - 8, card.height * 0.62);
  final scale = max(1, min((avail.width + 48) / sceneSize.width, avail.height / sceneSize.height).floor());
  final scene = sceneRectIn(avail, scale);
  return (card: card, scene: scene, scale: scale, stage: sceneLifterRect(areaArt.values.first, scene, scale));
}

/// Setup step 3 (docs/moodboard/README.md "Starting areas", D47): one big
/// card like the class card: the area's scene with the lifter in it, then
/// the name, the line, what you hit and the default-path tag. Swipe the
/// card to change the area, both ways, round and round. Dots show where
/// you are. The class picks the default; the player can choose any area.
class AreaView extends StatefulWidget {
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
  State<AreaView> createState() => _AreaViewState();
}

class _AreaViewState extends State<AreaView> with SwipeCarousel<AreaView> {
  @override
  int get count => areas.length;

  @override
  int get index => max(0, areas.indexWhere((a) => a.id == areaById(widget.areaId).id));

  @override
  void select(int i) => widget.onPick(areas[i].id);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final a = areaById(widget.areaId);
    final accent = Color(a.accent);
    return LayoutBuilder(builder: (context, box) {
      final l = areaLayout(box.biggest, MediaQuery.paddingOf(context).bottom);
      return Stack(
        children: [
          Positioned.fromRect(
            rect: l.card,
            child: swipe(
              key: const ValueKey('area-card'),
              child: Brutal(
                shadow: accent,
                child: slide(
                  a.id,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The scene, edge to edge (the shell draws the lifter in it).
                      Container(
                        height: l.scene.height + 3,
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.ink, width: 3))),
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: l.scene.width,
                            maxWidth: l.scene.width,
                            child: AreaScene(art: areaArt[a.id]!, scale: l.scale),
                          ),
                        ),
                      ),
                      Expanded(child: _AreaText(area: a, isDefault: a.defaultFor == widget.classId)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: l.card.bottom + 8,
            height: _areaDotsHeight - 8,
            child: CarouselDots(
              prefix: 'area',
              ids: [for (final x in areas) x.id],
              names: [for (final x in areas) x.name],
              current: a.id,
              colorOf: (id) => Color(areaById(id).accent),
              onTap: jump,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Nav(onBack: widget.onBack, next: widget.editing ? 'NEXT' : 'NEXT: READY?', onNext: widget.onNext),
          ),
        ],
      );
    });
  }
}

/// The texts of one area in the card: name, line, what you hit, and the
/// default-path tag. Scrolls if the phone is short.
class _AreaText extends StatelessWidget {
  const _AreaText({required this.area, required this.isDefault});

  final Area area;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final accent = Color(area.accent);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(area.name.toUpperCase(), style: display(30, p.ink).copyWith(shadows: [
              Shadow(offset: const Offset(2, 2), color: accent),
            ])),
          ),
          const SizedBox(height: 6),
          Text(area.line, style: mono(12, p.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(area.hint, bg: kNight, fg: accent, size: 12, angle: 0),
              if (isDefault) Tag('Your path\'s home', bg: accent, fg: p.on, size: 12, angle: 0),
            ],
          ),
        ],
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

  /// Jump back to a step: 0 character, 1 class and difficulty, 2 area.
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
              Center(child: Tag('Step 4 of 4 · ready?', bg: p.lime, fg: p.on, size: 18)),
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
                      row(1, 'Difficulty', d.name, p.pink),
                      row(2, 'Area', a.name, p.orange),
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
