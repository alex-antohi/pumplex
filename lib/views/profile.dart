// The lifter profile (D59-D62). It shows under the minimised workout when
// the lifter is tapped: the lifter editor (the setup screens) takes the
// space and the last session is a tile beside the arena. Swipe the editor
// up / down to change the property (body, class, area). Tap the session
// tile: the past-sessions card takes the space and the lifter is the tile.

import 'package:flutter/material.dart';

import '../dates.dart';
import '../game/content.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../store.dart';
import 'carousel.dart';
import 'play.dart';
import 'sprite.dart';

/// Past sessions: one training day at a time; swipe both ways, round and
/// round; "n / m" shows where you are. The shell keeps [index], so the
/// card keeps its place when it moves.
class SessionsCard extends StatefulWidget {
  const SessionsCard({super.key, required this.store, required this.index, required this.onIndex, this.onSwiped});

  final LogStore store;
  final int index;
  final ValueChanged<int> onIndex;

  /// A swipe changed the session (the shell then gives the card the space).
  final VoidCallback? onSwiped;

  @override
  State<SessionsCard> createState() => _SessionsCardState();
}

class _SessionsCardState extends State<SessionsCard> with SwipeCarousel<SessionsCard> {
  @override
  int get count => widget.store.history.length;

  @override
  int get index => widget.index.clamp(0, count == 0 ? 0 : count - 1);

  @override
  void select(int i) {
    widget.onIndex(i);
    widget.onSwiped?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final store = widget.store;
    final sessions = store.history;
    return Brutal(
      key: const ValueKey('profile-sessions'),
      shadow: p.violet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Shout('Past sessions', color: p.violet, size: 14),
                const Spacer(),
                if (sessions.isNotEmpty) Text('${index + 1} / ${sessions.length}', style: mono(11, p.ink)),
              ],
            ),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Terminal(['NOTHING HERE YET.', 'THE BOOK IS HUNGRY. FEED IT SETS.'])
            else
              swipe(
                key: const ValueKey('session-card'),
                child: slide(
                  sessions[index].date,
                  SessionPage(
                    session: sessions[index],
                    xp: store.xpOfSession(sessions[index]),
                    live: identical(sessions[index], store.todaySession),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small tile beside the minimised workout (D61, D62).
class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.title, required this.color, required this.lines, required this.onTap});

  final String title;
  final Color color;
  final List<String> lines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: p.panel,
          border: Border.all(color: p.ink, width: 3),
          boxShadow: [BoxShadow(color: color, offset: const Offset(4, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Shout(title, color: color, size: 10)),
            const SizedBox(height: 4),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(11, p.ink)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The lifter as a tile: class, difficulty, area. Tap: the lifter editor.
class LifterTile extends StatelessWidget {
  const LifterTile({super.key, required this.store, required this.onTap});

  final LogStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Tile(
        key: const ValueKey('tile-lifter'),
        title: 'Lifter',
        color: classColor(Pal.of(context), store.gameClass.id),
        lines: [
          store.gameClass.name.toUpperCase(),
          difficulties[store.difficulty].name.toUpperCase(),
          areaById(store.profile?.areaId).name.toUpperCase(),
        ],
        onTap: onTap,
      );
}

/// The session the carousel shows (the last one by default) as a tile:
/// date, sets, XP. Tap: the past-sessions card.
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.store, required this.index, required this.onTap});

  final LogStore store;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final all = store.history;
    final s = all.isEmpty ? null : all[index.clamp(0, all.length - 1)];
    return _Tile(
      key: const ValueKey('tile-session'),
      title: index == 0 ? 'Last session' : 'Session',
      color: Pal.of(context).violet,
      lines: s == null
          ? const ['NOTHING YET']
          : [
              shortDate(parseDateKey(s.date)).toUpperCase(),
              s.legacy ? 'OLD WORKOUT' : '${s.totalSets} SETS',
              '+${s.legacy && s.classId.isEmpty ? xpPerLegacySession : store.xpOfSession(s)} XP',
            ],
      onTap: onTap,
    );
  }
}
