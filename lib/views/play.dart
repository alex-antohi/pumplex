// Play: the hub, the workout (count working sets), and past sessions.

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
    required this.onGear,
    required this.onProfile,
  });

  final Rect stage;
  final LogStore store;
  final VoidCallback onTrain, onHistory, onGear, onProfile;

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
    final bottom = MediaQuery.paddingOf(context).bottom;
    final trained = store.history.where((s) => s.trained && !identical(s, today)).toList();
    return LayoutBuilder(builder: (context, box) {
      final (scene, scale) = hubLayout(box.biggest);
      return Stack(
        children: [
          // The area scene, framed (the lifter stands in it).
          Positioned(
            left: scene.left - 4,
            top: scene.top - 4,
            width: scene.width + 8,
            height: scene.height + 8,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: p.ink, width: 4),
                boxShadow: [BoxShadow(color: Color(area.accent), offset: const Offset(6, 6))],
              ),
            ),
          ),
          Positioned.fromRect(rect: scene, child: AreaScene(art: areaArt[area.artId]!, scale: scale)),
          // Where: the area name, top left over the sky.
          Positioned(
            left: scene.left + 8,
            top: scene.top + 8,
            child: Tag(area.name, bg: kNight, fg: Color(area.accent), size: 13, angle: -2),
          ),
          // Class name tag, bottom right of the scene.
          Positioned(
            right: box.maxWidth - scene.right + 8,
            bottom: box.maxHeight - scene.bottom + 8,
            child: Tag('${cls.name} · ${d.name}', bg: kNight, fg: color, size: 12, angle: 2),
          ),
          // Gear, top right of the scene.
          Positioned(
            right: box.maxWidth - scene.right + 8,
            top: scene.top + 8,
            child: BrutalButton(
              key: const ValueKey('hub-gear'),
              small: true,
              color: p.lime,
              onTap: onGear,
              child: const IconText('gear', 'GEAR'),
            ),
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
                Brutal(
                  shadow: p.orange,
                  offset: 5,
                  border: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shout('This week', color: p.ink, size: 14),
                        const SizedBox(height: 8),
                        _StreakRow(week: store.thisWeek, streak: store.streakWeeks),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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

/// This week's training days against the target, and the streak.
class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.week, required this.streak});

  final ({int days, int n}) week;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      children: [
        for (var i = 0; i < week.n; i++)
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: i < week.days ? p.orange : p.panel,
              border: Border.all(color: p.ink, width: 3),
            ),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'THIS WEEK ${week.days}/${week.n} DAYS'
            '${streak > 0 ? ' · STREAK $streak WEEK${streak == 1 ? '' : 'S'}' : ''}',
            style: mono(11.5, p.ink),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- history

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
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: stage.bottom + 4),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, stage.top + 4, stage.width + 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrutalButton(key: const ValueKey('history-hub'), small: true, color: p.sky, onTap: onBack, child: const IconText('next', 'HUB', iconAfter: true)),
                const SizedBox(height: 10),
                Text('PAST SESSIONS', style: display(26, p.ink)),
                const SizedBox(height: 4),
                Text('${all.length} TRAINING DAYS IN THE BOOK', style: mono(11.5, p.pink)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 24, 30 + MediaQuery.paddingOf(context).bottom),
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
              '${session.totalSets} SETS${took == null ? '' : ' · ⏱ ${fmtDuration(took)}'} · '
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
    final took = session.duration == null ? '' : ' · ⏱ ${fmtDuration(session.duration!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          PxIcon('arm', size: 18, color: Pal.of(context).ink),
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

// -------------------------------------------------------------------- gear

/// One item per slot. The level unlocks items; the body never changes.
class GearView extends StatelessWidget {
  const GearView({super.key, required this.stage, required this.store, required this.onBack});

  final Rect stage;
  final LogStore store;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final level = levelFor(store.totalXp).level;
    final gear = store.gear;
    return Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: stage.bottom + 4),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, stage.top + 4, stage.width + 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrutalButton(key: const ValueKey('gear-hub'), small: true, color: p.sky, onTap: onBack, child: const IconText('back', 'HUB')),
                const SizedBox(height: 10),
                Text('GEAR', style: display(26, p.ink)),
                const SizedBox(height: 4),
                Text('LEVELS UNLOCK GEAR. ONE ITEM PER SLOT.', style: mono(11.5, p.pink)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 24, 30 + MediaQuery.paddingOf(context).bottom),
            children: [
              for (final slot in GearSlot.values) ...[
                Shout(slot.name, color: p.violet, size: 14),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final it in items.where((i) => i.slot == slot))
                      _ItemChip(
                        item: it,
                        owned: gear.owned.contains(it.id),
                        equipped: gear.equipped[slot.name] == it.id,
                        onTap: () => store.equip(slot, gear.equipped[slot.name] == it.id ? null : it.id),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
              Terminal([
                'YOU ARE LVL $level.',
                'THE GEAR ART COMES FROM THE DESIGN TEAM. FOR NOW: ICONS.',
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemChip extends StatelessWidget {
  const _ItemChip({required this.item, required this.owned, required this.equipped, required this.onTap});

  final Item item;
  final bool owned, equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Opacity(
      opacity: owned ? 1 : 0.45,
      child: BrutalButton(
        key: ValueKey('item-${item.id}'),
        small: true,
        color: equipped ? p.lime : p.panel,
        onTap: owned ? onTap : null,
        child: Builder(builder: (context) {
          final color = DefaultTextStyle.of(context).style.color;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              owned
                  ? Image.asset(item.icon, width: 18, height: 18, color: color, filterQuality: FilterQuality.none)
                  : PxIcon('lock', size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(owned
                    ? '${item.name.toUpperCase()}${equipped ? ' · ON' : ''}'
                    : 'LVL ${item.unlockLevel} · ${item.name.toUpperCase()}'),
              ),
            ],
          );
        }),
      ),
    );
  }
}
