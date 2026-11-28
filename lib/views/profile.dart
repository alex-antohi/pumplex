// The lifter profile (D59-D62). It shows under the minimised workout when
// the lifter is tapped: the lifter editor (the setup screens) takes the
// space and the last session is a tile beside the arena. Swipe the editor
// up / down to change the property (body, class, area). Tap the session
// tile: the past-sessions list takes the space and the lifter is the tile;
// a tap on a day opens its full workout. BACK (and Android back) goes one
// level up: the day, the list, the editor.

import 'package:flutter/material.dart';

import '../dates.dart';
import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../i18n.dart';
import '../pumplex.dart';
import '../store.dart';
import 'play.dart';
import 'sprite.dart';

/// Past sessions: every training day, one under the other, newest first.
/// A tap on a row opens that day's full workout ([SessionDetail]).
class SessionsCard extends StatelessWidget {
  const SessionsCard({super.key, required this.store, required this.onOpen});

  final LogStore store;

  /// Opens the day at this index of [LogStore.history].
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final sessions = store.history;
    return Brutal(
      key: const ValueKey('profile-sessions'),
      shadow: p.violet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Shout(t('sessions.title'), color: p.violet, size: 14),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              Terminal([t('sessions.empty1'), t('sessions.empty2')])
            else
              for (final (i, s) in sessions.indexed)
                Padding(
                  padding: EdgeInsets.only(bottom: i == sessions.length - 1 ? 4 : 8),
                  child: _SessionRow(store: store, session: s, onTap: () => onOpen(i)),
                ),
          ],
        ),
      ),
    );
  }
}

/// The date of [s] as the past sessions show it: TODAY · for today's.
String sessionDate(LogStore store, Session s) =>
    (identical(s, store.todaySession) ? '${t('session.today')} · ' : '') + shortDate(parseDateKey(s.date)).toUpperCase();

/// The XP of a training day, as the session tile shows it.
int sessionXp(LogStore store, Session s) => s.legacy && s.classId.isEmpty ? xpPerLegacySession : store.xpOfSession(s);

/// One compact row of the past sessions: the date, then exercises and sets
/// (5 EX · 18 SETS), and the XP. Old days: OLD WORKOUT (D54).
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.store, required this.session, required this.onTap});

  final LogStore store;
  final Session session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final s = session;
    final moves = s.exercises.where((e) => e.sets > 0).length;
    return GestureDetector(
      key: ValueKey('session-row-${s.date}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Brutal(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
        border: 3,
        shadow: p.violet,
        offset: 4,
        duration: Duration.zero,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sessionDate(store, s), style: display(14, p.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    s.legacy ? t('session.old') : '${tn('exShort', moves)} · ${tn('sets', s.totalSets)}',
                    style: mono(11, p.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tag('+${sessionXp(store, s)} XP', bg: p.lime, fg: p.on, size: 12, angle: 2),
          ],
        ),
      ),
    );
  }
}

/// One training day in full ([SessionPage]): every exercise in order with
/// its sets, and the weight and reps of each logged set.
class SessionDetail extends StatelessWidget {
  const SessionDetail({super.key, required this.store, required this.session});

  final LogStore store;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Brutal(
      key: const ValueKey('session-detail'),
      shadow: p.violet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Shout(t('tile.session'), color: p.violet, size: 14),
            const SizedBox(height: 8),
            SessionPage(
              session: session,
              xp: sessionXp(store, session),
              live: identical(session, store.todaySession),
              setLines: true,
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
      child: Brutal(
        padding: const EdgeInsets.all(6),
        border: 3,
        shadow: color,
        offset: 4,
        duration: Duration.zero,
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
        title: t('tile.lifter'),
        color: classColor(Pal.of(context), store.gameClass.id),
        lines: [
          store.gameClass.name.toUpperCase(),
          difficulties[store.difficulty].name.toUpperCase(),
          areaById(store.profile?.areaId).name.toUpperCase(),
        ],
        onTap: onTap,
      );
}

/// The last session (always the newest, not the day opened last) as a
/// tile: date, sets, XP. Tap: the past-sessions list.
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.store, required this.onTap});

  final LogStore store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final all = store.history;
    final s = all.isEmpty ? null : all.first;
    return _Tile(
      key: const ValueKey('tile-session'),
      title: t('tile.last'),
      color: Pal.of(context).violet,
      lines: s == null
          ? [t('tile.nothing')]
          : [
              shortDate(parseDateKey(s.date)).toUpperCase(),
              s.legacy ? t('session.old') : tn('sets', s.totalSets),
              '+${sessionXp(store, s)} XP',
            ],
      onTap: onTap,
    );
  }
}

/// BACK of the past sessions (the list or a day), at the top right of the
/// free tile space: one level up (the day, the list, the editor).
class SessionsBack extends StatelessWidget {
  const SessionsBack({super.key, required this.buttonKey, required this.onTap});

  /// The key of the button itself.
  final Key buttonKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          // Room for the hard shadow inside the tile square.
          padding: const EdgeInsets.only(right: 6),
          child: BrutalButton(
            key: buttonKey,
            color: Pal.of(context).sky,
            onTap: onTap,
            child: FittedBox(fit: BoxFit.scaleDown, child: IconText('back', t('nav.back'))),
          ),
        ),
      );
}

/// SAVE BACKUP and LOAD BACKUP, stacked in the free tile space beside the
/// last-session tile. Placeholder look: design may restyle it.
class BackupButtons extends StatelessWidget {
  const BackupButtons({super.key, required this.onSave, required this.onLoad});

  final VoidCallback onSave, onLoad;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget button(String key, String text, Color color, VoidCallback onTap) => Expanded(
          child: BrutalButton(
            key: ValueKey(key),
            small: true,
            color: color,
            onTap: onTap,
            child: Center(
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, textAlign: TextAlign.center)),
            ),
          ),
        );
    return Padding(
      // Room for the hard shadow inside the tile square.
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          button('backup-save', t('backup.save'), p.lime, onSave),
          button('backup-load', t('backup.load'), p.sky, onLoad),
        ],
      ),
    );
  }
}

/// Asks before a backup file replaces the data on the phone: everything,
/// or only the sessions and XP when the file has no profile ([keepsProfile]).
/// True: load.
Future<bool?> confirmReplaceBackup(BuildContext context, {required bool keepsProfile}) => showDialog<bool>(
      context: context,
      builder: (context) {
        final p = Pal.of(context);
        return Dialog(
          key: const ValueKey('backup-replace-dialog'),
          backgroundColor: p.bg,
          shape: Border.all(color: p.ink, width: 3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Shout(t('backup.replaceTitle'), size: 18, color: p.ink),
                const SizedBox(height: 4),
                Text(t(keepsProfile ? 'backup.replaceSessions' : 'backup.replaceAll'), style: mono(12, p.ink)),
                const SizedBox(height: 14),
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: BrutalButton(
                        key: const ValueKey('backup-replace-cancel'),
                        small: true,
                        color: p.sky,
                        onTap: () => Navigator.pop(context, false),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(t('backup.cancel'))),
                      ),
                    ),
                    Expanded(
                      child: BrutalButton(
                        key: const ValueKey('backup-replace-confirm'),
                        small: true,
                        color: p.pink,
                        onTap: () => Navigator.pop(context, true),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(t('backup.replace'))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
