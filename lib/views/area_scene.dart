// An area scene from the design team's PNG layers (docs/moodboard/areas,
// data in lib/game/area_art.dart): background, floor, shadow, the marks
// that count the sets, the object to hit, effect frames and the burst.
// Pixel art: whole-number scale only, nearest-neighbour, hard-stepped motion.
//
// The lifter is not drawn here: the shell draws the one character on top,
// at [sceneLifterRect].

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/area_art.dart';
import '../pumplex.dart';

/// Rarity ladder for marks (docs/moodboard/areas/README.md): index 5 and up
/// use the last colour.
const markLadder = [
  Color(0xFFC9B8E8),
  Color(0xFFC6FF3D),
  Color(0xFF3FD2FF),
  Color(0xFFA77BFF),
  Color(0xFFFFA033),
  Color(0xFFFF5FB0),
];

/// The colour of every mark in the first round (D69): one colour for all.
const markFirst = Color(0xFFC6FF3D);

/// Mark colours once every mark spot is used (D68): the marks start again
/// at the first spot, one colour per lap, so the new sets stand out.
const markLaps = [
  Color(0xFF3FD2FF),
  Color(0xFFFFA033),
  Color(0xFFA77BFF),
  Color(0xFFFF5FB0),
];

/// The lap of the set shown at mark spot [i] with [count] sets and [spots]
/// spots: 0 for the first round, 1 once the marks start again, and so on.
int markLap(int i, int count, int spots) => count <= i ? 0 : (count - 1 - i) ~/ spots;

/// The biggest whole-number scale at which the scene fits in [box] (min 1).
int sceneScale(Size box) => max(1, min(box.width / sceneSize.width, box.height / sceneSize.height).floor());

/// The scene rect at [scale], centred at the top of [avail].
Rect sceneRectIn(Rect avail, int scale) {
  final w = sceneSize.width * scale, h = sceneSize.height * scale;
  return Rect.fromLTWH(avail.left + (avail.width - w) / 2, avail.top, w, h);
}

/// Where the shell draws the lifter for a scene at [scene] (scale [scale]):
/// a body cell at 1 art px = [scale] px, feet on the shadow. The box is a
/// bit taller than the cell so the height slider (×1.14) still fits.
Rect sceneLifterRect(AreaArt art, Rect scene, int scale) {
  final w = 52.0 * scale, h = 64.0 * scale;
  final feet = scene.top + (art.lifterPos.dy + 64) * scale;
  return Rect.fromLTWH(scene.left + art.lifterPos.dx * scale, feet - h * 1.15, w, h * 1.15);
}

/// The ink frame around a scene at [scene], with a hard shadow in [shadow].
/// Put it in the same [Stack] as the scene, before it.
Widget sceneFrame(Rect scene, {required Color ink, required Color shadow}) => Positioned(
      left: scene.left - 4,
      top: scene.top - 4,
      width: scene.width + 8,
      height: scene.height + 8,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: ink, width: 4),
          boxShadow: [BoxShadow(color: shadow, offset: const Offset(6, 6))],
        ),
      ),
    );

class AreaScene extends StatefulWidget {
  const AreaScene({
    super.key,
    required this.art,
    required this.scale,
    this.count = 0,
    this.hitRun = 0,
    this.burstText,
    this.onHit,
    this.onUndo,
    this.hitLabel = '',
  });

  final AreaArt art;
  final int scale;

  /// Sets of the active exercise: how many marks stay in the world.
  final int count;

  /// Goes up by one on every set: plays the hit, the effect and the burst.
  final int hitRun;

  /// "+1 SET", "CRUSHED!" or the 5th-mark stamp, written on the burst.
  final String? burstText;

  /// Null = a still picture (setup cards).
  final VoidCallback? onHit, onUndo;
  final String hitLabel;

  @override
  State<AreaScene> createState() => _AreaSceneState();
}

class _AreaSceneState extends State<AreaScene> with SingleTickerProviderStateMixin {
  static const _length = 1400; // ms, longer than every hit animation
  late final _t = AnimationController(vsync: this, duration: const Duration(milliseconds: _length));
  bool _played = false;

  @override
  void didUpdateWidget(AreaScene old) {
    super.didUpdateWidget(old);
    if (widget.hitRun != old.hitRun && widget.count > old.count) {
      _played = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _t.value = 1;
      } else {
        _t.forward(from: 0);
      }
    } else if (widget.count < old.count) {
      // Taking a set back has no effect animation.
      _played = false;
      _t.value = 1;
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  Widget _img(String file, Offset pos, Size size, {Color? tint}) {
    final s = widget.scale.toDouble();
    return Positioned(
      left: pos.dx * s,
      top: pos.dy * s,
      width: size.width * s,
      height: size.height * s,
      child: Image.asset(
        file,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        isAntiAlias: false,
        gaplessPlayback: true,
        color: tint,
        colorBlendMode: tint == null ? null : BlendMode.modulate,
        excludeFromSemantics: true,
      ),
    );
  }

  /// Frame of [frames] at [ms] after the hit, or null once it is over.
  /// [holdLast] keeps the last frame that many ms longer.
  ArtFrame? _frameAt(List<ArtFrame> frames, double ms, {int holdLast = 0}) {
    var t = 0;
    for (final f in frames) {
      t += f.ms;
      if (ms < t) return f;
    }
    return frames.isNotEmpty && ms < t + holdLast ? frames.last : null;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.art;
    final s = widget.scale.toDouble();
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final ms = _played ? _t.value * _length : double.infinity;
        // Object frame: play the sequence once, then rest on the last frame.
        var frame = a.objectSequence.last.$1;
        var seqEnd = 0;
        for (final (name, d) in a.objectSequence) {
          if (d == 0) break;
          if (ms < seqEnd + d) {
            frame = name;
            break;
          }
          seqEnd += d;
        }
        // Rustbelt roll-in / Frostbite reform, right after the hit frames.
        var objDx = 0.0, objRot = 0.0, objScale = 1.0;
        final after = ms - seqEnd;
        if (after >= 0 && after < 450 && a.rollIn) {
          final k = (after / 90).floor().clamp(0, 5) / 5; // 5 hard steps
          objDx = 75 * (1 - k);
          objRot = pi / 2 * (1 - k);
        }
        if (after >= 0 && after < 400 && a.reform) {
          objScale = ((after / 100).floor() + 1).clamp(1, 4) / 4; // 4 hard steps
        }
        // Shake the whole stack: 320 ms, 6 hard steps.
        final shakeStep = ms < 320 ? (ms / (320 / 6)).floor() : -1;
        final shake = shakeStep < 0 ? 0.0 : (shakeStep.isEven ? 2.0 : -2.0) * s;

        // Every spot holds the newest set that landed on it (D68).
        final spots = a.markPositions.length;
        final n = min(widget.count, spots);
        final newest = _played && ms < 220 && widget.count > 0 ? (widget.count - 1) % spots : -1;
        final marks = <Widget>[
          for (var i = 0; i < n; i++) _mark(i, newest == i ? ms : null, markLap(i, widget.count, spots)),
        ];
        final fifth = widget.count > 0 && widget.count % 5 == 0;
        final fx = _frameAt(fifth && a.fx5.isNotEmpty ? a.fx5 : a.fx, ms);
        final burst = _frameAt(a.burst, ms, holdLast: 300);
        final object = Transform.translate(
          offset: Offset(objDx * s, 0),
          child: Transform.rotate(
            angle: objRot,
            child: Transform.scale(
              alignment: Alignment.bottomCenter,
              scale: objScale,
              child: Image.asset(
                a.objectFrames[frame]!,
                width: a.objectSize.width * s,
                height: a.objectSize.height * s,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                isAntiAlias: false,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
            ),
          ),
        );
        return SizedBox(
          width: sceneSize.width * s,
          height: sceneSize.height * s,
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(shake, 0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _img(a.background, Offset.zero, sceneSize),
                  _img(a.floor, a.floorPos, Size(sceneSize.width, sceneSize.height - a.floorPos.dy)),
                  _img(a.shadow, a.shadowPos, Size(46, 5)),
                  if (!a.marksOverObject) ...marks,
                  Positioned(left: a.objectPos.dx * s, top: a.objectPos.dy * s, child: object),
                  if (a.ledRect != null)
                    Positioned.fromRect(
                      rect: Rect.fromLTWH(a.ledRect!.left * s, a.ledRect!.top * s, a.ledRect!.width * s, a.ledRect!.height * s),
                      child: FittedBox(
                        child: Text(
                          widget.count.clamp(0, 99).toString().padLeft(2, '0'),
                          key: const ValueKey('scene-led'),
                          style: mono(14, const Color(0xFFC6FF3D)),
                        ),
                      ),
                    ),
                  if (a.marksOverObject) ...marks,
                  if (fx != null) _img(fx.file, Offset.zero, sceneSize),
                  if (burst != null) ...[
                    _img(burst.file, a.burstPos, const Size(50, 50)),
                    if (widget.burstText != null)
                      Positioned(
                        left: (a.burstPos.dx - 15) * s,
                        top: a.burstPos.dy * s,
                        width: 80 * s,
                        height: 50 * s,
                        child: Center(
                          child: Text(
                            widget.burstText!,
                            textAlign: TextAlign.center,
                            style: display(9 * s, kNight).copyWith(
                              shadows: const [Shadow(color: Colors.white, offset: Offset(1, 1))],
                            ),
                          ),
                        ),
                      ),
                  ],
                  // The object: tap = one working set, hold = take one back.
                  if (widget.onHit != null) _hitArea(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _mark(int i, double? popMs, int lap) {
    final a = widget.art;
    final p = a.markPositions[i];
    final isFifth = a.markFifth != null && i % 5 == 4;
    final sprite = isFifth ? a.markFifth! : a.mark;
    // The first round: one colour (D69); each later lap: a new colour (D68).
    final color = lap == 0 ? markFirst : markLaps[(lap - 1) % markLaps.length];
    Widget m = Stack(
      children: [
        _img(sprite.file, Offset.zero, sprite.size, tint: a.tintMarks || lap > 0 ? color : null),
        if (a.markTint != null && !isFifth) _img(a.markTint!.file, Offset.zero, a.markTint!.size, tint: color),
      ],
    );
    if (popMs != null) {
      // Pop in: scale 2.2 to 1, rotate -14° to 0, 4 hard steps over 220 ms.
      final k = ((popMs / 55).floor() + 1).clamp(1, 4) / 4;
      m = Transform.rotate(
        angle: -14 * pi / 180 * (1 - k),
        child: Transform.scale(scale: 2.2 - 1.2 * k, child: m),
      );
    }
    final s = widget.scale.toDouble();
    return Positioned(
      left: p.dx * s,
      top: p.dy * s,
      width: sprite.size.width * s,
      height: sprite.size.height * s,
      child: m,
    );
  }

  Widget _hitArea() {
    final s = widget.scale.toDouble();
    final r = widget.art.hitBox;
    // At least 48 px to touch (the brief asks for 44).
    final w = max(48.0, r.width * s), h = max(48.0, r.height * s);
    return Positioned(
      left: r.center.dx * s - w / 2,
      top: r.center.dy * s - h / 2,
      width: w,
      height: h,
      child: Semantics(
        button: true,
        label: widget.hitLabel,
        child: GestureDetector(
          key: const ValueKey('world-object'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onHit,
          onLongPress: widget.onUndo,
        ),
      ),
    );
  }
}
