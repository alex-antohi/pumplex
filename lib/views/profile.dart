// Profile and menu (design demo screens 11 and 12, docs/demo/).

import 'package:flutter/material.dart';

import '../game/content.dart';
import '../game/rules.dart';
import '../pumplex.dart';
import '../store.dart';
import 'play.dart';
import 'setup.dart';
import 'sprite.dart';

// ----------------------------------------------------------------- profile

/// "YOUR LIFTER": level and title and the path (class, difficulty, area).
/// Design: docs/demo/11-profile.html, without the milestones (D35).
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.stage,
    required this.store,
    required this.onBack,
    required this.onBody,
    required this.onHistory,
    required this.onEditStep,
  });

  final Rect stage;
  final LogStore store;
  final VoidCallback onBack, onBody, onHistory;

  /// Opens one setup step to change it: 1 class, 2 difficulty, 3 area (D13).
  final ValueChanged<int> onEditStep;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final l = levelFor(store.totalXp);
    final cls = store.gameClass;
    final di = store.difficulty;
    final area = areaById(store.profile?.areaId);
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
            BrutalButton(
                key: const ValueKey('profile-history'),
                color: p.sky,
                onTap: onHistory,
                child: const Text('PAST SESSIONS')),
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

// -------------------------------------------------------------------- menu

/// Full-screen menu (design: docs/demo/12-menu.html). Sections: you and
/// gains insurance (backup). Not built: the design's DANGER ZONE (D30) and
/// look and feel (chaos, cel shader, sound: D39-D41).
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
  });

  final LogStore store;
  final VoidCallback onClose, onSave, onRestore;

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
  const _Item({super.key, required this.title, required this.sub, required this.onTap});

  final String title, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Brutal(
        margin: const EdgeInsets.only(bottom: 10),
        shadow: p.violet,
        offset: 4,
        border: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: display(18, p.ink)),
              Text(sub, style: mono(11, p.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
