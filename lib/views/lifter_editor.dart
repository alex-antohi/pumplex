// The lifter profile under the minimised workout (D59-D62): the lifter
// editor (the setup screens without BACK / NEXT, D60), or the past
// sessions, and the frame of the minimised workout window. The shell
// (main.dart) keeps the state; these widgets only show it.

import 'package:flutter/material.dart';

import '../game/model.dart';
import '../i18n.dart';
import '../pumplex.dart';
import '../store.dart';
import 'carousel.dart';
import 'profile.dart';
import 'setup.dart';
import 'sprite.dart';
import 'stage.dart';

/// The lifter editor's order (D63): BODY, CLASS, AREA. Up from BODY is
/// CLASS; down from BODY is AREA (round and round). The summary's EDIT
/// steps use it too (0 body, 1 class and difficulty, 2 area).
const lifterProps = [Scene.create, Scene.classSelect, Scene.area];

/// One property of the lifter editor (D60): the setup screen of [prop]
/// ([lifterProps]) without BACK / NEXT, its own lifter and the property
/// dots. Every change saves at once (a slider when it is let go): the shell
/// saves on [onSave] and in [onClass], [onDifficulty] and [onArea].
class LifterEditor extends StatelessWidget {
  const LifterEditor({
    super.key,
    required this.prop,
    required this.inset,
    required this.character,
    required this.classId,
    required this.difficultyId,
    required this.areaId,
    required this.headOpen,
    required this.onCharacter,
    required this.onSave,
    required this.onHead,
    required this.onClass,
    required this.onDifficulty,
    required this.onArea,
  });

  final int prop;

  /// The phone's navigation bar.
  final double inset;
  final Character character;
  final String classId, difficultyId, areaId;
  final bool headOpen;
  final ValueChanged<Character> onCharacter;
  final VoidCallback onSave;
  final ValueChanged<bool> onHead;
  final ValueChanged<String> onClass, onDifficulty, onArea;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _page(context, box.biggest));

  Widget _page(BuildContext context, Size size) {
    final p = Pal.of(context);
    final scene = lifterProps[prop];
    final stage = stageRect(scene, size, bottomInset: inset, buttons: false);
    final view = switch (scene) {
      Scene.create => CreateView(
          stage: stage,
          character: character,
          buttons: false,
          onCharacter: (c) {
            // A tap (sex, skin, hair, facial hair) saves at once; a slider
            // saves when it is let go.
            final tapped = c.sex != character.sex ||
                c.skin != character.skin ||
                c.hair != character.hair ||
                c.facialHair != character.facialHair;
            onCharacter(c);
            if (tapped) onSave();
          },
          onSlideEnd: onSave,
          onNext: () {},
          headOpen: headOpen,
          onHead: onHead,
        ),
      Scene.classSelect => ClassView(
          stage: stage,
          classId: classId,
          difficultyId: difficultyId,
          editing: true,
          buttons: false,
          onPick: onClass,
          onDifficulty: onDifficulty,
          onBack: () {},
          onNext: () {},
        ),
      _ => AreaView(
          stage: stage,
          areaId: areaId,
          classId: classId,
          editing: true,
          buttons: false,
          onPick: onArea,
          onBack: () {},
          onNext: () {},
        ),
    };
    return Stack(
      key: ValueKey('lifter-edit-$prop'),
      children: [
        Positioned.fill(child: view),
        // Which property: body, class, area (swipe up / down).
        Positioned(
          right: 4,
          top: 4,
          child: IgnorePointer(
            child: CarouselDots(
              axis: Axis.vertical,
              prefix: 'prop',
              ids: [for (var i = 0; i < lifterProps.length; i++) '$i'],
              current: '$prop',
              colorOf: (_) => p.lime,
            ),
          ),
        ),
        // The screen's own lifter (the small workout window has its own).
        Positioned.fromRect(
          rect: stage,
          child: IgnorePointer(
            child: CharacterSprite(
              key: const ValueKey('edit-lifter'),
              character: character,
              classId: classId,
              pedestal: scene != Scene.area,
              zoomHead: scene == Scene.create && headOpen,
              pixelScale: scene == Scene.area ? areaLayout(size, inset, buttons: false).scale : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Under the minimised workout (D62): the past-sessions list when
/// [sessions] (one day in full when [detail] is set), else the lifter
/// editor as a vertical carousel (D63): flick up / down for the next
/// property, round and round. [editor] builds the editor of a property.
/// The list and the day have BACK at the bottom left, as in the setup:
/// [onBack] goes one level up (the day, the list, the editor).
class LifterPanel extends StatelessWidget {
  const LifterPanel({
    super.key,
    required this.store,
    required this.sessions,
    required this.detail,
    required this.onOpenSession,
    required this.onBack,
    required this.prop,
    required this.onProp,
    required this.inset,
    required this.editor,
  });

  final LogStore store;
  final bool sessions;

  /// The day open in full (null: the list).
  final Session? detail;
  final int prop;
  final ValueChanged<int> onOpenSession, onProp;
  final VoidCallback onBack;
  final double inset;
  final Widget Function(int prop) editor;

  @override
  Widget build(BuildContext context) {
    if (sessions) {
      final p = Pal.of(context);
      final day = detail;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: ValueKey(day == null ? 'sessions-list' : 'session-detail-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 0, 22, 8),
              child: day == null
                  ? SessionsCard(store: store, onOpen: onOpenSession)
                  : SessionDetail(store: store, session: day),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 22, 14 + inset),
            child: BrutalButton(
              key: ValueKey(day == null ? 'sessions-back' : 'session-detail-back'),
              color: p.sky,
              onTap: onBack,
              child: IconText('back', t('nav.back')),
            ),
          ),
        ],
      );
    }
    return VerticalCarousel(
      key: const ValueKey('lifter-editor'),
      index: prop,
      count: lifterProps.length,
      onIndex: onProp,
      builder: (context, i) => editor(i),
    );
  }
}

/// The frame of the minimised workout window (D61, D75): an ink border that
/// fades in with [t] (0 full screen, 1 minimised). Tap it to go back
/// ([onTap] null: not tappable).
class MiniWorkoutFrame extends StatelessWidget {
  const MiniWorkoutFrame({super.key, required this.t, required this.onTap});

  final double t;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey('mini-workout'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // A card only while minimised (D75).
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Pal.of(context).ink.withValues(alpha: t), width: 3),
          ),
        ),
      );
}
