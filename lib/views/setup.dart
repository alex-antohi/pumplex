// Initial setup: character + class, difficulty, starting area, summary.
// The character itself is drawn by the shell (one sprite for the whole app);
// these views leave room for it at the [stage] rect.

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/area_art.dart';
import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../i18n.dart';
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
    return ActionBar(
      padding: _setupBarPadding(context),
      back: onBack == null ? null : BrutalButton(color: p.sky, onTap: onBack, child: IconText('back', t('nav.back'))),
      main: BrutalButton(
        color: p.pink,
        onTap: onNext,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(next, maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: display(24, p.on)),
        ),
      ),
    );
  }
}

/// The padding of the setup screens' bottom bar (over the phone's bar).
EdgeInsets _setupBarPadding(BuildContext context) =>
    EdgeInsets.fromLTRB(16, 8, 22, 14 + MediaQuery.paddingOf(context).bottom);

/// A small square toggle beside the body card: the sex buttons on the
/// left, the language buttons on the right. [onColor] fills it when on.
class _SideToggle extends StatelessWidget {
  const _SideToggle({required this.id, required this.on, required this.onColor, required this.onTap, required this.child});

  /// The key of the button (`sex-<sex>`, `lang-<lang>`).
  final String id;
  final bool on;
  final Color onColor;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BrutalButton(
        key: ValueKey(id),
        small: true,
        color: on ? onColor : p.panel,
        onTap: onTap,
        child: SizedBox(width: 34, height: 26, child: Center(child: child)),
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
    this.buttons = true,
    this.onSlideEnd,
  });

  final Rect stage;
  final Character character;
  final ValueChanged<Character> onCharacter;
  final VoidCallback onNext;

  /// False when editing the lifter under the minimised workout (D60): no
  /// NEXT / DONE row; tap the head again to close the head looks.
  final bool buttons;

  /// A slider drag ended (the lifter editor saves then, D60).
  final VoidCallback? onSlideEnd;

  /// The head looks panel is open (the shell zooms the character in).
  final bool headOpen;
  final ValueChanged<bool> onHead;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final head = headRect(spriteGeometry(stage.size, character.height).sprite).shift(stage.topLeft);
    // Inside the card: its border starts at (20, 12) in the view.
    const o = Offset(-20, -12);
    final card = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 8),
      // The body editor is a card (D63) as tall as its content (D64).
      child: Brutal(
        key: const ValueKey('body-card'),
        shadow: p.pink,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: stage.bottom - 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: headOpen ? _headPanel(p) : _bodyPanel(p),
                  ),
                ),
              ],
            ),
            if (!headOpen)
              Positioned(
                left: 10,
                top: stage.top - 6,
                child: Column(children: [
                  for (final sex in ['male', 'female'])
                    _SideToggle(
                      id: 'sex-$sex',
                      on: character.sex == sex,
                      onColor: p.pink,
                      onTap: () => onCharacter(character.copyWith(sex: sex)),
                      child: PxIcon(sex, size: 24, color: character.sex == sex ? p.on : p.ink),
                    ),
                ]),
              ),
            if (!headOpen)
              Positioned(
                right: 10,
                top: stage.top - 6,
                // The language (D68): EN / RO on the right, like the sex
                // buttons on the left.
                child: Semantics(
                  label: t('lang.label'),
                  child: Column(children: [
                    for (final l in I18n.languages)
                      _SideToggle(
                        id: 'lang-$l',
                        on: I18n.instance.language == l,
                        onColor: p.lime,
                        onTap: () => switchLanguage(l),
                        child: Text(l.toUpperCase(), style: display(17, I18n.instance.language == l ? p.on : p.ink)),
                      ),
                  ]),
                ),
              ),
            // An outline box marks the head: tap it for the head looks.
            if (!headOpen)
              Positioned.fromRect(
                // Ends at the chin, so the shoulders do not hide its bottom edge.
                rect: Rect.fromLTRB(head.left - 4, head.top - 4, head.right + 4, head.bottom).shift(o),
                child: IgnorePointer(
                  child: Container(
                    key: const ValueKey('head-outline'),
                    decoration: BoxDecoration(border: Border.all(color: p.lime, width: 3)),
                  ),
                ),
              ),
            // Tap the head to open (or close) the head looks.
            Positioned.fromRect(
              rect: (headOpen ? stage : head.inflate(8)).shift(o),
              child: GestureDetector(
                key: const ValueKey('creator-head'),
                behavior: HitTestBehavior.translucent,
                onTap: () => onHead(!headOpen),
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              // In the lifter editor the vertical drag belongs to the carousel (D63).
              physics: buttons ? null : const NeverScrollableScrollPhysics(),
              child: card,
            ),
          ),
        ),
        // NEXT names the next screen (D65).
        if (buttons) _Nav(next: headOpen ? t('nav.done') : t('nav.nextClass'), onNext: headOpen ? () => onHead(false) : onNext),
      ],
    );
  }

  List<Widget> _bodyPanel(Pal p) => [
        Shout(t('body.title'), size: 14, color: p.pink),
        const SizedBox(height: 10),
        _BodySlider(
          id: 'HEIGHT',
          label: t('body.height'),
          shown: t('body.heightValue', {'m': decimal(heightMetres(character.height), 2)}),
          value: character.height,
          onChanged: (v) => onCharacter(character.copyWith(height: v)),
          onChangeEnd: (_) => onSlideEnd?.call(),
        ),
        _BodySlider(
          id: 'WEIGHT',
          label: t('body.weight'),
          shown: t('body.weightValue', {'kg': weightKg(character.fat)}),
          value: character.fat,
          onChanged: (v) => onCharacter(character.copyWith(fat: v)),
          onChangeEnd: (_) => onSlideEnd?.call(),
        ),
        _BodySlider(
          id: 'MUSCLE',
          label: t('body.muscle'),
          value: character.muscle,
          onChanged: (v) => onCharacter(character.copyWith(muscle: v)),
          onChangeEnd: (_) => onSlideEnd?.call(),
        ),
      ];

  List<Widget> _headPanel(Pal p) {
    Widget row(String title, String kind, List<Look> looks, String current, Character Function(String) pick) => ChipSection(
          title: title,
          titleSize: 14,
          gap: 8,
          spacing: 12,
          bottom: 14,
          children: [
            for (final l in looks)
              _LookButton(
                key: ValueKey('look-$kind-${l.id}'),
                look: l,
                on: l.id == current,
                onTap: () => onCharacter(pick(l.id)),
              ),
          ],
        );
    return [
      Shout(t('head.title'), size: 14, color: p.pink),
      const SizedBox(height: 10),
      row(t('head.skin'), 'skin', skinLooks, character.skin, (id) => character.copyWith(skin: id)),
      row(t('head.hair'), 'hair', hairLooks, character.hair, (id) => character.copyWith(hair: id)),
      row(t('head.facial'), 'facial', facialHairLooks, character.facialHair, (id) => character.copyWith(facialHair: id)),
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

/// The class screen, top to bottom: the difficulty card, the class card,
/// the dots row and the BACK / NEXT row.
const _classDotsHeight = 30.0, _classDifficultyHeight = 128.0, _classNavHeight = 92.0;

/// Top of the setup cards (class, area): no title block above them.
const _setupCardTop = 8.0;

/// Gap between the difficulty card (with its shadow) and the class card.
const _classCardGap = 6.0;

/// Height of the class info at the bottom of the class card (name and
/// equipment, with room around them).
const classTextHeight = 112.0;

/// The class card and, inside it, where the shell draws the lifter, in a
/// view of [area] with [bottomInset] (the phone's navigation bar).
/// The card starts under the difficulty card; the dots sit under it.
/// The lifter gets the biggest whole-number scale that leaves
/// [classTextHeight] for the texts, and the stage is cut to that size, so
/// there is no empty band above the head.
/// [buttons] false: no BACK / NEXT row under it (the lifter editor, D60).
({Rect card, Rect stage}) classLayout(Size area, double bottomInset, {bool buttons = true}) {
  final card = Rect.fromLTRB(16, _setupCardTop + _classDifficultyHeight + _classCardGap, area.width - 22,
      area.height - bottomInset - (buttons ? _classNavHeight : 8) - _classDotsHeight);
  // CharacterSprite: pedestal = 10% of the box, the sprite gets the rest
  // minus half of it, at most spriteHeight × maxHeightScale × scale.
  const perScale = spriteHeight * maxHeightScale / 0.945;
  final avail = card.height - 12 - classTextHeight;
  final byWidth = (card.width - 24) / spriteWidth;
  final scale = max(2, min(byWidth, avail / perScale).floor());
  // The lifter stands right on the class info at the bottom (D64).
  final h = min(avail, perScale * scale + 2);
  final stage = Rect.fromLTWH(card.left + 12, card.top + 8 + avail - h, card.width - 24, h);
  return (card: card, stage: stage);
}

/// Setup step 2 (docs/moodboard/README.md "Class select", D46, D47): on
/// top, the DIFFICULTY card (6 modes): the mode name on the right, who it
/// is for, the slider. Under it one big card with the lifter, the class
/// name and the equipment. Swipe the card to change the class, both ways,
/// round and round. Dots under it show where you are.
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
    this.buttons = true,
  });

  final Rect stage;
  final String classId, difficultyId;
  final ValueChanged<String> onPick, onDifficulty;
  final VoidCallback onBack, onNext;
  final bool editing;

  /// False when editing the lifter under the minimised workout (D60).
  final bool buttons;

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
    return LayoutBuilder(builder: (context, box) {
      final card = classLayout(box.biggest, MediaQuery.paddingOf(context).bottom, buttons: widget.buttons).card;
      return Stack(
        children: [
          // Difficulty (D47): 6 modes, the current one named on the right, who
          // the mode is for, then the slider. In a card on top (D74).
          Positioned(
            left: 16,
            right: 22,
            top: _setupCardTop,
            height: _classDifficultyHeight - 8,
            child: DifficultyCard(
              index: di,
              onChanged: (i) => widget.onDifficulty(difficulties[i].id),
            ),
          ),
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
                    // The lifter fills the top; the class info sits at the bottom (D64).
                    const Spacer(),
                    SizedBox(
                      height: classTextHeight,
                      child: slide(cls.id, ClassCardText(cls: cls, color: color)),
                    ),
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
          if (widget.buttons)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Nav(onBack: widget.onBack, next: widget.editing ? t('nav.next') : t('nav.nextArea'), onNext: widget.onNext),
            ),
        ],
      );
    });
  }
}

/// The texts of one class in the card: the name and the equipment, big,
/// with room around them.
class ClassCardText extends StatelessWidget {
  const ClassCardText({super.key, required this.cls, required this.color});

  final GameClass cls;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShadowTitle(cls.name.toUpperCase(), size: 38, shadowColor: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(cls.equipment.toUpperCase(), style: display(20, color).copyWith(letterSpacing: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// The difficulty card (D47, D74): the mode name on the right, who the mode
/// is for, then the slider over the 6 modes. Give it a height (120 on the
/// class screen).
class DifficultyCard extends StatelessWidget {
  const DifficultyCard({super.key, required this.index, required this.onChanged});

  /// The difficulty shown (0..5).
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final di = index;
    final dColor = difficultyColor(p, di);
    return Brutal(
      key: const ValueKey('difficulty-card'),
      shadow: dColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Shout(t('label.difficulty'), size: 14),
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
            const SizedBox(height: 4),
            Text(
              difficulties[di].line,
              key: const ValueKey('difficulty-line'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: mono(11.5, p.ink),
            ),
            const Spacer(),
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
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A body slider (0..100). [shown] is the current value, above the slider
/// on the right.
class _BodySlider extends StatelessWidget {
  const _BodySlider({
    required this.id,
    required this.label,
    this.shown,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  /// The same in every language (the widget keys use it).
  final String id;
  final String label;
  final String? shown;
  final int value;
  final ValueChanged<int> onChanged;

  /// The drag ended (the editors save then, D60).
  final ValueChanged<int>? onChangeEnd;

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
            if (shown != null) Text(shown!, key: ValueKey('value-$id'), style: display(16, p.lime)),
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
            key: ValueKey('slider-$id'),
            value: value.toDouble(),
            max: 100,
            onChanged: (v) => onChanged(v.round()),
            onChangeEnd: onChangeEnd == null ? null : (v) => onChangeEnd!(v.round()),
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
    [p.muted, p.lime, p.sky, p.violet, p.orange, p.pink][i.clamp(0, 5)];

// ----------------------------------------------------------- starting area

/// Room under the area card: the dots row and the BACK / NEXT row.
const _areaDotsHeight = 30.0;

/// Height of the texts at the bottom of the area card (name, home tag).
const _areaTextHeight = 92.0;

/// The art-pixel span (left, right) that holds the lifter, the object and all
/// marks of every area: it must stay visible in the area card.
final (double, double) _areaContentSpan = () {
  var l = 6.0, r = 58.0;
  for (final a in areaArt.values) {
    final rects = <Rect>[
      Rect.fromLTWH(a.lifterPos.dx, a.lifterPos.dy, 52, 64),
      a.objectPos & a.objectSize,
      for (final m in a.markPositions) ...[
        m & a.mark.size,
        if (a.markFifth != null) m & a.markFifth!.size,
      ],
    ];
    for (final q in rects) {
      l = min(l, q.left);
      r = max(r, q.right);
    }
  }
  return (l, r);
}();

/// The area card, the scene in it (fractional scale) and where the shell
/// draws the lifter (standing in the scene, like on the hub). The arena
/// fills the card above the texts (D63): the biggest whole-number scale for
/// that height, the sides cut off if it is wider (crop, never stretch),
/// standing on the texts; the sky colour fills any room above it.
({Rect card, Rect arena, Rect scene, double scale, Rect stage}) areaLayout(Size area, double bottomInset, {bool buttons = true}) {
  final card = Rect.fromLTRB(16, _setupCardTop, area.width - 22,
      area.height - bottomInset - (buttons ? _classNavHeight : 8) - _areaDotsHeight);
  // Inside the card's 4 px border, above the texts.
  final arena = Rect.fromLTRB(card.left + 4, card.top + 4, card.right - 4, card.bottom - 4 - _areaTextHeight);
  // The sides may be cropped, but never the lifter, the object or a mark of
  // any area: the scale is capped so that span stays inside the arena.
  final (spanL, spanR) = _areaContentSpan;
  final scale = min(arena.height / sceneSize.height, arena.width / (spanR - spanL));
  final w = sceneSize.width * scale, h = sceneSize.height * scale;
  final left = w >= arena.width
      ? (arena.center.dx - (spanL + spanR) / 2 * scale).clamp(arena.right - w, arena.left).toDouble()
      : arena.center.dx - w / 2;
  final scene = Rect.fromLTWH(left, arena.bottom - h, w, h);
  return (card: card, arena: arena, scene: scene, scale: scale, stage: sceneLifterRect(areaArt.values.first, scene, scale));
}

/// Setup step 3 (docs/moodboard/README.md "Starting areas", D47): one big
/// card like the class card: the area's scene with the lifter in it, then
/// the name and the default-path tag. Swipe the
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
    this.buttons = true,
  });

  final Rect stage;
  final String areaId, classId;
  final bool editing;
  final ValueChanged<String> onPick;
  final VoidCallback onBack, onNext;

  /// False when editing the lifter under the minimised workout (D60).
  final bool buttons;

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
      final l = areaLayout(box.biggest, MediaQuery.paddingOf(context).bottom, buttons: widget.buttons);
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
                      // The arena fills the card (the shell draws the lifter in it).
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(a.sky),
                            border: Border(bottom: BorderSide(color: p.ink, width: 3)),
                          ),
                          child: ClipRect(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: l.scene.left - l.arena.left,
                                  bottom: 0,
                                  width: l.scene.width,
                                  height: l.scene.height + 160 * l.scale,
                                  child: Column(
                                    children: [
                                      // Optional sky strip above the scene (175 x 160 base).
                                      Image.asset(
                                        'assets/areas/${a.id}/sky.png',
                                        width: l.scene.width,
                                        height: 160 * l.scale,
                                        fit: BoxFit.fill,
                                        filterQuality: FilterQuality.none,
                                        isAntiAlias: false,
                                        gaplessPlayback: true,
                                        excludeFromSemantics: true,
                                        errorBuilder: (_, _, _) => SizedBox(height: 160 * l.scale),
                                      ),
                                      AreaScene(art: areaArt[a.id]!, scale: l.scale),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // The title and the subtext at the bottom.
                      SizedBox(
                        height: _areaTextHeight - 3,
                        child: _AreaText(area: a, isDefault: a.defaultFor == widget.classId),
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
          if (widget.buttons)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Nav(onBack: widget.onBack, next: widget.editing ? t('nav.next') : t('nav.nextReady'), onNext: widget.onNext),
            ),
        ],
      );
    });
  }
}

/// The texts of one area in the card: the name and, on the class's own
/// area, the default-path tag.
class _AreaText extends StatelessWidget {
  const _AreaText({required this.area, required this.isDefault});

  final Area area;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final accent = Color(area.accent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShadowTitle(area.name.toUpperCase(), size: 30, shadowColor: accent),
          if (isDefault) ...[
            const SizedBox(height: 8),
            Tag(t('area.home'), bg: accent, fg: p.on, size: 12, angle: 0),
          ],
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
    return Column(
      children: [
        SizedBox(height: stage.bottom + 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 24, 8),
            children: [
              Center(child: Tag(t('summary.tag'), bg: p.lime, fg: p.on, size: 18)),
              const SizedBox(height: 14),
              Brutal(
                color: kNight,
                shadow: color,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    children: [
                      _SummaryRow(label: t('label.class'), value: cls.name, color: color, onTap: () => onEdit(1)),
                      _SummaryRow(label: t('label.gear'), value: cls.equipment, color: p.sky, onTap: () => onEdit(1)),
                      _SummaryRow(label: t('label.difficulty'), value: d.name, color: p.pink, onTap: () => onEdit(1)),
                      _SummaryRow(label: t('label.area'), value: a.name, color: p.orange, onTap: () => onEdit(2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _Nav(onBack: onBack, next: editing ? t('nav.save') : t('nav.go'), onNext: onGo),
      ],
    );
  }
}

/// One summary line: the label, the value, the edit icon. Tap: that step.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, required this.color, required this.onTap});

  final String label, value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(width: 92, child: Shout(label, color: color, size: 12)),
              Expanded(child: Text(value.toUpperCase(), style: display(19, Pal.of(context).onNight))),
              PxIcon('edit', size: 18, color: color),
            ],
          ),
        ),
      );
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
              Center(child: Tag(t('migrate.found'), bg: p.orange, fg: p.on, size: 20)),
              const SizedBox(height: 16),
              Terminal([
                tn('migrate.days', oldWorkouts),
                t('migrate.xp', {'xp': xpPerLegacySession}),
                t('migrate.delete'),
                t('migrate.first'),
              ]),
            ],
          ),
        ),
        ActionBar(
          padding: _setupBarPadding(context),
          back: BrutalButton(color: p.sky, onTap: onLater, child: Text(t('migrate.later'))),
          main: BrutalButton(
            color: p.pink,
            onTap: onUpgrade,
            child: Text(t('migrate.upgrade'), textAlign: TextAlign.center, style: display(19, p.on)),
          ),
        ),
      ],
    );
  }
}
