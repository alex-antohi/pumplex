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
// D82), then the ANVIL reveal plays: the words drop onto an anvil, a
// hammer strikes, and the move shows as a NEW ITEM! loot card with FORGE
// ANOTHER (back to CHALK) and TO TODAY (closes on the new Today card).
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

/// How long the ANVIL reveal plays before its loot card is fully in. The
/// loot card then stays until FORGE ANOTHER or TO TODAY (no auto-close).
const kRevealPlay = Duration(milliseconds: 1400);

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

  /// The move just forged: the ANVIL reveal plays over the card.
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
    // Saved before the hammer falls, so a skip or a locked phone loses
    // nothing. Every new forge gets the ANVIL reveal (D83).
    final move = widget.store.forge(_words, _body.$2, _nickOrNull, typed: _typed);
    setState(() {
      _typing = null;
      _open = null;
      _reveal = move;
    });
  }

  /// FORGE ANOTHER on the loot card: back to CHALK, the words kept.
  void _another() {
    final nav = Navigator.of(context);
    _close();
    if (widget.onBackToChalk != null) {
      widget.onBackToChalk!();
    } else {
      showChalkSheet(nav.context, widget.store);
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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
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
          ),
          // The ANVIL reveal: over the whole screen (status bar too), on top
          // of the card in this same route; it takes every tap (D83).
          if (_reveal != null)
            Positioned.fill(child: ForgeReveal(move: _reveal!, onAnother: _another, onToday: _close)),
        ],
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

// The pixel colours of the anvil stage (drawn boxes, no art), from the
// ANVIL mockup: steel, its light edge and shadow, the outline, the handle.
const _steel = Color(0xFF5A4A7A), _steelLight = Color(0xFF8A7AB0), _steelDark = Color(0xFF3D3058);
const _hammerHead = Color(0xFFC9B8E8), _wood = Color(0xFFA6643C), _outline = Color(0xFF0B0414);

/// The ANVIL reveal (D83; the ANVIL take of the remodel mockup) after every
/// new forge. The words drop onto an anvil, a hammer strikes twice with
/// sparks, then rays and the NEW ITEM! loot card: the name (the nickname
/// big), body and muscle, tool, pattern, the classes, in a rarity frame
/// (RARE for a typed word, COMMON for a chalk mix). FORGE ANOTHER
/// ([onAnother]) and TO TODAY ([onToday]) are the only ways out: no
/// auto-close, so the lifter sees the loot. A tap while it plays skips to
/// the loot card and does nothing else. With reduced motion, the loot card
/// shows at once, with no rays.
class ForgeReveal extends StatefulWidget {
  const ForgeReveal({super.key, required this.move, required this.onAnother, required this.onToday});

  final ForgedMove move;
  final VoidCallback onAnother, onToday;

  @override
  State<ForgeReveal> createState() => _ForgeRevealState();
}

class _ForgeRevealState extends State<ForgeReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: kRevealPlay);
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  /// A tap while it plays: jump to the loot card, nothing else.
  void _skip() {
    if (_c.isCompleted) return;
    _c.stop();
    _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final move = widget.move;
    final moveId = chalkIdOf(move.words, 'move');
    final words = [
      if (move.typed != null) move.typed! else if (moveId != null) chalkLabel(chalkWordByKey('move.$moveId')!),
      for (final row in ['tool', 'pattern'])
        if (chalkIdOf(move.words, row) case final id?) chalkLabel(chalkWordByKey('$row.$id')!),
    ];
    return GestureDetector(
      key: const ValueKey('forge-reveal'),
      behavior: HitTestBehavior.opaque,
      onTap: _skip, // a skip only; on the loot card, only the 2 buttons act
      child: ColoredBox(
        color: _outline.withValues(alpha: 0.9),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              final done = _c.isCompleted;
              double seg(double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);
              final stage = 1 - seg(0.7, 0.8);
              final rays = _still ? 0.0 : seg(0.72, 0.9);
              final loot = Curves.easeOutBack.transform(seg(0.74, 1));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (rays > 0) Positioned.fill(child: CustomPaint(painter: _Rays(p.lime.withValues(alpha: 0.13 * rays)))),
                        if (stage > 0)
                          Opacity(
                            opacity: stage,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 24, 0),
                              child: _AnvilStage(v: v, words: words),
                            ),
                          ),
                        if (loot > 0)
                          Transform.scale(
                            scale: 0.6 + 0.4 * loot,
                            child: Opacity(opacity: loot.clamp(0.0, 1.0), child: _LootCard(move: move)),
                          ),
                      ],
                    ),
                  ),
                  Text(t(done ? 'forge.revealHint' : 'forge.revealSkip'),
                      textAlign: TextAlign.center, style: mono(11, Pal.chalkWhite.withValues(alpha: 0.7))),
                  // The 2 buttons, only on the loot card (a tap there while it
                  // plays is a skip).
                  IgnorePointer(
                    ignoring: !done,
                    child: Opacity(
                      opacity: done ? 1 : 0,
                      child: ActionBar(
                        padding: const EdgeInsets.fromLTRB(16, 10, 24, 12),
                        gap: 12,
                        back: BrutalButton(
                          key: const ValueKey('forge-another'),
                          small: true,
                          color: p.sky,
                          onTap: widget.onAnother,
                          child: Text(t('forge.another')),
                        ),
                        main: BrutalButton(
                          key: const ValueKey('forge-to-today'),
                          color: p.lime,
                          onTap: widget.onToday,
                          child: FittedBox(fit: BoxFit.scaleDown, child: Text(t('forge.toToday'))),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The anvil stage at time [v] (0 to 1 of [kRevealPlay]): a dotted panel
/// with THE ANVIL tag and a forge glow; [words] drop onto a pixel anvil,
/// then a pixel hammer strikes twice and sparks fly. Drawn on a fixed
/// 300 x 242 grid (the mockup's), scaled down on narrow phones.
class _AnvilStage extends StatelessWidget {
  const _AnvilStage({required this.v, required this.words});

  final double v;
  final List<String> words;

  /// The hammer's angle (radians; 0 is head up, minus swings it left onto
  /// the anvil): rest, lift, strike, lift, strike, rest.
  static double hammer(double v) {
    const rest = 0.61, up = 1.0, hit = -1.5;
    double seg(double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);
    double lerp(double a, double b, double x) => a + (b - a) * x;
    if (v < 0.28) return rest;
    if (v < 0.36) return lerp(rest, up, seg(0.28, 0.36));
    if (v < 0.42) return lerp(up, hit, Curves.easeIn.transform(seg(0.36, 0.42)));
    if (v < 0.52) return lerp(hit, up, Curves.easeOut.transform(seg(0.44, 0.52)));
    if (v < 0.58) return lerp(up, hit, Curves.easeIn.transform(seg(0.52, 0.58)));
    return lerp(hit, rest, Curves.easeOut.transform(seg(0.6, 0.7)));
  }

  /// How far the sparks of a strike starting at [a] have flown (0: none).
  double spark(double a) => v < a || v > a + 0.12 ? 0 : (v - a) / 0.12;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    double seg(double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);
    final drop = Curves.bounceOut.transform(seg(0, 0.28));
    final heat = max(spark(0.42), spark(0.58));
    Widget px(double l, double t, double w, double h, Color c, {double edge = 4}) => Positioned(
          left: l,
          top: t,
          width: w,
          height: h,
          child: DecoratedBox(
              decoration: BoxDecoration(color: c, border: edge > 0 ? Border.all(color: _outline, width: edge) : null)),
        );
    return Container(
      key: const ValueKey('forge-anvil'),
      height: 250,
      decoration: BoxDecoration(
        color: p.panel2,
        border: Border.all(color: p.ink, width: 4),
        boxShadow: [BoxShadow(color: p.orange, offset: const Offset(8, 8))],
      ),
      child: ClipRect(
        child: CustomPaint(
          painter: _Dots(p.dot),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 300,
                height: 242,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // The forge glow under the anvil, hotter on a strike.
                    Positioned(
                      left: 40,
                      top: 130,
                      width: 220,
                      height: 80,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(colors: [
                            const Color(0xFFFFA033).withValues(alpha: 0.4 + 0.4 * (1 - heat) * (heat > 0 ? 1 : 0)),
                            const Color(0x00FFA033),
                          ]),
                        ),
                      ),
                    ),
                    // The pixel anvil: horn, face and its light edge, waist, foot.
                    px(40, 150, 44, 16, _steel),
                    px(70, 150, 200, 26, _steel),
                    px(74, 154, 192, 5, _steelLight, edge: 0),
                    px(120, 172, 100, 30, _steelDark),
                    px(96, 198, 148, 18, _steel),
                    // The words drop onto the face.
                    for (final (i, word) in words.indexed)
                      Positioned(
                        left: 150.0 - words.length * 45 + i * 90,
                        top: -60 + (116 + 60) * drop - (i.isOdd ? 4 : 0),
                        child: Transform.rotate(
                          angle: (i.isOdd ? 5 : -6) * pi / 180,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 84),
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
                            decoration: BoxDecoration(
                              color: p.lime,
                              border: Border.all(color: p.ink, width: 3),
                              boxShadow: [BoxShadow(color: p.ink, offset: const Offset(3, 3))],
                            ),
                            child: FittedBox(
                                fit: BoxFit.scaleDown, child: Text(word.toUpperCase(), style: display(15, p.on))),
                          ),
                        ),
                      ),
                    // The hammer, turning on the end of its handle.
                    Positioned(
                      left: 250 - 28,
                      top: 136 - 112,
                      child: Transform.rotate(
                        angle: hammer(v),
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: 56,
                          height: 112,
                          child: Stack(children: [
                            px(22, 24, 12, 88, _wood, edge: 3),
                            px(0, 0, 56, 28, _hammerHead),
                          ]),
                        ),
                      ),
                    ),
                    // Sparks from each strike.
                    for (final a in const [0.42, 0.58])
                      if (spark(a) > 0)
                        for (var i = 0; i < 10; i++)
                          Positioned(
                            left: 160 + cos(pi + i * pi / 9) * 70 * spark(a),
                            top: 140 + sin(pi + i * pi / 9) * 60 * spark(a) + 50 * spark(a) * spark(a),
                            width: i.isEven ? 8 : 6,
                            height: i.isEven ? 8 : 6,
                            child: ColoredBox(color: i % 3 == 0 ? p.orange : p.lime),
                          ),
                    // The stage tag.
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Transform.rotate(
                        angle: -2 * pi / 180,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
                          decoration: BoxDecoration(color: _outline, border: Border.all(color: p.orange, width: 2)),
                          child: Text(t('forge.anvil'), style: display(13, p.orange)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The stage's dotted ground.
class _Dots extends CustomPainter {
  _Dots(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = 10.0; y < size.height; y += 20) {
      for (var x = 10.0; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Dots old) => old.color != color;
}

/// The loot rays: wedges of [color] around the middle (8 degrees on, 12 off).
class _Rays extends CustomPainter {
  _Rays(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    final paint = Paint()..color = color;
    for (var a = 0.0; a < 360; a += 20) {
      final a0 = a * pi / 180, a1 = (a + 8) * pi / 180;
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(c.dx + cos(a0) * r, c.dy + sin(a0) * r)
            ..lineTo(c.dx + cos(a1) * r, c.dy + sin(a1) * r)
            ..close(),
          paint);
    }
  }

  @override
  bool shouldRepaint(_Rays old) => old.color != color;
}

/// The new move as a loot card: NEW ITEM!, then a card in its rarity frame
/// (lime RARE for a typed word, sky COMMON for a chalk mix) with the name
/// (the nickname big, the words' name under it), FORGED BY YOU, and its
/// body and muscle, tool, pattern, classes and XP.
class _LootCard extends StatelessWidget {
  const _LootCard({required this.move});

  final ForgedMove move;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final rare = move.typed != null;
    final frame = rare ? p.lime : p.sky;
    String word(String row) {
      final id = chalkIdOf(move.words, row);
      return id == null ? '—' : chalkLabel(chalkWordByKey('$row.$id')!);
    }

    final classes = forgeClasses(move.words);
    Widget stat(String k, String v, {Color? color}) => Container(
          padding: const EdgeInsets.fromLTRB(0, 7, 0, 6),
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Pal.chalkWhite.withValues(alpha: 0.25), width: 2))),
          child: Row(children: [
            Text(k.toUpperCase(), style: mono(10, Pal.chalkWhite.withValues(alpha: 0.6))),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(v.toUpperCase(), style: display(16, color ?? Pal.chalkWhite)),
                ),
              ),
            ),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Transform.rotate(
              angle: -3 * pi / 180,
              child: Text(
                t('forge.loot'),
                key: const ValueKey('forge-loot-title'),
                style: display(34, Pal.chalkWhite).copyWith(shadows: [
                  Shadow(offset: const Offset(3, 3), color: p.pink),
                  Shadow(offset: const Offset(6, 6), color: p.sky),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Brutal(
            key: const ValueKey('forge-loot'),
            angle: -1.5,
            color: kNight,
            borderColor: frame,
            shadow: p.orange,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tag(t(rare ? 'forge.rarity' : 'forge.rarityCommon'), bg: frame, fg: kNight, size: 12, angle: 0),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text((move.nickname ?? move.name).toUpperCase(),
                        key: const ValueKey('forge-loot-name'),
                        style: display(30, Pal.chalkWhite).copyWith(shadows: [Shadow(offset: const Offset(2, 2), color: p.pink)])),
                  ),
                  if (move.nickname != null) Text(move.name.toUpperCase(), style: display(14, p.orange)),
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 10),
                    child: Text(t('forge.forgedBy'), style: display(13, p.orange)),
                  ),
                  stat(chalkRowLabel('body'), '${bodyPartLabel(_partOf(move.muscle))} · ${muscleLabel(move.muscle)}'),
                  stat(chalkRowLabel('tool'), word('tool')),
                  if (chalkIdOf(move.words, 'pattern') != null) stat(chalkRowLabel('pattern'), word('pattern')),
                  if (classes.isNotEmpty)
                    stat(t('forge.appearsAt'), [for (final c in classes) c.name].join(' · '), color: p.lime),
                  stat(t('forge.xpPerSet'), t('forge.xpLikeAny')),
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
