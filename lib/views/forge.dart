// The FORGE card (D72, docs/moodboard/chalk/02-forge.html): opened from the
// CHALK sheet's NO SUCH MOVE. FORGE IT? button. One scrolling card: the name
// from the chalk words (or the nickname, big, with the words' name small
// under it), the word chips TOOL, MOVE, PATTERN (tap to change them; no
// ANGLE or GRIP: the exercise card sets those, D81), which classes have the
// gear, BODY PART and MUSCLE (a first guess from the words), and an
// optional NICKNAME typed on an arcade keyboard (QWERTY, a Romanian row,
// no digits). BACK and FORGE IT sit in a bar at the bottom, over the
// keyboard; FORGE IT works before OK. The name has no length limit: it
// shrinks to stay on one line.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/chalk.dart';
import '../game/content.dart';
import '../game/exercises.dart';
import '../game/forge.dart';
import '../i18n.dart';
import '../pumplex.dart';
import '../store.dart';
import 'chalk.dart';
import 'filters.dart' show bodyPartLabel, muscleLabel;

/// Opens the FORGE card over the app, starting from the chalk [words].
Future<void> showForge(NavigatorState nav, LogStore store, Set<String> words) =>
    nav.push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ForgeScreen(store: store, words: words)));

/// The rows of word chips on the card, top to bottom.
const _forgeRows = ['tool', 'move', 'pattern'];

class ForgeScreen extends StatefulWidget {
  const ForgeScreen({super.key, required this.store, required this.words});

  final LogStore store;
  final Set<String> words;

  @override
  State<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends State<ForgeScreen> {
  late Set<String> _words = {...widget.words};
  late (String, String) _body = forgeBody(_words) ?? ('chest', 'chest');

  /// The lifter picked the body part or muscle: the words no longer move it.
  bool _bodyPicked = false;
  String _nick = '';
  bool _typing = false;

  void _toggle(ChalkWord w) => setState(() {
        _words = chalkToggle(_words, w);
        if (!_bodyPicked) _body = forgeBody(_words) ?? _body;
      });

  void _forge() {
    HapticFeedback.heavyImpact();
    final n = _nick.trim();
    widget.store.forge(_words, _body.$2, n.isEmpty ? null : n);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final name = forgeName(_words);
    final equipment = ForgedMove(id: '', words: _words, muscle: _body.$2).toExercise().equipment;
    final classes = [for (final c in gameClasses) if (classEquipment[c.id]!.contains(equipment)) c.name];
    final part = bodyPartById(_body.$1)!;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                child: Brutal(
                  key: const ValueKey('forge-card'),
                  shadow: p.orange,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shout(t('forge.title'), size: 13, color: p.ink),
                        const SizedBox(height: 8),
                        // The name on one line, smaller when long.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text((_nick.trim().isEmpty ? name : _nick.trim()).toUpperCase(),
                              key: const ValueKey('forge-name'),
                              maxLines: 1,
                              style: display(34, p.ink).copyWith(shadows: [Shadow(offset: const Offset(2, 2), color: p.orange)])),
                        ),
                        if (_nick.trim().isNotEmpty)
                          Text(name.toUpperCase(), key: const ValueKey('forge-chalk-name'), style: display(16, p.orange)),
                        const SizedBox(height: 12),
                        for (final row in _forgeRows) ...[
                          Text(chalkRowLabel(row).toUpperCase(), style: mono(10, p.ink)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final w in chalkWords.where((w) => w.row == row))
                              _Pick(
                                id: 'forge-${w.key}',
                                label: chalkLabel(w),
                                selected: _words.contains(w.key),
                                color: kNight,
                                fg: kChalk,
                                onTap: () => _toggle(w),
                              ),
                          ]),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          classes.isEmpty ? t('forge.noClass') : t('forge.showsFor', {'classes': classes.join(' · ')}),
                          key: const ValueKey('forge-shows-for'),
                          style: mono(11, p.violet),
                        ),
                        const SizedBox(height: 12),
                        Text(t('label.bodyPart').toUpperCase(), style: mono(10, p.ink)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final b in bodyParts)
                            _Pick(
                              id: 'forge-body-${b.id}',
                              label: bodyPartLabel(b.id),
                              selected: _body.$1 == b.id,
                              color: p.sky,
                              fg: p.on,
                              onTap: () => setState(() {
                                _bodyPicked = true;
                                _body = (b.id, b.muscles.first);
                              }),
                            ),
                        ]),
                        const SizedBox(height: 10),
                        Text(t('label.muscle').toUpperCase(), style: mono(10, p.ink)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final m in part.muscles)
                            _Pick(
                              id: 'forge-muscle-$m',
                              label: muscleLabel(m),
                              selected: _body.$2 == m,
                              color: p.violet,
                              fg: p.on,
                              onTap: () => setState(() {
                                _bodyPicked = true;
                                _body = (part.id, m);
                              }),
                            ),
                        ]),
                        const SizedBox(height: 12),
                        Text(t('forge.nickname'), style: mono(10, p.ink)),
                        const SizedBox(height: 4),
                        GestureDetector(
                          key: const ValueKey('forge-nickname'),
                          onTap: () => setState(() => _typing = true),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                            decoration: BoxDecoration(
                              color: kNight,
                              border: Border.all(color: _typing ? p.pink : p.ink, width: 3),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _nick.isEmpty ? t('forge.carve') : '${_nick.toUpperCase()}${_typing ? '_' : ''}',
                                style: display(20, _nick.isEmpty ? kChalk.withValues(alpha: 0.35) : kChalk),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // BACK and FORGE IT, over the keyboard.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 24, 12),
              child: Row(
                children: [
                  BrutalButton(
                    key: const ValueKey('forge-back'),
                    small: true,
                    color: p.sky,
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(t('nav.back')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrutalButton(
                      key: const ValueKey('forge-it'),
                      color: p.lime,
                      onTap: _forge,
                      child: Text(t('forge.go')),
                    ),
                  ),
                ],
              ),
            ),
            if (_typing)
              ArcadeKeyboard(
                onKey: (k) => setState(() => _nick += k),
                onDelete: () => setState(() => _nick = _nick.isEmpty ? '' : _nick.substring(0, _nick.length - 1)),
                onOk: () => setState(() => _typing = false),
              ),
          ],
        ),
      ),
    );
  }
}

/// A chip on the FORGE card: filled when picked.
class _Pick extends StatelessWidget {
  const _Pick({required this.id, required this.label, required this.selected, required this.color, required this.fg, required this.onTap});

  final String id, label;
  final bool selected;
  final Color color, fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      key: ValueKey(id),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : p.panel,
          border: Border.all(color: p.ink, width: 2),
          boxShadow: selected ? [BoxShadow(color: p.ink, offset: const Offset(2, 2))] : null,
        ),
        child: Text(label.toUpperCase(), style: display(12, selected ? fg : p.ink)),
      ),
    );
  }
}

/// The arcade keyboard (D72): QWERTY, a Romanian row (Ă Â Î Ș Ț), then DEL,
/// SPACE and OK. No digits. It is not the phone's keyboard.
class ArcadeKeyboard extends StatelessWidget {
  const ArcadeKeyboard({super.key, required this.onKey, required this.onDelete, required this.onOk});

  final ValueChanged<String> onKey;
  final VoidCallback onDelete, onOk;

  static const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM', 'ĂÂÎȘȚ'];

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget key(String id, String label, VoidCallback onTap, {int flex = 1, Color? color}) => Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: GestureDetector(
              key: ValueKey('key-$id'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color ?? p.panel, border: Border.all(color: p.ink, width: 2)),
                child: Text(label, style: display(16, p.ink)),
              ),
            ),
          ),
        );
    return Container(
      key: const ValueKey('arcade-keyboard'),
      color: kNight,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, row) in rows.indexed)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: i * 10.0),
              child: Row(children: [for (final c in row.characters) key(c, c, () => onKey(c))]),
            ),
          Row(children: [
            key('del', t('kb.del'), onDelete, flex: 2, color: p.orange),
            key('space', t('kb.space'), () => onKey(' '), flex: 5),
            key('ok', t('kb.ok'), onOk, flex: 2, color: p.lime),
          ]),
        ],
      ),
    );
  }
}
