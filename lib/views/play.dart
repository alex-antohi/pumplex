// Play: the hub and past sessions. The workout is in workout.dart.

import 'package:flutter/material.dart';

import '../dates.dart';
import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../store.dart';
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

/// The lit tab of [MainNav].
enum NavTab { history, hub, profile }

/// Bottom navigation (HISTORY, HUB, PROFILE) under the hub, the workout,
/// past sessions and the profile. The workout lights HUB.
class MainNav extends StatelessWidget {
  const MainNav({super.key, required this.current, required this.onHistory, required this.onHub, required this.onProfile});

  static const height = 56.0;

  final NavTab current;
  final VoidCallback onHistory, onHub, onProfile;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: height + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(color: kNight, border: Border(top: BorderSide(color: p.panel2, width: 3))),
      child: Row(
        children: [
          _NavButton(key: const ValueKey('nav-history'), icon: 'history', label: 'HISTORY', current: current == NavTab.history, onTap: onHistory),
          _NavButton(key: const ValueKey('nav-hub'), icon: 'bolt', label: 'HUB', current: current == NavTab.hub, onTap: onHub),
          _NavButton(key: const ValueKey('nav-profile'), icon: 'user', label: 'PROFILE', current: current == NavTab.profile, onTap: onProfile),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({super.key, required this.icon, required this.label, required this.onTap, this.current = false});

  final String icon, label;
  final VoidCallback onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = current ? Colors.white : const Color(0xFFC9B8E8);
    return Expanded(
      child: Semantics(
        button: true,
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
  const _PageHeader({required this.stage, required this.title, required this.line});

  final Rect stage;
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
  const HistoryView({super.key, required this.stage, required this.store});

  final Rect stage;
  final LogStore store;

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

