// The lifter profile (D50-D52). It shows under the minimised workout when
// the lifter is tapped: a past-sessions card (a carousel) and the lifter
// card (BODY, CLASS, DIFFICULTY, AREA). While a property is edited, the two
// cards shrink into tiles beside the minimised workout (D52).

import 'package:flutter/material.dart';

import '../dates.dart';
import '../game/content.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../store.dart';
import 'carousel.dart';
import 'play.dart';
import 'sprite.dart';

/// Both cards, one under the other.
class LifterProfile extends StatelessWidget {
  const LifterProfile({super.key, required this.store, required this.onEditStep});

  final LogStore store;

  /// Opens a setup screen under the minimised workout (D51): 0 body,
  /// 1 class and difficulty, 2 area. Changes save at once.
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.only(bottom: 14 + MediaQuery.paddingOf(context).bottom),
        children: [
          SessionsCard(store: store),
          const SizedBox(height: 18),
          LifterCard(store: store, onEditStep: onEditStep),
        ],
      );
}

/// Past sessions: one training day at a time; swipe both ways, round and
/// round; "n / m" shows where you are.
class SessionsCard extends StatefulWidget {
  const SessionsCard({super.key, required this.store});

  final LogStore store;

  @override
  State<SessionsCard> createState() => _SessionsCardState();
}

class _SessionsCardState extends State<SessionsCard> with SwipeCarousel<SessionsCard> {
  int _i = 0;

  @override
  int get count => widget.store.history.length;

  @override
  int get index => _i.clamp(0, count == 0 ? 0 : count - 1);

  @override
  void select(int i) => setState(() => _i = i);

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

/// The lifter: BODY, CLASS, DIFFICULTY, AREA. Tap a row to edit it.
class LifterCard extends StatelessWidget {
  const LifterCard({super.key, required this.store, required this.onEditStep});

  final LogStore store;
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = store.gameClass;
    final area = areaById(store.profile?.areaId);
    final c = store.profile?.character;
    final color = classColor(p, cls.id);
    Widget row(int step, String key, String label, String value, Color labelColor) => InkWell(
          key: ValueKey('profile-$key'),
          onTap: () => onEditStep(step),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(width: 92, child: Shout(label, color: labelColor, size: 12)),
                Expanded(child: Text(value.toUpperCase(), style: display(19, Colors.white))),
              ],
            ),
          ),
        );
    return Brutal(
      key: const ValueKey('profile-lifter'),
      color: kNight,
      shadow: color,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            if (c != null)
              row(0, 'body', 'Body', '${heightMetres(c.height).toStringAsFixed(2)} M · ${weightKg(c.fat)} KG', p.lime),
            row(1, 'class', 'Class', cls.name, color),
            row(1, 'difficulty', 'Difficulty', difficulties[store.difficulty].name, p.pink),
            row(2, 'area', 'Area', area.name, p.orange),
          ],
        ),
      ),
    );
  }
}

/// A small tile beside the minimised workout (D52).
class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.title, required this.color, required this.lines, required this.onTap, required this.on});

  final String title;
  final Color color;
  final List<String> lines;
  final VoidCallback onTap;

  /// Its card is the one shown below.
  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: on ? kNight : p.panel,
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
                child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(11, on ? Colors.white : p.ink)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The lifter card as a tile: class, difficulty, area. Tap: the full card.
class LifterTile extends StatelessWidget {
  const LifterTile({super.key, required this.store, required this.on, required this.onTap});

  final LogStore store;
  final bool on;
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
        on: on,
        onTap: onTap,
      );
}

/// The last session as a tile: date, sets, XP. Tap: the sessions carousel.
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.store, required this.on, required this.onTap});

  final LogStore store;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = store.history.isEmpty ? null : store.history.first;
    return _Tile(
      key: const ValueKey('tile-session'),
      title: 'Last session',
      color: Pal.of(context).violet,
      lines: last == null
          ? const ['NOTHING YET']
          : [
              shortDate(parseDateKey(last.date)).toUpperCase(),
              last.legacy ? 'OLD WORKOUT' : '${last.totalSets} SETS',
              '+${last.legacy ? xpPerLegacySession : store.xpOfSession(last)} XP',
            ],
      on: on,
      onTap: onTap,
    );
  }
}
