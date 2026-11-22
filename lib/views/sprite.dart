// The 2D character: the mood board's body atlas (docs/moodboard/creator,
// 5 fat × 5 muscle steps per sex), nearest cell for the slider values,
// scaled evenly for height. Skin, hair and facial hair come from
// tools/moodboard/looks.mjs (docs/moodboard/looks). Pixel art only scales with
// nearest-neighbour sampling (FilterQuality.none).

import 'dart:math';

import 'package:flutter/material.dart';

import '../game/content.dart';
import '../game/model.dart';
import '../game/rules.dart';
import '../pumplex.dart';

/// The body atlas: 260×640 px, 52×64 cells. Column = fat (0, 25, 50, 75,
/// 100). Rows 0-4 = male muscle 0..100, rows 5-9 = female, same order.
const bodyAtlas = 'assets/body/body_atlas.png';

/// Nearest slider stop that has a drawn cell (0, 25, 50, 75 or 100).
int nearestStop(int v) =>
    spriteStops.reduce((a, b) => (v - a).abs() <= (v - b).abs() ? a : b);

/// Atlas cell (column, row) for [c]'s nearest frame.
(int, int) spriteCell(Character c) => (
  spriteStops.indexOf(nearestStop(c.fat)),
  (c.female ? spriteStops.length : 0) +
      spriteStops.indexOf(nearestStop(c.muscle)),
);

/// Readable name of [c]'s frame, e.g. "female/fat0_muscle100".
String spriteFrame(Character c) =>
    '${c.female ? 'female' : 'male'}/fat${nearestStop(c.fat)}_muscle${nearestStop(c.muscle)}';

/// Class outfit overlay (docs/moodboard/outfits): same cells as the body.
String outfitAtlas(String classId) => 'assets/outfits/$classId.png';

/// The body atlas in [skin] and [hair] (the drawn atlas is light + brown).
String bodyAtlasFor(String skin, String hair) =>
    skin == defaultSkin && hair == defaultHair ? bodyAtlas : 'assets/body/looks/body_${skin}_$hair.png';

/// Beard overlay in the hair colour: same cells as the body.
String beardAtlas(String hair) => 'assets/body/looks/beard_$hair.png';

/// The atlas layers of [c], bottom to top: body, facial hair, outfit.
List<String> spriteLayers(Character c, String classId) => [
  bodyAtlasFor(c.skin, c.hair),
  if (c.facialHair == 'beard') beardAtlas(c.hair),
  outfitAtlas(classId),
];

/// Every image the character needs, to load before the first frame.
List<String> get allSpriteAssets => [
  for (final s in skinIds)
    for (final h in hairIds) bodyAtlasFor(s, h),
  for (final h in hairIds) beardAtlas(h),
  for (final c in gameClasses) outfitAtlas(c.id),
];

/// One atlas cell drawn at [width] × [height] (nearest-neighbour).
class AtlasSprite extends StatelessWidget {
  const AtlasSprite({
    super.key,
    required this.frame,
    required this.cell,
    required this.width,
    required this.height,
    this.asset = bodyAtlas,
  });

  final String frame;

  /// The atlas image: the body or a class outfit (same layout).
  final String asset;
  final (int, int) cell;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final cols = spriteStops.length, rows = spriteStops.length * 2;
    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: FractionalOffset(
            cell.$1 / (cols - 1),
            cell.$2 / (rows - 1),
          ),
          minWidth: width * cols,
          maxWidth: width * cols,
          minHeight: height * rows,
          maxHeight: height * rows,
          child: Image.asset(
            asset,
            width: width * cols,
            height: height * rows,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            isAntiAlias: false,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

/// Size factor of the sprite for the height slider (0..100). The sprite
/// grows evenly (width and height), it is not stretched.
double heightScale(int height) =>
    minHeightScale + (maxHeightScale - minHeightScale) * height / 100;

/// Where [CharacterSprite] draws in a box of [size]: the whole-number pixel
/// scale, the pedestal height and the sprite rect for [height].
({double scale, double pedestal, Rect sprite}) spriteGeometry(Size size, int height, {bool pedestal = true}) {
  final ped = pedestal ? max(10.0, size.height * 0.1) : 0.0;
  final room = size.height - ped * 0.55;
  // Whole-number scale so every sprite pixel stays square.
  final s = max(1, min(size.width / spriteWidth, room / (spriteHeight * maxHeightScale)).floor()).toDouble();
  final h = heightScale(height);
  final w = spriteWidth * s * h, hh = spriteHeight * s * h;
  return (scale: s, pedestal: ped, sprite: Rect.fromLTWH((size.width - w) / 2, size.height - ped * 0.45 - hh, w, hh));
}

/// The head inside a sprite rect: cell rows 0-17, columns 16-35.
Rect headRect(Rect sprite) {
  final px = sprite.width / spriteWidth;
  return Rect.fromLTWH(sprite.left + 16 * px, sprite.top, 20 * px, 18 * px);
}

/// Accent colour of a class (pedestal and highlights).
Color classColor(Pal p, String id) => switch (id) {
  'scrapper' => p.orange,
  'bruiser' => p.sky,
  'paladin' => p.lime,
  _ => p.violet,
};

/// The character on a pedestal in the class colour, sized to fill its box.
/// Bounces once when the frame or the class changes.
class CharacterSprite extends StatefulWidget {
  const CharacterSprite({
    super.key,
    required this.character,
    required this.classId,
    this.pedestal = true,
    this.zoomHead = false,
  });

  final Character character;
  final String classId;

  /// False in an area scene: the scene has its own ground shadow.
  final bool pedestal;

  /// The camera zooms onto the head (the creator's head looks).
  final bool zoomHead;

  @override
  State<CharacterSprite> createState() => _CharacterSpriteState();
}

class _CharacterSpriteState extends State<CharacterSprite>
    with SingleTickerProviderStateMixin {
  late final _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(CharacterSprite old) {
    super.didUpdateWidget(old);
    if (spriteFrame(old.character) != spriteFrame(widget.character) ||
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
    final layers = spriteLayers(widget.character, cls.id);
    return LayoutBuilder(
      builder: (context, box) {
        final g = spriteGeometry(box.biggest, widget.character.height, pedestal: widget.pedestal);
        final pedestal = g.pedestal, s = g.scale;
        final w = spriteWidth * s;
        // Head zoom: the head grows to most of the box height and moves to
        // its middle. Pixels stay square (FilterQuality.none).
        final head = headRect(g.sprite);
        final zoom = box.maxHeight * 0.8 / head.height;
        final to = Offset(box.maxWidth / 2, box.maxHeight / 2);
        return TweenAnimationBuilder<double>(
          tween: Tween(end: widget.zoomHead ? 1 : 0),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          builder: (context, t, child) {
            if (t == 0) return child!;
            final at = Offset.lerp(head.center, to, t)!;
            final k = 1 + (zoom - 1) * t;
            return ClipRect(
              child: Transform(
                transform: Matrix4.translationValues(at.dx, at.dy, 0)
                    .multiplied(Matrix4.diagonal3Values(k, k, 1))
                    .multiplied(Matrix4.translationValues(-head.center.dx, -head.center.dy, 0)),
                child: child,
              ),
            );
          },
          child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Pedestal.
            if (widget.pedestal)
              Positioned(
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: w * 1.25,
                  height: pedestal,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.all(
                      Radius.elliptical(w, pedestal),
                    ),
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
                  builder: (context, h, _) => Stack(
                    children: [
                      for (final (i, asset) in layers.indexed)
                        AtlasSprite(
                          key: i == 0
                              ? const ValueKey('character-sprite')
                              : null,
                          asset: asset,
                          frame: spriteFrame(widget.character),
                          cell: spriteCell(widget.character),
                          width: w * h,
                          height: spriteHeight * s * h,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        );
      },
    );
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
