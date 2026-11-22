// The 2D character: the mood board's body atlas (docs/moodboard/creator,
// 5 fat × 5 muscle steps per sex), nearest cell for the slider values,
// stretched vertically for height. Pixel art only scales with
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

/// Gear overlay for an item id such as `head.crown` (docs/moodboard/gear).
String gearAtlas(String itemId) =>
    'assets/gear/${itemId.split('.').first}/$itemId.png';

/// Gear layer order, bottom to top (docs/moodboard/gear/README.md).
const gearLayerOrder = [
  GearSlot.bottom,
  GearSlot.top,
  GearSlot.shoes,
  GearSlot.head,
  GearSlot.weapon,
];

/// Every image the character needs, to load before the first frame.
List<String> get allSpriteAssets => [
  bodyAtlas,
  for (final c in gameClasses) outfitAtlas(c.id),
  for (final i in items) gearAtlas(i.id),
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

  /// The atlas image: the body, a class outfit or a gear item (same layout).
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

double heightScale(int height) =>
    minHeightScale + (maxHeightScale - minHeightScale) * height / 100;

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
    this.gear = const [],
    this.pedestal = true,
  });

  final Character character;
  final String classId;

  /// Equipped item ids, drawn over the outfit (D21: never changes the body).
  final Iterable<String> gear;

  /// False in an area scene: the scene has its own ground shadow.
  final bool pedestal;

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
    final equipped = {for (final id in widget.gear) itemById(id)?.slot: id};
    final layers = [
      bodyAtlas,
      outfitAtlas(cls.id),
      for (final slot in gearLayerOrder)
        if (equipped[slot] != null) gearAtlas(equipped[slot]!),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final pedestal = widget.pedestal ? max(10.0, box.maxHeight * 0.1) : 0.0;
        final room = box.maxHeight - pedestal * 0.55;
        // Whole-number scale so every sprite pixel stays square.
        final s = max(
          1,
          min(
            box.maxWidth / spriteWidth,
            room / (spriteHeight * maxHeightScale),
          ).floor(),
        ).toDouble();
        final w = spriteWidth * s;
        return Stack(
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
                          width: w,
                          height: spriteHeight * s * h,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
