// The 2D character: mood board body-slider sprites, nearest frame for the
// slider values, stretched vertically for height. Pixel art only scales
// with nearest-neighbour sampling (FilterQuality.none).

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../pumplex.dart';

/// Nearest slider stop that has a drawn sprite (0, 50 or 100).
int nearestStop(int v) =>
    spriteStops.reduce((a, b) => (v - a).abs() <= (v - b).abs() ? a : b);

/// Asset for [c]'s nearest frame.
String spriteAsset(Character c) =>
    'assets/body/${c.female ? 'female' : 'male'}/fat${nearestStop(c.fat)}_muscle${nearestStop(c.muscle)}.png';

/// Every sprite, to load them all before the first frame needs one.
List<String> get allSpriteAssets => [
      for (final sex in ['male', 'female'])
        for (final f in spriteStops)
          for (final m in spriteStops) 'assets/body/$sex/fat${f}_muscle$m.png',
    ];

double heightScale(int height) =>
    minHeightScale + (maxHeightScale - minHeightScale) * height / 100;

/// Accent colour of a class (pedestal and highlights).
Color classColor(Pal p, String id) => switch (id) {
      'speedy' => p.orange,
      'rogue' => p.sky,
      'warrior' => p.lime,
      _ => p.violet,
    };

/// The character on a pedestal in the class colour, sized to fill its box.
/// Bounces once when the frame or the class changes.
class CharacterSprite extends StatefulWidget {
  const CharacterSprite({super.key, required this.character, required this.classId});

  final Character character;
  final String classId;

  @override
  State<CharacterSprite> createState() => _CharacterSpriteState();
}

class _CharacterSpriteState extends State<CharacterSprite> with SingleTickerProviderStateMixin {
  late final _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void didUpdateWidget(CharacterSprite old) {
    super.didUpdateWidget(old);
    if (spriteAsset(old.character) != spriteAsset(widget.character) ||
        old.classId != widget.classId) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final cls = classById(widget.classId);
    final color = classColor(p, cls.id);
    return LayoutBuilder(builder: (context, box) {
      final pedestal = max(10.0, box.maxHeight * 0.1);
      final room = box.maxHeight - pedestal * 0.55;
      // Whole-number scale so every sprite pixel stays square.
      final s = max(1, min(box.maxWidth / spriteWidth, room / (spriteHeight * maxHeightScale)).floor())
          .toDouble();
      final w = spriteWidth * s;
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Pedestal.
          Positioned(
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: w * 1.25,
              height: pedestal,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.all(Radius.elliptical(w, pedestal)),
                border: Border.all(color: p.ink, width: max(2, s / 2)),
              ),
            ),
          ),
          Positioned(
            bottom: pedestal * 0.45,
            child: AnimatedBuilder(
              animation: _bounce,
              builder: (context, child) => Transform.scale(
                alignment: Alignment.bottomCenter,
                scaleX: 1 + 0.08 * sin(_bounce.value * pi),
                scaleY: 1 - 0.06 * sin(_bounce.value * pi),
                child: child,
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: heightScale(widget.character.height)),
                duration: const Duration(milliseconds: 220),
                builder: (context, h, _) => Image.asset(
                  spriteAsset(widget.character),
                  key: const ValueKey('character-sprite'),
                  width: w,
                  height: spriteHeight * s * h,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                  isAntiAlias: false,
                ),
              ),
            ),
          ),
          // Class prop (placeholder until the class outfits are drawn).
          Positioned(
            bottom: pedestal * 0.2,
            right: max(0, box.maxWidth / 2 - w * 0.75),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Text(cls.icon, key: ValueKey(cls.id), style: TextStyle(fontSize: max(14, s * 7))),
            ),
          ),
        ],
      );
    });
  }
}

/// Plain tally marks: groups of four strokes and a fifth across.
class TallyMarks extends StatelessWidget {
  const TallyMarks({super.key, required this.count, this.height = 34});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return CustomPaint(
      size: Size(_width(count, height), height),
      painter: _Tally(count, p.ink),
    );
  }

  static double _width(int n, double h) {
    final groups = (n / 5).ceil();
    return groups == 0 ? 0 : groups * h * 0.9 + (groups - 1) * h * 0.3;
  }
}

class _Tally extends CustomPainter {
  _Tally(this.n, this.color);

  final int n;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..strokeWidth = max(2.5, h * 0.11)
      ..strokeCap = StrokeCap.square;
    final gw = h * 0.9, gap = h * 0.3, step = gw / 4.4;
    for (var i = 0; i < n; i++) {
      final g = i ~/ 5, k = i % 5;
      final x0 = g * (gw + gap);
      if (k < 4) {
        final x = x0 + step * (k + 0.6);
        canvas.drawLine(Offset(x, h * 0.08), Offset(x, h * 0.92), paint);
      } else {
        canvas.drawLine(Offset(x0, h * 0.8), Offset(x0 + gw, h * 0.2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_Tally old) => old.n != n || old.color != color;
}
