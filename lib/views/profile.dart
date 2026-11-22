// Profile and menu (design demo screens 11 and 12, docs/demo/).

import 'package:flutter/material.dart';

import '../game/content.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../sound.dart';
import '../store.dart';
import 'play.dart';
import 'setup.dart';
import 'sprite.dart';

// ----------------------------------------------------------------- profile

/// "YOUR LIFTER": level and title, the path (class, difficulty, area) and
/// the milestones (achievements). Design: docs/demo/11-profile.html.
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.stage,
    required this.store,
    required this.onBack,
    required this.onBody,
    required this.onHistory,
    required this.onGear,
    required this.onEditStep,
  });

  final Rect stage;
  final LogStore store;
  final VoidCallback onBack, onBody, onHistory, onGear;

  /// Opens one setup step to change it: 1 class, 2 difficulty, 3 area (D13).
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final l = levelFor(store.totalXp);
    final cls = store.gameClass;
    final di = store.difficulty;
    final area = areaById(store.profile?.areaId);
    final got = store.achievementsUnlocked;
    final days = store.history.length;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, stage.top + 4, 24, 30 + MediaQuery.paddingOf(context).bottom),
          children: [
            // Hero: the lifter stands on the right, inside the stage rect.
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: stage.height),
              child: Padding(
                padding: EdgeInsets.only(right: stage.width + 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BrutalButton(
                        key: const ValueKey('profile-back'),
                        small: true,
                        color: p.sky,
                        onTap: onBack,
                        child: const IconText('back', 'HUB')),
                    const SizedBox(height: 10),
                    Shout('Level ${l.level}', color: p.pink),
                    Text(levelTitle(l.level).toUpperCase(), style: display(28, p.ink)),
                    const SizedBox(height: 4),
                    Text(
                      days == 0 ? 'NO TRAINING DAYS YET.' : '$days TRAINING DAY${days == 1 ? '' : 'S'} SURVIVED.',
                      style: mono(11.5, p.ink),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            LevelBar(xp: store.totalXp),
            const SizedBox(height: 22),
            Shout('The path', color: p.violet, size: 15),
            const SizedBox(height: 8),
            _PathRow(
              key: const ValueKey('profile-class'),
              label: 'CLASS',
              value: cls.name,
              sub: cls.equipment,
              color: classColor(p, cls.id),
              onTap: () => onEditStep(1),
            ),
            _PathRow(
              key: const ValueKey('profile-difficulty'),
              label: 'DIFFICULTY',
              value: difficulties[di].name,
              sub: 'DIFFICULTY ${gems(di)}',
              color: difficultyColor(p, di),
              onTap: () => onEditStep(2),
            ),
            _PathRow(
              key: const ValueKey('profile-area'),
              label: 'WORLD',
              value: area.name,
              sub: area.line,
              color: Color(area.accent),
              onTap: () => onEditStep(3),
            ),
            const SizedBox(height: 18),
            Shout('Milestones', color: p.violet, size: 15),
            const SizedBox(height: 8),
            if (got.isEmpty)
              const Terminal(['NO MEDALS YET.', 'YOUR FIRST SET UNLOCKS FIRST BLOOD.']),
            for (final a in achievements) _Milestone(name: a.name, line: a.line, open: got.containsKey(a.id)),
            const SizedBox(height: 6),
            // Placeholder note: the achievements list is still open (D27).
            Text('MORE MILESTONES COMING. THE LIST IS A PLACEHOLDER.', style: mono(10.5, p.ink)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: BrutalButton(
                      key: const ValueKey('profile-history'),
                      color: p.sky,
                      onTap: onHistory,
                      child: const Text('PAST SESSIONS')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrutalButton(
                      key: const ValueKey('profile-gear'),
                      color: p.lime,
                      onTap: onGear,
                      child: const IconText('gear', 'GEAR')),
                ),
              ],
            ),
          ],
        ),
        // Tap the lifter to change the body sliders (D12).
        Positioned.fromRect(
          rect: stage,
          child: GestureDetector(
            key: const ValueKey('profile-character'),
            behavior: HitTestBehavior.translucent,
            onTap: onBody,
          ),
        ),
      ],
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    super.key,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  final String label, value, sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Brutal(
        margin: const EdgeInsets.only(bottom: 12),
        shadow: color,
        offset: 5,
        border: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: mono(10.5, p.ink)),
                    Text(value.toUpperCase(), style: display(19, p.ink)),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: mono(11, p.ink)),
                  ],
                ),
              ),
              Text('CHANGE', style: display(14, color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.name, required this.line, required this.open});

  final String name, line;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Opacity(
      opacity: open ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: open ? p.orange : p.panel,
                border: Border.all(color: p.ink, width: 3),
              ),
              child: PxIcon(open ? 'star' : 'lock', size: 18, color: p.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.toUpperCase(), style: display(16, p.ink)),
                  Text(line, style: mono(11, p.ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- menu

/// Full-screen menu (design: docs/demo/12-menu.html). Sections: you, gains
/// insurance (backup), look and feel. The design's DANGER ZONE (wipe all
/// data) is not built: owner decision D30 (docs/decisions.md).
class MenuView extends StatelessWidget {
  const MenuView({
    super.key,
    required this.store,
    required this.onClose,
    required this.onProfile,
    required this.onHistory,
    required this.onEditCharacter,
    required this.onSave,
    required this.onRestore,
    required this.onCel,
  });

  final LogStore store;
  final VoidCallback onClose, onSave, onRestore, onCel;

  /// Null when there is no profile yet (first setup).
  final VoidCallback? onProfile, onHistory, onEditCharacter;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final n = store.history.length;
    final l = levelFor(store.totalXp);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 30 + MediaQuery.paddingOf(context).bottom),
      children: [
        Row(
          children: [
            Expanded(child: Text('MENU', style: display(30, p.ink))),
            BrutalButton(
                key: const ValueKey('menu-close'),
                small: true,
                color: p.pink,
                onTap: onClose,
                child: const IconText('close', 'CLOSE')),
          ],
        ),
        const SizedBox(height: 16),
        if (onProfile != null) ...[
          const _Label('01', 'You'),
          _Item(
            key: const ValueKey('menu-profile'),
            title: 'PROFILE',
            sub: 'LVL ${l.level} ${levelTitle(l.level).toUpperCase()} · ${store.gameClass.name.toUpperCase()}',
            onTap: onProfile!,
          ),
          _Item(
            key: const ValueKey('menu-history'),
            title: 'PAST SESSIONS',
            sub: n == 0 ? 'Nothing logged yet. The floor is waiting.' : '$n training day${n == 1 ? '' : 's'} logged.',
            onTap: onHistory!,
          ),
          _Item(
            key: const ValueKey('menu-edit'),
            title: 'EDIT CHARACTER',
            sub: 'Body, class, difficulty, area. Your XP stays.',
            onTap: onEditCharacter!,
          ),
          const SizedBox(height: 10),
        ],
        const _Label('02', 'Gains insurance'),
        _Item(
          key: const ValueKey('menu-save'),
          title: 'SAVE BACKUP FILE',
          sub: n == 0 ? '0 training days. Back up anyway, you optimist.' : 'All $n training days into one file.',
          onTap: onSave,
        ),
        _Item(
          key: const ValueKey('menu-restore'),
          title: 'RESTORE BACKUP FILE',
          sub: 'Replaces everything on this phone with the file.',
          onTap: onRestore,
        ),
        const SizedBox(height: 10),
        const _Label('03', 'Look and feel'),
        _Item(
          key: const ValueKey('menu-chaos'),
          title: 'CHAOS MODE',
          sub: 'The whole app wobbles.',
          on: store.chaos.value,
          onTap: () => store.setChaos(!store.chaos.value),
        ),
        _Item(
          key: const ValueKey('menu-cel'),
          title: 'CEL SHADER',
          sub: 'Toon bands and ink outlines.',
          on: store.cel.value,
          onTap: onCel,
        ),
        _Item(
          key: const ValueKey('menu-sound'),
          title: 'SOUND',
          sub: 'Clanks, smashes and the level-up horn.',
          on: store.sound.value,
          onTap: () {
            final on = !store.sound.value;
            store.setSound(on);
            if (on) Sfx.play('ui_toggle');
          },
        ),
        const SizedBox(height: 18),
        BrutalButton(key: const ValueKey('menu-back'), color: p.lime, onTap: onClose, child: const Text('BACK')),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.no, this.text);

  final String no, text;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Tag(no, bg: p.violet, fg: p.on, size: 13, angle: 0),
          const SizedBox(width: 8),
          Shout(text, color: p.ink, size: 15),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({super.key, required this.title, required this.sub, required this.onTap, this.on});

  final String title, sub;
  final VoidCallback? onTap;

  /// A toggle shows ON / OFF; null = a plain action.
  final bool? on;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Brutal(
          margin: const EdgeInsets.only(bottom: 10),
          shadow: on == true ? p.lime : p.violet,
          offset: 4,
          border: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: display(18, p.ink)),
                      Text(sub, style: mono(11, p.ink)),
                    ],
                  ),
                ),
                if (on != null) Tag(on! ? 'ON' : 'OFF', bg: on! ? p.lime : kNight, fg: on! ? p.on : p.ink, size: 14),
                if (onTap == null) Tag('SOON', bg: kNight, fg: p.ink, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
