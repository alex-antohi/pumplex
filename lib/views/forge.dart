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
import '../game/exercises.dart';
import '../game/forge.dart';
import '../i18n.dart';
import '../labels.dart' show bodyPartLabel, muscleLabel;
import '../pumplex.dart';
import '../store.dart';
import 'chalk.dart';

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
    final classes = [for (final c in forgeClasses(_words)) c.name];
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
                        ShadowTitle(
                          (_nick.trim().isEmpty ? name : _nick.trim()).toUpperCase(),
                          textKey: const ValueKey('forge-name'),
                          maxLines: 1,
                          size: 34,
                          shadowColor: p.orange,
                        ),
                        if (_nick.trim().isNotEmpty)
                          Text(name.toUpperCase(), key: const ValueKey('forge-chalk-name'), style: display(16, p.orange)),
                        const SizedBox(height: 12),
                        for (final row in _forgeRows)
                          ChipSection(
                            title: chalkRowLabel(row),
                            small: true,
                            titleSize: 10,
                            gap: 4,
                            bottom: 10,
                            children: [
                              for (final w in chalkWords.where((w) => w.row == row))
                                PickChip(
                                  id: 'forge-${w.key}',
                                  label: chalkLabel(w),
                                  dense: true,
                                  selected: _words.contains(w.key),
                                  color: kNight,
                                  selectedFg: p.chalk,
                                  onTap: () => _toggle(w),
                                ),
                            ],
                          ),
                        Text(
                          classes.isEmpty ? t('forge.noClass') : t('forge.showsFor', {'classes': classes.join(' · ')}),
                          key: const ValueKey('forge-shows-for'),
                          style: mono(11, p.violet),
                        ),
                        const SizedBox(height: 12),
                        ChipSection(
                          title: t('label.bodyPart'),
                          small: true,
                          titleSize: 10,
                          gap: 4,
                          bottom: 10,
                          children: [
                            for (final b in bodyParts)
                              PickChip(
                                id: 'forge-body-${b.id}',
                                label: bodyPartLabel(b.id),
                                dense: true,
                                selected: _body.$1 == b.id,
                                color: p.sky,
                                onTap: () => setState(() {
                                  _bodyPicked = true;
                                  _body = (b.id, b.muscles.first);
                                }),
                              ),
                          ],
                        ),
                        ChipSection(
                          title: t('label.muscle'),
                          small: true,
                          titleSize: 10,
                          gap: 4,
                          bottom: 12,
                          children: [
                            for (final m in part.muscles)
                              PickChip(
                                id: 'forge-muscle-$m',
                                label: muscleLabel(m),
                                dense: true,
                                selected: _body.$2 == m,
                                color: p.violet,
                                onTap: () => setState(() {
                                  _bodyPicked = true;
                                  _body = (part.id, m);
                                }),
                              ),
                          ],
                        ),
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
                                style: display(20, _nick.isEmpty ? p.chalkFaint : p.chalk),
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
            ActionBar(
              padding: const EdgeInsets.fromLTRB(16, 4, 24, 12),
              gap: 12,
              back: BrutalButton(
                key: const ValueKey('forge-back'),
                small: true,
                color: p.sky,
                onTap: () => Navigator.of(context).pop(),
                child: Text(t('nav.back')),
              ),
              main: BrutalButton(
                key: const ValueKey('forge-it'),
                color: p.lime,
                onTap: _forge,
                child: Text(t('forge.go')),
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
