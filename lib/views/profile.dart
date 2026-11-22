// The lifter profile (D50): it shows under the minimised workout when the
// lifter is tapped. Two cards: past sessions (a carousel) and the lifter
// (body, class, gear, difficulty, area, each with a change pencil).

import 'package:flutter/material.dart';

import '../game/content.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../store.dart';
import 'carousel.dart';
import 'play.dart';
import 'sprite.dart';

class LifterProfile extends StatefulWidget {
  const LifterProfile({super.key, required this.store, required this.onEditStep});

  final LogStore store;

  /// Opens an editor under the minimised workout (D51): 0 body, 1 class
  /// and difficulty, 2 area. Changes save at once.
  final ValueChanged<int> onEditStep;

  @override
  State<LifterProfile> createState() => _LifterProfileState();
}

class _LifterProfileState extends State<LifterProfile> with SwipeCarousel<LifterProfile> {
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
    final today = store.todaySession;
    final cls = store.gameClass;
    final di = store.difficulty;
    final area = areaById(store.profile?.areaId);
    final c = store.profile?.character;
    final color = classColor(p, cls.id);
    Widget row(int step, String key, String label, String value, Color labelColor) => InkWell(
          key: ValueKey('profile-$key'),
          onTap: () => widget.onEditStep(step),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(width: 92, child: Shout(label, color: labelColor, size: 12)),
                Expanded(child: Text(value.toUpperCase(), style: display(19, Colors.white))),
                PxIcon('edit', size: 18, color: labelColor),
              ],
            ),
          ),
        );
    return ListView(
      padding: EdgeInsets.only(bottom: 14 + MediaQuery.paddingOf(context).bottom),
      children: [
        // Past sessions: one at a time, swipe both ways, round and round.
        Brutal(
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
                        live: identical(sessions[index], today),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // The lifter: the setup summary card; each row opens its step.
        Brutal(
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
                row(1, 'difficulty', 'Difficulty', difficulties[di].name, p.pink),
                row(2, 'area', 'Area', area.name, p.orange),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
