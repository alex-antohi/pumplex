// The FORGE card, FORJA in Romanian (D72, D83; the MINIMAL take of
// docs/moodboard/forge/01-forge-remodel.html). Opened from CHALK's FORGE IT
// (or NO SUCH MOVE. FORGE IT?), so a forge is 2 taps: FORGE IT there, FORGE
// IT here. One short card, no scroll: the name from the words (or the
// nickname, big, with the words' name small under it), 3 word slots (MOVE,
// TOOL, PATTERN; a tap on a slot opens only that row's tiles; no ANGLE or
// GRIP, D81), "+ TYPE THE MOVE" (a move CHALK has no word for, typed on
// the arcade keyboard and kept as typed), BODY (one chip; a tap opens the
// parts) with its muscles (the guess tagged GUESSED until the lifter taps
// one), and an optional NICKNAME on the arcade keyboard (QWERTY, a
// Romanian row, no digits). While the keyboard is up, BODY and MUSCLE hide.
// BACK and FORGE IT sit in a bar at the bottom, over the keyboard; FORGE IT
// works before OK. The forged move goes into Today and is selected (D79,
// D82). A move with a typed word gets the ANVIL reveal first.
//
// Edit mode (D78): a long-press on a forged card's title in Today opens the
// same card, filled in; the bar reads SAVE, plus MELT (delete; a dialog
// asks first when the move has sets).

import 'dart:async';
import 'dart:math';

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
/// [onBackToChalk] reopens CHALK (the BACK TO CHALK button).
Future<void> showForge(NavigatorState nav, LogStore store, Set<String> words, {VoidCallback? onBackToChalk}) =>
    nav.push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ForgeScreen(store: store, words: words, onBackToChalk: onBackToChalk)));

/// Opens the FORGE card in edit mode for forged move [move] (D78).
Future<void> showForgeEdit(NavigatorState nav, LogStore store, ForgedMove move) => nav.push(MaterialPageRoute<void>(
    fullscreenDialog: true, builder: (_) => ForgeScreen(store: store, words: move.words, edit: move)));

/// The word slots on the card, left to right (the mockup's order).
const forgeSlots = ['move', 'tool', 'pattern'];

/// How long the ANVIL reveal plays, and how long its loot card stays after.
const kRevealPlay = Duration(milliseconds: 1200);
const kRevealHold = Duration(milliseconds: 900);

/// The body part a muscle belongs to.
String _partOf(String muscle) => (bodyParts.where((b) => b.muscles.contains(muscle)).firstOrNull ?? bodyParts.first).id;

class ForgeScreen extends StatefulWidget {
  const ForgeScreen({super.key, required this.store, required this.words, this.edit, this.onBackToChalk});

  final LogStore store;
  final Set<String> words;

  /// The forged move edited (D78); null: a new forge.
  final ForgedMove? edit;
  final VoidCallback? onBackToChalk;

  @override
  State<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends State<ForgeScreen> {
  late Set<String> _words = {...widget.words};
  late (String, String) _body = widget.edit != null
      ? (_partOf(widget.edit!.muscle), widget.edit!.muscle)
      : forgeBody(_words) ?? ('chest', 'chest');

  /// The lifter picked the body part or muscle: the words no longer move it
  /// and the GUESSED tag goes.
  late bool _bodyPicked = widget.edit != null;
  late String _nick = widget.edit?.nickname ?? '';

  /// The move word typed with "+ TYPE THE MOVE" (D83).
  late String _typed = widget.edit?.typed ?? '';

  /// What the keyboard types: 'nick', 'move', or null (no keyboard).
  String? _typing;

  /// The slot (or 'body') whose tiles are open, or null.
  String? _open;

  /// The move forged with a typed word: the ANVIL reveal plays over the card.
  ForgedMove? _reveal;
  bool _closing = false;

  bool get _editing => widget.edit != null;

  void _toggle(ChalkWord w) => setState(() {
        _words = chalkToggle(_words, w);
        if (w.row == 'move') _typed = ''; // a chalk word takes the typed one's place
        if (!_bodyPicked) _body = forgeBody(_words) ?? _body;
      });

  void _type(String k) => setState(() {
        if (_typing == 'move') {
          if (_typed.isEmpty && k == ' ') return;
          _typed += k;
          _words = {for (final w in _words) if (!w.startsWith('move.')) w}; // the typed word is the MOVE
        } else {
          _nick += k;
        }
      });

  void _delete() => setState(() {
        String cut(String s) => s.isEmpty ? '' : s.substring(0, s.length - 1);
        if (_typing == 'move') {
          _typed = cut(_typed);
        } else {
          _nick = cut(_nick);
        }
      });

  String? get _nickOrNull => _nick.trim().isEmpty ? null : _nick.trim();

  void _forge() {
    if (_reveal != null) return;
    HapticFeedback.heavyImpact();
    if (_editing) {
      widget.store.editForged(widget.edit!.id, _words, _body.$2, _nickOrNull, typed: _typed);
      _close();
      return;
    }
    final move = widget.store.forge(_words, _body.$2, _nickOrNull, typed: _typed);
    // The ANVIL reveal only for a typed move word (D83).
    if (move.typed != null) {
      setState(() {
        _typing = null;
        _reveal = move;
      });
    } else {
      _close();
    }
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _melt() async {
    final id = widget.edit!.id;
    final sets = widget.store.allSets(id);
    if (sets > 0 && await _confirmMelt(context, sets) != true) return;
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    widget.store.meltForged(id);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final name = forgeName(_words, typed: _typed);
    final nick = _nick.trim();
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The title and BACK TO CHALK.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 24, 4),
                  child: Row(
                    children: [
                      Shout(t('forge.title'), size: 18, color: p.ink),
                      const Spacer(),
                      if (widget.onBackToChalk != null)
                        BrutalButton(
                          key: const ValueKey('forge-back-chalk'),
                          small: true,
                          color: p.sky,
                          onTap: () {
                            _close();
                            widget.onBackToChalk!();
                          },
                          child: Text(t('forge.backToChalk')),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 24, 12),
                    child: Brutal(
                      key: const ValueKey('forge-card'),
                      shadow: p.orange,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(t(_editing ? 'forge.editMove' : 'forge.newMove'), style: mono(10, p.inkQuiet)),
                                const Spacer(),
                                Text(t(_typed.trim().isNotEmpty ? 'forge.typed' : 'forge.fromChalk'),
                                    style: mono(10, p.lime).copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // The name on one line, smaller when long.
                            ShadowTitle(
                              (nick.isEmpty ? name : nick).toUpperCase(),
                              textKey: const ValueKey('forge-name'),
                              maxLines: 1,
                              size: 34,
                              shadowColor: p.orange,
                            ),
                            if (nick.isNotEmpty)
                              Text(name.toUpperCase(), key: const ValueKey('forge-chalk-name'), style: display(16, p.orange)),
                            const SizedBox(height: 10),
                            Text(t('forge.words'), style: mono(10, p.inkQuiet)),
                            const SizedBox(height: 4),
                            _slots(p),
                            if (_open != null && _open != 'body') _tiles(p, _open!),
                            const SizedBox(height: 8),
                            _typeTile(p),
                            if (_typing == null) ...[
                              const SizedBox(height: 10),
                              _bodyAndMuscles(p),
                            ],
                            const SizedBox(height: 10),
                            Text(t('forge.nickname'), style: mono(10, p.ink)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              key: const ValueKey('forge-nickname'),
                              onTap: () => setState(() => _typing = 'nick'),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                                decoration: BoxDecoration(
                                  color: kNight,
                                  border: Border.all(color: _typing == 'nick' ? p.pink : p.ink, width: 3),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _nick.isEmpty && _typing != 'nick'
                                        ? t('forge.carve')
                                        : '${_nick.toUpperCase()}${_typing == 'nick' ? '_' : ''}',
                                    style: display(20, _nick.isEmpty && _typing != 'nick' ? p.chalkFaint : p.chalk),
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
                // BACK (and MELT when editing), then FORGE IT or SAVE, over the keyboard.
                ActionBar(
                  padding: const EdgeInsets.fromLTRB(16, 4, 24, 12),
                  gap: 12,
                  back: Row(
                    spacing: 10,
                    children: [
                      BrutalButton(
                        key: const ValueKey('forge-back'),
                        small: true,
                        color: p.sky,
                        onTap: _close,
                        child: Text(t('nav.back')),
                      ),
                      if (_editing)
                        BrutalButton(
                          key: const ValueKey('forge-melt'),
                          small: true,
                          color: p.pink,
                          onTap: _melt,
                          child: Text(t('forge.melt')),
                        ),
                    ],
                  ),
                  main: BrutalButton(
                    key: const ValueKey('forge-it'),
                    color: p.lime,
                    onTap: _forge,
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(t(_editing ? 'forge.save' : 'forge.go'))),
                  ),
                ),
                if (_typing != null)
                  ArcadeKeyboard(
                    onKey: _type,
                    onDelete: _delete,
                    onOk: () => setState(() => _typing = null),
                  ),
              ],
            ),
            // The ANVIL reveal: over everything, it takes every tap (D83).
            if (_reveal != null) Positioned.fill(child: ForgeReveal(move: _reveal!, onDone: _close)),
          ],
        ),
      ),
    );
  }

  /// The 3 word slots: a filled slot is lime; a tap opens that row's tiles.
  Widget _slots(Pal p) => Row(
        spacing: 6,
        children: [
          for (final row in forgeSlots)
            Expanded(
              child: Builder(builder: (context) {
                final id = chalkIdOf(_words, row);
                final typed = row == 'move' && _typed.trim().isNotEmpty;
                final word = typed ? _typed.trim() : id == null ? '—' : chalkLabel(chalkWordByKey('$row.$id')!);
                final filled = typed || id != null;
                final open = _open == row;
                return GestureDetector(
                  key: ValueKey('forge-slot-$row'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _open = open ? null : row),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
                    decoration: BoxDecoration(
                      color: filled ? p.lime : kNight,
                      border: Border.all(color: open ? p.pink : p.ink, width: 3),
                      boxShadow: filled ? [BoxShadow(color: p.ink, offset: const Offset(3, 3))] : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(chalkRowLabel(row).toUpperCase(),
                            maxLines: 1, style: mono(8, filled ? p.on.withValues(alpha: 0.7) : p.chalkFaint)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(word.toUpperCase(),
                              key: ValueKey('forge-slot-$row-word'), style: display(17, filled ? p.on : p.chalk)),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
        ],
      );

  /// The tiles of slot [row] (only the open one).
  Widget _tiles(Pal p, String row) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          key: ValueKey('forge-tiles-$row'),
          spacing: 4,
          runSpacing: 4,
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
      );

  /// "+ TYPE THE MOVE" (D83): a dashed tile; while typing it shows the word.
  Widget _typeTile(Pal p) {
    final on = _typing == 'move';
    return GestureDetector(
      key: const ValueKey('forge-type-move'),
      onTap: () => setState(() {
        _typing = 'move';
        _open = null;
      }),
      child: CustomPaint(
        painter: _Dashed(on ? p.pink : p.ink),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
          child: Text(
            on ? '${_typed.toUpperCase()}_' : t('forge.typeMove'),
            style: display(13, on ? p.pink : p.ink),
          ),
        ),
      ),
    );
  }

  /// BODY (one chip; a tap opens all parts) and its muscles, the guess
  /// tagged GUESSED until the lifter picks.
  Widget _bodyAndMuscles(Pal p) {
    final part = bodyPartById(_body.$1)!;
    final openBody = _open == 'body';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(chalkRowLabel('body').toUpperCase(), style: mono(10, p.inkQuiet)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final b in bodyParts)
              if (openBody || b.id == _body.$1)
                PickChip(
                  id: 'forge-body-${b.id}',
                  label: openBody ? bodyPartLabel(b.id) : '${bodyPartLabel(b.id)} ▾',
                  dense: true,
                  selected: _body.$1 == b.id,
                  color: p.sky,
                  onTap: () => setState(() {
                    if (!openBody) {
                      _open = 'body';
                      return;
                    }
                    _open = null;
                    if (b.id != _body.$1) {
                      _bodyPicked = true;
                      _body = (b.id, b.muscles.first);
                    }
                  }),
                ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(t('label.muscle').toUpperCase(), style: mono(10, p.inkQuiet)),
            if (!_bodyPicked) ...[
              const SizedBox(width: 6),
              Container(
                key: const ValueKey('forge-guessed'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                color: p.orange,
                child: Text(t('forge.guessed'), style: mono(9, p.on).copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
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
      ],
    );
  }
}

/// A dashed ink border (the "+ TYPE THE MOVE" tile: raw ore).
class _Dashed extends CustomPainter {
  _Dashed(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const dash = 6.0, gap = 4.0, w = 2.5;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      final e = min(x + dash, size.width);
      canvas.drawRect(Rect.fromLTRB(x, 0, e, w), paint);
      canvas.drawRect(Rect.fromLTRB(x, size.height - w, e, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += dash + gap) {
      final e = min(y + dash, size.height);
      canvas.drawRect(Rect.fromLTRB(0, y, w, e), paint);
      canvas.drawRect(Rect.fromLTRB(size.width - w, y, size.width, e), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => old.color != color;
}

/// Asks before a forged move with [sets] sets melts (D78). True: melt.
Future<bool?> _confirmMelt(BuildContext context, int sets) => showDialog<bool>(
      context: context,
      builder: (context) {
        final p = Pal.of(context);
        return Dialog(
          key: const ValueKey('forge-melt-dialog'),
          backgroundColor: p.bg,
          shape: Border.all(color: p.ink, width: 3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Shout(t('forge.meltTitle'), size: 18, color: p.ink),
                const SizedBox(height: 4),
                Text(tn('forge.meltSets', sets), style: mono(12, p.ink)),
                const SizedBox(height: 14),
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: BrutalButton(
                        key: const ValueKey('forge-melt-cancel'),
                        small: true,
                        color: p.sky,
                        onTap: () => Navigator.pop(context, false),
                        child: Text(t('forge.meltKeep')),
                      ),
                    ),
                    Expanded(
                      child: BrutalButton(
                        key: const ValueKey('forge-melt-confirm'),
                        small: true,
                        color: p.pink,
                        onTap: () => Navigator.pop(context, true),
                        child: Text(t('forge.melt')),
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

// The pixel colours of the anvil and the hammer (drawn rectangles, no art).
const _steel = Color(0xFF8C82B4), _steelDark = Color(0xFF4B4170), _wood = Color(0xFF8B5A2B);

/// The ANVIL reveal (D83; the runner-up take of the remodel mockup), only
/// for a move forged with a typed word. The words drop onto an anvil, a
/// hammer strikes, and the new move shows like a loot card: [kRevealPlay],
/// then the card stays [kRevealHold] and [onDone] closes it. Any tap skips
/// it, and that tap does nothing else (like the level-up card). With
/// reduced motion, the loot card shows at once.
class ForgeReveal extends StatefulWidget {
  const ForgeReveal({super.key, required this.move, required this.onDone});

  final ForgedMove move;
  final VoidCallback onDone;

  @override
  State<ForgeReveal> createState() => _ForgeRevealState();
}

class _ForgeRevealState extends State<ForgeReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: kRevealPlay);
  Timer? _hold;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _hold = Timer(kRevealHold, _finish);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      _hold = Timer(kRevealHold, _finish);
    } else {
      _c.forward();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final move = widget.move;
    final words = [
      move.typed!,
      for (final row in ['tool', 'pattern'])
        if (chalkIdOf(move.words, row) case final id?) chalkLabel(chalkWordByKey('$row.$id')!),
    ];
    return GestureDetector(
      key: const ValueKey('forge-reveal'),
      behavior: HitTestBehavior.opaque,
      onTap: _finish, // a skip: nothing else
      child: ColoredBox(
        color: kNight.withValues(alpha: 0.96),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            double seg(double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);
            final drop = Curves.easeIn.transform(seg(0, 0.35));
            final lift = seg(0.35, 0.45), strike = Curves.easeIn.transform(seg(0.45, 0.58));
            final flash = v > 0.56 && v < 0.68;
            final loot = Curves.easeOutBack.transform(seg(0.62, 1));
            final stage = 1 - seg(0.62, 0.8);
            return LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth, h = box.maxHeight;
              final anvilTop = h * 0.55;
              return Stack(
                children: [
                  if (stage > 0)
                    Opacity(
                      opacity: stage,
                      child: Stack(
                        children: [
                          // The anvil: face and horn, waist, foot.
                          Positioned(left: w * 0.2, top: anvilTop, width: w * 0.6, height: 22, child: const ColoredBox(color: _steel)),
                          Positioned(left: w * 0.12, top: anvilTop + 4, width: w * 0.1, height: 12, child: const ColoredBox(color: _steel)),
                          Positioned(left: w * 0.36, top: anvilTop + 22, width: w * 0.28, height: 26, child: const ColoredBox(color: _steelDark)),
                          Positioned(left: w * 0.28, top: anvilTop + 48, width: w * 0.44, height: 14, child: const ColoredBox(color: _steelDark)),
                          // The words drop onto the face.
                          for (final (i, word) in words.indexed)
                            Positioned(
                              left: w * 0.22 + i * w * 0.19,
                              top: -40 + (anvilTop - 34 + 40) * drop - (i.isOdd ? 6 : 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(color: p.lime, border: Border.all(color: kNight, width: 2)),
                                child: Text(word.toUpperCase(), style: display(13, kNight)),
                              ),
                            ),
                          // The hammer: up, then down onto the words.
                          Positioned(
                            left: w * 0.5,
                            top: anvilTop - 150,
                            child: Transform.rotate(
                              angle: -0.2 - 0.7 * lift + 1.25 * strike,
                              alignment: Alignment.bottomRight,
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: Stack(children: [
                                  Positioned(left: 56, top: 20, width: 10, height: 100, child: const ColoredBox(color: _wood)),
                                  Positioned(left: 30, top: 0, width: 62, height: 30, child: const ColoredBox(color: _steel)),
                                ]),
                              ),
                            ),
                          ),
                          // Sparks on the strike.
                          if (flash)
                            for (var i = 0; i < 8; i++)
                              Positioned(
                                left: w * 0.5 + cos(i * pi / 4) * 46 * (v - 0.5) * 8,
                                top: anvilTop - 10 + sin(i * pi / 4) * 30 * (v - 0.5) * 8,
                                width: 6,
                                height: 6,
                                child: ColoredBox(color: i.isEven ? p.lime : p.orange),
                              ),
                        ],
                      ),
                    ),
                  // The loot card.
                  if (loot > 0)
                    Center(
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * loot,
                        child: Opacity(opacity: loot.clamp(0.0, 1.0), child: _LootCard(move: move)),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 24,
                    child: Text(t('forge.revealHint'), textAlign: TextAlign.center, style: mono(11, Pal.chalkWhite)),
                  ),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}

/// The new move as a loot card: NEW ITEM!, the rarity, the name and its
/// body, muscle and tool.
class _LootCard extends StatelessWidget {
  const _LootCard({required this.move});

  final ForgedMove move;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final tool = chalkIdOf(move.words, 'tool');
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Text(k.toUpperCase(), style: mono(10, Pal.chalkWhite.withValues(alpha: 0.6))),
            const Spacer(),
            Text(v.toUpperCase(), style: display(15, Pal.chalkWhite)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Text(t('forge.loot'), style: display(34, p.pink).copyWith(shadows: const [Shadow(offset: Offset(3, 3), color: Pal.chalkWhite)]))),
          const SizedBox(height: 12),
          Brutal(
            key: const ValueKey('forge-loot'),
            color: kNight,
            borderColor: p.lime,
            shadow: p.orange,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tag(t('forge.rarity'), bg: p.lime, fg: kNight, size: 12, angle: 0),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text((move.nickname ?? move.name).toUpperCase(),
                        style: display(28, Pal.chalkWhite).copyWith(shadows: [Shadow(offset: const Offset(2, 2), color: p.pink)])),
                  ),
                  if (move.nickname != null) Text(move.name.toUpperCase(), style: display(14, p.orange)),
                  line(chalkRowLabel('body'), '${bodyPartLabel(_partOf(move.muscle))} · ${muscleLabel(move.muscle)}'),
                  line(chalkRowLabel('tool'), tool == null ? '—' : chalkLabel(chalkWordByKey('tool.$tool')!)),
                ],
              ),
            ),
          ),
        ],
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
