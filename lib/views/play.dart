// Play: the hub and past sessions. The workout is in workout.dart.

import 'package:flutter/material.dart';

import '../dates.dart';
import '../game/area_art.dart';
import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../store.dart';
import 'area_scene.dart';
import 'sprite.dart';

/// Level number and XP bar.
class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final l = levelFor(xp);
    return Row(
      children: [
        Tag('LVL ${l.level}', bg: p.pink, fg: p.on, size: 22, angle: -4),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 22,
                decoration: BoxDecoration(
                  color: kNight,
                  border: Border.all(color: p.ink, width: 3),
                  boxShadow: [BoxShadow(color: p.lime, offset: const Offset(4, 4))],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: l.into / l.need),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, f, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: f.clamp(0.0, 1.0),
                    child: Container(color: p.lime),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text('${l.into} / ${l.need} XP TO LVL ${l.level + 1}', style: mono(11.5, p.ink)),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- hub

/// The hub scene's rect and whole-number scale in a view of [area]
/// (design demo 07: the area scene on top, the lifter in it).
(Rect, int) hubLayout(Size area) {
  final avail = Rect.fromLTWH(16, 8, area.width - 32, area.height * 0.36);
  final scale = sceneScale(avail.size);
  return (sceneRectIn(avail, scale), scale);
}

/// The lifter's place on the hub: in the scene, feet on the shadow.
Rect hubStage(Size area) {
  final (scene, scale) = hubLayout(area);
  return sceneLifterRect(areaArt.values.first, scene, scale);
}

/// Height of the bottom navigation (history, hub, profile).
const hubNavHeight = 56.0;

class HubView extends StatelessWidget {
  const HubView({
    super.key,
    required this.stage,
    required this.store,
    required this.onTrain,
    required this.onHistory,
    required this.onBody,
    required this.onProfile,
  });

  final Rect stage;
  final LogStore store;
  final VoidCallback onTrain, onHistory, onProfile;

  /// Opens the body sliders (tap on the character, D12).
  final VoidCallback onBody;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = store.gameClass;
    final d = difficulties[store.difficulty];
    final today = store.todaySession;
    final color = classColor(p, cls.id);
    final area = areaById(store.profile?.areaId);
    final accent = Color(area.accent);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final trained = store.history.where((s) => s.trained && !identical(s, today)).toList();
    return LayoutBuilder(builder: (context, box) {
      final (scene, scale) = hubLayout(box.biggest);
      return Stack(
        children: [
          // The area scene, framed (the lifter stands in it).
          sceneFrame(scene, ink: p.ink, shadow: accent),
          Positioned.fromRect(rect: scene, child: AreaScene(art: areaArt[area.id]!, scale: scale)),
          // Where: the area name, top left over the sky.
          Positioned(
            left: scene.left + 8,
            top: scene.top + 8,
            child: Tag(area.name, bg: kNight, fg: accent, size: 13, angle: -2),
          ),
          // Class name tag, bottom right of the scene.
          Positioned(
            right: box.maxWidth - scene.right + 8,
            bottom: box.maxHeight - scene.bottom + 8,
            child: Tag('${cls.name} · ${d.name}', bg: kNight, fg: color, size: 12, angle: 2),
          ),
          // Tap the character to change the body sliders.
          Positioned.fromRect(
            rect: stage,
            child: GestureDetector(
              key: const ValueKey('hub-character'),
              behavior: HitTestBehavior.translucent,
              onTap: onBody,
            ),
          ),
          // Level, next workout, this week.
          Positioned(
            left: 0,
            right: 0,
            top: scene.bottom + 8,
            bottom: hubNavHeight + bottom,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 24, 16),
              children: [
                // Tap the level to open the profile (design screen 11).
                GestureDetector(
                  key: const ValueKey('hub-level'),
                  onTap: onProfile,
                  child: LevelBar(xp: store.totalXp),
                ),
                const SizedBox(height: 18),
                // The workout card. Tapping it zooms the camera into the workout.
                GestureDetector(
                  key: const ValueKey('hub-workout'),
                  onTap: onTrain,
                  child: Brutal(
                    shadow: color,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Shout('Next workout', color: p.ink, size: 14)),
                              if (today != null && today.totalSets > 0)
                                Tag('ON · ${today.totalSets} SETS', bg: p.lime, fg: p.on, size: 13),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final s in store.todayExercises.where((e) => !e.removed))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: PxIcon('next', size: 16, color: color),
                                  ),
                                  Expanded(
                                    child: Text(exerciseName(s.exerciseId).toUpperCase(), style: display(18, p.ink)),
                                  ),
                                  if (s.sets > 0) TallyMarks(count: s.sets, height: 16),
                                ],
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text('${area.hint}: ONE WORKING SET. NO REPS, NO KILOS.', style: mono(11, p.ink)),
                          const SizedBox(height: 12),
                          Pulse(
                            amount: 0.03,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(color: p.lime, border: Border.all(color: p.ink, width: 4)),
                              child: DefaultTextStyle(
                                style: display(28, p.on).copyWith(letterSpacing: 1.5),
                                child: Center(
                                  child: IconText('play', today == null || today.totalSets == 0 ? 'TRAIN' : 'KEEP GOING',
                                      iconAfter: true),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  trained.isEmpty
                      ? 'NO CLOCK. NO PLAN. EVERY SET TODAY COUNTS FOR TODAY.'
                      : 'LAST TIME: ${shortDate(parseDateKey(trained.first.date)).toUpperCase()} · '
                          '${trained.first.totalSets} SETS',
                  style: mono(11, p.ink),
                ),
              ],
            ),
          ),
          // Bottom navigation (design demo 07).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: hubNavHeight + bottom,
            child: Container(
              padding: EdgeInsets.only(bottom: bottom),
              decoration: BoxDecoration(color: kNight, border: Border(top: BorderSide(color: p.panel2, width: 3))),
              child: Row(
                children: [
                  _NavButton(key: const ValueKey('hub-past'), icon: 'history', label: 'HISTORY', onTap: onHistory),
                  const _NavButton(icon: 'bolt', label: 'HUB', current: true),
                  _NavButton(key: const ValueKey('hub-profile'), icon: 'user', label: 'PROFILE', onTap: onProfile),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({super.key, required this.icon, required this.label, this.onTap, this.current = false});

  final String icon, label;
  final VoidCallback? onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = current ? Colors.white : const Color(0xFFC9B8E8);
    return Expanded(
      child: Semantics(
        button: !current,
        selected: current,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: current ? p.panel2 : null,
              border: current ? Border(top: BorderSide(color: p.pink, width: 4)) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PxIcon(icon, size: 20, color: c),
                const SizedBox(height: 3),
                Text(label, style: mono(11, c)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- history

/// Header of a list page (past sessions): a HUB button, a title and a line,
/// to the left of the small character at [stage].
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.stage, required this.button, required this.title, required this.line});

  final Rect stage;
  final Widget button;
  final String title, line;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: stage.bottom + 4),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, stage.top + 4, stage.width + 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            button,
            const SizedBox(height: 10),
            Text(title, style: display(26, p.ink)),
            const SizedBox(height: 4),
            Text(line, style: mono(11.5, p.pink)),
          ],
        ),
      ),
    );
  }
}

/// Padding of the list under a [_PageHeader].
EdgeInsets _pageListPadding(BuildContext context) =>
    EdgeInsets.fromLTRB(16, 8, 24, 30 + MediaQuery.paddingOf(context).bottom);

class HistoryView extends StatelessWidget {
  const HistoryView({super.key, required this.stage, required this.store, required this.onBack});

  final Rect stage;
  final LogStore store;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final all = store.history;
    final game = all.where((s) => !s.legacy).toList();
    final legacy = all.where((s) => s.legacy).toList();
    final today = store.todaySession;
    return Column(
      children: [
        _PageHeader(
          stage: stage,
          button: BrutalButton(key: const ValueKey('history-hub'), small: true, color: p.sky, onTap: onBack, child: const IconText('next', 'HUB', iconAfter: true)),
          title: 'PAST SESSIONS',
          line: '${all.length} TRAINING DAYS IN THE BOOK',
        ),
        Expanded(
          child: ListView(
            padding: _pageListPadding(context),
            children: [
              if (all.isEmpty) const Terminal(['NOTHING HERE YET.', 'THE BOOK IS HUNGRY. FEED IT SETS.']),
              for (final s in game)
                _SessionTile(session: s, xp: store.xpOfSession(s), live: identical(s, today)),
              if (legacy.isNotEmpty) ...[
                const SizedBox(height: 8),
                Shout('Old saves · +$xpPerLegacySession XP each (beta)', color: p.violet),
                const SizedBox(height: 10),
                for (final s in legacy) _LegacyTile(session: s),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.xp, required this.live});

  final Session session;
  final int xp;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final took = session.duration;
    return Brutal(
      margin: const EdgeInsets.only(bottom: 16),
      shadow: live ? p.lime : p.violet,
      offset: 5,
      border: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (live ? 'TODAY · ' : '') + shortDate(parseDateKey(session.date)).toUpperCase(),
                    style: display(19, p.ink),
                  ),
                ),
                Tag('+$xp XP', bg: p.lime, fg: p.on, size: 13, angle: 2),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${session.totalSets} SETS${took == null ? '' : ' · TIME ${fmtDuration(took)}'} · '
              '${classById(session.classId).name.toUpperCase()} · ${areaById(session.areaId).name.toUpperCase()}',
              style: mono(11.5, p.ink),
            ),
            const SizedBox(height: 6),
            for (final e in session.exercises)
              if (e.sets > 0)
                Row(
                  children: [
                    Expanded(
                      child: Text('${exerciseName(e.exerciseId).toUpperCase()}  ${e.sets}/${e.targetSets}',
                          style: display(15, p.ink)),
                    ),
                    TallyMarks(count: e.sets, height: 14),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

class _LegacyTile extends StatelessWidget {
  const _LegacyTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final took = session.duration == null ? '' : ' · TIME ${fmtDuration(session.duration!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          PxIcon('arm', size: 18, color: p.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${shortDate(parseDateKey(session.date)).toUpperCase()} · OLD WORKOUT$took',
              style: mono(12.5, p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

