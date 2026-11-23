// Freeze-frame intro card (docs/moodboard/README.md "Freeze-frame intro
// card", from borderlands-reference.md): on a class pick and on level-ups.
//
// - Dark diagonal stripes cover the area (the shell also turns the
//   character greyscale with high contrast while the card shows).
// - The name slams in as a stencil tag: 40 px display type on the colour,
//   4 px ink border, hard ink shadow, −6° tilt, scaling down from 2.2× in
//   6 hard steps over 420 ms (no easing, like the pixel art).
// - A joke subtitle slides in under it on an ink strip, tilted −3°.
// - It closes by itself after 1.8 s, or on a tap. With reduced motion, it
//   shows without the slam and the slide.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../pumplex.dart';

/// What the intro card shows.
typedef IntroSpec = ({String title, String subtitle, Color color});

const introSlam = Duration(milliseconds: 420);
const introSteps = 6;
const introHold = Duration(milliseconds: 1800);

/// Greyscale with high contrast, for the frozen character.
const freezeFilter = ColorFilter.matrix([
  0.43, 0.84, 0.15, 0, -90, //
  0.43, 0.84, 0.15, 0, -90,
  0.43, 0.84, 0.15, 0, -90,
  0, 0, 0, 1, 0,
]);

class IntroCard extends StatefulWidget {
  const IntroCard({super.key, required this.spec, required this.onDone});

  final IntroSpec spec;
  final VoidCallback onDone;

  @override
  State<IntroCard> createState() => _IntroCardState();
}

class _IntroCardState extends State<IntroCard> with SingleTickerProviderStateMixin {
  /// The subtitle slides in for this long, after the slam.
  static const _slideMs = 180;
  late final _c = AnimationController(vsync: this, duration: introSlam + const Duration(milliseconds: _slideMs));
  Timer? _close;

  @override
  void initState() {
    super.initState();
    _close = Timer(introHold, widget.onDone);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _close?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return GestureDetector(
      key: const ValueKey('intro-card'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDone,
      child: ClipRect(
        child: CustomPaint(
          painter: _Stripes(),
          child: LayoutBuilder(
            builder: (context, box) => Center(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final ms = _c.value * _c.duration!.inMilliseconds;
                  // 6 hard steps from 2.2× to 1×, no easing.
                  final step = min(introSteps, (ms / introSlam.inMilliseconds * introSteps).floor());
                  final scale = 2.2 - 1.2 * step / introSteps;
                  final slide = ((ms - introSlam.inMilliseconds) / _slideMs).clamp(0.0, 1.0);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: -6 * pi / 180,
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: s.color,
                              border: Border.all(color: kNight, width: 4),
                              boxShadow: const [BoxShadow(color: kNight, offset: Offset(6, 6))],
                            ),
                            // One line; shrinks to fit a narrow card.
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.8),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  s.title.toUpperCase(),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: display(40, kNight).copyWith(letterSpacing: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // No strip when there is no subtitle (the level-up card, D74).
                      if (s.subtitle.isNotEmpty)
                      Opacity(
                        opacity: slide,
                        child: Transform.translate(
                          offset: Offset(-60 * (1 - slide), 0),
                          child: Transform.rotate(
                            angle: -3 * pi / 180,
                            child: Container(
                              color: kNight,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.9),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    s.subtitle.toUpperCase(),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: display(17, s.color).copyWith(letterSpacing: 1.2),
                                  ),
                                ),
                              ),
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
        ),
      ),
    );
  }
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = kNight.withValues(alpha: 0.35));
    final paint = Paint()..color = kNight.withValues(alpha: 0.55);
    const w = 14.0, gap = 28.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + w, size.height)
          ..lineTo(x + w + size.height, 0)
          ..lineTo(x + size.height, 0)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => false;
}
