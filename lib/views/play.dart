// Past sessions: one session as a page of the lifter profile's carousel
// (D59). The workout is in workout.dart, the profile in profile.dart.

import 'package:flutter/material.dart';

import '../dates.dart';
import '../game/content.dart';
import '../game/exercises.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../i18n.dart';
import '../pumplex.dart';
import 'sprite.dart';

/// One training day: the date, the XP, sets / time / class / area, and the
/// sets per exercise (no targets, D52). Old-app days show as OLD WORKOUT;
/// days frozen by D54 keep their class, area and XP, with no exercise lines.
class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.session, required this.xp, required this.live});

  final Session session;
  final int xp;

  /// Today's session (still open).
  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final took = session.duration;
    final date = (live ? '${t('session.today')} · ' : '') + shortDate(parseDateKey(session.date)).toUpperCase();
    final time = took == null ? '' : ' · ${t('session.time', {'t': fmtDuration(took)})}';
    // Old-app days have no class. Days frozen by D54 keep theirs (OLD EXERCISE LIST).
    if (session.legacy && session.classId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(date, style: display(19, p.ink))),
              Tag('+$xpPerLegacySession XP', bg: p.lime, fg: p.on, size: 13, angle: 2),
            ],
          ),
          const SizedBox(height: 4),
          Text('${t('session.old')}$time · ${t('session.beta')}', style: mono(11.5, p.ink)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(date, style: display(19, p.ink))),
            Tag('+$xp XP', bg: p.lime, fg: p.on, size: 13, angle: 2),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${session.legacy ? t('session.oldList') : tn('sets', session.totalSets)}$time · '
          '${classById(session.classId).name.toUpperCase()} · ${areaById(session.areaId).name.toUpperCase()}',
          style: mono(11.5, p.ink),
        ),
        const SizedBox(height: 6),
        for (final e in session.exercises)
          if (e.sets > 0)
            Row(
              children: [
                Expanded(
                  child: Text('${_name(e.exerciseId).toUpperCase()}  ${e.sets}', style: display(15, p.ink)),
                ),
                TallyMarks(count: e.sets, height: 14),
              ],
            ),
      ],
    );
  }

  /// A logged exercise's name: the forged nickname too; an id the list no
  /// longer has keeps its English name.
  static String _name(String id) {
    final e = exerciseCatalog.byId[id];
    return e == null ? exerciseLabel(id, exerciseName(id)) : displayName(e);
  }
}
